`timescale 1ns/1ps
//`include "cpu_macro.svh"
module Forward_ISSUE (
    input reg_info [1:0] reg1,
    input lrf_data [1:0] reg1_data,
    input reg_info [1:0] reg2,
    input lrf_data [1:0] reg2_data,
    
    input wr_reg_info [1:0] wd_0,
    input wr_reg_info [1:0] wd_1,
    input wr_reg_info [1:0] wd_2,
    input wr_reg_info [1:0] wd_3,
    input wr_reg_info [1:0] wd_4,

    output lrf_data [1:0] forward_reg1_data,
    output lrf_data [1:0] forward_reg2_data
);
/*
always_comb begin
    genvar i; //way_no
    generate
        for (i = 0; i < `ISSUE_NUM; i++) begin
            forward_reg_data1[i] = (|reg1[i].addr && reg1[i].addr == wd_0[1].addr) ? wd_0[1].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_0[0].addr) ? wd_0[0].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_1[1].addr) ? wd_1[1].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_1[0].addr) ? wd_1[0].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_2[1].addr) ? wd_2[1].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_2[0].addr) ? wd_2[0].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_3[1].addr) ? wd_3[1].data : 
                                   (|reg1[i].addr && reg1[i].addr == wd_3[0].addr) ? wd_3[0].data : 
                                   reg1.data;
            forward_reg_data2[i] = (|reg2[i].addr && reg2[i].addr == wd_0[1].addr) ? wd_0[1].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_0[0].addr) ? wd_0[0].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_1[1].addr) ? wd_1[1].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_1[0].addr) ? wd_1[0].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_2[1].addr) ? wd_2[1].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_2[0].addr) ? wd_2[0].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_3[1].addr) ? wd_3[1].data : 
                                   (|reg2[i].addr && reg2[i].addr == wd_3[0].addr) ? wd_3[0].data : 
                                   reg2.data;
        end
    endgenerate
end*/
wr_reg_info [1:0] wd[`EXEC_CLASS_NUM - 1:0];
assign wd[0] = wd_0;
assign wd[1] = wd_1;
assign wd[2] = wd_2;
assign wd[3] = wd_3;
assign wd[4] = wd_4;
logic [31:0] reg1_tmp[2 * `EXEC_CLASS_NUM + 1:0];
logic [31:0] reg2_tmp[2 * `EXEC_CLASS_NUM + 1:0];
assign forward_reg1_data[0] = reg1_tmp[0];
assign forward_reg1_data[1] = reg1_tmp[`EXEC_CLASS_NUM + 1];
assign forward_reg2_data[0] = reg2_tmp[0];
assign forward_reg2_data[1] = reg2_tmp[`EXEC_CLASS_NUM + 1];
assign reg1_tmp[`EXEC_CLASS_NUM] = reg1_data[0];
assign reg1_tmp[2 * `EXEC_CLASS_NUM + 1] = reg1_data[1];
assign reg2_tmp[`EXEC_CLASS_NUM] = reg2_data[0];
assign reg2_tmp[2 * `EXEC_CLASS_NUM + 1] = reg2_data[1];
generate
    for (genvar i = `EXEC_CLASS_NUM - 1; i >= 0; --i) begin
        for (genvar j = 0; j < `ISSUE_NUM; ++j) begin
            assign reg1_tmp[j * (`EXEC_CLASS_NUM + 1) + i] = (~reg1[j].src && |reg1[j].addr && reg1[j].addr == wd[i][1].addr) ? wd[i][1].data : 
                                        (~reg1[j].src && |reg1[j].addr && reg1[j].addr == wd[i][0].addr) ? wd[i][0].data : 
                                        reg1_tmp[j * (`EXEC_CLASS_NUM + 1) + i + 1];
            assign reg2_tmp[j * (`EXEC_CLASS_NUM + 1) + i] = (~reg2[j].src && |reg2[j].addr && reg2[j].addr == wd[i][1].addr) ? wd[i][1].data : 
                                        (~reg2[j].src && |reg2[j].addr && reg2[j].addr == wd[i][0].addr) ? wd[i][0].data : 
                                        reg2_tmp[j * (`EXEC_CLASS_NUM + 1) + i + 1];
        end
    end
endgenerate
endmodule