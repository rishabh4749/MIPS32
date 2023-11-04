//Header where all the registers of the pipeline are being declared.
module pipe_MIPS32 (clk1,clk2);

input clk1,clk2;       //two clocks

reg [31:0] PC,IF_ID_IR,IF_ID_NPC;                                                                                                                                                                                                                                 //IF stage
reg [31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_Imm;                                                                                                                                                                                                          //ID stage
reg [2:0] ID_EX_type,EX_MEM_type,MEM_WB_type;                                                                                                                                                                                                                     // Type of instructions
reg [31:0] EX_MEM_IR,EX_MEM_ALUOut,EX_MEM_B;                                                                                                                                                                                                                      //MEM stage
reg EX_MEM_Cond;                                                                                                                                                                                                                                                  //Required for JUMP or branch condition checking.
reg [31:0] MEM_WB_IR,MEM_WB_ALUOut,MEM_WB_LMD;

                                                                                                                                                                                                                                                                  //Pre-WB stage
reg [31:0] Reg[0:31];                                                                                                                                                                                                                                             //Register Bank
reg [31:0] Mem[0:1023];                                                                                                                                                                                                                                           //Memory


parameter ADD=6'b000000,SUB=6'b000001,AND=6'b000010,OR=6'b000011,SLT=6'b000100,MUL=6'b000101,HLT=6'b111111,LW=6'b001000,SW=6'b001001,ADDI=6'b001010,SUBI=6'b001011,SLTI=6'b001100,BNEQZ=6'b001101,BEQZ=6'b001110;                                                 //OPCODES for instructions to be decoded in the ID stage


parameter RR_ALU=3'b000,RM_ALU=3'b001,LOAD=3'b010,STORE=3'b011,BRANCH=3'b100,HALT=3'b101;                                                                                                                                                                         //Code for the type of instructions

reg HALTED;                                                                                                                                                                                                                                                       //Set after HLT instruction is completed.

                                                                                                                                                                                                                                                                  //Say i+2'th instruction turns out to be a halt instruction the processor wont stop till the i+2 instruction finishes WB stage but during that time no new instructions after i+2 will finish execution i.e. WB stage hence WB is disabled when HALTED is 1.
reg TAKEN_BRANCH;
                                                                                                                                                                                                                                                                  //Required to disable instructions after branch.

//IF Stage


always @ (posedge clk1)
if(HALTED == 0)
                                                                                                                                                                                                                                                                  //HALTED needs to be zero for further execution because if HALTED is already 1 then there should not be any further fetching of instructions.
begin
    if((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_cond == 1)) || ((EX_MEM_IR[31:26] == BNEQZ && (EX_MEM_cond == 0)))
                                                                                                                                                                                                                                                                  //There would be a feedback from the EX stage that would tell the IF whether or not the previous instruction is a branch instruction along with the information about its condition.
    begin
        IF_ID_IR <= #2 Mem[EX_MEM_ALUOut];                                                                                                                                                                                                                        //The destination of branch instruction is known only after EX stage and is stored in the EX_MEM_ALUOut.
        TAKEN_BRANCH <= #2 1'b1;                                                                                                                                                                                                                                  //Since we are actually taking the branch
        IF_ID_NPC <= #2 EX_MEM_ALUOut + 1;                                                                                                                                                                                                                        //Next address calculation.
        PC <= #2 EX_MEM_ALUOut + 1;
    end

    else

    begin                                                                                                                                                                                                                                                         //Case when branch is not taken.
        IF_ID_IR <= #2 Mem[PC];
        IF_ID_NPC <= #2 PC+1;
        PC <= #2 PC+1;                                                                                                                                                                                                                                            //It's important to keep updating PC every cycle since we are fetching a new instruction every cycle.
    end

end


//ID Stage


always @ (posedge clk2)
if (HALTED == 0)

begin
    if(IF_ID_IR[25:21]==5'b00000) ID_EX_A <= 0;
    else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]];                                                                                                                                                                                                                       //Loading of first operand
    if(IF_ID_IR[20:16]==5'b00000) ID_EX_B<=0;
    else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]];                                                                                                                                                                                                                       //Loading of second operand

    ID_EX_NPC <= #2 IF_ID_NPC;
    ID_EX_IR <= #2 IF_ID_IR;
    ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};                                                                                                                                                                                                         // First 16 bits are the sign extension of the immediate value while the last 16 bits actually represent the offset value.

    case (IF_ID_IR[31:26])
                                                                                                                                                                                                                                                                   //Type of instructions being decoded
    ADD,SUB,AND,OR,SLT,MUL: ID_EX_type <= #2 RR_ALU;
    ADDI,SUBI,SLTI: ID_EX_type <= #2 RM_ALU;
    LW: ID_EX_type <= #2 LOAD;
    SW: ID_EX_type <= #2 STORE;
    BNEQZ,BEQZ: ID_EX_type <= #2 BRANCH;
    HLT: ID_EX_type <= #2 HALT;
    default: ID_EX_type <= #2 HALT;                                                                                                                                                                                                                                //In case the provided opcode is not valid
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

    RR_ALU: begin                                                                                                                                                                                                                                                  //Register-Register ALU i.e. No memory involved.
        case (ID_EX_IR[31:26])
        //Execution phase depending on the opcode of the instruction
        ADD: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;
        SUB: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;
        AND: EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B;
        OR: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B;
        SLT: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_B;
        MUL: EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B;
        default: ADD: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
    endcase
    end

    RM_ALU: begin                                                                                                                                                                                                                                                  //Register Memory ALU
                                                                                                                                                                                                                                                                   //Operations involving the immediate data i.e. I type instructions.
        case(ID_EX_IR[31:26]) //Opcode
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
        EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm;                                                                                                                                                                                                                 //Target address calculation
        EX_MEM_cond <= #2 (ID_EX_A == 0);
    end
endcase
end


//MEM stage


always @ (posedge clk2)
if(HALTED == 0)
begin
    MEM_WB_type <= EX_MEM_type;
    MEM_WB_IR <= #2 EX_MEM_IR;

    case (EX_MEM_type)

    RR_ALU,RM_ALU:
         MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;
    LOAD:
         MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut];
    STORE:
         if(TAKEN_BRANCH == 0)                                                                                                                                                                                                                                     //Disable write in case TAKEN_BRANCH is 1
                 Mem[EX_MEM_ALUOut]<= #2 EX_MEM_B;
endcase
end


//WB stage


always @ (posedge clk1)
begin
    if(TAKEN_BRANCH == 0)                                                                                                                                                                                                                                          // Disable write if branch is taken
    case(MEM_WB_type)
    RR_ALU: Reg[MEM_WB_IR[15:11]] <= #4 MEM_WB_ALUOut;
    RM_ALU: Reg[MEM_WB_IR[20:16]] <= #4 MEM_WB_ALUOut;
    LOAD: Reg[MEM_WB_IR[20:16]] <= #4 MEM_WB_LMD;
    HALT: HALTED <= #2 1'b1;
    endcase
end


endmodule

