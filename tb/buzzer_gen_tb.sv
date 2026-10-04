`timescale 1ns/1ps

module buzzer_gen_tb;

    logic        clk_i;
    logic        rst_i;
    logic [31:0] wdata_i;
    logic        we_i;
    logic        buzz_pwm_o;
    logic [31:0] rdata_o;

    // Frecuencia reducida para acelerar la simulacion.
    localparam int TEST_CLK_FREQ = 10_000;

    buzzer_gen #(
        .CLK_FREQ_HZ(TEST_CLK_FREQ)
    ) dut (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .wdata_i    (wdata_i),
        .we_i       (we_i),
        .buzz_pwm_o (buzz_pwm_o),
        .rdata_o    (rdata_o)
    );

    // Reloj de simulacion.
    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    task automatic start_tone(input logic [2:0] tone);
        begin
            @(negedge clk_i);
            wdata_i = {28'b0, 1'b1, tone};
            we_i    = 1'b1;

            @(posedge clk_i);
            #1;

            @(negedge clk_i);
            we_i    = 1'b0;
            wdata_i = 32'b0;
        end
    endtask

    task automatic check_active(
        input logic       expected_active,
        input logic [2:0] expected_tone,
        input string      name
    );
        begin
            #1;

            if (rdata_o[3] !== expected_active) begin
                $display(
                    "[FAIL] %s: active=%b esperado=%b",
                    name, rdata_o[3], expected_active
                );
                $fatal;
            end

            if (rdata_o[2:0] !== expected_tone) begin
                $display(
                    "[FAIL] %s: tone=%b esperado=%b",
                    name, rdata_o[2:0], expected_tone
                );
                $fatal;
            end

            $display(
                "[PASS] %s: active=%b tone=%b",
                name, rdata_o[3], rdata_o[2:0]
            );
        end
    endtask

    initial begin
        rst_i   = 1'b1;
        we_i    = 1'b0;
        wdata_i = 32'b0;

        // ----------------------------------------------------
        // Reset
        // ----------------------------------------------------
        repeat (2) @(posedge clk_i);
        #1;

        if (buzz_pwm_o !== 1'b0 || rdata_o[3:0] !== 4'b0000) begin
            $display(
                "[FAIL] Reset: pwm=%b rdata=%h",
                buzz_pwm_o, rdata_o
            );
            $fatal;
        end

        $display("[PASS] Reset");

        rst_i = 1'b0;

        // ----------------------------------------------------
        // Tono 000: impacto
        // 200 Hz, 150 ms
        // ----------------------------------------------------
        start_tone(3'b000);
        check_active(1'b1, 3'b000, "Inicio tono impacto");

        // A 10 kHz:
        // divisor = 10000 / (2*200) = 25 ciclos.
        repeat (24) @(posedge clk_i);
        #1;

        if (buzz_pwm_o !== 1'b0) begin
            $display("[FAIL] PWM cambio antes de tiempo");
            $fatal;
        end

        @(posedge clk_i);
        #1;

        if (buzz_pwm_o !== 1'b1) begin
            $display("[FAIL] PWM no cambio despues de 25 ciclos");
            $fatal;
        end

        $display("[PASS] Frecuencia del tono impacto correcta");

        // Esperar a que termine.
        // 150 ms a 10 kHz = 1500 ciclos.
        while (rdata_o[3] === 1'b1)
            @(posedge clk_i);

        #1;

        if (buzz_pwm_o !== 1'b0) begin
            $display("[FAIL] PWM no se apago al terminar");
            $fatal;
        end

        $display("[PASS] Tono impacto finalizo correctamente");

        // ----------------------------------------------------
        // Tono 010: barco hundido
        // Debe tener dos notas.
        // ----------------------------------------------------
        start_tone(3'b010);
        check_active(1'b1, 3'b010, "Inicio melodia barco hundido");

        // Primera nota: 100 ms = 1000 ciclos.
        // Esperamos suficiente tiempo para alcanzar la segunda nota.
        repeat (1002) @(posedge clk_i);
        #1;

        if (dut.step_idx !== 3'd1) begin
            $display(
                "[FAIL] Melodia no avanzo a segunda nota: step=%0d",
                dut.step_idx
            );
            $fatal;
        end

        $display("[PASS] Melodia avanzo a segunda nota");

        // ----------------------------------------------------
        // Interrupcion por una nueva orden
        // ----------------------------------------------------
        start_tone(3'b011);
        check_active(
            1'b1,
            3'b011,
            "Nueva orden interrumpe melodia anterior"
        );

        if (dut.step_idx !== 3'd0) begin
            $display(
                "[FAIL] Nueva orden no reinicio step_idx"
            );
            $fatal;
        end

        $display("[PASS] Nueva orden reinicia la secuencia");

        // ----------------------------------------------------
        // Escritura sin buzz_start
        // No debe iniciar un nuevo sonido.
        // ----------------------------------------------------
        // Primero esperamos que termine el tono 011.
        while (rdata_o[3] === 1'b1)
            @(posedge clk_i);

        @(negedge clk_i);
        wdata_i = 32'h0000_0004; // tone=100, start=0
        we_i    = 1'b1;

        @(posedge clk_i);
        #1;

        @(negedge clk_i);
        we_i = 1'b0;

        if (rdata_o[3] !== 1'b0) begin
            $display(
                "[FAIL] Escritura con buzz_start=0 inicio sonido"
            );
            $fatal;
        end

        $display("[PASS] buzz_start=0 no inicia sonido");

        // ----------------------------------------------------
        // Reset durante un sonido
        // ----------------------------------------------------
        start_tone(3'b100);
        check_active(1'b1, 3'b100, "Inicio melodia victoria");

        repeat (20) @(posedge clk_i);

        @(negedge clk_i);
        rst_i = 1'b1;

        @(posedge clk_i);
        #1;

        if (buzz_pwm_o !== 1'b0 || rdata_o[3:0] !== 4'b0000) begin
            $display(
                "[FAIL] Reset durante sonido: pwm=%b rdata=%h",
                buzz_pwm_o, rdata_o
            );
            $fatal;
        end

        $display("[PASS] Reset detiene el sonido");

        $display("=== TODAS LAS PRUEBAS PASARON ===");
        $finish;
    end

endmodule