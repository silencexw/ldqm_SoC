`ifndef _Predict_H_
`define _Predict_H_
typedef logic[31:0] Vaddr;
typedef logic[1: 0] TwoBitState;
typedef logic[11:0] Hash_12;
typedef logic[10:0] Hash_11;
typedef logic[9: 0] Hash_10;
typedef logic[5: 0] Hash_6;
typedef logic[6: 0] Hash_7;
typedef logic[2: 0] BranchHistoryReg;
typedef logic[5: 0] GlobalHistoryReg;

typedef enum logic [2:0] {
	None,
	Jump,
	Branch,
	Call,
	Return
} BranchType_E;

typedef struct packed {
    logic PC_Vaild; //Are we recognize this instruction as a Branch Inst?
    logic PC_Taken; //Are we change the controlflow? 1:Change 0:No
    logic PC_MissPredict; //Are we mispredict? 1:MISS 0:No
    logic Update_Location; //Branch in Which Location 1 or 2 ?
    TwoBitState TBT_Counter;
    TwoBitState GHR_Counter;
    Vaddr Update_PC; //Instruction address (Don't Modify)
    Vaddr Update_Target; //Controlflow target address
    Vaddr Predict_Target; //My Predict Target
    logic Predict_Location; //My Predict Location
    BranchType_E BranchType; //What type for this Branch Inst
    BranchType_E Predict_BranchType; //My Predict BranchType;
    GlobalHistoryReg Recover_GHR; // 6-bit New to add
    GlobalHistoryReg GHR; // 6-bit New to add
    TwoBitState CPHT;
    logic Update_True_PC;
} Update_Branch_S;

typedef struct packed {
    logic PC_Vaild; // I think it is a Branch Inst
    Vaddr Target; // I think it Will Branch to This Place
    BranchType_E BranchType; // Current type for this Branch Inst
    TwoBitState TBT_Counter;
    TwoBitState GHR_Counter;
    logic Location;
    GlobalHistoryReg Recover_GHR;
    GlobalHistoryReg GHR;
    TwoBitState CPHT;
} Predict_Branch_S;

typedef struct packed {
    logic PC_Vaild;
    logic PC_Taken;
    logic PC_MissPredict;
    TwoBitState TBT_Counter;
    TwoBitState GHR_Counter;
    Vaddr Update_PC;
    GlobalHistoryReg Recover_GHR;
    GlobalHistoryReg GHR;
    TwoBitState CPHT;
} Update_PHT_S;

typedef struct packed {
    logic PC_Vaild;
    logic PC_Taken;
    logic PC_MissPredict;
    Vaddr Update_PC;
    Vaddr Update_Target;
    BranchType_E BranchType;
    logic Update_Location;
} Update_BTB_S;

typedef struct packed {
    Vaddr Delay_PC;
    Vaddr Target;
    BranchType_E BranchType;
    logic Predict_Location;
} Predict_BTB_S;

typedef struct packed {
    TwoBitState TBT_Counter;
    TwoBitState GHR_Counter;
    GlobalHistoryReg Recover_GHR;
    GlobalHistoryReg GHR;
    TwoBitState CPHT;
} Predict_PHT_S;

typedef struct packed {
    logic [8:0] XorTag;
    Vaddr PC;
    BranchType_E BranchType;
    logic Location; 
} BTB_Table_Entry_S;

typedef struct packed {
    logic Vaild;
    Vaddr PC;
} Ras;

typedef struct packed {
    TwoBitState Counter;
    Vaddr PC;
    Vaddr Target;
    BranchType_E BranchType;
    logic Way_Select;
    logic Location;
} Recover_Mem_S;


typedef struct packed {
    TwoBitState Predict_Counter;
} Predict_TBT_S;


typedef struct packed {
    logic PC_Vaild;
    logic PC_Taken;
    TwoBitState Counter;
    Vaddr Update_PC;
} Update_TBT_S;


typedef struct packed {
    TwoBitState Predict_Counter;
    GlobalHistoryReg Recover_GHR;
    GlobalHistoryReg GHR;
} Predict_GHR_S;


typedef struct packed {
    logic PC_Vaild;
    logic PC_Taken;
    logic PC_MissPredict;
    logic GHR_MissPredict;
    TwoBitState Counter;
    Vaddr Update_PC;
    GlobalHistoryReg Recover_GHR;
    GlobalHistoryReg GHR;
} Update_GHR_S;


typedef struct packed {
    logic Vaild;
    Vaddr Target;
} Recover_Decode_S;

`endif