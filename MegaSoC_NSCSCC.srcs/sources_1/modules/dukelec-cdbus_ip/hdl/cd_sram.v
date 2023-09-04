/*
 * This Source Code Form is subject to the terms of the Mozilla
 * Public License, v. 2.0. If a copy of the MPL was not distributed
 * with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Notice: The scope granted to MPL excludes the ASIC industry.
 *
 * Copyright (c) 2017 DUKELEC, All rights reserved.
 *
 * Author: Duke Fong <d@d-l.io>
 */


module cd_sram
       #(
           parameter A_WIDTH = 8,
           parameter C_ASIC_SRAM = 0
       )(
           input                 clk,
           input [(A_WIDTH-1):0] ra,
           input [(A_WIDTH-1):0] wa,

           output       [7:0]    rd,
           input                 re,

           input        [7:0]    wd,
           input                 we
       );
       
generate if (C_ASIC_SRAM == 0) begin
    reg [7:0] ram[2**A_WIDTH-1:0];
    reg [7:0] rd_r;
    assign rd = rd_r;
    
    always @(posedge clk) begin
        if (we)
            ram[wa] <= wd;
    
        rd_r <= re ? ram[ra] : 8'dx;
    end
end else begin
    S018DP_RAM_DP_W256_B8_M4 ram (
        .CLKA(clk ),
        .CLKB(clk ),
        
        .CENA(~re ),
        .CENB(~we ),
        
        .WENA(1'b1),
        .WENB(~we ),
        
        .AA  (ra  ),
        .AB  (wa  ),
        
        .QA  (rd  ),
        .QB  (    ),
        
        .DA  (8'bx),
        .DB  (wd  )
    );
end
endgenerate
 
endmodule

