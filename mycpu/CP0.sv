`timescale 1ns/1ps
`include "InstrDefine.svh"
`include "cpu_macro.svh"
//Reg_space
//SR
`define SR_Bev Status[22]
`define SR_IM Status[15:8]
`define SR_KSU Status[4:3]
`define SR_ERL Status[2]
`define SR_EXL Status[1]
`define SR_IE Status[0]
//Cause
`define Cause_BD Cause[31]
`define Cause_TI Cause[30]
`define Cause_IV Cause[23]
`define Cause_IP Cause[15:8]
`define Cause_ExcCode Cause[6:2]

`define TLB_IDX_BITS 5

`define INIT_NORMAL 32'h0
`define INIT_Random 32'd31
`define INIT_Status 32'h00400000
`define INIT_PRId   32'h00018003
`define INIT_EBase  32'h80000000
`define INIT_Conf0  {1'b1,3'b0,3'b0,9'b0,1'b0,2'b0,3'b0,3'b1,3'b0,1'b0,3'd3}
`define INIT_Conf1  {1'b0,6'd31,3'd1,3'd4,3'd3,3'd1,3'd4,3'd3,7'd0};

module CP0(
	input clk, 				
	input reset,			
	input en,				
	input [4:0] CP0Add,		
	input [2:0] CP0Sel,
	input [31:0] CP0In,		
	output [31:0] CP0Out,	
	input [31:0] BadVAddrIn,
	input [31:0] VPC,		
	input BDIn,				
	input [4:0] ExcCodeIn,	
	input       tlb_refill_error,
	
	input [5:0] HWInt, 		
	input EXLClr,			
	output [31:0] EPCOut,
	output [31:0] Handler,	
	output Req_exc,
	output Req_int,
	input ready_int,
	
	//cp0_regs_output
	output [31:0] TagLo0_o,
	output [31:0] EntryHi_o,
	output [31:0] EntryLo0_o,
	output [31:0] EntryLo1_o,
	output [11:0] PageMask_o,
	output [31:0] TLB_Index_o,
`ifdef USE_SIMULATOR
	output [31:0] Random_o,
	output [31:0] Cause_o,
	output [31:0] Count_o,
`endif
	
	//tlb
	input  TLB_random,
	input  tlbr,
	input  tlbp,
	
	input  [31:0]  EntryLo0_i,
	input  [31:0]  EntryLo1_i,
	input  [31:0]  EntryHi_i,
	input  [11:0]  PageMask_i,
	input  [31:0]  Index_i,
	
	output cp0_km,
	output cp0_erl,
	output cp0_kseg0_cached
	);

reg [31:0] Index;   //0
reg [31:0] Random;  //1
reg [31:0] EntryLo0;//2
reg [31:0] EntryLo1;//3
reg [31:0] Context; //4
reg [31:0] PageMask;//5
reg [31:0] Wired;   //6
reg [31:0] BadVAddr; //8
reg [31:0] Count;   //9
reg [31:0] EntryHi; //10
reg [31:0] Compare; //11
/*(*mark_debug = "true"*)*/reg [31:0] Status;  //12
/*(*mark_debug = "true"*)*/reg [31:0] Cause; 	//13
/*(*mark_debug = "true"*)*/reg [31:0] EPC;	  	//14
/*(*mark_debug = "true"*)*/reg [31:0] EBase;   //15.1
reg [31:0] Conf0;   //16.0
reg [31:0] Conf1;   //16.1
reg [31:0] TagLo0;  //28.0
reg [31:0] TagHi0;  //29.0

wire [1:0] Req_ori;
reg [1:0] exc_buffer; //0: int, 1: exc
wire Req_Type;//0: int, 1:exc
/*(*mark_debug = "true"*)*/wire Req;
/*(*mark_debug = "true"*)*/reg int_buffer;
wire [15:8] fullInt;

//TLB read cp0 regs
assign TagLo0_o = TagLo0;
assign EntryHi_o = EntryHi;
assign EntryLo0_o = EntryLo0;
assign EntryLo1_o = EntryLo1;
assign PageMask_o = PageMask[24:13];
assign TLB_Index_o = TLB_random ? Random : Index;
`ifdef USE_SIMULATOR
assign Random_o = Random;
assign Cause_o = {Cause[31:16], fullInt, Cause[7:0]};
assign Count_o = Count;
`endif

function logic allow_int(input logic [15:8] fullInt_i, input logic [31:0] Status_i);
	return (Status_i[2:0] == 3'b001 && (|(fullInt_i & Status_i[15:8])));
endfunction

//system status
assign cp0_km = `SR_KSU == 2'b00 || `SR_EXL || `SR_ERL;
assign cp0_erl = `SR_ERL;
assign cp0_kseg0_cached = Conf0[2:0] == 3'b011;

//Exception Vector
/*(*mark_debug = "true"*)*/wire [31:0] Handler_base = `SR_Bev ? 32'hbfc00200 : {EBase[31:12], 12'h0};
wire [31:0] tre_handler = `SR_EXL ? Handler_base + 32'h180 : Handler_base;
assign Handler = (Req_int) ? (`Cause_IV ? Handler_base + 32'h200 : Handler_base + 32'h180) ://int_req
                  (Req_exc) ? (tlb_refill_error ? tre_handler : Handler_base + 32'h180) : 
                  32'hbfc00380;
                  
reg timer_int, clr_timer_int;
assign fullInt = {timer_int | HWInt[5], HWInt[4:0], Cause[9:8]};
reg [15:8] fullInt_buf;
//(*mark_debug = "true"*)wire [5:0] db_HWInt;
//assign db_HWInt = HWInt;

/*(*mark_debug = "true"*)*/wire int_req = Status[2:0] == 3'b001 && (|(fullInt & Status[15:8]));
wire exc_req = (|ExcCodeIn);
assign Req_ori = {exc_req, int_req};
assign Req_exc = exc_req;
assign Req_int = (int_req && ready_int) || (int_buffer && ready_int && allow_int(fullInt_buf, Status));
assign Req = Req_exc || Req_int;
assign Req_Type = Req && (Req_ori == 2'b10 || exc_buffer == 2'b10) ? 1'b1 : 1'b0;
always @(posedge clk) begin
    if (reset) begin
		int_buffer <= 1'b0;
    end
    else begin
        if (int_req && !ready_int) begin
		int_buffer <= 1'b1;
		fullInt_buf <= fullInt;
        end
	else if (int_buffer && ready_int) begin
		int_buffer <= 1'b0;
		fullInt_buf <= '0;
	end
    end
end
//

assign EPCOut = (Req) ? (BDIn ? VPC - 4: VPC) : EPC;

//core read cp0 regs
assign CP0Out = (CP0Add == 0) ? Index : 
                 (CP0Add == 1) ? Random :
                 (CP0Add == 2) ? EntryLo0 : 
                 (CP0Add == 3) ? EntryLo1 : 
                 (CP0Add == 4) ? Context : 
                 (CP0Add == 5) ? PageMask : 
                 (CP0Add == 6) ? Wired : 
                 (CP0Add == 8) ? BadVAddr : 
                 (CP0Add == 9) ? Count : 
                 (CP0Add == 10) ? EntryHi : 
                 (CP0Add == 11) ? Compare : 
                 (CP0Add == 12) ? Status : 
				 (CP0Add == 13) ? {Cause[31:16], fullInt, Cause[7:0]} : 
				 (CP0Add == 14) ? EPC :  
				 (CP0Add == 15 && CP0Sel == 3'd0) ? `INIT_PRId : 
				 (CP0Add == 15 && CP0Sel == 3'd1) ? EBase : 
				 (CP0Add == 16 && CP0Sel == 3'd0) ? Conf0 : 
				 (CP0Add == 16 && CP0Sel == 3'd1) ? Conf1 : 
				 (CP0Add == 28 && CP0Sel == 3'd0) ? TagLo0 : 
				 (CP0Add == 29 && CP0Sel == 3'd0) ? TagHi0 : 
				 0;

always@ (posedge clk) begin
    if (reset) begin
        timer_int <= 0;
    end
    else begin
        if (clr_timer_int) begin
            timer_int <= 0;
        end
        else if (Count == Compare && Compare != 32'h0) begin
            timer_int <= 1;
        end
    end
end

reg add_count;
wire [`TLB_IDX_BITS - 1 : 0] Random_nxt = Random[`TLB_IDX_BITS - 1 : 0] + 1'b1;

always@ (posedge clk) begin
	if (reset) begin
        Index <= 0;
        Random <= `INIT_Random;
        EntryLo0 <= 0;
        EntryLo1 <= 0;
        Context <= 0;
        PageMask <= 0;
        Wired <= 0;
		BadVAddr <= 32'h0;
		Count <= 32'h0;
		EntryHi <= 0;
		Compare <= 32'h0;
		Status <= `INIT_Status;
		Cause <= 32'h0;
		EPC <= 32'h0;
		EBase <= `INIT_EBase;
		Conf0 <= `INIT_Conf0;
		Conf1 <= `INIT_Conf1;
		TagLo0 <= 0;
		TagHi0 <= 0;
		
		clr_timer_int <= 0;
		add_count <= 1'b0;
	end
	else begin
	    add_count <= ~add_count;
	    if (Req || !en || CP0Add != 9) begin
	       Count <= Count + {31'h0, add_count};
	    end
		`Cause_IP <= fullInt;

		if (EXLClr) begin
			Status[1] <= 1'b0;
		end

		if (Req) begin
			Status[1] <= 1'b1;
			Cause[6:2] <= Req_int ? 5'b0 : ExcCodeIn; 
			//Cause[31] <= BDIn;
			//EPC <= BDIn ? VPC - 4: VPC;
			//дBadVAddr
			BadVAddr <= (!Req_int && (ExcCodeIn == `AdEL || ExcCodeIn == `AdES || ExcCodeIn == `TLBL || ExcCodeIn == `TLBS || ExcCodeIn == `TLBMod)) ? BadVAddrIn : BadVAddr;
			Context[22:4] <= (!Req_int && (ExcCodeIn == `TLBL || ExcCodeIn == `TLBS || ExcCodeIn == `TLBMod)) ? BadVAddrIn[31:13] : Context[22:4];
			EntryHi[31:13] <= (!Req_int && (ExcCodeIn == `TLBL || ExcCodeIn == `TLBS || ExcCodeIn == `TLBMod)) ? BadVAddrIn[31:13] : EntryHi[31:13];
			
			if (!`SR_EXL) begin
                 Cause[31] <= BDIn;
			     EPC <= BDIn ? VPC - 4: VPC;
			end
		end
        else if (en) begin 
            /*if (CP0Add == 12) begin
                Status <= CP0In;
            end
			else if (CP0Add == 14) begin
				EPC <= CP0In;
			end
			else if (CP0Add == 9) begin
			    Count <= CP0In;
			end
			else if (CP0Add == 13) begin
			    Cause[9:8] <= CP0In[9:8]; //��IP[1:0]��д
			end
			else if (CP0Add == 11) begin //Compare
			    Compare <= CP0In;
			    clr_timer_int <= 1;
			end*/
			case (CP0Add)
			     0: begin
			         //tlb index
			         Index[`TLB_IDX_BITS - 1 : 0] <= CP0In[`TLB_IDX_BITS - 1:0];
			     end
			     2: begin
			         EntryLo0[25:0] <= CP0In[25:0];
			     end
			     3: begin
			         EntryLo1[25:0] <= CP0In[25:0];
			     end
			     4: begin
			         Context[31:23] <= CP0In[31:23];
			     end
			     5: begin
			         PageMask[28:13] <= CP0In[28:13];
			     end
			     6: begin
			         Wired[`TLB_IDX_BITS - 1:0] <= CP0In[`TLB_IDX_BITS - 1:0];
			         Random[`TLB_IDX_BITS - 1:0] <= `INIT_Random;
			     end
			     9: begin
			         Count <= CP0In;
			     end
			     10: begin
			         EntryHi[31:13] <= CP0In[31:13];
			         EntryHi[7:0] <= CP0In[7:0];
			     end
			     11: begin
			         Compare <= CP0In;
			         clr_timer_int <= 1;
			     end
			     12: begin
			         Status[28] <= CP0In[28];
			         Status[22] <= CP0In[22];
			         Status[15:8] <= CP0In[15:8];
			         Status[4] <= CP0In[4];
					 `ifdef USE_SIMULATOR
					 Status[2] <= CP0In[2];
					 `endif
			         Status[1:0] <= CP0In[1:0];
			     end
			     13: begin
			         Cause[23] <= CP0In[23];
			         Cause[9:8] <= CP0In[9:8];
			     end
			     14: begin
			         EPC <= CP0In;
			     end
			     15: begin
			         if (CP0Sel == 3'b001) begin
			             EBase[29:12] <= CP0In[29:12];
			         end
			     end
			     16: begin
			         if (CP0Sel == 3'b000) begin
			             Conf0[2:0] <= CP0In[2:0];
			         end
			     end
			     28: begin
			         if (CP0Sel == 3'b000) begin
			             TagLo0 <= CP0In;
			         end
			     end
			     default: begin
			     end
			endcase
		end
		else if (tlbr) begin
            EntryHi <= EntryHi_i;
            EntryLo0 <= EntryLo0_i;
            EntryLo1 <= EntryLo1_i;
            PageMask[11:0] <= PageMask_i;
		end
		else if (tlbp) begin
            Index <= Index_i;
		end
		else if (TLB_random) begin
            Random <= Random_nxt < Wired ? Wired : Random_nxt;
		end
		
		if (clr_timer_int) begin
		    clr_timer_int <= 0;
		end
	end
end
endmodule// : CP0
