`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/09 21:25:34
// Design Name: 
// Module Name: MEM_REQ_MUX_2
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

module MEM_REQ_MUX_2(
    input   clk,
    input   reset,
    input   stall,
    input   stall_top,
    input   wb_stall,
    
    input   logic   LLbit,
    output  logic   set_LLbit,

    input   instr_info_dreq  [1:0] instr_i,
    input   lrf_data    [1:0] reg2_data,
    input   wr_reg_info [1:0] wd_i,
    input   TLB_Search_Out    tlb_info,
    
    output  instr_info_dreq  [1:0] instr_o,
    output  logic            data_req,
    output  logic [31:0]     data_addr,
    output  logic            data_cached,
    output  logic [1:0]      data_size,
    output  logic            data_wr,
    output  logic [3:0]      data_wstrb,
    output  logic [31:0]     data_wdata,
    input   logic            data_addr_ok,
    
    output logic            dcache_valid,
    output logic            dcache_op,
    output logic            dcache_wb,
    output logic [31:0]     icache_addr_req,
    output logic            icache_cached_req,
    output logic            icache_valid_req,
    output logic            icache_op_req,
    output logic [31:0]     icache_npc_req,
    
    output  logic            stall_inclass,
    output  wr_reg_info [1:0] wd_o,
    
    output logic [31:0]     vaddr
    );

logic save_valid;
TLB_Search_Out tlb_info_f, _tlb_info;
always_ff @(posedge clk) begin
    if (reset) begin
        _tlb_info <= '0;
        save_valid <= '0;
    end
    else begin
        if (stall && !save_valid) begin
            _tlb_info <= tlb_info;
            save_valid <= 1'b1;
        end
        else if (!stall) begin
            save_valid <= 1'b0;
        end
    end
end
assign tlb_info_f = save_valid ? _tlb_info : tlb_info;

logic [1:0] acc_mem;
logic sel_way;
instr_info_dreq sel_instr;
logic [4:0] exc_code;
logic       tlb_refill_error;
logic [31:0] address;
logic [31:0] ori_wdata;

/*
(*mark_debug = "true"*) wire [31:0] accmem_pc;
assign accmem_pc = sel_instr.pc;
*/
logic req_completed;
always_ff @(posedge clk) begin
    if (reset) begin
        req_completed <= 1'b0;
    end
    else begin
        if (!req_completed && data_req && data_addr_ok && stall_top) begin
            req_completed <= 1'b1;
        end
        else if (req_completed && !stall_top) begin
            req_completed <= 1'b0;
        end
    end
end
always_comb begin
    acc_mem = {instr_i[1].is_accmem || instr_i[1].cache_op.valid, 
               instr_i[0].is_accmem || instr_i[0].cache_op.valid};
    sel_way = acc_mem[0] ? 1'b0 : 
              acc_mem[1] ? 1'b1 : 
              1'b0;
    sel_instr = sel_way ? instr_i[1] : instr_i[0];
    
    //check tlb_info
    if (!sel_instr.is_accmem && !sel_instr.cache_op.valid) begin
        exc_code = `Int;
        tlb_refill_error = '0;
    end
    else begin
        if (sel_instr.mem_ctrl.acc_mem) begin
            //load and store instructions
            if (sel_instr.mem_ctrl.wr_mem) begin
                if (tlb_info_f.error) begin
                    exc_code = `AdES;
                    tlb_refill_error = '0;
                end
                else if (!tlb_info_f.v || !tlb_info_f.hit) begin
                    exc_code = `TLBS;
                    tlb_refill_error = !tlb_info_f.hit ? 1'b1 : 1'b0;
                end
                else if (!tlb_info_f.d) begin
                    exc_code = `TLBMod;
                    tlb_refill_error = '0;
                end
                else begin
                    exc_code = `Int;
                    tlb_refill_error = '0;
                end
            end
            else begin
                if (tlb_info_f.error) begin
                    exc_code = `AdEL;
                    tlb_refill_error = '0;
                end
                else if (!tlb_info_f.v || !tlb_info_f.hit) begin
                    exc_code = `TLBL;
                    tlb_refill_error = !tlb_info_f.hit ? 1'b1 : 1'b0;
                end
                else if (!tlb_info_f.d) begin
                    exc_code = `Int;
                    tlb_refill_error = '0;
                end
                else begin
                    exc_code = `Int;
                    tlb_refill_error = '0;
                end
            end
        end
        else begin
            //cache instructions
             if (tlb_info_f.error) begin
                exc_code = `AdEL;
                tlb_refill_error = '0;
            end
            else if (!tlb_info_f.v || !tlb_info_f.hit) begin
                exc_code = `TLBL;
                tlb_refill_error = !tlb_info_f.hit ? 1'b1 : 1'b0;
            end
            else begin
                exc_code = '0;
                tlb_refill_error = '0;
            end
        end
    end
    
    //normal acc-mem instructions and dache instruction
    data_req =  !wb_stall && ~reset && exc_code == `Int && (
                sel_instr.is_accmem && !(sel_instr.mem_ctrl.read_LLbit && ~LLbit) || //normal acc-mem instructions
                sel_instr.cache_op.valid && sel_instr.cache_op.target //dcache instructions
    ) && !req_completed;
    dcache_valid = sel_instr.cache_op.valid;
    dcache_op = sel_instr.cache_op.op;
    dcache_wb = sel_instr.cache_op.wb;
    
    icache_valid_req = exc_code == `Int && sel_instr.cache_op.valid && !sel_instr.cache_op.target;
    icache_op_req = sel_instr.cache_op.op;
    icache_addr_req = tlb_info_f.paddr;
    icache_cached_req = tlb_info_f.cached;
    icache_npc_req = sel_instr.pc + 4;
    
    data_wr = (sel_instr.mem_ctrl.wr_mem && !sel_instr.mem_ctrl.read_LLbit) ? 1'b1 : 
              (sel_instr.mem_ctrl.read_LLbit && LLbit) ? 1'b1 : 
              1'b0;
    address = tlb_info_f.paddr;
    vaddr = tlb_info_f.va_out;
    data_addr = address;
    data_cached = tlb_info_f.cached;
    set_LLbit = data_req && data_addr_ok && sel_instr.mem_ctrl.set_LLbit;
    
    ori_wdata = reg2_data[sel_way];
    case (sel_instr.mem_ctrl.size)
        2'b00: begin
            data_wstrb = (4'b0001 << address[1:0]);
            data_wdata = address[1:0] == 2'b00 ? {24'h0, ori_wdata[7:0]} : 
                    address[1:0] == 2'b01 ? {16'h0, ori_wdata[7:0], 8'h0} : 
                    address[1:0] == 2'b10 ? {8'h0, ori_wdata[7:0], 16'h0} : 
                    address[1:0] == 2'b11 ? {ori_wdata[7:0], 24'h0} : 0;
        end 
        2'b01: begin
            data_wstrb = (4'b0011 << {address[1], 1'b0});
            data_wdata = address[1] == 1'b0 ? {16'h0, ori_wdata[15:0]} : 
                    address[1] == 1'b1 ? {ori_wdata[15:0], 16'h0} : 0;
        end
        2'b10: begin
            if (sel_instr.mem_ctrl.unalign_left) begin
                data_wdata = ori_wdata >> {~address[1:0], 3'b0};
                data_wstrb = 4'b1111 >> (~address[1:0]);
            end
            else if (sel_instr.mem_ctrl.unalign_right) begin
                data_wdata = ori_wdata << {address[1:0], 3'b0};
                data_wstrb = 4'b1111 << (address[1:0]);
            end
            else begin
                data_wstrb = 4'b1111;
                data_wdata = ori_wdata;
            end
        end
        default: begin 
            data_wstrb = 4'b0000;
            data_wdata = '0;
        end
    endcase

    data_size = sel_instr.mem_ctrl.size;
    
    if (exc_code == `Int) begin
        instr_o = instr_i;
        wd_o = wd_i;
        if (sel_instr.mem_ctrl.read_LLbit) begin
            wd_o[sel_way].data = {31'b0, LLbit};
            if (!LLbit) begin
                instr_o[sel_way].is_accmem = 1'b0;
            end
        end
    end
    else begin
        if (sel_way) begin
            instr_o[0] = instr_i[0];
            wd_o[0] = wd_i[0];
            
            instr_o[1] = instr_i[1];
            wd_o[1] = '0;
            instr_o[1].rf_ctrl.wr_reg.addr = '0;
            instr_o[1].is_accmem = '0;
            instr_o[1].mem_ctrl = '0;
            instr_o[1].cache_op = '0;
            instr_o[1].is_priv = 1'b1;
            instr_o[1].bad_va_addr = tlb_info_f.va_out;
            instr_o[1].exc_code = exc_code;
            instr_o[1].exc_tre = tlb_refill_error;
        end
        else begin
            instr_o[1] = '0;
            wd_o[1] = '0;
            
            instr_o[0] = instr_i[0];
            wd_o[0] = '0;
            instr_o[0].rf_ctrl.wr_reg.addr = '0;
            instr_o[0].is_accmem = '0;
            instr_o[0].mem_ctrl = '0;
            instr_o[0].cache_op = '0;
            instr_o[0].is_priv = 1'b1;
            instr_o[0].bad_va_addr = tlb_info_f.va_out;
            instr_o[0].exc_code = exc_code;
            instr_o[0].exc_tre = tlb_refill_error;
        end
    end
    
    //stall_inclass = (instr_o[sel_way].is_accmem) && ~data_addr_ok;
    stall_inclass = (instr_o[sel_way].is_accmem || 
    instr_o[sel_way].cache_op.valid && instr_o[sel_way].cache_op.target) && ~data_addr_ok && !req_completed;
end
endmodule
