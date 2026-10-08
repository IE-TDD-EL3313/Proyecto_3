// Generador de color y RGB — ficha de cuarto nivel 7.4
// Renderiza dos tableros 8x8 con cuadrícula independiente
// y permite representar caracteres en tiles del HUD.

module vga_color_rgb (
    input  logic [31:0] tile_data_i,
    input  logic        video_on_i,
    input  logic [4:0]  pixel_x_i,
    input  logic [4:0]  pixel_y_i,
    input  logic [4:0]  tile_col_i,
    input  logic [3:0]  tile_row_i,
    input  logic [7:0]  cursor_ctrl_i,
    output logic [3:0]  r_o,
    output logic [3:0]  g_o,
    output logic [3:0]  b_o
);

    logic [2:0] color_index;

    logic       grid_line;
    logic       board_j1;
    logic       board_j2;
    logic       inside_board;

    logic       cursor_visible;
    logic       cursor_board;
    logic [2:0] cursor_row;
    logic [2:0] cursor_col;
    logic [4:0] cursor_tile_col;
    logic [3:0] cursor_tile_row;
    logic       cursor_tile;
    logic       cursor_border;

    // ---------------------------------------------------------
    // HUD / texto
    //
    // tile_data_i:
    //   [2:0]   color
    //   [10:3]  código ASCII
    //   [11]    TEXT_ENABLE
    // ---------------------------------------------------------

    logic       text_enable;
    logic [7:0] text_char;
    logic       text_pixel;
    logic [2:0] font_x;
    logic [2:0] font_y;

    assign color_index = tile_data_i[2:0];

    assign text_enable = tile_data_i[11];
    assign text_char   = tile_data_i[10:3];

    // Cada carácter 8x8 ocupa un tile completo de 32x32.
    // Cada píxel de la fuente se escala 4x4.
    assign font_x = pixel_x_i[4:2];
    assign font_y = pixel_y_i[4:2];

    // ---------------------------------------------------------
    // Tableros
    // ---------------------------------------------------------

    // Tablero J1: columnas 1..8, filas 6..13.
    assign board_j1 =
        (tile_col_i >= 5'd1)  && (tile_col_i <= 5'd8) &&
        (tile_row_i >= 4'd6)  && (tile_row_i <= 4'd13);

    // Tablero J2: columnas 11..18, filas 6..13.
    assign board_j2 =
        (tile_col_i >= 5'd11) && (tile_col_i <= 5'd18) &&
        (tile_row_i >= 4'd6)  && (tile_row_i <= 4'd13);

    assign inside_board = board_j1 || board_j2;

    // ---------------------------------------------------------
    // Cursor
    //
    // cursor_ctrl_i:
    //   [7]   visible
    //   [6]   tablero: 0=J1, 1=J2
    //   [5:3] fila lógica 0..7
    //   [2:0] columna lógica 0..7
    // ---------------------------------------------------------

    assign cursor_visible = cursor_ctrl_i[7];
    assign cursor_board   = cursor_ctrl_i[6];
    assign cursor_row     = cursor_ctrl_i[5:3];
    assign cursor_col     = cursor_ctrl_i[2:0];

    assign cursor_tile_col =
        cursor_board ? (5'd11 + {2'b00, cursor_col})
                     : (5'd1  + {2'b00, cursor_col});

    assign cursor_tile_row =
        4'd6 + {1'b0, cursor_row};

    assign cursor_tile =
        cursor_visible &&
        (tile_col_i == cursor_tile_col) &&
        (tile_row_i == cursor_tile_row);

    // Borde de 2 píxeles dentro de la casilla seleccionada.
    assign cursor_border =
        cursor_tile &&
        ((pixel_x_i <= 5'd1) || (pixel_x_i >= 5'd30) ||
         (pixel_y_i <= 5'd1) || (pixel_y_i >= 5'd30));

    // Separación visual entre casillas de 32x32 píxeles.
    assign grid_line = (pixel_x_i == 5'd0) ||
                       (pixel_y_i == 5'd0);

    // ---------------------------------------------------------
    // Fuente
    // ---------------------------------------------------------

    vga_font u_font (
        .char_code_i(text_char),
        .pixel_x_i  (font_x),
        .pixel_y_i  (font_y),
        .pixel_on_o (text_pixel)
    );

    // ---------------------------------------------------------
    // Generación RGB
    // ---------------------------------------------------------

    always_comb begin

        // Valor por defecto.
        {r_o, g_o, b_o} = 12'b0;

        if (!video_on_i) begin
            {r_o, g_o, b_o} = 12'b0;

        end else if (text_enable) begin
            // Texto del HUD.
            if (text_pixel)
                {r_o, g_o, b_o} = {4'd15, 4'd15, 4'd15};
            else
                {r_o, g_o, b_o} = {4'd0, 4'd0, 4'd0};

        end else if (!inside_board) begin
            // Fondo fuera de los dos tableros.
            {r_o, g_o, b_o} = {4'd0, 4'd0, 4'd0};

        end else if (cursor_border) begin
            // Cursor amarillo, superpuesto sin modificar la memoria VGA.
            {r_o, g_o, b_o} = {4'd15, 4'd15, 4'd0};

        end else if (grid_line) begin
            // Cuadrícula.
            {r_o, g_o, b_o} = {4'd0, 4'd0, 4'd0};

        end else begin

            unique case (color_index)

                3'b000:
                    {r_o, g_o, b_o} = {4'd0, 4'd4, 4'd15}; // agua

                3'b001:
                    {r_o, g_o, b_o} = {4'd8, 4'd8, 4'd8}; // barco

                3'b010:
                    {r_o, g_o, b_o} = {4'd15, 4'd0, 4'd0}; // impacto

                3'b011:
                    {r_o, g_o, b_o} = {4'd15, 4'd15, 4'd15}; // fallo

                default:
                    {r_o, g_o, b_o} = {4'd15, 4'd0, 4'd15}; // depuración

            endcase

        end
    end

endmodule
