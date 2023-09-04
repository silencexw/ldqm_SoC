//`include "cpu_macro.svh"
`define IDLE 0
`define CHECK 1
`define WAIT 2

`define BRANCH_MONITOR

module BVU #(
    
) (
    input   clk,
    input   reset,
    input   stall,
    input   stall_top,
    input   bru_info  way0_info,
    input   bru_info  way1_info,

    //output  bp_verify_info bp_verify,
    output  logic           update_valid,
    output  Update_Branch_S bp_verify,
    output  logic bp_fail
);

logic result;
logic true_branch;
Predict_Branch_S save_bp_info;
logic update_true_pc;
logic save_way0_unNone;
logic [31:0] true_pc;
logic [31:0] instr_pc;
logic true_able;
logic bvu_status;
BranchType_E save_branch_type;
/*
assign bp_verify.true_able = true_able;
assign bp_verify.true_pc = true_pc;
assign bp_verify.true_branch = true_branch;
assign bp_verify.instr_pc = {instr_pc[31:3], 3'b000};
assign update_valid = true_able;
assign bp_verify.PC_Vaild = true_able & save_way0_unNone;
assign bp_verify.PC_Taken = true_branch;
assign bp_verify.PC_MissPredict = ~result;
assign bp_verify.Way_Select = save_bp_info.Select;
assign bp_verify.Update_Location = instr_pc[2];
assign bp_verify.Counter = save_bp_info.Counter;
assign bp_verify.Update_PC = {instr_pc[31:3], 3'b000};
assign bp_verify.Update_Target = true_pc;
assign bp_verify.Predict_Target = save_bp_info.Target;
assign bp_verify.Predict_Location = save_bp_info.Location;
assign bp_verify.BranchType = save_branch_type;
assign bp_verify.Predict_BranchType = save_bp_info.BranchType;
*/

logic update_complete;
always_ff @(posedge clk) begin
    update_complete <= reset ? 1'b0 : 
                       ~update_complete && true_able && stall ? 1'b1 : 
                       update_complete && !stall ? 1'b0 : 
                       update_complete;
end
assign update_valid = true_able && !update_complete;

always_comb begin
    bp_verify.Update_True_PC = update_true_pc;
    bp_verify.PC_Vaild = update_valid && save_way0_unNone;
    if (update_true_pc) begin
        bp_verify.PC_Taken = true_branch;
        bp_verify.PC_MissPredict = ~result;
        bp_verify.Update_Target = true_pc;
    end
    else begin
        bp_verify.PC_Taken = '0;
        bp_verify.PC_MissPredict = 1'b1;
        bp_verify.Update_Target = instr_pc + 4;
    end
    bp_verify.Update_Location = instr_pc[2];
    bp_verify.TBT_Counter = save_bp_info.TBT_Counter;
    bp_verify.GHR_Counter = save_bp_info.GHR_Counter;
    bp_verify.Update_PC = {instr_pc[31:3], 3'b000};
    bp_verify.Predict_Target = save_bp_info.Target;
    bp_verify.Predict_Location = save_bp_info.Location;
    bp_verify.BranchType = save_branch_type;
    bp_verify.Predict_BranchType = save_bp_info.BranchType;
    bp_verify.Recover_GHR = save_bp_info.Recover_GHR;
    bp_verify.GHR = save_bp_info.GHR;
    bp_verify.CPHT = save_bp_info.CPHT;
end

assign bp_fail = ~result;
always_ff @(posedge clk) begin
    if (reset) begin
        bvu_status <= `IDLE;
        save_way0_unNone <= '0;
        true_branch <= '0;
        instr_pc <= '0;
        true_pc <= '0;
        save_bp_info <= '0;
        save_branch_type <= None;
        update_true_pc <= '0;
    end
    else if (!stall) begin
        if (bvu_status == `IDLE) begin
            if (way0_info.valid || way1_info.valid) begin
                //instr_pc <= way0_info.valid ? way0_info.pc : way1_info.pc;
                //save_way0_unNone <= way0_info.valid && way0_info.branch_type != None;
                //ensures branch instr is issued with delayslot instr so that branch instr must in way0
                if (way0_info.valid && way0_info.branch_type != None) begin
                    save_way0_unNone <= 1'b1;
                    instr_pc <= way0_info.pc;
                    true_branch <= way0_info.true_branch;
                    true_pc <= way0_info.true_pc;
                    save_bp_info <= way0_info.bp_info;
                    save_branch_type <= way0_info.branch_type;
                    update_true_pc <= 1'b1;
                end
                else if (way0_info.valid && way1_info.valid) begin
                    save_way0_unNone <= 1'b0;
                    instr_pc <= way0_info.update_true_pc ? way1_info.pc : way0_info.pc;
                    true_branch <= 1'b0;
                    true_pc <= way1_info.true_pc;
                    save_bp_info <= way0_info.bp_info;
                    save_branch_type <= way0_info.branch_type;
                    update_true_pc <= way0_info.update_true_pc & way1_info.update_true_pc;
                    save_bp_info <= way0_info.update_true_pc ? way1_info.bp_info : way0_info.bp_info;
                end
                else if (way0_info.valid) begin
                    save_way0_unNone <= 1'b0;
                    instr_pc <= way0_info.pc;
                    true_branch <= 1'b0;
                    true_pc <= way0_info.true_pc;
                    save_bp_info <= way0_info.bp_info;
                    save_branch_type <= way0_info.branch_type;
                    update_true_pc <= way0_info.update_true_pc;
                end
                else begin
                    save_way0_unNone <= 1'b0;
                    instr_pc <= way1_info.pc;
                    true_branch <= 1'b0;
                    true_pc <= way1_info.true_pc;
                    save_bp_info <= way1_info.bp_info;
                    save_branch_type <= way1_info.branch_type;
                    update_true_pc <= 1'b1;
                end
                bvu_status <= `CHECK;
            end
        end
        else if (bvu_status == `CHECK) begin
            if (!result) begin
                bvu_status <= `IDLE;
            end
            else if (way0_info.valid || way1_info.valid) begin
                //instr_pc <= way0_info.valid ? way0_info.pc : way1_info.pc;
                //save_way0_unNone <= way0_info.valid && way0_info.branch_type != None;
                //ensures branch instr is issued with delayslot instr so that branch instr must in way0
                if (way0_info.valid && way0_info.branch_type != None) begin
                    save_way0_unNone <= 1'b1;
                    instr_pc <= way0_info.pc;
                    true_branch <= way0_info.true_branch;
                    true_pc <= way0_info.true_pc;
                    save_bp_info <= way0_info.bp_info;
                    save_branch_type <= way0_info.branch_type;
                    update_true_pc <= 1'b1;
                end
                else if (way0_info.valid && way1_info.valid) begin
                    save_way0_unNone <= 1'b0;
                    instr_pc <= way0_info.update_true_pc ? way1_info.pc : way0_info.pc;
                    true_branch <= 1'b0;
                    true_pc <= way1_info.true_pc;
                    save_branch_type <= way0_info.branch_type;
                    update_true_pc <= way0_info.update_true_pc & way1_info.update_true_pc;
                    save_bp_info <= way0_info.update_true_pc ? way1_info.bp_info : way0_info.bp_info;
                end
                else if (way0_info.valid) begin
                    save_way0_unNone <= 1'b0;
                    instr_pc <= way0_info.pc;
                    true_branch <= 1'b0;
                    true_pc <= way0_info.true_pc;
                    save_bp_info <= way0_info.bp_info;
                    save_branch_type <= way0_info.branch_type;
                    update_true_pc <= way0_info.update_true_pc;
                end
                else begin
                    save_way0_unNone <= 1'b0;
                    instr_pc <= way1_info.pc;
                    true_branch <= 1'b0;
                    true_pc <= way1_info.true_pc;
                    save_bp_info <= way1_info.bp_info;
                    save_branch_type <= way1_info.branch_type;
                    update_true_pc <= 1'b1;
                end
                bvu_status <= `CHECK;
            end
            else begin
                bvu_status <= `CHECK;
            end
        end
        else begin
            bvu_status <= `IDLE;
        end
    end
end

always_comb begin
    if (bvu_status == `CHECK/* && !stall_top*//* &&!reset*/) begin
        result = way0_info.valid ? (way0_info.pc == true_pc) : 
                 way1_info.valid ? (way1_info.pc == true_pc) : 1'b1;
        true_able = way0_info.valid || way1_info.valid;
    end
    else begin
        result = 1'b1;
        true_able = 1'b0;
    end
end

`ifdef BRANCH_MONITOR
logic [31:0] total_branch;
logic [31:0] failed_branch;
logic bp_err;
always_ff @( posedge clk ) begin
    if (reset) begin
        total_branch <= '0;
        failed_branch <= '0;
        bp_err <= '0;
    end
    else begin
        if (way0_info.branch_type != None && ~stall) begin
            total_branch <= total_branch + 1;
        end

        if (bp_verify.PC_Vaild && bp_verify.PC_MissPredict) begin
            failed_branch <= failed_branch + 1;
        end
        
        if (bp_fail && ~bp_err) begin
            bp_err <= bp_verify.Update_Target == bp_verify.Predict_Target;
        end
    end
end

integer bp_trace;
initial begin
    bp_trace = $fopen("bp_trace.txt", "w");
end
always_ff @(posedge clk) begin
    if (bp_verify.PC_Vaild && ~stall && bp_verify.PC_MissPredict) begin
        $fdisplay(bp_trace, "PC_Vaild: %x, PC_Taken: %x, PC_MissPredict: %x,Time: %t", bp_verify.PC_Vaild, bp_verify.PC_Taken, bp_verify.PC_MissPredict,$time);
        $fdisplay(bp_trace, "Update_Location: %x, BHRCounter: %x, GHRCounter: %x", bp_verify.Update_Location, bp_verify.TBT_Counter,bp_verify.GHR_Counter);
        $fdisplay(bp_trace, "GHR:%x", bp_verify.GHR);
        $fdisplay(bp_trace, "Update_PC: %x, Update_Target: %x, Predict_Target: %x", bp_verify.Update_PC, bp_verify.Update_Target, bp_verify.Predict_Target);
        $fdisplay(bp_trace, "Predict_Location: %x, BranchType: %x, Predict_BranchType: %x\n", bp_verify.Predict_Location, bp_verify.BranchType, bp_verify.Predict_BranchType);
    end
end
`endif
endmodule