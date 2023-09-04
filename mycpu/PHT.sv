`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  Unicorn
// 
// Create Date: 2023/05/05 09:54:16
// Design Name:  
// Module Name: PHT
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

module PHT # (
    parameter SIZE = 4096
)   
(
    input logic clk,
    input logic reset,
    input Vaddr Now_PC,
    input Update_PHT_S Update_PHT,
    output Predict_PHT_S Predict_PHT,
    input logic Predict_Branch_Vaild,
    input logic GHR_Type_Coupled,
    input logic TBT_Used,
    input logic TBT_Taken,
    input stall
);
//===============================Logic Define===================================
Hash_11 Hash_Read_PC;
Hash_11 Hash_Write_PC; 
logic Read_enb;
logic Write_Vaild;
TwoBitState Write_CPHT;
logic Delay_Violent;
TwoBitState Predict_CPHT;
TwoBitState Delay_Write_CPHT;
logic [1:0] Taken_Type;
logic TBT_MissPredict;
logic GHR_MissPredict;

Update_TBT_S Update_TBT;
Update_GHR_S Update_GHR;

Predict_TBT_S Predict_TBT;
Predict_GHR_S Predict_GHR;
//===============================Logic Define===================================




//===============================Comb Logic=====================================
assign Hash_Read_PC = hash_11(Now_PC);
assign Hash_Write_PC = hash_11(Update_PHT.Update_PC);
assign Write_Vaild = Update_PHT.PC_Vaild;
assign Write_CPHT = Update_Counter(Update_PHT.CPHT, Taken_Type);
assign Read_enb = !(Hash_Read_PC ==  Hash_Write_PC);

assign Update_TBT.PC_Vaild = Update_PHT.PC_Vaild;
assign Update_TBT.PC_Taken = Update_PHT.PC_Taken;
assign Update_TBT.Counter = Update_PHT.TBT_Counter;
assign Update_TBT.Update_PC = Update_PHT.Update_PC;

assign Update_GHR.PC_Vaild =  GHR_Type_Coupled ? Update_PHT.PC_Vaild : '0;
assign Update_GHR.PC_Taken = Update_PHT.PC_Taken;
assign Update_GHR.PC_MissPredict = Update_PHT.PC_MissPredict;
assign Update_GHR.GHR_MissPredict = GHR_MissPredict;
assign Update_GHR.Counter = Update_PHT.GHR_Counter;
assign Update_GHR.Update_PC = Update_PHT.Update_PC;
assign Update_GHR.Recover_GHR = Update_PHT.Recover_GHR;
assign Update_GHR.GHR = Update_PHT.GHR;

assign TBT_MissPredict = ((Update_PHT.TBT_Counter == 2 || Update_PHT.TBT_Counter == 3) && Update_PHT.PC_Taken) ? 1'b0 :
                            ((Update_PHT.TBT_Counter == 0 || Update_PHT.TBT_Counter == 1) && !Update_PHT.PC_Taken) ? 1'b0 : 
                                (!Update_PHT.PC_Vaild) ? 1'b0 : 1'b1;
                                
assign GHR_MissPredict = ((Update_PHT.GHR_Counter == 2 || Update_PHT.GHR_Counter == 3) && Update_PHT.PC_Taken) ? 1'b0 :
                            ((Update_PHT.GHR_Counter == 0 || Update_PHT.GHR_Counter == 1) && !Update_PHT.PC_Taken) ? 1'b0 : 
                                 (!Update_PHT.PC_Vaild) ? 1'b0 : 1'b1;
                                 
assign Taken_Type = ((TBT_MissPredict && GHR_MissPredict) ||  (!TBT_MissPredict && !GHR_MissPredict)) ? 2'd2 :
                       (TBT_MissPredict && !GHR_MissPredict) ? 2'd0 : 2'd1;
                       
assign Predict_PHT.TBT_Counter = Predict_TBT.Predict_Counter;
assign Predict_PHT.GHR_Counter = Predict_GHR.Predict_Counter;
assign Predict_PHT.Recover_GHR = Predict_GHR.Recover_GHR;
assign Predict_PHT.GHR = Predict_GHR.GHR;
assign Predict_PHT.CPHT = (Delay_Violent) ?  Delay_Write_CPHT : Predict_CPHT;
//===============================Comb Logic=====================================


//============================FF Logic=========================================//
always_ff @(posedge clk) begin
    if (reset) begin
        Delay_Write_CPHT <= '0;
        Delay_Violent <= '0;
    end else begin
        Delay_Write_CPHT <= Write_CPHT;
        if (Hash_Read_PC ==  Hash_Write_PC ) begin
            Delay_Violent <= 1'b1;
        end else begin
            Delay_Violent <= 1'b0;
        end
   end
end
//============================FF Logic=========================================//


//===============================Model Used======================================
GlobalHistory global_history(
    .clk,
    .reset,
    .Now_PC,
    .Update_GHR,
    .Predict_GHR,
    .Predict_Branch_Vaild,
    .TBT_Used,
    .TBT_Taken,
    .stall
);


TwoBit two_bit (
    .clk,
    .reset,
    .Now_PC,
    .Update_TBT,
    .Predict_TBT
);
//===============================Model Used======================================


//=============================PHT MEM IP Core===================================//
Simple_Dual_Ram_NWByte #(
	    .LEN_DATA(45),
        .RAM_SIZE(2048)
)  CPHT_Core (
        .clka(clk),
        .clkb(clk),
        .ena(1'b1),
        .enb(Read_enb),
        .wea(Write_Vaild),
        .addra(Hash_Write_PC),
        .addrb(Hash_Read_PC),
        .dina(Write_CPHT),
        .doutb(Predict_CPHT)
);
//============================PHT MEM IP Core===================================//


//=========================Function Define===================================//
//******Return The Next State********
function automatic [1:0] Update_Counter(
    input [1:0] Counter,
    input [1:0] PC_Taken
    );
    logic [1:0] NewCounter;
    if(PC_Taken == 2'd1) 
    begin
		unique case(Counter)
			2'b00: NewCounter = 2'b10;
			2'b01: NewCounter = 2'b00;
			2'b10: NewCounter = 2'b11;
			2'b11: NewCounter = 2'b11;
		endcase
	end else if (PC_Taken == 2'd0)
    begin
		unique case(Counter)
			2'b00: NewCounter = 2'b01;
			2'b01: NewCounter = 2'b01;
			2'b10: NewCounter = 2'b00;
			2'b11: NewCounter = 2'b10;
		endcase
	end else begin
	   NewCounter = Counter;
	end
    return NewCounter;
endfunction
//******use this fuction to transform 32 bit PC to 12 bit hash value******
function automatic [11:0] hash_12(input [31:0] data);
    logic [11:0] hash_value;
    
    hash_value = {data[31:24], data[23:16], data[15:8], data[7:0]};
    hash_value = hash_value ^ (hash_value >> 6);
    hash_value = hash_value ^ (hash_value << 5);
    hash_value = hash_value ^ (hash_value >> 8);
    
    return hash_value;
endfunction
//******use this fuction to transform 32 bit PC to 11 bit hash value******
function automatic logic [10:0] hash_11(input logic [31:0] input_data);
  logic [10:0] output_hash;
  
  // ¹þÏ£Ëã·¨Âß¼­
  output_hash = ((input_data & 11'h7FF) ^ (input_data >> 11)) ^ (input_data >> 22);
  
  return output_hash;
endfunction

//=========================Function Define===================================//

endmodule
