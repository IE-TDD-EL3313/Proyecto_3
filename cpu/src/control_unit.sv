// Control combinacional del subconjunto de 29 instrucciones RV32I.
// Instruccion no soportada: sin efectos laterales, PC secuencial (sin trap).
// AUIPC selecciona PC en la ALU; los saltos usan su propio sumador.
module control_unit (
 input logic [6:0] opcode, funct7,
 input logic [2:0] funct3,
 output logic RegWrite, ALUSrcA, ALUSrcB,
 output logic [3:0] ALUControl,
 output logic [2:0] ImmSrc,
 output logic [1:0] ResultSrc, BranchCtrl,
 output logic Branch, Jump, JALR, MemWrite
);
 logic [26:0] InstrSel;
 assign InstrSel[0] = (opcode == 7'h03 && funct3 == 3'd2); // lw
 assign InstrSel[1] = (opcode == 7'h23 && funct3 == 3'd2); // sw
 assign InstrSel[2] = (opcode == 7'h33 && funct3 == 3'd1 && funct7 == 7'd0); // sll
 assign InstrSel[3] = (opcode == 7'h13 && funct3 == 3'd1 && funct7 == 7'd0); // slli
 assign InstrSel[4] = (opcode == 7'h33 && funct3 == 3'd5 && funct7 == 7'd0); // srl
 assign InstrSel[5] = (opcode == 7'h13 && funct3 == 3'd5 && funct7 == 7'd0); // srli
 assign InstrSel[6] = (opcode == 7'h33 && funct3 == 3'd5 && funct7 == 7'd32); // sra
 assign InstrSel[7] = (opcode == 7'h13 && funct3 == 3'd5 && funct7 == 7'd32); // srai
 assign InstrSel[8] = (opcode == 7'h33 && funct3 == 3'd0 && funct7 == 7'd0); // add
 assign InstrSel[9] = (opcode == 7'h33 && funct3 == 3'd0 && funct7 == 7'd32); // sub
 assign InstrSel[10] = (opcode == 7'h33 && funct3 == 3'd7 && funct7 == 7'd0); // and
 assign InstrSel[11] = (opcode == 7'h33 && funct3 == 3'd6 && funct7 == 7'd0); // or
 assign InstrSel[12] = (opcode == 7'h33 && funct3 == 3'd4 && funct7 == 7'd0); // xor
 assign InstrSel[13] = (opcode == 7'h13 && funct3 == 3'd0); // addi
 assign InstrSel[14] = (opcode == 7'h13 && funct3 == 3'd7); // andi
 assign InstrSel[15] = (opcode == 7'h13 && funct3 == 3'd6); // ori
 assign InstrSel[16] = (opcode == 7'h13 && funct3 == 3'd4); // xori
 assign InstrSel[17] = (opcode == 7'h63 && funct3 == 3'd0); // beq
 assign InstrSel[18] = (opcode == 7'h63 && funct3 == 3'd1); // bne
 assign InstrSel[19] = (opcode == 7'h63 && funct3 == 3'd4); // blt
 assign InstrSel[20] = (opcode == 7'h63 && funct3 == 3'd5); // bge
 assign InstrSel[21] = (opcode == 7'h33 && funct3 == 3'd2 && funct7 == 7'd0); // slt
 assign InstrSel[22] = (opcode == 7'h13 && funct3 == 3'd2); // slti
 assign InstrSel[23] = (opcode == 7'h33 && funct3 == 3'd3 && funct7 == 7'd0); // sltu
 assign InstrSel[24] = (opcode == 7'h13 && funct3 == 3'd3); // sltiu
 assign InstrSel[25] = (opcode == 7'h6f); // jal
 assign InstrSel[26] = (opcode == 7'h67 && funct3 == 3'd0); // jalr
 always @* begin
  RegWrite=0; ALUSrcA=0; ALUSrcB=0; ALUControl=4'd0;
  ImmSrc=2'd0; ResultSrc=2'd0; BranchCtrl=2'd0;
  Branch=0; Jump=0; JALR=0; MemWrite=0;
  case (InstrSel)
   27'h0000001: begin RegWrite=1; ALUSrcB=1; ResultSrc=2'd1; end // lw
   27'h0000002: begin MemWrite=1; ALUSrcB=1; ImmSrc=2'd1; end // sw
   27'h0000004: begin RegWrite=1; ALUControl=4'd5; end // sll
   27'h0000008: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd5; end // slli
   27'h0000010: begin RegWrite=1; ALUControl=4'd6; end // srl
   27'h0000020: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd6; end // srli
   27'h0000040: begin RegWrite=1; ALUControl=4'd7; end // sra
   27'h0000080: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd7; end // srai
   27'h0000100: begin RegWrite=1; ALUControl=4'd0; end // add
   27'h0000200: begin RegWrite=1; ALUControl=4'd1; end // sub
   27'h0000400: begin RegWrite=1; ALUControl=4'd2; end // and
   27'h0000800: begin RegWrite=1; ALUControl=4'd3; end // or
   27'h0001000: begin RegWrite=1; ALUControl=4'd4; end // xor
   27'h0002000: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd0; end // addi
   27'h0004000: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd2; end // andi
   27'h0008000: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd3; end // ori
   27'h0010000: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd4; end // xori
   27'h0020000: begin Branch=1; ImmSrc=2'd2; BranchCtrl=2'd0; end // beq
   27'h0040000: begin Branch=1; ImmSrc=2'd2; BranchCtrl=2'd1; end // bne
   27'h0080000: begin Branch=1; ImmSrc=2'd2; BranchCtrl=2'd2; end // blt
   27'h0100000: begin Branch=1; ImmSrc=2'd2; BranchCtrl=2'd3; end // bge
   27'h0200000: begin RegWrite=1; ALUControl=4'd8; end // slt
   27'h0400000: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd8; end // slti
   27'h0800000: begin RegWrite=1; ALUControl=4'd9; end // sltu
   27'h1000000: begin RegWrite=1; ALUSrcB=1; ALUControl=4'd9; end // sltiu
   27'h2000000: begin RegWrite=1; Jump=1; ImmSrc=2'd3; ResultSrc=2'd2; end // jal
   27'h4000000: begin RegWrite=1; Jump=1; JALR=1; ResultSrc=2'd2; end // jalr
   default: begin end // Conserva las asignaciones seguras anteriores.
  endcase
  // Los opcodes U no se solapan con el decodificador anterior.
  if (opcode == 7'h37) begin // LUI
   RegWrite=1; ALUSrcB=1; ImmSrc=3'd4; ALUControl=4'd10;
  end else if (opcode == 7'h17) begin // AUIPC
   RegWrite=1; ALUSrcA=1; ALUSrcB=1; ImmSrc=3'd4;
  end
 end
endmodule
