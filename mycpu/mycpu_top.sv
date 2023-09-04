`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/04/14 20:02:41
// Design Name: 
// Module Name: mycpu_top
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

`include "mem_if_def.svh"
`include "cpu_macro.svh"
module mycpu_top #(
    parameter CTRL_TLB = 1'b0,
    parameter CTRL_CLO_CLZ = 1'b0,
    parameter CTRL_TRAP_UNIT = 1'b0,
    parameter CTRL_USE_XPM_CPC = 1'b1,
    parameter CTRL_EXTEND_INST_SET = 1'b0,
    parameter CTRL_XBAR_USE_IP = 1'b0,
    parameter CTRL_PLRU_ENABLE = 1'b0,
    parameter CTRL_IPREF_ENABLE = 1'b0,
    parameter CTRL_DPREF_ENABLE = 1'b1
) (
    input         aclk,
    input         aresetn,
    input  [5 :0] ext_int,
    //ar
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [3 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock        ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
    //r           
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    //aw          
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [3 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    //w          
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    //b           
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       ,
    
    //debug
//`ifdef USE_SIMULATOR
    output [31:0]   debug_cp0_random,// cp0_random used in TLBWR
    output [31:0]   debug_cp0_cause, // cp0_cause for rising interrupts and mfc0
    output [31:0] debug_cp0_count,
    output          debug_int,       
    output          debug_commit,
//`endif
    
    output [31:0] debug_wb_pc,
    output [3:0] debug_wb_rf_wen,
    output [4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
    );
    
wire inst_req;
wire [31:0] inst_addr;
wire        inst_cached;
wire [1:0] inst_size;
wire [63:0] inst_rdata;
wire inst_addr_ok, inst_data_ok;
/*(*mark_debug = "true"*)*/wire data_req;
/*(*mark_debug = "true"*)*/wire data_wr;
/*(*mark_debug = "true"*)*/wire [3:0] data_wstrb;
/*(*mark_debug = "true"*)*/wire [31:0] data_addr;
/*(*mark_debug = "true"*)*/wire        data_cached;
/*(*mark_debug = "true"*)*/wire [1:0] data_size;
/*(*mark_debug = "true"*)*/wire [31:0] data_rdata;
/*(*mark_debug = "true"*)*/wire [31:0] data_wdata;
/*(*mark_debug = "true"*)*/wire data_addr_ok;
/*(*mark_debug = "true"*)*/wire data_data_ok;

wire icache_valid;
wire icache_op;
wire dcache_valid;
wire dcache_op;
wire dcache_wb;

TLB_Search_In inst_tlb_search, data_tlb_search;
TLB_Search_Out inst_tlb_info, data_tlb_info;
wire   cp0_km;
wire   cp0_erl;
wire   cp0_kseg0_cached;
wire   tlb_wr;
wire [31:0] cp0_TagLo0_o;
wire [31:0] cp0_EntryHi_o;
wire [31:0] cp0_EntryLo0_o;
wire [31:0] cp0_EntryLo1_o;
wire [11:0] cp0_PageMask_o;
wire [31:0] cp0_TLB_Index_o;
wire  [31:0]  cp0_EntryLo0_i;
wire  [31:0]  cp0_EntryLo1_i;
wire  [31:0]  cp0_EntryHi_i;
wire  [11:0]  cp0_PageMask_i;
wire  [31:0]  cp0_Index_i;
mycpu_core #(
    .CTRL_CLO_CLZ(CTRL_CLO_CLZ),
    .CTRL_TRAP_UNIT(CTRL_TRAP_UNIT),
    .CTRL_USE_XPM_CPC(CTRL_USE_XPM_CPC),
    .CTRL_EXTEND_INST_SET(CTRL_EXTEND_INST_SET)
) u_core(
    .clk(aclk),
    .resetn(aresetn),
    .ext_int(ext_int),
    
    .inst_req(inst_req),
    .inst_size(inst_size),
    .inst_addr(inst_addr),
    .inst_cached(inst_cached),
    .inst_rdata(inst_rdata),
    .inst_addr_ok(inst_addr_ok),
    .inst_data_ok(inst_data_ok),
    .inst_tlb_search,
    .inst_tlb_info,
    
    .data_req(data_req),
    .data_wr(data_wr),
    .data_size(data_size),
    .data_wstrb(data_wstrb),
    .data_addr(data_addr),
    .data_cached(data_cached),
    .data_rdata(data_rdata),
    .data_wdata(data_wdata),
    .data_addr_ok(data_addr_ok),
    .data_data_ok(data_data_ok),
    .data_tlb_search,
    .data_tlb_info,
    
    .icache_valid,
    .icache_op,
    
    .dcache_valid,
    .dcache_op,
    .dcache_wb,
    
    .cp0_km,
    .cp0_erl,
    .cp0_kseg0_cached,
    .tlb_wr,
    .cp0_TagLo0_o,
    .cp0_EntryHi_o,
    .cp0_EntryLo0_o,
    .cp0_EntryLo1_o,
    .cp0_PageMask_o,
    .cp0_TLB_Index_o,
    .cp0_EntryHi_i,
    .cp0_EntryLo0_i,
    .cp0_EntryLo1_i,
    .cp0_PageMask_i,
    .cp0_Index_i,
    
`ifdef USE_SIMULATOR
    // for simulator
    .debug_cp0_count(debug_cp0_count),
    .debug_cp0_random(debug_cp0_random),
    .debug_cp0_cause(debug_cp0_cause),
    .debug_int(debug_int),
    .debug_commit(debug_commit),
`endif
    
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wen(debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
`ifndef USE_SIMULATOR
assign debug_commit = debug_wb_pc != '0;
`endif

//tlb
if (CTRL_TLB == 1'b1) begin
tlb tlb_uut(
    .clk(aclk),
    .reset(!aresetn),
    
    //status
    .km(cp0_km),
    .cp0_erl(cp0_erl),
    .kseg0_cached(cp0_kseg0_cached),
    
    //search
    .inst_search_in(inst_tlb_search),
    .inst_search_out(inst_tlb_info),
    .data_search_in(data_tlb_search),
    .data_search_out(data_tlb_info),
    
    .write(tlb_wr),
    .index_in(cp0_TLB_Index_o),
    .mask_in(cp0_PageMask_o),
    .entryhi_in(cp0_EntryHi_o),
    .entrylo0_in(cp0_EntryLo0_o),
    .entrylo1_in(cp0_EntryLo1_o),
    
    .mask_out(cp0_PageMask_i),
    .entryhi_out(cp0_EntryHi_i),
    .entrylo0_out(cp0_EntryLo0_i),
    .entrylo1_out(cp0_EntryLo1_i),
    
    .index_out(cp0_Index_i)
);
end
else begin
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        inst_tlb_info <= '0;
        data_tlb_info <= '0;
    end
    else begin
        if (inst_tlb_search.ce) begin
            inst_tlb_info.va_out <= inst_tlb_search.vaddr;
            inst_tlb_info.paddr <= inst_tlb_search.vaddr & 32'h1fffffff;
            inst_tlb_info.hit <= 1'b1;
            inst_tlb_info.v <= 1'b1;
            inst_tlb_info.d <= 1'b1;
            inst_tlb_info.cached <= !(inst_tlb_search.vaddr[31:28] == 4'ha || inst_tlb_search.vaddr[31:28] == 4'hb);
            inst_tlb_info.error <= 1'b0;
        end
        
        if (data_tlb_search.ce) begin
            data_tlb_info.va_out <= data_tlb_search.vaddr;
            data_tlb_info.paddr <= data_tlb_search.vaddr & 32'h1fffffff;
            data_tlb_info.hit <= 1'b1;
            data_tlb_info.v <= 1'b1;
            data_tlb_info.d <= 1'b1;
            data_tlb_info.cached <= !(data_tlb_search.vaddr[31:28] == 4'ha || data_tlb_search.vaddr[31:28] == 4'hb);
            data_tlb_info.error <= 1'b0;
        end
    end
end
end

// initialization of bus interfaces
cpu_ibus_if ibus_if();
cpu_dbus_if dbus_if();

// a temporary interface convertor, 
cpu_cache_convertor cc_convertor(
    .inst_req,
    .inst_cached,
    .inst_addr,
    .inst_size,
    .inst_rdata,
    .inst_addr_ok,
    .inst_data_ok,

    .data_req,
    .data_wr,
    .data_wstrb,
    .data_addr,
    .data_size,
    .data_cached,
    .data_rdata,
    .data_wdata,
    .data_addr_ok,
    .data_data_ok,

    .ibus(ibus_if.master),
    .dbus(dbus_if.master)
);

axi_req_t icache_axi_req, dcache_axi_req;
axi_resp_t icache_axi_resp, dcache_axi_resp;
logic [3:0] i_axi_req_arid, i_axi_req_awid, i_axi_req_wid, i_axi_resp_rid, i_axi_resp_bid;
logic [3:0] d_axi_req_arid, d_axi_req_awid, d_axi_req_wid, d_axi_resp_rid, d_axi_resp_bid;

iCache #(
    .CTRL_IPREF_ENABLE(CTRL_IPREF_ENABLE),
    .CTRL_PLRU_ENABLE(CTRL_PLRU_ENABLE),
    .SET_SIZE(4),
    .GROUP_NUM(128),
    .LINE_WIDTH(256)
) icache(
    .clk(aclk),
    .reset(!aresetn),

    .cache_valid(icache_valid),
    .cache_op(icache_op),

    .ibus(ibus_if.slave),

    // all remaining axi signals
    .axi_req(icache_axi_req),
    .axi_req_arid(i_axi_req_arid),
    .axi_req_awid(i_axi_req_awid),
    .axi_req_wid(i_axi_req_wid),

    .axi_resp(icache_axi_resp),
    .axi_resp_rid(i_axi_resp_rid),
    .axi_resp_bid(i_axi_resp_bid)
);

dCache #(
    .CTRL_DPREF_ENABLE(CTRL_DPREF_ENABLE),
    .CTRL_PLRU_ENABLE(CTRL_PLRU_ENABLE),
    .SET_SIZE(4),
    .GROUP_NUM(128),
    .LINE_WIDTH(256),
    .UW_FIFO_DEPTH(16)
) dcache(
    .clk(aclk),
    .reset(!aresetn),

    .cache_valid(dcache_valid),
    .cache_op(dcache_op),
    .cache_writeback(dcache_wb),

    .dbus(dbus_if.slave),

    // all remaining axi signals
    .axi_req(dcache_axi_req),
    .axi_req_arid(d_axi_req_arid),
    .axi_req_awid(d_axi_req_awid),
    .axi_req_wid(d_axi_req_wid),

    .axi_resp(dcache_axi_resp),
    .axi_resp_rid(d_axi_resp_rid),
    .axi_resp_bid(d_axi_resp_bid),
    
    .ms_addr(),
    .ms_valid()
);

if (CTRL_XBAR_USE_IP == 1) begin
axi_crossbar_2x1 axi_crossbar (
  .aclk(aclk),                    // input wire aclk
  .aresetn(aresetn),              // input wire aresetn

  .s_axi_awid       ({i_axi_req_awid, d_axi_req_awid}),        // input wire [1 : 0] s_axi_awid
  .s_axi_awaddr     ({{icache_axi_req.awaddr} , {dcache_axi_req.awaddr}}),    // input wire [63 : 0] s_axi_awaddr
  .s_axi_awlen      ({{icache_axi_req.awlen } , {dcache_axi_req.awlen}}),      // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize     ({{icache_axi_req.awsize} , {dcache_axi_req.awsize}}),    // input wire [5 : 0] s_axi_awsize
  .s_axi_awburst    ({{icache_axi_req.awburst}, {dcache_axi_req.awburst}}),  // input wire [3 : 0] s_axi_awburst
  .s_axi_awlock     ({{icache_axi_req.awlock} , {dcache_axi_req.awlock}}),    // input wire [3 : 0] s_axi_awlock
  .s_axi_awcache    ({{icache_axi_req.awcache}, {dcache_axi_req.awcache}}),  // input wire [7 : 0] s_axi_awcache
  .s_axi_awprot     ({{icache_axi_req.awprot} , {dcache_axi_req.awprot}}),    // input wire [5 : 0] s_axi_awprot
  .s_axi_awqos      (8'b0),      // input wire [7 : 0] s_axi_awqos
  .s_axi_awvalid    ({{icache_axi_req.awvalid}, {dcache_axi_req.awvalid}}),  // input wire [1 : 0] s_axi_awvalid
  .s_axi_awready    ({{icache_axi_resp.awready}, {dcache_axi_resp.awready}}),  // output wire [1 : 0] s_axi_awready
  .s_axi_wid        ({i_axi_req_wid, d_axi_req_wid}),          // input wire [1 : 0] s_axi_wid
  .s_axi_wdata      ({{icache_axi_req.wdata}, {dcache_axi_req.wdata}}),      // input wire [63 : 0] s_axi_wdata
  .s_axi_wstrb      ({{icache_axi_req.wstrb}, {dcache_axi_req.wstrb}}),      // input wire [7 : 0] s_axi_wstrb
  .s_axi_wlast      ({{icache_axi_req.wlast}, {dcache_axi_req.wlast}}),      // input wire [1 : 0] s_axi_wlast
  .s_axi_wvalid     ({{icache_axi_req.wvalid}, {dcache_axi_req.wvalid}}),    // input wire [1 : 0] s_axi_wvalid
  .s_axi_wready     ({{icache_axi_resp.wready}, {dcache_axi_resp.wready}}),    // output wire [1 : 0] s_axi_wready
  .s_axi_bid        ({i_axi_resp_bid, d_axi_resp_bid}),          // output wire [1 : 0] s_axi_bid
  .s_axi_bresp      ({{icache_axi_resp.bresp}, {dcache_axi_resp.bresp}}),      // output wire [3 : 0] s_axi_bresp
  .s_axi_bvalid     ({{icache_axi_resp.bvalid}, {dcache_axi_resp.bvalid}}),    // output wire [1 : 0] s_axi_bvalid
  .s_axi_bready     ({{icache_axi_req.bready}, {dcache_axi_req.bready}}),    // input wire [1 : 0] s_axi_bready
  .s_axi_arid       ({i_axi_req_arid, d_axi_req_arid}),        // input wire [1 : 0] s_axi_arid
  .s_axi_araddr     ({{icache_axi_req.araddr}, {dcache_axi_req.araddr}}),    // input wire [63 : 0] s_axi_araddr
  .s_axi_arlen      ({{icache_axi_req.arlen}, {dcache_axi_req.arlen}}),      // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize     ({{icache_axi_req.arsize}, {dcache_axi_req.arsize}}),    // input wire [5 : 0] s_axi_arsize
  .s_axi_arburst    ({{icache_axi_req.arburst}, {dcache_axi_req.arburst}}),  // input wire [3 : 0] s_axi_arburst
  .s_axi_arlock     ({{icache_axi_req.arlock}, {dcache_axi_req.arlock}}),    // input wire [3 : 0] s_axi_arlock
  .s_axi_arcache    ({{icache_axi_req.arcache}, {dcache_axi_req.arcache}}),  // input wire [7 : 0] s_axi_arcache
  .s_axi_arprot     ({{icache_axi_req.arprot}, {dcache_axi_req.arprot}}),    // input wire [5 : 0] s_axi_arprot
  .s_axi_arqos      (8'b0),      // input wire [7 : 0] s_axi_arqos
  .s_axi_arvalid    ({{icache_axi_req.arvalid}, {dcache_axi_req.arvalid}}),  // input wire [1 : 0] s_axi_arvalid
  .s_axi_arready    ({{icache_axi_resp.arready}, {dcache_axi_resp.arready}}),  // output wire [1 : 0] s_axi_arready
  .s_axi_rid        ({i_axi_resp_rid, d_axi_resp_rid}),          // output wire [1 : 0] s_axi_rid
  .s_axi_rdata      ({{icache_axi_resp.rdata}, {dcache_axi_resp.rdata}}),      // output wire [63 : 0] s_axi_rdata
  .s_axi_rresp      ({{icache_axi_resp.rresp}, {dcache_axi_resp.rresp}}),      // output wire [3 : 0] s_axi_rresp
  .s_axi_rlast      ({{icache_axi_resp.rlast}, {dcache_axi_resp.rlast}}),      // output wire [1 : 0] s_axi_rlast
  .s_axi_rvalid     ({{icache_axi_resp.rvalid}, {dcache_axi_resp.rvalid}}),    // output wire [1 : 0] s_axi_rvalid
  .s_axi_rready     ({{icache_axi_req.rready}, {dcache_axi_req.rready}}),    // input wire [1 : 0] s_axi_rready

//  .m_axi_awid       (awid),        // output wire [0 : 0] m_axi_awid
  .m_axi_awaddr     (awaddr),    // output wire [31 : 0] m_axi_awaddr
  .m_axi_awlen      (awlen),      // output wire [3 : 0] m_axi_awlen
  .m_axi_awsize     (awsize),    // output wire [2 : 0] m_axi_awsize
  .m_axi_awburst    (awburst),  // output wire [1 : 0] m_axi_awburst
  .m_axi_awlock     (awlock),    // output wire [1 : 0] m_axi_awlock
  .m_axi_awcache    (awcache),  // output wire [3 : 0] m_axi_awcache
  .m_axi_awprot     (awprot),    // output wire [2 : 0] m_axi_awprot
  .m_axi_awqos      (),      // output wire [3 : 0] m_axi_awqos
  .m_axi_awvalid    (awvalid),  // output wire [0 : 0] m_axi_awvalid
  .m_axi_awready    (awready),  // input wire [0 : 0] m_axi_awready
//  .m_axi_wid        (wid),          // output wire [0 : 0] m_axi_wid
  .m_axi_wdata      (wdata),      // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb      (wstrb),      // output wire [3 : 0] m_axi_wstrb
  .m_axi_wlast      (wlast),      // output wire [0 : 0] m_axi_wlast
  .m_axi_wvalid     (wvalid),    // output wire [0 : 0] m_axi_wvalid
  .m_axi_wready     (wready),    // input wire [0 : 0] m_axi_wready
//  .m_axi_bid        (bid),          // input wire [0 : 0] m_axi_bid
  .m_axi_bresp      (bresp),      // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid     (bvalid),    // input wire [0 : 0] m_axi_bvalid
  .m_axi_bready     (bready),    // output wire [0 : 0] m_axi_bready
//  .m_axi_arid       (arid),        // output wire [0 : 0] m_axi_arid
  .m_axi_araddr     (araddr),    // output wire [31 : 0] m_axi_araddr
  .m_axi_arlen      (arlen),      // output wire [3 : 0] m_axi_arlen
  .m_axi_arsize     (arsize),    // output wire [2 : 0] m_axi_arsize
  .m_axi_arburst    (arburst),  // output wire [1 : 0] m_axi_arburst
  .m_axi_arlock     (arlock),    // output wire [1 : 0] m_axi_arlock
  .m_axi_arcache    (arcache),  // output wire [3 : 0] m_axi_arcache
  .m_axi_arprot     (arprot),    // output wire [2 : 0] m_axi_arprot
  .m_axi_arqos      (),      // output wire [3 : 0] m_axi_arqos
  .m_axi_arvalid    (arvalid),  // output wire [0 : 0] m_axi_arvalid
  .m_axi_arready    (arready),  // input wire [0 : 0] m_axi_arready
//  .m_axi_rid        (rid),          // input wire [0 : 0] m_axi_rid
  .m_axi_rdata      (rdata),      // input wire [31 : 0] m_axi_rdata
  .m_axi_rresp      (rresp),      // input wire [1 : 0] m_axi_rresp
  .m_axi_rlast      (rlast),      // input wire [0 : 0] m_axi_rlast
  .m_axi_rvalid     (rvalid),    // input wire [0 : 0] m_axi_rvalid
  .m_axi_rready     (rready)    // output wire [0 : 0] m_axi_rready
);
/*
assign awid = 0;
assign wid = 0;
assign arid = 0;
*/
end
else begin
`define AXI_LINE(name) AXI_BUS #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXI_ID_WIDTH(4), .AXI_USER_WIDTH(1)) name()
// ugly axi signals convertor
`AXI_LINE(icache_axi);
`AXI_LINE(dcache_axi);
`AXI_LINE(ext_axi);
// icache

assign icache_axi.aw_id   = '0;
assign icache_axi.aw_addr = icache_axi_req.awaddr;
assign icache_axi.aw_len  = icache_axi_req.awlen;
assign icache_axi.aw_size = icache_axi_req.awsize;
assign icache_axi.aw_burst= icache_axi_req.awburst;
assign icache_axi.aw_lock = icache_axi_req.awlock;
assign icache_axi.aw_cache= icache_axi_req.awcache;
assign icache_axi.aw_prot = icache_axi_req.awprot;
assign icache_axi.aw_user = '0;
assign icache_axi.aw_qos  = '0;
assign icache_axi.aw_region = '0;
assign icache_axi.aw_atop = '0;
assign icache_axi.aw_valid= icache_axi_req.awvalid;
assign icache_axi_resp.awready = icache_axi.aw_ready;

assign icache_axi.w_data  = icache_axi_req.wdata;
assign icache_axi.w_strb  = icache_axi_req.wstrb;
assign icache_axi.w_last  = icache_axi_req.wlast;
assign icache_axi.w_valid = icache_axi_req.wvalid;
assign icache_axi_resp.wready = icache_axi.w_ready;

assign i_axi_resp_bid        = icache_axi.b_id;
assign icache_axi_resp.bresp = icache_axi.b_resp;
assign icache_axi_resp.bvalid= icache_axi.b_valid;
assign icache_axi.b_ready    = icache_axi_req.bready;

assign icache_axi.ar_id   = '1;
assign icache_axi.ar_addr = icache_axi_req.araddr;
assign icache_axi.ar_len  = icache_axi_req.arlen;
assign icache_axi.ar_size = icache_axi_req.arsize;
assign icache_axi.ar_burst= icache_axi_req.arburst;
assign icache_axi.ar_lock = icache_axi_req.arlock;
assign icache_axi.ar_cache= icache_axi_req.arcache;
assign icache_axi.ar_prot = icache_axi_req.arprot;
assign icache_axi.ar_user = '0;
assign icache_axi.ar_qos  = '0;
assign icache_axi.ar_region = '0;
assign icache_axi.ar_valid= icache_axi_req.arvalid;
assign icache_axi_resp.arready = icache_axi.ar_ready;

assign i_axi_resp_rid        = icache_axi.r_id;
assign icache_axi_resp.rdata = icache_axi.r_data;
assign icache_axi_resp.rresp = icache_axi.r_resp;
assign icache_axi_resp.rlast = icache_axi.r_last;
assign icache_axi_resp.rvalid= icache_axi.r_valid;
assign icache_axi.r_ready    = icache_axi_req.rready;

// dcache
assign dcache_axi.aw_id   = '0;
assign dcache_axi.aw_addr = dcache_axi_req.awaddr;
assign dcache_axi.aw_len  = dcache_axi_req.awlen;
assign dcache_axi.aw_size = dcache_axi_req.awsize;
assign dcache_axi.aw_burst= dcache_axi_req.awburst;
assign dcache_axi.aw_lock = dcache_axi_req.awlock;
assign dcache_axi.aw_cache= dcache_axi_req.awcache;
assign dcache_axi.aw_prot = dcache_axi_req.awprot;
assign dcache_axi.aw_user = '0;
assign dcache_axi.aw_qos  = '0;
assign dcache_axi.aw_region = '0;
assign dcache_axi.aw_atop = '0;
assign dcache_axi.aw_valid= dcache_axi_req.awvalid;
assign dcache_axi_resp.awready = dcache_axi.aw_ready;

assign dcache_axi.w_data  = dcache_axi_req.wdata;
assign dcache_axi.w_strb  = dcache_axi_req.wstrb;
assign dcache_axi.w_last  = dcache_axi_req.wlast;
assign dcache_axi.w_valid = dcache_axi_req.wvalid;
assign dcache_axi_resp.wready = dcache_axi.w_ready;

assign d_axi_resp_bid        = dcache_axi.b_id;
assign dcache_axi_resp.bresp = dcache_axi.b_resp;
assign dcache_axi_resp.bvalid= dcache_axi.b_valid;
assign dcache_axi.b_ready    = dcache_axi_req.bready;

assign dcache_axi.ar_id   = '1;
assign dcache_axi.ar_addr = dcache_axi_req.araddr;
assign dcache_axi.ar_len  = dcache_axi_req.arlen;
assign dcache_axi.ar_size = dcache_axi_req.arsize;
assign dcache_axi.ar_burst= dcache_axi_req.arburst;
assign dcache_axi.ar_lock = dcache_axi_req.arlock;
assign dcache_axi.ar_cache= dcache_axi_req.arcache;
assign dcache_axi.ar_prot = dcache_axi_req.arprot;
assign dcache_axi.ar_user = '0;
assign dcache_axi.ar_qos  = '0;
assign dcache_axi.ar_region = '0;
assign dcache_axi.ar_valid= dcache_axi_req.arvalid;
assign dcache_axi_resp.arready = dcache_axi.ar_ready;

assign d_axi_resp_rid        = dcache_axi.r_id;
assign dcache_axi_resp.rdata = dcache_axi.r_data;
assign dcache_axi_resp.rresp = dcache_axi.r_resp;
assign dcache_axi_resp.rlast = dcache_axi.r_last;
assign dcache_axi_resp.rvalid= dcache_axi.r_valid;
assign dcache_axi.r_ready    = dcache_axi_req.rready;


axi_mux_intf #(
    .SLV_AXI_ID_WIDTH(3),
    .MST_AXI_ID_WIDTH(4),
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32),
    .NO_SLV_PORTS(2),
    .MAX_W_TRANS(2),
    .FALL_THROUGH(1)
) mem_mux (
    .clk_i(aclk),
    .rst_ni(aresetn),
    .test_i(1'b0),
    .slv0(dcache_axi),
    .slv1(icache_axi),
    .mst(ext_axi)
);


assign awid    = ext_axi.aw_id;
assign awaddr  = ext_axi.aw_addr;
assign awlen   = ext_axi.aw_len;
assign awsize  = ext_axi.aw_size;
assign awburst = ext_axi.aw_burst;
assign awlock  = ext_axi.aw_lock;
assign awcache = ext_axi.aw_cache;
assign awprot  = ext_axi.aw_prot;
assign awvalid = ext_axi.aw_valid;
assign ext_axi.aw_ready = awready;

assign wid = 0;
assign wdata  = ext_axi.w_data;
assign wstrb  = ext_axi.w_strb;
assign wlast  = ext_axi.w_last;
assign wvalid = ext_axi.w_valid;
assign ext_axi.w_ready = wready;

assign ext_axi.b_id    = bid;
assign ext_axi.b_resp  = bresp;
assign ext_axi.b_valid = bvalid;
assign bready = ext_axi.b_ready;

assign arid    = ext_axi.ar_id;
assign araddr  = ext_axi.ar_addr;
assign arlen   = ext_axi.ar_len;
assign arsize  = ext_axi.ar_size;
assign arburst = ext_axi.ar_burst;
assign arlock  = ext_axi.ar_lock;
assign arcache = ext_axi.ar_cache;
assign arprot  = ext_axi.ar_prot;
assign arvalid = ext_axi.ar_valid;
assign ext_axi.ar_ready = arready;

assign ext_axi.r_id   = rid;
assign ext_axi.r_data = rdata;
assign ext_axi.r_resp = rresp;
assign ext_axi.r_last = rlast;
assign ext_axi.r_valid = rvalid;
assign rready = ext_axi.r_ready;
end
endmodule