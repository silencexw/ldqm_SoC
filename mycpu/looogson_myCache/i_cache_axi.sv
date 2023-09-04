`timescale 1ns / 1ps

`include "mem_if_def.svh"

module I_Cache_AXI #(
    parameter CTRL_IPREF_ENABLE = 0,
    parameter CTRL_PLRU_ENABLE = 0,
    parameter SET_SIZE = 4,
    parameter GROUP_NUM = 128,
    parameter LINE_WIDTH = 256,
    parameter INDEX_WIDTH = $clog2(GROUP_NUM),
    parameter OFFSET_WIDTH = $clog2(LINE_WIDTH / 8),
    parameter TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH,
    parameter WAY_WIDTH = $clog2(SET_SIZE),
    parameter type index_t  = logic [INDEX_WIDTH  -1:0],
    parameter type offset_t = logic [OFFSET_WIDTH -1:0],
    parameter type tag_t    = logic [TAG_WIDTH    -1:0],
    parameter type way_t    = logic [WAY_WIDTH    -1:0]
) (
    input logic clk,
    input logic reset,

    // CACHE instruction
    input logic m0_cache_valid,
    input logic m0_cache_op,
    input logic m1_cache_valid,
    input logic m1_cache_op,
    input way_t m1_way,

    // basic request signals
    input logic       m0_valid,
    input logic       m0_uncache,
    input index_t     m0_index,
    input tag_t       m0_tag,
    input offset_t    m0_offset,
    input logic [1:0] m0_size,
    input logic       m1_valid,
    input logic       m1_uncache,
    input index_t     m1_index,
    input tag_t       m1_tag,
    input offset_t    m1_offset,
    input logic [1:0] m1_size,

    // basic response signals
    output logic m0_addr_ok,
    output logic m1_data_ok,
    output logic [63:0] m1_rdata,

    // Cache - AXI_crossbar
    // AXI request
    output axi_req_t    axi_req,
    output logic [3 :0] axi_req_arid,
    output logic [3 :0] axi_req_awid,
    output logic [3 :0] axi_req_wid,
	// AXI response
    input  axi_resp_t   axi_resp,
    input  logic [3 :0] axi_resp_rid,
    input  logic [3 :0] axi_resp_bid,

    // Miss info
    output logic [31:0] ms_addr,
    output logic ms_valid
);

    typedef struct packed {
        logic valid;
        tag_t tag;
    } tagv_t;

    typedef logic [LINE_WIDTH / 32 - 1 : 0][31: 0] line_t;

    index_t way_rindex;
    index_t way_windex;
    logic [SET_SIZE - 1:0] way_data_wen;
    logic [SET_SIZE - 1:0] way_tagv_wen;
    logic  way_wvalid;
    line_t way_wdata;
    tagv_t [SET_SIZE - 1:0] way_tagv ;
    line_t [SET_SIZE - 1:0] way_rdata;
    logic enb;

    logic [63: 0] rdata_h;                      // read data hit
    logic cache_hit;
    logic [SET_SIZE - 1:0] hit;
    way_t hit_way;
    logic doable;

    logic data_delay;
    logic d_cache_hit;

    // prefetch related signals
    logic         rq_valid;
    logic [31: 0] rq_addr;
    logic         pf_valid;
    logic [31: 0] pf_addr;
    logic         pf_answer;

    logic [OFFSET_WIDTH - 1 - 2:0] refill_offset;
    logic [LINE_WIDTH / 32 - 1 :0] refill_rdy;
    way_t  refill_way;
    way_t  refill_way_que[3:0];
    logic  [1:0] refill_way_wq, refill_way_rq;
    line_t refill_data_store;
    line_t refill_data;     

    logic hazard;
    assign hazard = way_rindex == way_windex;

    logic wprio;
    localparam logic WP_CACHE = 0;
    localparam logic WP_REFILL = 1;
    // logic rprio;
    // localparam logic RP_RTAGV = 0;
    // localparam logic RP_PREF = 1;

    // bc 寄存器
    index_t  bc_index ;
    tag_t    bc_tag   ;
    offset_t bc_offset;
    logic    bc_uncache;
    logic [2:0] bc_size;
    logic    bc_pf_valid;
    logic    bc_pf_off;
    logic    bc_pf_data_delay;
    logic    bc_d_pf_off;

    logic [2:0] bus_state, bus_next_state;
    localparam logic [2:0] S_BUS_IDLE  = 3'b000;
    localparam logic [2:0] S_BUS_RDREQ = 3'b001;     // set axi_req.arvalid
    localparam logic [2:0] S_BUS_READ  = 3'b010;
    localparam logic [2:0] S_BUS_REFILL= 3'b011;
    always_ff @(posedge clk) begin
        if (reset) bus_state <= S_BUS_IDLE;
        else bus_state <= bus_next_state;
    end

    always_comb begin
        bus_next_state = bus_state;
        pf_answer      = 0;
        case (bus_state)
            S_BUS_IDLE: begin
                if (m1_valid && ((!data_delay && !cache_hit) || (data_delay && !d_cache_hit)) && !m1_uncache && !m1_cache_valid) begin
                    bus_next_state = S_BUS_RDREQ;
                end
                else if (m0_valid && m0_uncache || m1_valid && m1_uncache) begin
                    bus_next_state = S_BUS_RDREQ;
                end
                else if (pf_valid && !m0_valid) begin
                    pf_answer = 1;
                    bus_next_state = S_BUS_RDREQ;
                end
            end
            S_BUS_RDREQ: begin
                if (bc_pf_valid && bc_pf_off && !bc_pf_data_delay) begin
                    bus_next_state = S_BUS_IDLE;
                end
                else if (axi_resp.arready) begin
                    bus_next_state = S_BUS_READ;
                end
            end
            S_BUS_READ: begin
                if (axi_resp.rvalid && axi_resp.rlast && axi_req.rready) begin
                    if (bc_uncache) begin
                        bus_next_state = S_BUS_IDLE;
                    end
                    else begin
                        bus_next_state = S_BUS_REFILL;
                    end
                end
            end
            S_BUS_REFILL: begin
                if (wprio == WP_REFILL && !(hazard && m0_valid && (!m1_valid || m1_data_ok) && !(m0_cache_valid && m0_index == bc_index))) begin
                    bus_next_state = S_BUS_IDLE;
                end
            end
        endcase
    end

    // logic [31:0] miss_cnt;
    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         miss_cnt <= 0;
    //     end
    //     else if (|way_data_wen) begin
    //         miss_cnt <= miss_cnt + 1;
    //     end
    // end

    assign wprio = (m1_cache_valid && m1_valid) ? WP_CACHE : WP_REFILL;
    // assign rprio = (m0_valid) ? RP_RTAGV : RP_PREF;

    always_ff @(posedge clk) begin
        if (/*reset || */bus_next_state == S_BUS_IDLE) begin
            refill_rdy <= 0;
            bc_uncache <= 0;
            bc_pf_valid<= 0;
        end
        else if (bus_state == S_BUS_IDLE && bus_next_state == S_BUS_RDREQ) begin
            if (m1_valid && ((!data_delay && !cache_hit) || (data_delay && !d_cache_hit)) && !m1_uncache && !m1_cache_valid) begin     // regular read or write miss
                bc_index   <= m1_index;
                bc_tag     <= m1_tag;
                bc_offset  <= m1_offset;
                bc_uncache <= m1_uncache;
                refill_offset <= m1_offset[OFFSET_WIDTH - 1:2];
            end
            else if (m1_valid && m1_uncache) begin    // m1 uncache read
                bc_index   <= m1_index;
                bc_tag     <= m1_tag;
                bc_offset  <= m1_offset;
                bc_uncache <= m1_uncache;
                bc_size    <= {1'b0, m1_size};
            end
            else if (m0_valid && m0_uncache) begin    // m0 uncache read
                bc_index   <= m0_index;
                bc_tag     <= m0_tag;
                bc_offset  <= m0_offset;
                bc_uncache <= m0_uncache;
                bc_size    <= {1'b0, m0_size};
            end
            else if (pf_valid && !m0_valid) begin
                bc_pf_valid<= 1;
                bc_index   <= pf_addr[OFFSET_WIDTH +: INDEX_WIDTH];
                bc_tag     <= pf_addr[OFFSET_WIDTH + INDEX_WIDTH +: TAG_WIDTH];
                bc_offset  <= {OFFSET_WIDTH{1'b0}};
                bc_uncache <= 0;
                refill_offset <= 3'b0;
            end
            refill_rdy <= 8'b0;
        end
        else if (bus_state == S_BUS_RDREQ || bus_state == S_BUS_READ || bus_state == S_BUS_REFILL) begin    // prepare for refill data
            if (axi_req.rready && axi_resp.rvalid && !bc_uncache) begin
                refill_data[refill_offset] <= axi_resp.rdata;
                refill_rdy [refill_offset] <= 1;
                refill_offset <= refill_offset + 1;
            end
        end
    end

    // prefetcher unit
    if (CTRL_IPREF_ENABLE == 1) begin
    assign ms_valid = m1_valid && !m1_uncache && !m1_cache_valid && ((!data_delay && !cache_hit) || (data_delay && !d_cache_hit)) && bus_state == S_BUS_IDLE;
    assign ms_addr = {m1_tag, m1_index, {OFFSET_WIDTH{1'b0}}};
    assign rq_valid = (m1_valid && !m1_uncache && !m1_cache_valid);
    assign rq_addr  = {m1_tag, m1_index, 5'b0};
    Prefetcher #(
        .LINE_WIDTH(LINE_WIDTH)
    ) prefetcher (
        .clk,
        .reset,

        .ms_valid,
        .ms_addr,
        .rq_valid,
        .rq_addr,
        .pf_valid,
        .pf_addr,
        .pf_answer
    );
    always_comb begin
        bc_pf_off = 0;
        for(int i=0;i < SET_SIZE;++i) begin
            if (way_tagv[i].valid && way_tagv[i].tag == bc_tag) begin
                bc_pf_off = 1;
            end
        end 
    end
    always_ff @(posedge clk) begin
        if (pf_answer) begin
            bc_pf_data_delay <= 0;
        end
        else if (!bc_pf_data_delay) begin
            bc_pf_data_delay <= 1;
            bc_d_pf_off      <= bc_pf_off;
        end
    end
    end
    else begin
    assign pf_valid = 0;
    end
    
    way_t way_to_replace;
    if (CTRL_PLRU_ENABLE == 0) begin
    // LFSR
    way_t randWay       ;
    LFSR lfsr(
        .clk            (clk            ),
        .reset          (reset          ),
        .q              (               ),
        .way_to_replace (randWay        )
    );
    always_comb begin
        if (SET_SIZE == 4) begin
            way_to_replace = (!way_tagv[0].valid) ? 0 :
                             (!way_tagv[1].valid) ? 1 :
                             (!way_tagv[2].valid) ? 2 :
                             (!way_tagv[3].valid) ? 3 : randWay;
        end
        else if (SET_SIZE == 2) begin
            way_to_replace = (!way_tagv[0].valid) ? 0 :
                             (!way_tagv[1].valid) ? 1 : randWay;
        end
    end
    end
    else begin
    way_t lru_way;
    logic lru_valid;
    index_t lru_index;
    way_t ask_way  ;
    assign lru_valid = (m1_valid && !m1_cache_valid && !m1_uncache && !data_delay) || (bc_pf_valid && !bc_pf_data_delay && !bc_pf_off);
    assign lru_index = (m1_valid) ? m1_index : bc_index;
    assign ask_way   = (cache_hit && m1_valid) ? hit_way : way_to_replace;

    PLRU #(
        .SET_SIZE(SET_SIZE),
        .GROUP_NUM(GROUP_NUM)
    ) plru (
        .clk,
        .reset,
        .valid(lru_valid),
        .index(lru_index),
        .ask_way(ask_way),
        .lru_way(lru_way)
    );
    always_comb begin
        if (SET_SIZE == 4) begin
            way_to_replace = (!way_tagv[0].valid) ? 0 :
                             (!way_tagv[1].valid) ? 1 :
                             (!way_tagv[2].valid) ? 2 :
                             (!way_tagv[3].valid) ? 3 : lru_way;
        end
        else if (SET_SIZE == 2) begin
            way_to_replace = (!way_tagv[0].valid) ? 0 :
                             (!way_tagv[1].valid) ? 1 : lru_way;
        end
    end
    end
    always_ff @(posedge clk) begin
        if (reset) begin
            // refill_way_que[0] <= 0;
            // refill_way_que[1] <= 0;
            // refill_way_que[2] <= 0;
            // refill_way_que[3] <= 0;
            refill_way_wq  <= 0;
        end
        else if (m1_valid && !data_delay && !cache_hit) begin
            refill_way_que[refill_way_wq] <= way_to_replace;
            refill_way_wq  <= refill_way_wq + 1;
        end
        if (reset) begin
            refill_way_rq  <= 0;
        end
        else if (bus_state == S_BUS_REFILL && bus_next_state == S_BUS_IDLE) begin
            refill_way_rq  <= refill_way_rq + 1;
        end
    end
    assign refill_way = refill_way_que[refill_way_rq];
    assign way_tagv_wen = (m1_valid && m1_cache_valid && m1_cache_op) ? hit : 
                          (m1_valid && m1_cache_valid && !m1_cache_op) ? 1 << m1_way : 
                          (bus_state == S_BUS_REFILL && bus_next_state == S_BUS_IDLE) ? 1 << refill_way : 0;
    assign way_data_wen = (bus_state == S_BUS_REFILL && bus_next_state == S_BUS_IDLE) ? 1 << refill_way : 0;
    
    assign way_wdata  = refill_data;
    assign way_wvalid = !m1_cache_valid;

    assign way_rindex = (m0_valid) ? m0_index : pf_addr[OFFSET_WIDTH +: INDEX_WIDTH];
    assign way_windex = (wprio == WP_CACHE) ? m1_index : bc_index;

    assign enb = !(hazard && m1_cache_valid && m1_valid);

    // generate block RAMs
    for(genvar i = 0; i < SET_SIZE; ++i) begin : gen_icache_mem
        simpleDualPortRam #(
            .dataWidth(21),
            .byteWidth(21),
            .portWidth(21),
            .ramDepth(GROUP_NUM)
        ) tagv_ram (
            .clk,
            .reset,

            .addra(way_windex),
            .addrb(way_rindex),
            .wen(way_tagv_wen[i]),
            .wdata({way_wvalid, bc_tag}),
            .ena(way_tagv_wen[i]),
            .enb(enb),

            .rdata(way_tagv[i])
        );

        simpleDualPortRam #(
            .byteWidth(LINE_WIDTH),
            .portWidth(LINE_WIDTH),
            .ramDepth (GROUP_NUM)
        ) data_ram (
            .clk,
            .reset,

            .addra(way_windex),
            .addrb(way_rindex),
            .wen(way_data_wen[i]),
            .wdata(way_wdata),
            .ena(way_data_wen[i]),
            .enb(enb),

            .rdata(way_rdata[i])
        );
    end

    // does it hit?
    for(genvar i = 0; i < SET_SIZE; ++i) begin : gen_icache_hit
        assign hit[i] = (way_tagv[i].valid && (m1_tag == way_tagv[i].tag)) ? 1 : 0;
    end
    always_comb begin
        if (SET_SIZE == 4) begin
            hit_way = hit[0] ? 0 : hit[1] ? 1 : hit[2] ? 2 : hit[3] ? 3 : 0;
        end
        else if (SET_SIZE == 2) begin
            hit_way = hit[0] ? 0 : hit[1] ? 1 : 0;
        end
    end
    assign cache_hit = (|hit && !m1_uncache);

    always_ff @(posedge clk) begin
        if (reset) begin
            data_delay  <= 0;
            d_cache_hit <= 0;
            // d_hit_way   <= 0;
            // d_valid     <= 0;
            // d_dirt      <= 0;
            // d_way_rdata <= 0;
        end
        else if (m0_addr_ok && (!m1_valid || m1_data_ok)) begin // 这是一个很关键的时机，它意味着可能有请求在上升沿进入，从而把data_delay这个关键信号置零
            data_delay  <= 0;
            d_cache_hit <= 0;
            // d_hit_way   <= 0;
            // d_valid     <= 0;
            // d_dirt      <= 0;
            // d_way_rdata <= 0;
        end
        else if (!data_delay) begin
            data_delay  <= 1;
            d_cache_hit <= cache_hit;
            // d_hit_way   <= hit_way;
            // d_valid     <= way_tagv[m1_way].valid;
            // d_dirt      <= (m1_cache_op) ? way_dirt[hit_way] : way_dirt[m1_way];
            // d_way_rdata <= way_rdata;
        end
    end

    assign rdata_h[31: 0] = way_rdata[hit_way][m1_offset[OFFSET_WIDTH - 1:2]];
    assign rdata_h[63:32] = way_rdata[hit_way][m1_offset[OFFSET_WIDTH - 1:2] + 1];

    assign doable = (m1_tag == bc_tag && m1_index == bc_index && !m1_uncache && (bus_state != S_BUS_IDLE));

    assign m0_addr_ok = (bus_state != S_BUS_IDLE && m0_cache_valid && m0_index == bc_index && !bc_uncache) ? 0 : enb;
    // assign m0_data_ok = (m_status == `LOOKUP && cache_hit) | (m_status == `LOOKUP && m1_cache_valid) |  // if hit-invalidate, whether hit or not, set data_ok.
    //     (m_status == `REFILL && axi_resp.rvalid && ret_num == (m1_offset[4:2] + 1)) | 
    //     (m_status == `REFILL && axi_resp.rvalid && m1_uncache);
    always_comb begin
        m1_data_ok = 0;
        if (m1_valid && !m1_cache_valid && cache_hit && !data_delay) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && !m1_cache_valid && doable) begin
            if (refill_offset == (m1_offset[OFFSET_WIDTH - 1:2] + 1) && axi_resp.rvalid && axi_req.rready) begin
                m1_data_ok = 1;
            end
            else if (refill_rdy[m1_offset[OFFSET_WIDTH - 1:2] + 1]) begin
                m1_data_ok = 1;
            end
        end
        else if (m1_valid && bc_uncache && axi_resp.rvalid && axi_req.rready) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && m1_cache_valid) begin
            m1_data_ok = 1;
        end
    end
    assign m1_rdata = (cache_hit && !data_delay) ? rdata_h : 
                      (bc_uncache && m1_offset[2:0] == 3'b0) ? {32'b0, axi_resp.rdata} :
                      (bc_uncache) ? {axi_resp.rdata, 32'b0} : 
                      (refill_rdy[m1_offset[OFFSET_WIDTH - 1:2] + 1]) ? {refill_data[m1_offset[OFFSET_WIDTH - 1:2] + 1], refill_data[m1_offset[OFFSET_WIDTH - 1:2]]} : 
                      {axi_resp.rdata, refill_data[m1_offset[OFFSET_WIDTH - 1:2]]};

    assign axi_req.awvalid = 0;        // icache doesn't write back
    assign axi_req.wvalid  = 0;   
    assign axi_req.awaddr  = 0;
    assign axi_req.awlen   = 0;
    assign axi_req.awsize  = 0;
    assign axi_req.awburst = 0;
    assign axi_req.awlock  = 0;
    assign axi_req.awcache = 0;
    assign axi_req.awprot  = 0;
    assign axi_req.wdata   = 0;
    assign axi_req.wstrb   = 0;
    assign axi_req.wlast   = 0;
    assign axi_req.bready  = 1;

    assign axi_req.arvalid = (bus_state == S_BUS_RDREQ && !(bc_pf_valid && ((!bc_pf_data_delay && bc_pf_off) || (bc_pf_data_delay && bc_d_pf_off))));
    assign axi_req.araddr  = (bc_uncache) ? {bc_tag, bc_index, bc_offset} : {bc_tag, bc_index, bc_offset[OFFSET_WIDTH - 1:2], 2'b0}; 
    assign axi_req.arlen   = (bc_uncache) ? 4'b0000 : (LINE_WIDTH / 32 - 1);
    assign axi_req.arsize  = (bc_uncache) ? bc_size : 3'b010;   // represents 4 bytes.
    assign axi_req.arburst = (bc_uncache) ? 2'b0 : 2'b10;
    assign axi_req.arlock  = 2'd0;
    assign axi_req.arcache = 4'd0;
    assign axi_req.arprot  = 3'd0;

    assign axi_req.rready = 1;          // icache always ready!

    assign axi_req_arid = 0;
    assign axi_req_awid = 0;
    assign axi_req_wid = 0;
    /*
    (*mark_debug = "true"*)wire[2:0] db_i_bus_state = bus_state;
    (*mark_debug = "true"*)wire db_i_m1_valid = m1_valid;
    (*mark_debug = "true"*)wire db_i_m1_uncache = m1_uncache;
    (*mark_debug = "true"*)wire db_i_m1_cache_valid = m1_cache_valid;
    (*mark_debug = "true"*)wire db_i_wprio = wprio;
    (*mark_debug = "true"*)wire db_i_hazard = hazard;
    (*mark_debug = "true"*)wire db_i_doable = doable;
    (*mark_debug = "true"*)wire db_i_cache_hit = cache_hit;
    (*mark_debug = "true"*)wire db_i_data_delay = data_delay;
    (*mark_debug = "true"*)wire db_i_enb = enb;
    (*mark_debug = "true"*)wire[7:0] db_i_refill_rdy = refill_rdy;
    */
endmodule