// Top de integracion del sistema P3.
//
// Integra:
//   - Procesador RISC-V + ROM + RAM
//   - Decodificador MMIO
//   - UART
//   - Entradas del Jugador 1
//   - Displays de 7 segmentos
//   - LED
//   - Buzzer
//   - VGA
//   - Multiplexor de lectura MMIO

module sistema_top #(
    parameter ROM_FILE = "game.hex"
) (
    input  logic       clk_i,
    input  logic       rst_ni,

    // Entradas Jugador 1
    input  logic [6:0] btn_raw_i,

    // UART
    input  logic       uart_rx_i,
    output logic       uart_tx_o,

    // Displays
    output logic [6:0] seg_o,
    output logic [3:0] anode_o,

    // LED
    output logic [2:0] led_o,

    // Buzzer
    output logic       buzz_pwm_o,

    // VGA
    output logic       hsync_o,
    output logic       vsync_o,
    output logic [3:0] r_o,
    output logic [3:0] g_o,
    output logic [3:0] b_o

);

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------

    // El pulsador de reset de la Nexys 4 es activo en bajo.
    // Los modulos internos utilizan reset activo en alto.
    logic rst_i;
    assign rst_i = ~rst_ni;

    // ---------------------------------------------------------
    // Bus MMIO del procesador
    // ---------------------------------------------------------

    logic [31:0] mmio_addr;
    logic [31:0] mmio_wdata;
    logic [31:0] mmio_rdata;
    logic        mmio_sel;
    logic        mmio_we;

    // PC interno, disponible para depuracion en simulacion.
    // No se expone como puerto fisico de la FPGA.
    logic [31:0] pc_internal;

    // ---------------------------------------------------------
    // Clock enable del procesador
    // ---------------------------------------------------------
    // Todo el sistema permanece fisicamente a 100 MHz.
    // El CPU realiza un commit cada 4 ciclos: 25 MIPS max.
    logic [1:0] cpu_ce_cnt;
    logic       cpu_ce;

    always_ff @(posedge clk_i) begin
        if (rst_i)
            cpu_ce_cnt <= 2'b00;
        else
            cpu_ce_cnt <= cpu_ce_cnt + 2'b01;
    end

    assign cpu_ce = (cpu_ce_cnt == 2'b11);

    // ---------------------------------------------------------
    // Selecciones del decodificador
    // ---------------------------------------------------------

    logic sel_ram;
    logic sel_uart;
    logic sel_input;
    logic sel_display;
    logic sel_led;
    logic sel_buzzer;
    logic sel_vga_ctrl;
    logic sel_vga;

    logic we_ram;
    logic we_uart;
    logic we_display;
    logic we_led;
    logic we_buzzer;
    logic we_vga_ctrl;
    logic we_vga;

    // ---------------------------------------------------------
    // Datos de lectura
    // ---------------------------------------------------------

    logic [31:0] uart_rdata;
    logic [31:0] input_rdata;
    logic [31:0] display_rdata;
    logic [31:0] led_rdata;
    logic [31:0] buzzer_rdata;

    // VGA es actualmente de escritura.
    logic [31:0] vga_rdata;

    // Control visual del cursor VGA:
    // [7] visible, [6] tablero, [5:3] fila, [2:0] columna.
    logic [7:0] vga_cursor_ctrl;

    // Dirección local del periférico UART.
    logic [1:0] uart_addr;

    // Dirección local de palabra/tile VGA.
    logic [8:0] vga_addr;

    // ---------------------------------------------------------
    // Procesador + ROM + RAM
    // ---------------------------------------------------------

    processor_subsystem #(
        .ROM_FILE(ROM_FILE)
    ) u_processor (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .ce_i        (cpu_ce),
        .mmio_rdata_i(mmio_rdata),
        .mmio_addr_o (mmio_addr),
        .mmio_wdata_o(mmio_wdata),
        .mmio_sel_o  (mmio_sel),
        .mmio_we_o   (mmio_we),
        .pc_o        (pc_internal)
    );

    // ---------------------------------------------------------
    // Decodificador MMIO
    // ---------------------------------------------------------

    address_decoder u_decoder (
        .DataAddress_i(mmio_addr),
        .we_i         (mmio_we),

        .sel_ram_o    (sel_ram),
        .sel_uart_o   (sel_uart),
        .sel_input_o  (sel_input),
        .sel_display_o(sel_display),
        .sel_led_o    (sel_led),
        .sel_buzzer_o  (sel_buzzer),
        .sel_vga_ctrl_o(sel_vga_ctrl),
        .sel_vga_o     (sel_vga),

        .we_ram_o     (we_ram),
        .we_uart_o    (we_uart),
        .we_display_o (we_display),
        .we_led_o     (we_led),
        .we_buzzer_o   (we_buzzer),
        .we_vga_ctrl_o (we_vga_ctrl),
        .we_vga_o      (we_vga)
    );

    // ---------------------------------------------------------
    // UART
    //
    // 0x10040 -> 00 STATUS/CONTROL
    // 0x10044 -> 01 TX
    // 0x10048 -> 10 RX
    // ---------------------------------------------------------

    assign uart_addr = (mmio_addr - 32'h0001_0040) >> 2;

    uart_peripheral u_uart (
        .clk_i         (clk_i),
        .rst_i         (rst_i),
        .write_enable_i(we_uart),
        .addr_i        (uart_addr),
        .wdata_i       (mmio_wdata),
        .rdata_o       (uart_rdata),
        .uart_rx_i     (uart_rx_i),
        .uart_tx_o     (uart_tx_o)
    );

    // ---------------------------------------------------------
    // Perifericos locales
    // ---------------------------------------------------------

    perifericos_locales u_locales (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .btn_raw_i      (btn_raw_i),
        .input_ack_i    (sel_input && cpu_ce && !mmio_we),
        .rdata_input_o  (input_rdata),

        .disp_wdata_i   (mmio_wdata),
        .disp_we_i      (we_display),
        .seg_o          (seg_o),
        .anode_o        (anode_o),
        .rdata_display_o(display_rdata),

        .led_wdata_i    (mmio_wdata),
        .led_we_i       (we_led),
        .led_o          (led_o),
        .rdata_led_o    (led_rdata),

        .buzz_wdata_i   (mmio_wdata),
        .buzz_we_i      (we_buzzer),
        .buzz_pwm_o     (buzz_pwm_o),
        .rdata_buzzer_o (buzzer_rdata)
    );

    // ---------------------------------------------------------
    // Control de cursor VGA
    //
    // 0x00010148:
    //   bit 7    = visible
    //   bit 6    = tablero (0=J1, 1=J2)
    //   bits 5:3 = fila
    //   bits 2:0 = columna
    // ---------------------------------------------------------

    always_ff @(posedge clk_i) begin
        if (rst_i)
            vga_cursor_ctrl <= 8'b0;
        else if (we_vga_ctrl)
            vga_cursor_ctrl <= mmio_wdata[7:0];
    end

    // ---------------------------------------------------------
    // VGA
    //
    // Dirección del CPU expresada en bytes:
    //
    //   0x11000 -> tile 0
    //   0x11004 -> tile 1
    //   ...
    //
    // La memoria VGA ignora indices >= 300.
    // ---------------------------------------------------------

    assign vga_addr =
        (mmio_addr - 32'h0001_1000) >> 2;

    vga_periferico u_vga (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .vga_we_i    (we_vga),
        .vga_addr_i   (vga_addr),
        .vga_wdata_i  (mmio_wdata),
        .cursor_ctrl_i(vga_cursor_ctrl),
        .hsync_o      (hsync_o),
        .vsync_o     (vsync_o),
        .r_o         (r_o),
        .g_o         (g_o),
        .b_o         (b_o)
    );

    // VGA no implementa lectura MMIO actualmente.
    assign vga_rdata = 32'h0000_0000;

    // ---------------------------------------------------------
    // Multiplexor de lectura
    //
    // La RAM esta dentro de processor_subsystem, por lo que la
    // entrada RAM del mux externo permanece en cero.
    // ---------------------------------------------------------

    read_mux u_read_mux (
        .ram_rdata_i    (32'h0000_0000),
        .uart_rdata_i   (uart_rdata),
        .input_rdata_i  (input_rdata),
        .display_rdata_i(display_rdata),
        .led_rdata_i    (led_rdata),
        .buzzer_rdata_i (buzzer_rdata),
        .vga_rdata_i    (vga_rdata),

        .sel_ram_i      (1'b0),
        .sel_uart_i     (sel_uart),
        .sel_input_i    (sel_input),
        .sel_display_i  (sel_display),
        .sel_led_i      (sel_led),
        .sel_buzzer_i   (sel_buzzer),
        .sel_vga_i      (sel_vga),

        .DataIn_o       (mmio_rdata)
    );

endmodule
