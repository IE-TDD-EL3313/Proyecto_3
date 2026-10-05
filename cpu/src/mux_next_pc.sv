// Seleccion de la proxima direccion: 0=secuencial, 1=destino.
// TargetPC llega calculado y con el ajuste de jalr ya aplicado.
module mux_next_pc (
    input  logic [31:0] PCPlus4,
    input  logic [31:0] TargetPC,
    input  logic        PCSrc,
    output logic [31:0] NextPC
);
    assign NextPC = PCSrc ? TargetPC : PCPlus4;
endmodule
