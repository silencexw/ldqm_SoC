//this is an IFU used in start os
`include "TLB_defs.svh"
//`include "cpu_macro.svh"
`include "Predict_defs.svh"
`timescale 1ns / 1ps

`define SINGLE 1'b0
`define DOUBLE 1'b1

module InstrFetchUnit_5_2 (
    input           clk,
    input           reset,
    input           stall,
    output          preIF_stall,
    
    //from icache
    output          inst_req,
    output [31:0]   inst_addr4,
    output [1:0]    inst_size,
    output          inst_cached,
    input           inst_addr_ok,
    input           inst_data_ok,
    input [63:0]    inst_rdata,
    
    input Predict_Branch_S bp_info,
    output [31:0]    Now_PC,
    
    //from BRU of FU
    input           bp_failed,
    input  [31:0]   correct_pc,
    
    //from CP0
    input           eret_valid,
    input [31:0]    eret_pc,
    
    //from CP0
    input           exc_valid,
    input [31:0]    exc_pc,
    
    //icache instruction need to flush pipeline
    input           icache_inst_valid,
    input  [31:0]   icache_inst_npc,
    
    //to decoder
    output [1:0]    valid_F,
    output [63:0]   instr_F,
    output [31:0]   pc_F,
    output [4:0]    exc_code_F,
    output          tre_F,
    output Predict_Branch_S [1:0] bp_info_F,
    input           allowin_D,

    //to TLB
    output  TLB_Search_In   tlb_search,
    input   TLB_Search_Out  tlb_info
);

//var declarations
//preIF:
//branch prediction jump:
Predict_Branch_S bp_info_preIF;
Predict_Branch_S bp_info_s;
logic [31:0] bp_info_pc;
logic [31:0] _bp_info_pc;
logic [1:0] bp_info_valid_preIF;
logic [1:0] _bp_info_valid_preIF;

wire [1:0] bp_jump; //branch predict jump at 'nPC'
wire [31:0] bp_jump_target;
wire [1:0] bp_jump_valid;

logic update;
wire update_bp;

logic ds_preIF;

//delayslot of bp jump:
wire [1:0] ds_jump;
wire [1:0] ds_valid;
logic [31:0] ds_jump_target;
wire ds_jump_ready;
logic _ds_jump_ready;

//special jump:
/*(*mark_debug = "true"*)*/wire sp_jump;
/*(*mark_debug = "true"*)*/wire [31:0] sp_jump_target;
wire [1:0] sp_jump_valid;
wire wait_sp;
logic _sp_jump;

//non jump:
wire [31:0] non_jump_target;
wire [1:0] non_jump_valid;
wire wait_nonjump;
logic _non_jump;

//preIF fetch req:
logic p_reset;
/*(*mark_debug = "true"*)*/wire allowin_preIF;
/*(*mark_debug = "true"*)*/wire ready_go_preIF;
wire inst_req_mode;
logic [1:0] valid_preIF;
logic [31:0] PC_preIF;
wire [1:0] valid_preIF_f;
logic accept_bp;
/*(*mark_debug = "true"*)*/wire [31:0] inst_addr_v;

//AT address translate
/*(*mark_debug = "true"*)*/wire [31:0] inst_addr;
wire allowin_AT;
wire ready_go_AT;
wire [4:0] exc_code_AT;
logic [1:0] valid_AT;
logic [31:0] pc_AT;
TLB_Search_Out _at_info_AT, at_info_AT;
logic update_at_info;

//IF get instr:
logic addr_rcv;

wire allowin_IF;
logic [1:0] bp_jump_IF;
wire inst_recv_mode;
logic update_bp_IF;
Predict_Branch_S bp_info_IF;
Predict_Branch_S _bp_info_IF;
logic [31:0] PC_IF;
logic [1:0] valid_IF;
logic [4:0] exc_code_IF;
logic [4:0] tre_IF;

logic intercept;
logic save;
logic [63:0] save_instr_IF;
logic [63:0] save_inst_rdata;

//functions declarations:
function logic is_kseg1(input logic [31:0] inst_addr);
    return inst_addr[31:28] == 4'ha || inst_addr[31:28] == 4'hb;
    //return 1'b0;
endfunction

function logic is_kseg0(input logic [31:0] addr);
    return addr[31:28] == 4'h8 || addr[31:28] == 4'h9;
endfunction

function logic is_map(input logic [31:0] inst_addr);
    return !is_kseg0(inst_addr) && !is_kseg1(inst_addr);
endfunction

function logic [31:0] align4(input logic [31:0] inst_addr);
    return inst_addr;
endfunction

function logic [31:0] align8(input logic [31:0] inst_addr);
    return {inst_addr[31:3], 1'b0, inst_addr[1:0]};
endfunction

assign Now_PC = inst_addr_v;

//deal with branch prediction
assign update_bp = bp_jump && ds_jump ? 1'b0 : 
                   allowin_preIF;
always_ff @(posedge clk) begin
    update <= sp_jump ? 1'b1 : 
              update_bp;
    bp_info_s <= sp_jump ? '0 : 
                 update ? bp_info : bp_info_s;
    _bp_info_pc <= update ? inst_addr_v : _bp_info_pc;
    _bp_info_valid_preIF <= update ? valid_preIF_f : _bp_info_valid_preIF;
end
assign bp_info_preIF = update ? bp_info : bp_info_s;
assign bp_info_pc = update ? Now_PC : _bp_info_pc;
assign bp_info_valid_preIF = update ? valid_preIF_f : _bp_info_valid_preIF;
assign bp_jump =  ~bp_info_preIF.PC_Vaild ? 2'b00 : 
                  bp_info_preIF.Target == bp_info_pc + 8 ? 2'b00 :
                  bp_info_preIF.Location ? (2'b10 & bp_info_valid_preIF) : (2'b01 & bp_info_valid_preIF);

assign bp_jump_target = bp_info_preIF.Target;
assign bp_jump_valid = bp_jump_target[2] ? 2'b10 : 
                        is_kseg1(bp_jump_target) ? 2'b01 : 
                        2'b11;

assign ds_jump = bp_jump && 
                  (is_kseg1(bp_info_pc) ? 1'b1 : (bp_jump == 2'b10 && bp_info_valid_preIF[1] || bp_jump == 2'b01 && bp_info_valid_preIF == 2'b01)) && 
                  ~ds_jump_ready;
assign ds_valid = bp_jump == 2'b10 ? 2'b01 : 2'b10;
assign ds_jump_target = bp_jump == 2'b10 ? bp_info_pc + 8 : bp_info_pc;
assign ds_jump_ready = _ds_jump_ready;

always_ff @(posedge clk) begin
    if (sp_jump) begin
        _ds_jump_ready <= 1'b0;
    end
    else if (_ds_jump_ready == 1'b0 && bp_jump && ds_jump) begin
        _ds_jump_ready <= ready_go_preIF && allowin_AT ? 1'b1 : _ds_jump_ready;
    end
    else begin
        _ds_jump_ready <= update_bp ? 1'b0 : _ds_jump_ready;
    end
end

//deal with special jump: exception, eret, bp failed jump

assign sp_jump = reset | exc_valid | eret_valid | bp_failed | icache_inst_valid;

assign sp_jump_target = reset ? `RESET_HANDLER : 
                      exc_valid ? exc_pc : 
                      icache_inst_valid ? icache_inst_npc : 
                      eret_valid ? eret_pc : 
                      bp_failed ? correct_pc : '0;

assign sp_jump_valid = sp_jump_target[2] ? 2'b10 : 
                        is_kseg1(sp_jump_target) ? 2'b01 : 
                        2'b11;
assign wait_sp = _sp_jump;
always_ff @(posedge clk) begin
    _sp_jump <= /*reset ? 1'b0 : */
                sp_jump ? 1'b1 : 
                _sp_jump && allowin_preIF ? 1'b0 : 
                _sp_jump;
end

//non jump just pc + 4 or pc + 8

assign non_jump_target = is_kseg1(inst_addr_v) ? (valid_preIF_f[1] ? inst_addr_v + 8 : inst_addr_v) : 
                          inst_addr_v + 8;

assign non_jump_valid = is_kseg1(inst_addr_v) ? (valid_preIF_f[1] ? 2'b01 : 2'b10) : 
                         2'b11;
assign wait_nonjump = _non_jump;
always_ff @(posedge clk) begin
    if (~sp_jump && ~wait_sp && bp_jump == 2'b00 && ~allowin_preIF) begin
        _non_jump <= 1'b1;
    end
    else if (_non_jump && allowin_preIF) begin
        _non_jump <= 1'b0;
    end
end                

//pre-IF


//assign inst_req_mode = is_kseg1(inst_addr) ? `SINGLE : `DOUBLE;

/*assign valid_preIF_f = bp_jump && ds_jump ? ds_valid : 
                        bp_jump ? bp_jump_valid : valid_preIF;*/
assign valid_preIF_f = valid_preIF;
                        
/*assign inst_addr_v = bp_jump && ds_jump && ~p_reset ? align8(ds_jump_target) : 
                    bp_jump && ~p_reset ? align8(bp_jump_target) : PC_preIF;*/
assign inst_addr_v = PC_preIF;

//assign inst_size = inst_req_mode == `DOUBLE ? 2'b10 : 2'b01;
assign tlb_search.vaddr = inst_addr_v;
assign tlb_search.ce = |valid_preIF_f;

assign allowin_preIF = (|valid_preIF_f && allowin_AT && ready_go_preIF || valid_preIF_f == 2'b00);
assign ready_go_preIF = |valid_preIF_f;
assign preIF_stall = |valid_preIF_f && !(ready_go_preIF && allowin_AT);

always_ff @(posedge clk) begin
    p_reset <= reset;
    if (reset) begin
        PC_preIF <= `RESET_HANDLER;
        valid_preIF <= 2'b01;
        ds_preIF <= 1'b0;
    end
    else if (sp_jump) begin
        PC_preIF <= align8(sp_jump_target);
        valid_preIF <= sp_jump_valid;
        ds_preIF <= 1'b0;
    end
    else if (allowin_preIF) begin
        if (bp_jump) begin
            if (ds_jump) begin
                PC_preIF <= align8(ds_jump_target);
                valid_preIF <= ds_valid;
                ds_preIF <= 1'b1;
            end
            else begin
                PC_preIF <= align8(bp_jump_target);
                valid_preIF <= bp_jump_valid;
                ds_preIF <= 1'b0;
            end
        end
        else begin
            PC_preIF <= align8(non_jump_target);
            valid_preIF <= non_jump_valid;
            ds_preIF <= 1'b0;
        end
    end
end

//AT class
wire uncache_jump;
wire [31:0] uncache_jump_target;
assign ready_go_AT = valid_AT && inst_req && inst_addr_ok || valid_AT && exc_code_AT;
assign allowin_AT = (valid_AT == 2'b00 || ready_go_AT && allowin_IF) && !uncache_jump;
assign at_info_AT = update_at_info ? tlb_info : _at_info_AT;
always_ff @(posedge clk) begin
    _at_info_AT <= update_at_info ? tlb_info : 
                    _at_info_AT;
end

assign uncache_jump = !(|exc_code_AT) && (&valid_AT) && !inst_cached;
assign uncache_jump_target = pc_AT + 4;

assign exc_code_AT = valid_AT == 2'b00 ? '0 : 
                      pc_AT[1:0] != 2'b00 ? `AdEL : 
                      at_info_AT.error ? `AdEL : 
                      ~at_info_AT.v || ~at_info_AT.hit ? `TLBL : 
                      `Int;
wire tre_AT = exc_code_AT == `TLBL && ~at_info_AT.hit;
assign inst_req_mode = !at_info_AT.cached ? `SINGLE : `DOUBLE;
assign inst_addr = at_info_AT.paddr;
assign inst_addr4 = at_info_AT.cached ? inst_addr : 
                    valid_AT[0] ? inst_addr : 
                    valid_AT[1] ? inst_addr + 4 : inst_addr;
assign inst_size = inst_req_mode == `DOUBLE ? 2'b11 : 2'b10;
assign inst_cached = at_info_AT.cached;

wire [1:0] valid_AT_f;
assign valid_AT_f = uncache_jump ? 2'b01 : valid_AT;
always_ff @(posedge clk) begin
    if (sp_jump) begin
        valid_AT <= '0;
        pc_AT <= '0;
        update_at_info <= '0;
    end
    else begin
        if (allowin_AT) begin
            valid_AT <= valid_preIF_f;
            pc_AT <= inst_addr_v;
            update_at_info <= 1'b1;
        end
        else if (ready_go_AT && allowin_IF) begin
            valid_AT <= 2'b10;
            pc_AT <= pc_AT;
            update_at_info <= 1'b0;
        end
        else begin
            update_at_info <= '0;
        end
    end
end

Predict_Branch_S bp_info_AT, _bp_info_AT;
Predict_Branch_S bp_info_AT_f;
logic update_bp_AT;
assign bp_info_AT = _bp_info_AT;
assign bp_info_AT_f = exc_code_AT == `Int && !intercept ? bp_info_AT : '0;

always_ff @(posedge clk) begin
    _bp_info_AT <=  sp_jump ? '0 : 
                    allowin_AT ? (ds_preIF ? '0 : bp_info_preIF) : _bp_info_AT;
end

//logic addr_rcv;
always_ff @( posedge clk ) begin
    addr_rcv <= reset ? 1'b0 : 
                ~addr_rcv && inst_req && inst_addr_ok ? 1'b1 : 
                addr_rcv && inst_data_ok ? 1'b0 : addr_rcv;
end

//IF class
//assign inst_req = allowin_IF && ~stall && ~reset && ~exc_valid && ~eret_valid && ~bp_failed; //add '~bpu_stall'
//assign inst_req = allowin_IF && ~stall && ~sp_jump && exc_code_AT == `Int && |valid_AT;
assign inst_req = (allowin_D || valid_IF == 2'b00) && !intercept && ~stall && ~sp_jump && exc_code_AT == `Int && |valid_AT;
assign ready_go_IF = inst_data_ok || save || exc_code_IF != `Int;
assign allowin_IF = (ready_go_IF && allowin_D || valid_IF == 2'b00) && !intercept;

assign valid_F[0] = valid_IF[0] && ready_go_IF && !intercept && !sp_jump;
assign valid_F[1] = valid_IF[1] && ready_go_IF && !intercept && !sp_jump;
/*
assign bp_info_IF = intercept ? '0 :     
                     //update_bp_IF ? (bp_jump && ds_jump ? '0 : bp_info_preIF) : 
                     update_bp_IF ? bp_info_preIF :
                     _bp_info_IF;*/
assign bp_info_F[0] = ~valid_F[0] ? '0 : 
                       //bp_info_IF.Location ? '0 : bp_info_IF;
                       bp_info_IF;
assign bp_info_F[1] = ~valid_F[1] ? '0 : 
                        //~bp_info_IF.Location ? '0 : bp_info_IF;
                        bp_info_IF;
/*
always_ff @(posedge clk) begin
    update_bp_IF <= sp_jump ? 1'b0 : 
                    //allowin_IF && update_bp;
                    allowin_IF && update_bp ? ((bp_jump && ds_jump) ? 1'b0 : 1'b1) : 1'b0;
    _bp_info_IF <= allowin_IF ? (bp_jump && ds_jump ? '0 : bp_info_preIF) : 
                   update_bp_IF ? bp_info_preIF : 
                                _bp_info_IF;
end
*/
assign pc_F = PC_IF;
assign instr_F = {(valid_F[1] ? (save ? save_inst_rdata[63:32] : inst_rdata[63:32]) : 32'h0), (valid_F[0] ?(save ? save_inst_rdata[31:0] : inst_rdata[31:0]) : 32'h0)};
assign inst_recv_mode = is_kseg1(PC_IF) ? `SINGLE : `DOUBLE;

assign exc_code_F = |valid_F ? exc_code_IF : '0;
assign tre_F = |valid_F ? tre_IF : '0;
always_ff @(posedge clk) begin
    if (reset) begin
        intercept <= 1'b0;
        save <= 1'b0;
        valid_IF <= 2'b00;
        PC_IF <= `RESET_HANDLER;
    end
    else begin
        if (~intercept && (exc_valid | eret_valid | bp_failed | icache_inst_valid) && (ready_go_AT && exc_code_AT == '0 || addr_rcv) && ~ready_go_IF) begin
            intercept <= 1'b1;
        end
        else if (intercept && ready_go_IF/* && allowin_D*/) begin
            intercept <= 1'b0;
        end
        
        if (exc_valid | eret_valid | bp_failed | icache_inst_valid) begin
            valid_IF <= 2'b00;
            exc_code_IF <= '0;
            tre_IF <= '0;
        end
        else if (allowin_IF) begin
            if (ready_go_AT) begin
                valid_IF <= valid_AT_f;
                PC_IF <= pc_AT;
                exc_code_IF <= exc_code_AT;
                tre_IF <= tre_AT;
                bp_info_IF <= bp_info_AT_f;
            end
            else begin
                valid_IF <= 2'b00;
            end
        end
        
        if (ready_go_IF) begin
            if (exc_valid | eret_valid | bp_failed | icache_inst_valid) begin
                save <= 1'b0;
            end
            else if (allowin_D) begin
                save <= save ? 1'b0 : save;
            end
            else begin
                save_inst_rdata <= ~save ? inst_rdata : save_inst_rdata;
                save <= 1'b1;
            end
        end
    end
end

endmodule
