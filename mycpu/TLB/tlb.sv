
module tlb #(
    parameter TLBNUM = 32,
    parameter IDXLEN = 5
)(
    input clk,
    input reset,

    // status
    input km,
    input cp0_erl,
    input kseg0_cached,

    // inst_search
    input TLB_Search_In inst_search_in,
    output TLB_Search_Out inst_search_out,

    // data_search
    input TLB_Search_In data_search_in,
    output TLB_Search_Out data_search_out,

    // write port TLBWI
    input        write,        
    input [31:0] index_in,           
    input [11:0] mask_in,        
    input [31:0] entryhi_in, // search and write
    input [31:0] entrylo0_in,
    input [31:0] entrylo1_in,

    // read port TLBR
    output [11:0] mask_out,    
    output [31:0] entryhi_out,
    output [31:0] entrylo0_out,
    output [31:0] entrylo1_out,

    // probe port TLBP
    output [31:0] index_out
);

TLB_Line tlb_lines[TLBNUM-1:0];

wire [IDXLEN-1:0] index = index_in[IDXLEN-1:0];
integer m;

always_ff @(posedge clk) begin
    if (reset) begin
        for (m = 0; m < TLBNUM; m++) begin
            tlb_lines[m].mask  <= 0;
            tlb_lines[m].vpn2  <= 0;
            tlb_lines[m].asid  <= 0;
            tlb_lines[m].G     <= 0;
            tlb_lines[m].pfn0  <= 0;
            tlb_lines[m].pfn1  <= 0;
            tlb_lines[m].c0    <= 0;
            tlb_lines[m].c1    <= 0;
            tlb_lines[m].d0    <= 0;
            tlb_lines[m].d1    <= 0;
            tlb_lines[m].v0    <= 0;
            tlb_lines[m].v1    <= 0;
        end
    end
    else begin
        // write
        if (write) begin
            tlb_lines[index].mask  <= mask_in;
            tlb_lines[index].vpn2  <= entryhi_in[31:13] & ~mask_in;
            tlb_lines[index].asid  <= entryhi_in[7:0];
            tlb_lines[index].G     <= entrylo0_in[0] & entrylo1_in[0];
            tlb_lines[index].pfn0  <= entrylo0_in[25:6] & ~mask_in;
            tlb_lines[index].pfn1  <= entrylo1_in[25:6] & ~mask_in;
            tlb_lines[index].c0    <= entrylo0_in[5:3];
            tlb_lines[index].c1    <= entrylo1_in[5:3];
            tlb_lines[index].d0    <= entrylo0_in[2];
            tlb_lines[index].d1    <= entrylo1_in[2];
            tlb_lines[index].v0    <= entrylo0_in[1];
            tlb_lines[index].v1    <= entrylo1_in[1];
        end
    end
end

genvar i;

// probe

wire [TLBNUM-1:0] pro_match;
wire [IDXLEN-1:0] pro_index[TLBNUM:0];

assign pro_index[0] = 0;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin
        assign pro_match[i] = (entryhi_in[31:13] & ~tlb_lines[i].mask) == (tlb_lines[i].vpn2 & ~tlb_lines[i].mask) && (tlb_lines[i].G || tlb_lines[i].asid == entryhi_in[7:0]);
        assign pro_index[i+1] = pro_index[i] | (pro_match[i] ? i : 0);
    end
endgenerate

assign index_out = ((~|pro_match) << 31) | pro_index[TLBNUM];

// read
assign entryhi_out  = {tlb_lines[index_in].vpn2, 5'b0, tlb_lines[index_in].asid};
assign entrylo0_out = {6'b0, tlb_lines[index_in].pfn0, tlb_lines[index_in].c0, tlb_lines[index_in].d0, tlb_lines[index_in].v0, tlb_lines[index_in].G};
assign entrylo1_out = {6'b0, tlb_lines[index_in].pfn1, tlb_lines[index_in].c1, tlb_lines[index_in].d1, tlb_lines[index_in].v1, tlb_lines[index_in].G};
assign mask_out     = tlb_lines[index_in].mask;

// inst search
Search #(.TLBNUM(TLBNUM))inst_search(clk, reset, km, cp0_erl, kseg0_cached, entryhi_in, inst_search_in, inst_search_out, tlb_lines);

// data search
Search #(.TLBNUM(TLBNUM))data_search(clk, reset, km, cp0_erl, kseg0_cached, entryhi_in, data_search_in, data_search_out, tlb_lines);

endmodule

module Search #(
    parameter TLBNUM = 16
)(
    input clk,
    input reset,
    input km,
    input cp0_erl,
    input kseg0_cached,
    input [31:0] entryhi_in, 

    input TLB_Search_In search_in,
    output TLB_Search_Out search_out,
    input TLB_Line tlb_lines [TLBNUM-1:0]
);

typedef enum logic [2:0] {
        useg,
        kseg0,
        kseg1,
        kseg2,
        kseg3
    } segment;

segment va_seg;

always_comb begin
    unique case (search_in.vaddr[31:29])
        3'b100:  va_seg = kseg0;
        3'b101:  va_seg = kseg1;
        3'b110:  va_seg = kseg2;
        3'b111:  va_seg = kseg3;
        default: va_seg = useg;
    endcase
end

genvar i;

wire [TLBNUM-1:0] match;
wire [TLBNUM-1:0] sel;
wire [19:0] pfn [TLBNUM-1:0];
wire [31:0] lookup_paddr    [TLBNUM:0];
wire [2:0]  lookup_c        [TLBNUM:0];
wire        lookup_d        [TLBNUM:0];
wire        lookup_v        [TLBNUM:0];

assign lookup_paddr[0]  = 32'd0;
assign lookup_c[0]      = 3'd0;
assign lookup_d[0]      = 1'd0; 
assign lookup_v[0]      = 1'd0; 
generate
    for (i=0; i<TLBNUM; i=i+1) begin
        assign match[i] = (search_in.vaddr[31:13] & ~tlb_lines[i].mask) == (tlb_lines[i].vpn2 & ~tlb_lines[i].mask)&& (tlb_lines[i].G || tlb_lines[i].asid == entryhi_in[7:0]);
        assign sel[i]   = (search_in.vaddr[24:12] & {tlb_lines[i].mask, 1'b1}) != (search_in.vaddr[24:12] & {1'b0, tlb_lines[i].mask});
        assign pfn[i]   = sel[i] ? tlb_lines[i].pfn1 : tlb_lines[i].pfn0;
        // all lookup results are OR'd together assuming match is at-most-one-hot
        assign lookup_paddr[i+1]    = lookup_paddr[i]   | {32{match[i]}} & (((pfn[i] & ~tlb_lines[i].mask) << 12) | (search_in.vaddr & {tlb_lines[i].mask, 12'hfff}));
        assign lookup_c[i+1]        = lookup_c[i]       | { 3{match[i]}} & (sel[i] ? tlb_lines[i].c1 : tlb_lines[i].c0);
        assign lookup_d[i+1]        = lookup_d[i]       | { 1{match[i]}} & (sel[i] ? tlb_lines[i].d1 : tlb_lines[i].d0);
        assign lookup_v[i+1]        = lookup_v[i]       | { 1{match[i]}} & (sel[i] ? tlb_lines[i].v1 : tlb_lines[i].v0);
    end
endgenerate


logic mapped, error;
always_comb begin
    unique case (va_seg)
    useg: begin
            if (km) begin
                mapped = !cp0_erl;
                error = 0;
            end else begin
                mapped = 1;
                error = 0;
            end
        end
        kseg0, kseg1: begin
            if (km) begin
                mapped = 0;
                error = 0;
            end else begin
                mapped = 0;
                error = 1;
            end
        end
        kseg3, kseg2: begin
            if (km) begin
                mapped = 1;
                error = 0;
            end else begin
                mapped = 0;
                error = 1;
            end
        end
        default: begin
            error = 1;
            mapped = 0;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (search_in.ce) begin
        search_out.va_out <= search_in.vaddr;
        search_out.error <= error;
        if (mapped) begin
            search_out.paddr    <= lookup_paddr[TLBNUM];
            search_out.cached    <= lookup_c[TLBNUM] == 3;
            search_out.hit     <= |match;
            search_out.v  <= lookup_v[TLBNUM];
            search_out.d    <= lookup_d[TLBNUM];
        end else begin
            search_out.paddr <= {3'b0, search_in.vaddr[28:0]};
            search_out.hit <= 1;
            search_out.v <= 1;
            search_out.d <= 1;
            search_out.cached <= va_seg == kseg0 ? kseg0_cached : 0;
        end
    end
end

endmodule