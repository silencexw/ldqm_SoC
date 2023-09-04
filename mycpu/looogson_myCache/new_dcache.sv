`timescale 1ns / 1ps
`include "mem_if_def.svh"

module dCache #(
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
    input logic cache_valid,
    input logic cache_op,           // 0 for index invalidate, 1 for hit invalidate
    input logic cache_writeback,    // 0 for non-writeback, 1 for writeback

    // CPU - Cache
    cpu_dbus_if.slave dbus,

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
    
    output logic [31:0] ms_addr,
    output logic ms_valid
);

    // skid buf typedef 
    typedef struct packed {
        logic         uncache;
        logic         op     ;
        logic         CACHE  ; // CACHE inst
        logic         cache_op;
        logic         cache_writeback;
        index_t       index  ;
        way_t         way    ;
        tag_t         tag    ;
        offset_t      offset ;
        logic [1 : 0] size   ;
        logic [31: 0] wdata  ;
        logic [3 : 0] wstrb  ; 
    } rq_fifo_t;

    logic [1:0] main_state, main_next_state;
    localparam logic [1:0] S_MAIN_IDLE = 2'b00;
    localparam logic [1:0] S_MAIN_LOOK = 2'b01;
    always @(posedge clk) begin
        if (reset) main_state <= S_MAIN_IDLE;
        else main_state <= main_next_state;
    end

    offset_t offset;  // 32 bytes in a cache line
    index_t index;        // 128 groups
    tag_t tag;    
    way_t way;
    assign offset = dbus.address[0 +: OFFSET_WIDTH];
    assign index = dbus.address[OFFSET_WIDTH +: INDEX_WIDTH];
    assign tag =  dbus.address[OFFSET_WIDTH + INDEX_WIDTH +: TAG_WIDTH];
    assign way =  dbus.address[OFFSET_WIDTH + INDEX_WIDTH +: WAY_WIDTH]; 

    rq_fifo_t     in_req;
    rq_fifo_t     m0_req;
    always_comb begin
        in_req.uncache = dbus.uncache;
        in_req.op      = dbus.op;
        in_req.CACHE   = cache_valid;
        in_req.cache_op= cache_op;
        in_req.cache_writeback = cache_writeback;
        in_req.index   = index;
        in_req.way     = way;
        in_req.tag     = tag;
        in_req.offset  = offset;
        in_req.size    = dbus.size;
        in_req.wdata   = dbus.wdata;
        in_req.wstrb   = dbus.wstrb;
    end

    logic         fifo_full;
    logic         fifo_w_req;
    logic         fifo_r_req;
    rq_fifo_t     ff_req;
    // logic         ff_uncache;
    // logic         ff_op     ;
    // logic         ff_CACHE  ; // CACHE inst
    // logic         ff_cache_op;
    // logic         ff_cache_writeback;
    // index_t       ff_index  ;
    // way_t         ff_way    ;
    // tag_t         ff_tag    ;
    // offset_t      ff_offset ;
    // logic [1 : 0] ff_size   ;
    // logic [31: 0] ff_wdata  ;
    // logic [3 : 0] ff_wstrb  ; 

    logic         rb_valid  ;
    rq_fifo_t     rb_req    ;
    // logic         rb_uncache;
    // logic         rb_op     ;
    // logic         rb_CACHE  ; // CACHE inst
    // logic         rb_cache_op;
    // logic         rb_cache_writeback;
    // index_t       rb_index  ;
    // way_t         rb_way    ;
    // tag_t         rb_tag    ;
    // offset_t      rb_offset ;
    // logic [1 : 0] rb_size   ;
    // logic [31: 0] rb_wdata  ;
    // logic [3 : 0] rb_wstrb  ; 

    logic addr_ok;
    logic data_ok;

    always_comb begin
        main_next_state = main_state;
        case (main_state)
            S_MAIN_IDLE: begin
                if ((dbus.valid || fifo_full) && addr_ok) begin
                    main_next_state = S_MAIN_LOOK;
                end
            end
            S_MAIN_LOOK: begin
                if (data_ok && (!(dbus.valid || fifo_full) || !addr_ok)) begin
                    main_next_state = S_MAIN_IDLE;
                end
            end
        endcase
    end

    // skid buffer
    assign fifo_w_req = dbus.valid && !fifo_full && !(main_state == S_MAIN_IDLE && addr_ok || main_state == S_MAIN_LOOK && data_ok && addr_ok);
    assign fifo_r_req = fifo_full && (main_state == S_MAIN_IDLE && addr_ok || main_state == S_MAIN_LOOK && data_ok && addr_ok);
    always_ff @(posedge clk) begin
        if (reset || fifo_r_req) begin
            fifo_full <= 0;
            // ff_uncache<= 1;
            // ff_op     <= 0;
            // ff_CACHE  <= 0;
            // ff_cache_writeback <= 0;
            // ff_index  <= 0;
            // ff_way    <= 0;
            // ff_tag    <= 0;
            // ff_offset <= 0;
            // ff_size   <= 0;
            // ff_wdata  <= 0;
            // ff_wstrb  <= 0;
        end
        else if(fifo_w_req) begin
            fifo_full <= 1;
            ff_req    <= in_req;
            // ff_uncache<= dbus.uncache;
            // ff_op     <= dbus.op     ;
            // ff_CACHE  <= cache_valid ;
            // ff_cache_op <= cache_op;
            // ff_cache_writeback <= cache_writeback;
            // ff_index  <= index  ;
            // ff_way    <= way    ;
            // ff_tag    <= tag    ;
            // ff_offset <= offset ;
            // ff_size   <= dbus.size;
            // ff_wdata  <= dbus.wdata;
            // ff_wstrb  <= dbus.wstrb;
        end
    end
    assign m0_req = (fifo_full) ? ff_req : in_req;

    // Request Buffer
    assign rb_valid = (main_state == S_MAIN_LOOK);
    always_ff @(posedge clk) begin
        if (reset) begin
            // rb_uncache<= 1;
            // rb_op     <= 0;
            // rb_CACHE  <= 0;
            // rb_cache_writeback <= 0;
            // rb_index  <= 0;
            // rb_way    <= 0;
            // rb_tag    <= 0;
            // rb_offset <= 0;
            // rb_size   <= 0;
            // rb_wdata  <= 0;
            // rb_wstrb  <= 0;
        end
        else if((dbus.valid || fifo_full) && ((main_state == S_MAIN_IDLE/* && addr_ok*/) || (main_state == S_MAIN_LOOK && data_ok/* && addr_ok*/))) begin
            // rb_uncache<= dbus.uncache;
            // rb_op     <= dbus.op     ;
            // rb_CACHE  <= cache_valid ;
            // rb_cache_op <= cache_op;
            // rb_cache_writeback <= cache_writeback;
            // rb_index  <= index  ;
            // rb_way    <= way    ;
            // rb_tag    <= tag    ;
            // rb_offset <= offset ;
            // rb_size   <= dbus.size;
            // rb_wdata  <= dbus.wdata;
            // rb_wstrb  <= dbus.wstrb;
            rb_req <= m0_req;
        end
    end

    D_Cache_AXI #(
        .CTRL_DPREF_ENABLE(CTRL_DPREF_ENABLE),
        .CTRL_PLRU_ENABLE(CTRL_PLRU_ENABLE),
        .SET_SIZE(SET_SIZE),
        .GROUP_NUM(GROUP_NUM),
        .LINE_WIDTH(LINE_WIDTH),
        .UW_FIFO_DEPTH(UW_FIFO_DEPTH)
    ) d_cache_axi (
        .clk,
        .reset,

        // CACHE instruction
        .m0_cache_valid     (m0_req.CACHE           ),
        .m0_cache_op        (m0_req.cache_op        ),
        .m0_cache_writeback (m0_req.cache_writeback ),
        .m1_cache_valid     (rb_req.CACHE           ),
        .m1_cache_op        (rb_req.cache_op        ),
        .m1_cache_writeback (rb_req.cache_writeback ),
        .m1_way             (rb_req.way             ),

        // basic request signals
        .m0_valid   (dbus.valid || fifo_full),
        .m0_uncache (m0_req.uncache         ),
        .m0_index   (m0_req.index           ),
        .m0_tag     (m0_req.tag             ),
        .m0_offset  (m0_req.offset          ),
        .m0_size    (m0_req.size            ),
        .m0_op      (m0_req.op              ),
        .m1_valid   (rb_valid               ),
        .m1_uncache (rb_req.uncache         ),
        .m1_index   (rb_req.index           ),
        .m1_tag     (rb_req.tag             ),
        .m1_offset  (rb_req.offset          ),
        .m1_size    (rb_req.size            ),
        .m1_op      (rb_req.op              ),
        .m1_wdata   (rb_req.wdata           ),
        .m1_wstrb   (rb_req.wstrb           ),

        // basic response signals
        .m0_addr_ok(addr_ok),
        .m1_data_ok(data_ok),
        .m1_rdata(dbus.rdata),

        // Cache - AXI_crossbar
        // AXI request
        .axi_req,
        .axi_req_arid,
        .axi_req_awid,
        .axi_req_wid,
        // AXI response
        .axi_resp,
        .axi_resp_rid,
        .axi_resp_bid,
        
        .ms_addr,
        .ms_valid
    );

    // dbus.addr_ok是一个重要信号，它意味着m0级的请求可进入m1级，换言之，m1级空闲或在本周期完成且m0级请求在本周期完成了它需要的读操作。
    // 或者从流水线的角度看，它意味着可以不再提供这个请求的有效信号。
    // assign dbus.addr_ok = (main_state == S_MAIN_IDLE && addr_ok || main_state == S_MAIN_LOOK && data_ok && addr_ok);
    assign dbus.addr_ok = !fifo_full;
    // dbus.data_ok是一个重要信号，它意味着这个请求从流水线看来已经完成了，这个周期读回的数据是有效的
    assign dbus.data_ok = data_ok;

endmodule