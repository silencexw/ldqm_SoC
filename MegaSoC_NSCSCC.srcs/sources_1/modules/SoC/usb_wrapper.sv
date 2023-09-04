`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/06 10:49:02
// Design Name: 
// Module Name: usb_wapper
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


module usb_wrapper(
    // UTMI
    input           UTMI_clk,
    input  [7:0]    UTMI_data_i,
    output [7:0]    UTMI_data_o,
    output          UTMI_data_t,
    output          UTMI_reset,
    input           UTMI_txready,
    input           UTMI_rxvalid,
    input           UTMI_rxactive,
    input           UTMI_rxerror,
    input  [1:0]    UTMI_linestate,
    input           UTMI_hostdisc,
    input           UTMI_iddig,
    input           UTMI_vbusvalid,
    input           UTMI_sessend,
    output          UTMI_txvalid,
    output [1:0]    UTMI_opmode,
    output [1:0]    UTMI_xcvrsel,
    output          UTMI_termsel,
    output          UTMI_dppulldown,
    output          UTMI_dmpulldown,
    output          UTMI_idpullup,
    output          UTMI_chrgvbus,
    output          UTMI_dischrgvbus,
    output          UTMI_suspend_n,
    
    input           aclk,
    input           aresetn,
    output          usb_interrupt,
    
    AXI_BUS.Slave   slv
    );
    `define AXI_LINE(name) AXI_BUS #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXI_ID_WIDTH(4)) name()
    `AXI_LINE(usb);
        
    assign usb.r_id = usb.ar_id;
    assign usb.b_id = usb.aw_id;
    assign usb.r_last = usb.r_valid;
    
    /*
    xpm_cdc_single #(
      .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(1)   // DECIMAL; 0=do not register input, 1=register input
   )
   xpm_cdc_single_inst (
      .dest_out(dest_out), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                           // registered.

      .dest_clk(dest_clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_clk(src_clk),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
      .src_in(src_in)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
   );*/
   logic UTMI_aresetn;
   
   stolen_cdc_sync_rst usb_rstgen(
        .dest_clk(UTMI_clk),
        .dest_rst(UTMI_aresetn),
        .src_rst(aresetn)
    );
   
    axi_cdc_intf #(
        .AXI_ID_WIDTH(4),
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .LOG_DEPTH(2)
    ) usb_cdc (
        .src_clk_i(aclk),
        .src_rst_ni(aresetn),
        .src(slv),
        
        .dst_clk_i(UTMI_clk),
        .dst_rst_ni(UTMI_aresetn),
        .dst(usb)
    ); 
    
    logic intr;
    stolen_cdc_array_single #(1, 0, 1) int_cdc(
       .src_clk(UTMI_clk),
       .src_in(intr),
       .dest_clk(aclk),
       .dest_out(usb_interrupt)
    );
    
    
    utmi_usb_controller usb_controller(
      .aclk                 (UTMI_clk),
      .aresetn              (UTMI_aresetn),
      .intr                 (intr),
      
      .cfg_awvalid          (usb.aw_valid),
      .cfg_awaddr           (usb.aw_addr),
      .cfg_awready          (usb.aw_ready),
      .cfg_wvalid           (usb.w_valid),
      .cfg_wdata            (usb.w_data),
      .cfg_wstrb            (usb.w_strb),
      .cfg_wready           (usb.w_ready),
      .cfg_arready          (usb.ar_ready),
      .cfg_arvalid          (usb.ar_valid),
      .cfg_araddr           (usb.ar_addr),
      .cfg_bready           (usb.b_ready),
      .cfg_bvalid           (usb.b_valid),
      .cfg_bresp            (usb.b_resp),
      .cfg_rready           (usb.r_ready),
      .cfg_rvalid           (usb.r_valid),
      .cfg_rdata            (usb.r_data),
      .cfg_rresp            (usb.r_resp),
      
      .utmi_data_in         (UTMI_data_i),
      .utmi_data_out        (UTMI_data_o),
      .utmi_data_t          (UTMI_data_t),
      .utmi_reset           (UTMI_reset),
      .utmi_txready         (UTMI_txready),
      .utmi_rxvalid         (UTMI_rxvalid),
      .utmi_rxactive        (UTMI_rxactive),
      .utmi_rxerror         (UTMI_rxerror),
      .utmi_linestate       (UTMI_linestate),
      .utmi_txvalid         (UTMI_txvalid),
      .utmi_opmode          (UTMI_opmode),
      .utmi_xcvrsel         (UTMI_xcvrsel),
      .utmi_termsel         (UTMI_termsel),
      .utmi_dppulldown      (UTMI_dppulldown),
      .utmi_dmpulldown      (UTMI_dmpulldown),
      .utmi_idpullup        (UTMI_idpullup),
      .utmi_chrgvbus        (UTMI_chrgvbus),
      .utmi_dischrgvbus     (UTMI_dischrgvbus),
      .utmi_suspend_n       (UTMI_suspend_n),
      .utmi_hostdisc        (UTMI_hostdisc),
      .utmi_iddig           (UTMI_iddig),
      .utmi_vbusvalid       (UTMI_vbusvalid),
      .utmi_sessend         (UTMI_sessend)
    );
endmodule
