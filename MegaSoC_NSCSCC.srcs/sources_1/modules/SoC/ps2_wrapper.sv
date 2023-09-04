`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/14 19:44:05
// Design Name: 
// Module Name: ps2_wrapper
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


module ps2_wrapper(
    input aclk,
    input aresetn,
    output ps2_clk_o,
    output ps2_clk_t,
    input  ps2_clk_i,
    output ps2_dat_o,
    output ps2_dat_t,
    input  ps2_dat_i,

    output irq,

    AXI_BUS.Slave   slv
    );
    
    wire [31:0] apb_paddr;
    wire [31:0] apb_prdata;
    wire [31:0] apb_pwdata;
    wire [3:0] apb_pstrb;
    wire [2:0] apb_pprot;
    wire apb_penable;
    wire apb_pwrite;
    wire apb_pready;
    wire apb_psel;
    wire apb_pslverr;
    /*
    (*mark_debug = "true"*) wire [31:0] ps2_slave_ar_addr  = slv.ar_addr  ;
    (*mark_debug = "true"*) wire        ps2_slave_ar_valid = slv.ar_valid ;
    (*mark_debug = "true"*) wire        ps2_slave_ar_ready = slv.ar_ready ;
    (*mark_debug = "true"*) wire [2:0]  ps2_slave_ar_prot =  slv.ar_prot  ;
    (*mark_debug = "true"*) wire [31:0] ps2_slave_r_data   = slv.r_data   ;
    (*mark_debug = "true"*) wire [1 :0] ps2_slave_r_resp   = slv.r_resp   ;
    (*mark_debug = "true"*) wire        ps2_slave_r_valid  = slv.r_valid  ;
    (*mark_debug = "true"*) wire        ps2_slave_r_ready  = slv.r_ready  ;
    (*mark_debug = "true"*) wire [31:0] ps2_slave_aw_addr  = slv.aw_addr  ;
    (*mark_debug = "true"*) wire        ps2_slave_aw_valid = slv.aw_valid ;
    (*mark_debug = "true"*) wire        ps2_slave_aw_ready = slv.aw_ready ;
    (*mark_debug = "true"*) wire [2:0]  ps2_slave_aw_prot =  slv.aw_prot  ;
    (*mark_debug = "true"*) wire [31:0] ps2_slave_w_data   = slv.w_data   ;
    (*mark_debug = "true"*) wire [3 :0] ps2_slave_w_strb   = slv.w_strb   ;
    (*mark_debug = "true"*) wire        ps2_slave_w_valid  = slv.w_valid  ;
    (*mark_debug = "true"*) wire        ps2_slave_w_ready  = slv.w_ready  ;
    (*mark_debug = "true"*) wire [1 :0] ps2_slave_b_resp   = slv.b_resp   ;
    (*mark_debug = "true"*) wire        ps2_slave_b_valid  = slv.b_valid  ;
    (*mark_debug = "true"*) wire        ps2_slave_b_ready  = slv.b_ready  ;

    (*mark_debug = "true"*) wire [3 :0] ps2_slave_ar_id = slv.ar_id ;
    (*mark_debug = "true"*) wire [3 :0] ps2_slave_r_id  = slv.r_id  ;
    (*mark_debug = "true"*) wire [3 :0] ps2_slave_aw_id = slv.aw_id ;
    (*mark_debug = "true"*) wire [3 :0] ps2_slave_b_id  = slv.b_id  ;*/
    /*logic [3:0] r_id, b_id;
    always_ff @(posedge aclk) begin
        if (~aresetn) begin
            r_id <= 0;
            b_id <= 0;
        end
        else begin
            if (slv.ar_valid && slv.ar_ready) begin
                r_id <= slv.ar_id;
            end
            
            if (slv.aw_valid && slv.aw_ready) begin
                b_id <= slv.aw_id;
            end
        end
    end
    assign slv.r_id = r_id;
    assign slv.b_id = b_id;*/
    assign slv.r_id = slv.ar_id;
    assign slv.b_id = slv.aw_id;
    assign slv.r_last = slv.r_valid;
  

    axi_apb_bridge_0 axi_apb_bridge(
        .s_axi_aclk(aclk),
        .s_axi_aresetn(aresetn),

        .s_axi_araddr       (slv.ar_addr ),
        .s_axi_arprot       (slv.ar_prot ),
        .s_axi_arvalid      (slv.ar_valid),
        .s_axi_arready      (slv.ar_ready),
        .s_axi_rdata        (slv.r_data  ),
        .s_axi_rresp        (slv.r_resp  ),
        .s_axi_rvalid       (slv.r_valid ),
        .s_axi_rready       (slv.r_ready ),
        .s_axi_awaddr       (slv.aw_addr ),
        .s_axi_awprot       (slv.aw_prot),
        .s_axi_awvalid      (slv.aw_valid),
        .s_axi_awready      (slv.aw_ready),
        .s_axi_wdata        (slv.w_data  ),
        .s_axi_wstrb        (slv.w_strb  ),
        .s_axi_wvalid       (slv.w_valid ),
        .s_axi_wready       (slv.w_ready ),
        .s_axi_bresp        (slv.b_resp  ),
        .s_axi_bvalid       (slv.b_valid ),
        .s_axi_bready       (slv.b_ready ),

        .m_apb_paddr        (apb_paddr),
        .m_apb_psel         (apb_psel),
        .m_apb_penable      (apb_penable),
        .m_apb_pwrite       (apb_pwrite),
        .m_apb_pwdata       (apb_pwdata),
        .m_apb_pready       (apb_pready),
        .m_apb_prdata       (apb_prdata),
        .m_apb_pslverr      (apb_pslverr),
        .m_apb_pprot        (apb_pprot),
        .m_apb_pstrb        (apb_pstrb)    
    );

    ps2_controller instance_ps2(
        .penable            (apb_penable),
        .perr               (apb_pslverr),
        .write              (apb_pwrite),
        .paddr              (apb_paddr[3:0]),
        .writedata          (apb_pwdata),
        .psel               (apb_psel),
        .waitrequest_n      (apb_pready),
        .readdata           (apb_prdata),
        .byteenable         (apb_pstrb),

        .clk                (aclk),
        .reset_n            (aresetn),
        .irq                (irq),

        .PS2_CLK_o          (ps2_clk_o),
        .PS2_CLK_t          (ps2_clk_t),
        .PS2_CLK_i          (ps2_clk_i),
        .PS2_DAT_o          (ps2_dat_o),
        .PS2_DAT_t          (ps2_dat_t),
        .PS2_DAT_i          (ps2_dat_i)
    );
endmodule
