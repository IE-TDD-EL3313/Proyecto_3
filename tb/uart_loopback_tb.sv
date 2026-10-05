`timescale 1ns/1ps

module uart_loopback_tb;

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

    logic [7:0] rx_data_o;
    logic       rx_valid_o;
    logic       rx_frame_error_o;

    // ---------------------------------------------------------
    // Generador de baud
    // ---------------------------------------------------------

    baud_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_baud (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .baud_tick_o(baud_tick)
    );

    // ---------------------------------------------------------
    // Transmisor
    // ---------------------------------------------------------

    uart_tx u_tx (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .baud_tick_i(baud_tick),
        .tx_data_i  (tx_data_i),
        .tx_start_i (tx_start_i),
        .tx_o       (tx_o),
        .tx_busy_o  (tx_busy_o),
        .tx_done_o  (tx_done_o)
    );

    // ---------------------------------------------------------
    // Receptor
    //
    // Loopback:
    //      TX serial -> RX serial
    // ---------------------------------------------------------

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_rx (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .rx_i           (tx_o),
        .rx_data_o      (rx_data_o),
        .rx_valid_o     (rx_valid_o),
        .rx_frame_error_o(rx_frame_error_o)
    );

    initial clk_i = 1'b0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // ---------------------------------------------------------
    // Enviar un byte y comprobar que RX recibe exactamente
    // el mismo valor.
    // ---------------------------------------------------------

    task automatic send_and_check(input logic [7:0] data);
        begin
            // Esperar a que TX esté disponible.
            while (tx_busy_o)
                @(posedge clk_i);

            // Aplicar datos antes del flanco de captura.
            @(negedge clk_i);
            tx_data_i  = data;
            tx_start_i = 1'b1;

            @(posedge clk_i);
            #1ns;

            tx_start_i = 1'b0;

            if (!tx_busy_o)
                $fatal(
                    1,
                    "FAIL: TX no inicio para 0x%02h",
                    data
                );

            // Esperar recepción.
            @(posedge rx_valid_o);
            #1ns;

            if (rx_data_o !== data)
                $fatal(
                    1,
                    "FAIL: enviado=0x%02h recibido=0x%02h",
                    data,
                    rx_data_o
                );

            if (rx_frame_error_o)
                $fatal(
                    1,
                    "FAIL: frame error inesperado para 0x%02h",
                    data
                );

            $display(
                "PASS: loopback 0x%02h -> 0x%02h",
                data,
                rx_data_o
            );

            // Esperar que TX termine completamente antes
            // de iniciar el siguiente byte.
            while (tx_busy_o)
                @(posedge clk_i);

            repeat (2) @(posedge clk_i);
        end
    endtask

    initial begin
        rst_i      = 1'b1;
        tx_data_i  = 8'h00;
        tx_start_i = 1'b0;

        repeat (4) @(posedge clk_i);

        @(negedge clk_i);
        rst_i = 1'b0;

        repeat (3) @(posedge clk_i);

        send_and_check(8'h00);
        send_and_check(8'hA5);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'hFF);

        $display(
            "PASS: todas las pruebas de loopback UART"
        );

        $finish;
    end

endmodule
