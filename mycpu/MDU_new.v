`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/02 09:02:06
// Design Name: 
// Module Name: MDU_new
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


module MDU_new(
    input wire clk,
    input wire reset,
    
    input wire [31:0] srcA,
    input wire [31:0] srcB,
    input wire [3:0] op,
    
    input  wire in_valid,
    output wire in_ready,
    output wire out_valid,
    input  wire out_ready,
    
    output wire [31:0] hi_res,
    output wire [31:0] lo_res
    );

wire busy_mul, busy_div;
wire valid_res_mul, valid_res_div;
wire [31:0] hi_mul;
wire [31:0] lo_mul;
wire [31:0] hi_div;
wire [31:0] lo_div;
MULUnit_new my_mul(
    .clk    (clk),
    .reset  (reset),
    
    .req    ((op == `MULT || op == `MULTU) && in_valid),
    .busy   (busy_mul),
    .sign   (op == `MULT),
    .srcA   (srcA),
    .srcB   (srcB),
    
    .valid_res(valid_res_mul),
    .res_recv(out_ready),
    .hi_res(hi_mul),
    .lo_res(lo_mul)
);

DIVUnit_new my_div(
    .clk    (clk),
    .reset  (reset),
    
    .req    ((op == `DIV || op == `DIVU) && in_valid),
    .busy   (busy_div),
    .sign   (op == `DIV),
    .srcA   (srcA),
    .srcB   (srcB),
    
    .valid_res(valid_res_div),
    .res_recv(out_ready),
    .hi_res(hi_div),
    .lo_res(lo_div)
);

reg [3:0] op_s;
assign out_valid = valid_res_mul | valid_res_div;
assign in_ready = ~busy_mul & ~busy_div;
assign hi_res = (op_s == `DIV || op_s == `DIVU) ? hi_div : hi_mul;
assign lo_res = (op_s == `DIV || op_s == `DIVU) ? lo_div : lo_mul;

always @(posedge clk) begin
    if (reset) begin
        op_s <= 4'h0;
    end
    else if (in_valid && in_ready) begin
        op_s <= op;
    end
    else if (out_valid && out_ready) begin
        op_s <= 4'h0;
    end
end
endmodule

module MULUnit_new(
    input wire clk,
    input wire reset,
    
    input wire req,
    output wire busy,
    input wire sign,    
    input wire [31:0] srcA,
    input wire [31:0] srcB,
    
    output wire valid_res,
    input wire res_recv,
    output reg [31:0] hi_res,
    output reg [31:0] lo_res
);
reg complete;

assign valid_res = complete;
assign busy = complete;

always@ (posedge clk) begin
    if (reset) begin
        complete <= 1'b0;
        hi_res <= 32'h0;
        lo_res <= 32'h0;
    end
    else if (req && ~busy) begin
        if (sign) begin
            {hi_res, lo_res} <= $signed(srcA) * $signed(srcB);
        end
        else begin
            {hi_res, lo_res} <= srcA * srcB;
        end
        complete <= 1'b1;
    end
    else if (res_recv && complete) begin
        complete <= 1'b0;
    end
end

endmodule

module DIVUnit_new(
    input wire clk,
    input wire reset,
    
    input wire req,
    output reg busy,
    input wire sign,    
    input wire [31:0] srcA,
    input wire [31:0] srcB,
    
    output wire valid_res,
    input wire res_recv,
    output wire [31:0] hi_res,
    output wire [31:0] lo_res
);

//wire [1:0] neg_src;
wire [31:0] unsigned_src32 [1:0];
wire [63:0] unsigned_src64 [1:0];

assign {unsigned_src32[1], unsigned_src32[0]} = {(srcB[31] & sign) ? -srcB : srcB, (srcA[31] & sign) ? -srcA : srcA};
assign {unsigned_src64[1], unsigned_src64[0]} = {unsigned_src32[1], 64'h0, unsigned_src32[0]};

reg [31:0] counter;
reg [66:0] tmp[3:0];

reg [1:0] neg_res;
wire[66:0] sub [2:0];

assign {sub[2], sub[1], sub[0]} = {(tmp[0] << 2) - tmp[3], (tmp[0] << 2) - tmp[2], (tmp[0] << 2) - tmp[1]};

wire [31:0] _res [1:0];

assign {_res[1], _res[0]} = tmp[0][63:0];
assign hi_res = neg_res[1] ? -_res[1] : _res[1];
assign lo_res = neg_res[0] ? -_res[0] : _res[0];
assign valid_res = ~counter[1] & busy;

always @(posedge clk) begin
    if (reset) begin
        neg_res <= 2'b00;
        counter <= 32'h0;
        tmp[3] <= 66'h0;
        tmp[2] <= 66'h0;
        tmp[1] <= 66'h0;
        tmp[0] <= 66'h0;
        busy <= 1'b0;
    end
    else if (req && ~busy) begin
            //begin a div calculate
            counter <= 32'hffffffff;
            neg_res <= {srcA[31] & sign, (srcA[31] & sign) ^ (srcB[31] & sign)};
            {tmp[3], tmp[2], tmp[1], tmp[0]} <= {({3'b0, unsigned_src64[1]} << 1) + {3'b0, unsigned_src64[1]}, 
                                                {3'b0, unsigned_src64[1]} << 1, 
                                                {3'b0, unsigned_src64[1]}, {3'b0, unsigned_src64[0]}};
            busy <= 1'b1;
    end
    else begin
        if(counter[15] & (tmp[0][47:16] < tmp[1][63:32])) begin
                counter <= counter >> 16;
                tmp[0] <= tmp[0] << 16;
        end 
        else if(counter[7] & (tmp[0][55:24] < tmp[1][63:32])) begin
            counter <= counter >> 8;
            tmp[0] <= tmp[0] << 8;
        end 
        else if(counter[3] & (tmp[0][59:28] < tmp[1][63:32])) begin
            counter <= counter >> 4;
            tmp[0] <= tmp[0] << 4;
        end 
        else if(counter[0]) begin
            counter <= counter >> 2;
            tmp[0] <= !sub[2][66] ? sub[2] + 'd3 : !sub[1][66] ? sub[1] + 'd2 : !sub[0][66] ? sub[0] + 'd1 : (tmp[0] << 2);
        end 
        
        if (res_recv && valid_res) begin
            busy <= 1'b0;
        end 
    end
end
endmodule
