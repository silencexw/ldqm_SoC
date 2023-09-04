`timescale 1ns/1ps
module cpu_cache_convertor (
    input logic inst_req,
    input logic [31:0] inst_addr,
    input logic [1:0] inst_size,
    input logic inst_cached,
    output logic [63:0] inst_rdata,
    output logic inst_addr_ok,
    output logic inst_data_ok,

    input logic data_req,
    input logic data_wr,
    input logic [3:0] data_wstrb,
    input logic [31:0] data_addr,
    input logic [1:0] data_size,
    input logic data_cached,
    input logic [31:0] data_wdata,
    output logic [31:0] data_rdata,
    output logic data_addr_ok,
    output logic data_data_ok,

    cpu_ibus_if.master ibus,
    cpu_dbus_if.master dbus
);

assign ibus.valid = inst_req;
assign ibus.address = inst_addr;
assign ibus.size = inst_size;
assign ibus.op = 0;
//assign ibus.uncache = !(inst_addr[31:28] >= 4'b1000 && inst_addr[31:28] <= 4'b1001);
assign ibus.uncache = !inst_cached;
//assign ibus.uncache = 1'b0;
assign inst_addr_ok = ibus.addr_ok;
assign inst_data_ok = ibus.data_ok;
assign inst_rdata = ibus.rdata;

assign dbus.valid = data_req;
assign dbus.address = data_addr;
assign dbus.size = data_size;
assign dbus.wdata = data_wdata;
assign dbus.op = data_wr;
//assign dbus.uncache = !(data_addr[31:28] >= 4'b1000 && data_addr[31:28] <= 4'b1001);
assign dbus.uncache = !data_cached;
assign dbus.wstrb = data_wstrb;
assign data_rdata = dbus.rdata;
assign data_addr_ok = dbus.addr_ok;
assign data_data_ok = dbus.data_ok;

endmodule