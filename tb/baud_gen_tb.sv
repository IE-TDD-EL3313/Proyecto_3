`timescale 1ns/1ps

module baud_gen_tb;

    localparam int CLK_FREQ_HZ = 1_000_000;
    localparam int BAUD_RATE   = 100_000;
    localparam int DIVISOR     = 10;
    localparam time CLK_PERIOD = 1us;

    logic clk_i;
    logic rst_i;
    logic baud_tick_o;

    integer cycles_between_ticks;
    integer ticks_checked;

    baud_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .baud_tick_o(baud_tick_o)
    );

    initial clk_i = 1'b0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    initial begin
        rst_i = 1'b1;

        repeat (3) @(posedge clk_i);

        // Liberar reset fuera del flanco activo para evitar
        // condiciones de carrera entre DUT y testbench.
        @(negedge clk_i);
        rst_i = 1'b0;

        // Ignorar el primer tick: a partir de este medimos
        // periodos completos entre ticks consecutivos.
        @(posedge baud_tick_o);

        cycles_between_ticks = 0;
        ticks_checked        = 0;

        while (ticks_checked < 5) begin
            @(posedge clk_i);
            #1ns;

            cycles_between_ticks = cycles_between_ticks + 1;

            if (baud_tick_o) begin
                if (cycles_between_ticks != DIVISOR) begin
                    $fatal(
                        1,
                        "FAIL: intervalo de %0d ciclos; esperado %0d",
                        cycles_between_ticks,
                        DIVISOR
                    );
                end

                ticks_checked = ticks_checked + 1;

                $display(
                    "PASS: intervalo %0d = %0d ciclos",
                    ticks_checked,
                    cycles_between_ticks
                );

                cycles_between_ticks = 0;

                // El siguiente ciclo no puede seguir en alto.
                @(posedge clk_i);
                #1ns;

                if (baud_tick_o) begin
                    $fatal(
                        1,
                        "FAIL: baud_tick permanece activo mas de un ciclo"
                    );
                end

                // Este ciclo ya pertenece al siguiente intervalo.
                cycles_between_ticks = 1;
            end
        end

        $display(
            "PASS: baud_gen genera ticks cada %0d ciclos",
            DIVISOR
        );

        $display(
            "PASS: baud_tick permanece activo un solo ciclo"
        );

        $finish;
    end

endmodule
