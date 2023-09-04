`timescale 1ns / 1ps
`include "iobuf_helper.svh"
`include "debug.vh"

module mchip_top (
    input clk_100m,
    input sys_rstn,

   //------DDR3 interface------
    inout  [15:0] ddr3_dq,
    output [12:0] ddr3_addr,
    output [2 :0] ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_odt,
    output        ddr3_reset_n,
    output        ddr3_cke,
    output [1:0]  ddr3_dm,
    inout  [1:0]  ddr3_dqs_p,
    inout  [1:0]  ddr3_dqs_n,
    output        ddr3_ck_p,
    output        ddr3_ck_n,

    
    output        SPI_CLK,              // SPI 时钟，由 SoC 时钟分频得到
    output  [3:0] SPI_CS,               // SPI 片�?�信�?
    inout         SPI_MISO,             // SPI 数据信号�?1bit SPI: MISO，Dual SPI: IO1�?
    inout         SPI_MOSI,             // SPI 数据信号�?1bit SPI：MOSI，Dual SPI: IO2�?
    
    inout         UART_RX,              // UART
    inout         UART_TX,
    
    input           mii_tx_clk,
    output  [3:0]   mii_txd,    
    output          mii_tx_en,
    output          mii_tx_er,

    input           mii_rx_clk,
    input   [3:0]   mii_rxd, 
    input           mii_rxdv,
    input           mii_rx_err,
    input           mii_crs,
    input           mii_col,
    output mii_phy_rstn,
    
    output        MDC,                  // MDIO 时钟（RMII 管理总线），�? SoC 时钟分频得到
    inout         MDIO,                 // MDIO 数据

    //  VGA
    output [3:0]  VGA_R,
    output [3:0]  VGA_G,
    output [3:0]  VGA_B,
    output        VGA_HSYNC,
    output        VGA_VSYNC,

    // PS2
    inout   PS2_dat,
    inout   PS2_clk,
    
    // USB
    input        UTMI_clk,
    inout  [7:0] UTMI_data,
    output       UTMI_reset,
    input        UTMI_txready,
    input        UTMI_rxvalid,
    input        UTMI_rxactive,
    input        UTMI_rxerror,
    input  [1:0] UTMI_linestate,
    input        UTMI_hostdisc,
    input        UTMI_iddig,
    input        UTMI_vbusvalid,
    input        UTMI_sessend,
    output       UTMI_txvalid,
    output [1:0] UTMI_opmode,
    output [1:0] UTMI_xcvrsel,
    output       UTMI_termsel,
    output       UTMI_dppulldown,
    output       UTMI_dmpulldown,
    output       UTMI_idpullup,
    output       UTMI_chrgvbus,
    output       UTMI_dischrgvbus,
    output       UTMI_suspend_n,
    
    inout  [3:0]  SD_DAT,               // SDIO 数据输入 / 输出
    inout         SD_CMD,               // SDIO 指令输入 / 输出
    output        SD_CLK,               // SDIO 时钟输出，由 SoC 时钟分频得到
    
    output          CDBUS_tx,           // CDBUS 总线信号，类�? UART 串口，属�? SoC 时钟�?
    output          CDBUS_tx_en,
    input           CDBUS_rx,

    inout  [7:0] gpio,

    inout i2cm_scl,
    inout i2cm_sda
);

wire soc_clk;
wire ui_clk;
wire soc_aresetn;
`IPAD_GEN_SIMPLE(sys_rstn)

wire mem_sys_clk, mem_ref_clk, cpu_clk, vga_clk;
wire clk_locked;

  clk_wiz_1 clk_gen_1
   (
    // Clock out ports
    .mem_ref_clk(mem_ref_clk),      // output mem_ref_clk
    .mem_sys_clk(mem_sys_clk),      // output mem_sys_clk
    .cpu_clk(cpu_clk),              // output cpu_clk
    .vga_clk(vga_clk),              // ouptut vga_clk
    .soc_clk(soc_clk),
    // Status and control signals
    .resetn(sys_rstn_c),            // input resetn
    .locked(clk_locked),
    // Clock in ports
    .clk_in1(clk_100m));            // input clk_in1


// PS2
`IOBUF_GEN(PS2_clk, PS2_clk_tri);
`IOBUF_GEN(PS2_dat, PS2_dat_tri);

 // USB
 `IOBUF_GEN_VEC_UNIFORM_SIMPLE(UTMI_data);

// WARNING: en==0 means output, en==1 means input!!!
`IOBUF_GEN_SIMPLE(UART_TX)
`IOBUF_GEN_SIMPLE(UART_RX)
`IOBUF_GEN_VEC_SIMPLE(gpio)

`IOBUF_GEN_SIMPLE(i2c_sda)
`IPAD_GEN_SIMPLE(i2c_scl)

`OPAD_GEN_SIMPLE(SPI_CLK)
`OPAD_GEN_VEC_SIMPLE(SPI_CS)
`IOBUF_GEN_SIMPLE(SPI_MISO)
`IOBUF_GEN_SIMPLE(SPI_MOSI)

`IPADG_GEN_SIMPLE(mii_tx_clk)
`IPADG_GEN_SIMPLE(mii_rx_clk)
`OPAD_GEN_VEC_SIMPLE(mii_txd)
`IPAD_GEN_VEC_SIMPLE(mii_rxd)
`OPAD_GEN_SIMPLE(mii_tx_en)
`OPAD_GEN_SIMPLE(mii_tx_er)
`IPAD_GEN_SIMPLE(mii_rxdv)
`IPAD_GEN_SIMPLE(mii_rx_err)
`IPAD_GEN_SIMPLE(mii_crs)
`IPAD_GEN_SIMPLE(mii_col)

`OPAD_GEN_SIMPLE(MDC)
`IOBUF_GEN_SIMPLE(MDIO)

`OPAD_GEN_VEC_SIMPLE(VGA_R)
`OPAD_GEN_VEC_SIMPLE(VGA_G)
`OPAD_GEN_VEC_SIMPLE(VGA_B)
`OPAD_GEN_SIMPLE(VGA_HSYNC)
`OPAD_GEN_SIMPLE(VGA_VSYNC)

`OPAD_GEN_SIMPLE(SD_CLK)
`IOBUF_GEN_SIMPLE(SD_CMD)
`IOBUF_GEN_VEC_UNIFORM_SIMPLE(SD_DAT)

`OEPAD_GEN_SIMPLE(CDBUS_tx)
`OEPAD_GEN_SIMPLE(CDBUS_tx_en)
`IPAD_GEN_SIMPLE(CDBUS_rx)

`IOBUF_GEN_SIMPLE(i2cm_scl)
`IOBUF_GEN_SIMPLE(i2cm_sda)

assign i2c_sda_t = i2c_sda_o;

wire [6:0]  mem_axi_awid;
wire [31:0] mem_axi_awaddr;
wire [7:0]  mem_axi_awlen;
wire [2:0]  mem_axi_awsize;
wire [1:0]  mem_axi_awburst;
wire        mem_axi_awvalid;
wire        mem_axi_awready;
wire [31:0] mem_axi_wdata;
wire [3:0]  mem_axi_wstrb;
wire        mem_axi_wlast;
wire        mem_axi_wvalid;
wire        mem_axi_wready;
wire        mem_axi_bready;
wire  [6:0] mem_axi_bid;
wire  [1:0] mem_axi_bresp;
wire        mem_axi_bvalid;
wire [6:0]  mem_axi_arid;
wire [31:0] mem_axi_araddr;
wire [7:0]  mem_axi_arlen;
wire [2:0]  mem_axi_arsize;
wire [1:0]  mem_axi_arburst;
wire        mem_axi_arvalid;
wire        mem_axi_arready;
wire        mem_axi_rready;
wire [6:0]  mem_axi_rid;
wire [31:0] mem_axi_rdata;
wire [1:0]  mem_axi_rresp;
wire        mem_axi_rlast;
wire        mem_axi_rvalid;
wire mig_ui_sync_rst;
  mig_axi_32 u_mig_axi_32 (

    // Memory interface ports
    .ddr3_addr                      (ddr3_addr),  // output [12:0]		ddr3_addr
    .ddr3_ba                        (ddr3_ba),  // output [2:0]		ddr3_ba
    .ddr3_cas_n                     (ddr3_cas_n),  // output			ddr3_cas_n
    .ddr3_ck_n                      (ddr3_ck_n),  // output [0:0]		ddr3_ck_n
    .ddr3_ck_p                      (ddr3_ck_p),  // output [0:0]		ddr3_ck_p
    .ddr3_cke                       (ddr3_cke),  // output [0:0]		ddr3_cke
    .ddr3_ras_n                     (ddr3_ras_n),  // output			ddr3_ras_n
    .ddr3_reset_n                   (ddr3_reset_n),  // output			ddr3_reset_n
    .ddr3_we_n                      (ddr3_we_n),  // output			ddr3_we_n
    .ddr3_dq                        (ddr3_dq),  // inout [15:0]		ddr3_dq
    .ddr3_dqs_n                     (ddr3_dqs_n),  // inout [1:0]		ddr3_dqs_n
    .ddr3_dqs_p                     (ddr3_dqs_p),  // inout [1:0]		ddr3_dqs_p
    .init_calib_complete            (),  // output			init_calib_complete
      
    .ddr3_dm                        (ddr3_dm),  // output [1:0]		ddr3_dm
    .ddr3_odt                       (ddr3_odt),  // output [0:0]		ddr3_odt
    // Application interface ports
    .ui_clk                         (ui_clk),  // output			ui_clk
    .ui_clk_sync_rst                (mig_ui_sync_rst),  // output			ui_clk_sync_rst
    .aresetn                        (soc_aresetn),  // input			aresetn

    .app_sr_req                     (1'b0),  // input			app_sr_req
    .app_ref_req                    (1'b0),  // input			app_ref_req
    .app_zq_req                     (1'b0),  // input			app_zq_req

    .s_axi_awlock                   ('b0),  // input [0:0]			s_axi_awlock
    .s_axi_awcache                  ('b0),  // input [3:0]			s_axi_awcache
    .s_axi_awprot                   ('b0),  // input [2:0]			s_axi_awprot
    .s_axi_awqos                    ('b0),  // input [3:0]			s_axi_awqos

    .s_axi_arlock                   ('b0),  // input [0:0]			s_axi_arlock
    .s_axi_arcache                  ('b0),  // input [3:0]			s_axi_arcache
    .s_axi_arprot                   ('b0),  // input [2:0]			s_axi_arprot
    .s_axi_arqos                    ('b0),  // input [3:0]			s_axi_arqos
    
    .s_axi_awid                     (mem_axi_awid),  // input [4:0]			s_axi_awid
    .s_axi_awaddr                   (mem_axi_awaddr[26:0]),  // input [26:0]			s_axi_awaddr
    .s_axi_awlen                    (mem_axi_awlen),  // input [7:0]			s_axi_awlen
    .s_axi_awsize                   (mem_axi_awsize),  // input [2:0]			s_axi_awsize
    .s_axi_awburst                  (mem_axi_awburst),  // input [1:0]			s_axi_awburst
    .s_axi_awvalid                  (mem_axi_awvalid),  // input			s_axi_awvalid
    .s_axi_awready                  (mem_axi_awready),  // output			s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata                    (mem_axi_wdata),  // input [31:0]			s_axi_wdata
    .s_axi_wstrb                    (mem_axi_wstrb),  // input [3:0]			s_axi_wstrb
    .s_axi_wlast                    (mem_axi_wlast),  // input			s_axi_wlast
    .s_axi_wvalid                   (mem_axi_wvalid),  // input			s_axi_wvalid
    .s_axi_wready                   (mem_axi_wready),  // output			s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid                      (mem_axi_bid),  // output [4:0]			s_axi_bid
    .s_axi_bresp                    (mem_axi_bresp),  // output [1:0]			s_axi_bresp
    .s_axi_bvalid                   (mem_axi_bvalid),  // output			s_axi_bvalid
    .s_axi_bready                   (mem_axi_bready),  // input			s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid                     (mem_axi_arid),  // input [4:0]			s_axi_arid
    .s_axi_araddr                   (mem_axi_araddr[26:0]),  // input [26:0]			s_axi_araddr
    .s_axi_arlen                    (mem_axi_arlen),  // input [7:0]			s_axi_arlen
    .s_axi_arsize                   (mem_axi_arsize),  // input [2:0]			s_axi_arsize
    .s_axi_arburst                  (mem_axi_arburst),  // input [1:0]			s_axi_arburst
    .s_axi_arvalid                  (mem_axi_arvalid),  // input			s_axi_arvalid
    .s_axi_arready                  (mem_axi_arready),  // output			s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid                      (mem_axi_rid),  // output [4:0]			s_axi_rid
    .s_axi_rdata                    (mem_axi_rdata),  // output [31:0]			s_axi_rdata
    .s_axi_rresp                    (mem_axi_rresp),  // output [1:0]			s_axi_rresp
    .s_axi_rlast                    (mem_axi_rlast),  // output			s_axi_rlast
    .s_axi_rvalid                   (mem_axi_rvalid),  // output			s_axi_rvalid
    .s_axi_rready                   (mem_axi_rready),  // input	
    // System Clock Ports
    .sys_clk_i                      (mem_sys_clk),
    // Reference Clock Ports
    .clk_ref_i                      (mem_ref_clk),
    .sys_rst                        (clk_locked) // input sys_rst
    );
    
assign soc_aresetn = ~mig_ui_sync_rst;

soc_top #(
    .C_ASIC_SRAM(0)
) soc (
    .soc_clk(soc_clk),
    .cpu_clk(cpu_clk),
    .mig_aresetn(soc_aresetn),
    .mig_clk(ui_clk),
    
    .mem_axi_awid(mem_axi_awid),
    .mem_axi_awaddr(mem_axi_awaddr),
    .mem_axi_awlen(mem_axi_awlen),
    .mem_axi_awsize(mem_axi_awsize),
    .mem_axi_awburst(mem_axi_awburst),
    .mem_axi_awvalid(mem_axi_awvalid),
    .mem_axi_awready(mem_axi_awready),
    .mem_axi_wdata(mem_axi_wdata),
    .mem_axi_wstrb(mem_axi_wstrb),
    .mem_axi_wlast(mem_axi_wlast),
    .mem_axi_wvalid(mem_axi_wvalid),
    .mem_axi_wready(mem_axi_wready),
    .mem_axi_bready(mem_axi_bready),
    .mem_axi_bid(mem_axi_bid),
    .mem_axi_bresp(mem_axi_bresp),
    .mem_axi_bvalid(mem_axi_bvalid),
    .mem_axi_arid(mem_axi_arid),
    .mem_axi_araddr(mem_axi_araddr),
    .mem_axi_arlen(mem_axi_arlen),
    .mem_axi_arsize(mem_axi_arsize),
    .mem_axi_arburst(mem_axi_arburst),
    .mem_axi_arvalid(mem_axi_arvalid),
    .mem_axi_arready(mem_axi_arready),
    .mem_axi_rready(mem_axi_rready),
    .mem_axi_rid(mem_axi_rid),
    .mem_axi_rdata(mem_axi_rdata),
    .mem_axi_rresp(mem_axi_rresp),
    .mem_axi_rlast(mem_axi_rlast),
    .mem_axi_rvalid(mem_axi_rvalid),
    
    .csn_o(SPI_CS_c),
    .sck_o(SPI_CLK_c),
    .sdo_i(SPI_MOSI_i),
    .sdo_o(SPI_MOSI_o),
    .sdo_en(SPI_MOSI_t),  // Notice: en==0 means output, en==1 means input!
    .sdi_i(SPI_MISO_i),
    .sdi_o(SPI_MISO_o),
    .sdi_en(SPI_MISO_t),
    
    .uart_txd_i(UART_TX_i),
    .uart_txd_o(UART_TX_o),
    .uart_txd_en(UART_TX_t),
    .uart_rxd_i(UART_RX_i),
    .uart_rxd_o(UART_RX_o),
    .uart_rxd_en(UART_RX_t),
    
    .mii_tx_clk(mii_tx_clk_c),
    .mii_txd(mii_txd_c),    
    .mii_tx_en(mii_tx_en_c),
    .mii_tx_er(mii_tx_er_c),

    .mii_rx_clk(mii_rx_clk_c),
    .mii_rxd(mii_rxd_c), 
    .mii_rxdv(mii_rxdv_c),
    .mii_rx_err(mii_rx_err_c),
    .mii_crs(mii_crs_c),
    .mii_col(mii_col_c),
    .phy_rstn(mii_phy_rstn),

    // MDIO
    .mdc_0        (MDC_c    ),
    .md_i_0       (MDIO_i   ),
    .md_o_0       (MDIO_o   ),       
    .md_t_0       (MDIO_t   ),

    // VGA
    .vga_r      (VGA_R_c),
    .vga_g      (VGA_G_c),
    .vga_b      (VGA_B_c),
    .vga_hsync  (VGA_HSYNC_c),
    .vga_vsync  (VGA_VSYNC_c),
    .vga_clk    (vga_clk),  // input

    // PS2
    .ps2_clk_o (PS2_clk_tri_o),
    .ps2_clk_t (PS2_clk_tri_t),
    .ps2_clk_i (PS2_clk_tri_i),
    .ps2_dat_o (PS2_dat_tri_o),
    .ps2_dat_t (PS2_dat_tri_t),
    .ps2_dat_i (PS2_dat_tri_i),
    
    // USB
    .UTMI_clk           (UTMI_clk),
    .UTMI_data_i        (UTMI_data_i),
    .UTMI_data_o        (UTMI_data_o),
    .UTMI_data_t        (UTMI_data_t),
    .UTMI_reset         (UTMI_reset),
    .UTMI_txready       (UTMI_txready),
    .UTMI_rxvalid       (UTMI_rxvalid),
    .UTMI_rxactive      (UTMI_rxactive),
    .UTMI_rxerror       (UTMI_rxerror),
    .UTMI_linestate     (UTMI_linestate),
    .UTMI_hostdisc      (UTMI_hostdisc),
    .UTMI_iddig         (UTMI_iddig),
    .UTMI_vbusvalid     (UTMI_vbusvalid),
    .UTMI_sessend       (UTMI_sessend),
    .UTMI_txvalid       (UTMI_txvalid),
    .UTMI_opmode        (UTMI_opmode),
    .UTMI_xcvrsel       (UTMI_xcvrsel),
    .UTMI_termsel       (UTMI_termsel),
    .UTMI_dppulldown    (UTMI_dppulldown),
    .UTMI_dmpulldown    (UTMI_dmpulldown),
    .UTMI_idpullup      (UTMI_idpullup),
    .UTMI_chrgvbus      (UTMI_chrgvbus),
    .UTMI_dischrgvbus   (UTMI_dischrgvbus),
    .UTMI_suspend_n     (UTMI_suspend_n),
    
    .sd_dat_i(SD_DAT_i),
    .sd_dat_o(SD_DAT_o),
    .sd_dat_t(SD_DAT_t),
    .sd_cmd_i(SD_CMD_i),
    .sd_cmd_o(SD_CMD_o),
    .sd_cmd_t(SD_CMD_t),
    .sd_clk  (SD_CLK_c),
    
    .CDBUS_tx(CDBUS_tx_c),
    .CDBUS_tx_t(CDBUS_tx_t),
    .CDBUS_tx_en(CDBUS_tx_en_c),
    .CDBUS_tx_en_t(CDBUS_tx_en_t),
    .CDBUS_rx(CDBUS_rx_c),

    .gpio_o(gpio_o),
    .gpio_i(gpio_i),
    .gpio_t(gpio_t),
    .spi_div_ctrl(4'b0100),
    .intr_ctrl(1'b0),

    .debug_output_mode(2'b00),

    .i2cm_scl_i,
	.i2cm_scl_o,
	.i2cm_scl_t, 

	.i2cm_sda_i,
	.i2cm_sda_o,
	.i2cm_sda_t
);

endmodule
