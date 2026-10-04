// Periférico VGA completo — corresponde a la caja "Periférico VGA" del
// diagrama de tercer nivel. Instancia y conecta: PLL, temporización,
// memoria de video y generador de color/RGB.
//
// Este es el único módulo que el resto del sistema (decodificador MMIO,
// top-level) necesita instanciar para tener el periférico VGA completo.

module vga_periferico (
    input  logic        clk_i,        // 100 MHz, reloj del sistema
    input  logic        rst_i,

    // Interfaz de escritura desde el CPU (vía decodificador MMIO)
    input  logic        vga_we_i,
    input  logic [8:0]  vga_addr_i,
    input  logic [31:0] vga_wdata_i,

    // Salida física hacia el monitor
    output logic        hsync_o,
    output logic        vsync_o,
    output logic [3:0]  r_o,
    output logic [3:0]  g_o,
    output logic [3:0]  b_o
);

    // --- Señales internas entre subbloques ---
    logic        clk_pix;
    logic        pll_locked;
    logic        rst_pix;      // reset del dominio de video: externo + "aún no locked"

    logic [9:0]  hcount, vcount;
    logic        video_on;
    logic [31:0] tile_data;
    logic        video_on_d;

    assign rst_pix = rst_i | ~pll_locked;

    // Compensación de la latencia de lectura de la memoria de video
    always_ff @(posedge clk_pix) begin
        if (rst_pix)
            video_on_d <= 1'b0;
        else
            video_on_d <= video_on;
    end

    // --- Generador de reloj de píxel ---
    // Clocking Wizard: 100 MHz -> 25 MHz
    clk_wiz_pixel u_pll (
        .clk_in1  (clk_i),
        .reset    (rst_i),
        .clk_out1 (clk_pix),
        .locked   (pll_locked)
    );

    // --- Generador de temporización ---
    vga_timing u_timing (
        .clk_pix_i (clk_pix),
        .rst_i     (rst_pix),
        .hcount_o  (hcount),
        .vcount_o  (vcount),
        .hsync_o   (hsync_o),
        .vsync_o   (vsync_o),
        .video_on_o(video_on)
    );

    // --- Memoria de video (doble puerto, doble reloj) ---
    vga_memory u_memory (
        .clk_i      (clk_i),
        .vga_we_i   (vga_we_i),
        .vga_addr_i (vga_addr_i),
        .vga_wdata_i(vga_wdata_i),
        .clk_pix_i  (clk_pix),
        .hcount_i   (hcount),
        .vcount_i   (vcount),
        .tile_data_o(tile_data)
    );

    // --- Generador de color y RGB ---
    vga_color_rgb u_color (
        .tile_data_i(tile_data),
        .video_on_i (video_on_d),
        .r_o        (r_o),
        .g_o        (g_o),
        .b_o        (b_o)
    );

endmodule
