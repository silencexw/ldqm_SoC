`timescale 1ns / 1ps
/* this prefetcher is mainly about a state machine, 
 */

module Prefetcher #(
    parameter LINE_WIDTH = 256,
    parameter OFFSET = (LINE_WIDTH / 32) * 4
) (
    input logic clk,
    input logic reset,

    input logic ms_valid,
    input logic [31:0] ms_addr,
    
    input logic rq_valid,
    input logic [31:0] rq_addr,

    output logic pf_valid,
    output logic [31:0] pf_addr,

    input logic pf_answer
);

    // the state machine
    logic [2:0] pf_state, pf_next_state;
    localparam logic [2:0] S_PF_IDLE  = 3'b000;
    localparam logic [2:0] S_PF_MISS  = 3'b001;
    localparam logic [2:0] S_PF_FETCH = 3'b010;
    localparam logic [2:0] S_PF_REST  = 3'b011;
    always_ff @(posedge clk) begin
        if (reset) pf_state <= S_PF_IDLE;
        else pf_state <= pf_next_state;
    end

    // miss history registor
    logic [31:0] last_miss_addr;
    logic [31:0] fetch_addr;

    always_comb begin
        pf_next_state = pf_state;
        case (pf_state)
            S_PF_IDLE: begin
                if (ms_valid) begin
                    pf_next_state = S_PF_MISS;
                end
            end
            S_PF_MISS: begin
                if (ms_valid && ms_addr == last_miss_addr + OFFSET) begin
                    pf_next_state = S_PF_FETCH;
                end
            end
            S_PF_FETCH: begin
                if (ms_valid && ms_addr != fetch_addr) begin
                    pf_next_state = S_PF_MISS;
                end
                else if (pf_answer) begin
                    pf_next_state = S_PF_REST;
                end
            end
            S_PF_REST: begin
                if (rq_valid && rq_addr == fetch_addr) begin
                    pf_next_state = S_PF_FETCH;
                end
                else if (ms_valid) begin
                    pf_next_state = S_PF_MISS;
                end
            end
        endcase
    end

    // miss history
    always_ff @(posedge clk) begin
        if (pf_state == S_PF_IDLE && pf_next_state == S_PF_MISS) begin
            last_miss_addr <= ms_addr;
        end
        else if (pf_state == S_PF_MISS && pf_next_state == S_PF_MISS && ms_valid) begin
            last_miss_addr <= ms_addr;
        end
        else if (pf_state == S_PF_FETCH && pf_next_state == S_PF_MISS) begin
            last_miss_addr <= ms_addr;
        end
        else if (pf_state == S_PF_REST && pf_next_state == S_PF_MISS) begin
            last_miss_addr <= ms_addr;
        end
    end

    always_ff @(posedge clk) begin
        if (pf_state == S_PF_MISS && pf_next_state == S_PF_FETCH) begin
            fetch_addr <= ms_addr + OFFSET;
        end
        else if (pf_state == S_PF_FETCH && ms_valid && ms_addr == fetch_addr) begin
            fetch_addr <= fetch_addr + OFFSET;
        end
        else if (pf_state == S_PF_FETCH && rq_valid && rq_addr == fetch_addr) begin
            fetch_addr <= fetch_addr + OFFSET;
        end
        else if (pf_state == S_PF_REST && rq_valid && rq_addr == fetch_addr) begin
            fetch_addr <= fetch_addr + OFFSET;
        end
    end

    // fetch signals
    assign pf_valid = (pf_state == S_PF_FETCH /*|| pf_next_state == S_PF_FETCH*/);
    assign pf_addr  = /*(pf_state == S_PF_MISS && pf_next_state == S_PF_FETCH) ? ms_addr + 32'h00000020 :
                      (pf_state == S_PF_REST && pf_next_state == S_PF_FETCH) ? rq_addr + 32'h00000020 :*/
                      (pf_state == S_PF_FETCH && rq_valid && rq_addr == fetch_addr) ? fetch_addr + OFFSET : fetch_addr;

endmodule