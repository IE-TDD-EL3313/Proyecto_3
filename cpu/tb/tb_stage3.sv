`timescale 1ns/1ps
// Banco de prueba, no sintetizable. Verifica selecciones y temporizacion del PC.
module tb_stage3;
    logic clk_i = 0;
    always #5 clk_i = ~clk_i;
    logic rst_i = 1;
    logic [31:0] PC, PCPlus4, NextPC, TargetPC = 32'h100;
    logic PCSrc = 0;
    logic [31:0] RD1 = 32'h12345678, RD2 = 32'h87654321;
    logic [31:0] Imm = 32'hfffffffc;
    logic ALUSrcA = 0, ALUSrcB = 0;
    logic [31:0] ALUOperandA, ALUOperandB, WriteData;
    logic [31:0] ALUResult = 32'haaaaaaaa, DataIn_i = 32'h55555555;
    logic [1:0] ResultSrc = 0;
    logic [31:0] testPC, testPCPlus4;
    integer checks = 0;

    pc_register pc_dut(.*);
    pc_plus4 add_dut(.PC(PC), .PCPlus4(PCPlus4));
    pc_plus4 overflow_dut(.PC(testPC), .PCPlus4(testPCPlus4));
    mux_next_pc next_dut(.*);
    mux_a a_dut(.*);
    mux_b b_dut(.*);
    mux_writeback wb_dut(.*);

    task automatic check32(input logic [31:0] actual, expected, input string label);
        begin
            checks = checks + 1;
            if (actual !== expected)
                $fatal(1, "%s: actual=%h esperado=%h", label, actual, expected);
        end
    endtask

    initial begin
        // Reset inicial, incluso con un destino distinto de cero seleccionado.
        PCSrc = 1;
        @(posedge clk_i); #1;
        check32(PC, 0, "Reset con prioridad");
        check32(PCPlus4, 4, "PC+4 desde cero");
        @(negedge clk_i); rst_i = 0; PCSrc = 0;
        #1; check32(PC, 0, "PC conserva valor entre flancos");
        check32(NextPC, 4, "Seleccion secuencial");
        @(posedge clk_i); #1; check32(PC, 4, "Avance secuencial");

        @(negedge clk_i); PCSrc = 1;
        #1; check32(NextPC, 32'h100, "Seleccion destino");
        check32(PC, 4, "Destino no cambia PC antes del flanco");
        @(posedge clk_i); #1; check32(PC, 32'h100, "Carga de destino");

        @(negedge clk_i); rst_i = 1;
        #1; check32(PC, 32'h100, "Reset es sincrono");
        @(posedge clk_i); #1; check32(PC, 0, "Reset en flanco");

        // MUX A y B: cada entrada, seguida de cambios sin reloj.
        check32(ALUOperandA, RD1, "MUX A registro");
        check32(ALUOperandB, RD2, "MUX B registro");
        ALUSrcA = 1; ALUSrcB = 1; #1;
        check32(ALUOperandA, PC, "MUX A PC");
        check32(ALUOperandB, Imm, "MUX B inmediato negativo");
        Imm = 32'h123; #1;
        check32(ALUOperandB, Imm, "MUX B respuesta combinacional");
        ALUSrcA = 0; RD1 = 32'hfedcba98; #1;
        check32(ALUOperandA, RD1, "MUX A respuesta combinacional");

        ResultSrc = 0; #1; check32(WriteData, ALUResult, "WB ALU");
        ResultSrc = 1; #1; check32(WriteData, DataIn_i, "WB memoria");
        ResultSrc = 2; #1; check32(WriteData, PCPlus4, "WB retorno");
        ResultSrc = 3; #1; check32(WriteData, 0, "WB reservado");

        testPC = 32'hfffffffc; #1;
        check32(testPCPlus4, 0, "Suma modulo 2**32");
        testPC = 32'h12345678; #1;
        check32(testPCPlus4, 32'h1234567c, "Suma general");
        $display("PASS: Etapa 3, %0d comprobaciones", checks);
        $finish;
    end

    initial begin
        #1000; $fatal(1, "Timeout");
    end
endmodule
