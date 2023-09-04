module FU_delay #(
    parameter CTRL_CLO_CLZ = 1'b0
) (
    input instr_info_mem    instr,
    input logic [31:0]     reg1_data,
    input logic [31:0]     reg2_data,
    input  wr_reg_info      wd_i,
    output wr_reg_info      wd_o
);
wire [31:0] unsigned_imm = {16'h0, instr.extimm[15:0]};
wire write_reg;
wire [31:0] alu_result;
ALU #(.CTRL_CLO_CLZ(CTRL_CLO_CLZ)) alu_d(
    .a(instr.alu_ctrl.src_a ? instr.s : reg1_data),
    .b(instr.alu_ctrl.src_b ? (instr.alu_ctrl.sign_b ? instr.extimm : unsigned_imm) : reg2_data),
    .ALUControl(instr.alu_ctrl.alu_en ? instr.alu_ctrl.alu_op : '0),
    .ALUResult(alu_result),
    .OvCtrl('0),
    .ov(),
    .WrCtrl(instr.alu_ctrl.alu_op == `MOVN || instr.alu_ctrl.alu_op == `MOVZ ),
    .write_reg
);

always_comb begin
    if (!instr.alu_ctrl.alu_en) begin
        wd_o = wd_i;
    end
    if (~write_reg) begin
        wd_o = '0;
    end
    else begin
        wd_o.addr = wd_i.addr;
        wd_o.data = wd_i.Tnew == 1 ? alu_result : wd_i.data;
        wd_o.Tnew = wd_i.Tnew;
    end
end
endmodule