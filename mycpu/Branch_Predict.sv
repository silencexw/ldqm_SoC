`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/05 09:51:15
// Design Name: 
// Module Name: Branch_Predict
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


module Branch_Predict # (
        parameter int SIZE = 4096
        )
        (
        input logic clk,                           //clk
        input logic reset,                         //reset
        input Vaddr Now_PC,
        input logic stall,
        input Recover_Decode_S Recover_Decode,
        input Update_Branch_S Update_Predict,
        output Predict_Branch_S Predict_Branch
    );

//===============================Logic Define===================================
Predict_BTB_S Predict_BTB;
Predict_PHT_S Predict_PHT;
Update_BTB_S Update_BTB;
Update_PHT_S Update_PHT;
logic Predict_Branch_Vaild;
TwoBitState Predict_Counter;
logic Type_Coupled;
Vaddr True_PC;
logic Predict_If_Branch;
logic Predict_Branch_Right_Now;
logic Predict_Branch_Delay_Now;
Vaddr Delay_Target;
Vaddr Delay_True_PC;
logic Update_If_Branch;
logic First_Inst_Is_Fake;
logic Second_Inst_Is_Fake;
//===============================Logic Define===================================

//===============================Comb Logic=====================================
assign Predict_If_Branch = ((Predict_BTB.BranchType == Branch 
                                    && (Predict_Counter == 2'd2 || Predict_Counter == 2'd3)) 
                                    || Predict_BTB.BranchType == Call || Predict_BTB.BranchType == Return || Predict_BTB.BranchType == Jump) ? 1'b1 : 1'b0;
assign Predict_Branch_Right_Now = (Predict_If_Branch && (Predict_BTB.Predict_Location == 1'b0) ) ? 1'b1 : 1'b0;
assign Update_If_Branch =  (Update_Predict.PC_Vaild && Update_Predict.PC_MissPredict && Update_Predict.Update_True_PC) ? 1'b1 : 1'b0;
                      
always_comb begin
    if (Update_If_Branch) begin
        True_PC = Update_BTB.Update_Target & 32'hffff_fff8;
    end else if (Recover_Decode.Vaild) begin
        True_PC = Recover_Decode.Target & 32'hffff_fff8;    
    end else if (stall) begin
        True_PC = Delay_True_PC;    
    end else if (Predict_Branch_Right_Now && !First_Inst_Is_Fake) begin
        True_PC = Predict_BTB.Target& 32'hffff_fff8;    
    end else if (Predict_Branch_Delay_Now) begin
        True_PC = Delay_Target & 32'hffff_fff8;    
    end else begin
        True_PC = Now_PC + 8;    
    end
end          



assign Update_BTB.PC_Vaild = Update_Predict.PC_Vaild;
assign Update_BTB.PC_Taken = Update_Predict.PC_Taken;
assign Update_BTB.Update_PC = Update_Predict.Update_PC;
assign Update_BTB.Update_Target = Update_Predict.Update_Target;
assign Update_BTB.BranchType = Update_Predict.BranchType;
assign Update_BTB.PC_MissPredict = Update_Predict.PC_MissPredict;
assign Update_BTB.Update_Location = Update_Predict.Update_Location;

assign Update_PHT.PC_Vaild = (Update_Predict.BranchType == Branch) ? Update_Predict.PC_Vaild : '0;
assign Update_PHT.PC_Taken = Update_Predict.PC_Taken;
assign Update_PHT.PC_MissPredict= Update_Predict.PC_MissPredict;
assign Update_PHT.TBT_Counter = Update_Predict.TBT_Counter;
assign Update_PHT.GHR_Counter = Update_Predict.GHR_Counter;
assign Update_PHT.Update_PC = Update_Predict.Update_PC;
assign Update_PHT.Recover_GHR = Update_Predict.Recover_GHR;
assign Update_PHT.GHR = Update_Predict.GHR;
assign Update_PHT.CPHT = Update_Predict.CPHT;

assign Predict_Branch.PC_Vaild = (Predict_BTB.BranchType != None);
assign Predict_Branch.Target = (Predict_BTB.BranchType == Branch 
                                    && (Predict_Counter == 2'b00 || Predict_Counter == 2'b01)) 
                                        ? Predict_BTB.Delay_PC + 8 : Predict_BTB.Target;
assign Predict_Branch.BranchType = Predict_BTB.BranchType;
assign Predict_Branch.TBT_Counter = Predict_PHT.TBT_Counter;
assign Predict_Branch.GHR_Counter = Predict_PHT.GHR_Counter;
assign Predict_Branch.Location = Predict_BTB.Predict_Location;
assign Predict_Branch.Recover_GHR = Predict_PHT.Recover_GHR;
assign Predict_Branch.GHR = Predict_PHT.GHR;
assign Predict_Branch.CPHT = Predict_PHT.CPHT;

assign Predict_Branch_Vaild = (Predict_BTB.BranchType == Branch) ? 1'b1 : 1'b0;
assign Predict_Counter = (Predict_PHT.CPHT == 2'd0 || Predict_PHT.CPHT == 2'd1) ? Predict_PHT.GHR_Counter : Predict_PHT.TBT_Counter;
assign TBT_Used  = (Predict_PHT.CPHT == 2'd2 || Predict_PHT.CPHT == 2'd3) ?  1'b1 : 1'b0;
assign TBT_Taken = (Predict_Counter  == 2'd2 || Predict_Counter  == 2'd3) ?  1'b1 : 1'b0;
assign Type_Coupled = (Update_Predict.BranchType == Update_Predict.Predict_BranchType);
//===============================Comb Logic=====================================

//=================================FF Logic=====================================
always_ff @(posedge clk) begin
    if (reset) begin
        Predict_Branch_Delay_Now <= 1'b0; 
        Delay_Target <= 32'd0;
    end else if (stall) begin
        Predict_Branch_Delay_Now <= Predict_Branch_Delay_Now;
        Delay_Target <= Delay_Target;
    end else if (Predict_If_Branch && (Predict_BTB.Predict_Location == 1'b1) 
                    && !Update_If_Branch && (Now_PC + 8 != {Predict_BTB.Target[31:3],3'd0})
                        && !Second_Inst_Is_Fake && !Recover_Decode.Vaild) begin
        Predict_Branch_Delay_Now <= 1'b1;
        Delay_Target <= Predict_BTB.Target;
    end else begin
        Predict_Branch_Delay_Now <= 1'b0;
        Delay_Target <= 32'd0;
    end
end


always_ff @(posedge clk) begin
    if (reset) begin
        Second_Inst_Is_Fake <= 1'b0;
    end else if (stall) begin
        Second_Inst_Is_Fake <= Second_Inst_Is_Fake;
    end else if (Predict_If_Branch && (Predict_BTB.Predict_Location == 1'b1) && (True_PC == Now_PC + 8)) begin
        Second_Inst_Is_Fake <= 1'b1;
    end else begin
        Second_Inst_Is_Fake <= 1'b0;
    end
end


always_ff @(posedge clk) begin
    if (reset) begin
        First_Inst_Is_Fake <= 1'b0;
    end else if (Update_If_Branch && (Update_Predict.Update_Target[2:0] != '0) && (True_PC == Update_Predict.Update_Target)) begin
        First_Inst_Is_Fake <= 1'b1;
    end else if (Recover_Decode.Vaild && (Recover_Decode.Target[2:0] != '0) && (True_PC == Recover_Decode.Target)) begin
        First_Inst_Is_Fake <= 1'b1;
    end else if (stall) begin
        First_Inst_Is_Fake <= First_Inst_Is_Fake;
    end else if ( Predict_Branch_Right_Now && (Predict_Branch.Target[2:0] != '0) && (True_PC == {Predict_BTB.Target[31:3],3'd0})) begin
        First_Inst_Is_Fake <= 1'b1;
    end else if ( Predict_Branch_Delay_Now && (Delay_Target[2:0] != '0) && (True_PC == {Delay_Target[31:3],3'd0})) begin
        First_Inst_Is_Fake <= 1'b1;
    end else begin
        First_Inst_Is_Fake <= 1'b0;
    end
end


always_ff @(posedge clk) begin
    if (reset) begin
        Delay_True_PC <= 32'hBFC0_0008;
    end else begin
        Delay_True_PC <= True_PC;
    end
end
//=================================FF Logic=====================================


//===============================Model Used======================================
BTB #(
    .SIZE ( SIZE )
) btb (
    .clk,
    .reset,
    .Now_PC(True_PC),
    .Update_BTB,
    .Predict_BTB,
    .stall
);

PHT #(
    .SIZE ( SIZE )
) pht (
    .clk,
    .reset,
    .Now_PC(True_PC),
    .Update_PHT,
    .Predict_PHT,
    .Predict_Branch_Vaild,
    .GHR_Type_Coupled(Type_Coupled),
    .TBT_Used,
    .TBT_Taken,
    .stall
);

//===============================Model Used======================================
endmodule
