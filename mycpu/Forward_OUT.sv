`timescale 1ns/1ps
//`include "cpu_macro.svh"
/*
execute class bypassing net
*/
module Forward_OUT (
    input clk,
    input reset,
    input stall,
    // static parameters
    input reg_info reg1,
    input lrf_data reg1_data,
    input reg_info reg2,
    input lrf_data reg2_data,
    
    input wr_reg_info [1:0] wd_0,
    input wr_reg_info [1:0] wd_1,
    input wr_reg_info [1:0] wd_2,
    input wr_reg_info [1:0] wd_3,
    input wr_reg_info [1:0] wd_4,

    output lrf_data forward_reg1_data,
    output lrf_data forward_reg2_data
);
wr_reg_info [1:0] wd[4:0];
assign wd[0] = wd_0;
assign wd[1] = wd_1;
assign wd[2] = wd_2;
assign wd[3] = wd_3;
assign wd[4] = wd_4;

logic [31:0] tmp1 [5:0];
logic [4:0] related1;
logic [31:0] tmp2 [5:0];
logic [4:0] related2;
//2023/7/6
logic [31:0] _forward_reg1_data;
logic [31:0] _forward_reg2_data;
logic save_valid1;
logic save_valid2;
assign forward_reg1_data = (related1 || ~save_valid1) ? tmp1[0] : _forward_reg1_data;
assign forward_reg2_data = (related2 || ~save_valid2) ? tmp2[0] : _forward_reg2_data;
assign tmp1[5] = reg1_data;
assign tmp2[5] = reg2_data;
generate
    for (genvar i = 4; i >= 0; --i) begin
        assign tmp1[i] = (~reg1.src && |reg1.addr && reg1.addr == wd[i][1].addr && !(|wd[i][1].Tnew)) ? wd[i][1].data : 
                         (~reg1.src && |reg1.addr && reg1.addr == wd[i][0].addr && !(|wd[i][0].Tnew)) ? wd[i][0].data : 
                         tmp1[i+1];
        assign related1[i] = (~reg1.src && |reg1.addr && reg1.addr == wd[i][1].addr && !(|wd[i][1].Tnew)) || 
                             (~reg1.src && |reg1.addr && reg1.addr == wd[i][0].addr && !(|wd[i][0].Tnew));
        assign tmp2[i] = (~reg2.src && |reg2.addr && reg2.addr == wd[i][1].addr && !(|wd[i][1].Tnew)) ? wd[i][1].data : 
                         (~reg2.src && |reg2.addr && reg2.addr == wd[i][0].addr && !(|wd[i][0].Tnew)) ? wd[i][0].data : 
                         tmp2[i+1];
        assign related2[i] = (~reg2.src && |reg2.addr && reg2.addr == wd[i][1].addr && !(|wd[i][1].Tnew)) || 
                             (~reg2.src && |reg2.addr && reg2.addr == wd[i][0].addr && !(|wd[i][0].Tnew));
    end
endgenerate

//2023/7/6
always_ff @(posedge clk) begin
    if (reset) begin
        _forward_reg1_data <= '0;
        _forward_reg2_data <= '0;
        save_valid1 <= '0;
        save_valid2 <= '0;
    end
    else begin
        if (stall) begin
            if (related1) begin
                _forward_reg1_data <= tmp1[0];
                save_valid1 <= 1'b1;
            end
            if (related2) begin
                _forward_reg2_data <= tmp2[0];
                save_valid2 <= 1'b1;
            end
        end
        else begin
            save_valid1 <= '0;
            _forward_reg1_data <= '0;
            save_valid2 <= '0;
            _forward_reg2_data <= '0;
        end
    end
end
endmodule