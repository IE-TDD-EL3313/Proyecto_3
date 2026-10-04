// Generador de temporización VGA — ficha de cuarto nivel 7.2
// Fusiona: contador horizontal, contador vertical, generador HSYNC,
//          generador VSYNC y detector de región visible.
// Estándar: 640x480 @ 60Hz.

module vga_timing (
    input  logic        clk_pix_i,   // Reloj de píxel, 25 MHz (desde el PLL)
    input  logic        rst_i,
    output logic [9:0]  hcount_o,    // 0-799
    output logic [9:0]  vcount_o,    // 0-524
    output logic        hsync_o,     // activo en bajo
    output logic        vsync_o,     // activo en bajo
    output logic        video_on_o
);

    // Parámetros de temporización estándar 640x480@60Hz
    localparam int H_VISIBLE = 640;
    localparam int H_FRONT   = 16;
    localparam int H_SYNC    = 96;
    localparam int H_BACK    = 48;
    localparam int H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

    localparam int V_VISIBLE = 480;
    localparam int V_FRONT   = 10;
    localparam int V_SYNC    = 2;
    localparam int V_BACK    = 33;
    localparam int V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    logic [9:0] h_count, v_count;

    // Contador horizontal
    always_ff @(posedge clk_pix_i) begin
        if (rst_i) begin
            h_count <= '0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= '0;
        end else begin
            h_count <= h_count + 10'd1;
        end
    end

    // Contador vertical: solo avanza al completar una línea horizontal
    always_ff @(posedge clk_pix_i) begin
        if (rst_i) begin
            v_count <= '0;
        end else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= '0;
            else
                v_count <= v_count + 10'd1;
        end
    end

    // Sincronismos y región visible (combinacional)
    assign hsync_o = ~((h_count >= H_VISIBLE + H_FRONT) &&
                        (h_count <  H_VISIBLE + H_FRONT + H_SYNC));

    assign vsync_o = ~((v_count >= V_VISIBLE + V_FRONT) &&
                        (v_count <  V_VISIBLE + V_FRONT + V_SYNC));

    assign video_on_o = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    assign hcount_o = h_count;
    assign vcount_o = v_count;

endmodule
