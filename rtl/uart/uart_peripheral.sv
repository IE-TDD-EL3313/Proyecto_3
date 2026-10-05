// Periferico UART con interfaz MMIO.
//
// Mapa interno:
//   addr_i = 2'b00 : STATUS
//   addr_i = 2'b01 : TX
//   addr_i = 2'b10 : RX
//
// STATUS:
//   bit 0 : TX_BUSY
//   bit 1 : RX_VALID (dato recibido pendiente de lectura)
//   bit 2 : RX_FRAME_ERROR
//
// TX:
//   escritura en addr_i=01 transmite wdata_i[7:0]
//
// RX:
//   lectura en addr_i=10 entrega el ultimo byte valido recibido.
//
// RX_VALID permanece activo hasta que el procesador lee RX.

module uart_peripheral #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,

    output logic [31:0] rdata_o,

    input  logic        uart_rx_i,
    output logic        uart_tx_o
);

    logic baud_tick;

    logic [7:0] tx_data_r;
    logic       tx_start;
    logic       tx_busy;
    logic       tx_done;

    logic [7:0] rx_data;
    logic       rx_valid;
    logic       rx_frame_error;

    logic [7:0] rx_data_r;
    logic       rx_pending_r;
    logic       rx_frame_error_r;

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
    // UART TX
    // ---------------------------------------------------------

    uart_tx u_tx (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .baud_tick_i(baud_tick),
        .tx_data_i  (tx_data_r),
        .tx_start_i (tx_start),
        .tx_o       (uart_tx_o),
        .tx_busy_o  (tx_busy),
        .tx_done_o  (tx_done)
    );

    // ---------------------------------------------------------
    // UART RX
    // ---------------------------------------------------------

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_rx (
        .clk_i           (clk_i),
        .rst_i           (rst_i),
        .rx_i            (uart_rx_i),
        .rx_data_o       (rx_data),
        .rx_valid_o      (rx_valid),
        .rx_frame_error_o(rx_frame_error)
    );

    // ---------------------------------------------------------
    // Registro TX y solicitud de transmision
    // ---------------------------------------------------------

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            tx_data_r <= 8'h00;
            tx_start  <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            // Ignorar escrituras mientras TX esta ocupado.
            if (write_enable_i &&
                (addr_i == 2'b01) &&
                !tx_busy) begin

                tx_data_r <= wdata_i[7:0];
                tx_start  <= 1'b1;
            end
        end
    end

    // ---------------------------------------------------------
    // Registro RX y estado persistente
    // ---------------------------------------------------------

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rx_data_r        <= 8'h00;
            rx_pending_r     <= 1'b0;
            rx_frame_error_r <= 1'b0;
        end else begin

            // Escritura en CONTROL/STATUS:
            // bit 1 limpia RX_VALID.
            // bit 2 limpia RX_FRAME_ERROR.
            if (write_enable_i && (addr_i == 2'b00)) begin
                if (wdata_i[1])
                    rx_pending_r <= 1'b0;

                if (wdata_i[2])
                    rx_frame_error_r <= 1'b0;
            end

            // Un nuevo byte valido tiene prioridad sobre el borrado.
            if (rx_valid) begin
                rx_data_r        <= rx_data;
                rx_pending_r     <= 1'b1;
                rx_frame_error_r <= 1'b0;
            end

            // Un nuevo error tiene prioridad sobre el borrado.
            if (rx_frame_error) begin
                rx_frame_error_r <= 1'b1;
            end
        end
    end

    // ---------------------------------------------------------
    // Lectura MMIO
    // ---------------------------------------------------------

    always_comb begin
        rdata_o = 32'h0000_0000;

        case (addr_i)

            // STATUS
            2'b00: begin
                rdata_o[0] = tx_busy;
                rdata_o[1] = rx_pending_r;
                rdata_o[2] = rx_frame_error_r;
            end

            // TX: lectura no necesaria.
            2'b01: begin
                rdata_o = 32'h0000_0000;
            end

            // RX
            2'b10: begin
                rdata_o = {24'h000000, rx_data_r};
            end

            default: begin
                rdata_o = 32'h0000_0000;
            end

        endcase
    end

endmodule
