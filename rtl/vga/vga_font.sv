// Generador de caracteres 8x8 para el HUD del periférico VGA.
//
// Cada carácter se representa mediante una matriz de 8x8 bits.
// El módulo es combinacional y no contiene estado.
//
// char_code_i : código ASCII del carácter.
// pixel_x_i   : columna del píxel dentro del carácter (0..7).
// pixel_y_i   : fila del píxel dentro del carácter (0..7).
// pixel_on_o  : 1 si el píxel correspondiente debe encenderse.

module vga_font (
    input  logic [7:0] char_code_i,
    input  logic [2:0] pixel_x_i,
    input  logic [2:0] pixel_y_i,
    output logic       pixel_on_o
);

    logic [7:0] row_bits;

    always_comb begin
        // Espacio por defecto.
        row_bits = 8'b00000000;

        unique case (char_code_i)

            // ---------------------------------------------------------
            // Letras mayúsculas utilizadas por el HUD.
            // ---------------------------------------------------------

            8'h41: begin // A
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11000011;
                    3'd4: row_bits = 8'b11111111;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b11000011;
                    3'd7: row_bits = 8'b11000011;
                endcase
            end

            8'h42: begin // B
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111100;
                    3'd1: row_bits = 8'b11000110;
                    3'd2: row_bits = 8'b11000110;
                    3'd3: row_bits = 8'b11111100;
                    3'd4: row_bits = 8'b11000110;
                    3'd5: row_bits = 8'b11000110;
                    3'd6: row_bits = 8'b11000110;
                    3'd7: row_bits = 8'b11111100;
                endcase
            end


            8'h43: begin // C
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111110;
                    3'd1: row_bits = 8'b01100011;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b11000000;
                    3'd4: row_bits = 8'b11000000;
                    3'd5: row_bits = 8'b11000000;
                    3'd6: row_bits = 8'b01100011;
                    3'd7: row_bits = 8'b00111110;
                endcase
            end

            8'h44: begin // D
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111100;
                    3'd1: row_bits = 8'b11000110;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11000011;
                    3'd4: row_bits = 8'b11000011;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b11000110;
                    3'd7: row_bits = 8'b11111100;
                endcase
            end

            8'h45: begin // E
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111111;
                    3'd1: row_bits = 8'b11000000;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b11111110;
                    3'd4: row_bits = 8'b11000000;
                    3'd5: row_bits = 8'b11000000;
                    3'd6: row_bits = 8'b11000000;
                    3'd7: row_bits = 8'b11111111;
                endcase
            end

            8'h47: begin // G
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111110;
                    3'd1: row_bits = 8'b01100011;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b11001111;
                    3'd4: row_bits = 8'b11000011;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b01100011;
                    3'd7: row_bits = 8'b00111110;
                endcase
            end

            8'h49: begin // I
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111111;
                    3'd1: row_bits = 8'b00011000;
                    3'd2: row_bits = 8'b00011000;
                    3'd3: row_bits = 8'b00011000;
                    3'd4: row_bits = 8'b00011000;
                    3'd5: row_bits = 8'b00011000;
                    3'd6: row_bits = 8'b00011000;
                    3'd7: row_bits = 8'b11111111;
                endcase
            end

            8'h4A: begin // J
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00011111;
                    3'd1: row_bits = 8'b00000110;
                    3'd2: row_bits = 8'b00000110;
                    3'd3: row_bits = 8'b00000110;
                    3'd4: row_bits = 8'b00000110;
                    3'd5: row_bits = 8'b11000110;
                    3'd6: row_bits = 8'b11000110;
                    3'd7: row_bits = 8'b01111100;
                endcase
            end

            8'h4C: begin // L
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11000000;
                    3'd1: row_bits = 8'b11000000;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b11000000;
                    3'd4: row_bits = 8'b11000000;
                    3'd5: row_bits = 8'b11000000;
                    3'd6: row_bits = 8'b11000000;
                    3'd7: row_bits = 8'b11111111;
                endcase
            end

            8'h46: begin // F
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111111;
                    3'd1: row_bits = 8'b11000000;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b11111110;
                    3'd4: row_bits = 8'b11000000;
                    3'd5: row_bits = 8'b11000000;
                    3'd6: row_bits = 8'b11000000;
                    3'd7: row_bits = 8'b11000000;
                endcase
            end

            8'h51: begin // Q
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11000011;
                    3'd4: row_bits = 8'b11001011;
                    3'd5: row_bits = 8'b11000110;
                    3'd6: row_bits = 8'b01111110;
                    3'd7: row_bits = 8'b00000011;
                endcase
            end

            8'h53: begin // S
                case (pixel_y_i)
                    3'd0: row_bits = 8'b01111110;
                    3'd1: row_bits = 8'b11000011;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b01111100;
                    3'd4: row_bits = 8'b00000110;
                    3'd5: row_bits = 8'b00000011;
                    3'd6: row_bits = 8'b11000011;
                    3'd7: row_bits = 8'b01111110;
                endcase
            end

            8'h4D: begin // M
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11000011;
                    3'd1: row_bits = 8'b11100111;
                    3'd2: row_bits = 8'b11111111;
                    3'd3: row_bits = 8'b11011011;
                    3'd4: row_bits = 8'b11000011;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b11000011;
                    3'd7: row_bits = 8'b11000011;
                endcase
            end

            8'h4E: begin // N
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11000011;
                    3'd1: row_bits = 8'b11100011;
                    3'd2: row_bits = 8'b11110011;
                    3'd3: row_bits = 8'b11011011;
                    3'd4: row_bits = 8'b11001111;
                    3'd5: row_bits = 8'b11000111;
                    3'd6: row_bits = 8'b11000011;
                    3'd7: row_bits = 8'b11000011;
                endcase
            end

            8'h4F: begin // O
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11000011;
                    3'd4: row_bits = 8'b11000011;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h50: begin // P
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111100;
                    3'd1: row_bits = 8'b11000110;
                    3'd2: row_bits = 8'b11000110;
                    3'd3: row_bits = 8'b11111100;
                    3'd4: row_bits = 8'b11000000;
                    3'd5: row_bits = 8'b11000000;
                    3'd6: row_bits = 8'b11000000;
                    3'd7: row_bits = 8'b11000000;
                endcase
            end

            8'h52: begin // R
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111100;
                    3'd1: row_bits = 8'b11000110;
                    3'd2: row_bits = 8'b11000110;
                    3'd3: row_bits = 8'b11111100;
                    3'd4: row_bits = 8'b11011000;
                    3'd5: row_bits = 8'b11001100;
                    3'd6: row_bits = 8'b11000110;
                    3'd7: row_bits = 8'b11000011;
                endcase
            end

            8'h54: begin // T
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11111111;
                    3'd1: row_bits = 8'b00011000;
                    3'd2: row_bits = 8'b00011000;
                    3'd3: row_bits = 8'b00011000;
                    3'd4: row_bits = 8'b00011000;
                    3'd5: row_bits = 8'b00011000;
                    3'd6: row_bits = 8'b00011000;
                    3'd7: row_bits = 8'b00011000;
                endcase
            end

            8'h55: begin // U
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11000011;
                    3'd1: row_bits = 8'b11000011;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11000011;
                    3'd4: row_bits = 8'b11000011;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h56: begin // V
                case (pixel_y_i)
                    3'd0: row_bits = 8'b11000011;
                    3'd1: row_bits = 8'b11000011;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11000011;
                    3'd4: row_bits = 8'b11000011;
                    3'd5: row_bits = 8'b01100110;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            // ---------------------------------------------------------
            // Dígitos.
            // ---------------------------------------------------------

            8'h30: begin // 0
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b11000011;
                    3'd3: row_bits = 8'b11011011;
                    3'd4: row_bits = 8'b11011011;
                    3'd5: row_bits = 8'b11000011;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h31: begin // 1
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00011000;
                    3'd1: row_bits = 8'b00111000;
                    3'd2: row_bits = 8'b00011000;
                    3'd3: row_bits = 8'b00011000;
                    3'd4: row_bits = 8'b00011000;
                    3'd5: row_bits = 8'b00011000;
                    3'd6: row_bits = 8'b00011000;
                    3'd7: row_bits = 8'b01111110;
                endcase
            end

            8'h32: begin // 2
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b00000110;
                    3'd3: row_bits = 8'b00001100;
                    3'd4: row_bits = 8'b00011000;
                    3'd5: row_bits = 8'b00110000;
                    3'd6: row_bits = 8'b01100000;
                    3'd7: row_bits = 8'b01111110;
                endcase
            end

            8'h33: begin // 3
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b00000110;
                    3'd3: row_bits = 8'b00011100;
                    3'd4: row_bits = 8'b00000110;
                    3'd5: row_bits = 8'b00000110;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h34: begin // 4
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00001100;
                    3'd1: row_bits = 8'b00011100;
                    3'd2: row_bits = 8'b00111100;
                    3'd3: row_bits = 8'b01101100;
                    3'd4: row_bits = 8'b11001100;
                    3'd5: row_bits = 8'b11111110;
                    3'd6: row_bits = 8'b00001100;
                    3'd7: row_bits = 8'b00001100;
                endcase
            end

            8'h35: begin // 5
                case (pixel_y_i)
                    3'd0: row_bits = 8'b01111110;
                    3'd1: row_bits = 8'b01100000;
                    3'd2: row_bits = 8'b01100000;
                    3'd3: row_bits = 8'b01111100;
                    3'd4: row_bits = 8'b00000110;
                    3'd5: row_bits = 8'b00000110;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h36: begin // 6
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100000;
                    3'd2: row_bits = 8'b11000000;
                    3'd3: row_bits = 8'b11111100;
                    3'd4: row_bits = 8'b11000110;
                    3'd5: row_bits = 8'b11000110;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h37: begin // 7
                case (pixel_y_i)
                    3'd0: row_bits = 8'b01111110;
                    3'd1: row_bits = 8'b00000110;
                    3'd2: row_bits = 8'b00001100;
                    3'd3: row_bits = 8'b00011000;
                    3'd4: row_bits = 8'b00110000;
                    3'd5: row_bits = 8'b00110000;
                    3'd6: row_bits = 8'b00110000;
                    3'd7: row_bits = 8'b00110000;
                endcase
            end

            8'h38: begin // 8
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b01100110;
                    3'd3: row_bits = 8'b00111100;
                    3'd4: row_bits = 8'b01100110;
                    3'd5: row_bits = 8'b01100110;
                    3'd6: row_bits = 8'b01100110;
                    3'd7: row_bits = 8'b00111100;
                endcase
            end

            8'h39: begin // 9
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00111100;
                    3'd1: row_bits = 8'b01100110;
                    3'd2: row_bits = 8'b01100110;
                    3'd3: row_bits = 8'b00111110;
                    3'd4: row_bits = 8'b00000110;
                    3'd5: row_bits = 8'b00000110;
                    3'd6: row_bits = 8'b00001100;
                    3'd7: row_bits = 8'b00111000;
                endcase
            end

            // Dos puntos.
            8'h3A: begin // :
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00000000;
                    3'd1: row_bits = 8'b00011000;
                    3'd2: row_bits = 8'b00011000;
                    3'd3: row_bits = 8'b00000000;
                    3'd4: row_bits = 8'b00000000;
                    3'd5: row_bits = 8'b00011000;
                    3'd6: row_bits = 8'b00011000;
                    3'd7: row_bits = 8'b00000000;
                endcase
            end

            // Guion.
            8'h2D: begin // -
                case (pixel_y_i)
                    3'd0: row_bits = 8'b00000000;
                    3'd1: row_bits = 8'b00000000;
                    3'd2: row_bits = 8'b00000000;
                    3'd3: row_bits = 8'b01111110;
                    3'd4: row_bits = 8'b01111110;
                    3'd5: row_bits = 8'b00000000;
                    3'd6: row_bits = 8'b00000000;
                    3'd7: row_bits = 8'b00000000;
                endcase
            end

            // Espacio.
            8'h20: row_bits = 8'b00000000;

            default: row_bits = 8'b00000000;

        endcase
    end

    assign pixel_on_o = row_bits[7 - pixel_x_i];

endmodule
