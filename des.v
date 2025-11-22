`timescale 1ns / 1ps
  
  //Arithmetic and Logic Operations:
     // 1. ADD Rd,Rs1,Rs2 - Rd=Rs1+Rs2
     // 2. ADDI Rd,Rs,Imm - Rd=Rs+Imm
     // 3. SUB Rd,Rs1,Rs2 - Rd=Rs1-Rs2
     // 4. SUBI  Rd,Rs,Imm - Rd=Rs-Imm
     // 5. AND Rd,Rs1,Rs2 - Rd=Rs1&Rs2
     // 6. OR Rd,Rs1,Rs2 - Rd=Rs1|Rs2
     // 7. MUL Rd,Rs1,Rs2 - Rd=Rs1*Rs2
     // 8. SLT Rd,Rs1,Rs2 - Rd=1 if Rs1<Rs2 else Rd=0
     // 9. SLTI Rd,Rs,Imm - Rd=1 if Rs<Imm else Rd=0
     
  //Load and Store Operations:
     // 1. LW Rd,Offset(Rs) - Rd=M[Rs+Offset]
     // 2. SW Rs,Offset(Rd) - M[Rd+Offset] = Rs
     
  //Branching Operations:   
     // 1. BEQZ R1,Label - Branch to Label if R1=0
     // 2. BNEQZ R1,Label - Branch to Label R1 != 0
     
  //Jump Operations (J-Type - Work in Progress):
     // 1. J Label - PC = Label
     // 2. JAL Rd,Label - Rd = PC+1, PC = Label
     
  //Halt Operations:
     // 1. HLT
     
     
module des (clk1,clk2);

input clk1,clk2;

reg [31:0] PC; //32-bit Program Counter

//Interstage latch registers between IF and ID stage.
reg [31:0] IF_ID_IR, //Instruction register 
           IF_ID_NPC; //Next PC (temporary register)

 //Interstage latch registers between ID and EX stage.  
reg [31:0] ID_EX_IR, //Instruction register
           ID_EX_NPC, //Next PC (temporary register)
           ID_EX_A, //First register to be used for operations
           ID_EX_B, //Second register to be used for operations
           ID_EX_Imm; //Immediate offset value to be used when required

  // Type of instructions
reg [2:0] ID_EX_type,EX_MEM_type,MEM_WB_type;

//Interstage latch registers between EX and MEM stage.
reg [31:0] EX_MEM_IR, //Instruction register
           EX_MEM_ALUOut, //To be used for storing operation results or effective address depending on the instruction.
           EX_MEM_B,
           EX_MEM_cond;  //Required for JUMP or branch condition checking.

//Interstage latch registers between MEM and WB stage.
reg [31:0] MEM_WB_IR, //Instruction register
           MEM_WB_ALUOut, //Operation results or Effective address
           MEM_WB_LMD; //Load Memory Data
           

//Register Bank
//32 32-bit general purpose registers
//R0 is always assumed to store a constant 0
reg [31:0] Reg[0:31]; 

//Memory
reg [31:0] Mem[0:1023];

//Only instructions that can access memory are load and store instructions
//Other instructions will have to first load the data into the CPU registers from the memory in order to access it.


parameter 

//OPCODES for instructions to be decoded in the ID stage
//6 of the most significant bytes of one instruction
//Register Type Instructions
//Instructions involving two source registers.
ADD=6'b000000,SUB=6'b000001,AND=6'b000010,OR=6'b000011,SLT=6'b000100,MUL=6'b000101,HLT=6'b111111,

//I Type Instructions (Immediate Instructions)
//Instrcutions involving one source register and one immediate offset.
LW=6'b001000,SW=6'b001001,ADDI=6'b001010,SUBI=6'b001011,SLTI=6'b001100,BNEQZ=6'b001101,BEQZ=6'b001110,

//J Type Instructions (Jump Instructions - Work in Progress)
J=6'b001111,JAL=6'b010000;


//Code for the type of instructions
parameter RR_ALU=3'b000,RM_ALU=3'b001,LOAD=3'b010,STORE=3'b011,BRANCH=3'b100,HALT=3'b101,JUMP=3'b110;

//Set after HLT instruction is completed.
reg HALTED; 

//Required to disable instructions after branch.
reg TAKEN_BRANCH;


//IF Stage


always @ (posedge clk1)

//HALTED needs to be zero for further execution because if HALTED is already 1 then there should not be any further fetching of instructions.
if(HALTED == 0)

begin

    //There would be a feedback from the EX stage that would tell the IF stage whether or not the previous instruction is a branch instruction along with the information about its condition whether it is satisfied or not.
  if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_cond == 1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
    
    begin
    
        //The destination of branch instruction is known only after EX stage and is stored in the EX_MEM_ALUOut which we have defined for storing the effective address.
        IF_ID_IR <= #2 Mem[EX_MEM_ALUOut]; 
        
        //Since we are taking the branch we need to set the taken branch register to 1
        TAKEN_BRANCH <= #2 1'b1;
        
        //Next address calculation using the current effective address.
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

//Halted again needs to be 0 for normal execution in the ID stage. 
if (HALTED == 0)

begin

    //Loading of first operand
    
    if(IF_ID_IR[25:21]==5'b00000) //The mentioned bits of the instruction register are supposed to store the first operand which is 0 in this case
    
    ID_EX_A <= 0; //Assigning the 0 value to the first operand.
    
    else 
    
    ID_EX_A <= #2 Reg[IF_ID_IR[25:21]]; //Assignment in the case of non-zero value.
    
    //Loading of second operand
    if(IF_ID_IR[20:16]==5'b00000)
    
    ID_EX_B<=0;
    
    else
    
    ID_EX_B <= #2 Reg[IF_ID_IR[20:16]]; 

    //Fowarding of values of NPC and IR
    ID_EX_NPC <= #2 IF_ID_NPC; 
    ID_EX_IR <= #2 IF_ID_IR;
    
    // First 16 bits are the sign extension of the immediate value while the last 16 bits actually represent the offset value
    //Sign extension is needed because instructions are of 32 bits.
    ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}}; 

    //Type of instructions being decoded
    case (IF_ID_IR[31:26])
    
    //Depending on the op-code the instructions are categorised in different types
   
    ADD,SUB,AND,OR,SLT,MUL: ID_EX_type <= #2 RR_ALU;
    
    ADDI,SUBI,SLTI: ID_EX_type <= #2 RM_ALU;
    
    LW: ID_EX_type <= #2 LOAD;
    
    SW: ID_EX_type <= #2 STORE;
    
    BNEQZ,BEQZ: ID_EX_type <= #2 BRANCH;
    
    // J-Type instructions (Work in Progress)
    J,JAL: ID_EX_type <= #2 JUMP;
    
    HLT: ID_EX_type <= #2 HALT;
    
    //In case the provided opcode is not valid
    
    default: ID_EX_type <= #2 HALT;
    
endcase

end


//EX stage


always @ (posedge clk1)

//Halted needs to be 0.
if(HALTED == 0)

begin
    
    //Forwarding of values defined in the last stage.
    EX_MEM_type <= #2 ID_EX_type;
    EX_MEM_IR <= #2 ID_EX_IR;
    
    //Resetting the taken branch flag to zero again
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
        SLT: EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_B);
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
    
    //Calculation of the effective memory address to be accessed for LOAD/STORE instruction
        EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
        
    //Forwarding of the value of B
        EX_MEM_B <= #2 ID_EX_B;
        
    end

    BRANCH:begin
    
        //Target address calculation
        EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm; 
        EX_MEM_cond <= #2 (ID_EX_A == 0);
        
    end
    
    // J-Type instruction execution (Work in Progress)
    JUMP:begin
        // TODO: Implement jump target address calculation
        // EX_MEM_ALUOut <= #2 jump_target_address;
    end
    
endcase
end


//MEM stage (Memory access / Branch comepletion stage)


always @ (posedge clk2)

//Halted needs to be 0.
if(HALTED == 0)

begin

    //Forwarding of some values defined in the last stage.
    MEM_WB_type <= #2 EX_MEM_type;
    MEM_WB_IR <= #2 EX_MEM_IR;

    case (EX_MEM_type)

    RR_ALU,RM_ALU:
    
    //In case of arithmetic and logic instructions ALUOut is simply forwarded
         MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;
         
    LOAD:
    
    //In this case the ALUOut is used for the effective address calculation.
         MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut];
         
    STORE:
    
         //Disable write in case TAKEN_BRANCH is 1
         if(TAKEN_BRANCH == 0)  
                 Mem[EX_MEM_ALUOut]<= #2 EX_MEM_B;
    
    // J-Type completion (Work in Progress)
    JUMP:begin
        // TODO: Handle jump completion
    end
                 
endcase

end


//WB stage


always @ (posedge clk1)

begin

    // Disable write if branch is taken
    if(TAKEN_BRANCH == 0)
    
    case(MEM_WB_type)
    
    //Writing of different values depending on the type of instruction.
    RR_ALU: Reg[MEM_WB_IR[15:11]] <= #4 MEM_WB_ALUOut;
    RM_ALU: Reg[MEM_WB_IR[20:16]] <= #4 MEM_WB_ALUOut;
    LOAD: Reg[MEM_WB_IR[20:16]] <= #4 MEM_WB_LMD;
    
    // J-Type writeback (Work in Progress)
    JUMP:begin
        // TODO: Handle JAL register writeback if needed
    end
    
    HALT: HALTED <= #2 1'b1;
    
    endcase
    
end


endmodule
