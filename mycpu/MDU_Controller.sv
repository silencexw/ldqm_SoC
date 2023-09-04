`timescale 1ns/1ps
`include "InstrDefine.svh"

module MDU_Controller (
    input clk,
    input resetn,

    input logic [31:0] a0,
    input logic [31:0] b0,
    input logic [3:0] MDUOp0,

    input logic [31:0] a1,
    input logic [31:0] b1,
    input logic [3:0] MDUOp1,

    output logic [31:0] hi_reg,
    output logic [31:0] lo_reg,
    output logic [31:0] result,
    
    //hand shake
    input logic [1:0]   valid,
    output logic [1:0]  recv,
    
    input logic         recover,
    input logic [1:0]   recover_num
);

wire [31:0] srcA;
wire [31:0] srcB;
wire [3:0] op;
wire busy;
wire mt_en;
wire start;
wire sel;

assign recv[0] = !busy;
assign recv[1] = !busy;
assign sel = valid[1] && recv[1] ? 1'b1 : 1'b0;

assign srcA = sel ? a1 : a0;
assign srcB = sel ? b1 : b0;
assign op = sel ? MDUOp1 : MDUOp0;
assign mt_en = ~start ? 1'b0 : 
                (op == `MTLO || op == `MTHI) ? 1'b1 : 1'b0;
assign start = recv[0] && valid[0] || recv[1] && valid[1];

wire [31:0] mul_result;
MDU2 mdu_u(
    .clk,
    .reset(~resetn),
    .a(srcA),
    .b(srcB),
    .MDUOp(op),
    .start,
    .mt_en(mt_en),
    .highReg(hi_reg),
    .lowReg(lo_reg),
    .mul_result(mul_result),
    .busy(busy),
    
    .recover,
    .recover_num
);

assign result = op == `MFHI ? hi_reg : 
                op == `MFLO ? lo_reg : 
                mul_result;
                //op == `MUL ? mul_result : '0;
endmodule