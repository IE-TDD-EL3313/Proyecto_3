// Generador de sonidos para buzzer activo de corriente continua.
// EL3313 - Proyecto 3: Batalla Naval
//
// Registro de control:
//   wdata_i[2:0] = seleccion del evento
//   wdata_i[3]   = iniciar sonido
//
// Eventos:
//   000: impacto             -> 1 pitido de 150 ms
//   001: fallo               -> 2 pitidos de 100 ms
//   010: barco hundido       -> 3 pitidos de 120 ms
//   011: colocacion invalida -> 1 pitido de 400 ms
//   100: victoria            -> 5 pitidos de 150 ms
//
// Una nueva orden interrumpe el patron anterior.

module buzzer_gen #(
    parameter int CLK_FREQ_HZ = 100_000_000
)(
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    output logic        buzz_pwm_o,
    output logic [31:0] rdata_o
);

    localparam int CYCLES_PER_MS = CLK_FREQ_HZ / 1000;
    localparam int COUNTER_WIDTH = $clog2(CYCLES_PER_MS * 500 + 1);

    typedef enum logic [1:0] {
        IDLE,
        BEEP_ON,
        BEEP_OFF
    } state_t;

    state_t state;

    logic [2:0] tone_sel_r;
    logic [2:0] beep_count;
    logic [2:0] total_beeps;

    logic [COUNTER_WIDTH-1:0] timer;
    logic [15:0] on_duration_ms;
    logic [15:0] off_duration_ms;

    function automatic logic [2:0] get_beeps(input logic [2:0] sel);
        case (sel)
            3'b000: get_beeps = 3'd1;
            3'b001: get_beeps = 3'd2;
            3'b010: get_beeps = 3'd3;
            3'b011: get_beeps = 3'd1;
            3'b100: get_beeps = 3'd5;
            default: get_beeps = 3'd1;
        endcase
    endfunction

    function automatic logic [15:0] get_on_ms(input logic [2:0] sel);
        case (sel)
            3'b000: get_on_ms = 16'd150;
            3'b001: get_on_ms = 16'd100;
            3'b010: get_on_ms = 16'd120;
            3'b011: get_on_ms = 16'd400;
            3'b100: get_on_ms = 16'd150;
            default: get_on_ms = 16'd150;
        endcase
    endfunction

    function automatic logic [15:0] get_off_ms(input logic [2:0] sel);
        case (sel)
            3'b000: get_off_ms = 16'd0;
            3'b001: get_off_ms = 16'd120;
            3'b010: get_off_ms = 16'd100;
            3'b011: get_off_ms = 16'd0;
            3'b100: get_off_ms = 16'd80;
            default: get_off_ms = 16'd0;
        endcase
    endfunction

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state           <= IDLE;
            tone_sel_r      <= 3'd0;
            beep_count      <= 3'd0;
            total_beeps     <= 3'd0;
            timer           <= '0;
            on_duration_ms  <= 16'd0;
            off_duration_ms <= 16'd0;
        end else if (we_i && wdata_i[3]) begin
            // Una nueva orden reinicia el patron.
            tone_sel_r      <= wdata_i[2:0];
            total_beeps     <= get_beeps(wdata_i[2:0]);
            on_duration_ms  <= get_on_ms(wdata_i[2:0]);
            off_duration_ms <= get_off_ms(wdata_i[2:0]);

            beep_count <= 3'd1;
            timer      <= CYCLES_PER_MS * get_on_ms(wdata_i[2:0]) - 1;
            state      <= BEEP_ON;
        end else begin
            case (state)

                IDLE: begin
                    timer <= '0;
                end

                BEEP_ON: begin
                    if (timer != 0) begin
                        timer <= timer - 1'b1;
                    end else if (beep_count >= total_beeps) begin
                        state <= IDLE;
                    end else begin
                        timer <= CYCLES_PER_MS * off_duration_ms - 1;
                        state <= BEEP_OFF;
                    end
                end

                BEEP_OFF: begin
                    if (timer != 0) begin
                        timer <= timer - 1'b1;
                    end else begin
                        beep_count <= beep_count + 1'b1;
                        timer <= CYCLES_PER_MS * on_duration_ms - 1;
                        state <= BEEP_ON;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

    // El buzzer activo suena cuando recibe un nivel alto.
    assign buzz_pwm_o = (state == BEEP_ON);

    // Estado compatible con el registro original.
    // bit 3: sonido activo; bits 2:0: evento seleccionado.
    assign rdata_o = {28'b0, (state != IDLE), tone_sel_r};

endmodule
