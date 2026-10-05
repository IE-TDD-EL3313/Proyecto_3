// Dos lecturas combinacionales y una escritura en flanco ascendente.
// x0 es una constante; solamente x1 a x31 tienen almacenamiento.
module register_file (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        RegWrite,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] WriteData,
    output logic [31:0] RD1,
    output logic [31:0] RD2
);
    logic [31:0] registers [1:31];
    integer index;

    // Reset sincrono, activo en alto y con prioridad sobre la escritura.
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            for (index = 1; index < 32; index = index + 1)
                registers[index] <= 32'b0;
        end else if (RegWrite && (rd != 5'd0)) begin
            registers[rd] <= WriteData;
        end
    end

    assign RD1 = (rs1 == 5'd0) ? 32'b0 : registers[rs1];
    assign RD2 = (rs2 == 5'd0) ? 32'b0 : registers[rs2];
endmodule
