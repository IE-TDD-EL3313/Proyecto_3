// Core uniciclo: instrucciones y datos con lectura combinacional externa.
// Direcciones en bytes. Reset sincrono activo en alto; escrituras bloqueadas en reset.
// Subconjunto educativo: sin excepciones, sin esperas, accesos de palabra alineados.
module riscv_core (
 input logic clk_i, rst_i,
 input logic [31:0] ProgIn_i, DataIn_i,
 output logic [31:0] ProgAddress_o, DataAddress_o, DataOut_o,
 output logic we_o
);
 logic [31:0] PC, NextPC, PCPlus4, RD1, RD2, Imm;
 logic [31:0] ALUOperandA, ALUOperandB, ALUResult, WriteData, TargetPC;
 logic [6:0] opcode, funct7;
 logic [2:0] funct3;
 logic [4:0] rs1, rs2, rd;
 logic RegWrite, ALUSrcA, ALUSrcB, Branch, Jump, JALR, MemWrite;
 logic BranchTaken, PCSrc;
 logic [3:0] ALUControl;
 logic [2:0] ImmSrc;
 logic [1:0] ResultSrc, BranchCtrl;
 pc_register u_pc_register (
  .clk_i(clk_i),
  .rst_i(rst_i),
  .NextPC(NextPC),
  .PC(PC)
 );
 pc_plus4 u_pc_plus4 (
  .PC(PC),
  .PCPlus4(PCPlus4)
 );
 instruction_decoder u_instruction_decoder (
  .ProgIn_i(ProgIn_i),
  .opcode(opcode),
  .funct7(funct7),
  .funct3(funct3),
  .rs1(rs1),
  .rs2(rs2),
  .rd(rd)
 );
 control_unit u_control_unit (
  .opcode(opcode),
  .funct7(funct7),
  .funct3(funct3),
  .RegWrite(RegWrite),
  .ALUSrcA(ALUSrcA),
  .ALUSrcB(ALUSrcB),
  .ALUControl(ALUControl),
  .ImmSrc(ImmSrc),
  .ResultSrc(ResultSrc),
  .BranchCtrl(BranchCtrl),
  .Branch(Branch),
  .Jump(Jump),
  .JALR(JALR),
  .MemWrite(MemWrite)
 );
 register_file u_register_file (
  .clk_i(clk_i),
  .rst_i(rst_i),
  .RegWrite(RegWrite),
  .rs1(rs1),
  .rs2(rs2),
  .rd(rd),
  .WriteData(WriteData),
  .RD1(RD1),
  .RD2(RD2)
 );
 immediate_generator u_immediate_generator (
  .ProgIn_i(ProgIn_i),
  .ImmSrc(ImmSrc),
  .Imm(Imm)
 );
 mux_a u_mux_a (
  .RD1(RD1),
  .PC(PC),
  .ALUSrcA(ALUSrcA),
  .ALUOperandA(ALUOperandA)
 );
 mux_b u_mux_b (
  .RD2(RD2),
  .Imm(Imm),
  .ALUSrcB(ALUSrcB),
  .ALUOperandB(ALUOperandB)
 );
 alu u_alu (
  .ALUOperandA(ALUOperandA),
  .ALUOperandB(ALUOperandB),
  .ALUControl(ALUControl),
  .ALUResult(ALUResult)
 );
 branch_comparator u_branch_comparator (
  .RD1(RD1),
  .RD2(RD2),
  .BranchCtrl(BranchCtrl),
  .BranchTaken(BranchTaken)
 );
 mux_writeback u_mux_writeback (
  .ALUResult(ALUResult),
  .DataIn_i(DataIn_i),
  .PCPlus4(PCPlus4),
  .ResultSrc(ResultSrc),
  .WriteData(WriteData)
 );
 branch_jump_logic u_branch_jump_logic (
  .PC(PC),
  .RD1(RD1),
  .Imm(Imm),
  .BranchTaken(BranchTaken),
  .Branch(Branch),
  .Jump(Jump),
  .JALR(JALR),
  .TargetPC(TargetPC),
  .PCSrc(PCSrc)
 );
 mux_next_pc u_mux_next_pc (
  .PCPlus4(PCPlus4),
  .TargetPC(TargetPC),
  .PCSrc(PCSrc),
  .NextPC(NextPC)
 );
 // ROM, RAM y decodificacion MMIO pertenecen a la plataforma externa.
 assign ProgAddress_o = PC;
 assign DataAddress_o = ALUResult;
 assign DataOut_o = RD2;
 assign we_o = MemWrite & ~rst_i;
endmodule
