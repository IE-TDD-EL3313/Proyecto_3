// Generador del buzzer — ficha de cuarto nivel 7.8
// Fusiona: registro de control, selector de tono, divisor de frecuencia
//          y contador de duracion. Soporta tonos de una sola nota y
//          melodias cortas de varias notas en secuencia.
//
// Las notas se definen en Hz reales y milisegundos reales; el modulo
// calcula los ciclos de reloj necesarios a partir de CLK_FREQ_HZ, para
// que el diseno sea correcto sin importar la frecuencia real del reloj
// del sistema (y para poder simularlo rapido con un CLK_FREQ_HZ chico).
//
// Formato de wdata_i:
//   wdata_i[2:0] = tone_sel  (ver tabla de eventos abajo)
//   wdata_i[3]   = buzz_start (escribir 1 para disparar el tono/melodia)
//
// Decision de diseno: una nueva orden (buzz_start) siempre interrumpe el
// sonido en curso y comienza el nuevo tono de inmediato.

module buzzer_gen #(
    parameter int CLK_FREQ_HZ = 100_000_000
) (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [31:0] wdata_i, // tone_sel[2:0] + buzz_start (0x0001_0140)
    input  logic        we_i,
    output logic        buzz_pwm_o,
    output logic [31:0] rdata_o  // estado: bit[3]=sonando, [2:0]=tono actual (mux de lectura, P3 ficha 7.27)
);

    localparam int CYCLES_PER_MS = CLK_FREQ_HZ / 1000;
    localparam int DIV_WIDTH     = $clog2(CLK_FREQ_HZ) + 1;
    localparam int DUR_WIDTH     = $clog2(CYCLES_PER_MS * 1024) + 1; // margen para duraciones hasta ~1s

    // --- Tabla de eventos (frecuencia real en Hz, duracion real en ms) ---
    //   000 impacto        (1 nota,  200 Hz, 150 ms)
    //   001 fallo          (1 nota,  150 Hz, 150 ms)
    //   010 barco hundido  (2 notas, 300 Hz / 450 Hz, melodia ascendente corta)
    //   011 colocacion inv.(1 nota,  100 Hz, 200 ms)
    //   100 victoria       (4 notas, 300/400/500/600 Hz, fanfarria)

    typedef struct packed {
        logic [15:0] freq_hz;
        logic [15:0] duration_ms;
    } note_spec_t;

    function automatic logic [2:0] get_num_steps(input logic [2:0] sel);
        unique case (sel)
            3'b000:  get_num_steps = 3'd1;
            3'b001:  get_num_steps = 3'd1;
            3'b010:  get_num_steps = 3'd2;
            3'b011:  get_num_steps = 3'd1;
            3'b100:  get_num_steps = 3'd4;
            default: get_num_steps = 3'd1;
        endcase
    endfunction

    function automatic note_spec_t get_note_spec(input logic [2:0] sel, input logic [2:0] idx);
        note_spec_t s;
        unique case (sel)
            3'b000: begin s.freq_hz = 16'd200; s.duration_ms = 16'd150; end
            3'b001: begin s.freq_hz = 16'd150; s.duration_ms = 16'd150; end
            3'b010: begin
                unique case (idx)
                    3'd0:    begin s.freq_hz = 16'd300; s.duration_ms = 16'd100; end
                    default: begin s.freq_hz = 16'd450; s.duration_ms = 16'd150; end
                endcase
            end
            3'b011: begin s.freq_hz = 16'd100; s.duration_ms = 16'd200; end
            3'b100: begin
                unique case (idx)
                    3'd0:    begin s.freq_hz = 16'd300; s.duration_ms = 16'd120; end
                    3'd1:    begin s.freq_hz = 16'd400; s.duration_ms = 16'd120; end
                    3'd2:    begin s.freq_hz = 16'd500; s.duration_ms = 16'd120; end
                    default: begin s.freq_hz = 16'd600; s.duration_ms = 16'd300; end
                endcase
            end
            default: begin s.freq_hz = 16'd200; s.duration_ms = 16'd150; end
        endcase
        return s;
    endfunction

    function automatic logic [DIV_WIDTH-1:0] freq_to_div(input logic [15:0] freq_hz);
        unique case (freq_hz)
            16'd100: freq_to_div = CLK_FREQ_HZ / 200;
            16'd150: freq_to_div = CLK_FREQ_HZ / 300;
            16'd200: freq_to_div = CLK_FREQ_HZ / 400;
            16'd300: freq_to_div = CLK_FREQ_HZ / 600;
            16'd400: freq_to_div = CLK_FREQ_HZ / 800;
            16'd450: freq_to_div = CLK_FREQ_HZ / 900;
            16'd500: freq_to_div = CLK_FREQ_HZ / 1000;
            16'd600: freq_to_div = CLK_FREQ_HZ / 1200;
            default: freq_to_div = CLK_FREQ_HZ / 400;
        endcase
    endfunction

    function automatic logic [DUR_WIDTH-1:0] ms_to_cycles(input logic [15:0] duration_ms);
        return CYCLES_PER_MS * duration_ms;
    endfunction

    // --- Secuenciador: registro de control + contador de duracion por nota ---
    logic [2:0]           tone_sel_r;
    logic [2:0]           step_idx;
    logic [2:0]           num_steps_r;
    logic [DUR_WIDTH-1:0] duration_cnt;
    logic [DIV_WIDTH-1:0] div_value_r;
    logic                 sound_active;

    assign sound_active = (duration_cnt != 0);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            tone_sel_r   <= 3'b0;
            step_idx     <= 3'd0;
            num_steps_r  <= 3'd1;
            duration_cnt <= '0;
            div_value_r  <= '0;
        end else if (we_i && wdata_i[3]) begin
            // Nueva orden: interrumpe cualquier sonido/melodia en curso
            tone_sel_r   <= wdata_i[2:0];
            step_idx     <= 3'd0;
            num_steps_r  <= get_num_steps(wdata_i[2:0]);
            div_value_r  <= freq_to_div(get_note_spec(wdata_i[2:0], 3'd0).freq_hz);
            duration_cnt <= ms_to_cycles(get_note_spec(wdata_i[2:0], 3'd0).duration_ms);
        end else if (duration_cnt != 0) begin
            duration_cnt <= duration_cnt - 1'b1;
        end else if (step_idx != num_steps_r - 3'd1) begin
            // La nota actual termino y quedan mas notas en la melodia
            step_idx     <= step_idx + 3'd1;
            div_value_r  <= freq_to_div(get_note_spec(tone_sel_r, step_idx + 3'd1).freq_hz);
            duration_cnt <= ms_to_cycles(get_note_spec(tone_sel_r, step_idx + 3'd1).duration_ms);
        end
    end

    // --- Divisor de frecuencia: genera la onda cuadrada de la nota actual ---
    logic [DIV_WIDTH-1:0] div_cnt;
    logic                 tone_wave;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            div_cnt   <= '0;
            tone_wave <= 1'b0;
        end else if (sound_active) begin
            if (div_cnt >= div_value_r - 1'b1) begin
                div_cnt   <= '0;
                tone_wave <= ~tone_wave;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end else begin
            div_cnt   <= '0;
            tone_wave <= 1'b0;
        end
    end

    assign buzz_pwm_o = sound_active ? tone_wave : 1'b0;
    assign rdata_o     = {28'b0, sound_active, tone_sel_r};

endmodule
