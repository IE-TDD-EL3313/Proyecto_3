`timescale 1ns/1ps

module address_decoder_tb;

    logic [31:0] DataAddress_i;
    logic        we_i;

    logic sel_ram_o;
    logic sel_uart_o;
    logic sel_input_o;
    logic sel_display_o;
    logic sel_led_o;
    logic sel_buzzer_o;
    logic sel_vga_o;

    logic we_ram_o;
    logic we_uart_o;
    logic we_display_o;
    logic we_led_o;
    logic we_buzzer_o;
    logic we_vga_o;

    address_decoder dut (
        .DataAddress_i (DataAddress_i),
        .we_i          (we_i),

        .sel_ram_o     (sel_ram_o),
        .sel_uart_o    (sel_uart_o),
        .sel_input_o   (sel_input_o),
        .sel_display_o (sel_display_o),
        .sel_led_o     (sel_led_o),
        .sel_buzzer_o  (sel_buzzer_o),
        .sel_vga_o     (sel_vga_o),

        .we_ram_o      (we_ram_o),
        .we_uart_o     (we_uart_o),
        .we_display_o  (we_display_o),
        .we_led_o      (we_led_o),
        .we_buzzer_o   (we_buzzer_o),
        .we_vga_o      (we_vga_o)
    );

    task automatic check_select(
        input logic [31:0] addr,
        input logic [6:0] expected_sel
    );
        begin
            DataAddress_i = addr;
            we_i = 1'b0;
            #1;

            if ({sel_vga_o,
                 sel_buzzer_o,
                 sel_led_o,
                 sel_display_o,
                 sel_input_o,
                 sel_uart_o,
                 sel_ram_o} !== expected_sel) begin

                $error("FAIL addr=%h sel=%b expected=%b",
                    addr,
                    {sel_vga_o,
                     sel_buzzer_o,
                     sel_led_o,
                     sel_display_o,
                     sel_input_o,
                     sel_uart_o,
                     sel_ram_o},
                    expected_sel);
            end
        end
    endtask

    initial begin

        // RAM: extremos y punto interno
        check_select(32'h0000_2000, 7'b0000001);
        check_select(32'h0000_2500, 7'b0000001);
        check_select(32'h0000_2FFF, 7'b0000001);

        // UART
        check_select(32'h0001_0040, 7'b0000010);
        check_select(32'h0001_0044, 7'b0000010);
        check_select(32'h0001_0048, 7'b0000010);

        // Periféricos locales
        check_select(32'h0001_0120, 7'b0000100);
        check_select(32'h0001_0130, 7'b0001000);
        check_select(32'h0001_0138, 7'b0010000);
        check_select(32'h0001_0140, 7'b0100000);

        // VGA: extremos y punto interno
        check_select(32'h0001_1000, 7'b1000000);
        check_select(32'h0001_1400, 7'b1000000);
        check_select(32'h0001_17FF, 7'b1000000);

        // Direcciones fuera del mapa
        check_select(32'h0000_1FFF, 7'b0000000);
        check_select(32'h0000_3000, 7'b0000000);
        check_select(32'h0001_0100, 7'b0000000);
        check_select(32'h0001_1800, 7'b0000000);
        check_select(32'hFFFF_FFFF, 7'b0000000);

        // Comprobación de escritura RAM
        DataAddress_i = 32'h0000_2000;
        we_i = 1'b1;
        #1;
        if (!we_ram_o)
            $error("FAIL: we_ram_o no se activo");

        // Comprobación de escritura UART
        DataAddress_i = 32'h0001_0044;
        #1;
        if (!we_uart_o)
            $error("FAIL: we_uart_o no se activo");

        // INPUT debe ser solo lectura
        DataAddress_i = 32'h0001_0120;
        #1;
        if (we_ram_o || we_uart_o || we_display_o ||
            we_led_o || we_buzzer_o || we_vga_o)
            $error("FAIL: INPUT genero una habilitacion de escritura");

        // Escritura a dirección inválida
        DataAddress_i = 32'hDEAD_BEEF;
        #1;
        if (we_ram_o || we_uart_o || we_display_o ||
            we_led_o || we_buzzer_o || we_vga_o)
            $error("FAIL: direccion invalida genero escritura");

        $display("========================================");
        $display(" PASS: address_decoder_tb");
        $display("========================================");

        $finish;
    end

endmodule
