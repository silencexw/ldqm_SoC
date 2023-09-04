`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/01 19:04:20
// Design Name: 
// Module Name: two_bit
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


module TwoBit # (
    parameter SIZE = 4096
)   
(
    input logic clk,
    input logic reset,
    input Vaddr Now_PC,
    input Update_TBT_S Update_TBT,
    output Predict_TBT_S Predict_TBT
);

//=========================Logic Define======================================//
logic WeaValid;
TwoBitState NewCounter;
Hash_11 Hash_Read_PC;
Hash_11 Hash_Write_PC;
logic Delay_Violent;
TwoBitState Delay_NewCounter;
TwoBitState Predict_Counter;
logic Read_enb;
//=========================Logic Define======================================//

//=============================Comb Logic==========================================//
assign WeaValid = Update_TBT.PC_Vaild;
assign NewCounter = Update_Counter(Update_TBT.Counter,Update_TBT.PC_Taken);
assign Hash_Read_PC = hash_11(Now_PC);
assign Hash_Write_PC = hash_11(Update_TBT.Update_PC);
assign Predict_TBT.Predict_Counter = (Delay_Violent) ?  Delay_NewCounter : Predict_Counter;
assign Read_enb = ((Hash_Read_PC ==  Hash_Write_PC) && Update_TBT.PC_Vaild) ? 1'b0 : 1'b1;
//=============================Comb Logic==========================================//


//============================FF Logic==========================================//
always_ff @(posedge clk) begin
    if (reset) begin
        Delay_NewCounter <= '0;
        Delay_Violent <= '0;
    end else begin
        Delay_NewCounter <= NewCounter;
        if ( (Hash_Read_PC ==  Hash_Write_PC) && Update_TBT.PC_Vaild) begin
            Delay_Violent <= 1'b1;
        end else begin
            Delay_Violent <= 1'b0;
        end
   end
end
//============================FF Logic=========================================//

//=========================PHT MEM IP Core===================================//
//Hint:I use Channel A to Read PHT MEM,Use Channel B to Write(Update) PHT

Simple_Dual_Ram_NWByte #(
	    .LEN_DATA(2),
        .RAM_SIZE(2048)
)  PHT_Core (
        .clka(clk),
        .clkb(clk),
        .ena(1'b1),
        .enb(Read_enb),
        .wea(WeaValid),
        .addra(Hash_Write_PC),
        .addrb(Hash_Read_PC),
        .dina(NewCounter),
        .doutb(Predict_Counter)
);

//=========================PHT MEM IP Core===================================//


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
endmodule
