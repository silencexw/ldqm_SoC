`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/02/28 08:27:22
// Design Name: 
// Module Name: LFSR
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


module LFSR #(
    parameter SET_SIZE = 4,
    parameter WAY_WIDTH = $clog2(SET_SIZE),
    parameter type way_t = logic [WAY_WIDTH    -1:0]
) (
    input logic clk,
    input logic reset,    // Active-high synchronous reset to 5'h1
    output logic [4:0] q,
    output way_t way_to_replace
);

    always@(posedge clk) begin
        if(reset) 
            q <= 5'h1;
        else begin
            q <= {q[0],q[4],q[3]^q[0],q[2:1]};
        end 
    end

    assign way_to_replace = q[WAY_WIDTH - 1:0];
endmodule
