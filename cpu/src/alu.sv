// ALU combinacional de 32 bits. Los controles reservados producen cero.
module alu (
    input  logic [31:0] ALUOperandA,
    input  logic [31:0] ALUOperandB,
    input  logic [3:0]  ALUControl,
    output logic [31:0] ALUResult
);
    always @* begin
        ALUResult = 32'b0;
        case (ALUControl)
            4'b0000: ALUResult = ALUOperandA + ALUOperandB;
            4'b0001: ALUResult = ALUOperandA - ALUOperandB;
            4'b0010: ALUResult = ALUOperandA & ALUOperandB;
            4'b0011: ALUResult = ALUOperandA | ALUOperandB;
            4'b0100: ALUResult = ALUOperandA ^ ALUOperandB;
            4'b0101: ALUResult = ALUOperandA << ALUOperandB[4:0];
            4'b0110: ALUResult = ALUOperandA >> ALUOperandB[4:0];
            4'b0111: ALUResult = $signed(ALUOperandA) >>> ALUOperandB[4:0];
            4'b1000: ALUResult = {31'b0, ($signed(ALUOperandA) < $signed(ALUOperandB))};
            4'b1001: ALUResult = {31'b0, (ALUOperandA < ALUOperandB)};
            4'b1010: ALUResult = ALUOperandB; // LUI: ignora los bits que ocuparian rs1.
            default: ALUResult = 32'b0;
        endcase
    end
endmodule
