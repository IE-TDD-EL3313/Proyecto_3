`timescale 1ns/1ps

module uart_rx_tb;

    localparam int CLK_FREQ_HZ  = 1_000_000;
    localparam int BAUD_RATE    = 100_000;
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam time CLK_PERIOD  = 1us;
    localparam time BIT_PERIOD  = CLKS_PER_BIT * CLK_PERIOD;

    logic       clk_i;
    logic       rst_i;
    logic       rx_i;
    logic [7:0] rx_data_o;
    logic       rx_valid_o;
    logic       rx_frame_error_o;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .clk_i           (clk_i),
        .rst_i           (rst_i),
        .rx_i            (rx_i),
        .rx_data_o       (rx_data_o),
        .rx_valid_o      (rx_valid_o),
        .rx_frame_error_o(rx_frame_error_o)
    );

    initial clk_i = 1'b0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // Envia una trama UART 8N1.
    task automatic send_uart_byte(
        input logic [7:0] data,
        input logic       valid_stop
    );
        integer i;
        begin
            // Idle previo
            rx_i = 1'b1;
            #(2 * BIT_PERIOD);

            // Start
            rx_i = 1'b0;
            #(BIT_PERIOD);

            // 8 bits de datos, LSB primero
            for (i = 0; i < 8; i = i + 1) begin
                rx_i = data[i];
                #(BIT_PERIOD);
            end

            // Stop
            rx_i = valid_stop;
            #(BIT_PERIOD);

            // Regreso a idle
            rx_i = 1'b1;
            #(2 * BIT_PERIOD);
        end
    endtask

    initial begin
        rst_i = 1'b1;
        rx_i  = 1'b1;

        repeat (4) @(posedge clk_i);
        rst_i = 1'b0;

        repeat (3) @(posedge clk_i);

        // -------------------------------------------------
        // Prueba 1: recepcion valida de 0xA5
        // -------------------------------------------------
        fork
            begin
                send_uart_byte(8'hA5, 1'b1);
            end

            begin
                @(posedge rx_valid_o);

                if (rx_data_o !== 8'hA5) begin
                    $fatal(
                        1,
                        "FAIL: esperado 0xA5, recibido 0x%02h",
                        rx_data_o
                    );
                end

                $display(
                    "PASS: uart_rx recibe 0xA5 correctamente"
                );
            end
        join

        // -------------------------------------------------
        // Prueba 2: stop bit invalido
        // -------------------------------------------------
        fork
            begin
                send_uart_byte(8'h3C, 1'b0);
            end

            begin
                @(posedge rx_frame_error_o);

                $display(
                    "PASS: uart_rx detecta stop bit invalido"
                );
            end
        join

        repeat (3) @(posedge clk_i);

        $display("PASS: todas las pruebas de uart_rx");
        $finish;
    end

endmodule
