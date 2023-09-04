`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/09 20:12:57
// Design Name: 
// Module Name: AGU
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
`include "InstrDefine.svh"
`include "cpu_macro.svh"
module AGU(
    input logic flush,

    input instr_info [1:0] instr_i,
    input lrf_data [1:0] reg1_data,
    input lrf_data [1:0] reg2_data,
    input wr_reg_info [1:0] wd_i,
    
    output logic [31:0] v_addr,
    output instr_info [1:0] instr_o,
    output wr_reg_info [1:0]  wd_o,
    output ce
    ); 
wire [1:0] accmem;
assign accmem[1] = instr_i[1].is_accmem || instr_i[1].cache_op.valid;
assign accmem[0] = instr_i[0].is_accmem || instr_i[0].cache_op.valid;
logic sel_way;
instr_info  sel_instr;
lrf_data sel_reg1_data, sel_reg2_data;
logic [4:0] exc_code;
assign ce = |accmem && !(|exc_code);
always_comb begin
    //generate virtual address
    sel_way = accmem[0] ? 1'b0 : 
              accmem[1] ? 1'b1 : 1'b0;
    sel_instr = sel_way ? instr_i[1] : instr_i[0];
    sel_reg1_data = sel_way ? reg1_data[1] : reg1_data[0];
    sel_reg2_data = sel_way ? reg2_data[1] : reg2_data[0];
    v_addr = sel_reg1_data + sel_instr.extimm;
    
    //check virtual address
    if (sel_instr.is_accmem) begin
        case (sel_instr.mem_ctrl.size)
            2'b10: begin
                exc_code = sel_instr.mem_ctrl.unalign_left || sel_instr.mem_ctrl.unalign_right ? '0 : 
                           v_addr[1:0] != 2'b00 ? (sel_instr.mem_ctrl.wr_mem ? `AdES : `AdEL) : '0;
            end 
            2'b01: begin
                exc_code = v_addr[0] ? (sel_instr.mem_ctrl.wr_mem ? `AdES : `AdEL) : '0;
            end
            default: exc_code = '0;
        endcase
    end
    else begin
        exc_code = '0;
    end
    
    //gen instr_o
    if (flush) begin
        instr_o = '0;
        wd_o = '0;
    end
    else if (exc_code == `Int) begin
        instr_o = instr_i;
        wd_o = wd_i;
        wd_o[0].Tnew = wd_i[0].Tnew > 0 ? wd_i[0].Tnew - 1 : wd_i[0].Tnew;
        wd_o[1].Tnew = wd_i[1].Tnew > 0 ? wd_i[1].Tnew - 1 : wd_i[1].Tnew;
    end
    else begin
        if (sel_way) begin
            instr_o[0] = instr_i[0];
            wd_o[0] = wd_i[0];
            wd_o[0].Tnew = wd_i[0].Tnew ? wd_i[0].Tnew - 1 : '0;
            instr_o[1] = sel_instr;
            instr_o[1].exc_code = exc_code;
            instr_o[1].is_accmem = 1'b0;
            instr_o[1].cache_op = '0;
            instr_o[1].is_priv = 1'b1;
            instr_o[1].bad_va_addr = v_addr;
            wd_o[1].addr = '0;
        end
        else begin
            instr_o[1] = instr_i[1];
            instr_o[0] = sel_instr;
            instr_o[0].exc_code = exc_code;
            instr_o[0].is_accmem = 1'b0;
            instr_o[0].cache_op = '0;
            instr_o[0].is_priv = 1'b1;
            instr_o[0].bad_va_addr = v_addr;
            wd_o = '0;
        end
    end
end
endmodule
