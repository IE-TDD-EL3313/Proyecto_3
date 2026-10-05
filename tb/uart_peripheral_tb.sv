`timescale 1ns/1ps

module uart_peripheral_tb;

    localparam int CLK_FREQ_HZ = 1_000_000;
    localparam int BAUD_RATE   = 100_000;
    localparam int CLKS_PER_BIT =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;

    localparam time CLK_PERIOD = 1us;
    localparam time BIT_PERIOD = CLK_PERIOD * CLKS_PER_BIT;

    logic clk_i;
    logic rst_i;

    logic        write_enable_i;
    logic [1:0]  addr_i;
    logic [31:0] wdata_i;
    logic [31:0] rdata_o;

    logic uart_rx_i;
    logic uart_tx_o;

    uart_peripheral #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .clk_i         (clk_i),
        .rst_i         (rst_i),
        .write_enable_i(write_enable_i),
        .addr_i        (addr_i),
        .wdata_i       (wdata_i),
        .rdata_o       (rdata_o),
        .uart_rx_i     (uart_rx_i),
        .uart_tx_o     (uart_tx_o)
    );

    initial clk_i = 1'b0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // ---------------------------------------------------------
    // Escritura MMIO
    // ---------------------------------------------------------

    task automatic mmio_write(
        input logic [1:0]  address,
        input logic [31:0] data
    );
        begin
            @(negedge clk_i);
            addr_i         = address;
            wdata_i        = data;
            write_enable_i = 1'b1;

            @(posedge clk_i);
            #1ns;

            @(negedge clk_i);
            write_enable_i = 1'b0;
            wdata_i        = 32'h0000_0000;
        end
    endtask

    // ---------------------------------------------------------
    // Enviar byte serial hacia RX del periférico
    // ---------------------------------------------------------

    task automatic serial_send(input logic [7:0] data);
        integer i;
        begin
            // START
            uart_rx_i = 1'b0;
            #(BIT_PERIOD);

            // 8 bits LSB primero
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_i = data[i];
                #(BIT_PERIOD);
            end

            // STOP
            uart_rx_i = 1'b1;
            #(BIT_PERIOD);

            // margen
            #(BIT_PERIOD);
        end
    endtask

    // ---------------------------------------------------------
    // Test
    // ---------------------------------------------------------

    initial begin
        rst_i          = 1'b1;
        write_enable_i = 1'b0;
        addr_i         = 2'b00;
        wdata_i        = 32'h0000_0000;
        uart_rx_i      = 1'b1;

        repeat (4) @(posedge clk_i);

        @(negedge clk_i);
        rst_i = 1'b0;

        repeat (3) @(posedge clk_i);
        #1ns;

        // -----------------------------------------------------
        // 1. STATUS después de reset
        // -----------------------------------------------------

        addr_i = 2'b00;
        #1ns;

        if (rdata_o[2:0] !== 3'b000)
            $fatal(
                1,
                "FAIL: STATUS tras reset = %03b",
                rdata_o[2:0]
            );

        $display("PASS: STATUS correcto despues de reset");

        // -----------------------------------------------------
        // 2. Escritura en TX
        // -----------------------------------------------------

        mmio_write(2'b01, 32'h0000_00A5);

        // tx_start se registra en uart_peripheral.
        // uart_tx lo observa en el siguiente flanco de clk_i.
        @(posedge clk_i);
        #1ns;

        // TX debe quedar ocupado.
        addr_i = 2'b00;
        #1ns;

        if (rdata_o[0] !== 1'b1)
            $fatal(
                1,
                "FAIL: TX_BUSY no se activo"
            );

        $display("PASS: escritura MMIO activa TX_BUSY");

        // Esperar comienzo físico de START.
        @(negedge uart_tx_o);

        // Muestrear aproximadamente en el centro de cada bit.
        #(BIT_PERIOD/2);

        if (uart_tx_o !== 1'b0)
            $fatal(1, "FAIL: START incorrecto");

        // A5 = 10100101, LSB primero:
        // 1 0 1 0 0 1 0 1

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b1)
            $fatal(1, "FAIL: TX D0");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b0)
            $fatal(1, "FAIL: TX D1");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b1)
            $fatal(1, "FAIL: TX D2");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b0)
            $fatal(1, "FAIL: TX D3");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b0)
            $fatal(1, "FAIL: TX D4");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b1)
            $fatal(1, "FAIL: TX D5");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b0)
            $fatal(1, "FAIL: TX D6");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b1)
            $fatal(1, "FAIL: TX D7");

        #(BIT_PERIOD);
        if (uart_tx_o !== 1'b1)
            $fatal(1, "FAIL: STOP incorrecto");

        $display("PASS: TX MMIO transmite 0xA5 correctamente");

        // Esperar final completo.
        wait (dut.tx_busy == 1'b0);
        @(posedge clk_i);
        #1ns;

        addr_i = 2'b00;
        #1ns;

        if (rdata_o[0] !== 1'b0)
            $fatal(1, "FAIL: TX_BUSY no regreso a cero");

        $display("PASS: TX_BUSY regresa a cero");

        // -----------------------------------------------------
        // 3. Recepción serial
        // -----------------------------------------------------

        serial_send(8'h5A);

        repeat (3) @(posedge clk_i);

        // STATUS
        addr_i = 2'b00;
        #1ns;

        if (rdata_o[1] !== 1'b1)
            $fatal(
                1,
                "FAIL: RX_VALID no se activo"
            );

        if (rdata_o[2] !== 1'b0)
            $fatal(
                1,
                "FAIL: RX_FRAME_ERROR inesperado"
            );

        $display("PASS: RX_VALID se mantiene activo");

        // Leer RX.
        addr_i = 2'b10;
        #1ns;

        if (rdata_o[7:0] !== 8'h5A)
            $fatal(
                1,
                "FAIL: RX esperado=0x5A obtenido=0x%02h",
                rdata_o[7:0]
            );

        $display("PASS: lectura MMIO RX = 0x5A");

        // -----------------------------------------------------
        // 4. Limpiar RX_VALID mediante CONTROL
        // -----------------------------------------------------

        mmio_write(
            2'b00,
            32'h0000_0002
        );

        addr_i = 2'b00;
        #1ns;

        if (rdata_o[1] !== 1'b0)
            $fatal(
                1,
                "FAIL: RX_VALID no se limpio"
            );

        $display("PASS: RX_VALID se limpia mediante CONTROL");

        // -----------------------------------------------------
        // 5. Dirección interna inválida
        // -----------------------------------------------------

        addr_i = 2'b11;
        #1ns;

        if (rdata_o !== 32'h0000_0000)
            $fatal(
                1,
                "FAIL: direccion invalida no retorna cero"
            );

        $display("PASS: direccion MMIO interna invalida retorna cero");

        $display("PASS: todas las pruebas de uart_peripheral");

        $finish;
    end

endmodule
