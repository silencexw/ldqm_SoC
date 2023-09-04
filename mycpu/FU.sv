`timescale 1ns/1ps
//`include "cpu_macro.svh"
`include "InstrDefine.svh"
module FU #(
    parameter CTRL_CLO_CLZ = 1'b0
) (
    input clk,
    input reset,
    output logic stall,
    input logic stall_top,

    input logic way_num,
    
    input instr_info instr,
    input wr_reg_info wd_ori,

    //bypassing net
    output logic [5:0] reg_addr1,
    input logic [31:0] reg_data1,
    output logic [5:0] reg_addr2,
    input logic [31:0] reg_data2,

    //mdu
    output logic [3:0] mdu_op,
    output logic [31:0] mdu_srcA,
    output logic [31:0] mdu_srcB,
    output mdu_start,
    output mdu_started,
    input logic mdu_recv,
    input logic [31:0] mdu_result,
    //input logic [31:0] mdu_result_lo,

    //BRU
    output bru_info bru_res,
    output logic likely_flush,//delayslot flush caused by likely branch

    //result
    output wr_reg_info fu_wr_reg,
    output instr_info fu_instr
);
wire exec_valid = instr.valid && instr.exc_code == 0;
wire mdu_stall;
assign stall = mdu_stall;
//bypassing
assign reg_addr1 = exec_valid ? instr.rf_ctrl.rd_reg1.addr : 0;
assign reg_addr2 = exec_valid ? instr.rf_ctrl.rd_reg2.addr : 0;
wire [31:0] srcA = reg_data1;
wire [31:0] srcB = reg_data2;

wr_reg_info bru_result;
//bru
BRU bru_u(
    .instr(instr),
    .rd_reg1(srcA),
    .rd_reg2(srcB),
    .bru_res(bru_res),
    .bru_wr_reg(bru_result),
    .likely_flush
);

//alu
wire check_ov;
wire [31:0] alu_result;
wire alu_ov_result;
wire write_reg;
//assign check_ov = instr.alu_ctrl.alu_en ? (instr.opcode == 0 && (instr.funct == `add || instr.funct == `sub) || instr.opcode == `addi) : 0;
assign check_ov = instr.alu_ctrl.alu_en ? instr.alu_ctrl.check_ov : '0;
wire [31:0] unsigned_imm = {16'h0, instr.imm};
wire [31:0] signed_imm = instr.extimm;
ALU #(.CTRL_CLO_CLZ(CTRL_CLO_CLZ)) alu_u(
    .a(instr.alu_ctrl.src_a ? instr.s : srcA),
    .b(instr.alu_ctrl.src_b ? (instr.alu_ctrl.sign_b ? instr.extimm : unsigned_imm) : srcB),
    .ALUControl(instr.alu_ctrl.alu_en ? instr.alu_ctrl.alu_op : '0),
    .ALUResult(alu_result),
    .OvCtrl(check_ov),
    .ov(alu_ov_result),
    .WrCtrl(instr.opcode == '0 && (instr.funct == `movn || instr.funct == `movz)),
    .write_reg
);

//mdu
wire is_mul;
//assign is_mul = instr.opcode == `SPECIAL2 && instr.funct == `mul;
assign is_mul = instr.mdu_ctrl.mdu_en && instr.mdu_ctrl.mdu_op == `MUL;
wire read_mdu;
assign read_mdu = instr.mdu_ctrl.mdu_en && (instr.mdu_ctrl.mdu_op == `MFHI || instr.mdu_ctrl.mdu_op == `MFLO);
logic [1:0] mdu_complete;
//assign mdu_start = instr.mdu_ctrl.mdu_en && exec_valid/* && ~reset */&& ~stall_top;
assign mdu_start = instr.mdu_ctrl.mdu_en && exec_valid && (mdu_complete == 2'b00 || read_mdu);
assign mdu_op = instr.mdu_ctrl.mdu_op;
assign mdu_srcA = srcA;
assign mdu_srcB = srcB;
//assign mdu_stall = instr.mdu_ctrl.mdu_en && exec_valid && !mdu_recv;
//assign mdu_stall = instr.mdu_ctrl.mdu_en && exec_valid && !mdu_recv && !mdu_complete;
assign mdu_stall = !instr.mdu_ctrl.mdu_en || !exec_valid ? 1'b0 : 
                    !is_mul ? !mdu_recv && mdu_complete != 2'b10 : 
                    !(mdu_complete == 2'b01 && mdu_recv || mdu_complete == 2'b10);
/*
always_ff @(posedge clk) begin
    if (reset) begin
        mdu_complete <= '0;
    end
    else begin
        if (mdu_start && mdu_recv && stall_top) begin
            mdu_complete <= 1'b1;
        end
        else if (mdu_complete && ~stall_top) begin
            mdu_complete <= '0;
        end
    end
end
*/
always_ff @(posedge clk) begin
    if (reset) begin
        mdu_complete <= '0;
    end
    else begin
        case (mdu_complete)
            2'b00: begin
                mdu_complete <= mdu_start && mdu_recv && stall_top ? (!is_mul ? 2'b10 : 2'b01) : 
                                mdu_start && mdu_recv && ~stall_top ? (!is_mul ? 2'b00 : 2'b01) : 
                                2'b00;
            end
            2'b01: begin
                mdu_complete <= mdu_recv && stall_top ? 2'b10 : 
                                mdu_recv && ~stall_top ? 2'b00 : 
                                2'b01;
            end
            2'b10: begin
                mdu_complete <= ~stall_top ? 2'b00 : 2'b10;
            end
        endcase
    end
end

assign mdu_started = instr.mdu_ctrl.mdu_en && !read_mdu && mdu_complete != 2'b00;

wire [31:0] result = instr.alu_ctrl.alu_en ? alu_result : 
                     instr.mdu_ctrl.mdu_en ? /*(!is_mul ? mdu_result : mdu_result_lo)*/mdu_result : 
                     bru_result.data;

// generate wr_reg_info which is used in bypassing net
logic [2:0] exec_Tnew;
always_comb begin
    //fu_wr_reg.addr = ~reset && (instr.exc_code == `Int || alu_ov_result) ? instr.rf_ctrl.wr_reg.addr : 0;
    fu_wr_reg.addr = reset ? '0 : 
                     instr.exc_code != `Int ? '0 : 
                     instr.alu_ctrl.alu_en && alu_ov_result ? '0 : 
                     instr.alu_ctrl.alu_en && ~write_reg ? '0 : 
                     wd_ori.addr;
                     
    fu_wr_reg.data = result;
    /*
    exec_Tnew = (instr.opcode == 0 && instr.funct >= `sll && instr.funct <= `srav) ? 1 : 
                     (instr.opcode == 0 && instr.funct >= `add && instr.funct <= `sltu) ? 1 : 
                     (instr.opcode == 0 && instr.funct == `jalr || instr.funct == `mfhi || instr.funct == `mflo) ? 1 : 
                     (instr.opcode == 0) ? `NOT_WRITE : 
                     (instr.opcode >= `RT && (instr.code[20:16] == `bltzal || instr.code[20:16] == `bgezal)) ? 1 : 
                     (instr.opcode == `jal) ? 1 : 
                     (instr.opcode >= `addi && instr.opcode <= `lui) ? 1 : 
                     (instr.opcode >= `lb && instr.opcode <= `lw) ? `MEM_GEN : 
                     (instr.opcode == `RS && instr.code[25:21] == `mfc0) ? `CP0_GEN : 
                     `NOT_WRITE;*/
    fu_wr_reg.Tnew = instr.alu_ctrl.alu_en && write_reg && wd_ori.Tnew != `MEM_GEN ? '0 :  //not delay exec 
                     wd_ori.Tnew > 0 ? wd_ori.Tnew - 1 : wd_ori.Tnew;
    
    if (reset) begin
        fu_instr = '0;
    end
    else if (instr.exc_code == `Int && alu_ov_result/* || reset */|| instr.alu_ctrl.alu_en && ~write_reg) begin
        fu_instr = instr;
        fu_instr.rf_ctrl.wr_reg.addr = 0;
        fu_instr.exc_code = /*reset ? `Int : */
                            instr.exc_code != `Int ? instr.exc_code : 
                            instr.exc_code == `Int && alu_ov_result ? `Ov : 
                            `Int;
        fu_instr.is_accmem = 0;
        fu_instr.is_priv = /*reset || */instr.alu_ctrl.alu_en && ~write_reg ? 0 : 1;
    end
    else begin
        fu_instr = instr;
    end
end
endmodule
