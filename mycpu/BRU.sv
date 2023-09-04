`timescale 1ns/1ps
`include "Predict_defs.svh"
//`include "cpu_macro.svh"
`include "InstrDefine.svh"

module BRU (
    input instr_info    instr,
    input logic [31:0]  rd_reg1,
    input logic [31:0]  rd_reg2,

    output bru_info     bru_res,
    output wr_reg_info  bru_wr_reg,
    output logic       likely_flush
);

logic condition; //1: jump, 0: not jump
logic [31:0] if_jump_target; // the target pc if jump
BranchType_E branch_type;

assign bru_res.valid = instr.valid;
assign bru_res.pc = instr.pc;
assign bru_res.true_pc = condition ? (if_jump_target == instr.pc + 4 ? instr.pc + 8 : if_jump_target) : 
                          instr.bru_ctrl != `pc4_bru && instr.bru_ctrl != `eret_bru ? instr.pc + 8 : 
                          instr.pc + 4;// branch instr is issued with delayslot instr
assign bru_res.true_branch = condition;
assign bru_res.update_true_pc = instr.update_true_pc;
assign likely_flush = ~condition && instr.is_likely;
/*
assign bru_res.branch_type = (!instr.valid) ? None : 
                             (instr.op.bru_op == `pc4_bru) ? None : //non-jump instr
                             (instr.op.bru_op == `eret_bru) ? None : //non-delayslot jump, don't care eret
                             2; //delayslot jump
*/
assign bru_res.branch_type = branch_type;
assign bru_res.bp_info = instr.bp_info;

always_comb begin
    case (instr.bru_ctrl)
        `j_bru: condition = 1;
        `jr_bru: condition = 1;
        `beq_bru: condition = rd_reg1 == rd_reg2;
        `bne_bru: condition = rd_reg1 != rd_reg2;
        `blez_bru: condition = rd_reg1 == 0 || rd_reg1[31];
        `bgtz_bru: condition = rd_reg1 != 0 && ~rd_reg1[31];
        `bltz_bru, `bltzal_bru: condition = rd_reg1[31];
        `bgez_bru, `bgezal_bru: condition = ~rd_reg1[31];
        default: condition = 0;
    endcase

    case (instr.bru_ctrl)
        `j_bru: if_jump_target = {instr.pc[31:28], instr.imm26, 2'b00};
        `jr_bru: if_jump_target = rd_reg1;
        `beq_bru, `bne_bru, `blez_bru, `bgtz_bru, 
        `bltz_bru, `bltzal_bru, `bgez_bru, `bgezal_bru: if_jump_target = instr.pc + 4 + {{14{instr.imm[15]}}, instr.imm, 2'b00};
        default: if_jump_target = instr.pc + 4;
    endcase
    
    case (instr.bru_ctrl)
        `j_bru: begin
            if (instr.opcode == `jal) begin
                bru_wr_reg.addr = 31;
                bru_wr_reg.data = instr.pc + 8;
                bru_wr_reg.Tnew = `BRU_GEN;

                branch_type = Call;
            end
            else begin
                bru_wr_reg.addr = 0;
                bru_wr_reg.data = 0;
                bru_wr_reg.Tnew = `NOT_WRITE;
                
                branch_type = Jump;
            end
        end
        `jr_bru: begin
            if (instr.funct == `jalr) begin
                bru_wr_reg.addr = instr.rf_ctrl.wr_reg.addr;
                bru_wr_reg.data = instr.pc + 8;
                bru_wr_reg.Tnew = `BRU_GEN;

                branch_type = Call;
            end
            else begin
                bru_wr_reg.addr = 0;
                bru_wr_reg.data = 0;
                bru_wr_reg.Tnew = `NOT_WRITE;

                branch_type = instr.rf_ctrl.rd_reg1.src == 1'b0 && instr.rf_ctrl.rd_reg1.addr == 5'd31 ? Return : Jump;
            end
        end
        `bltzal_bru, `bgezal_bru: begin
            bru_wr_reg.addr = 31;
            bru_wr_reg.data = instr.pc + 8;
            bru_wr_reg.Tnew = `BRU_GEN;

            branch_type = Call;
        end
        default: begin
            bru_wr_reg.addr = 0;
            bru_wr_reg.data = 0;
            bru_wr_reg.Tnew = `NOT_WRITE;

            branch_type = instr.is_branch ? Branch : None;
        end
    endcase
end

endmodule