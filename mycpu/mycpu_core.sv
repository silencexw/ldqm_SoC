`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/04/16 09:15:49
// Design Name: 
// Module Name: mycpu_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/*

*/
`include "InstrDefine.svh"
`include "cpu_macro.svh"
`define _MEM_DEBUG
`define MONITOR_VADDR 32'h1fc1a460
//`default_nettype none

module mycpu_core #(
    parameter CTRL_CLO_CLZ = 1'b0,
    parameter CTRL_TRAP_UNIT = 1'b0,
    parameter CTRL_USE_XPM_CPC = 1'b1,
    parameter CTRL_EXTEND_INST_SET = 1'b0
) (
    input logic [5:0] ext_int,
    
    input wire clk,
    input wire resetn,
    
    output logic inst_req,
    output logic inst_wr,
    output logic [1:0] inst_size,
    output logic [31:0] inst_addr,
    output logic [31:0] inst_wdata,
    output logic        inst_cached,
    input wire [63:0] inst_rdata,
    input wire inst_addr_ok,
    input wire inst_data_ok,
    
    output logic data_req,
    output logic data_wr,
    output logic [1:0] data_size,
    output logic [3:0] data_wstrb,
    output logic [31:0] data_addr,
    output logic        data_cached,
    output logic [31:0] data_wdata,
    input wire [31:0] data_rdata,
    input wire data_addr_ok,
    input wire data_data_ok,
    
    output logic        dcache_valid,
    output logic        dcache_op,
    output logic        dcache_wb,
    
    output logic        icache_valid,
    output logic        icache_op,
    
    //tlb output and input
    output  TLB_Search_In   inst_tlb_search,
    input   TLB_Search_Out  inst_tlb_info,
    output  TLB_Search_In   data_tlb_search,
    input   TLB_Search_Out  data_tlb_info,
    output  wire   cp0_km,
    output  wire   cp0_erl,
    output  wire   cp0_kseg0_cached,
    output  wire   tlb_wr,
    output [31:0] cp0_TagLo0_o,
	output [31:0] cp0_EntryHi_o,
	output [31:0] cp0_EntryLo0_o,
	output [31:0] cp0_EntryLo1_o,
	output [11:0] cp0_PageMask_o,
	output [31:0] cp0_TLB_Index_o,
	input  [31:0]  cp0_EntryLo0_i,
	input  [31:0]  cp0_EntryLo1_i,
	input  [31:0]  cp0_EntryHi_i,
	input  [11:0]  cp0_PageMask_i,
	input  [31:0]  cp0_Index_i,
	
//`ifdef USE_SIMULATOR
    output logic [31:0] debug_cp0_count,
    output [31:0]   debug_cp0_random,// cp0_random used in TLBWR
    output [31:0]   debug_cp0_cause, // cp0_cause for rising interrupts and mfc0
    output          debug_int,       
    output          debug_commit,
//`endif
    output logic [31:0] debug_wb_pc,
    output logic [3:0] debug_wb_rf_wen,
    output logic [4:0] debug_wb_rf_wnum,
    output logic [31:0] debug_wb_rf_wdata
);
`ifdef MEM_DEBUG
integer mem_trace;
always_ff @(posedge clk) begin
    if (~resetn) begin
        mem_trace = $fopen("mem_trace.txt", "w");
    end
    else begin
        if (data_req && data_addr_ok && data_addr == `MONITOR_VADDR) begin
            if (data_wr) begin
                $fdisplay(mem_trace, "[%t] write %x at %x", $time, data_wdata, data_addr);
            end
            else begin
                $fdisplay(mem_trace, "[%t] read %x", $time, data_addr);
            end
        end
    end
end
`endif

function wr_reg_info next_wd(input wr_reg_info wd);
    wr_reg_info ret_wd;
    ret_wd.addr = wd.addr;
    ret_wd.data = wd.data;
    ret_wd.Tnew = wd.Tnew ? wd.Tnew - 1 : wd.Tnew;
    return ret_wd;
endfunction

function wr_reg_info [1:0] next_wd_double(input wr_reg_info [1:0] wd);
    return {next_wd(wd[1]), next_wd(wd[0])};
endfunction

wire preIF_stall;
wire [1:0] valid_F;
wire [63:0] instr_F;
wire [31:0] pc_F;
wire bp_fail;
wire bp_failed_D;
Update_Branch_S bp_verify;
Update_Branch_S bp_verify_D;
wire [31:0] eret_pc;
wire exception;
/*(*mark_debug = "true"*)*/wire exception_int;
logic eret_jump;
//assign inst_size = 2'b11;
assign inst_wr = 1'b0;
assign inst_wdata = 32'h0;
wire stall_D;
Predict_Branch_S [1:0] bp_info_F;

wire [31:0] Now_PC;
Predict_Branch_S bp_info;
wire update_valid;

wire bpu_stall = preIF_stall && ~bp_fail && ~bp_failed_D;
logic bpu_stall_d;
Recover_Decode_S recover_decode;
always_ff @(posedge clk) begin
    if (~resetn) begin
        bpu_stall_d <= '0;
    end
    else begin
        bpu_stall_d <= bpu_stall;
    end
end
Branch_Predict bpu_core(
    .clk,
    .reset(~resetn),
    .stall(bpu_stall_d),
    .Now_PC,
    .Recover_Decode(bp_failed_D ? recover_decode : '0),
    .Update_Predict(bp_verify),
    .Predict_Branch(bp_info)
);



//Branch_Predictor_Fake bpu_core_f(
//    .clk,
//    .reset(~resetn),
//    .Now_PC,
//    .Predict_Branch(bp_info)
//);
wire [31:0] correct_pc_D;
wire [4:0] exc_code_F;
wire       tre_F;
/*(*mark_debug = "true"*)*/wire [31:0] exc_handler;

//icache instruction's influence
wire icache_valid_req;
wire icache_op_req;
wire [31:0] icache_addr_req;
wire        icache_cached_req;
wire [31:0] icache_npc_req;
logic _icache_valid_req;
logic _icache_op_req;
logic [31:0] _icache_addr_req;
logic [31:0] _icache_cached_req;
logic [31:0] _icache_npc_req;

wire fetch_inst_req;
wire [31:0] fetch_inst_addr;
wire        fetch_inst_cached;
wire fetch_inst_addr_ok;

wire icache_occupied;
logic _icache_occupied;
assign icache_occupied = icache_valid_req || _icache_occupied;
always_ff @(posedge clk) begin
    if (~resetn) begin
        _icache_occupied <= '0;
        _icache_valid_req <= '0;
        _icache_op_req <= '0;
        _icache_addr_req <= '0;
        _icache_cached_req <= '0;
        _icache_npc_req <= '0;
    end
    else begin
        if (~_icache_occupied) begin
            _icache_occupied <= icache_valid_req && ~inst_addr_ok ? 1'b1 : 
                                1'b0;
            _icache_valid_req <= icache_valid_req && ~inst_addr_ok ? 1'b1 : 
                                1'b0;
            _icache_op_req <= icache_valid_req && ~inst_addr_ok ? icache_op_req : 1'b0;
            _icache_addr_req <= icache_valid_req && ~inst_addr_ok ? icache_addr_req : '0;
            _icache_cached_req <= icache_valid_req && ~inst_addr_ok ? icache_cached_req : '0;
        end
        else begin
            _icache_occupied <= inst_addr_ok ? 1'b0 : 1'b1;
        end
    end
end

assign inst_addr = icache_valid_req ? icache_addr_req : 
                    _icache_occupied ? _icache_addr_req : 
                    fetch_inst_addr;
assign inst_cached = icache_valid_req ? icache_cached_req : 
                    _icache_occupied ? _icache_cached_req : 
                    fetch_inst_cached;
assign inst_req = icache_occupied ? 1'b1 :  
                   fetch_inst_req;
assign fetch_inst_addr_ok = icache_occupied ? 1'b0 : 
                             inst_addr_ok;
assign icache_op = icache_valid_req ? icache_op_req : 
                    _icache_occupied ? _icache_op_req : 
                    1'b0;
assign icache_valid = icache_occupied;

InstrFetchUnit_5_2 ifu_core(
    .clk,
    .reset(~resetn),
    .stall(stall_D),
    .preIF_stall,
    
    .Now_PC,
    .bp_info(bp_info),

    .inst_req(fetch_inst_req),
    .inst_addr4(fetch_inst_addr),
    .inst_size,
    .inst_cached(fetch_inst_cached),
    .inst_addr_ok(fetch_inst_addr_ok),
    .inst_data_ok,
    .inst_rdata,

    //.is_jump(2'b00),//before add branch prediction
    //.jump_target(),
    
    .bp_failed(bp_fail ? 1'b1 : bp_failed_D),
    .correct_pc(bp_fail ? bp_verify.Update_Target : correct_pc_D),

    .eret_valid(eret_jump),
    .eret_pc,

    .exc_valid(exception | exception_int),
    //.exc_pc(32'hbfc00380), //for func test
    .exc_pc(exc_handler),//system
    
    .icache_inst_valid(icache_valid_req),
    .icache_inst_npc(icache_npc_req),

    .valid_F,
    .instr_F,
    .pc_F,
    .bp_info_F,
    .exc_code_F,
    .tre_F,
    .allowin_D,
    
    .tlb_search(inst_tlb_search),
    .tlb_info(inst_tlb_info)
);
//assign exc_code_F[4:0] = pc_F[1:0] != 2'b00 ? `AdEL : 0;

//decode class
wire allowin_D;
wire decode_flush;
assign decode_flush = ~resetn | bp_fail | exception | exception_int | eret_jump | icache_valid_req;
instr_info [1:0] instr_D;
wire [1:0] valid_D;
wire allowin_I;
assign stall_D = ~allowin_I;
//wire [31:0] correct_pc_D;
DecodeUnit_3 #(.CTRL_EXTEND_INST_SET(CTRL_EXTEND_INST_SET)) decode_core(
    .clk,
    .flush(decode_flush),
    .stall(~allowin_I),
    .exc_code_F,
    .tre_F,

    .allowin_D,
    .allowin_I,
    
    .instr_F,
    .valid_F,
    .pc_F,
    .bp_info_F,

    .valid_D,
    .instr_D_o(instr_D),
    
    .bp_failed_D,
    .correct_pc_D,
    //.bp_verify_D
    .recover_decode
);

//issue class
lrf_addr rd_reg1_addr0, rd_reg2_addr0, rd_reg1_addr1, rd_reg2_addr1;
lrf_data rd_reg1_data0, rd_reg2_data0, rd_reg1_data1, rd_reg2_data1;
lrf_data highReg, lowReg;
wire wen0, wen1;
wire [4:0] wr_addr0;
wire [4:0] wr_addr1;
wire [31:0] wr_data0;
wire [31:0] wr_data1;
LRF lrf_core(
    .clk,
    .resetn,
    .rs_addr0(rd_reg1_addr0),
    .rs_data0(rd_reg1_data0),
    .rt_addr0(rd_reg2_addr0),
    .rt_data0(rd_reg2_data0),

    .rs_addr1(rd_reg1_addr1),
    .rs_data1(rd_reg1_data1),
    .rt_addr1(rd_reg2_addr1),
    .rt_data1(rd_reg2_data1),

    .wen0,
    .wr_addr0,
    .wr_data0,

    .wen1,
    .wr_addr1,
    .wr_data1,

    .hi(highReg),
    .lo(lowReg)
);

wire issue_flush;
wr_reg_info [1:0] wd_0;
wr_reg_info [1:0] wd_1;
wr_reg_info [1:0] wd_2;
wr_reg_info [1:0] wd_3;
wr_reg_info [1:0] wd_4;
instr_info instr0_I, instr1_I;
/*(*mark_debug = "true"*)*/wire way0_valid;
/*(*mark_debug = "true"*)*/wire way1_valid;
lrf_data [1:0] issue_reg1_data_f;
lrf_data [1:0] issue_reg2_data_f;

wire exec_stall;
//wire exec_stall_inclass; //stall signal generated from this class, same as dreq/mem
wr_reg_info [1:0] wd_ori;
//wire issue_flush;
assign issue_flush = ~resetn | bp_fail | exception | exception_int | eret_jump | icache_valid_req;
IssueUnit_2 issue_core(
    .clk,
    .flush(issue_flush),
    .stall(exec_stall),

    .allowin_I,
    .valid_D(valid_D),
    .instr_D(instr_D),

    //read logic register file
    .rd_reg1_addr0,
    .rd_reg2_addr0,
    .rd_reg1_addr1,
    .rd_reg2_addr1,

    .rd_reg1_data0,
    .rd_reg2_data0,
    .rd_reg1_data1,
    .rd_reg2_data1,

    //bypassing net
    .wd_ori,
    .wd_0,
    .wd_1,
    .wd_2,
    .wd_3,
    .wd_4,

    //send to exec class
    .way0_valid,
    .instr0_I,
    .way1_valid,
    .instr1_I,

    .reg_data1(issue_reg1_data_f),
    .reg_data2(issue_reg2_data_f)
);
//top signals for exec, dreq, mem, wb class

//stall signal of exec and after class:
/*(*mark_debug = "true"*)*/wire exec_stall_inclass;
wire exec_stall_top; //outside stall
/*(*mark_debug = "true"*)*/wire dreq_stall_inclass; //stall signal generated from dreq class
/*(*mark_debug = "true"*)*/wire mem_stall_inclass; //stall signal generated from mem class
/*(*mark_debug = "true"*)*/wire wb_stall_inclass;

//exec class
// pipeline
wire way0_stall, way1_stall; //inside stall
//wire exec_stall; //final stall
wire exec_flush;
wire allowin_exec;
logic [1:0] exec_valid;
instr_info [1:0] fu_instr_res;
instr_info [1:0] exec_instr;
instr_info_at [1:0] exec_instr_o;
wire dreq_stall;
wire wb_stall;

assign exec_flush = ~resetn | bp_fail | exception | exception_int | eret_jump | icache_valid_req;
//assign exec_stall_top = dreq_stall;
assign exec_stall_top = dreq_stall_inclass || mem_stall_inclass
`ifdef COMMIT_QUEUE
 || wb_stall_inclass
 `endif
 ;
assign exec_stall_inclass = way0_stall | way1_stall;
//2023/7/6
assign exec_stall = exec_stall_inclass | exec_stall_top;
//assign exec_stall = stall_top;
assign allowin_exec = !exec_stall;
lrf_data [1:0] exec_reg1_data_i;
lrf_data [1:0] exec_reg2_data_i;

always_ff @( posedge clk ) begin
    if (exec_flush) begin
        exec_valid <= '0;
        exec_instr <= '0;
        exec_reg1_data_i <= '0;
        exec_reg2_data_i <= '0;
        wd_0 <= '0;
    end
    else if (!exec_stall) begin
        exec_valid <= {way1_valid, way0_valid};
        exec_instr[0] <= way0_valid ? instr0_I : '0;
        exec_instr[1] <= way1_valid ? instr1_I : '0;
        exec_reg1_data_i <= issue_reg1_data_f;
        exec_reg2_data_i <= issue_reg2_data_f;
        wd_0[0] <= way0_valid ? wd_ori[0] : '0;
        wd_0[1] <= way1_valid ? wd_ori[1] : '0;
    end
end

wire [3:0] mdu_op [1:0];
wire [31:0] mdu_srcA [1:0];
wire [31:0] mdu_srcB [1:0];
wire [1:0] mdu_start;
wire [1:0] mdu_recv;
wire [31:0] mdu_result;

bru_info [1:0] bru_res;
lrf_data [1:0] exec_reg1_data_f_t; //intime value
lrf_data [1:0] exec_reg2_data_f_t;
lrf_data [1:0] save_exec_reg1_data_f; //save value
lrf_data [1:0] save_exec_reg2_data_f;
lrf_data [1:0] exec_reg1_data_f; //final forward value
lrf_data [1:0] exec_reg2_data_f;
wr_reg_info [1:0] fu_wd;
/*
always_ff @(posedge clk) begin
    save_exec_reg1_data_f <= ~exec_stall ? exec_reg1_data_f_t : save_exec_reg1_data_f;
    save_exec_reg2_data_f <= ~exec_stall ? exec_reg2_data_f_t : save_exec_reg2_data_f;
end
assign exec_reg1_data_f = ~exec_stall ? exec_reg1_data_f_t : save_exec_reg1_data_f;
assign exec_reg2_data_f = ~exec_stall ? exec_reg2_data_f_t : save_exec_reg2_data_f;
*/
Forward_OUT forward_exec_core0(
    //2023/7/6
    .clk,
    .reset(exec_flush),
    .stall(exec_stall),
    
    .reg1(exec_instr[0].rf_ctrl.rd_reg1),
    .reg1_data(exec_reg1_data_i[0]),
    .reg2(exec_instr[0].rf_ctrl.rd_reg2),
    .reg2_data(exec_reg2_data_i[0]),

    .wd_0('0),
    .wd_1,
    .wd_2,
    .wd_3,
    .wd_4,

    .forward_reg1_data(exec_reg1_data_f[0]),
    .forward_reg2_data(exec_reg2_data_f[0])
);

wire likely_flush;
wire [1:0] mdu_started;
FU #(
    .CTRL_CLO_CLZ(CTRL_CLO_CLZ)
) fu_core_0(
    .clk,
    .reset(exec_flush),
    .stall(way0_stall),
    .stall_top(exec_stall_top),

    .reg_addr1(),
    .reg_data1(exec_reg1_data_f[0]),
    .reg_addr2(),
    .reg_data2(exec_reg2_data_f[0]),

    .mdu_op(mdu_op[0]),
    .mdu_srcA(mdu_srcA[0]),
    .mdu_srcB(mdu_srcB[0]),
    .mdu_start(mdu_start[0]),
    .mdu_recv(mdu_recv[0]),
    .mdu_result,
    .mdu_started(mdu_started[0]),
    //.mdu_result_lo(lowReg),

    .bru_res(bru_res[0]),
    .likely_flush,
    
    .wd_ori(wd_0[0]),
    .instr(exec_instr[0]),
    .fu_wr_reg(fu_wd[0]),
    .fu_instr(fu_instr_res[0])
);

Forward_OUT forward_exec_core1(
    //2023/7/6
    .clk,
    .reset(exec_flush),
    .stall(exec_stall),
    
    .reg1(exec_instr[1].rf_ctrl.rd_reg1),
    .reg1_data(exec_reg1_data_i[1]),
    .reg2(exec_instr[1].rf_ctrl.rd_reg2),
    .reg2_data(exec_reg2_data_i[1]),

    .wd_0('0),
    .wd_1,
    .wd_2,
    .wd_3,
    .wd_4,

    .forward_reg1_data(exec_reg1_data_f[1]),
    .forward_reg2_data(exec_reg2_data_f[1])
);
FU #(
    .CTRL_CLO_CLZ(CTRL_CLO_CLZ)
) fu_core_1(
    .clk,
    .reset(exec_flush | likely_flush),
    .stall(way1_stall),
    .stall_top(exec_stall_top),

    .reg_addr1(),
    .reg_data1(exec_reg1_data_f[1]),
    .reg_addr2(),
    .reg_data2(exec_reg2_data_f[1]),

    .mdu_op(mdu_op[1]),
    .mdu_srcA(mdu_srcA[1]),
    .mdu_srcB(mdu_srcB[1]),
    .mdu_start(mdu_start[1]),
    .mdu_recv(mdu_recv[1]),
    .mdu_result,
    .mdu_started(mdu_started[1]),
    //.mdu_result_lo(lowReg),

    .bru_res(bru_res[1]),
    .likely_flush(),
    
    .wd_ori(wd_0[1]),
    .instr(exec_instr[1]),
    .fu_wr_reg(fu_wd[1]),
    .fu_instr(fu_instr_res[1])
);

wire [1:0] recover_num_ori [2:0];
logic [1:0] recover_num;
logic mod_hilo [2:0];
logic priv_way;
generate
    assign recover_num_ori[0] = mod_hilo[0] ? 2'b01 : 2'b00;
    for (genvar recover_i = 1; recover_i < 3; recover_i++) begin
        assign recover_num_ori[recover_i] = mod_hilo[recover_i] ? recover_num_ori[recover_i - 1] + 1 : recover_num_ori[recover_i - 1];
    end
endgenerate
always_comb begin
    mod_hilo[0] = (exec_instr[1].wr_md || exec_instr[0].wr_md) && (|mdu_started);
    mod_hilo[1] = at_instr[1].wr_md | at_instr[0].wr_md;
    mod_hilo[2] = priv_way ? dreq_instr[1].wr_md : dreq_instr[1].wr_md | dreq_instr[0].wr_md;
    recover_num = !(exception || exception_int) ? '0 : recover_num_ori[2];
end
MDU_Controller mdu_core(
    .clk,
    .resetn,

    .a0(mdu_srcA[0]),
    .b0(mdu_srcB[0]),
    .MDUOp0(mdu_op[0]),

    .a1(mdu_srcA[1]),
    .b1(mdu_srcB[1]),
    .MDUOp1(mdu_op[1]),

    .hi_reg(highReg),
    .lo_reg(lowReg),

    .valid(~exec_flush ? mdu_start : 2'b00),
    .recv(mdu_recv),
    .result(mdu_result),
    .recover(exception || exception_int),
    .recover_num
);

BVU bvu_core(
    .clk,
    .reset(~resetn | exception | exception_int | icache_valid_req | eret_jump),
    .stall(exec_stall),
    .stall_top(exec_stall_top),

    .way0_info(bru_res[0]),
    .way1_info(bru_res[1]),

    .update_valid,
    .bp_verify,
    .bp_fail
);

wr_reg_info [1:0] agu_wd;
wr_reg_info [1:0] exec_wd_o;
wire agu_ce;
wire [31:0] agu_v_addr;
instr_info [1:0] agu_instr;
AGU agu_core(
    .flush(exec_flush),
    .instr_i(exec_instr),
    .reg1_data(exec_reg1_data_f),
    .reg2_data(exec_reg2_data_f),
    .wd_i(wd_0),
    
    .v_addr(agu_v_addr),
    .instr_o(agu_instr),
    .wd_o(agu_wd),
    .ce(agu_ce)
);

lrf_data [1:0] exec_reg1_data_o;
lrf_data [1:0] exec_reg2_data_o;
instr_info [1:0] exec_instr_res;
//wr_reg_info [1:0] exec_wd_o;
always_comb begin
    exec_reg1_data_o = exec_reg1_data_f;
    exec_reg2_data_o = exec_reg2_data_f;
    exec_instr_res[0] = exec_instr[0].is_accmem ? agu_instr[0] : fu_instr_res[0];
    exec_instr_res[1] = exec_instr[1].is_accmem ? agu_instr[1] : fu_instr_res[1];
    exec_wd_o[0] = exec_instr[0].is_accmem ? agu_wd[0] : fu_wd[0];
    exec_wd_o[1] = exec_instr[1].is_accmem ? agu_wd[1] : fu_wd[1];
end

assign exec_instr_o = {exec2at(exec_instr_res[1]), exec2at(exec_instr_res[0])};

//address translate class 
instr_info_at [1:0] at_instr;

instr_info_dreq [1:0] at_instr_o;
wire at_flush;
wire at_ready_go;
wire at_allowin;
wire at_stall;
wire at_stall_inclass;
logic [1:0] at_valid;
logic at_ce;
logic [31:0] at_v_addr;
//wr_reg_info wd_at;
lrf_data [1:0] at_reg1_data_i;
lrf_data [1:0] at_reg2_data_i;
lrf_data [1:0] at_reg1_data_f;
lrf_data [1:0] at_reg2_data_f;


assign at_flush = ~resetn | exception | exception_int | eret_jump | icache_valid_req;
assign at_stall = dreq_stall;
always_ff @(posedge clk) begin
    if (at_flush) begin
        at_instr <= '0;
        at_valid <= '0;
        wd_1 <= '0;
        at_reg1_data_i <= '0;
        at_reg2_data_i <= '0;
        at_ce <= '0;
        at_v_addr <= '0;
    end
    else if (!at_stall) begin
        if (!exec_stall) begin
            at_valid <= exec_valid;
            at_instr <= exec_instr_o;
            wd_1 <= exec_wd_o;
            at_reg1_data_i <= exec_reg1_data_o;
            at_reg2_data_i <= exec_reg2_data_o;
            at_ce <= agu_ce;
            at_v_addr <= agu_v_addr;
        end
        else begin
            at_valid <= '0;
            at_instr <= '0;
            wd_1 <= '0;
            at_reg1_data_i <= '0;
            at_reg2_data_i <= '0;
            at_ce <= '0;
            at_v_addr <= '0;
        end
    end
end

generate
    for (genvar at_i = 0; at_i < 2; at_i++) begin
        Forward_OUT forward_at_core(
            .clk,
            .reset(at_flush),
            .stall(at_stall),
            
            .reg1(at_instr[at_i].rf_ctrl.rd_reg1),
            .reg1_data(at_reg1_data_i[at_i]),
            .reg2(at_instr[at_i].rf_ctrl.rd_reg2),
            .reg2_data(at_reg2_data_i[at_i]),
        
            .wd_0('0),
            .wd_1('0),
            .wd_2,
            .wd_3,
            .wd_4,
        
            .forward_reg1_data(at_reg1_data_f[at_i]),
            .forward_reg2_data(at_reg2_data_f[at_i])
        );
    end
endgenerate


assign data_tlb_search.vaddr = at_v_addr;
assign data_tlb_search.ce = at_ce;

instr_info_at [1:0] trap_instr;
wire [1:0] trap_way;
wire [4:0] exc_code_trap;
TrapUnit #(.CTRL_TRAP_UNIT(CTRL_TRAP_UNIT)) trap_core(
    .instr(at_instr),
    .reg1_data(at_reg1_data_f),
    .reg2_data(at_reg2_data_f),
    .exc_code(exc_code_trap),
    .trap_way
);
always_comb begin
    trap_instr = at_instr;
    if (trap_way[0]) begin
        trap_instr[0].exc_code = exc_code_trap;
    end
    if (trap_way[1]) begin
        trap_instr[1].exc_code = exc_code_trap;
    end
end

assign at_instr_o = {at2dreq(trap_instr[1]), at2dreq(trap_instr[0])};
wr_reg_info [1:0] at_wd_o;
always_comb begin
    at_wd_o = wd_1;
    at_wd_o[0].Tnew = wd_1[0].Tnew ? wd_1[0].Tnew - 1 : '0;
    at_wd_o[1].Tnew = wd_1[1].Tnew ? wd_1[1].Tnew - 1 : '0;
end

//data_req class ----------------------------------------------------------------------------------------
instr_info_dreq [1:0] dreq_instr;
instr_info_dreq [1:0] dreq_instr_res;
instr_info_mem [1:0] dreq_instr_o;
wire dreq_flush;
wire [1:0] core_addr_ok;
wire dreq_ready_go;
wire dreq_allowin;
logic [1:0] dreq_valid;
mem_addr dreq_va_addr;
wire dreq_stall_top; //outside stall
//wire dreq_stall_inclass; //stall signal generated from this class
wire mem_stall; //final stall

wire dreq_exception_flush;
assign dreq_exception_flush = dreq_stall ? ((exception || exception_int) && ~priv_way) : 
                              exception || exception_int;
`ifndef USE_SIMULATOR
assign dreq_flush = ~resetn | dreq_exception_flush | eret_jump | icache_valid_req;
`else
logic [1:0] exc_buf_valid;
assign dreq_flush = ~resetn | dreq_exception_flush | eret_jump | icache_valid_req || exc_buf_valid && !mem_stall;
`endif
//2023/7/5
//origin
//assign dreq_stall_top = exec_stall_inclass || mem_stall_inclass || wb_stall_inclass;
assign dreq_stall_top = mem_stall_inclass
 `ifdef COMMIT_QUEUE
 || wb_stall_inclass
 `endif
 ;
//assign dreq_stall_inclass = !dreq_ready_go;
//2023/7/6
`ifndef USE_SIMULATOR
assign dreq_stall = dreq_stall_inclass || dreq_stall_top; 
`else
instr_info_mem [1:0] exc_inst_buf;
cp0_info [1:0] cp0_info_buf;
assign dreq_stall = dreq_stall_inclass || dreq_stall_top || exc_buf_valid;
`endif

//assign dreq_stall = stall_top;
//assign dreq_ready_go = &core_addr_ok;
assign dreq_allowin = dreq_valid == 2'b00 || core_addr_ok;
lrf_data [1:0] dreq_reg1_data_i;
lrf_data [1:0] dreq_reg2_data_i;
lrf_data [1:0] dreq_reg1_data_f;
lrf_data [1:0] dreq_reg2_data_f;
always_ff @( posedge clk ) begin
    if (dreq_flush) begin
        dreq_valid <= '0;
        dreq_instr <= '0;
        wd_2 <= '0;
        dreq_reg1_data_i <= '0;
        dreq_reg2_data_i <= '0;
    end
    else if (!dreq_stall) begin
        //2023/7/6
        if (!at_stall) begin
            dreq_valid <= at_valid;
            dreq_instr <= at_instr_o;
            wd_2 <= at_wd_o;
            dreq_reg1_data_i <= at_reg1_data_f;
            dreq_reg2_data_i <= at_reg2_data_f;
        end
        else begin
            dreq_valid <= '0;
            dreq_instr <= '0;
            wd_2 <= '0;
            dreq_reg1_data_i <= '0;
            dreq_reg2_data_i <= '0;
        end
    end
end

generate
    genvar i;
    for (i = 0; i < `ISSUE_NUM; i++) begin
        Forward_OUT forward_dreq_core0(
        //2023/7/6
        .clk,
        .reset(dreq_flush),
        .stall(dreq_stall),
        
        .reg1(dreq_instr[i].rf_ctrl.rd_reg1),
        .reg1_data(dreq_reg1_data_i[i]),
        .reg2(dreq_instr[i].rf_ctrl.rd_reg2),
        .reg2_data(dreq_reg2_data_i[i]),

        .wd_0('0),
        .wd_1('0),
        .wd_2('0),
        .wd_3,
        .wd_4,

        .forward_reg1_data(dreq_reg1_data_f[i]),
        .forward_reg2_data(dreq_reg2_data_f[i])
    );
    end
endgenerate
/*
always_ff@ (posedge clk) begin
    save_dreq_reg1_data_f <= ~dreq_stall ? dreq_reg1_data_f_t : save_dreq_reg1_data_f;
    save_dreq_reg2_data_f <= ~dreq_stall ? dreq_reg2_data_f_t : save_dreq_reg2_data_f;
end
assign dreq_reg1_data_f = ~dreq_stall ? dreq_reg1_data_f_t : save_dreq_reg1_data_f;
assign dreq_reg2_data_f = ~dreq_stall ? dreq_reg2_data_f_t : save_dreq_reg2_data_f;
*/
//dreq inclass forward
lrf_data [1:0] dreq_reg1_data_ff;
lrf_data [1:0] dreq_reg2_data_ff;
/*
Forward_IN dreq_inclass_forward(
    .way1_reg1(dreq_instr[1].rf_ctrl.rd_reg1),
    .way1_reg1_data(dreq_reg1_data_f[1]),
    .way1_reg2(dreq_instr[1].rf_ctrl.rd_reg2),
    .way1_reg2_data(dreq_reg2_data_f[1]),
    
    .way0_wr_reg(wd_2[0]),
    .way1_reg1_data_f(dreq_reg1_data_ff[1]),
    .way1_reg2_data_f(dreq_reg2_data_ff[1])
);
*/
always_comb begin
    //dreq_reg1_data_ff[0] = dreq_reg1_data_f[0];
    //dreq_reg2_data_ff[0] = dreq_reg2_data_f[0];
    dreq_reg1_data_ff = dreq_reg1_data_f;
    dreq_reg2_data_ff = dreq_reg2_data_f;
end

//generate acc-mem signal
wire [3:0] wstrb;
wire res_way;

logic LLbit;
wire set_LLbit;
`ifdef USE_SIMULATOR
assign LLbit = 1'b1;
`else
always_ff @(posedge clk) begin
    if (~resetn) begin
        LLbit <= 1'b0;
    end
    else if (set_LLbit) begin
        LLbit <= 1'b1;
    end
    else if (eret_jump || exception || exception_int) begin
        LLbit <= 1'b0;
    end
end
`endif

wr_reg_info [1:0] wd_2_o;
MEM_REQ_MUX_2 mem_req_mux_2(
    .clk,
    .reset(~resetn/* | ((exception || exception_int) && ~priv_way)*/),
    .stall(dreq_stall),
    .stall_top(dreq_stall_top),
    .wb_stall(wb_stall_inclass),
    
    .LLbit,
    .set_LLbit,
    .instr_i(dreq_instr),
    .reg2_data(dreq_reg2_data_ff),
    .wd_i(wd_2),
    .tlb_info(data_tlb_info),
    
    .instr_o(dreq_instr_res),
    .data_req,
    .data_addr,
    .data_cached,
    .data_size,
    .data_wr,
    .data_wstrb,
    .data_wdata,
    .data_addr_ok,
    .dcache_valid,
    .dcache_op,
    .dcache_wb,
    
    .icache_valid_req,
    .icache_op_req,
    .icache_addr_req,
    .icache_cached_req,
    .icache_npc_req,
    
    .stall_inclass(dreq_stall_inclass),
    .wd_o(wd_2_o),
    
    .vaddr(dreq_va_addr)
);

//priv instr generate
instr_info_dreq priv_instr;
logic [4:0] CP0Add;
logic cp0_wen;
lrf_data CP0Din;
lrf_data CP0Dout;
logic [4:0] exc_code;
always_comb begin
    priv_way = dreq_instr_res[0].is_priv ? '0 : 
               dreq_instr_res[1].is_priv ? '1 : '0;
    priv_instr = priv_way ? dreq_instr_res[1] : dreq_instr_res[0];
    exc_code = priv_instr.exc_code;
    CP0Add = priv_instr.rf_ctrl.rd_reg1.src ? priv_instr.rf_ctrl.rd_reg1.addr[4:0] : 
             priv_instr.rf_ctrl.rd_reg2.src ? priv_instr.rf_ctrl.rd_reg2.addr[4:0] : 
             priv_instr.rf_ctrl.wr_reg.src ? priv_instr.rf_ctrl.wr_reg.addr[4:0] : '0;
    //cp0_wen = priv_instr.wr_reg.src && !dreq_stall_top;
    cp0_wen = priv_instr.cp0_ctrl.cp0_en && priv_instr.cp0_ctrl.wr_cp0;
    CP0Din = priv_instr.rf_ctrl.wr_reg.src ? (priv_way ? dreq_reg2_data_ff[1] : dreq_reg2_data_ff[0]) : '0;
    //eret_jump = priv_instr.opcode == `RS && priv_instr.code[25:21] == `cop0 && ~dreq_stall && priv_instr.funct == `eret;
    eret_jump = priv_instr.bru_ctrl == `eret_bru;
end
wire tlbr, tlbp, tlb_random;
assign tlbr = priv_instr.exc_code == `Int && priv_instr.tlb_ctrl == `TLB_Read;
assign tlbp = priv_instr.exc_code == `Int && priv_instr.tlb_ctrl == `TLB_Probe;
assign tlb_random = priv_instr.exc_code == `Int && priv_instr.tlb_ctrl == `TLB_WR;
assign tlb_wr = priv_instr.exc_code == `Int && (priv_instr.tlb_ctrl == `TLB_WR || priv_instr.tlb_ctrl == `TLB_WI);

/*(*mark_debug = "true"*)*/wire dreq_ready_int;
assign dreq_ready_int = dreq_instr[0].valid && {dreq_instr[1].is_accmem | dreq_instr[1].cache_op.valid, dreq_instr[0].is_accmem | dreq_instr[0].cache_op.valid} == 2'b00 && 
                         /*{dreq_instr[1].is_md, dreq_instr[0].is_md, at_instr[1].is_md, at_instr[0].is_md} == 4'b0000 && */
                         /*mdu_start == 2'b00 && */
                         {mem_instr[1].is_accmem, mem_instr[0].is_accmem} == 2'b00 && !wb_stall;//to adapte simulator environment
//xpm cdc
wire [5:0] cpu_ext_int;
`ifdef USE_SIMULATOR
assign cpu_ext_int = ext_int;
`else
if (CTRL_USE_XPM_CPC) begin
xpm_cdc_array_single #(
      .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(0),  // DECIMAL; 0=do not register input, 1=register input
      .WIDTH(6)           // DECIMAL; range: 1-1024
   )
   xpm_cdc_array_single_inst (
      .dest_out(cpu_ext_int), // WIDTH-bit output: src_in synchronized to the destination clock domain. This
                           // output is registered.

      .dest_clk(clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_clk(),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
      .src_in(ext_int)      // WIDTH-bit input: Input single-bit array to be synchronized to destination clock
                           // domain. It is assumed that each bit of the array is unrelated to the others. This
                           // is reflected in the constraints applied to this macro. To transfer a binary value
                           // losslessly across the two clock domains, use the XPM_CDC_GRAY macro instead.

   );
end
else begin
assign cpu_ext_int = ext_int;
end
`endif

//cp0
`ifdef USE_SIMULATOR
cp0_info [1:0] dreq_cp0_info;
cp0_info [1:0] mem_cp0_info;
cp0_info [1:0] wb_cp0_info;
wire [31:0] debug_cp0_count_ori;
wire [31:0] debug_cp0_random_ori;
wire [31:0] debug_cp0_cause_ori;
wire debug_int_ori;
assign debug_int_ori = exception_int;
always_comb begin
    dreq_cp0_info[0].cp0_count = debug_cp0_count_ori;
    dreq_cp0_info[0].cp0_random = debug_cp0_random_ori;
    dreq_cp0_info[0].cp0_cause = debug_cp0_cause_ori;
    dreq_cp0_info[0].cp0_int = debug_int_ori;
    
    dreq_cp0_info[1].cp0_count = debug_cp0_count_ori;
    dreq_cp0_info[1].cp0_random = debug_cp0_random_ori;
    dreq_cp0_info[1].cp0_cause = debug_cp0_cause_ori;
    dreq_cp0_info[1].cp0_int = debug_int_ori;
end
`endif

logic exc_req_complete;
wire exception_int_ori, exception_ori;
always_ff @(posedge clk) begin
	if (~resetn) begin
		exc_req_complete <= '0;
	end
	else begin
		if (dreq_stall) begin
			exc_req_complete <= exception_ori || exception_int_ori;
		end
		else begin
			exc_req_complete <= '0;
		end
	end
end
assign exception = exception_ori && !exc_req_complete;
assign exception_int = exception_int_ori && !exc_req_complete;
CP0 cp0_core(
    .clk,
    .reset(~resetn),
    .en(cp0_wen),
    .CP0Add,
    .CP0Sel(priv_instr.extimm[2:0]),
    .CP0In(CP0Din),
    .CP0Out(CP0Dout),
    .BadVAddrIn(priv_instr.bad_va_addr),
    .VPC(priv_instr.pc),
    .BDIn(priv_instr.in_delayslot),
    .ExcCodeIn(exc_code),
    .tlb_refill_error(priv_instr.exc_tre),
    .HWInt(cpu_ext_int),
    .EXLClr(eret_jump),
    .EPCOut(eret_pc),
    .Req_exc(exception_ori),
    .Req_int(exception_int_ori),
    .Handler(exc_handler),
    .ready_int(dreq_ready_int),
    
    .TagLo0_o(cp0_TagLo0_o),
    .EntryHi_o(cp0_EntryHi_o),
    .EntryLo0_o(cp0_EntryLo0_o),
    .EntryLo1_o(cp0_EntryLo1_o),
    .PageMask_o(cp0_PageMask_o),
    .TLB_Index_o(cp0_TLB_Index_o),
`ifdef USE_SIMULATOR
    .Random_o(debug_cp0_random_ori),
    .Cause_o(debug_cp0_cause_ori),
    .Count_o(debug_cp0_count_ori),
`endif
    
    .EntryLo0_i(cp0_EntryLo0_i),
    .EntryLo1_i(cp0_EntryLo1_i),
    .EntryHi_i(cp0_EntryHi_i),
    .PageMask_i(cp0_PageMask_i),
    .Index_i(cp0_Index_i),
    
    .tlbr,
    .tlbp,
    .TLB_random(tlb_random),
    
    .cp0_km,
    .cp0_erl,
    .cp0_kseg0_cached
);

wr_reg_info [1:0] dreq_wd;
generate
    for (genvar i = 0; i < `ISSUE_NUM; i++) begin
        assign dreq_wd[i].addr = ((exception || exception_int) && priv_way && i == 0 || ~(exception || exception_int)) ? wd_2_o[i].addr : '0;
        assign dreq_wd[i].data = `ifdef USE_SIMULATOR
        				!((exception || exception_int) && priv_way && i == 0 || ~(exception || exception_int)) ? '0 : 
        			  `endif
        		          dreq_instr[i].is_priv && ~dreq_instr[i].rf_ctrl.wr_reg.src && dreq_instr[i].rf_ctrl.wr_reg.addr ? CP0Dout : 
                                  //dreq_instr[i].opcode == `sc ? {31'b0, LLbit} : 
                                  wd_2_o[i].data;
        assign dreq_wd[i].Tnew = wd_2_o[i].Tnew > 0 ? wd_2_o[i].Tnew - 1 : wd_2_o[i].Tnew; 
    end
endgenerate

`ifdef USE_SIMULATOR
cp0_info [1:0] dreq_cp0_info_o;
always_ff @(posedge clk) begin
    if (~resetn) begin
        exc_buf_valid <= '0;
        exc_inst_buf <= '0;
        cp0_info_buf <= '0;
    end
    else if (exc_buf_valid == '0 && mem_stall) begin
        exc_buf_valid <= exception_int || exception || eret_jump || icache_valid_req ? dreq_valid : '0;
        exc_inst_buf <= dreq_instr_o;
        cp0_info_buf <= dreq_cp0_info;
    end
    else begin
        exc_buf_valid <= !mem_stall ? '0 : exc_buf_valid;
    end
end
`endif

always_comb begin
`ifndef USE_SIMULATOR
    dreq_instr_o = (exception_int || exception) && ~priv_way ? {'0, dreq2mem(dreq_instr_res[0])} : 
                   {dreq2mem(dreq_instr_res[1]), dreq2mem(dreq_instr_res[0])};
`else
    dreq_instr_o = exc_buf_valid ? exc_inst_buf : 
                   (exception_int || exception) && ~priv_way ? {'0, dreq2mem(dreq_instr_res[0])} : 
                   {dreq2mem(dreq_instr_res[1]), dreq2mem(dreq_instr_res[0])};
    dreq_cp0_info_o = exc_buf_valid ? cp0_info_buf : dreq_cp0_info;
`endif
    //dreq_instr_o = dreq_instr_res;
end
//mem_data class--------------------------------------------------------------------------------------------
instr_info_mem [1:0] mem_instr;
lrf_data [1:0] mem_reg1_data_i;
lrf_data [1:0] mem_reg2_data_i;
lrf_data [1:0] mem_reg1_data_f;
lrf_data [1:0] mem_reg2_data_f;

wire mem_stall_top; //outside stall
wire mem_flush;
//wire mem_stall; //final stall
wire mem_allowin;
wire mem_ready_go;
logic [1:0] mem_valid;
mem_addr mem_va_addr;
wire [1:0] acc_mem;
wire [31:0] mem_result;
logic save_data_data_ok;
assign mem_flush = ~resetn;
assign acc_mem[0] = mem_instr[0].is_accmem || mem_instr[0].cache_op.valid && mem_instr[0].cache_op.target;
assign acc_mem[1] = mem_instr[1].is_accmem || mem_instr[1].cache_op.valid && mem_instr[1].cache_op.target;
assign mem_ready_go = acc_mem == 2'b00 || data_data_ok || save_data_data_ok;
assign mem_allowin = mem_ready_go;
//assign mem_stall_top = wb_stall;
//2023/7/5
//orgin:
//assign mem_stall_top = exec_stall_inclass || dreq_stall_inclass || wb_stall_inclass;
`ifdef COMMIT_QUEUE
assign mem_stall_top = wb_stall_inclass;
`else
assign mem_stall_top = 1'b0;
`endif
assign mem_stall_inclass = !mem_ready_go;
//2023/7/6
assign mem_stall = (mem_stall_inclass || mem_stall_top);
//assign mem_stall = stall_top;
always_ff @( posedge clk ) begin
    if (mem_flush) begin
        mem_valid <= '0;
        mem_instr <= '0;
        wd_3 <= '0;
        mem_va_addr <= '0;
        mem_reg1_data_i <= '0;
        mem_reg2_data_i <= '0;
`ifdef USE_SIMULATOR
        mem_cp0_info <= '0;
`endif
    end
    else if (!mem_stall) begin
        //2023/7/6
        
        if (!dreq_stall
`ifdef USE_SIMULATOR
         || exc_buf_valid
`endif         
) begin
`ifdef USE_SIMULATOR
            mem_valid <= exc_buf_valid ? exc_buf_valid : dreq_valid;
`else
            mem_valid <= dreq_valid;
`endif
            mem_instr <= dreq_instr_o;
            wd_3 <= dreq_wd;
            mem_va_addr <= dreq_va_addr;
            mem_reg1_data_i <= dreq_reg1_data_ff;
            mem_reg2_data_i <= dreq_reg2_data_ff;
`ifdef USE_SIMULATOR
            mem_cp0_info <= dreq_cp0_info_o;
`endif
        end
        else begin
            mem_valid <= '0;
            mem_instr <= '0;
            wd_3 <= '0;
            mem_va_addr <= '0;
            mem_reg1_data_i <= '0;
            mem_reg2_data_i <= '0;
`ifdef USE_SIMULATOR
            mem_cp0_info <= '0;
`endif
        end
    end
end
wire [31:0] mem_result_intime;
logic [31:0] save_mem_result;
MEM_RECV_MUX mem_recv_mux_core(
   .instr(mem_instr),
   .rdata(data_rdata),
   .v_addr(mem_va_addr),
   .reg2_data(mem_reg2_data_f),
   .result(mem_result_intime)
);
assign mem_result = data_data_ok ? mem_result_intime : save_mem_result;
always_ff @(posedge clk)
begin
    /*
    save_data_data_ok <= ~resetn ? 1'b0 : 
                         //2023/7/5: mem_stall_top -> mem_stall
                         data_data_ok && mem_stall && (acc_mem[0] || acc_mem[1]) ? 1'b1 : 
                         (~mem_stall && (acc_mem[0] || acc_mem[1])) ? 1'b0 : 
                         save_data_data_ok;
    */
    save_data_data_ok <= ~resetn ? 1'b0 : 
                         !save_data_data_ok && acc_mem == 2'b00 && data_data_ok ? 1'b1 : 
                         !save_data_data_ok && acc_mem && data_data_ok && mem_stall ? 1'b1 : 
                         save_data_data_ok && acc_mem && !mem_stall ? 1'b0 : 
                         save_data_data_ok;
    save_mem_result <= ~resetn ? 32'h0 : 
                       data_data_ok ? mem_result_intime : save_mem_result;
end

generate
    for (genvar i = 0; i < `ISSUE_NUM; i++) begin
        Forward_OUT forward_mem_core (
            .clk,
            .reset(mem_flush),
            .stall(mem_stall),
            
            .reg1(mem_instr[i].rf_ctrl.rd_reg1),
            .reg1_data(mem_reg1_data_i[i]),
            .reg2(mem_instr[i].rf_ctrl.rd_reg2),
            .reg2_data(mem_reg2_data_i[i]),

            .wd_0('0),
            .wd_1('0),
            .wd_2('0),
            .wd_3('0),
            .wd_4,

            .forward_reg1_data(mem_reg1_data_f[i]),
            .forward_reg2_data(mem_reg2_data_f[i])
        );
    end
endgenerate

wr_reg_info [1:0] fu_d_wd;
generate
    for (genvar fu_d_i = 0; fu_d_i < `ISSUE_NUM; fu_d_i++) begin
        FU_delay #(
            .CTRL_CLO_CLZ(CTRL_CLO_CLZ)
        ) fu_d(
            .instr(mem_instr[fu_d_i]),
            .reg1_data(mem_reg1_data_f[fu_d_i]),
            .reg2_data(mem_reg2_data_f[fu_d_i]),
            .wd_i(wd_3[fu_d_i]),
            .wd_o(fu_d_wd[fu_d_i])
        );
    end
endgenerate

wr_reg_info [1:0] mem_wd;
generate
    for (genvar i = 0; i < `ISSUE_NUM; i++) begin
        assign mem_wd[i].addr = fu_d_wd[i].addr;
        assign mem_wd[i].data = mem_instr[i].is_accmem && !mem_instr[i].mem_ctrl.read_LLbit ? mem_result : fu_d_wd[i].data;
        assign mem_wd[i].Tnew = fu_d_wd[i].Tnew > 0 ? fu_d_wd[i].Tnew - 1 : fu_d_wd[i].Tnew;
    end
endgenerate

//write back class
wire wb_flush;
wire wb_allowin;
//wire wb_stall;
logic [1:0] wb_valid;
assign wb_flush = ~resetn;
instr_info_wb [1:0] wb_instr;
//wr_reg_info [1:0] wd_4;
always_ff @( posedge clk ) begin
    if (wb_flush) begin
        wb_valid <= '0;
        wb_instr <= '0;
        wd_4 <= '0;
`ifdef USE_SIMULATOR
        wb_cp0_info <= '0;
`endif
    end
    else if (~wb_stall) begin
        //2023/7/6
        
        if (!mem_stall) begin
            wb_valid <= mem_ready_go ? mem_valid : 2'b00;
            wb_instr <= {mem2wb(mem_instr[1]), mem2wb(mem_instr[0])};
            wd_4 <= mem_wd;
`ifdef USE_SIMULATOR
            wb_cp0_info <= mem_cp0_info;
`endif
        end
        else begin
            wb_valid <= '0;
            wb_instr <= '0;
            wd_4 <= '0;
`ifdef USE_SIMULATOR
            wb_cp0_info <= mem_cp0_info;
`endif
        end
    end
end
assign wb_stall_inclass = ~wb_allowin && wb_valid;
//2023/7/6
assign wb_stall = wb_stall_inclass;
//assign wb_stall = stall_top;
`ifdef USE_SIMULATOR
cp0_info debug_cp0_info;
assign debug_cp0_count = debug_cp0_info.cp0_count;
assign debug_cp0_random = debug_cp0_info.cp0_random;
assign debug_cp0_cause = debug_cp0_info.cp0_cause;
assign debug_int = debug_cp0_info.cp0_int;
`endif
WriteBackUnit write_back_core(
    .clk,
    .resetn,
    .allowin(wb_allowin),
    
    .wen0,
    .wen1,
    .wr_addr0,
    .wr_addr1,
    .wr_data0,
    .wr_data1,

    .wd(wb_valid & ~wb_stall ? wd_4 : '0),
    .instr(wb_valid & ~wb_stall ? wb_instr : '0),
`ifdef USE_SIMULATOR
    .cp0_info_wb(wb_cp0_info),
    .debug_cp0_info,
    .debug_commit,
`endif
    .debug_wb_pc,
    .debug_wb_rf_wen,
    .debug_wb_rf_wnum,
    .debug_wb_rf_wdata
);
endmodule
