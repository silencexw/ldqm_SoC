module Simple_Dual_Ram_NWByte #(
    parameter LEN_DATA = 32,
    parameter RAM_SIZE = 4096
) (clka,clkb,ena,enb,wea,addra,addrb,dina,doutb);
    localparam LEN_ADDR = $clog2(RAM_SIZE);
    input                  clka,clkb,ena,enb;
    input                  wea;
    input  [LEN_ADDR-1:0]  addra,addrb;
    input  [LEN_DATA-1:0]  dina;
    output [LEN_DATA-1:0]  doutb;
    
    (* ram_style="block" *) reg [LEN_DATA - 1 : 0] ram [RAM_SIZE - 1 : 0];

    reg [LEN_DATA-1:0] doutb;

    integer j;
    initial begin
        for (j = 0;j < RAM_SIZE; j++) ram[j] = 0;
    end
    
    
    always @(posedge clka) begin
       if (ena && wea) begin
             ram[addra] <= dina;
       end
    end
    

    always @(posedge clkb) begin
        if (enb) begin
            doutb <= ram[addrb];
        end
    end
endmodule