`timescale 1ns/1ps

// Testbench autoverificable de btn_input.
//
// Se usa CLK_FREQ_HZ=1000 para acelerar el debounce:
// MS_COUNT = CLK_FREQ_HZ/1000 = 1.
//
// Verifica:
//   1) Reset -> rdata_o = 0.
//   2) Una pulsacion genera un evento.
//   3) El evento permanece almacenado sin ACK.
//   4) ACK limpia el evento.
//   5) Los rebotes producen un solo evento.
//   6) Un nuevo evento puede registrarse despues del ACK.

module btn_input_tb;

    localparam int CLK_FREQ_HZ_SIM = 1000;
    localparam int DEBOUNCE_MS_SIM = 3;

    logic        clk_i     = 1'b0;
    logic        rst_i     = 1'b1;
    logic [6:0]  btn_raw_i = 7'b0;
    logic        ack_i     = 1'b0;
    logic [31:0] rdata_o;

    int errors = 0;

    btn_input #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ_SIM),
        .DEBOUNCE_MS(DEBOUNCE_MS_SIM)
    ) dut (
        .clk_i     (clk_i),
        .rst_i     (rst_i),
        .btn_raw_i (btn_raw_i),
        .ack_i     (ack_i),
        .rdata_o   (rdata_o)
    );

    always #5 clk_i = ~clk_i;

    task automatic check_bit(
        input int bit_idx,
        input logic expected,
        input string label
    );
        begin
            if (rdata_o[bit_idx] !== expected) begin
                $error("[FAIL] %s: bit %0d = %b, esperado %b",
                       label, bit_idx, rdata_o[bit_idx], expected);
                errors++;
            end else begin
                $display("[PASS] %s", label);
            end
        end
    endtask

    task automatic acknowledge;
        begin
            @(negedge clk_i);
            ack_i = 1'b1;

            @(posedge clk_i);
            #1;

            @(negedge clk_i);
            ack_i = 1'b0;

            @(posedge clk_i);
            #1;
        end
    endtask

    task automatic press_clean(input int bit_idx);
        begin
            @(negedge clk_i);
            btn_raw_i[bit_idx] = 1'b1;

            // Tiempo suficiente para sincronizacion + debounce.
            repeat (10) @(posedge clk_i);

            @(negedge clk_i);
            btn_raw_i[bit_idx] = 1'b0;

            // Permitir tambien debounce de liberacion.
            repeat (10) @(posedge clk_i);
        end
    endtask

    task automatic press_bouncy(input int bit_idx);
        begin
            // Rebotes iniciales.
            repeat (4) begin
                @(negedge clk_i);
                btn_raw_i[bit_idx] = ~btn_raw_i[bit_idx];
            end

            // Pulsacion finalmente estable.
            @(negedge clk_i);
            btn_raw_i[bit_idx] = 1'b1;

            repeat (10) @(posedge clk_i);

            @(negedge clk_i);
            btn_raw_i[bit_idx] = 1'b0;

            repeat (10) @(posedge clk_i);
        end
    endtask

    initial begin

        // ------------------------------------------------------------
        // Reset
        // ------------------------------------------------------------
        rst_i = 1'b1;
        repeat (5) @(posedge clk_i);

        if (rdata_o !== 32'b0) begin
            $error("[FAIL] Reset: rdata_o=%h, esperado 0", rdata_o);
            errors++;
        end else begin
            $display("[PASS] Reset deja rdata_o = 0");
        end

        @(negedge clk_i);
        rst_i = 1'b0;

        repeat (5) @(posedge clk_i);


        // ------------------------------------------------------------
        // Prueba 1: evento sticky
        // ------------------------------------------------------------
        press_clean(0);

        check_bit(
            0,
            1'b1,
            "BTN_UP queda almacenado despues de la pulsacion"
        );

        // Esperamos mucho mas que los 4 ciclos del cpu_ce.
        repeat (12) @(posedge clk_i);

        check_bit(
            0,
            1'b1,
            "BTN_UP permanece almacenado sin ACK"
        );


        // ------------------------------------------------------------
        // Prueba 2: ACK limpia el evento
        // ------------------------------------------------------------
        acknowledge();

        check_bit(
            0,
            1'b0,
            "ACK limpia BTN_UP"
        );


        // ------------------------------------------------------------
        // Prueba 3: rebotes
        // ------------------------------------------------------------
        press_bouncy(5);

        check_bit(
            5,
            1'b1,
            "BTN_OK con rebotes genera un evento almacenado"
        );

        repeat (12) @(posedge clk_i);

        check_bit(
            5,
            1'b1,
            "BTN_OK permanece almacenado hasta ACK"
        );

        acknowledge();

        check_bit(
            5,
            1'b0,
            "ACK limpia BTN_OK"
        );


        // ------------------------------------------------------------
        // Prueba 4: nuevo evento despues del ACK
        // ------------------------------------------------------------
        press_clean(6);

        check_bit(
            6,
            1'b1,
            "BTN_RST puede registrarse despues de ACK previo"
        );

        acknowledge();

        check_bit(
            6,
            1'b0,
            "ACK final limpia BTN_RST"
        );


        // ------------------------------------------------------------
        // Resultado
        // ------------------------------------------------------------
        if (errors == 0) begin
            $display("----------------------------------------");
            $display("TODAS LAS PRUEBAS DE BTN_INPUT PASARON");
            $display("----------------------------------------");
        end else begin
            $display("----------------------------------------");
            $display("%0d PRUEBA(S) DE BTN_INPUT FALLARON", errors);
            $display("----------------------------------------");
        end

        $finish;
    end

endmodule
