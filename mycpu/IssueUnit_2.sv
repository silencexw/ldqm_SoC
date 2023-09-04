`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/16 21:23:32
// Design Name: 
// Module Name: IssueUnit_2
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
`define IQ_LENGTH 8

module IssueUnit_2(
    input clk,
    input flush,
    input stall,

    output  logic       allowin_I,
    input   logic [1:0]  valid_D,

    input   instr_info [1:0]    instr_D,
    output  instr_info          instr0_I,
    output  logic               way0_valid,
    output  instr_info          instr1_I,
    output  logic               way1_valid,
    output  lrf_data [1:0]      reg_data1,
    output  lrf_data [1:0]      reg_data2,

    // read Logic Register File
    output  logic       [5:0]   rd_reg1_addr0,
    input   logic       [31:0]  rd_reg1_data0,
    output  logic       [5:0]   rd_reg2_addr0,
    input   logic       [31:0]  rd_reg2_data0, 

    output  logic       [5:0]   rd_reg1_addr1,
    input   logic       [31:0]  rd_reg1_data1,
    output  logic       [5:0]   rd_reg2_addr1,
    input   logic       [31:0]  rd_reg2_data1, 

    // receive bypassing
    output wr_reg_info [1:0] wd_ori,
    input wr_reg_info [1:0] wd_0,
    input wr_reg_info [1:0] wd_1,
    input wr_reg_info [1:0] wd_2,
    input wr_reg_info [1:0] wd_3,
    input wr_reg_info [1:0] wd_4
    );

issue_entry issue_queue [`IQ_LENGTH - 1 : 0];
issue_entry issue_queue_nxt [`IQ_LENGTH - 1 : 0];
logic [$clog2(`IQ_LENGTH + 1) - 1 : 0] tail;
logic [$clog2(`IQ_LENGTH + 1) - 1 : 0] head;
logic [$clog2(`IQ_LENGTH + 1) - 1 : 0] size;
//wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] write_ptr;
wire [1: 0] ready; //for invalid entry, always set 0
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] issue_instr_num;
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] req_instr_num;
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] enter_instr_num;
assign issue_instr_num =
 way1_valid && way0_valid ? 2 : 
                          way0_valid ? 1 : 0;
assign req_instr_num = valid_D[1] && valid_D[0] ? 2 : 
                        valid_D[0] ? 1 : 0;
assign enter_instr_num = allowin_I ? req_instr_num : 0;
//assign write_ptr = tail - issue_instr_num;
//assign allowin_I = (size + req_instr_num > `IQ_LENGTH) ? 1'b0 : 1'b1;
assign allowin_I = (size + 2 > `IQ_LENGTH) ? 1'b0 : 1'b1;

integer i;
always_ff @( posedge clk ) begin
    if (flush) begin
        for (i = 0; i < `IQ_LENGTH; i = i + 1) begin
            issue_queue[i] <= '0;
        end
        tail <= 0;
        head <= 0;
        size <= 0;
    end
    else begin
        issue_queue <= issue_queue_nxt;
        tail <= tail + enter_instr_num >= `IQ_LENGTH ? tail + enter_instr_num - `IQ_LENGTH : 
                tail + enter_instr_num;
        head <= head + issue_instr_num >= `IQ_LENGTH ? head + issue_instr_num - `IQ_LENGTH : 
                head + issue_instr_num;
        size <= size + enter_instr_num - issue_instr_num;
    end
end

issue_entry [1:0] enter_entry;
wire way0_stop, way1_stop;
assign enter_entry[0].instr = instr_D[0];
assign enter_entry[0].valid = instr_D[0].valid & valid_D[0];
assign enter_entry[1].instr = instr_D[1];
assign enter_entry[1].valid = instr_D[1].valid & valid_D[1];
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] head0;
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] head1;
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] tail0;
wire [$clog2(`IQ_LENGTH + 1) - 1 : 0] tail1;
assign tail0 = tail;
assign tail1 = (tail + 1 >= `IQ_LENGTH) ? '0 : tail + 1;
generate 
    for (genvar j = 0; j < `IQ_LENGTH; j = j + 1) begin
        assign issue_queue_nxt[j] = (j == tail0 && |enter_instr_num[1:0]) ? enter_entry[0] : 
                                     (j == tail1 && enter_instr_num[1]) ? enter_entry[1] : 
                                     (j == head0 && |issue_instr_num[1:0]) ? '0 : 
                                     (j == head1 && issue_instr_num[1]) ? '0 : 
                                     issue_queue[j];
    end
endgenerate

// haven't completed yet
// IssueWaken module ensures that if ready is set, this instr will be accept by correspond function unit
issue_entry [1:0] queue_head;
issue_entry [`IQ_LENGTH : 0] tmp0;
issue_entry [`IQ_LENGTH : 0] tmp1;
generate
    assign head0 = head;
    assign head1 = (head + 1 >= `IQ_LENGTH) ? '0 : head + 1;
    assign tmp0[`IQ_LENGTH] = '0;
    assign tmp1[`IQ_LENGTH] = '0;
    for (genvar k = `IQ_LENGTH - 1; k >= 0; --k) begin
        assign tmp0[k] = (k == head0) ? issue_queue[k] : tmp0[k + 1];
        assign tmp1[k] = (k == head1) ? issue_queue[k] : tmp1[k + 1]; 
    end
    assign queue_head[0] = tmp0[0];
    assign queue_head[1] = tmp1[0];
endgenerate
                        
wire both_acc_mem = queue_head[0].valid && queue_head[1].valid && 
                    queue_head[0].instr.is_accmem && queue_head[0].instr.is_accmem;
assign way0_stop = queue_head[0].instr.valid && queue_head[0].instr.is_branch && !queue_head[1].instr.valid;
assign way1_stop = way0_stop || queue_head[1].valid && queue_head[1].instr.is_branch && !(queue_head[0].valid && queue_head[0].instr.is_branch) || 
                 queue_head[0].instr.valid && queue_head[0].instr.is_accmem && queue_head[1].instr.valid && queue_head[1].instr.is_accmem ||
                 //queue_head[0].instr.valid && queue_head[0].instr.is_accmem && queue_head[1].instr.valid && queue_head[1].instr.is_md ||
                 queue_head[0].instr.valid && queue_head[0].instr.is_md && queue_head[1].instr.valid && queue_head[1].instr.is_md || 
                 //queue_head[0].instr.valid && queue_head[0].instr.alu_ctrl.check_ov && queue_head[1].instr.valid && queue_head[1].instr.is_md || 
                 queue_head[0].instr.valid && queue_head[0].instr.is_priv && queue_head[1].instr.valid || 
                 queue_head[1].instr.valid && queue_head[1].instr.is_priv && !(queue_head[0].instr.valid && queue_head[0].instr.is_branch);
wire [1:0] delay_exec;
WakenUnit issuewaken0(
    .instr(queue_head[0].instr),
    .en(queue_head[0].valid && !way0_stop),
    .wd_way0('0),
    .way_no('0),
    
    .wd_0,
    .wd_1,
    .wd_2,
    .wd_3,
    .wd_4,
    
    .delay_exec(delay_exec[0]),
    .ready(ready[0])
);

reg_info wd_way0;
wire way1_after_stall;
always_comb begin
    wd_way0.addr = queue_head[0].instr.rf_ctrl.wr_reg.addr;
    wd_way0.src = queue_head[0].instr.rf_ctrl.wr_reg.src;
end
WakenUnit issuewaken1(
    .instr(queue_head[1].instr),
    .en(queue_head[1].valid && !way1_stop),
    .way_no(1'b1),
    .wd_way0(wd_ori[0]),
    
    .wd_0,
    .wd_1,
    .wd_2,
    .wd_3,
    .wd_4,

    .delay_exec(delay_exec[1]),
    .ready(ready[1])
);

//issue
assign instr0_I = queue_head[0].instr;
assign way0_valid = instr0_I.is_branch && ~way1_valid ? '0 : ready[0] && !stall;
assign instr1_I = queue_head[1].instr;
assign way1_valid = ready[1] && ready[0] && !stall;

//read logic register file
assign rd_reg1_addr0 = instr0_I.valid && !instr0_I.rf_ctrl.rd_reg1.src ? instr0_I.rf_ctrl.rd_reg1.addr : 0;
assign rd_reg2_addr0 = instr0_I.valid && !instr0_I.rf_ctrl.rd_reg2.src ? instr0_I.rf_ctrl.rd_reg2.addr : 0;
assign rd_reg1_addr1 = instr1_I.valid && !instr1_I.rf_ctrl.rd_reg1.src ? instr1_I.rf_ctrl.rd_reg1.addr : 0;
assign rd_reg2_addr1 = instr1_I.valid && !instr1_I.rf_ctrl.rd_reg2.src ? instr1_I.rf_ctrl.rd_reg2.addr : 0;


Forward_ISSUE forward_issue(
    .reg1({queue_head[1].instr.rf_ctrl.rd_reg1, queue_head[0].instr.rf_ctrl.rd_reg1}),
    .reg2({queue_head[1].instr.rf_ctrl.rd_reg2, queue_head[0].instr.rf_ctrl.rd_reg2}),
    .reg1_data({rd_reg1_data1, rd_reg1_data0}),
    .reg2_data({rd_reg2_data1, rd_reg2_data0}),

    .wd_0,
    .wd_1,
    .wd_2,
    .wd_3,
    .wd_4,

    .forward_reg1_data(reg_data1),
    .forward_reg2_data(reg_data2)
);

//generate Tnew in order to avoid data relation
generate
    for (genvar k = 0; k < `ISSUE_NUM; ++k) begin
        TnewDecoder Tnew_decoder_issue(
            .instr(queue_head[k].instr),
            .delay_exec(delay_exec[k]),
            .wr_reg_info_ori(wd_ori[k])
        );
    end
endgenerate
endmodule
