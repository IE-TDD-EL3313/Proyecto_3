// PC de 32 bits: reset sincrono activo en alto, con prioridad.
// Sin reset, captura NextPC en cada flanco ascendente y lo conserva entre flancos.
module pc_register (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        ce_i,
    input  logic [31:0] NextPC,
    output logic [31:0] PC
);
    always_ff @(posedge clk_i) begin
        if (rst_i)
            PC <= 32'h0000_0000;
        else if (ce_i)
            PC <= NextPC;
    end
endmodule
