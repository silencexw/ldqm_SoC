module simpleDualPortRam #(
    parameter int unsigned dataWidth = 32,
    parameter int unsigned ramDepth = 128,
    // parameter int unsigned dataSize = 8,
    parameter int unsigned byteWidth = 8,
    parameter int unsigned portWidth = 256,
    parameter int unsigned wenWidth = portWidth / byteWidth
) (
    input logic clk,
    input logic reset,

    input logic [$clog2(ramDepth) - 1 : 0] addra,
    input logic [$clog2(ramDepth) - 1 : 0] addrb,
    input logic [wenWidth - 1 : 0] wen,
    input logic [portWidth - 1 : 0] wdata,
    input logic ena,
    input logic enb,
    
    output logic [portWidth - 1 : 0] rdata
);

    `ifdef USE_XPM
    xpm_memory_sdpram
    #(
        // Port A modul parameters
        .ADDR_WIDTH_A($clog2(ramDepth)),
        .WRITE_DATA_WIDTH_A(portWidth),
        .BYTE_WRITE_WIDTH_A(byteWidth),

        // Port B modul parameters
        .ADDR_WIDTH_B($clog2(ramDepth)),
        .READ_DATA_WIDTH_B(portWidth),
        .READ_LATENCY_B(1),
        .WRITE_MODE_B("write_first"),

        // common modul parameters
        .AUTO_SLEEP_TIME(0),
        .CLOCKING_MODE("common_clock"),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .MEMORY_OPTIMIZATION("true"),
        .USE_MEM_INIT(0),
        .MESSAGE_CONTROL(1),
        .MEMORY_PRIMITIVE("auto"),
        .MEMORY_SIZE(portWidth * ramDepth)

    )
    xpm_memory_sdpram_inst (
        .clka(clk),
        .clkb(clk),
        .rstb(reset),

        // port a
        .ena(ena),
        .addra(addra),
        .wea(wen),
        .dina(wdata),

        // port b
        .enb(enb),
        .addrb(addrb),
        .doutb(rdata),
        
        // else 
        .sleep(1'b0),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .regceb(1'b1)
    );
    `else
    
    bram #(
        .LEN_DATA(portWidth),
        .LEN_ADDR($clog2(ramDepth)),
        .byteWidth(byteWidth)
      ) cache_bram(
        .clka(clk),
        .clkb(clk),
        // port a
         .ena(ena),
        .addra(addra),
        .wea(wen),
        .dina(wdata),

        // port b
        .enb(enb),
        .addrb(addrb),
        .doutb(rdata)
      );
      `endif

endmodule