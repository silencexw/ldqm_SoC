`timescale 1ns/1ps
//`include "cpu_macro.svh"
/*
this is logic register file module

two pairs of read
two pairs of write, way1 prior

in order to support **non-data-capture** issue queue structure
*/
module LRF (
    input           clk,
    input           resetn,

    // 2 ways of read port
    input   [5:0]   rs_addr0,
    input   [5:0]   rt_addr0,
    output  [31:0]  rs_data0,
    output  [31:0]  rt_data0,

    input   [5:0]   rs_addr1,
    input   [5:0]   rt_addr1,
    output  [31:0]  rs_data1,
    output  [31:0]  rt_data1,

    // 2 ways of write port
    input           wen0,
    input   [4:0]   wr_addr0,
    input   [31:0]  wr_data0,
    
    input           wen1,
    input   [4:0]   wr_addr1,
    input   [31:0]  wr_data1,

    input [31:0] hi,
    input [31:0] lo
);

lrf_data regs [31:0];
/*
(*mark_debug = "true"*) wire [31:0] db_v0;
(*mark_debug = "true"*) wire [31:0] db_ra;
assign db_v0 = regs[2];
assign db_ra = regs[31];
*/
//hi: 33, lo: 34
assign rs_data0 = rs_addr0[5] ? (rs_addr0[0] ? hi : lo) : 
                  |rs_addr0 ? regs[rs_addr0] : 0;
assign rt_data0 = rt_addr0[5] ? (rt_addr0[0] ? hi : lo) :
                  |rt_addr0 ? regs[rt_addr0] : 0;
assign rs_data1 = rs_addr1[5] ? (rs_addr1[0] ? hi : lo) : 
                  |rs_addr1 ? regs[rs_addr1] : 0;
assign rt_data1 = rt_addr1[5] ? (rt_addr1[0] ? hi : lo) :
                  |rt_addr1 ? regs[rt_addr1] : 0;

integer i;
always_ff @( posedge clk ) begin 
    if (~resetn) begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'h0;
        end
    end
    else begin
        if (wen0 && !wen1) begin
            regs[wr_addr0] <= wr_data0;
        end
        else if (!wen0 && wen1) begin
            regs[wr_addr1] <= wr_data1;
        end
        else if (wen0 && wen1) begin
            if (wr_addr0 != wr_addr1) begin
            regs[wr_addr0] <= wr_data0;
            regs[wr_addr1] <= wr_data1;
            end
            else begin
                regs[wr_addr1] <= wr_data1;
            end
        end
    end
end
endmodule