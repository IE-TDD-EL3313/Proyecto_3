// Direccion secuencial. La suma se realiza modulo 2**32.
module pc_plus4 (
    input  logic [31:0] PC,
    output logic [31:0] PCPlus4
);
    assign PCPlus4 = PC + 32'd4;
endmodule
