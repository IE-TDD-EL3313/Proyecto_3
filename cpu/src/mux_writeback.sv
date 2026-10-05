// Seleccion del dato hacia el banco de registros.
// ResultSrc: 00=ALU, 01=memoria, 10=retorno PC+4, 11=reservado (cero).
// Este modulo no habilita escrituras: esa funcion corresponde a RegWrite.
module mux_writeback (
    input  logic [31:0] ALUResult,
    input  logic [31:0] DataIn_i,
    input  logic [31:0] PCPlus4,
    input  logic [1:0]  ResultSrc,
    output logic [31:0] WriteData
);
    assign WriteData = (ResultSrc == 2'b00) ? ALUResult : (ResultSrc == 2'b01) ? DataIn_i : (ResultSrc == 2'b10) ? PCPlus4 : 32'b0;
endmodule
