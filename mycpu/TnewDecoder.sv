`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/05 22:36:24
// Design Name: 
// Module Name: TnewDecoder
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
`timescale 1ns/1ps
`include "InstrDefine.svh"

module TnewDecoder(
    input instr_info instr,
    input delay_exec,
    output wr_reg_info wr_reg_info_ori
    );
logic [2:0] Tnew;
always_comb begin
    wr_reg_info_ori.addr = ~instr.rf_ctrl.wr_reg.src ? instr.rf_ctrl.wr_reg.addr : '0;
    wr_reg_info_ori.data = 0;
    
    if (wr_reg_info_ori.addr == 0) begin
        Tnew = `NOT_WRITE;
    end
    else if (instr.likely_delayslot && instr.in_delayslot) begin
        Tnew = `STALL;
    end
    else if (instr.alu_ctrl.alu_en) begin
        Tnew = (instr.alu_ctrl.alu_op == `MOVZ || instr.alu_ctrl.alu_op == `MOVN) ? `STALL : 
               delay_exec ? `MEM_GEN : 
               `ALU_GEN;
    end
    else if (instr.mdu_ctrl.mdu_en) begin
        Tnew = instr.rf_ctrl.wr_reg.addr ? `MDU_GEN : `NOT_WRITE;
    end
    else if (instr.bru_ctrl == `bltzal_bru || instr.bru_ctrl == `bgezal_bru || 
        (instr.bru_ctrl == `j_bru && instr.opcode == `jal)) begin
        Tnew = `BRU_GEN;
    end
    else if (instr.cp0_ctrl.cp0_en && !instr.cp0_ctrl.wr_cp0) begin
        Tnew = `CP0_GEN;
    end
    else if (instr.opcode >= `lb && instr.opcode <= `lwr || instr.opcode == `ll) begin
        Tnew = `MEM_GEN;
    end
    else if (instr.opcode == `sc) begin
        Tnew = `CP0_GEN;
    end
    else begin
        Tnew = `NOT_WRITE;
    end
    
    wr_reg_info_ori.Tnew = Tnew;
end
endmodule
