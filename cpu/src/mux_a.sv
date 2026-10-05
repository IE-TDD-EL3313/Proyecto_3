// Seleccion del primer operando: 0=RD1, 1=PC.
// Se conserva la entrada PC prevista en el diagrama de tercer nivel.
module mux_a (
    input  logic [31:0] RD1,
    input  logic [31:0] PC,
    input  logic        ALUSrcA,
    output logic [31:0] ALUOperandA
);
    assign ALUOperandA = ALUSrcA ? PC : RD1;
endmodule
