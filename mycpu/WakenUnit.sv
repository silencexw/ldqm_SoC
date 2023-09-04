`timescale 1ns/1ps
//`include "cpu_macro.svh"
/*
judge if the head entry of issue queue is ready according to revelant register can be update before using it
*/
module WakenUnit (
    input instr_info instr,
    input logic en,

    input logic way_no,     //take way_no into consideration, in order to support in-class forwarding of ALU
    
    input wr_reg_info wd_way0,
    
    input wr_reg_info [1:0] wd_0,
    input wr_reg_info [1:0] wd_1,
    input wr_reg_info [1:0] wd_2,
    input wr_reg_info [1:0] wd_3,
    input wr_reg_info [1:0] wd_4,

    output logic delay_exec,
    output logic ready
);

reg_info reg1, reg2;
logic result;
assign ready = en ? result : 0;

wr_reg_info [1:0] wd [`EXEC_CLASS_NUM - 1:0];
wire inclass_data_related1, inclass_data_related2;
assign wd[0] = wd_0;
assign wd[1] = wd_1;
assign wd[2] = wd_2;
assign wd[3] = wd_3;
assign wd[4] = wd_4;

logic stall1, stall2, stall_way0;
assign inclass_data_related1 = way_no && reg1.addr && reg1.addr == wd_way0.addr;
assign inclass_data_related2 = way_no && reg2.addr && reg2.addr == wd_way0.addr;

wire allow_delay_exec;
assign allow_delay_exec = instr.is_cal && !instr.alu_ctrl.check_ov;
always_comb begin
    reg1 = instr.rf_ctrl.rd_reg1;
    reg2 = instr.rf_ctrl.rd_reg2;

    stall_way0 = inclass_data_related1 || inclass_data_related2;

    result = (!stall1 && !stall2 || delay_exec) && !stall_way0;
end

logic [`EXEC_CLASS_NUM - 1:0] stall1_array;
logic [`EXEC_CLASS_NUM - 1:0] stall1_array_d;
logic [`EXEC_CLASS_NUM - 1:0] stall2_array;
logic [`EXEC_CLASS_NUM - 1:0] stall2_array_d;
assign stall1 = |stall1_array;
assign stall2 = |stall2_array;
assign stall1_d = |stall1_array_d;
assign stall2_d = |stall2_array_d;
generate
    for (genvar i = 0; i <= `EXEC_CLASS_NUM - 1; i++) begin
        assign stall1_array[i] = (reg1.addr && wd[i][1].addr == reg1.addr && instr.rf_ctrl.Tuse1 + 1 < wd[i][1].Tnew) |
                         (reg1.addr && wd[i][0].addr == reg1.addr && instr.rf_ctrl.Tuse1 + 1 < wd[i][0].Tnew);
        assign stall1_array_d[i] = (reg1.addr && wd[i][1].addr == reg1.addr && instr.rf_ctrl.Tuse1 + `MEM_GEN - `ALU_GEN + 1 < wd[i][1].Tnew) |
                         (reg1.addr && wd[i][0].addr == reg1.addr && instr.rf_ctrl.Tuse1 +  `MEM_GEN - `ALU_GEN + 1 < wd[i][0].Tnew);
                             
        assign stall2_array[i] = (reg2.addr && wd[i][1].addr == reg2.addr && instr.rf_ctrl.Tuse2 + 1 < wd[i][1].Tnew) |
                         (reg2.addr && wd[i][0].addr == reg2.addr && instr.rf_ctrl.Tuse2 + 1 < wd[i][0].Tnew);
        assign stall2_array_d[i] = (reg2.addr && wd[i][1].addr == reg2.addr && instr.rf_ctrl.Tuse2 + `MEM_GEN - `ALU_GEN + 1 < wd[i][1].Tnew) |
                         (reg2.addr && wd[i][0].addr == reg2.addr && instr.rf_ctrl.Tuse2 + `MEM_GEN - `ALU_GEN + 1 < wd[i][0].Tnew);
    end
endgenerate
//is alu instruction, and not generate exception, and cannot normal_exec but can delay_exec
assign delay_exec = allow_delay_exec && (stall1 || stall2) && !(stall1_d || stall2_d);
endmodule