`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/05 12:15:34
// Design Name: 
// Module Name: BTB
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

module BTB # (
    parameter SIZE = 4096
)
(
    input logic clk,
    input logic reset,
    input Vaddr Now_PC,
    input Update_BTB_S Update_BTB,
    output Predict_BTB_S Predict_BTB,
    input stall
    );
localparam Way_Size = SIZE/2;


//=========================Logic Define======================================
Vaddr                          Delay_Now_PC;
BTB_Table_Entry_S              Way_Read;
BTB_Table_Entry_S              Way_IP_Read;
logic [8:0]                    Delay_PC_To_Tag;
logic                          Way_Write_Vaild;
logic [10:0]                   Way_Write_Addr;
BTB_Table_Entry_S              Way_Write_Content;
logic                          Read_enb;
Ras                            Ras_Top_Data;
logic                          Pop_Request;
logic                          Push_Request;
logic [31:0]                   Push_Data;
BTB_Table_Entry_S              Delay_Update_BTB_S;
logic                          Violent;
logic                          Delay_Violent;
//=========================Logic Define======================================


//==========================Comb Logic=======================================


    //************************Update*********************************
assign Way_Write_Addr               = Update_BTB.Update_PC[13:3];
assign Way_Write_Vaild              = (Update_BTB.PC_Vaild && Update_BTB.PC_Taken && 
                                           Update_BTB.PC_MissPredict) ? 1'b1 : 1'b0;;
assign Way_Write_Content.XorTag     = CalTag(Update_BTB.Update_PC);
assign Way_Write_Content.PC         = Update_BTB.Update_Target;
assign Way_Write_Content.BranchType = Update_BTB.BranchType;  
assign Way_Write_Content.Location   = Update_BTB.Update_Location;
    //************************Update*********************************


    //************************Predict********************************
assign Delay_PC_To_Tag      = CalTag(Delay_Now_PC);
assign Way_Read             = (Delay_Violent) ?  Delay_Update_BTB_S : Way_IP_Read;
assign Read_enb             = ((Now_PC[13:3] == Way_Write_Addr) && Update_BTB.PC_Vaild) ? 1'b0 : 1'b1;
assign Violent              = ((Now_PC[13:3] == Way_Write_Addr) && Update_BTB.PC_Vaild) ? 1'b1 : 1'b0;
assign Predict_BTB.Delay_PC = Delay_Now_PC;
assign Push_Data            = ( (Way_Read.BranchType == Call && Way_Read.Location == 1'b1) ) ? Delay_Now_PC + 12 : 
                                    ( (Way_Read.BranchType == Call && Way_Read.Location == 1'b0) ) ? Delay_Now_PC + 8 : 32'd0;


always_comb 
begin
    Push_Request = 1'b0;
    Pop_Request = 1'b0;
    if (Delay_PC_To_Tag == Way_Read.XorTag && Way_Read.BranchType != None) 
    begin
        Predict_BTB.BranchType = Way_Read.BranchType;
        Predict_BTB.Predict_Location = Way_Read.Location;
        unique case(Way_Read.BranchType)
            Return: begin
                if (Ras_Top_Data.Vaild) begin
                    Pop_Request = 1'b1;
                    Predict_BTB.Target = Ras_Top_Data.PC;
                end
                else begin
                    Predict_BTB.Target = Delay_Now_PC + 8;
                end
            end
            Call: begin
                Predict_BTB.Target = Way_Read.PC;
                Push_Request = 1'b1;
            end
            None: begin
                Predict_BTB.Target = Delay_Now_PC + 8;
            end
            default: begin
                Predict_BTB.Target = Way_Read.PC;
            end
        endcase
    end 
    else
    begin
        Predict_BTB.BranchType = None;
        Predict_BTB.Target = Delay_Now_PC + 8;
        Predict_BTB.Predict_Location = '0;
    end
end


always_ff @(posedge clk) 
begin
    if (reset) begin
        Delay_Now_PC <= 32'hBFC0_0000;
        Delay_Update_BTB_S <= '0;
        Delay_Violent <= 1'b0;
    end else begin
        Delay_Now_PC <= Now_PC;
        Delay_Update_BTB_S <= Way_Write_Content;
        if (Violent) begin
            Delay_Violent <= 1'b1;
        end else begin
            Delay_Violent <= 1'b0;
        end
    end
end
    //************************Predict********************************



//=========================BTB MEM IP Core===================================
Simple_Dual_Ram_NWByte #(
	    .LEN_DATA(45),
        .RAM_SIZE(2048)
)  BTB_Core (
        .clka(clk),
        .clkb(clk),
        .ena(1'b1),
        .enb(Read_enb),
        .wea(Way_Write_Vaild),
        .addra(Way_Write_Addr),
        .addrb(Now_PC[13:3]),
        .dina(Way_Write_Content),
        .doutb(Way_IP_Read)
);
//=========================BTB MEM IP Core===================================//

//=========================Model Element====================================//
RAS ras(
    .clk,
    .reset,
    .Push_Request,
    .Pop_Request,
    .Push_Data,
    .Pop_Data(Ras_Top_Data),
    .stall
);
//=========================Model Element====================================//

//=========================Function Define===================================//
function automatic [8:0] CalTag(input [17:0] PC);
    logic [8:0] Result;
    
    Result = PC[17:9] ^ PC[8:0];
    
    return Result;
endfunction
//=========================Function Define===================================//
endmodule
