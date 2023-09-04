`timescale 1ns / 1ps

`include "mem_if_def.svh"

module iCache #(
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
    input logic cache_valid,      // coperates with ibus.valid
    input logic cache_op,         // 0 for index invalidate, 1 for hit invalidate
    
    // CPU - Cache
    cpu_ibus_if.slave ibus,

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

    logic [1:0] main_state, main_next_state;
    localparam logic [1:0] S_MAIN_IDLE = 2'b00;
    localparam logic [1:0] S_MAIN_LOOK = 2'b01;
    always @(posedge clk) begin
        if (reset) main_state <= S_MAIN_IDLE;
        else main_state <= main_next_state;
    end

    offset_t offset;
    index_t  index ;
    tag_t    tag   ;    
    way_t    way   ;
    assign offset = ibus.address[0 +: OFFSET_WIDTH];
    assign index  = ibus.address[OFFSET_WIDTH +: INDEX_WIDTH];
    assign tag    = ibus.address[OFFSET_WIDTH + INDEX_WIDTH +: TAG_WIDTH];
    assign way    = ibus.address[OFFSET_WIDTH + INDEX_WIDTH +: WAY_WIDTH]; 

    logic         rb_valid  ;
    logic         rb_uncache;
    logic         rb_CACHE  ; // CACHE inst
    logic         rb_cache_op;
    index_t       rb_index  ;
    way_t         rb_way    ;
    tag_t         rb_tag    ;
    offset_t      rb_offset ;
    logic [1 : 0] rb_size   ;

    logic addr_ok;
    logic data_ok;

    always_comb begin
        main_next_state = main_state;
        case (main_state)
            S_MAIN_IDLE: begin
                if (ibus.valid && addr_ok) begin
                    main_next_state = S_MAIN_LOOK;
                end
            end
            S_MAIN_LOOK: begin
                if (data_ok && (!ibus.valid || !addr_ok)) begin
                    main_next_state = S_MAIN_IDLE;
                end
            end
        endcase
    end

    // Request Buffer
    assign rb_valid = (main_state == S_MAIN_LOOK);
    always_ff @(posedge clk) begin
        if (reset) begin
            rb_uncache<= 1;
            rb_CACHE  <= 0;
            rb_index  <= 0;
            rb_way    <= 0;
            rb_tag    <= 0;
            rb_offset <= 0;
            rb_size   <= 0;
        end
        else if(ibus.valid && ((main_state == S_MAIN_IDLE) || (main_state == S_MAIN_LOOK && data_ok))) begin
            rb_uncache<= ibus.uncache;
            rb_CACHE  <= cache_valid ;
            rb_cache_op <= cache_op;
            rb_index  <= index  ;
            rb_way    <= way    ;
            rb_tag    <= tag    ;
            rb_offset <= offset ;
            rb_size   <= ibus.size;
        end
    end

    I_Cache_AXI #(
        .CTRL_IPREF_ENABLE(CTRL_IPREF_ENABLE),
        .CTRL_PLRU_ENABLE(CTRL_PLRU_ENABLE),
        .SET_SIZE(SET_SIZE),
        .GROUP_NUM(GROUP_NUM),
        .LINE_WIDTH(LINE_WIDTH)
    ) i_cache_axi (
        .clk,
        .reset,

        // CACHE instruction
        .m0_cache_valid(cache_valid),
        .m0_cache_op(cache_op),
        .m1_cache_valid(rb_CACHE),
        .m1_cache_op(rb_cache_op),
        .m1_way(rb_way),

        // basic request signals
        .m0_valid(ibus.valid),
        .m0_uncache(ibus.uncache),
        .m0_index(index),
        .m0_tag(tag),
        .m0_offset(offset),
        .m0_size(ibus.size),
        .m1_valid(rb_valid),
        .m1_uncache(rb_uncache),
        .m1_index(rb_index),
        .m1_tag(rb_tag),
        .m1_offset(rb_offset),
        .m1_size(rb_size),

        // basic response signals
        .m0_addr_ok(addr_ok),
        .m1_data_ok(data_ok),
        .m1_rdata(ibus.rdata),

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

    // ibus.addr_ok是一个重要信号，它意味着m0级的请求可进入m1级，换言之，m1级空闲或在本周期完成且m0级请求在本周期完成了它需要的读操作�??
    // 或�?�从流水线的角度看，它意味着可以不再提供这个请求的有效信号�??
    assign ibus.addr_ok = (main_state == S_MAIN_IDLE && addr_ok || main_state == S_MAIN_LOOK && data_ok && addr_ok);
    // ibus.data_ok是一个重要信号，它意味着这个请求从流水线看来已经完成了，这个周期读回的数据是有效�?
    assign ibus.data_ok = data_ok;
    /*
    (*mark_debug = "true"*)wire db_i_addr_ok = ibus.addr_ok;
    (*mark_debug = "true"*)wire db_i_data_ok = ibus.data_ok;
    (*mark_debug = "true"*)wire db_i_uncache = ibus.uncache;
    (*mark_debug = "true"*)wire db_i_CACHE   = cache_valid;
    (*mark_debug = "true"*)wire db_i_valid   = ibus.valid;
    (*mark_debug = "true"*)wire[1:0] db_i_main_state = main_state;
    */
endmodule