`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Multiplexor de lectura MMIO
//
// Selecciona el dato proveniente de RAM o de uno de los periféricos
// y lo entrega al procesador mediante DataIn_o.
//
// El decodificador de direcciones garantiza que, como máximo,
// una señal sel_* esté activa simultáneamente.
//
// Si ninguna fuente está seleccionada, DataIn_o = 0.
// -----------------------------------------------------------------------------

module read_mux (
    input  logic [31:0] ram_rdata_i,
    input  logic [31:0] uart_rdata_i,
    input  logic [31:0] input_rdata_i,
    input  logic [31:0] display_rdata_i,
    input  logic [31:0] led_rdata_i,
    input  logic [31:0] buzzer_rdata_i,
    input  logic [31:0] vga_rdata_i,

    input  logic sel_ram_i,
    input  logic sel_uart_i,
    input  logic sel_input_i,
    input  logic sel_display_i,
    input  logic sel_led_i,
    input  logic sel_buzzer_i,
    input  logic sel_vga_i,

    output logic [31:0] DataIn_o
);

    always_comb begin
        DataIn_o = 32'b0;

        if (sel_ram_i)
            DataIn_o = ram_rdata_i;
        else if (sel_uart_i)
            DataIn_o = uart_rdata_i;
        else if (sel_input_i)
            DataIn_o = input_rdata_i;
        else if (sel_display_i)
            DataIn_o = display_rdata_i;
        else if (sel_led_i)
            DataIn_o = led_rdata_i;
        else if (sel_buzzer_i)
            DataIn_o = buzzer_rdata_i;
        else if (sel_vga_i)
            DataIn_o = vga_rdata_i;
    end

endmodule
