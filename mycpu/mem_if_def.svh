`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

/*
	This header defines data structures and constants used in the whole SOPC
*/

// project configuration
`default_nettype wire
`timescale 1ns / 1ps

`define _DIRT_USE_REG_FILE
`define _TAGV_USE_IP_CORE
`define TAGV_USE_LUT
`define _DATA_USE_IP_CORE
`define _USE_XPM


typedef logic [7:0]   uint8_t;
typedef logic [15:0]  uint16_t;
typedef logic [31:0]  uint32_t;
typedef logic [63:0]  uint64_t;
typedef uint32_t      virt_t;
typedef uint32_t      phys_t;

// interface of I$ and CPU
// I$ is 2-stage pipelined
interface cpu_ibus_if();
	logic valid;
	logic op;			// read(0) or write(1)
	logic uncache;      // is uncache
	logic addr_ok;      // is addr ok?
	logic data_ok;  	// is data ok?
	phys_t address;     // physical address 
	logic [1:0] size;
	uint64_t rdata;     // data from mem[address]
	
	modport master (
		output valid, address, size,
		output op, uncache,
		input  addr_ok, data_ok, rdata
	);

	modport slave (
		input valid, address, size,
		input op, uncache,
		output addr_ok, data_ok, rdata
	);

endinterface

// interface of D$ and CPU
interface cpu_dbus_if();
	logic valid;
	logic op;			// read(0) or write(1)
	logic uncache;      // is uncache
	logic addr_ok;      // is addr ok?
	logic data_ok;  	// is data ok?
	phys_t address;     // physical address
	logic [1:0] size;
	uint32_t rdata;     // data from mem[address]
	uint32_t wdata;		// data to mem[address]
	logic [3:0] wstrb;	// wstrb 4'b1111 4'b0011 ... byte enable 
	
	modport master (
		output valid, address, size, wdata,
		output op, uncache, wstrb,
		input  addr_ok, data_ok, rdata
	);

	modport slave (
		input valid, address, size, wdata,
		input op, uncache, wstrb,
		output addr_ok, data_ok, rdata
	);

endinterface

typedef struct packed {
	// ar
    logic [31:0] araddr;
    logic [3 :0] arlen;
    logic [2 :0] arsize;
    logic [1 :0] arburst;
    logic [1 :0] arlock;
    logic [3 :0] arcache;
    logic [2 :0] arprot;
    logic        arvalid;
	// r
    logic        rready;
	// aw
    logic [31:0] awaddr;
    logic [3 :0] awlen;
    logic [2 :0] awsize;
    logic [1 :0] awburst;
    logic [1 :0] awlock;
    logic [3 :0] awcache;
    logic [2 :0] awprot;
    logic        awvalid;
	// w
    logic [31:0] wdata;
    logic [3 :0] wstrb;
    logic        wlast;
    logic        wvalid;
	// b
    logic        bready;
} axi_req_t;

typedef struct packed {
	// ar
	logic        arready;
	// r
	logic [31:0] rdata;
	logic [1 :0] rresp;
	logic        rlast;
	logic        rvalid;
	// aw
	logic        awready;
	// w
	logic        wready;
	// b
	logic [1 :0] bresp;
	logic        bvalid;
} axi_resp_t;

`endif
