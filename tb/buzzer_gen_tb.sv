`timescale 1ns/1ps

module buzzer_gen_tb;

    localparam int CLK_FREQ_HZ = 10_000;
    localparam int CYCLES_PER_MS = CLK_FREQ_HZ / 1000;

    logic clk_i = 0;
    logic rst_i = 1;
    logic [31:0] wdata_i = 0;
    logic we_i = 0;
    logic buzz_pwm_o;
    logic [31:0] rdata_o;

    // Reloj de simulacion
    always #5 clk_i = ~clk_i;

    buzzer_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .wdata_i(wdata_i),
        .we_i(we_i),
        .buzz_pwm_o(buzz_pwm_o),
        .rdata_o(rdata_o)
    );

    task automatic iniciar(input logic [2:0] evento);
        @(negedge clk_i);
        wdata_i = {28'd0, 1'b1, evento};
        we_i = 1'b1;

        @(negedge clk_i);
        we_i = 1'b0;
        wdata_i = 0;
    endtask

    // Comprueba un intervalo completo de encendido o apagado.
    task automatic verificar_intervalo(
        input logic nivel,
        input integer duracion_ms
    );
        integer ciclos;

        ciclos = duracion_ms * CYCLES_PER_MS;

        for (integer i = 0; i < ciclos; i++) begin
            if (buzz_pwm_o !== nivel)
                $fatal(1,
                    "Nivel incorrecto: esperado=%b, obtenido=%b, ciclo=%0d",
                    nivel, buzz_pwm_o, i);

            @(negedge clk_i);
        end
    endtask

    task automatic probar_evento(
        input logic [2:0] evento,
        input integer cantidad,
        input integer encendido_ms,
        input integer apagado_ms
    );
        iniciar(evento);

        if (rdata_o[3] !== 1'b1 ||
            rdata_o[2:0] !== evento)
            $fatal(1, "Estado inicial incorrecto: evento %0d", evento);

        for (integer i = 0; i < cantidad; i++) begin
            verificar_intervalo(1'b1, encendido_ms);

            if (i < cantidad - 1)
                verificar_intervalo(1'b0, apagado_ms);
        end

        // Esperar el cambio a IDLE.
        repeat (2) @(negedge clk_i);

        if (rdata_o[3] !== 1'b0 || buzz_pwm_o !== 1'b0)
            $fatal(1, "Evento %0d no finalizo", evento);

        $display(
            "PASS evento %0d: %0d pitidos, ON=%0d ms, OFF=%0d ms",
            evento, cantidad, encendido_ms, apagado_ms
        );
    endtask

    initial begin
        repeat (5) @(negedge clk_i);
        rst_i = 0;

        // Cinco eventos del juego
        probar_evento(3'b000, 1, 150, 0);
        probar_evento(3'b001, 2, 100, 120);
        probar_evento(3'b010, 3, 120, 100);
        probar_evento(3'b011, 1, 400, 0);
        probar_evento(3'b100, 5, 150, 80);

        // Una orden nueva debe interrumpir el sonido anterior.
        iniciar(3'b100);
        repeat (20) @(negedge clk_i);
        iniciar(3'b000);

        if (rdata_o[2:0] !== 3'b000 ||
            buzz_pwm_o !== 1'b1)
            $fatal(1, "Nueva orden no interrumpio el sonido");

        $display("PASS interrupcion por nueva orden");

        // Una escritura sin buzz_start no debe iniciar sonido.
        rst_i = 1'b1;
        repeat (2) @(negedge clk_i);
        rst_i = 1'b0;

        @(negedge clk_i);
        wdata_i = 32'h0000_0004;
        we_i = 1'b1;

        @(negedge clk_i);
        we_i = 1'b0;

        if (rdata_o[3] !== 1'b0)
            $fatal(1, "buzz_start=0 inicio sonido");

        $display("PASS escritura sin buzz_start");

        // Reset durante un sonido.
        iniciar(3'b100);
        repeat (20) @(negedge clk_i);

        rst_i = 1'b1;
        repeat (2) @(negedge clk_i);

        if (buzz_pwm_o !== 1'b0 ||
            rdata_o[3:0] !== 4'b0000)
            $fatal(1, "Reset no detuvo el buzzer");

        $display("PASS reset durante sonido");

        $display("=== TODAS LAS PRUEBAS PASARON ===");
        $finish;
    end

endmodule
