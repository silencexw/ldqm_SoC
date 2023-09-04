`timescale 1ns / 1ps
`include "mem_if_def.svh"
/* manage the dcache-sram and read-write bus. Dcache will
 * ask this module for read, write, uncache req and CACHE inst
 * and this module will return data_ok as soon as possible and 
 * handle sram and bus activities itself.
 */

module D_Cache_AXI #(
    parameter CTRL_DPREF_ENABLE = 1,
    parameter CTRL_PLRU_ENABLE = 0,
    parameter SET_SIZE = 4,
    parameter GROUP_NUM = 128,
    parameter LINE_WIDTH = 256,
    parameter UW_FIFO_DEPTH = 16,
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
    input logic m0_cache_writeback,
    input logic m1_cache_valid,
    input logic m1_cache_op,
    input logic m1_cache_writeback,
    input way_t m1_way,

    // basic request signals
    input logic m0_valid,
    input logic m0_uncache,
    input index_t  m0_index,
    input tag_t    m0_tag,
    input offset_t m0_offset,
    input logic [ 1: 0] m0_size,
    input logic m0_op,
    input logic m1_valid,
    input logic m1_uncache,
    input index_t  m1_index,
    input tag_t    m1_tag,
    input offset_t m1_offset,
    input logic [ 1: 0] m1_size,
    input logic m1_op,
    input logic [31: 0] m1_wdata,
    input logic [ 3: 0] m1_wstrb,

    // basic response signals
    output logic m0_addr_ok,
    output logic m1_data_ok,
    output logic [31:0] m1_rdata,

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

    typedef logic [LINE_WIDTH / 32 - 1 : 0][31: 0] line_t;       // 1 cache line, 8 words, 8 * 4 = 32 bytes, 8 * 32 = 256 bits

    // uncache-write fifo store buf
    typedef struct packed {
        logic [31:0] addr;      // physical address
        logic [31:0] data;
        logic [ 3:0] strobe;
        logic [ 2:0] size;      // this may be useless
    } uw_fifo_t;

    // AXI bus controller FSM related signals
    logic [2:0] bus_state, bus_next_state;
    localparam logic [2:0] S_BUS_IDLE  = 3'b000;
    localparam logic [2:0] S_BUS_RDREQ = 3'b001;     // set axi_req.arvalid
    localparam logic [2:0] S_BUS_READ  = 3'b010;
    localparam logic [2:0] S_BUS_REFILL= 3'b011;
    localparam logic [2:0] S_BUS_WTREQ = 3'b100;
    localparam logic [2:0] S_BUS_WRITE_BACK = 3'b101;
    always_ff @(posedge clk) begin
        if (reset) bus_state <= S_BUS_IDLE;
        else bus_state <= bus_next_state;
    end
    logic read_over;    // means the FSM can goto S_BUS_REFILL, all axi read is over.

    // AXI bus control signals
    index_t  bc_index; // bus-control index 
    tag_t    bc_tag;
    offset_t bc_offset;
    logic [31: 0] bc_addr;  // for uncache write and CACHE inst
    logic [ 2: 0] bc_size;  // for uncache write
    logic [ 3: 0] bc_wstrb; // for uncache write
    logic [31: 0] bc_uw_data; // for uncache write
    line_t        bc_data;  // for CACHE inst
    logic         bc_uncache;
    logic         bc_cache_inst;
    logic [OFFSET_WIDTH - 1 - 2: 0] bc_ret_off;   // to record the offset of the next word to be transfered.
    logic [ 3: 0] bc_wb_cnt;
    line_t        bc_write_back_data;
    logic [31: 0] bc_write_back_addr;

    logic         refill_dirty;
    way_t         refill_way;
    logic         duplication;  // refill a cacheline which is already in ram.
    logic         refill_off;   // the refill is off, canceled
    line_t        refill_data;
    logic [LINE_WIDTH / 32 : 0] refill_rdy;  // to record words that have been read back or written.
    line_t        refill_strobe;
    logic [31: 0] m1_strobe;
    /* about refill_strobe: when write into refill data, use refill_strobe to record
     * wstrb at the same time. In case the transfer data comes later, it will use refill_strobe
     * to determine which bits to write.
     * in refill_data, a word is valid iff a transfer have written the word.
     */

    // prefetch related signals
    logic         rq_valid;
    logic [31: 0] rq_addr;
    logic         pf_valid;
    logic [31: 0] pf_addr;
    logic         pf_answer;

    // uncache write buffer related signals
    uw_fifo_t [UW_FIFO_DEPTH - 1 : 0] uw_fifo_store;
    uw_fifo_t uw_req;
    // logic m0_cache_wr, m0_cache_wv, m1_cache_wf;
    logic uw_w_req, uw_r_req, uw_answer, uw_empty;
    logic[$clog2(UW_FIFO_DEPTH) : 0] uw_w_ptr, uw_r_ptr, uw_cnt;
    logic fifo_full;


    // ram related signals
    logic [SET_SIZE - 1 : 0][LINE_WIDTH / 8:0] way_data_wen;
    logic [SET_SIZE - 1 : 0] way_tagv_wen;
    logic [SET_SIZE - 1 : 0] way_setd;
    logic [SET_SIZE - 1 : 0] way_dirt;
    index_t way_rindex;
    index_t way_windex;
    // logic [11:5] way_drindex; // dirt file read index
    // logic [11:5] way_dwindex; // dirt file write index
    line_t [SET_SIZE - 1 : 0] way_rdata;
    line_t way_wdata;
    logic  way_wdirt;
    logic way_wvalid;
    line_t hit_wdata;
    tagv_t [SET_SIZE - 1:0] way_tagv;
    logic enb;
    logic hazard;
    logic [1:0] rprio, wprio;
    localparam [1:0] WP_REFILL = 2'b00;
    localparam [1:0] WP_WDATA  = 2'b01;
    localparam [1:0] WP_CACHE  = 2'b10;
    localparam [1:0] RP_REFILL = 2'b00;
    localparam [1:0] RP_RTAGV  = 2'b01;
    // localparam [1:0] RP_CACHE  = 2'b10;
    logic m0_forward, m1_forward;

    logic [SET_SIZE - 1 : 0] hit;
    way_t hit_way;
    logic cache_hit;
    logic doable;
    logic [31:0] rdata_h, rdata_t;
    
    // delay 系列变量存储没有及时完成的m1级请求在刚进入m1级的那个周期得到的重要数据
    // data_delay 是一个重要信号，当m1_valid置高是才有意义，它为0意味着本周期是m1级请求进入m1级的第一个周期，它所需的data, tagv, dirt刚从广义ram中读出。
    logic  data_delay;
    line_t [SET_SIZE - 1:0] d_way_rdata;
    tagv_t [SET_SIZE - 1:0] d_way_tagv;
    logic  d_valid;
    logic  d_dirt;
    way_t  d_hit_way;
    logic  d_cache_hit;

    always_comb begin
        if (bus_state == S_BUS_REFILL) begin
            wprio = WP_REFILL;
        end
        else if (m1_valid && m1_op) begin
            wprio = WP_WDATA;
        end
        else begin
            wprio = WP_CACHE;
        end

        if (m0_valid && (!m1_valid || m1_data_ok) && !(m0_cache_valid && m0_index == bc_index && !bc_uncache && (bus_state == S_BUS_RDREQ || bus_state == S_BUS_READ))) begin
            rprio = RP_RTAGV;
        end
        else begin
            rprio = RP_REFILL;
        end
    end
    // hazard 信号含义：所有广义ram读写端口地址相同
    assign hazard = way_rindex == way_windex;
    // 转发的严苛的条件：连续的写后读，同一地址且写请求命中
    // m0_forward 信号含义：m1级是写请求且命中，并且发生了hazard
    assign m0_forward = (hazard && cache_hit && !data_delay && m1_op && m0_offset[OFFSET_WIDTH - 1:2] == m1_offset[OFFSET_WIDTH - 1:2] && m0_tag == m1_tag);
    // assign m0_forward = 0;
    always_ff @(posedge clk) begin
        m1_forward <= m0_forward;
    end
    // assign enb = !((|way_tagv_wen || |way_data_wen) && hazard);
    assign enb = !(hazard && ((m1_op && cache_hit && !data_delay) || (m1_valid && m1_cache_valid && !data_delay && (!m1_cache_op || cache_hit)) || wprio == WP_REFILL));
    // assign enb = !(hazard && ((m1_op && m1_valid && !data_delay) || (m1_valid && m1_cache_valid && !data_delay) || wprio == WP_REFILL));
    assign way_rindex = (rprio == RP_RTAGV) ? m0_index : bc_index;
    assign way_windex = (wprio == WP_REFILL) ? bc_index : m1_index;

    // logic of way_tagv_wen
    always_comb begin
        way_tagv_wen = 0;
        way_wvalid = 0;
        if (wprio == WP_REFILL && !refill_off) begin
            way_tagv_wen = 1 << refill_way;
            way_wvalid = 1;
        end
        else if (m1_cache_valid && !m1_cache_op && !data_delay) begin   // 0 for index invalidate
            way_tagv_wen = 1 << m1_way;
        end
        else if (m1_cache_valid && m1_cache_op) begin  // 1 for hit invalidate
            way_tagv_wen = (cache_hit && !data_delay) ? hit : 0;
        end
    end

    always_comb begin
        way_data_wen = 0;
        way_setd     = 0;
        if (wprio == WP_REFILL && !refill_off) begin
            way_data_wen[refill_way] = -1;
            way_setd[refill_way]     = 1;
        end
        else if (m1_op && cache_hit && !data_delay) begin
            for (int i = 0;i < SET_SIZE;i++) begin
                if (hit[i]) begin
                    way_data_wen[i] = {'0, m1_wstrb} << (m1_offset[OFFSET_WIDTH - 1:2] * 4);    // about grammar?
                    way_setd[i] = 1;
                end
            end
        end
        else if (m1_valid && m1_cache_valid && !data_delay) begin // 这里的逻辑可以简化
            if (m1_cache_op && cache_hit) begin
                way_setd[hit_way] = 1;
            end
            else if (!m1_cache_op) begin
                way_setd[m1_way]  = 1;
            end
        end
    end

    assign hit_wdata = {{(LINE_WIDTH - 32){1'b0}}, m1_wdata} << (m1_offset[OFFSET_WIDTH - 1:2] * 32);
    assign way_wdata = (m1_valid && m1_op && cache_hit && !data_delay) ? hit_wdata : refill_data;
    assign way_wdirt = (wprio == WP_REFILL) ? refill_dirty : (m1_valid && m1_cache_valid) ? 0 : 1; // refill CACHE hit写请求 三种情况
    always_ff @(posedge clk) begin
        rdata_t <= (m1_wdata & m1_strobe) | (way_rdata[hit_way][m1_offset[OFFSET_WIDTH - 1:2]] & ~m1_strobe);
    end

    way_t way_to_replace;

    if (CTRL_PLRU_ENABLE == 0) begin
    // LFSR
    way_t randWay;

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
    // PLRU
    way_t lru_way  ;
    logic lru_valid;
    index_t lru_index;
    way_t ask_way  ;
    assign lru_valid = (m1_valid && !m1_cache_valid && !m1_uncache && !data_delay && cache_hit) || (bus_state == S_BUS_REFILL);
    assign lru_index = (bus_state == S_BUS_REFILL) ? bc_index : m1_index;
    assign ask_way   = (bus_state == S_BUS_REFILL) ? way_to_replace : hit_way;

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

    always_comb begin
        duplication = 0;
        for(int i=0;i < SET_SIZE;++i) begin
            if (way_tagv[i].valid && way_tagv[i].tag == bc_tag) begin
                duplication = 1;
            end
        end 
    end

    // the rams of the dcache.
    for(genvar i = 0; i < SET_SIZE; ++i) begin : gen_dcache_mem
        // is a registor file with 1 cycle latency.
        `ifdef DIRT_USE_REG_FILE
        dirt_reg_file #(
            .GROUP_NUM(GROUP_NUM)
        ) dirt_file (
            .clk,
            .reset,
            .set_D(way_setd[i]),        
            .wdirt(way_wdirt),   
            .addra(way_windex),        
            .addrb(way_rindex),
            .isDirt(way_dirt[i])
        );
        `else
        // dirt_lut dirt_file (
        //     .a(way_windex),          // input wire [6 : 0] a
        //     .d(way_wdirt),           // input wire [0 : 0] d
        //     .dpra(way_rindex),       // input wire [6 : 0] dpra
        //     .clk(clk),               // input wire clk
        //     .we(way_setd[i]),        // input wire we
        //     .qdpo_clk(clk),          // input wire qdpo_clk
        //     .qdpo(way_dirt[i])       // output wire [0 : 0] qdpo
        // );
        xpm_memory_dpdistram #(
            .ADDR_WIDTH_A(INDEX_WIDTH),
            .ADDR_WIDTH_B(INDEX_WIDTH),
            .BYTE_WRITE_WIDTH_A(1),
            .MEMORY_SIZE(1 * GROUP_NUM),
            .MESSAGE_CONTROL(1),
            .READ_DATA_WIDTH_A(1),
            .READ_DATA_WIDTH_B(1),
            .READ_LATENCY_A(1),
            .READ_LATENCY_B(1),
            .SIM_ASSERT_CHK(1),
            .WRITE_DATA_WIDTH_A(1)
        ) dirt_file (
            .douta(),              // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
            .doutb(way_dirt[i]),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            .addra(way_windex),    // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
            .addrb(way_rindex),    // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
            .clka(clk),
            .dina(way_wdirt),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            .ena(way_setd[i]),       
            .enb(enb),       
            .regcea(1),         // 1-bit input: Clock Enable for the last register stage on the output data path.
            .regceb(1),         // 1-bit input: Do not change from the provided value.
            .rsta(reset),     
            .rstb(reset),     
            .wea(way_setd[i])
        );
        `endif

        `ifdef TAGV_USE_IP_CORE
        simple_dual_port_d_tagv tagv_ram (
            .clka(clk),                 // input wire clka
            .ena(way_tagv_wen[i]),
            .wea(way_tagv_wen[i]),      // input wire [0 : 0] wea
            .addra(way_windex),         // input wire [6 : 0] addra
            .dina({way_wvalid, bc_tag}),// input wire [20 : 0] dina
            .clkb(clk),                 // input wire clkb
            .enb(enb),
            .addrb(way_rindex),         // input wire [6 : 0] addrb
            .doutb(way_tagv[i])         // output wire [20 : 0] doutb
        );
        `elsif TAGV_USE_LUT
        // simple_dual_port_lut_tagv tagv_ram (
        //     .a(way_windex),                // input wire [6 : 0] a
        //     .d({way_wvalid, bc_tag}),      // input wire [20 : 0] d
        //     .dpra(way_rindex),             // input wire [6 : 0] dpra
        //     .clk(clk),                     // input wire clk
        //     .we(way_tagv_wen[i]),          // input wire we
        //     .qdpo_clk(clk),                // input wire qdpo_clk
        //     .qdpo(way_tagv[i])             // output wire [20 : 0] qdpo
        // );
        xpm_memory_dpdistram #(
            .ADDR_WIDTH_A(INDEX_WIDTH),
            .ADDR_WIDTH_B(INDEX_WIDTH),
            .BYTE_WRITE_WIDTH_A(21),
            .MEMORY_SIZE(21 * GROUP_NUM),
            .MESSAGE_CONTROL(1),
            .READ_DATA_WIDTH_A(21),
            .READ_DATA_WIDTH_B(21),
            .READ_LATENCY_A(1),
            .READ_LATENCY_B(1),
            .SIM_ASSERT_CHK(1),
            .WRITE_DATA_WIDTH_A(21)
        ) tagv_ram (
            .douta(),        // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
            .doutb(way_tagv[i]),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            .addra(way_windex),    // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
            .addrb(way_rindex),    // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
            .clka(clk),
            .dina({way_wvalid, bc_tag}),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            .ena(way_tagv_wen[i]),       
            .enb(enb),       
            .regcea(1),         // 1-bit input: Clock Enable for the last register stage on the output data path.
            .regceb(1),         // 1-bit input: Do not change from the provided value.
            .rsta(reset),     
            .rstb(reset),     
            .wea(way_tagv_wen[i])
        );
        `else
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
        `endif

        `ifdef DATA_USE_IP_CORE
        simple_dual_port_d_way data_ram (
            .clka(clk),                 // input wire clka
            .ena(|way_data_wen[i]),
            .wea(way_data_wen[i]),      // input wire [31 : 0] wea
            .addra(way_windex),         // input wire [6 : 0] addra for write
            .dina(way_wdata),           // input wire [255 : 0] dina
            .clkb(clk),                 // input wire clkb
            .enb(enb),
            .addrb(way_rindex),         // input wire [6 : 0] addrb for read
            .doutb(way_rdata[i])        // output wire [255 : 0] doutb
        );
        `else
        simpleDualPortRam #(
            .ramDepth(GROUP_NUM),
            .portWidth(LINE_WIDTH)
        ) data_ram (
            .clk,
            .reset,

            .addra(way_windex),
            .addrb(way_rindex),
            .wen(way_data_wen[i]),
            .wdata(way_wdata),
            .ena(|way_data_wen[i]),
            .enb(enb),

            .rdata(way_rdata[i])
        );
        `endif
    end

    // find the hit way
    for(genvar i = 0; i < SET_SIZE; ++i) begin : gen_dcache_hit
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
    assign cache_hit = m1_valid && |hit && !m1_uncache;
    assign doable = (m1_tag == bc_tag && m1_index == bc_index && !m1_uncache && (bus_state == S_BUS_RDREQ || bus_state == S_BUS_READ));
    always_ff @(posedge clk) begin
        if (reset) begin
            data_delay  <= 0;
            // d_cache_hit <= 0;
            // d_hit_way   <= 0;
            // d_valid     <= 0;
            // d_dirt      <= 0;
            // d_way_rdata <= 0;
            // d_way_tagv  <= 0;
        end
        else if (m0_addr_ok && (!m1_valid || m1_data_ok)) begin // 这是一个很关键的时机，它意味着可能有请求在上升沿进入，从而把data_delay这个关键信号置零
            data_delay  <= 0;
            d_cache_hit <= 0;
            d_hit_way   <= 0;
            d_valid     <= 0;
            d_dirt      <= 0;
            d_way_rdata <= 0;
            d_way_tagv  <= 0;
        end
        else if (!data_delay) begin
            data_delay  <= 1;
            d_cache_hit <= cache_hit;
            d_hit_way   <= hit_way;
            d_valid     <= way_tagv[m1_way].valid;
            d_dirt      <= (m1_cache_op) ? way_dirt[hit_way] : way_dirt[m1_way];
            d_way_rdata <= way_rdata;
            d_way_tagv  <= way_tagv ;
        end
    end
    
    assign rdata_h = way_rdata[hit_way][m1_offset[OFFSET_WIDTH - 1:2]];

    // Uncache Write FIFO Part
    always_ff @(posedge clk) begin
        if (reset) begin
            uw_w_ptr <= '0;
        end else if (uw_w_req && !(uw_empty && uw_r_req)) begin
            uw_w_ptr <= uw_w_ptr + 1'd1;
        end
    end
    always_ff @(posedge clk) begin
        if (reset) begin
            uw_r_ptr <= '0;
        end else if (uw_r_req && !uw_empty) begin
            uw_r_ptr <= uw_r_ptr + 1'd1;
        end
    end
    always_ff @(posedge clk) begin
        if (uw_w_req) begin
            uw_fifo_store[uw_w_ptr[$clog2(UW_FIFO_DEPTH) - 1: 0]] <= uw_req;
        end
    end

    assign uw_w_req = !fifo_full && (m1_valid && m1_uncache && m1_op);
    assign uw_r_req = bus_state == S_BUS_IDLE && bus_next_state == S_BUS_WTREQ && uw_answer;
    assign uw_cnt = uw_w_ptr - uw_r_ptr;
    assign uw_empty = uw_cnt == 0;
    assign fifo_full = uw_cnt[$clog2(UW_FIFO_DEPTH)];

    always_comb begin
        uw_req.addr = {m1_tag, m1_index, m1_offset/*[OFFSET_WIDTH - 1:2], 2'b00*/};
        uw_req.data = m1_wdata;
        uw_req.strobe = m1_wstrb;
        uw_req.size = m1_size;
    end

    // prefetcher unit
    if (CTRL_DPREF_ENABLE == 1) begin
    assign ms_valid = m1_valid && !m1_uncache && !m1_cache_valid && ((!data_delay && !cache_hit) || (data_delay && !d_cache_hit)) && bus_state == S_BUS_IDLE;
    assign ms_addr = {m1_tag, m1_index, {OFFSET_WIDTH{1'b0}}};
    assign rq_valid = (m1_valid && !m1_uncache && !m1_cache_valid && !data_delay);
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
    end
    else begin
    assign pf_valid = 0;
    end

    // AXI bus controller FSM
    always_comb begin
        bus_next_state = bus_state;
        pf_answer = 0;
        uw_answer = 0;
        case (bus_state)
            S_BUS_IDLE: begin
                // normal read or write miss
                if (m1_valid && !m1_uncache && !m1_cache_valid && ((!data_delay && !cache_hit) || (data_delay && !d_cache_hit))) begin
                    bus_next_state = S_BUS_RDREQ;
                end
                else if (m1_valid && m1_cache_valid && m1_cache_writeback) begin
                    if (m1_cache_op && ((!data_delay && cache_hit && way_dirt[hit_way]) || (data_delay && d_cache_hit && d_dirt))) begin
                        bus_next_state = S_BUS_WTREQ;
                    end
                    else if (!m1_cache_op && ((!data_delay && way_dirt[m1_way]) || (data_delay && d_dirt))) begin
                        bus_next_state = S_BUS_WTREQ;
                    end
                end
                // uncache write buffer
                else if (!uw_empty || uw_w_req) begin
                    bus_next_state = S_BUS_WTREQ;
                    uw_answer = 1;
                end
                // uncache read
                else if (m0_valid && m0_uncache && !m0_op || m1_valid && m1_uncache && !m1_op) begin
                    bus_next_state = S_BUS_RDREQ;
                end
                // prefetch
                else if (pf_valid) begin
                    pf_answer = 1;
                    bus_next_state = S_BUS_RDREQ;
                end
            end
            S_BUS_RDREQ: begin
                if (axi_resp.arready) begin
                    bus_next_state = S_BUS_READ;
                end
            end
            S_BUS_READ: begin
                if (axi_resp.rvalid && axi_resp.rlast && axi_req.rready) begin
                    if (bc_uncache) begin
                        bus_next_state = S_BUS_IDLE;
                    end
                    else if (rprio == RP_REFILL && enb) begin
                        bus_next_state = S_BUS_REFILL;
                    end
                end
                else if (read_over && rprio == RP_REFILL && enb) begin
                    bus_next_state = S_BUS_REFILL;
                end
            end
            S_BUS_REFILL: begin
                if (way_dirt[way_to_replace] && !refill_off) begin // refill successfully && have to writeback
                    bus_next_state = S_BUS_WTREQ;
                end
                else begin                         // refill successfully && no need to writeback 
                    bus_next_state = S_BUS_IDLE;
                end
            end
            S_BUS_WTREQ: begin
                if (axi_resp.bvalid) begin
                    bus_next_state = S_BUS_IDLE;
                end
                else if (axi_resp.awready) begin
                    bus_next_state = S_BUS_WRITE_BACK;
                end
            end
            S_BUS_WRITE_BACK: begin
                if (axi_resp.bvalid) begin
                    bus_next_state = S_BUS_IDLE;
                end
            end
        endcase
    end

    // set axi bus control related signals
    assign m1_strobe = {{8{m1_wstrb[3]}}, {8{m1_wstrb[2]}}, {8{m1_wstrb[1]}}, {8{m1_wstrb[0]}}};
    // 
    always_comb begin
        refill_off = duplication;
        refill_way = way_to_replace;
    end
    always_ff @(posedge clk) begin
        if (/*reset || */bus_next_state == S_BUS_IDLE) begin
            refill_dirty <= 0;
            refill_strobe <= 0;
            bc_cache_inst <= 0;
            bc_tag <= 0;
            bc_index <= 0;
        end
        else if (bus_state == S_BUS_IDLE && bus_next_state == S_BUS_RDREQ) begin
            if (m1_valid && ((!data_delay && !cache_hit) || (data_delay && !d_cache_hit)) && !m1_uncache && !m1_cache_valid) begin     // regular read or write miss
                bc_index   <= m1_index;
                bc_tag     <= m1_tag;
                bc_offset  <= m1_offset;
                bc_uncache <= m1_uncache;
                bc_ret_off <= m1_offset[OFFSET_WIDTH - 1:2];
                if (m1_op) begin
                    refill_data  [m1_offset[OFFSET_WIDTH - 1:2]] <= (m1_wdata & m1_strobe);
                    refill_strobe[m1_offset[OFFSET_WIDTH - 1:2]] <= m1_strobe;
                    refill_dirty <= 1;
                end
            end
            else if (m1_valid && m1_uncache && !m1_op) begin    // m1 uncache read
                bc_index   <= m1_index;
                bc_tag     <= m1_tag;
                bc_offset  <= m1_offset;
                bc_uncache <= m1_uncache;
                bc_size    <= {1'b0, m1_size};
            end
            else if (m0_valid && m0_uncache && !m0_op) begin    // m0 uncache read
                bc_index   <= m0_index;
                bc_tag     <= m0_tag;
                bc_offset  <= m0_offset;
                bc_uncache <= m0_uncache;
                bc_size    <= {1'b0, m0_size};
            end
            else if (pf_valid) begin
                bc_index   <= pf_addr[OFFSET_WIDTH +: INDEX_WIDTH];
                bc_tag     <= pf_addr[OFFSET_WIDTH + INDEX_WIDTH +: TAG_WIDTH];
                bc_offset  <= {OFFSET_WIDTH{1'b0}};
                bc_uncache <= 0;
                bc_ret_off <= {(OFFSET_WIDTH - 2){1'b0}};
            end
            refill_rdy <= 8'b0;
        end
        else if (bus_state == S_BUS_IDLE && bus_next_state == S_BUS_WTREQ) begin
            if (m1_valid && m1_cache_valid && m1_cache_writeback) begin     // CACHE writeback inst 
                bc_uncache <= 0;
                bc_cache_inst <= 1;
                if (m1_cache_op) begin
                    bc_addr <= (!data_delay) ? {way_tagv[hit_way].tag, m1_index, {OFFSET_WIDTH{1'b0}}} : {d_way_tagv[d_hit_way].tag, m1_index, {OFFSET_WIDTH{1'b0}}};
                    bc_data <= (!data_delay) ? way_rdata[hit_way] : d_way_rdata[d_hit_way];
                end
                else begin
                    bc_addr <= (!data_delay) ? {way_tagv[m1_way].tag, m1_index, {OFFSET_WIDTH{1'b0}}} : {d_way_tagv[m1_way].tag, m1_index, {OFFSET_WIDTH{1'b0}}};
                    bc_data <= (!data_delay) ? way_rdata[m1_way] : d_way_rdata[m1_way];
                end
            end
            else if (!uw_empty) begin       // uncache writeback buffer
                bc_uncache <= 1;
                bc_addr <= uw_fifo_store[uw_r_ptr[$clog2(UW_FIFO_DEPTH) - 1: 0]].addr;
                bc_size <= uw_fifo_store[uw_r_ptr[$clog2(UW_FIFO_DEPTH) - 1: 0]].size;
                bc_uw_data <= uw_fifo_store[uw_r_ptr[$clog2(UW_FIFO_DEPTH) - 1: 0]].data;
                bc_wstrb <= uw_fifo_store[uw_r_ptr[$clog2(UW_FIFO_DEPTH) - 1: 0]].strobe;
            end
            else begin
                bc_uncache <= 1;
                bc_addr <= uw_req.addr;
                bc_size <= uw_req.size;
                bc_uw_data <= uw_req.data;
                bc_wstrb <= uw_req.strobe;
            end
        end
        else if (bus_state == S_BUS_RDREQ || bus_state == S_BUS_READ || bus_state == S_BUS_REFILL) begin    // prepare for refill data
            if (axi_req.rready && axi_resp.rvalid && !bc_uncache) begin
                refill_data[bc_ret_off] <= (axi_resp.rdata & ~refill_strobe[bc_ret_off]) | (refill_data[bc_ret_off] & refill_strobe[bc_ret_off]);
                refill_rdy[bc_ret_off] <= 1;
                bc_ret_off <= bc_ret_off + 1;
            end

            if (m1_valid && m1_op && doable) begin
                refill_data[m1_offset[OFFSET_WIDTH - 1:2]]   <= (m1_wdata & m1_strobe) | (refill_data[m1_offset[OFFSET_WIDTH - 1:2]] & ~m1_strobe);
                refill_strobe[m1_offset[OFFSET_WIDTH - 1:2]] <= m1_strobe | refill_strobe[m1_offset[OFFSET_WIDTH - 1:2]];
                refill_dirty <= 1;
            end
        end

        if (axi_req.arvalid && axi_resp.arready) begin
            read_over <= 0;
        end
        else if (axi_resp.rvalid && axi_resp.rlast && axi_req.rready) begin
            read_over <= 1;
        end

        if (bus_state == S_BUS_REFILL) begin
            bc_write_back_addr <= {way_tagv[way_to_replace].tag, bc_index, {OFFSET_WIDTH{1'b0}}};
            bc_write_back_data <= way_rdata[way_to_replace];
        end
        
        if (bus_next_state == S_BUS_WTREQ) begin    // cnt for bus writeback
            bc_wb_cnt <= 0;
        end
        else if (bus_state == S_BUS_WTREQ || bus_state == S_BUS_WRITE_BACK) begin
            if (axi_resp.wready && axi_req.wvalid) begin
                bc_wb_cnt <= bc_wb_cnt + 1;
            end
        end
    end

//    logic [3:0] axi_len;
//    assign axi_len = (LINE_WIDTH == 256) ? 4'b0111 : (LINE_WIDTH == 512) ? 4'b1111 : '0;

    // axi read req signals
    always_comb begin
        axi_req.araddr  = '0;
        axi_req.arlen   = '0;
        axi_req.arsize  = '0;
        axi_req.arburst = '0;
        axi_req.arvalid = 0;
        axi_req.arlock  = 2'd0;
        axi_req.arcache = 4'd0;
        axi_req.arprot  = 3'd0;
        if (bus_state == S_BUS_RDREQ) begin
            axi_req.arvalid = 1;
            axi_req.araddr  = (bc_uncache) ? {bc_tag, bc_index, bc_offset} : {bc_tag, bc_index, bc_offset[OFFSET_WIDTH - 1:2], 2'b0};
            axi_req.arlen   = (bc_uncache) ? 0 : (LINE_WIDTH / 32 - 1);  // represents 8 transfers
            axi_req.arsize  = (bc_uncache) ? bc_size : 3'b010;   // represents 4 bytes.
            axi_req.arburst = (bc_uncache) ? 2'b0 : 2'b10;
        end
    end

    // axi write req signals
    always_comb begin
        axi_req.awaddr  = '0;
        axi_req.awlen   = (LINE_WIDTH / 32 - 1);          // 4'b0000 -> 1; 4'b0001 -> 2; ... ; 4'b0111 -> 8; times
        axi_req.awsize  = 3'b010;           // 3'b000 -> 1; 3'b001 -> 2; 3'b010 -> 4; bytes for one transfer
        axi_req.awburst = 2'd1;
        axi_req.awlock  = 2'd0;
        axi_req.awcache = 4'd0;
        axi_req.awprot  = 3'd0;
        axi_req.awvalid = 0;
        axi_req.wvalid  = 0;
        axi_req.wlast   = 0;
        axi_req.wdata   = 0;
        axi_req.wstrb   = 4'b1111;
        if (bus_state == S_BUS_WTREQ) begin
            axi_req.awvalid = 1;
            if (bc_uncache) begin
                axi_req.awlen   = 4'b0;
                axi_req.awaddr  = bc_addr;
                axi_req.awburst = 2'b0;
                axi_req.awsize  = bc_size;
            end
            else if (bc_cache_inst) begin
                axi_req.awaddr = bc_addr;
            end
            else begin
                axi_req.awaddr = bc_write_back_addr;
            end
        end
        if (bus_state == S_BUS_WTREQ || bus_state == S_BUS_WRITE_BACK) begin  // normal replace writeback | CACHE inst writeback
            if (!bc_uncache) begin
                axi_req.wvalid = (bc_wb_cnt <= (LINE_WIDTH / 32 - 1));
                axi_req.wlast  = (bc_wb_cnt == (LINE_WIDTH / 32 - 1));
                if (!bc_cache_inst) begin
                    axi_req.wdata  = bc_write_back_data[bc_wb_cnt];
                end
                else begin
                    axi_req.wdata  = bc_data[bc_wb_cnt];
                end
            end
            else begin
                axi_req.wvalid = (bc_wb_cnt == '0);
                axi_req.wlast  = 1;
                axi_req.wdata  = bc_uw_data;
                axi_req.wstrb  = bc_wstrb;
            end
        end
    end

    // addr_ok是一个重要信号，它意味着m0级的请求已经完成了它需要的读操作
    // addr_ok is important, it means that the read operation of req in m0 has been finished.
    assign m0_addr_ok = (m0_cache_valid && m0_index == bc_index && !bc_uncache && (bus_state == S_BUS_RDREQ || bus_state == S_BUS_READ)) ? 0 : 
                        (enb && rprio == RP_RTAGV) || (m0_forward && m0_valid && !m0_op && !m0_cache_valid && !m0_uncache);
    // data_ok是一个重要信号，它意味着这个请求从流水线看来已经完成了，这个周期读回的数据是有效的
    // data_ok is important, it means that, for the pipeline, the req has been completed and the data read back in this cycle is valid.
    always_comb begin
        m1_data_ok = 0;
        if (m1_valid && !m1_cache_valid && cache_hit && !data_delay) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && !m1_op && !m1_cache_valid && !m1_uncache && m1_forward) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && !m1_op && !m1_cache_valid && doable) begin
            if (bc_ret_off == m1_offset[OFFSET_WIDTH - 1:2] && axi_resp.rvalid && axi_req.rready) begin
                m1_data_ok = 1;
            end
            else if (refill_rdy[m1_offset[OFFSET_WIDTH - 1:2]]) begin
                m1_data_ok = 1;
            end
        end
        else if (m1_valid && m1_op && !m1_uncache && bus_state == S_BUS_IDLE) begin // 其实这里不管是不是uncache都可以ok
            m1_data_ok = 1;
        end
        else if (m1_valid && m1_op && doable) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && m1_op && m1_uncache && !fifo_full) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && bc_uncache && axi_resp.rvalid && axi_req.rready) begin
            m1_data_ok = 1;
        end
        else if (m1_valid && m1_cache_valid) begin
            if (!m1_cache_writeback) begin
                m1_data_ok = 1;
            end
            else if (!m1_cache_op && !data_delay && !way_dirt[m1_way]) begin
                m1_data_ok = 1;
            end
            else if (m1_cache_op && !data_delay && (!way_dirt[hit_way] || !(cache_hit))) begin
                m1_data_ok = 1;
            end
            else if (bus_state == S_BUS_IDLE) begin
                m1_data_ok = 1;
            end
        end
    end

    assign m1_rdata = (m1_forward) ? rdata_t :
                      (cache_hit && !data_delay) ? rdata_h : 
                      (bc_uncache) ? axi_resp.rdata : 
                      (bc_ret_off == m1_offset[OFFSET_WIDTH - 1:2] && axi_resp.rvalid) ? ((axi_resp.rdata & ~refill_strobe[bc_ret_off]) | (refill_data[bc_ret_off] & refill_strobe[bc_ret_off])) : 
                      refill_data[m1_offset[OFFSET_WIDTH - 1:2]];

    assign axi_req.rready = !(m1_valid && m1_op && doable);
    assign axi_req_arid = 0;
    assign axi_req_awid = 0;
    assign axi_req_wid = 0;
    assign axi_req.bready = 1;

endmodule