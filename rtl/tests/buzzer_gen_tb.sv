`timescale 1ns/1ps

module buzzer_gen_tb;

    localparam int CLK_FREQ_HZ = 10_000;

    logic clk_i = 0;
    logic rst_i = 1;
    logic [31:0] wdata_i = 0;
    logic we_i = 0;
    logic buzz_pwm_o;
    logic [31:0] rdata_o;

    always #50 clk_i = ~clk_i;

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

    task automatic probar_evento(
        input logic [2:0] evento,
        input integer esperados
    );
        integer pitidos;
        integer ciclos;
        logic estado_previo;

        @(negedge clk_i);
        wdata_i = {28'd0, 1'b1, evento};
        we_i = 1'b1;

        @(negedge clk_i);
        we_i = 1'b0;

        if (!buzz_pwm_o)
            $fatal(1, "Evento %0d no inicia", evento);

        pitidos = 1;
        ciclos = 0;
        estado_previo = buzz_pwm_o;

        while (rdata_o[3] && ciclos < 100_000) begin
            @(negedge clk_i);
            ciclos = ciclos + 1;

            if (buzz_pwm_o && !estado_previo)
                pitidos = pitidos + 1;

            estado_previo = buzz_pwm_o;
        end

        if (ciclos >= 100_000)
            $fatal(1, "Timeout evento %0d", evento);

        if (pitidos != esperados)
            $fatal(1,
                "Evento %0d: esperados %0d, obtenidos %0d",
                evento, esperados, pitidos);

        $display("PASS evento %0d: %0d pitidos",
                 evento, pitidos);
    endtask

    initial begin
        repeat (5) @(negedge clk_i);
        rst_i = 1'b0;

        probar_evento(3'b000, 1);
        probar_evento(3'b001, 2);
        probar_evento(3'b010, 3);
        probar_evento(3'b011, 1);
        probar_evento(3'b100, 5);

        $display("PASS: todos los eventos del buzzer");
        $finish;
    end

endmodule
