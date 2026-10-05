// Transmisor UART 8N1.
//
// Formato:
//   - 1 bit de inicio (0)
//   - 8 bits de datos, LSB primero
//   - sin paridad
//   - 1 bit de parada (1)
//
// La temporizacion es proporcionada externamente mediante baud_tick_i.
//
// Una solicitud tx_start_i se captura inmediatamente, pero la trama
// comienza en el siguiente baud_tick. De esta forma todos los bits,
// incluido START, tienen exactamente un periodo de baud.

module uart_tx (
    input  logic       clk_i,
    input  logic       rst_i,

    input  logic       baud_tick_i,

    input  logic [7:0] tx_data_i,
    input  logic       tx_start_i,

    output logic       tx_o,
    output logic       tx_busy_o,
    output logic       tx_done_o
);

    logic [9:0] frame_r;
    logic [3:0] bit_idx_r;
    logic       started_r;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            frame_r   <= 10'b11_1111_1111;
            bit_idx_r <= 4'd0;
            started_r <= 1'b0;

            tx_o      <= 1'b1;
            tx_busy_o <= 1'b0;
            tx_done_o <= 1'b0;
        end else begin
            tx_done_o <= 1'b0;

            // Capturar una nueva solicitud.
            if (!tx_busy_o) begin
                tx_o <= 1'b1;

                if (tx_start_i) begin
                    frame_r   <= {1'b1, tx_data_i, 1'b0};
                    bit_idx_r <= 4'd0;
                    started_r <= 1'b0;
                    tx_busy_o <= 1'b1;
                end
            end

            // Transmision activa.
            else if (baud_tick_i) begin

                // Primer tick despues de tx_start:
                // comenzar START.
                if (!started_r) begin
                    tx_o      <= frame_r[0];
                    bit_idx_r <= 4'd0;
                    started_r <= 1'b1;
                end

                // START/DATA/STOP ya comenzaron.
                else if (bit_idx_r == 4'd9) begin
                    // STOP ya permanecio un periodo completo.
                    tx_o      <= 1'b1;
                    tx_busy_o <= 1'b0;
                    tx_done_o <= 1'b1;
                    bit_idx_r <= 4'd0;
                    started_r <= 1'b0;
                end

                else begin
                    bit_idx_r <= bit_idx_r + 1'b1;
                    tx_o      <= frame_r[bit_idx_r + 1'b1];
                end
            end
        end
    end

endmodule
