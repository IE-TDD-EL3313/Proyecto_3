`timescale 1ns/1ps

module vga_color_rgb_tb;

    logic [31:0] tile_data_i;
    logic        video_on_i;
    logic [3:0]  r_o;
    logic [3:0]  g_o;
    logic [3:0]  b_o;

    int errores = 0;

    vga_color_rgb dut (
        .tile_data_i (tile_data_i),
        .video_on_i  (video_on_i),
        .r_o         (r_o),
        .g_o         (g_o),
        .b_o         (b_o)
    );

    task automatic comprobar_color(
        input logic [2:0] indice,
        input logic [3:0] r_esperado,
        input logic [3:0] g_esperado,
        input logic [3:0] b_esperado
    );
        begin
            tile_data_i = {29'b0, indice};
            video_on_i  = 1'b1;
            #1;

            if ({r_o, g_o, b_o} !==
                {r_esperado, g_esperado, b_esperado}) begin

                $error(
                    "ERROR: indice=%b esperado RGB=(%0d,%0d,%0d) obtenido=(%0d,%0d,%0d)",
                    indice,
                    r_esperado, g_esperado, b_esperado,
                    r_o, g_o, b_o
                );
                errores++;
            end
        end
    endtask

    initial begin

        // ----------------------------------------------------
        // Prueba 1: colores definidos
        // ----------------------------------------------------
        comprobar_color(3'b000, 4'd0,  4'd4,  4'd15); // agua
        comprobar_color(3'b001, 4'd8,  4'd8,  4'd8 ); // barco propio
        comprobar_color(3'b010, 4'd15, 4'd0,  4'd0 ); // impacto
        comprobar_color(3'b011, 4'd15, 4'd15, 4'd15); // fallo

        // ----------------------------------------------------
        // Prueba 2: valores reservados -> magenta
        // ----------------------------------------------------
        comprobar_color(3'b100, 4'd15, 4'd0, 4'd15);
        comprobar_color(3'b101, 4'd15, 4'd0, 4'd15);
        comprobar_color(3'b110, 4'd15, 4'd0, 4'd15);
        comprobar_color(3'b111, 4'd15, 4'd0, 4'd15);

        // ----------------------------------------------------
        // Prueba 3: blanking siempre debe producir negro
        // ----------------------------------------------------
        tile_data_i = 32'hFFFF_FFFF;
        video_on_i  = 1'b0;
        #1;

        if ({r_o, g_o, b_o} !== 12'h000) begin
            $error(
                "ERROR BLANKING: esperado RGB=000, obtenido RGB=%h%h%h",
                r_o, g_o, b_o
            );
            errores++;
        end

        // ----------------------------------------------------
        // Resultado
        // ----------------------------------------------------
        if (errores == 0)
            $display("PASS: vga_color_rgb supero todas las pruebas.");
        else
            $fatal(1, "FAIL: se detectaron %0d errores.", errores);

        $finish;
    end

endmodule
