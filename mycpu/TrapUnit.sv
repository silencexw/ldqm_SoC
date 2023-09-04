`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/08 18:29:48
// Design Name: 
// Module Name: TrapUnit
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
`include "cpu_macro.svh"

module TrapUnit #(
    parameter CTRL_TRAP_UNIT = 1'b0
) (
    input instr_info_at [1:0] instr,
    input lrf_data [1:0] reg1_data,
    input lrf_data [1:0] reg2_data,
    output logic [4:0] exc_code,
    output logic [1:0] trap_way
    );
if (CTRL_TRAP_UNIT) begin
logic [31:0] srcA;
logic [31:0] srcB;
logic condition;
instr_info_at priv_instr;
always_comb begin
    priv_instr = instr[0].exc_code == `Tr ? instr[0] : 
                 instr[1].exc_code == `Tr ? instr[1] : 
                 '0;
    trap_way = instr[0].exc_code == `Tr ? 2'b01 : 
               instr[1].exc_code == `Tr ? 2'b10 : 2'b00;
    condition = '0;
    if (priv_instr.exc_code == `Tr) begin
        srcA = trap_way[1] ? reg1_data[1] : reg1_data[0];
        srcB = priv_instr.trap_ctrl.src_b ? priv_instr.extimm : 
               trap_way[1] ? reg2_data[1] : reg2_data[0];
        case(priv_instr.trap_ctrl.trap_op)
            `EQ_trap: condition = srcA == srcB;
            `NE_trap: condition = srcA != srcB;
            `GE_trap: condition = ($signed(srcA) >= $signed(srcB)) ? 1'b1 : 1'b0;
            `GEU_trap: condition = {1'b0, srcA} >= {1'b0, srcB};
            `LT_trap: condition = ($signed(srcA) < $signed(srcB)) ? 1'b1 : 1'b0;
            `LTU_trap: condition = {1'b0, srcA} < {1'b0, srcB};
            default: condition = '0;
        endcase
        exc_code = condition ? `Tr : `Int;
    end
    else begin
        exc_code = priv_instr.exc_code;
    end
end
end
else begin
always_comb begin
    exc_code = '0;
    trap_way = '0;
end
end
endmodule
