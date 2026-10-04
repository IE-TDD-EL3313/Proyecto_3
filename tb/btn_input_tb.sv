`timescale 1ns/1ps
// Testbench autoverificable de btn_input.
// Requiere compilar junto a: button_debouncer.sv (del proyecto anterior).
//
// Truco de simulación: se instancia con CLK_FREQ_HZ=1000 (en vez de
// 100_000_000 reales), de forma que MS_COUNT = CLK_FREQ_HZ/1000 = 1 y
// "ce_1ms" se activa en cada ciclo de reloj. Esto no cambia la lógica
// verificada (sigue siendo el mismo RTL), solo acelera drásticamente el
// tiempo de simulación necesario para probar el antirrebote.
//
// Verifica:
//   1) Tras el reset, rdata_o = 0.
//   2) Una pulsación limpia genera exactamente 1 pulso en el bit correspondiente.
//   3) Una pulsación con rebotes simulados también genera exactamente 1 pulso
//      (confirma que el filtro antirrebote realmente filtra).

module btn_input_tb;

    localparam int CLK_FREQ_HZ_SIM = 1000;
    localparam int DEBOUNCE_MS_SIM = 3;

    logic        clk_i = 1'b0;
    logic        rst_i = 1'b1;
    logic [6:0]  btn_raw_i = 7'b0;
    logic [31:0] rdata_o;

    int pulse_count [0:6];
    int errors = 0;

    btn_input #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ_SIM),
        .DEBOUNCE_MS(DEBOUNCE_MS_SIM)
    ) dut (
        .clk_i     (clk_i),
        .rst_i     (rst_i),
        .btn_raw_i (btn_raw_i),
        .rdata_o   (rdata_o)
    );

    always #5 clk_i = ~clk_i;

    // Acumulador de pulsos observados por bit (para autochequeo)
    always @(posedge clk_i) begin
        for (int k = 0; k < 7; k++) begin
            if (rdata_o[k]) pulse_count[k] = pulse_count[k] + 1;
        end
    end

    task automatic check_reset;
        begin
            if (rdata_o !== 32'b0) begin
                $error("[FAIL] rdata_o != 0 justo despues del reset (rdata_o=%0h)", rdata_o);
                errors++;
            end else begin
                $display("[PASS] rdata_o = 0 despues del reset");
            end
        end
    endtask

    task automatic press_clean(input int bit_idx, input string label);
        int count_before, count_after;
        begin
            count_before = pulse_count[bit_idx];
            @(posedge clk_i);
            btn_raw_i[bit_idx] <= 1'b1;
            repeat (10) @(posedge clk_i);
            count_after = pulse_count[bit_idx];
            if (count_after - count_before == 1) begin
                $display("[PASS] %s: bit %0d genero exactamente 1 pulso", label, bit_idx);
            end else begin
                $error("[FAIL] %s: bit %0d genero %0d pulso(s) (se esperaba 1)",
                       label, bit_idx, count_after - count_before);
                errors++;
            end
            @(posedge clk_i);
            btn_raw_i[bit_idx] <= 1'b0;
            repeat (10) @(posedge clk_i);
        end
    endtask

    task automatic press_bouncy(input int bit_idx, input string label);
        int count_before, count_after;
        begin
            count_before = pulse_count[bit_idx];
            // Simular varios rebotes mecanicos antes de asentarse en 1
            repeat (4) begin
                @(posedge clk_i);
                btn_raw_i[bit_idx] <= ~btn_raw_i[bit_idx];
            end
            @(posedge clk_i);
            btn_raw_i[bit_idx] <= 1'b1; // valor final estable
            repeat (10) @(posedge clk_i);
            count_after = pulse_count[bit_idx];
            if (count_after - count_before == 1) begin
                $display("[PASS] %s: rebotes filtrados, bit %0d genero exactamente 1 pulso",
                          label, bit_idx);
            end else begin
                $error("[FAIL] %s: bit %0d genero %0d pulso(s) con rebotes (se esperaba 1)",
                       label, bit_idx, count_after - count_before);
                errors++;
            end
            @(posedge clk_i);
            btn_raw_i[bit_idx] <= 1'b0;
            repeat (10) @(posedge clk_i);
        end
    endtask

    initial begin
        for (int k = 0; k < 7; k++) pulse_count[k] = 0;

        rst_i = 1'b1;
        repeat (5) @(posedge clk_i);
        check_reset();
        rst_i = 1'b0;
        repeat (5) @(posedge clk_i);

        press_clean(0, "Pulsacion limpia (arriba)");
        press_bouncy(5, "Pulsacion con rebotes (OK)");
        press_clean(6, "Pulsacion limpia (RST)");

        repeat (10) @(posedge clk_i);

        if (errors == 0)
            $display("=== TODAS LAS PRUEBAS PASARON ===");
        else
            $display("=== %0d PRUEBA(S) FALLARON ===", errors);

        $finish;
    end

endmodule
