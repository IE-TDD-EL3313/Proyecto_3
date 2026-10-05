`timescale 1ns/1ps

module uart_tx_tb;

    localparam int CLK_FREQ_HZ = 1_000_000;
    localparam int BAUD_RATE   = 100_000;
    localparam time CLK_PERIOD = 1us;

    logic clk_i;
    logic rst_i;
    logic baud_tick;

    logic [7:0] tx_data_i;
    logic       tx_start_i;
    logic       tx_o;
    logic       tx_busy_o;
    logic       tx_done_o;

    baud_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_baud (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .baud_tick_o(baud_tick)
    );

    uart_tx dut (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .baud_tick_i(baud_tick),
        .tx_data_i  (tx_data_i),
        .tx_start_i (tx_start_i),
        .tx_o       (tx_o),
        .tx_busy_o  (tx_busy_o),
        .tx_done_o  (tx_done_o)
    );

    initial clk_i = 1'b0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // baud_tick es registrado por baud_gen.
    // TX lo consume en el siguiente flanco de clk_i.
    task automatic wait_baud_advance;
        begin
            @(posedge baud_tick);
            @(posedge clk_i);
            #1ns;
        end
    endtask

    task automatic check_bit(
        input logic expected,
        input string name
    );
        begin
            if (tx_o !== expected) begin
                $fatal(
                    1,
                    "FAIL: %s esperado=%b obtenido=%b",
                    name,
                    expected,
                    tx_o
                );
            end
        end
    endtask

    initial begin
        rst_i      = 1'b1;
        tx_data_i  = 8'h00;
        tx_start_i = 1'b0;

        repeat (3) @(posedge clk_i);

        @(negedge clk_i);
        rst_i = 1'b0;

        repeat (2) @(posedge clk_i);
        #1ns;

        if (tx_o !== 1'b1 || tx_busy_o !== 1'b0)
            $fatal(1, "FAIL: estado idle incorrecto");

        // Solicitar 0xA5.
        @(negedge clk_i);
        tx_data_i  = 8'hA5;
        tx_start_i = 1'b1;

        @(posedge clk_i);
        #1ns;
        tx_start_i = 1'b0;

        // La solicitud queda capturada.
        if (!tx_busy_o)
            $fatal(1, "FAIL: tx_busy_o no se activo");

        // Todavia estamos en idle hasta el siguiente baud_tick.
        check_bit(1'b1, "IDLE antes de START");

        // Primer tick: START.
        wait_baud_advance();
        check_bit(1'b0, "START");

        wait_baud_advance();
        check_bit(1'b1, "D0");

        wait_baud_advance();
        check_bit(1'b0, "D1");

        wait_baud_advance();
        check_bit(1'b1, "D2");

        wait_baud_advance();
        check_bit(1'b0, "D3");

        wait_baud_advance();
        check_bit(1'b0, "D4");

        wait_baud_advance();
        check_bit(1'b1, "D5");

        wait_baud_advance();
        check_bit(1'b0, "D6");

        wait_baud_advance();
        check_bit(1'b1, "D7");

        wait_baud_advance();
        check_bit(1'b1, "STOP");

        // Un periodo completo para STOP.
        wait_baud_advance();

        if (tx_busy_o)
            $fatal(1, "FAIL: tx_busy_o permanece activo");

        if (!tx_done_o)
            $fatal(1, "FAIL: tx_done_o no se genero");

        if (tx_o !== 1'b1)
            $fatal(1, "FAIL: TX no regreso a idle");

        $display(
            "PASS: uart_tx transmite 0xA5 con START sincronizado"
        );

        $display(
            "PASS: tx_busy_o y tx_done_o funcionan correctamente"
        );

        $finish;
    end

endmodule
