`ifndef _Instr_H_
`define _Instr_H_

//for func and perf test, close this macro
`define EXTEND_INST_SET

//OpCode
`define SPECIAL 6'b000000

`define RT 6'd1
`define j 6'd2
`define jal 6'd3
`define beq 6'd4
`define bne 6'd5
`define blez 6'd6
`define bgtz 6'd7

`define addi 6'd8
`define addiu 6'd9
`define slti 6'd10
`define sltiu 6'd11
`define andi 6'd12
`define ori 6'd13
`define xori 6'd14
`define lui 6'd15

`define RS 6'd16

`define SPECIAL2 6'b011100

`define lb 6'd32
`define lh 6'd33
`define lwl 6'd34
`define lw 6'd35
`define lbu 6'd36
`define lhu 6'd37
`define lwr 6'd38

`define sb 6'd40
`define sh 6'd41
`define swl 6'd42
`define sw 6'd43
`define swr 6'd46
`define cache 6'b101111
`define ll 6'd48
`define pref 6'd51
`define sc 6'd56
//SPECIAL
`define nop 6'b000000
`define sll 6'd0
`define srl 6'd2
`define sra 6'd3
`define sllv 6'd4
`define srlv 6'd6
`define srav 6'd7

`define jr 6'd8
`define jalr 6'd9
`define movz 6'd10
`define movn 6'd11
`define syscall 6'd12
`define break 6'd13
`define sync 6'd15
`define mfhi 6'd16
`define mthi 6'd17
`define mflo 6'd18
`define mtlo 6'd19
`define beql 6'b010100
`define bnel 6'b010101
`define blezl 6'b010110
`define bgtzl 6'b010111
`define mult 6'd24
`define multu 6'd25
`define div 6'd26
`define divu 6'd27

`define add 6'd32
`define addu 6'd33
`define sub 6'd34
`define subu 6'd35
`define and 6'd36
`define or 6'd37
`define xor 6'd38
`define nor 6'd39
`define slt 6'd42
`define sltu 6'd43

`define tge     6'b110000
`define tgeu    6'b110001
`define tlt     6'b110010
`define tltu    6'b110011
`define teq     6'b110100
`define tne     6'b110110

//RT
`define bltz    5'd0
`define bgez    5'd1
`define bltzl   5'b00010
`define bgezl   5'b00011
`define tgei    5'b01000
`define tgeiu   5'b01001
`define tlti    5'b01010
`define tltiu   5'b01011
`define teqi    5'b01100
`define tnei    5'b01110
`define bltzal 5'd16
`define bgezal 5'd17
`define bltzall 5'd18
`define bgezall 5'd19

//RS
`define mfc0 5'd0
`define mtc0 5'd4
`define cop0 6'd16

//cop0
`define tlbr 6'd1
`define tlbwi 6'd2
`define tlbwr 6'd6
`define tlbp 6'd8
`define eret 6'd24
`define wait 6'd32

//SPECIAL2
`define madd    6'b000000
`define maddu   6'b000001
`define mul     6'b000010
`define msub    6'b000100
`define msubu   6'b000101
`define clz     6'b100000
`define clo     6'b100001

//ALUOp
`define ADD 4'b0000
`define SUB 4'b0001
`define AND 4'b0010
`define OR 4'b0011
`define SLT 4'b0100
`define SLTU 4'b0101
`define XOR 4'b0110
`define NOR 4'b0111
`define LL 4'b1000
`define RA 4'b1001
`define RL 4'b1010
`define LUI 4'b1011
`define CLZ 4'b1100
`define CLO 4'b1101
`define MOVZ  4'b1110
`define MOVN  4'b1111

//MultDivOp
`define MULT 0
`define MULTU 1
`define DIV 2
`define DIVU 3
`define MFHI 4
`define MTHI 5
`define MFLO 6
`define MTLO 7
`define MADD 8
`define MADDU 9
`define MSUB 10
`define MSUBU 11
`define MUL 12

`define hi 33
`define lo 34
//BRUOp
`define pc4_bru 0
`define beq_bru 1
`define bne_bru 2
`define j_bru 3
`define jr_bru 4
`define eret_bru 5
`define blez_bru 6
`define bgtz_bru 7
`define bltz_bru 8
`define bgez_bru 9
`define bltzal_bru 10
`define bgezal_bru 11
/*
//接口�??
//EXTOp
`define Unsigned 0
`define Signed 1
`define HighPlace 2

//MPCmux
`define ADD4 0
`define NPC 1

//SrcAmux
`define V1 0
`define s 1

//SrcBmux
`define V2 0
`define extImm_E 1

//MemRd
`define Word 0
`define Hword 1
`define Byte 2
`define HwordU 3
`define ByteU 4

//MRegA
`define rd 0
`define rt 1
`define ra 2

//MRegWD
`define Addr 0
`define DM_RD 1
`define extImm_W 2
`define PC8 3

//使能信号效果比较显然，不单独定义�??
*/
//ExcCode
`define Int 5'd0
`define TLBMod 5'd1
`define TLBL 5'd2
`define TLBS 5'd3
`define AdEL 5'd4
`define AdES 5'd5
`define Syscall 5'd8
`define Bp 5'd9
`define RI 5'd10
`define Ov 5'd12
`define Tr 5'd13

//TLBOp
`define TLB_None 0
`define TLB_Probe 1
`define TLB_Read 2
`define TLB_WI 3
`define TLB_WR 4

//
`define RESET_HANDLER 32'hbfc00000

`endif