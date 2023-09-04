`timescale 1ns/1ps
//`include "cpu_macro.svh"

module DecodeUnit_3 #(
    parameter CTRL_EXTEND_INST_SET = 1'b0
) (
    input clk,
    input flush,
    input stall,

    output logic allowin_D,
    input logic allowin_I, //issue queue handshake

    input   logic       [63:0]  instr_F,
    input   logic       [1:0]   valid_F,
    input   logic       [31:0]  pc_F,
    input   Predict_Branch_S [1:0]    bp_info_F,
    input   logic       [4:0]   exc_code_F,
    input   logic               tre_F,

    output  logic       [1:0]   valid_D,
    output  instr_info   [1:0]   instr_D_o,
    
    output  logic               bp_failed_D,
    output  logic       [31:0]  correct_pc_D,
    output  Recover_Decode_S   recover_decode
);
instr_info [1:0] decoded_instr;
instr_info [1:0] decoded_instr_final;
logic ori_bp_failed_D;
instr_info priv_instr;
logic [31:0] _correct_pc_D;
logic [1:0] valid;
wire [1:0] _valid_D;
instr_info [1:0] instr_D;
instr_info [1:0] _instr_D;

instr_info [1:0] pbp_inst_buf;
logic [1:0] pbp_buf_valid;
wire pbp_allowin;

//assign valid_D = ori_bp_failed_D ? 2'b00 : {instr_D_o[1].valid, instr_D_o[0].valid};
assign valid_D  = ori_bp_failed_D ? 2'b00 : 
                  pbp_buf_valid ? pbp_buf_valid : _valid_D;
assign _instr_D = valid[0] ? decoded_instr_final : 
                  valid[1] ? {decoded_instr_final[0], decoded_instr_final[1]} : decoded_instr_final;
assign _valid_D = valid[0] ? valid : 
                  valid[1] ? {valid[0], valid[1]} : valid;
//assign allowin_D = (!(|valid) || allowin_I) && !stall;
assign allowin_D = !(|valid) && pbp_buf_valid == 2'b00 || pbp_allowin && allowin_I;

logic [31:0] instr0, instr1;
logic [31:0] pc0, pc1;
logic [4:0] exc_code;
logic tre_D;
Predict_Branch_S [1:0] bp_info;
Predict_Branch_S last_branch_bp_info;

logic wait_delayslot;
logic wait_likely;
logic [31:0] pc_delayslot;

// can reuse my decoder design, use 2 module to decode the two instr
wire self_flush;
always_ff @( posedge clk ) begin
    if (flush || self_flush || ori_bp_failed_D) begin
        valid <= 2'b00;
        instr0 <= '0;
        instr1 <= '0;
        pc0 <= '0;
        pc1 <= '0;
        exc_code <= '0;
        tre_D <= '0;
        bp_info <= '0;
    end
    else if (allowin_D) begin
        valid <= valid_F;
        instr0 <= instr_F[31:0];
        instr1 <= instr_F[63:32];
        pc0 <= pc_F;
        pc1 <= pc_F + 4;
        exc_code <= exc_code_F;
        tre_D <= tre_F;
        bp_info <= bp_info_F;
    end

    if (flush) begin
        wait_delayslot <= 0;
        wait_likely <= 1'b0;
    end
    else if (valid && (ori_bp_failed_D && pbp_allowin || allowin_I)) begin
        if ((decoded_instr[1].is_branch || 
            decoded_instr[0].is_branch && !decoded_instr[1].valid) && exc_code == `Int) begin
            // in these clk cycle, no instr can become delayslot instr
            wait_delayslot <= 1;
            wait_likely <= decoded_instr[1].is_branch ? decoded_instr[1].is_likely : decoded_instr[0].is_likely;
            last_branch_bp_info <= decoded_instr[1].is_branch ? bp_info[1] : bp_info[0];
            pc_delayslot <= (decoded_instr[1].is_branch) ? decoded_instr[1].pc + 4 : 
                            decoded_instr[0].pc + 4;
        end
        else if (wait_delayslot && decoded_instr[0].valid && pc_delayslot == decoded_instr[0].pc) begin
            wait_delayslot <= 0;
            wait_likely <= 1'b0;
        end
        else if (wait_delayslot && decoded_instr[1].valid && pc_delayslot == decoded_instr[1].pc) begin
            wait_delayslot <= 0;
            wait_likely <= 1'b0;
        end
    end
end

Decoder #(.CTRL_EXTEND_INST_SET(CTRL_EXTEND_INST_SET)) decoder0 (
    .en(valid[0]/* && exc_code == 0*/),
    .instr(instr0),
    .pc(pc0),
    .delayslot('0),
    .bp_info(bp_info[0]),
    .instr_d(decoded_instr[0])
);

Decoder #(.CTRL_EXTEND_INST_SET(CTRL_EXTEND_INST_SET)) decoder1(
    .en(valid[1]/* && exc_code == 0*/),
    .instr(instr1),
    .pc(pc1),
    .bp_info(bp_info[1]),
    .delayslot('0),
    .instr_d(decoded_instr[1])
);

always_comb begin
    decoded_instr_final = decoded_instr;
    if (decoded_instr[1].valid && decoded_instr[0].is_branch && exc_code == `Int) begin
        // decoded_instr[0] is delayslot jump and decoded_instr[1] valid
        decoded_instr_final[1].in_delayslot = 1;
        decoded_instr_final[1].likely_delayslot = decoded_instr[0].is_likely;
    end
    else if (decoded_instr[0].valid && wait_delayslot) begin
        decoded_instr_final[0].in_delayslot = 1;
        decoded_instr_final[0].likely_delayslot = wait_likely;
    end
    else if (decoded_instr[1].valid && wait_delayslot) begin
        decoded_instr_final[1].in_delayslot = 1;
        decoded_instr_final[1].likely_delayslot = wait_likely;
    end

    if (exc_code != `Int) begin
        if (valid[0]) begin
            decoded_instr_final[0].is_cal = '0;
            decoded_instr_final[0].is_accmem = '0;
            decoded_instr_final[0].is_branch = '0;
            decoded_instr_final[0].is_md = '0;
            decoded_instr_final[0].wr_md = '0;
            decoded_instr_final[0].is_likely = '0;
            
            decoded_instr_final[0].rf_ctrl = '0;
            decoded_instr_final[0].alu_ctrl = '0;
            decoded_instr_final[0].mdu_ctrl = '0;
            decoded_instr_final[0].mem_ctrl = '0;
            decoded_instr_final[0].cache_op = '0;
            decoded_instr_final[0].tlb_ctrl = '0;
            decoded_instr_final[0].cp0_ctrl = '0;
            decoded_instr_final[0].trap_ctrl = '0;
            decoded_instr_final[0].bru_ctrl = `pc4_bru;
            
            decoded_instr_final[0].exc_code = exc_code;
            decoded_instr_final[0].exc_tre = tre_D;
            decoded_instr_final[0].bad_va_addr = decoded_instr[0].pc;
            decoded_instr_final[0].is_priv = 1;
        end
        if (valid[1]) begin
            decoded_instr_final[1].is_cal = '0;
            decoded_instr_final[1].is_accmem = '0;
            decoded_instr_final[1].is_branch = '0;
            decoded_instr_final[1].is_md = '0;
            decoded_instr_final[1].wr_md = '0;
            decoded_instr_final[1].is_likely = '0;
            
            decoded_instr_final[1].rf_ctrl = '0;
            decoded_instr_final[1].alu_ctrl = '0;
            decoded_instr_final[1].mdu_ctrl = '0;
            decoded_instr_final[1].mem_ctrl = '0;
            decoded_instr_final[1].cache_op = '0;
            decoded_instr_final[1].tlb_ctrl = '0;
            decoded_instr_final[1].cp0_ctrl = '0;
            decoded_instr_final[1].trap_ctrl = '0;
            decoded_instr_final[1].bru_ctrl = `pc4_bru;
            
            decoded_instr_final[1].exc_code = exc_code;
            decoded_instr_final[1].exc_tre = tre_D;
            decoded_instr_final[1].bad_va_addr = decoded_instr[1].pc;
            decoded_instr_final[1].is_priv = 1;
        end
    end
end

//bp take non-jump instr as jump instr
function logic precheck_bp (input instr_info instr);
    if (~instr.valid || ~instr.bp_info.PC_Vaild) begin
        return 1'b0;
    end
    else if (instr.bru_ctrl != `pc4_bru) begin
        return 1'b0;
    end
    else if (instr.pc[2] && instr.bp_info.Target != instr.pc + 4 && instr.bp_info.Location) begin//mod 2023/06/30
        return 1'b1;
    end
    else if (~instr.pc[2] && instr.bp_info.Target != instr.pc + 8 && ~instr.bp_info.Location) begin//mod 2023/06/30
        return 1'b1;
    end
    return 1'b0;
endfunction

assign self_flush = bp_failed_D;
logic [1:0] precheck_failed;
always_comb begin
    precheck_failed[0] = precheck_bp(_instr_D[0]);
    precheck_failed[1] = precheck_bp(_instr_D[1]);
    ori_bp_failed_D = |precheck_failed;
    if (precheck_failed[0]) begin
        priv_instr = _instr_D[0];
        //ori_bp_failed_D = 1'b1;
        instr_D[0] = _instr_D[0];
        if (_instr_D[1].valid) begin
            if (_instr_D[1].pc == _instr_D[0].pc + 4) begin
                _correct_pc_D = _instr_D[0].pc + 8;
                instr_D[1] = _instr_D[1];
            end
            else begin
                _correct_pc_D = _instr_D[0].pc + 4;
                instr_D[1] = '0;
            end
        end
        else begin
            _correct_pc_D = _instr_D[0].pc + 4;
            instr_D[1] = '0;
        end
    end
    else if (precheck_failed[1]) begin
        priv_instr = _instr_D[1];
        //ori_bp_failed_D = 1'b1;
        _correct_pc_D = _instr_D[1].pc + 4;
        instr_D = _instr_D;
    end
    else begin
        //ori_bp_failed_D = 1'b0;
        _correct_pc_D = '0;
        instr_D = _instr_D;
        priv_instr = '0;
    end
end

assign pbp_allowin = pbp_buf_valid == 2'b00 || allowin_I;
assign bp_failed_D = pbp_buf_valid && allowin_I;
logic [31:0] correct_pc_pbp;
assign correct_pc_D = correct_pc_pbp;
always_ff @( posedge clk ) begin
    if (flush || self_flush) begin
        pbp_buf_valid <= '0;
        pbp_inst_buf <= '0;
        correct_pc_pbp <= '0;
    end
    else begin
        if (ori_bp_failed_D) begin
            pbp_inst_buf <= instr_D;
            pbp_buf_valid <= _valid_D;
            correct_pc_pbp <= _correct_pc_D;
        end
        else if (pbp_buf_valid && allowin_I) begin
            pbp_buf_valid <= '0;
            pbp_inst_buf <= '0;
            correct_pc_pbp <= '0;
        end
    end
end

always_comb begin
    instr_D_o = pbp_buf_valid ? pbp_inst_buf : instr_D;
    recover_decode.Vaild = bp_failed_D;
    recover_decode.Target = correct_pc_D;
end
endmodule
