// Periféricos locales — corresponde a la caja "Periféricos locales" del
// diagrama de tercer nivel. Instancia y conecta: condicionador de
// entradas de botones, controlador de displays, registro del LED y
// generador del buzzer.
//
// Interfaz alineada con el decodificador de direcciones y el
// multiplexor de lectura de P3 (ficha 7.26/7.27): cada periférico recibe
// su propio we_X ya calificado por dirección (sin addr_i, porque cada
// uno mapea a una sola palabra), y expone su propio rdata_X hacia el
// multiplexor de lectura central.

module perifericos_locales (
    input  logic        clk_i,      // 100 MHz
    input  logic        rst_i,

    // --- Entradas del Jugador 1 (solo lectura) ---
    input  logic [6:0]  btn_raw_i,
    output logic [31:0] rdata_input_o,

    // --- Displays de 7 segmentos ---
    input  logic [31:0] disp_wdata_i,
    input  logic        disp_we_i,
    output logic [6:0]  seg_o,
    output logic [3:0]  anode_o,
    output logic [31:0] rdata_display_o,

    // --- LED de estado ---
    input  logic [31:0] led_wdata_i,
    input  logic        led_we_i,
    output logic [2:0]  led_o,
    output logic [31:0] rdata_led_o,

    // --- Buzzer ---
    input  logic [31:0] buzz_wdata_i,
    input  logic        buzz_we_i,
    output logic        buzz_pwm_o,
    output logic [31:0] rdata_buzzer_o
);

    btn_input u_btn_input (
        .clk_i    (clk_i),
        .rst_i    (rst_i),
        .btn_raw_i(btn_raw_i),
        .rdata_o  (rdata_input_o)
    );

    seg7_ctrl u_seg7_ctrl (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .wdata_i(disp_wdata_i),
        .we_i   (disp_we_i),
        .seg_o  (seg_o),
        .anode_o(anode_o),
        .rdata_o(rdata_display_o)
    );

    led_reg u_led_reg (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .wdata_i(led_wdata_i),
        .we_i   (led_we_i),
        .led_o  (led_o),
        .rdata_o(rdata_led_o)
    );

    buzzer_gen u_buzzer_gen (
        .clk_i     (clk_i),
        .rst_i     (rst_i),
        .wdata_i   (buzz_wdata_i),
        .we_i      (buzz_we_i),
        .buzz_pwm_o(buzz_pwm_o),
        .rdata_o   (rdata_buzzer_o)
    );

endmodule
