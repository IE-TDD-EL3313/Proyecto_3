// BranchCtrl: 00=BEQ, 01=BNE, 10=BLT, 11=BGE.
// BranchTaken expresa la condicion; Branch habilita su uso fuera del modulo.
module branch_comparator (
    input  logic [31:0] RD1,
    input  logic [31:0] RD2,
    input  logic [1:0]  BranchCtrl,
    output logic        BranchTaken
);
    always @* begin
        BranchTaken = 1'b0;
        case (BranchCtrl)
            2'b00: BranchTaken = (RD1 == RD2);
            2'b01: BranchTaken = (RD1 != RD2);
            2'b10: BranchTaken = ($signed(RD1) < $signed(RD2));
            2'b11: BranchTaken = ($signed(RD1) >= $signed(RD2));
            default: BranchTaken = 1'b0;
        endcase
    end
endmodule
