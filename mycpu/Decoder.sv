`timescale 1ns/1ps
//`include "cpu_macro.svh"
`include "InstrDefine.svh"
`define RUN_FUNC_TEST
module Decoder #(
    parameter CTRL_EXTEND_INST_SET = 1'b0
) (
    input logic en,
    input logic [31:0] instr,
    input logic [31:0] pc,
    input logic delayslot,
    input Predict_Branch_S bp_info,
    output instr_info instr_d
);

function logic[5:0] rf_addr_ext(input logic [4:0] ori_lrf_addr);
    return {1'b0, ori_lrf_addr};
endfunction

wire [5:0] rs = rf_addr_ext(instr[25:21]);
wire [5:0] rt = rf_addr_ext(instr[20:16]);
wire [5:0] rd = rf_addr_ext(instr[15:11]);
wire [5:0] opcode = instr[31:26];
wire [5:0] funct = instr[5:0];
wire [4:0] s = instr[10:6];
wire [15:0] imm = instr[15:0];

if (CTRL_EXTEND_INST_SET) begin
always_comb begin
    if (en) begin
        instr_d = '0;//prevent warning
        instr_d.valid = en;
        //instr_d.code = instr;
        instr_d.opcode = opcode;
        instr_d.funct = funct;
        instr_d.s = s;
        instr_d.imm = instr[15:0];
        instr_d.extimm = {{16{instr[15]}}, instr[15:0]};
        instr_d.imm26 = instr[25:0];

        instr_d.pc = pc;
        instr_d.in_delayslot = delayslot;
        instr_d.bad_va_addr = '0;
        
        case (instr[31:26])
            `SPECIAL: begin
                case (instr[5:0])
                    `add, `addu, `sub, `subu, 
                    `or, `and, `xor, `nor,
                    `slt, `sltu: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `ALU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `ALU_USE;

                        instr_d.rf_ctrl.wr_reg.addr = rd;
                        instr_d.rf_ctrl.wr_reg.src = 0;

                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.alu_ctrl.alu_en = 1;
                        case (funct)
                            `add, `addu: instr_d.alu_ctrl.alu_op = `ADD;
                            `sub, `subu: instr_d.alu_ctrl.alu_op = `SUB;
                            `or: instr_d.alu_ctrl.alu_op = `OR;
                            `and: instr_d.alu_ctrl.alu_op = `AND;
                            `xor: instr_d.alu_ctrl.alu_op = `XOR;
                            `nor: instr_d.alu_ctrl.alu_op = `NOR;
                            `slt: instr_d.alu_ctrl.alu_op = `SLT;
                            `sltu: instr_d.alu_ctrl.alu_op = `SLTU;
                            default: instr_d.alu_ctrl.alu_op = 0;
                        endcase
                        instr_d.alu_ctrl.check_ov = funct == `add || funct == `sub;
                        instr_d.alu_ctrl.src_a = 0;
                        instr_d.alu_ctrl.src_b = 0;
                        instr_d.mem_ctrl = '0;
                        instr_d.cache_op = '0;
                        instr_d.tlb_ctrl = '0;
                        instr_d.exc_code = 0;
                    end
                    `sll, `srl, `sra, `sllv, `srlv, `srav: begin
                        instr_d.rf_ctrl.rd_reg1.addr = (funct > `sra) ? rs : 0;
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.Tuse1 = (funct > `sra) ? `ALU_USE : `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.Tuse2 = `ALU_USE;
                        instr_d.rf_ctrl.wr_reg.addr = rd;
                        instr_d.rf_ctrl.wr_reg.src = 0;

                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.alu_ctrl.alu_en = 1;
                        case (funct)
                            `sll, `sllv: instr_d.alu_ctrl.alu_op = `LL;
                            `srl, `srlv: instr_d.alu_ctrl.alu_op = `RL;
                            `sra, `srav: instr_d.alu_ctrl.alu_op = `RA; 
                            default: instr_d.alu_ctrl.alu_op = 0;
                        endcase
                        instr_d.alu_ctrl.src_a = (funct > `sra) ? 0 : 1;
                        instr_d.alu_ctrl.src_b = 0;
                        instr_d.exc_code = 0;
                    end
                    `mult, `multu, `div, `divu: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `MDU_USE;
                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        case (funct)
                            `mult: instr_d.mdu_ctrl.mdu_op = `MULT;
                            `multu: instr_d.mdu_ctrl.mdu_op = `MULTU;
                            `div: instr_d.mdu_ctrl.mdu_op = `DIV;
                            `divu: instr_d.mdu_ctrl.mdu_op = `DIVU; 
                            default: instr_d.mdu_ctrl.mdu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    `mfhi, `mflo: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = funct == `mfhi ? 33 : 34;
                        instr_d.rf_ctrl.Tuse1 = `LRF_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = 0;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = rd;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        instr_d.mdu_ctrl.mdu_op = funct == `mfhi ? `MFHI : `MFLO;
                        instr_d.exc_code = 0;
                    end
                    `mthi, `mtlo: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = funct == `mthi ? 33 : 34;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        instr_d.mdu_ctrl.mdu_op = funct == `mthi ? `MTHI : `MTLO;
                        instr_d.exc_code = 0;
                    end
                    `jalr, `jr: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = funct == `jalr ? rd : 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `jr_bru;
                        instr_d.exc_code = 0;
                    end
                    `break, `syscall: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = (funct == `break) ? `Bp : `Syscall;
                    end
                    `ifdef EXTEND_INST_SET 
                    `sync: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `Int;
                    end
                    `teq, `tne, `tge, `tgeu, `tlt, `tltu: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `TRAP_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `TRAP_USE;
                        
                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;
                        
                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        
                        instr_d.trap_ctrl.trap_en = 1;
                        instr_d.trap_ctrl.src_b = 0;
                        case (funct)
                            `teq: instr_d.trap_ctrl.trap_op = `EQ_trap;
                            `tne: instr_d.trap_ctrl.trap_op = `NE_trap;
                            `tge: instr_d.trap_ctrl.trap_op = `GE_trap;
                            `tgeu: instr_d.trap_ctrl.trap_op = `GEU_trap;
                            `tlt: instr_d.trap_ctrl.trap_op = `LT_trap;
                            `tltu: instr_d.trap_ctrl.trap_op = `LTU_trap;
                            default: instr_d.trap_ctrl.trap_op = '0;
                        endcase
                        
                        instr_d.exc_code = `Tr;
                    end
                    `movz, `movn: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `ALU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `ALU_USE;

                        instr_d.rf_ctrl.wr_reg.addr = rd;
                        instr_d.rf_ctrl.wr_reg.src = 0;

                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.alu_ctrl.alu_en = 1;
                        case (funct)
                            `movz: instr_d.alu_ctrl.alu_op = `MOVZ;
                            `movn: instr_d.alu_ctrl.alu_op = `MOVN;
                            default: instr_d.alu_ctrl.alu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    `endif
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `ifdef EXTEND_INST_SET
            `SPECIAL2: begin
                case (funct)
                    `madd, `maddu, `msub, `msubu, `mul: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `MDU_USE;
                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = funct == `mul ? rd : '0;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        case (funct)
                            `madd: instr_d.mdu_ctrl.mdu_op = `MADD;
                            `maddu: instr_d.mdu_ctrl.mdu_op = `MADDU;
                            `msub: instr_d.mdu_ctrl.mdu_op = `MSUB;
                            `msubu: instr_d.mdu_ctrl.mdu_op = `MSUBU; 
                            `mul: instr_d.mdu_ctrl.mdu_op = `MUL;
                            default: instr_d.mdu_ctrl.mdu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    `clo, `clz: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `ALU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.addr = rd;
                        instr_d.rf_ctrl.wr_reg.src = 0;

                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.alu_ctrl.alu_en = 1;
                        case (funct)
                            `clo: instr_d.alu_ctrl.alu_op = `CLO;
                            `clz: instr_d.alu_ctrl.alu_op = `CLZ;
                            default: instr_d.alu_ctrl.alu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `else
            `SPECIAL2: begin
                case (funct)
                    `mul: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `MDU_USE;
                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = rd;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        case (funct)
                            `mul: instr_d.mdu_ctrl.mdu_op = `MUL;
                            default: instr_d.mdu_ctrl.mdu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `endif
            `ori, `addi, `addiu, `andi, `slti, `sltiu, `xori: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `ALU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;
                
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.alu_ctrl.alu_en = 1;
                instr_d.alu_ctrl.alu_op = (opcode == `ori) ? `OR : 
                                    (opcode == `addi || opcode == `addiu) ? `ADD : 
                                    (opcode == `andi) ? `AND : 
                                    (opcode == `slti) ? `SLT : 
                                    (opcode == `sltiu) ? `SLTU : 
                                    (opcode == `xori) ? `XOR : 0;
                instr_d.alu_ctrl.check_ov = (opcode == `addi);
                instr_d.alu_ctrl.src_a = 0;
                instr_d.alu_ctrl.src_b = 1;
                instr_d.alu_ctrl.sign_b = opcode == `addi || opcode == `addiu || opcode == `slti || opcode == `sltiu;
                instr_d.exc_code = 0;
            end
            `lui: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = 0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;

                instr_d.alu_ctrl.alu_en = 1;
                instr_d.alu_ctrl.alu_op = `LUI;
                instr_d.alu_ctrl.check_ov = 0;
                instr_d.alu_ctrl.src_b = 1;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.exc_code = 0;
            end
            `beq, `bne
            `ifdef EXTEND_INST_SET
            , `beql, `bnel
            `endif
            : begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = rt;
                instr_d.rf_ctrl.Tuse2 = `BRU_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = (opcode == `beq || opcode == `beql) ? `beq_bru : 
                                    (opcode == `bne || opcode == `bnel) ? `bne_bru : 0;
                instr_d.exc_code = 0;
            end
            `blez, `bgtz
            `ifdef EXTEND_INST_SET
            , `blezl, `bgtzl
            `endif
            : begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = (opcode == `blez || opcode == `blezl) ? `blez_bru : 
                                    (opcode == `bgtz || opcode == `bgtzl) ? `bgtz_bru : 0;
                instr_d.exc_code = 0;
            end
            `RT: begin
                case (rt)
                    `bltz, `bgez
                    `ifdef EXTEND_INST_SET
                    , `bltzl, `bgezl
                    `endif
                    : begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = (rt == `bltz || rt == `bltzl) ? `bltz_bru : 
                                            (rt == `bgez || rt == `bgezl) ? `bgez_bru : 0;
                        instr_d.exc_code = 0;
                    end 
                    `bltzal, `bgezal
                    `ifdef EXTEND_INST_SET
                    , `bltzall, `bgezall
                    `endif
                    : begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 31;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = (rt == `bltzal || rt == `bltzall) ? `bltzal_bru : 
                                            (rt == `bgezal || rt == `bgezall) ? `bgezal_bru : '0;
                        instr_d.exc_code = 0;
                    end
                    `ifdef EXTEND_INST_SET
                    `teqi, `tnei, `tgei, `tgeiu, `tlti, `tltiu: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `TRAP_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.trap_ctrl.trap_en = 1;
                        instr_d.trap_ctrl.src_b = 1;
                        case (rt)
                            `teqi: instr_d.trap_ctrl.trap_op = `EQ_trap;
                            `tnei: instr_d.trap_ctrl.trap_op = `NE_trap;
                            `tgei: instr_d.trap_ctrl.trap_op = `GE_trap;
                            `tgeiu: instr_d.trap_ctrl.trap_op = `GEU_trap;
                            `tlti: instr_d.trap_ctrl.trap_op = `LT_trap;
                            `tltiu: instr_d.trap_ctrl.trap_op = `LTU_trap;
                            default: instr_d.trap_ctrl.trap_op = '0;
                        endcase

                        instr_d.exc_code = `Tr;
                    end 
                    `endif
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `lw, `lh, `lhu, `lb, `lbu
            `ifdef EXTEND_INST_SET
            , `lwl, `lwr, `ll
            `endif
            : begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `AGU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = (opcode == `lwr || opcode == `lwl) ? rt : 0;
                instr_d.rf_ctrl.Tuse2 = (opcode == `lwr || opcode == `lwl) ? `MEM_USE : `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.mem_ctrl.acc_mem = 1'b1;
                instr_d.mem_ctrl.wr_mem = 1'b0;
                case (opcode)
                    `lb, `lbu: instr_d.mem_ctrl.size = 2'b0;
                    `lh, `lhu: instr_d.mem_ctrl.size = 2'b1;
                    `lw, `ll, `lwl, `lwr: instr_d.mem_ctrl.size = 2'b10;
                    default: instr_d.mem_ctrl.size = 2'b0;
                endcase
                instr_d.mem_ctrl.rdata_sign = (opcode == `lbu || opcode == `lhu) ? 1'b0 : 1'b1;
                instr_d.mem_ctrl.set_LLbit = (opcode == `ll);
                instr_d.mem_ctrl.unalign_left = (opcode == `lwl);
                instr_d.mem_ctrl.unalign_right = (opcode == `lwr);

                instr_d.exc_code = 0;
            end
            `sw, `sh, `sb
            `ifdef EXTEND_INST_SET
            , `swl, `swr
            `endif
            : begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `AGU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = rt;
                instr_d.rf_ctrl.Tuse2 = `AGU_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;

                instr_d.mem_ctrl.acc_mem = 1'b1;
                instr_d.mem_ctrl.wr_mem = 1'b1;
                case (opcode)
                    `sw, `swl, `swr: begin
                        instr_d.mem_ctrl.size = 2'b10;
                    end 
                    `sh: begin
                        instr_d.mem_ctrl.size = 2'b1;
                    end
                    `sb: begin
                        instr_d.mem_ctrl.size = 2'b0;
                    end
                    default: instr_d.mem_ctrl.size = 2'b0; 
                endcase
                instr_d.mem_ctrl.unalign_left = (opcode == `swl);
                instr_d.mem_ctrl.unalign_right = (opcode == `swr);

                instr_d.exc_code = 0;
            end
            `ifdef EXTEND_INST_SET
            `pref: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = '0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = '0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = '0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.exc_code = 0;
            end
            `sc: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `AGU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = rt;
                instr_d.rf_ctrl.Tuse2 = `AGU_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.mem_ctrl.acc_mem = 1'b1;
                instr_d.mem_ctrl.wr_mem = 1'b1;
                instr_d.mem_ctrl.size = 3'b010;
                instr_d.mem_ctrl.read_LLbit = 1'b1;
                instr_d.exc_code = 0;
            end
            `endif
            `j, `jal: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = 0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = (opcode == `jal) ? 31 : 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `j_bru;
                instr_d.exc_code = 0;
            end
            `RS: begin
                case (rs)
                    `mfc0: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 1;
                        instr_d.rf_ctrl.rd_reg2.addr = rd;
                        instr_d.rf_ctrl.Tuse2 = `LRF_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = rt;

                        instr_d.cp0_ctrl.cp0_en = 1'b1;
                        instr_d.cp0_ctrl.wr_cp0 = 1'b0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.exc_code = 0;
                    end 
                    `mtc0: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `CP0_USE;

                        instr_d.rf_ctrl.wr_reg.src = 1;
                        instr_d.rf_ctrl.wr_reg.addr = rd;

                        instr_d.cp0_ctrl.cp0_en = 1'b1;
                        instr_d.cp0_ctrl.wr_cp0 = 1'b1;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.exc_code = 0;
                    end
                    `cop0: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = (funct == `eret) ? `eret_bru : `pc4_bru;
                        case (funct)
                            `eret: instr_d.tlb_ctrl = `TLB_None;
                            `ifdef EXTEND_INST_SET
                            `tlbp: instr_d.tlb_ctrl = `TLB_Probe;
                            `tlbr: instr_d.tlb_ctrl = `TLB_Read;
                            `tlbwi: instr_d.tlb_ctrl = `TLB_WI;
                            `tlbwr: instr_d.tlb_ctrl = `TLB_WR;
                            `endif
                            default: instr_d.tlb_ctrl = `TLB_None; 
                        endcase
                        instr_d.exc_code = 0;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `ifdef EXTEND_INST_SET
            `cache: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `AGU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;
                
                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;
                
                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.cache_op.valid = 1'b1;
                instr_d.cache_op.target = rt[1:0] == 2'b00 ? 1'b0 : 
                                             rt[1:0] == 2'b01 ? 1'b1 : 1'b0;
                instr_d.cache_op.op = rt[4:2] == 3'b000 ? 1'b0 : 
                                         rt[4:2] == 3'b100 ? 1'b1 : 
                                         rt[4:2] == 3'b101 ? 1'b1 : 1'b0;
                instr_d.cache_op.wb = rt[4:2] == 3'b000 ? 1'b1 : 
                                         rt[4:2] == 3'b100 ? 1'b0 : 
                                         rt[4:2] == 3'b101 ? 1'b1 : 1'b0;
                        
                instr_d.exc_code = 0;
            end
            `endif
            default: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = 0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;

                instr_d.exc_code = `RI;            
            end
        endcase
        
        instr_d.is_priv = instr_d.exc_code != `Int || instr_d.opcode == `RS || instr_d.opcode == `cache || instr == 32'h40;
        instr_d.is_branch = instr_d.is_priv ? 0 : 
                            instr_d.bru_ctrl != `pc4_bru;
        instr_d.is_likely = ~instr_d.is_branch ? '0 : 
                            instr_d.opcode[5:2] == 4'b0101 ? 1'b1 : 
                            instr_d.opcode == `RT && (rt[4:1] == 4'b0001 || rt[4:1] == 4'b1001) ? 1'b1 : 
                            1'b0;
        instr_d.is_accmem = instr_d.is_priv ? 0 : 
                            instr_d.opcode >= `lb && instr_d.opcode <= `sc && instr_d.opcode != `pref || instr_d.opcode == `cache;
        instr_d.is_md = instr_d.is_priv ? 0 :
                        instr_d.mdu_ctrl.mdu_en;
        instr_d.wr_md = instr_d.is_md && instr_d.mdu_ctrl.mdu_op != `MFLO && instr_d.mdu_ctrl.mdu_op != `MFHI && instr_d.mdu_ctrl.mdu_op != `MUL;
        instr_d.is_cal = instr_d.is_priv ? 0 : 
                          instr_d.opcode == 0 && (instr_d.funct >= 0 && instr_d.funct <= 7 || instr_d.funct >= 32 && instr_d.funct <= 43) ||
                         (instr_d.opcode >= 8 && instr_d.opcode <= 15);

        instr_d.bp_info = bp_info;
    end
    else begin
        instr_d = '0;
    end
end
end

else begin
always_comb begin
    if (en) begin
        instr_d = '0;//prevent warning
        instr_d.valid = en;
        //instr_d.code = instr;
        instr_d.opcode = opcode;
        instr_d.funct = funct;
        instr_d.s = s;
        instr_d.imm = instr[15:0];
        instr_d.extimm = {{16{instr[15]}}, instr[15:0]};
        instr_d.imm26 = instr[25:0];

        instr_d.pc = pc;
        instr_d.in_delayslot = delayslot;
        instr_d.bad_va_addr = '0;
        
        case (instr[31:26])
            `SPECIAL: begin
                case (instr[5:0])
                    `add, `addu, `sub, `subu, 
                    `or, `and, `xor, `nor,
                    `slt, `sltu: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `ALU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `ALU_USE;

                        instr_d.rf_ctrl.wr_reg.addr = rd;
                        instr_d.rf_ctrl.wr_reg.src = 0;

                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.alu_ctrl.alu_en = 1;
                        case (funct)
                            `add, `addu: instr_d.alu_ctrl.alu_op = `ADD;
                            `sub, `subu: instr_d.alu_ctrl.alu_op = `SUB;
                            `or: instr_d.alu_ctrl.alu_op = `OR;
                            `and: instr_d.alu_ctrl.alu_op = `AND;
                            `xor: instr_d.alu_ctrl.alu_op = `XOR;
                            `nor: instr_d.alu_ctrl.alu_op = `NOR;
                            `slt: instr_d.alu_ctrl.alu_op = `SLT;
                            `sltu: instr_d.alu_ctrl.alu_op = `SLTU;
                            default: instr_d.alu_ctrl.alu_op = 0;
                        endcase
                        instr_d.alu_ctrl.check_ov = funct == `add || funct == `sub;
                        instr_d.alu_ctrl.src_a = 0;
                        instr_d.alu_ctrl.src_b = 0;
                        instr_d.mem_ctrl = '0;
                        instr_d.cache_op = '0;
                        instr_d.tlb_ctrl = '0;
                        instr_d.exc_code = 0;
                    end
                    `sll, `srl, `sra, `sllv, `srlv, `srav: begin
                        instr_d.rf_ctrl.rd_reg1.addr = (funct > `sra) ? rs : 0;
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.Tuse1 = (funct > `sra) ? `ALU_USE : `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.Tuse2 = `ALU_USE;
                        instr_d.rf_ctrl.wr_reg.addr = rd;
                        instr_d.rf_ctrl.wr_reg.src = 0;

                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.alu_ctrl.alu_en = 1;
                        case (funct)
                            `sll, `sllv: instr_d.alu_ctrl.alu_op = `LL;
                            `srl, `srlv: instr_d.alu_ctrl.alu_op = `RL;
                            `sra, `srav: instr_d.alu_ctrl.alu_op = `RA; 
                            default: instr_d.alu_ctrl.alu_op = 0;
                        endcase
                        instr_d.alu_ctrl.src_a = (funct > `sra) ? 0 : 1;
                        instr_d.alu_ctrl.src_b = 0;
                        instr_d.exc_code = 0;
                    end
                    `mult, `multu, `div, `divu: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `MDU_USE;
                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        case (funct)
                            `mult: instr_d.mdu_ctrl.mdu_op = `MULT;
                            `multu: instr_d.mdu_ctrl.mdu_op = `MULTU;
                            `div: instr_d.mdu_ctrl.mdu_op = `DIV;
                            `divu: instr_d.mdu_ctrl.mdu_op = `DIVU; 
                            default: instr_d.mdu_ctrl.mdu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    `mfhi, `mflo: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = funct == `mfhi ? 33 : 34;
                        instr_d.rf_ctrl.Tuse1 = `LRF_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = 0;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = rd;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        instr_d.mdu_ctrl.mdu_op = funct == `mfhi ? `MFHI : `MFLO;
                        instr_d.exc_code = 0;
                    end
                    `mthi, `mtlo: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = funct == `mthi ? 33 : 34;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        instr_d.mdu_ctrl.mdu_op = funct == `mthi ? `MTHI : `MTLO;
                        instr_d.exc_code = 0;
                    end
                    `jalr, `jr: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = funct == `jalr ? rd : 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `jr_bru;
                        instr_d.exc_code = 0;
                    end
                    `break, `syscall: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = (funct == `break) ? `Bp : `Syscall;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `SPECIAL2: begin
                case (funct)
                    `mul: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `MDU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `MDU_USE;
                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = rd;

                        instr_d.alu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.mdu_ctrl.mdu_en = 1;
                        case (funct)
                            `mul: instr_d.mdu_ctrl.mdu_op = `MUL;
                            default: instr_d.mdu_ctrl.mdu_op = 0;
                        endcase
                        instr_d.exc_code = 0;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `ori, `addi, `addiu, `andi, `slti, `sltiu, `xori: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `ALU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;
                
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.alu_ctrl.alu_en = 1;
                instr_d.alu_ctrl.alu_op = (opcode == `ori) ? `OR : 
                                    (opcode == `addi || opcode == `addiu) ? `ADD : 
                                    (opcode == `andi) ? `AND : 
                                    (opcode == `slti) ? `SLT : 
                                    (opcode == `sltiu) ? `SLTU : 
                                    (opcode == `xori) ? `XOR : 0;
                instr_d.alu_ctrl.check_ov = (opcode == `addi);
                instr_d.alu_ctrl.src_a = 0;
                instr_d.alu_ctrl.src_b = 1;
                instr_d.alu_ctrl.sign_b = opcode == `addi || opcode == `addiu || opcode == `slti || opcode == `sltiu;
                instr_d.exc_code = 0;
            end
            `lui: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = 0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;

                instr_d.alu_ctrl.alu_en = 1;
                instr_d.alu_ctrl.alu_op = `LUI;
                instr_d.alu_ctrl.check_ov = 0;
                instr_d.alu_ctrl.src_b = 1;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.exc_code = 0;
            end
            `beq, `bne: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = rt;
                instr_d.rf_ctrl.Tuse2 = `BRU_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = (opcode == `beq || opcode == `beql) ? `beq_bru : 
                                    (opcode == `bne || opcode == `bnel) ? `bne_bru : 0;
                instr_d.exc_code = 0;
            end
            `blez, `bgtz: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = (opcode == `blez || opcode == `blezl) ? `blez_bru : 
                                    (opcode == `bgtz || opcode == `bgtzl) ? `bgtz_bru : 0;
                instr_d.exc_code = 0;
            end
            `RT: begin
                case (rt)
                    `bltz, `bgez: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = (rt == `bltz || rt == `bltzl) ? `bltz_bru : 
                                            (rt == `bgez || rt == `bgezl) ? `bgez_bru : 0;
                        instr_d.exc_code = 0;
                    end 
                    `bltzal, `bgezal: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = rs;
                        instr_d.rf_ctrl.Tuse1 = `BRU_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 31;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = (rt == `bltzal || rt == `bltzall) ? `bltzal_bru : 
                                            (rt == `bgezal || rt == `bgezall) ? `bgezal_bru : '0;
                        instr_d.exc_code = 0;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            `lw, `lh, `lhu, `lb, `lbu: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `AGU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = (opcode == `lwr || opcode == `lwl) ? rt : 0;
                instr_d.rf_ctrl.Tuse2 = (opcode == `lwr || opcode == `lwl) ? `MEM_USE : `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = rt;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;
                instr_d.mem_ctrl.acc_mem = 1'b1;
                instr_d.mem_ctrl.wr_mem = 1'b0;
                case (opcode)
                    `lb, `lbu: instr_d.mem_ctrl.size = 2'b0;
                    `lh, `lhu: instr_d.mem_ctrl.size = 2'b1;
                    `lw, `ll, `lwl, `lwr: instr_d.mem_ctrl.size = 2'b10;
                    default: instr_d.mem_ctrl.size = 2'b0;
                endcase
                instr_d.mem_ctrl.rdata_sign = (opcode == `lbu || opcode == `lhu) ? 1'b0 : 1'b1;
                instr_d.mem_ctrl.set_LLbit = (opcode == `ll);
                instr_d.mem_ctrl.unalign_left = (opcode == `lwl);
                instr_d.mem_ctrl.unalign_right = (opcode == `lwr);

                instr_d.exc_code = 0;
            end
            `sw, `sh, `sb: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = rs;
                instr_d.rf_ctrl.Tuse1 = `AGU_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = rt;
                instr_d.rf_ctrl.Tuse2 = `AGU_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;

                instr_d.mem_ctrl.acc_mem = 1'b1;
                instr_d.mem_ctrl.wr_mem = 1'b1;
                case (opcode)
                    `sw, `swl, `swr: begin
                        instr_d.mem_ctrl.size = 2'b10;
                    end 
                    `sh: begin
                        instr_d.mem_ctrl.size = 2'b1;
                    end
                    `sb: begin
                        instr_d.mem_ctrl.size = 2'b0;
                    end
                    default: instr_d.mem_ctrl.size = 2'b0; 
                endcase
                instr_d.mem_ctrl.unalign_left = (opcode == `swl);
                instr_d.mem_ctrl.unalign_right = (opcode == `swr);

                instr_d.exc_code = 0;
            end
            `j, `jal: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = 0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = (opcode == `jal) ? 31 : 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `j_bru;
                instr_d.exc_code = 0;
            end
            `RS: begin
                case (rs)
                    `mfc0: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 1;
                        instr_d.rf_ctrl.rd_reg2.addr = rd;
                        instr_d.rf_ctrl.Tuse2 = `LRF_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = rt;

                        instr_d.cp0_ctrl.cp0_en = 1'b1;
                        instr_d.cp0_ctrl.wr_cp0 = 1'b0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.exc_code = 0;
                    end 
                    `mtc0: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = rt;
                        instr_d.rf_ctrl.Tuse2 = `CP0_USE;

                        instr_d.rf_ctrl.wr_reg.src = 1;
                        instr_d.rf_ctrl.wr_reg.addr = rd;

                        instr_d.cp0_ctrl.cp0_en = 1'b1;
                        instr_d.cp0_ctrl.wr_cp0 = 1'b1;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;
                        instr_d.exc_code = 0;
                    end
                    `cop0: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = (funct == `eret) ? `eret_bru : `pc4_bru;
                        case (funct)
                            `eret: instr_d.tlb_ctrl = `TLB_None;
                            default: instr_d.tlb_ctrl = `TLB_None; 
                        endcase
                        instr_d.exc_code = 0;
                    end
                    default: begin
                        instr_d.rf_ctrl.rd_reg1.src = 0;
                        instr_d.rf_ctrl.rd_reg1.addr = 0;
                        instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                        instr_d.rf_ctrl.rd_reg2.src = 0;
                        instr_d.rf_ctrl.rd_reg2.addr = 0;
                        instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                        instr_d.rf_ctrl.wr_reg.src = 0;
                        instr_d.rf_ctrl.wr_reg.addr = 0;

                        instr_d.alu_ctrl = '0;
                        instr_d.mdu_ctrl = '0;
                        instr_d.bru_ctrl = `pc4_bru;

                        instr_d.exc_code = `RI;
                    end
                endcase
            end
            default: begin
                instr_d.rf_ctrl.rd_reg1.src = 0;
                instr_d.rf_ctrl.rd_reg1.addr = 0;
                instr_d.rf_ctrl.Tuse1 = `NOT_USE;
                instr_d.rf_ctrl.rd_reg2.src = 0;
                instr_d.rf_ctrl.rd_reg2.addr = 0;
                instr_d.rf_ctrl.Tuse2 = `NOT_USE;

                instr_d.rf_ctrl.wr_reg.src = 0;
                instr_d.rf_ctrl.wr_reg.addr = 0;

                instr_d.alu_ctrl = '0;
                instr_d.mdu_ctrl = '0;
                instr_d.bru_ctrl = `pc4_bru;

                instr_d.exc_code = `RI;            
            end
        endcase
        
        instr_d.is_priv = instr_d.exc_code != `Int || instr_d.opcode == `RS || instr_d.opcode == `cache || instr == 32'h40;
        instr_d.is_branch = instr_d.is_priv ? 0 : 
                            instr_d.bru_ctrl != `pc4_bru;
        instr_d.is_likely = ~instr_d.is_branch ? '0 : 
                            instr_d.opcode[5:2] == 4'b0101 ? 1'b1 : 
                            instr_d.opcode == `RT && (rt[4:1] == 4'b0001 || rt[4:1] == 4'b1001) ? 1'b1 : 
                            1'b0;
        instr_d.is_accmem = instr_d.is_priv ? 0 : 
                            instr_d.opcode >= `lb && instr_d.opcode <= `sc && instr_d.opcode != `pref || instr_d.opcode == `cache;
        instr_d.is_md = instr_d.is_priv ? 0 :
                        instr_d.mdu_ctrl.mdu_en;
        instr_d.wr_md = instr_d.is_md && instr_d.mdu_ctrl.mdu_op != `MFLO && instr_d.mdu_ctrl.mdu_op != `MFHI && instr_d.mdu_ctrl.mdu_op != `MUL;
        instr_d.is_cal = instr_d.is_priv ? 0 : 
                          instr_d.opcode == 0 && (instr_d.funct >= 0 && instr_d.funct <= 7 || instr_d.funct >= 32 && instr_d.funct <= 43) ||
                         (instr_d.opcode >= 8 && instr_d.opcode <= 15);

        instr_d.bp_info = bp_info;
    end
    else begin
        instr_d = '0;
    end
end
end
endmodule
