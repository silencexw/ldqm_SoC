`timescale 1ns / 1ps
/* valid 信号时机：在只考虑cache的读写指令情况下，不区分读写访问，只有hit和miss两种情况
 * 在请求进入m1后的第一个周期判断出命中，此时valid应置高，ask_way = hit_way; 若此时判断
 * 为miss，valid信号应该在bus_state == refill时置高，ask_way = way_to_replace。
 * 这样做的一点点误差：在读重填数据时，如果有对同index的命中请求，会先记录这个后来的请求，那个miss的请求在refill时才会被记录。
 */

module PLRU #(
    parameter SET_SIZE = 4,
    parameter GROUP_NUM = 128,
    parameter WAY_WIDTH = $clog2(SET_SIZE),
    parameter INDEX_WIDTH = $clog2(GROUP_NUM),
    parameter type index_t  = logic [INDEX_WIDTH -1:0],
    parameter type way_t = logic [WAY_WIDTH -1:0],
    parameter type rec_t = logic [SET_SIZE - 1:0]
) (
    input logic clk,
    input logic reset,
    input logic valid, 
    input index_t index,
    input way_t ask_way,
    output way_t lru_way
);

    if (SET_SIZE == 2) begin
        rec_t record[GROUP_NUM - 1:0]; // 记录每一组，哪一路，最近被访问，1表示左侧即第0路最近被访问，0 versa
        always_ff @(posedge clk) begin
            /*if (reset) begin
                for (int i = 0;i < GROUP_NUM;++i) begin
                    record[i] <= 0;
                end
            end
            else */if (valid) begin
                // if (ask_way == 0) begin
                //     record[index] <= 1;
                // end
                // else begin
                //     record[index] <= 0;
                // end
                record[index] <= ~ask_way;
            end
        end
        assign lru_way = record[index];
    end
    else if (SET_SIZE == 4) begin
        rec_t record[GROUP_NUM - 1:0]; // 第0位为1，way0, way1最近被访问，第1位为1，way0最近被访问，第2位为1，way2最近被访问
        always_ff @(posedge clk) begin
            /*if (reset) begin
                for (int i = 0;i < GROUP_NUM;++i) begin
                    record[i] <= 0;
                end
            end
            else */if (valid) begin
                // if (ask_way == 0) begin
                //     record[index][0] <= 1;
                //     record[index][1] <= 1;
                // end
                // else if (ask_way == 2'b01) begin
                //     record[index][0] <= 1;
                //     record[index][1] <= 0;
                // end
                // else if (ask_way == 2'b10) begin
                //     record[index][0] <= 0;
                //     record[index][2] <= 1;
                // end
                // else if (ask_way == 2'b11) begin
                //     record[index][0] <= 0;
                //     record[index][2] <= 0;
                // end
                record[index][0] <= ~ask_way[1];
                record[index][1] <= (ask_way[1]) ? record[index][1] : ~ask_way[0];
                record[index][2] <= (ask_way[1]) ? ~ask_way[0] : record[index][1];
            end
        end
        assign lru_way = record[index][0] == 1'b1 ? {record[index][0], record[index][2]} : {record[index][0], record[index][1]};
    end
    
endmodule