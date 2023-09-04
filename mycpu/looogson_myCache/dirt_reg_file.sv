`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/04/25 08:34:45
// Design Name: 
// Module Name: dirt_reg_file
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


module dirt_reg_file #(
    parameter GROUP_NUM = 128,
    parameter INDEX_WIDTH = $clog2(GROUP_NUM),
    parameter type index_t  = logic [INDEX_WIDTH  -1:0]
) (
    input logic clk,
    input logic reset,

    input logic set_D,
    input logic wdirt,
    input index_t addra,
    input index_t addrb,
    output logic isDirt
);

    reg D_file [0:GROUP_NUM - 1];
    reg SYNC_isDirt;
    integer i;
    always@ (posedge clk) begin
        if (reset) begin
            D_file <= '{default: '0};
        end
        else if (set_D) begin
            D_file[addra] <= wdirt;
        end
        
        if (reset) begin
            SYNC_isDirt <= 0;
        end
        else begin
            SYNC_isDirt <= D_file[addrb];
        end
    end
    assign isDirt = SYNC_isDirt;

endmodule

