// ImmSrc: 000=I, 001=S, 010=B, 011=J, 100=U.
// B y J ya incluyen el bit inferior cero: no desplazar nuevamente.
module immediate_generator (
    input  logic [31:0] ProgIn_i,
    input  logic [2:0]  ImmSrc,
    output logic [31:0] Imm
);
    always @* begin
        Imm = 32'b0;
        case (ImmSrc)
            3'b000: Imm = {{20{ProgIn_i[31]}}, ProgIn_i[31:20]};
            3'b001: Imm = {{20{ProgIn_i[31]}}, ProgIn_i[31:25], ProgIn_i[11:7]};
            3'b010: Imm = {{19{ProgIn_i[31]}}, ProgIn_i[31], ProgIn_i[7],
                         ProgIn_i[30:25], ProgIn_i[11:8], 1'b0};
            3'b011: Imm = {{11{ProgIn_i[31]}}, ProgIn_i[31], ProgIn_i[19:12],
                         ProgIn_i[20], ProgIn_i[30:21], 1'b0};
            3'b100: Imm = {ProgIn_i[31:12], 12'b0};
            default: Imm = 32'b0;
        endcase
    end
endmodule
