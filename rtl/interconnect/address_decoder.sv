`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Decodificador de direcciones MMIO
//
// Determina qué memoria o periférico corresponde a DataAddress_i.
// Las señales de escritura se habilitan únicamente cuando:
//      we_i = 1 && sel_X = 1
//
// Mapa:
//   RAM      : 0x0000_2000 - 0x0000_2FFF
//   UART     : 0x0001_0040 - 0x0001_0048
//   INPUT    : 0x0001_0120
//   DISPLAY  : 0x0001_0130
//   LED      : 0x0001_0138
//   BUZZER   : 0x0001_0140
//   VGA_CTRL : 0x0001_0148
//   VGA      : 0x0001_1000 - 0x0001_17FF
//
// INPUT es de solo lectura.
// -----------------------------------------------------------------------------

module address_decoder (
    input  logic [31:0] DataAddress_i,
    input  logic        we_i,

    output logic sel_ram_o,
    output logic sel_uart_o,
    output logic sel_input_o,
    output logic sel_display_o,
    output logic sel_led_o,
    output logic sel_buzzer_o,
    output logic sel_vga_ctrl_o,
    output logic sel_vga_o,

    output logic we_ram_o,
    output logic we_uart_o,
    output logic we_display_o,
    output logic we_led_o,
    output logic we_buzzer_o,
    output logic we_vga_ctrl_o,
    output logic we_vga_o
);

    always_comb begin
        // Valores por defecto
        sel_ram_o     = 1'b0;
        sel_uart_o    = 1'b0;
        sel_input_o   = 1'b0;
        sel_display_o = 1'b0;
        sel_led_o     = 1'b0;
        sel_buzzer_o  = 1'b0;
        sel_vga_ctrl_o = 1'b0;
        sel_vga_o     = 1'b0;

        // RAM
        if ((DataAddress_i >= 32'h0000_2000) &&
            (DataAddress_i <= 32'h0000_2FFF))
            sel_ram_o = 1'b1;

        // UART
        else if ((DataAddress_i >= 32'h0001_0040) &&
                 (DataAddress_i <= 32'h0001_0048))
            sel_uart_o = 1'b1;

        // Entradas Jugador 1
        else if (DataAddress_i == 32'h0001_0120)
            sel_input_o = 1'b1;

        // Display 7 segmentos
        else if (DataAddress_i == 32'h0001_0130)
            sel_display_o = 1'b1;

        // LED
        else if (DataAddress_i == 32'h0001_0138)
            sel_led_o = 1'b1;

        // Buzzer
        else if (DataAddress_i == 32'h0001_0140)
            sel_buzzer_o = 1'b1;

        // Control de cursor VGA
        else if (DataAddress_i == 32'h0001_0148)
            sel_vga_ctrl_o = 1'b1;

        // Memoria de video VGA
        else if ((DataAddress_i >= 32'h0001_1000) &&
                 (DataAddress_i <= 32'h0001_17FF))
            sel_vga_o = 1'b1;
    end

    // Habilitaciones de escritura
    always_comb begin
        we_ram_o     = we_i && sel_ram_o;
        we_uart_o    = we_i && sel_uart_o;
        we_display_o = we_i && sel_display_o;
        we_led_o     = we_i && sel_led_o;
        we_buzzer_o   = we_i && sel_buzzer_o;
        we_vga_ctrl_o = we_i && sel_vga_ctrl_o;
        we_vga_o      = we_i && sel_vga_o;
    end

endmodule
