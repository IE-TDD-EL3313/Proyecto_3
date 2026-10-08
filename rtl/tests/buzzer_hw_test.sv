module buzzer_hw_test (
    input  logic clk_i,
    output logic buzz_pwm_o
);

    // Reloj de 100 MHz.
    // Cambia el estado cada segundo.
    logic [26:0] contador = 27'd0;
    logic estado = 1'b0;

    always_ff @(posedge clk_i) begin
        if (contador == 27'd99_999_999) begin
            contador <= 27'd0;
            estado   <= ~estado;
        end else begin
            contador <= contador + 1'b1;
        end
    end

    assign buzz_pwm_o = estado;

endmodule
