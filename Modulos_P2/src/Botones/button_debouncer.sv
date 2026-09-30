module button_debouncer #(
    parameter integer DEBOUNCE_MS = 10
) (
    input  logic clk,
    input  logic reset,
    input  logic ce_1ms,
    input  logic button_sync,
    output logic button_level
);

    localparam integer COUNTER_WIDTH =
        (DEBOUNCE_MS <= 1) ? 1 : $clog2(DEBOUNCE_MS);

    logic [COUNTER_WIDTH-1:0] stable_counter;

    always_ff @(posedge clk) begin
        if (reset) begin
            stable_counter <= '0;
            button_level   <= 1'b0;
        end else if (ce_1ms) begin
            if (button_sync == button_level) begin
                stable_counter <= '0;
            end else if (stable_counter == DEBOUNCE_MS - 1) begin
                button_level   <= button_sync;
                stable_counter <= '0;
            end else begin
                stable_counter <= stable_counter + 1'b1;
            end
        end
    end

endmodule
