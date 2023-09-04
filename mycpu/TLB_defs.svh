`ifndef _TLB_H_
`define _TLB_H_
typedef struct packed {
    logic [11:0] mask;
    logic [18:0] vpn2;
    logic [7 :0] asid;
    logic        G   ;
    logic [19:0] pfn0;
    logic [19:0] pfn1;
    logic [2 :0] c0  ;
    logic [2 :0] c1  ;
    logic        d0  ;
    logic        d1  ;
    logic        v0  ;
    logic        v1  ;
} TLB_Line;

typedef struct packed {
    logic [31:0] vaddr;    // 虚拟地址输入
    logic        ce   ;    // 是否�?要翻译，1为需�?
} TLB_Search_In;

typedef struct packed {
    logic [31:0] va_out;   // 返回的原来的虚拟地址，不知道具体作用，学长代码里�?
    logic [31:0] paddr;    // 翻译的物理地�?
    logic hit;             // 是否命中�?1为命�?
    logic v;               // 是否有效�?1为有�?
    logic d;               // 脏位�?1为修�?
    logic cached;          // Cache属�??
    logic error;           // 访问地址是否错误，比如用户�?�访问内核地�?�?1为错�?
} TLB_Search_Out;
`endif