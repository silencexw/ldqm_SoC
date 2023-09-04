`timescale 1ns/1ps
`include "cpu_macro.svh"
`include "InstrDefine.svh"
module MEM_RECV_MUX (
    input instr_info_mem [1:0] instr,
    input mem_data rdata,
    input mem_addr v_addr,
    input lrf_data [1:0] reg2_data,
    
    output mem_data result
);
instr_info_mem sel_instr; 
logic [1:0] offset;
lrf_data sel_reg2_data;
always_comb begin
    sel_instr = instr[0].is_accmem ? instr[0] : 
                instr[1].is_accmem ? instr[1] : '0;
    sel_reg2_data = instr[0].is_accmem ? reg2_data[0] : 
                    instr[1].is_accmem ? reg2_data[1] : '0;
    case (sel_instr.mem_ctrl.size)
        2'b10: begin
            if (sel_instr.mem_ctrl.unalign_left) begin
                offset = v_addr[1:0];
                result = (rdata << ({~offset,3'b0})) | (sel_reg2_data & ~(32'hFFFFFFFF << {~offset, 3'b0}));
            end
            else if (sel_instr.mem_ctrl.unalign_right) begin
                offset = v_addr[1:0];
                result = (rdata >> ({offset,3'b0})) | (sel_reg2_data & ~(32'hFFFFFFFF >> {offset, 3'b0}));
            end
            else begin
                result = rdata;
            end
        end
        2'b01: begin
            if (sel_instr.mem_ctrl.rdata_sign) begin
                result = v_addr[1] ? {{16{rdata[31]}}, rdata[31:16]} : {{16{rdata[15]}}, rdata[15:0]};
            end
            else begin
                result = v_addr[1] ? {16'h0, rdata[31:16]} : {16'h0, rdata[15:0]};
            end
        end
        2'b00: begin
            if (sel_instr.mem_ctrl.rdata_sign) begin
                result = v_addr[1:0] == 2'b00 ? {{24{rdata[7]}}, rdata[7:0]} : 
                         v_addr[1:0] == 2'b01 ? {{24{rdata[15]}}, rdata[15:8]} : 
                         v_addr[1:0] == 2'b10 ? {{24{rdata[23]}}, rdata[23:16]} : 
                         v_addr[1:0] == 2'b11 ? {{24{rdata[31]}}, rdata[31:24]} : '0;
            end
            else begin
                result = v_addr[1:0] == 2'b00 ? {24'h0, rdata[7:0]} : 
                         v_addr[1:0] == 2'b01 ? {24'h0, rdata[15:8]} : 
                         v_addr[1:0] == 2'b10 ? {24'h0, rdata[23:16]} : 
                         v_addr[1:0] == 2'b11 ? {24'h0, rdata[31:24]} : '0;
            end
        end
        default: result ='0;
    endcase
end
endmodule