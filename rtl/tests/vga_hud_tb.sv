`timescale 1ns / 1ps

module vga_hud_tb;

    logic [31:0] tile_data;
    logic video_on;
    logic [4:0] pixel_x, pixel_y, tile_col;
    logic [3:0] tile_row;
    logic [7:0] cursor_ctrl;
    logic [3:0] r, g, b;

    integer errors = 0;

    vga_color_rgb dut (
        .tile_data_i   (tile_data),
        .video_on_i    (video_on),
        .pixel_x_i     (pixel_x),
        .pixel_y_i     (pixel_y),
        .tile_col_i    (tile_col),
        .tile_row_i    (tile_row),
        .cursor_ctrl_i (cursor_ctrl),
        .r_o           (r),
        .g_o           (g),
        .b_o           (b)
    );

    task automatic check_rgb(
        input logic [11:0] expected,
        input string description
    );
        #1;
        if ({r, g, b} !== expected) begin
            $display("FAIL: %s | RGB=%h esperado=%h",
                     description, {r, g, b}, expected);
            errors++;
        end else begin
            $display("PASS: %s", description);
        end
    endtask

    initial begin
        video_on   = 1;
        cursor_ctrl = 0;
        pixel_x    = 0;
        pixel_y    = 0;
        tile_col   = 0;
        tile_row   = 0;
        tile_data  = 0;

        // --------------------------------------------------
        // Prueba 1: carácter A.
        //
        // TEXT_ENABLE = bit 11
        // ASCII 'A'   = 0x41 en bits [10:3]
        // --------------------------------------------------

        tile_data = (32'h41 << 3) | 32'h800;

        // Primera fila de A: 00111100.
        // Columna 2 debe estar encendida.
        pixel_x = 8;
        pixel_y = 0;

        check_rgb(12'hFFF, "Caracter A - pixel encendido");

        // Columna 0 debe estar apagada.
        pixel_x = 0;

        check_rgb(12'h000, "Caracter A - pixel apagado");

        // --------------------------------------------------
        // Prueba 2: agua en tablero J1.
        // --------------------------------------------------

        tile_data = 0;
        tile_col  = 1;
        tile_row  = 6;
        pixel_x   = 10;
        pixel_y   = 10;

        check_rgb(12'h04F, "Tablero J1 - agua");

        // --------------------------------------------------
        // Prueba 3: barco propio.
        // --------------------------------------------------

        tile_data = 1;

        check_rgb(12'h888, "Tablero J1 - barco");

        // --------------------------------------------------
        // Prueba 4: impacto.
        // --------------------------------------------------

        tile_data = 2;

        check_rgb(12'hF00, "Tablero J1 - impacto");

        // --------------------------------------------------
        // Prueba 5: fallo.
        // --------------------------------------------------

        tile_data = 3;

        check_rgb(12'hFFF, "Tablero J1 - fallo");

        // --------------------------------------------------
        // Prueba 6: cursor amarillo.
        // Visible=1, tablero J1, fila 0, columna 0.
        // --------------------------------------------------

        tile_data   = 0;
        cursor_ctrl = 8'h80;
        pixel_x     = 1;
        pixel_y     = 10;

        check_rgb(12'hFF0, "Cursor amarillo");

        // --------------------------------------------------
        // Prueba 7: fuera del área visible.
        // --------------------------------------------------

        video_on = 0;

        check_rgb(12'h000, "Video deshabilitado");

        // --------------------------------------------------
        // Resultado.
        // --------------------------------------------------

        if (errors == 0) begin
            $display("================================");
            $display("PASS: VGA HUD - 8 pruebas");
            $display("================================");
        end else begin
            $fatal(1, "FAIL: VGA HUD - %0d errores", errors);
        end

        $finish;
    end

endmodule
