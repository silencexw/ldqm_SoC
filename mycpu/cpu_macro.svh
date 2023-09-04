`ifndef _CPU_H_
`define _CPU_H_

`include "Predict_defs.svh"
`define ISSUE_NUM 2
`define EXEC_CLASS_NUM 5
`define _COMMIT_QUEUE
`define _USE_SIMULATOR
`define _USE_XPM_CPC
`define _CLO_CLZ
`define _TRAP_UNIT

`ifdef USE_SIMULATOR
    `ifndef COMMIT_QUEUE
        `define COMMIT_QUEUE
    `endif
`endif

typedef logic [5:0] lrf_addr;
typedef logic [31:0] lrf_data;
typedef logic [31:0] va_addr;
typedef logic [31:0] pa_addr;
typedef logic [31:0] mem_data;
typedef logic [31:0] mem_addr;
/*
typedef struct packed {
    logic valid;
    logic jump;
    logic [31:0] target;
} bp_info;*/

// used in bypassing network
//Tuse enum
typedef struct packed {
    logic src;//0: lrf, 1: cp0
    lrf_addr addr;
} reg_info;
`define NOT_USE 5
`define BRU_USE 0
`define ALU_USE 0
`define MDU_USE 0
`define AGU_USE 0
`define TRAP_USE 1
`define CP0_USE 2
`define MEM_USE 3
`define LRF_USE 4

typedef struct packed {
    lrf_addr addr;   // 'unvalid' = 'write reg 0'
    lrf_data data;
    logic[2:0] Tnew;   //speculative cycles before get value, especially for load instr
} wr_reg_info;
`define NOT_WRITE 0
`define LRF_GEN 0 //for mfxx instr
`define ALU_GEN 1
`define MDU_GEN 1
`define BRU_GEN 1
`define CP0_GEN 3
`define MEM_GEN 4
`define STALL 7

typedef struct packed {
    logic valid;
    logic target;//0: icache, 1: dcache
    logic op;// 0 for index invalidate, 1 for hit invalidate
    logic wb;// 0 for non-writeback, 1 for writeback
} cache_op_t;

typedef struct packed {
    reg_info rd_reg1;
    logic [2:0] Tuse1;
    reg_info rd_reg2;
    logic [2:0] Tuse2;
    reg_info wr_reg;
} rf_ctrl_t;

typedef struct packed {
    logic alu_en;
    logic [3:0] alu_op; //reuse
    logic check_ov;
    logic src_a;//1: s, 0: reg_data
    logic src_b;//0: reg_data, 1: immidiate num
    logic sign_b;
} alu_ctrl_t;

typedef struct packed {
    logic mdu_en;
    logic [3:0] mdu_op; //redesign
    logic multi_cycle; //1�� mul instr, 0: other instr
} mdu_ctrl_t;

typedef struct packed {
    logic       acc_mem; //valid
    logic       wr_mem; //0: read, 1: write
    logic [1:0] size;
    logic       rdata_sign;
    //need new signal for 'swl' ,'swr', 'lwl', 'lwr', 'll', 'sc'
    logic       set_LLbit;
    logic       read_LLbit;

    logic       unalign_left;
    logic       unalign_right;
} mem_ctrl_t;

typedef struct packed {
    logic cp0_en;
    logic wr_cp0;
} cp0_ctrl_t;

typedef struct packed {
    logic trap_en;
    logic src_b; //0: reg_data, 1: extimm32
    logic [2:0] trap_op;
} trap_ctrl_t;
`define EQ_trap 3'd0
`define NE_trap 3'd1
`define GE_trap 3'd2
`define GEU_trap 3'd3
`define LT_trap 3'd4
`define LTU_trap 3'd5

typedef logic [3:0] tlb_ctrl_t;
typedef logic [3:0] bru_ctrl_t;

/*
typedef struct packed {
    logic alu_en;
    logic [3:0] alu_op; //reuse
    logic mdu_en;
    logic [3:0] mdu_op; //redesign
    logic [3:0] bru_op;
    logic [2:0] tlb_op;
    cache_op_t   cache_op;    
} instr_op;
*/

typedef struct packed {
    //mem_data code;
    logic valid;
    logic [5:0] opcode;         // instr[31:26]
    logic [5:0] funct;          // instr[5:0]
    logic [5:0] s;              // instr[10:6]
    logic [15:0] imm;
    logic [31:0] extimm;
    logic [25:0] imm26;

    rf_ctrl_t rf_ctrl;
    mdu_ctrl_t mdu_ctrl;
    bru_ctrl_t bru_ctrl;
    alu_ctrl_t alu_ctrl;
    mem_ctrl_t mem_ctrl;
    cache_op_t cache_op;
    cp0_ctrl_t cp0_ctrl;
    tlb_ctrl_t tlb_ctrl;
    trap_ctrl_t trap_ctrl;

    va_addr pc;
    logic in_delayslot;         //is delay branch instruction
    logic likely_delayslot;
    logic [4:0] exc_code;
    logic       exc_tre;
    logic [31:0] bad_va_addr;

    //instr_op op;                //instr's behavior
    logic is_branch;
    logic is_likely;
    logic is_accmem;
    logic is_cal;
    logic is_md;
    logic wr_md;
    logic is_priv;              //include mfc0, mtc0, eret

    Predict_Branch_S bp_info;   //signals of branch prediction
    logic update_true_pc;
} instr_info;

typedef struct packed {
    logic valid;
    logic [31:0] extimm;
    logic [5:0] s;
    
    rf_ctrl_t   rf_ctrl;
    alu_ctrl_t  alu_ctrl;
    bru_ctrl_t  bru_ctrl;
    mem_ctrl_t  mem_ctrl;
    cache_op_t  cache_op;
    tlb_ctrl_t  tlb_ctrl;
    cp0_ctrl_t  cp0_ctrl;
    trap_ctrl_t trap_ctrl;
    
    va_addr          pc;
    logic           in_delayslot;
    logic [4:0]     exc_code;
    logic           exc_tre;
    logic [31:0]    bad_va_addr;
    
     //instr_op op;                //instr's behavior
    logic is_branch;
    logic is_likely;
    logic is_accmem;
    logic is_cal;
    logic is_md;
    logic wr_md;
    logic is_priv;
} instr_info_at;

function instr_info_at exec2at(input instr_info exec_instr);
    instr_info_at ret;
    ret.valid = exec_instr.valid;
    ret.extimm = exec_instr.extimm;
    ret.s = exec_instr.s;
    ret.rf_ctrl = exec_instr.rf_ctrl;
    ret.alu_ctrl = exec_instr.alu_ctrl;
    ret.bru_ctrl = exec_instr.bru_ctrl;
    ret.mem_ctrl = exec_instr.mem_ctrl;
    ret.cache_op = exec_instr.cache_op;
    ret.tlb_ctrl = exec_instr.tlb_ctrl;
    ret.cp0_ctrl = exec_instr.cp0_ctrl;
    ret.trap_ctrl = exec_instr.trap_ctrl;
    
    ret.pc = exec_instr.pc;
    ret.in_delayslot = exec_instr.in_delayslot;
    ret.exc_code = exec_instr.exc_code;
    ret.exc_tre = exec_instr.exc_tre;
    ret.bad_va_addr = exec_instr.bad_va_addr;
    
    ret.is_branch = exec_instr.is_branch;
    ret.is_likely = exec_instr.is_likely;
    ret.is_accmem = exec_instr.is_accmem;
    ret.is_cal = exec_instr.is_cal;
    ret.is_md = exec_instr.is_md;
    ret.wr_md = exec_instr.wr_md;
    ret.is_priv = exec_instr.is_priv;
    
    return ret;
endfunction

typedef struct packed {
    logic valid;
    logic [31:0] extimm;
    logic [5:0] s;
    
    rf_ctrl_t   rf_ctrl;
    alu_ctrl_t  alu_ctrl;
    bru_ctrl_t  bru_ctrl;
    mem_ctrl_t  mem_ctrl;
    cache_op_t  cache_op;
    tlb_ctrl_t  tlb_ctrl;
    cp0_ctrl_t  cp0_ctrl;
    trap_ctrl_t trap_ctrl;
    
    va_addr          pc;
    logic           in_delayslot;
    logic [4:0]     exc_code;
    logic           exc_tre;
    logic [31:0]    bad_va_addr;
    
     //instr_op op;                //instr's behavior
    logic is_branch;
    logic is_likely;
    logic is_accmem;
    logic is_cal;
    logic is_md;
    logic wr_md;
    logic is_priv;
} instr_info_dreq;

function instr_info_dreq at2dreq(input instr_info_at at_instr);
    return at_instr;
endfunction

typedef struct packed {
    logic valid;
    logic [31:0] extimm;
    logic [5:0] s;
    rf_ctrl_t   rf_ctrl;
    alu_ctrl_t  alu_ctrl;
    mem_ctrl_t  mem_ctrl;
    cache_op_t  cache_op;
    va_addr     pc;
    logic is_accmem;
} instr_info_mem;

function instr_info_mem dreq2mem(input instr_info_dreq dreq_instr);
    instr_info_mem ret;
    ret.valid = dreq_instr.valid;
    ret.extimm = dreq_instr.extimm;
    ret.s = dreq_instr.s;
    ret.rf_ctrl = dreq_instr.rf_ctrl;
    ret.alu_ctrl = dreq_instr.alu_ctrl;
    ret.mem_ctrl = dreq_instr.mem_ctrl;
    ret.cache_op = dreq_instr.cache_op;
    ret.pc = dreq_instr.pc;
    ret.is_accmem = dreq_instr.is_accmem;

    return ret;
endfunction

typedef struct packed {
    logic valid;
    va_addr     pc;
} instr_info_wb;

function instr_info_wb mem2wb(input instr_info_mem mem_instr);
    instr_info_wb ret;
    ret.valid = mem_instr.valid;
    ret.pc = mem_instr.pc;
    return ret;
endfunction

// issue queue
typedef struct packed {
    instr_info instr;
    logic valid;
} issue_entry;

//FU macro
//BRU, infomation which sent from bru, to bvu
typedef struct packed {
    logic valid;
    va_addr pc;
    //logic [1:0] branch_type; //0: non-jump, 1: non-delayslot jump, 2: delayslot jump 
    BranchType_E branch_type;
    Predict_Branch_S bp_info;

    va_addr true_pc;
    logic true_branch;//0: not jump, 1: jump
    
    logic update_true_pc;
} bru_info;

//BVU
typedef struct packed {
    va_addr true_pc;
    va_addr instr_pc;
    logic true_branch;
    logic true_able;
} bp_verify_info;

`ifdef USE_SIMULATOR
typedef struct packed {
    logic [31:0] cp0_count;
    logic [31:0] cp0_random;
    logic [31:0] cp0_cause;
    logic cp0_int;
} cp0_info;
`endif
//
typedef struct packed {
`ifdef USE_SIMULATOR
    logic valid;
    cp0_info debug_cp0_info;
`endif
    logic [31:0] pc;
    logic [3:0] wen;
    logic [4:0] wnum;
    logic [31:0] wdata;
} wb_info;

`endif
