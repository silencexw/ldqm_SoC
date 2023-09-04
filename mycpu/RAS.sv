`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/05 21:36:16
// Design Name: 
// Module Name: RAS
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

module RAS # ( 
    parameter int Stack_Depth = 16
)
(
    input logic clk,
    input logic reset,
    input logic Push_Request,
    input logic Pop_Request,
    input Vaddr Push_Data,
    input logic stall,
    output Ras Pop_Data
);

//===============================Logic Define===================================
Ras RAS_Stack [15:0];
logic [3:0] RAS_Point;
logic [3:0] Pop_True;
logic Real_Push_Request;
logic Real_Pop_Request;
//===============================Logic Define===================================

//===============================Comb Logic=====================================
assign Pop_Data = RAS_Stack[Pop_True];
assign Pop_True = RAS_Point - 1;
assign Real_Push_Request = (Push_Request && !stall) ? 1'b1 : 1'b0;
assign Real_Pop_Request = (Pop_Request && !stall) ? 1'b1 : 1'b0;
//===============================Comb Logic=====================================

//===============================Time Logic=====================================
always_ff @(posedge clk)
begin
    if (reset) begin
        for (int i = 0; i < 16 ; i++ ) begin
            RAS_Stack[i] <= '0;
        end
        RAS_Point <= '0;
    end
    else begin
        if (Real_Push_Request) begin
            RAS_Stack[RAS_Point].PC <= Push_Data;
            RAS_Stack[RAS_Point].Vaild <= 1'b1;
            RAS_Point <= RAS_Point + 1;
        end
        else if (Real_Pop_Request) begin
            RAS_Stack[RAS_Point].Vaild <= 1'b0;
            RAS_Stack[RAS_Point].PC <= 32'd0;
            RAS_Point <= RAS_Point - 1;
        end
    end
end



//===============================Time Logic=====================================
endmodule
