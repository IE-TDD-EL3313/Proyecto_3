// Generador de color y RGB — ficha de cuarto nivel 7.4
// Renderiza dos tableros 8x8 con cuadricula independiente.

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

    assign color_index = tile_data_i[2:0];

    // Tablero J1: columnas 1..8, filas 3..10.
    assign board_j1 =
        (tile_col_i >= 5'd1)  && (tile_col_i <= 5'd8) &&
        (tile_row_i >= 4'd3)  && (tile_row_i <= 4'd10);

    // Tablero J2: columnas 11..18, filas 3..10.
    assign board_j2 =
        (tile_col_i >= 5'd11) && (tile_col_i <= 5'd18) &&
        (tile_row_i >= 4'd3)  && (tile_row_i <= 4'd10);

    assign inside_board = board_j1 || board_j2;

    // ---------------------------------------------------------
    // Cursor
    //
    // cursor_ctrl_i:
    //   [7]   visible
    //   [6]   tablero: 0=J1, 1=J2
    //   [5:3] fila logica 0..7
    //   [2:0] columna logica 0..7
    // ---------------------------------------------------------

    assign cursor_visible = cursor_ctrl_i[7];
    assign cursor_board   = cursor_ctrl_i[6];
    assign cursor_row     = cursor_ctrl_i[5:3];
    assign cursor_col     = cursor_ctrl_i[2:0];

    assign cursor_tile_col =
        cursor_board ? (5'd11 + {2'b00, cursor_col})
                     : (5'd1  + {2'b00, cursor_col});

    assign cursor_tile_row =
        4'd3 + {1'b0, cursor_row};

    assign cursor_tile =
        cursor_visible &&
        (tile_col_i == cursor_tile_col) &&
        (tile_row_i == cursor_tile_row);

    // Borde de 2 pixeles dentro de la casilla seleccionada.
    assign cursor_border =
        cursor_tile &&
        ((pixel_x_i <= 5'd1) || (pixel_x_i >= 5'd30) ||
         (pixel_y_i <= 5'd1) || (pixel_y_i >= 5'd30));

    // Separacion visual entre casillas de 32x32 pixeles.
    assign grid_line = (pixel_x_i == 5'd0) ||
                       (pixel_y_i == 5'd0);

    always_comb begin
        if (!video_on_i) begin
            {r_o, g_o, b_o} = '0;

        end else if (!inside_board) begin
            // Fondo fuera de los dos tableros.
            {r_o, g_o, b_o} = {4'd0, 4'd0, 4'd0};

        end else if (cursor_border) begin
            // Cursor amarillo, superpuesto sin modificar la memoria VGA.
            {r_o, g_o, b_o} = {4'd15, 4'd15, 4'd0};

        end else if (grid_line) begin
            // Cuadricula.
            {r_o, g_o, b_o} = {4'd0, 4'd0, 4'd0};

        end else begin
            unique case (color_index)
                3'b000:  {r_o, g_o, b_o} = {4'd0,  4'd4,  4'd15}; // agua
                3'b001:  {r_o, g_o, b_o} = {4'd8,  4'd8,  4'd8 }; // barco
                3'b010:  {r_o, g_o, b_o} = {4'd15, 4'd0,  4'd0 }; // impacto
                3'b011:  {r_o, g_o, b_o} = {4'd15, 4'd15, 4'd15}; // fallo
                default: {r_o, g_o, b_o} = {4'd15, 4'd0,  4'd15}; // depuracion
            endcase
        end
    end

endmodule
