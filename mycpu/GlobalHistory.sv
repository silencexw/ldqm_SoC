`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/06 17:35:19
// Design Name: 
// Module Name: BHR
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
module GlobalHistory(
    input logic clk,
    input logic reset,
    input Vaddr Now_PC,
    input Update_GHR_S Update_GHR,
    output Predict_GHR_S Predict_GHR,
    input logic Predict_Branch_Vaild,
    input logic TBT_Used,
    input logic TBT_Taken,
    input stall
);

GlobalHistoryReg GHR;


logic [10:0]        PHT_Read_PC;
logic               Read_enb;
TwoBitState         PHT_IP_Predict_Counter;
TwoBitState         Delay_NewCounter;
logic               Delay_PHT_Violent;
logic               Predict_Taken;
logic               Merge_Predict_Taken;


logic [10:0]        PHT_Write_PC;
logic               Write_Vaild;
TwoBitState         Write_Counter;


assign PHT_Read_PC = {GHR,Now_PC[7:3]};
assign Predict_GHR.Predict_Counter = (Delay_PHT_Violent) ? Delay_NewCounter : PHT_IP_Predict_Counter;
assign Predict_GHR.Recover_GHR = Predict_Branch_Vaild ? {GHR[4:0],~Merge_Predict_Taken} : '0;
assign Predict_GHR.GHR = Predict_Branch_Vaild ? GHR : '0;
assign Predict_Taken = (Predict_GHR.Predict_Counter == 2'd0 || Predict_GHR.Predict_Counter == 2'd1) ? 1'b0 : 1'b1;
assign Merge_Predict_Taken = (TBT_Used) ? TBT_Taken : Predict_Taken;

assign Write_Vaild = Update_GHR.PC_Vaild;
assign PHT_Write_PC = {Update_GHR.GHR, Update_GHR.Update_PC[7:3]};
assign Write_Counter = Update_Counter(Update_GHR.Counter,Update_GHR.PC_Taken);
assign Read_enb = !(PHT_Read_PC ==  PHT_Write_PC);


always_ff @(posedge clk) begin
    if (reset) begin
        Delay_NewCounter <= '0;
        Delay_PHT_Violent <= '0;
    end else begin
        Delay_NewCounter <= Write_Counter;
        if ( PHT_Read_PC == PHT_Write_PC ) begin
            Delay_PHT_Violent <= 1'b1;
        end else begin
            Delay_PHT_Violent <= 1'b0;
        end
   end
end


always_ff @(posedge clk) begin
    if (reset) begin
        GHR <= '0;
    end else begin
        if (Update_GHR.PC_Vaild && Update_GHR.PC_MissPredict) begin
            GHR <= Update_GHR.Recover_GHR;
        end else if (!stall && Predict_Branch_Vaild) begin
            GHR <= {GHR[4:0],Merge_Predict_Taken};
        end else begin
            GHR <= GHR;
        end
    end
end

Simple_Dual_Ram_NWByte #(
	    .LEN_DATA(45),
        .RAM_SIZE(2048)
)  PHT_Core (
        .clka(clk),
        .clkb(clk),
        .ena(1'b1),
        .enb(Read_enb),
        .wea(Write_Vaild),
        .addra(PHT_Write_PC),
        .addrb(PHT_Read_PC),
        .dina(Write_Counter),
        .doutb(PHT_IP_Predict_Counter)
);
//===============================BHR==========================================

//=========================Function Define===================================//
//******Return The Next State********
function automatic [1:0] Update_Counter(
    input [1:0] Counter,
    input PC_Taken
    );
    logic [1:0] NewCounter;
    if(PC_Taken) 
    begin
		unique case(Counter)
			2'b00: NewCounter = 2'b10;
			2'b01: NewCounter = 2'b00;
			2'b10: NewCounter = 2'b11;
			2'b11: NewCounter = 2'b11;
		endcase
	end else 
    begin
		unique case(Counter)
			2'b00: NewCounter = 2'b01;
			2'b01: NewCounter = 2'b01;
			2'b10: NewCounter = 2'b00;
			2'b11: NewCounter = 2'b10;
		endcase
	end
    return NewCounter;
endfunction
//******use this fuction to transform 32 bit PC to 10 bit hash value******
function automatic [9:0] hash_10(input [31:0] data);
  logic [9:0] output_hash;
  
  logic [15:0] intermediate_value;
  intermediate_value = data ^ (data >> 16);
  intermediate_value = intermediate_value ^ (intermediate_value >> 8);
  output_hash = intermediate_value[9:0]; 
  
  return output_hash;
endfunction
//=========================Function Define===================================//
endmodule
