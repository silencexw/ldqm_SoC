`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/01/19 10:50:16
// Design Name: 
// Module Name: MDU2
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

`include "InstrDefine.svh"
module MDU2(
    input clk,
	input reset,
	input [31:0] a,
	input [31:0] b,
	input [3:0] MDUOp,
	input start,
	input mt_en,
	output [31:0] highReg,
    output [31:0] lowReg,
    output [31:0] mul_result,
	output busy,
	
	input          recover,
	input  [1:0]   recover_num
    );
    
wire allow_recover;
wire recover_f;
reg _recover;
wire [31:0] recover_hi;
wire [31:0] recover_lo;

wire [1:0] multi_cycle = (MDUOp == `MULT || MDUOp == `MULTU) ? 2'b01 : 
                    (MDUOp == `MADD || MDUOp == `MADDU || MDUOp == `MSUB || MDUOp == `MSUBU || MDUOp == `MUL) ? 2'b01 :
                    (MDUOp == `DIV || MDUOp == `DIVU) ? 2'b10 : 2'b00;
//wire in_sign = MDUOp == `MULT || MDUOp == `DIV;
wire in_ready;
//wire in_valid = start && in_op != 2'b00;
reg in_valid;
wire out_valid;
wire [31:0] lo_cal;
wire [31:0] hi_cal;
reg [31:0] lo;
reg [31:0] hi;
reg [31:0] mul_res;

reg [3:0] in_op;
reg [31:0] srcA;
reg [31:0] srcB;

always @(posedge clk) begin
    if (reset) begin
        in_valid <= 1'b0;
        in_op <= 4'b0;
        srcA <= 32'h0;
        srcB <= 32'h0;
    end
    else begin
        if (in_valid) begin
            in_valid <= 1'b0;
        end
        else begin
            if (multi_cycle != 2'b00 && start) begin
                in_valid <= 1'b1;
                in_op <= MDUOp;
                srcA <= a;
                srcB <= b;
            end
        end
    end
end

wire [3:0] _in_op;
assign _in_op = ~in_op[3] ? in_op : 
                 in_op == `MSUB || in_op == `MADD || in_op == `MUL ? `MULT : 
                 in_op == `MSUBU || in_op == `MADDU ? `MULTU : 4'b0;
MDU_new multdivunit(
    .clk(clk),
    .reset(reset),
    
    .srcA(srcA),
    .srcB(srcB),
    .op(_in_op),
    
    .in_valid(in_valid),
    .in_ready(in_ready),
    .out_valid(out_valid),
    .out_ready(1'b1),
    
    .hi_res(hi_cal),
    .lo_res(lo_cal)
);
assign busy = ~in_ready || out_valid || in_valid || _recover;
assign allow_recover = !(~in_ready || out_valid || in_valid);
assign highReg = hi;
assign lowReg = lo;
assign mul_result = mul_res;

reg [31:0] p_hi [2:0];
reg [31:0] p_lo [2:0];
wire update_hilo = MDUOp == `MTLO && mt_en || MDUOp == `MTHI && mt_en || out_valid && in_op != `MUL;
integer i;
integer j;
always @(posedge clk) begin
    if (reset || (recover_f && allow_recover)) begin
        for (i = 0; i < 3; i = i + 1) begin
            p_hi[i] <= 32'h0;
            p_lo[i] <= 32'h0;
        end
    end
    else if (update_hilo) begin
        for (j = 1; j < 3; j = j + 1) begin
            p_hi[j] <= p_hi[j - 1];
            p_lo[j] <= p_lo[j - 1];
        end
        p_hi[0] <= hi;
        p_lo[0] <= lo;
    end
end

wire [1:0] recover_num_f;
reg [1:0] _recover_num;
assign recover_f = recover || _recover;
assign recover_num_f = _recover ? _recover_num : recover_num;
always @(posedge clk) begin
    if (reset) begin
        _recover_num <= 2'b00;
        _recover <= 1'b0;
    end
    else if (recover && ~_recover && !allow_recover) begin
        _recover <= 1'b1;
        _recover_num <= recover_num;
    end
    else if (_recover && allow_recover) begin
        _recover <= 1'b0;
        _recover_num <= 2'b00;
    end
end
assign recover_hi = recover_num_f == 2'd3 ? p_hi[2] : 
                    recover_num_f == 2'd2 ? p_hi[1] : 
                    recover_num_f == 2'd1 ? p_hi[0] : 
                    hi;
assign recover_lo = recover_num_f == 2'd3 ? p_lo[2] : 
                    recover_num_f == 2'd2 ? p_lo[1] : 
                    recover_num_f == 2'd1 ? p_lo[0] : 
                    lo;

always@ (posedge clk)begin
    if (reset) begin
        lo <= 0;
        hi <= 0;
    end
    else if (recover_f && allow_recover) begin
        lo <= recover_lo;
        hi <= recover_hi;
    end
    else if (MDUOp == `MTLO && mt_en) begin
        lo <= a;
        hi <= hi;
    end
    else if (MDUOp == `MTHI && mt_en) begin
        lo <= lo;
        hi <= a;
    end
    else if (out_valid) begin
        if (in_op == `MADDU || in_op == `MADD) begin
            //lo <= lo + lo_cal;
            //hi <= hi + hi_cal;
            {hi, lo} <= {hi, lo} + {hi_cal, lo_cal};
        end
        else if (in_op == `MSUB || in_op == `MSUBU) begin
            //lo <= lo - lo_cal;
            //hi <= hi - hi_cal;
            {hi, lo} <= {hi, lo} - {hi_cal, lo_cal};
        end
        else if (in_op == `MUL) begin
            mul_res <= lo_cal;
            //lo <= lo_cal;
            //hi <= hi_cal;
        end
        else begin
            lo <= lo_cal;
            hi <= hi_cal;
        end
    end
    else begin
        lo <= lo;
        hi <= hi;
    end
end
endmodule
