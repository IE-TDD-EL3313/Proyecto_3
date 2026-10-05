// Generador de baud para UART.
//
// Produce un pulso de un ciclo de clk_i por cada periodo de bit UART.
//
// Valores por defecto:
//   clk_i     = 100 MHz
//   BAUD_RATE = 115200
//
// Para 100 MHz / 115200:
//   DIVISOR = round(868.055...) = 868
//   baud real ~= 115207.37 baudios

module baud_gen #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic clk_i,
    input  logic rst_i,
    output logic baud_tick_o
);

    localparam int DIVISOR =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;

    localparam int CNT_WIDTH =
        (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

    logic [CNT_WIDTH-1:0] count_r;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            count_r     <= '0;
            baud_tick_o <= 1'b0;
        end else begin
            baud_tick_o <= 1'b0;

            if (count_r == DIVISOR - 1) begin
                count_r     <= '0;
                baud_tick_o <= 1'b1;
            end else begin
                count_r <= count_r + 1'b1;
            end
        end
    end

endmodule
