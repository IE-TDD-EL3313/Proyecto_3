// Sumador de destinos independiente de la ALU, segun el diagrama aprobado.
// Imm B/J ya contiene el bit cero: no se desplaza nuevamente.
module branch_jump_logic (
 input logic [31:0] PC, RD1, Imm,
 input logic BranchTaken, Branch, Jump, JALR,
 output logic [31:0] TargetPC,
 output logic PCSrc
);
 logic [31:0] TargetBase, TargetSum;
 assign TargetBase = JALR ? RD1 : PC;
 assign TargetSum = TargetBase + Imm;
 assign TargetPC = JALR ? (TargetSum & 32'hffff_fffe) : TargetSum;
 assign PCSrc = Jump | (Branch & BranchTaken);
endmodule
