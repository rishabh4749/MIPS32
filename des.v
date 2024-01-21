`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.01.2024 19:22:46
// Design Name: 
// Module Name: des
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


//Header where all the registers of the pipeline are being declared.
module des (clk1,clk2);

input clk1,clk2;       //two clocks

//IF(Instruction Fetch) stage
reg [31:0] PC,IF_ID_IR,IF_ID_NPC; 

 //ID(Instruction Decode) stage   
reg [31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_Imm; 

// Type of instructions
reg [2:0] ID_EX_type,EX_MEM_type,MEM_WB_type;

//MEM stage
reg [31:0] EX_MEM_IR,EX_MEM_ALUOut,EX_MEM_B; 

//Required for JUMP or branch condition checking.
reg EX_MEM_cond;  


reg [31:0] MEM_WB_IR,MEM_WB_ALUOut,MEM_WB_LMD;

//Register Bank
reg [31:0] Reg[0:31]; 

//Memory
reg [31:0] Mem[0:1023];

//Only instructions that can access memory are load and store instructions

//Other instructions will have to first load the data into the CPU registers from the memory in order to access it.

parameter 

//OPCODES for instructions to be decoded in the ID stage

//Register Type Instructions
ADD=6'b000000,SUB=6'b000001,AND=6'b000010,OR=6'b000011,SLT=6'b000100,MUL=6'b000101,HLT=6'b111111,

//I Type Instructions (Immediate Instructions)
LW=6'b001000,SW=6'b001001,ADDI=6'b001010,SUBI=6'b001011,SLTI=6'b001100,BNEQZ=6'b001101,BEQZ=6'b001110;

//No flag registers are there in MIPS32 RISC

//Code for the type of instructions
parameter RR_ALU=3'b000,RM_ALU=3'b001,LOAD=3'b010,STORE=3'b011,BRANCH=3'b100,HALT=3'b101;

//Set after HLT instruction is completed.
reg HALTED; 

//Say i+2'th instruction turns out to be a halt instruction the processor wont stop till the i+2 instruction finishes WB stage but during that time no new instructions after i+2 will finish execution i.e. WB stage hence WB is disabled when HALTED is 1.
//Required to disable instructions after branch.
reg TAKEN_BRANCH;


//IF Stage


always @ (posedge clk1)

//HALTED needs to be zero for further execution because if HALTED is already 1 then there should not be any further fetching of instructions.
if(HALTED == 0)

begin

    //There would be a feedback from the EX stage that would tell the IF whether or not the previous instruction is a branch instruction along with the information about its condition.
    if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_cond == 1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
    
    begin
    
        //The destination of branch instruction is known only after EX stage and is stored in the EX_MEM_ALUOut.
        IF_ID_IR <= #2 Mem[EX_MEM_ALUOut]; 
        
        //Since we are actually taking the branch we need to set the taken branch register to 1
        TAKEN_BRANCH <= #2 1'b1;
        
        //Next address calculation.
        IF_ID_NPC <= #2 EX_MEM_ALUOut + 1; 
        
        //Assigning of the nest address to the program counter
        PC <= #2 EX_MEM_ALUOut + 1;
        
    end

    //Case when branch is not taken.
    else

    begin
        
        //Fetching of instructions from the PC
        IF_ID_IR <= #2 Mem[PC];
        
        //Updating the values of PC and NPC
        IF_ID_NPC <= #2 PC+1;
        PC <= #2 PC+1;         
    end

end


//ID Stage


always @ (posedge clk2)
if (HALTED == 0)

begin

    //Loading of first operand
    if(IF_ID_IR[25:21]==5'b00000)
    ID_EX_A <= 0;
    else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]];
    
    //Loading of second operand
    if(IF_ID_IR[20:16]==5'b00000)
    ID_EX_B<=0;
    else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]]; 

    ID_EX_NPC <= #2 IF_ID_NPC;
    ID_EX_IR <= #2 IF_ID_IR;
    
    // First 16 bits are the sign extension of the immediate value while the last 16 bits actually represent the offset value
    //Sign extension is needed because instructions are of 32 bits in MIPS 32
    ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}}; 

    //Type of instructions being decoded
    case (IF_ID_IR[31:26])
    
    //Depending on the op-code the instructions are categorised in different types
   
    ADD,SUB,AND,OR,SLT,MUL: ID_EX_type <= #2 RR_ALU;
    ADDI,SUBI,SLTI: ID_EX_type <= #2 RM_ALU;
    LW: ID_EX_type <= #2 LOAD;
    SW: ID_EX_type <= #2 STORE;
    BNEQZ,BEQZ: ID_EX_type <= #2 BRANCH;
    HLT: ID_EX_type <= #2 HALT;
    
    //In case the provided opcode is not valid
    default: ID_EX_type <= #2 HALT;
    
endcase

end


//EX stage


always @ (posedge clk1)
if(HALTED == 0)
begin
    EX_MEM_type <= #2 ID_EX_type;
    EX_MEM_IR <= #2 ID_EX_IR;
    TAKEN_BRANCH <= #2 0;

    case (ID_EX_type)

    //Register-Register ALU i.e. No memory involved.
    RR_ALU: begin 
    
        case (ID_EX_IR[31:26])
        
        //Execution phase depending on the opcode of the instruction
        ADD: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;
        SUB: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;
        AND: EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B;
        OR: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B;
        SLT: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_B;
        MUL: EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B;
        default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
        
    endcase
    
    end

    //Register Memory ALU
    RM_ALU: begin   
    
        //Operations involving the immediate data i.e. I type instructions.
        case(ID_EX_IR[31:26]) 
        
        ADDI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
        SUBI: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm;
        SLTI: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_Imm;
        default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
        
    endcase
    
    end

    LOAD,STORE:
    begin
    
    //Calculation of the memory address to be accessed for LOAD/STORE instruction
    
        EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
        EX_MEM_B <= #2 ID_EX_B;
        
    end

    BRANCH:begin
    
        //Target address calculation
        EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm; 
        EX_MEM_cond <= #2 (ID_EX_A == 0);
        
    end
    
endcase
end


//MEM stage (Memory access / Branch comepletion stage)


always @ (posedge clk2)
if(HALTED == 0)
begin
    MEM_WB_type <= #2 EX_MEM_type;
    MEM_WB_IR <= #2 EX_MEM_IR;

    case (EX_MEM_type)

    RR_ALU,RM_ALU:
         MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;
         
    LOAD:
         MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut];
         
    STORE:
    
         //Disable write in case TAKEN_BRANCH is 1
         if(TAKEN_BRANCH == 0)  
                 Mem[EX_MEM_ALUOut]<= #2 EX_MEM_B;
                 
endcase

end


//WB stage


always @ (posedge clk1)
begin

    // Disable write if branch is taken
    if(TAKEN_BRANCH == 0)
    case(MEM_WB_type)
    
    RR_ALU: Reg[MEM_WB_IR[15:11]] <= #4 MEM_WB_ALUOut;
    RM_ALU: Reg[MEM_WB_IR[20:16]] <= #4 MEM_WB_ALUOut;
    LOAD: Reg[MEM_WB_IR[20:16]] <= #4 MEM_WB_LMD;
    HALT: HALTED <= #2 1'b1;
    
    endcase
    
end


endmodule
