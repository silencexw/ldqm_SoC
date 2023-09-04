`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/03 17:00:45
// Design Name: 
// Module Name: WriteBackUnit
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
`include "cpu_macro.svh"
`define WBQ_LENGTH 8

module WriteBackUnit(
    input clk,
    input resetn,

    output logic allowin,
    output logic wen0,
    output logic wen1,
    output logic [4:0] wr_addr0,
    output logic [4:0] wr_addr1,
    output logic [31:0] wr_data0,
    output logic [31:0] wr_data1,
    
    input wr_reg_info [1:0] wd,
    input instr_info_wb [1:0] instr,
`ifdef USE_SIMULATOR
    input cp0_info  [1:0] cp0_info_wb,
    output logic        debug_commit,
    output cp0_info      debug_cp0_info,
`endif
    output logic [31:0] debug_wb_pc,
    output logic [3:0] debug_wb_rf_wen,
    output logic [4:0] debug_wb_rf_wnum,
    output logic [31:0] debug_wb_rf_wdata
);

`ifdef COMMIT_QUEUE
wb_info [`WBQ_LENGTH - 1: 0] wb_queue;
wb_info [`WBQ_LENGTH - 1: 0] wb_queue_nxt;
logic [$clog2(`WBQ_LENGTH + 1) - 1 : 0] tail;
wire [$clog2(`WBQ_LENGTH + 1) - 1 : 0] write_ptr;
`endif

wb_info [1:0] enter_entry;

`ifdef COMMIT_QUEUE
`ifndef USE_SIMULATOR
wire [1:0] enter_wb_num = enter_entry[0].wnum && enter_entry[1].wnum ? 2 : 
                    enter_entry[0].wnum ? 1 : 0;
wire out_wb_num = wb_queue[0].wnum ? 1 : 0;
`else
wire [1:0] enter_wb_num = enter_entry[0].valid && enter_entry[1].valid ? 2 : 
                          enter_entry[0].valid || enter_entry[1].valid ? 1 : 0;
wire out_wb_num = wb_queue[0].valid ? 1 : 0;
`endif
assign write_ptr = tail - out_wb_num;
assign allowin = tail < `WBQ_LENGTH - 1;
`endif

`ifndef COMMIT_QUEUE
assign allowin = 1'b1;
`endif

assign wen0 = &enter_entry[0].wen && allowin;
assign wen1 = &enter_entry[1].wen && allowin;
assign wr_addr0 = enter_entry[0].wnum;
assign wr_addr1 = enter_entry[1].wnum;
assign wr_data0 = enter_entry[0].wdata;
assign wr_data1 = enter_entry[1].wdata;
always_comb begin
    if (~allowin) begin
        enter_entry = '0;
    end
`ifndef USE_SIMULATOR
    else if (wd[0].addr) begin
        enter_entry[0].pc = instr[0].pc;
        enter_entry[0].wen = |wd[0].addr && wd[0].addr  < 32 ? 4'b1111 : 4'b0000;
        enter_entry[0].wnum = wd[0].addr;
        enter_entry[0].wdata = wd[0].data;

        enter_entry[1].pc = instr[1].pc;
        enter_entry[1].wen = |wd[1].addr && wd[1].addr < 32 ? 4'b1111 : 4'b0000;
        enter_entry[1].wnum = wd[1].addr;
        enter_entry[1].wdata = wd[1].data;
    end
    else if (wd[1].addr) begin
        enter_entry[0].pc = instr[1].pc;
        enter_entry[0].wen = |wd[1].addr && wd[1].addr < 32 ? 4'b1111 : 4'b0000;
        enter_entry[0].wnum = wd[1].addr;
        enter_entry[0].wdata = wd[1].data;
        
        enter_entry[1] = '0;
    end
`else
    else if (instr[0].valid) begin
        enter_entry[0].valid = 1'b1;
        enter_entry[0].pc = instr[0].pc;
        enter_entry[0].wen = |wd[0].addr && wd[0].addr < 32 ? 4'b1111 : 4'b0000;
        enter_entry[0].wnum = wd[0].addr;
        enter_entry[0].wdata = wd[0].data;
        enter_entry[0].debug_cp0_info = cp0_info_wb[0];
        if (instr[1].valid) begin
            enter_entry[1].valid = 1'b1;
            enter_entry[1].pc = instr[1].pc;
            enter_entry[1].wen = |wd[1].addr && wd[1].addr < 32 ? 4'b1111 : 4'b0000;
            enter_entry[1].wnum = wd[1].addr;
            enter_entry[1].wdata = wd[1].data;
            enter_entry[1].debug_cp0_info = cp0_info_wb[1];
        end
        else begin
            enter_entry[1] = '0;
        end
    end
    else if (instr[1].valid) begin
        enter_entry[0].valid = 1'b1;
        enter_entry[0].pc = instr[1].pc;
        enter_entry[0].wen = |wd[1].addr && wd[1].addr < 32 ? 4'b1111 : 4'b0000;
        enter_entry[0].wnum = wd[1].addr;
        enter_entry[0].wdata = wd[1].data;
        enter_entry[0].debug_cp0_info = cp0_info_wb[1];
        
        enter_entry[1] = '0;
    end
`endif
    else begin
        enter_entry = '0;
    end
end

`ifdef COMMIT_QUEUE
integer i;
always_ff @( posedge clk ) begin
    if (~resetn) begin
        for (i = 0; i < `WBQ_LENGTH; i = i + 1) begin
            wb_queue[i] <= '0;
        end
        tail <= '0;
    end
    else begin
        wb_queue <= wb_queue_nxt;
        tail <= tail + enter_wb_num - out_wb_num;
    end
end

generate
    for (genvar j = 0; j < `WBQ_LENGTH - 1; ++j) begin
        assign wb_queue_nxt[j] = (j < write_ptr) ? (out_wb_num ? wb_queue[j + 1] : wb_queue[j]) : 
                          (j < write_ptr + enter_wb_num) ? (j == write_ptr ? enter_entry[0] : enter_entry[1]) : '0;
    end
endgenerate
`endif

always_comb begin
`ifdef COMMIT_QUEUE
`ifdef USE_SIMULATOR
    debug_commit = out_wb_num;
    debug_cp0_info = wb_queue[0].debug_cp0_info;
`endif
    if (out_wb_num) begin
        debug_wb_pc = wb_queue[0].pc;
        debug_wb_rf_wen = wb_queue[0].wen;
        debug_wb_rf_wnum = wb_queue[0].wnum;
        debug_wb_rf_wdata = wb_queue[0].wdata;
    end
    else begin
        debug_wb_rf_wen = 4'b0000;
        debug_wb_rf_wnum = 0;
        debug_wb_rf_wdata = '0;
        debug_wb_pc = wb_queue[0].pc;
    end
`else
    debug_wb_pc = enter_entry[0].pc == 32'hbfc00100 || enter_entry[1].pc == 32'hbfc00100 ? 32'hbfc00100 : enter_entry[0].pc;
    debug_wb_rf_wen = enter_entry[0].wen;
    debug_wb_rf_wnum = enter_entry[0].wnum;
    debug_wb_rf_wdata = enter_entry[0].wdata;
`endif
end
endmodule
