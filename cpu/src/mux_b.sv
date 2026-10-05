// Seleccion del segundo operando: 0=RD2, 1=Imm.
// RD2 sigue disponible externamente para DataOut_o durante sw.
module mux_b (
    input  logic [31:0] RD2,
    input  logic [31:0] Imm,
    input  logic        ALUSrcB,
    output logic [31:0] ALUOperandB
);
    assign ALUOperandB = ALUSrcB ? Imm : RD2;
endmodule
