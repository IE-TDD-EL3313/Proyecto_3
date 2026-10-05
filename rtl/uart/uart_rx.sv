// Receptor UART.
//
// Formato:
//   - 1 bit de inicio (0)
//   - 8 bits de datos, LSB primero
//   - sin paridad
//   - 1 bit de parada (1)
//
// Configuracion por defecto:
//   CLK_FREQ_HZ = 100 MHz
//   BAUD_RATE   = 115200
//
// rx_valid_o genera un pulso de un ciclo cuando se recibe
// correctamente un byte.
// rx_frame_error_o genera un pulso si el bit de parada no es valido.

module uart_rx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic       clk_i,
    input  logic       rst_i,

    input  logic       rx_i,

    output logic [7:0] rx_data_o,
    output logic       rx_valid_o,
    output logic       rx_frame_error_o
);

    localparam int CLKS_PER_BIT =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;

    localparam int HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;

    localparam int BAUD_CNT_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state_r;

    logic [BAUD_CNT_WIDTH-1:0] baud_cnt;
    logic [2:0]                bit_idx;
    logic [7:0]                data_r;

    // Sincronizador de dos etapas para la entrada asincrona RX.
    logic rx_meta_r;
    logic rx_sync_r;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rx_meta_r <= 1'b1;
            rx_sync_r <= 1'b1;
        end else begin
            rx_meta_r <= rx_i;
            rx_sync_r <= rx_meta_r;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_r          <= IDLE;
            baud_cnt         <= '0;
            bit_idx          <= '0;
            data_r           <= '0;
            rx_data_o        <= '0;
            rx_valid_o       <= 1'b0;
            rx_frame_error_o <= 1'b0;
        end else begin
            rx_valid_o       <= 1'b0;
            rx_frame_error_o <= 1'b0;

            case (state_r)

                IDLE: begin
                    baud_cnt <= '0;
                    bit_idx  <= '0;

                    if (!rx_sync_r) begin
                        state_r <= START;
                    end
                end

                START: begin
                    // Confirmar el bit de inicio aproximadamente
                    // en su centro para rechazar pulsos espurios.
                    if (baud_cnt == HALF_CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;

                        if (!rx_sync_r) begin
                            state_r <= DATA;
                        end else begin
                            state_r <= IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt       <= '0;
                        data_r[bit_idx] <= rx_sync_r;

                        if (bit_idx == 3'd7) begin
                            bit_idx <= '0;
                            state_r <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        state_r  <= IDLE;

                        if (rx_sync_r) begin
                            rx_data_o  <= data_r;
                            rx_valid_o <= 1'b1;
                        end else begin
                            rx_frame_error_o <= 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: begin
                    state_r  <= IDLE;
                    baud_cnt <= '0;
                    bit_idx  <= '0;
                end

            endcase
        end
    end

endmodule
