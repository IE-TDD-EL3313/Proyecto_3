// Generador de color y RGB — ficha de cuarto nivel 7.4
// Fusiona: decodificador de color + generador de señales RGB.
// Paleta propuesta (ajustar con el equipo, ver Sección 9 de la ficha).

module vga_color_rgb (
    input  logic [31:0] tile_data_i,
    input  logic        video_on_i,
    output logic [3:0]  r_o,
    output logic [3:0]  g_o,
    output logic [3:0]  b_o
);

    logic [2:0] color_index;
    assign color_index = tile_data_i[2:0];

    always_comb begin
        if (!video_on_i) begin
            // Blanking: negro absoluto, sin importar el color de la casilla
            {r_o, g_o, b_o} = '0;
        end else begin
            unique case (color_index)
                3'b000:  {r_o, g_o, b_o} = {4'd0,  4'd4,  4'd15}; // agua
                3'b001:  {r_o, g_o, b_o} = {4'd8,  4'd8,  4'd8 }; // barco propio
                3'b010:  {r_o, g_o, b_o} = {4'd15, 4'd0,  4'd0 }; // impacto
                3'b011:  {r_o, g_o, b_o} = {4'd15, 4'd15, 4'd15}; // fallo
                default: {r_o, g_o, b_o} = {4'd15, 4'd0,  4'd15}; // reservado/HUD: magenta de depuración
            endcase
        end
    end

endmodule
