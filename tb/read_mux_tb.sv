`timescale 1ns/1ps

module read_mux_tb;

    logic [31:0] ram_rdata_i;
    logic [31:0] uart_rdata_i;
    logic [31:0] input_rdata_i;
    logic [31:0] display_rdata_i;
    logic [31:0] led_rdata_i;
    logic [31:0] buzzer_rdata_i;
    logic [31:0] vga_rdata_i;

    logic sel_ram_i;
    logic sel_uart_i;
    logic sel_input_i;
    logic sel_display_i;
    logic sel_led_i;
    logic sel_buzzer_i;
    logic sel_vga_i;

    logic [31:0] DataIn_o;

    read_mux dut (
        .ram_rdata_i     (ram_rdata_i),
        .uart_rdata_i    (uart_rdata_i),
        .input_rdata_i   (input_rdata_i),
        .display_rdata_i (display_rdata_i),
        .led_rdata_i     (led_rdata_i),
        .buzzer_rdata_i  (buzzer_rdata_i),
        .vga_rdata_i     (vga_rdata_i),

        .sel_ram_i       (sel_ram_i),
        .sel_uart_i      (sel_uart_i),
        .sel_input_i     (sel_input_i),
        .sel_display_i   (sel_display_i),
        .sel_led_i       (sel_led_i),
        .sel_buzzer_i    (sel_buzzer_i),
        .sel_vga_i       (sel_vga_i),

        .DataIn_o        (DataIn_o)
    );

    task automatic clear_select;
        begin
            sel_ram_i     = 1'b0;
            sel_uart_i    = 1'b0;
            sel_input_i   = 1'b0;
            sel_display_i = 1'b0;
            sel_led_i     = 1'b0;
            sel_buzzer_i  = 1'b0;
            sel_vga_i     = 1'b0;
        end
    endtask

    task automatic check_output(
        input logic [31:0] expected
    );
        begin
            #1;
            if (DataIn_o !== expected)
                $error(
                    "FAIL: DataIn_o=%h expected=%h",
                    DataIn_o,
                    expected
                );
        end
    endtask

    initial begin

        // Valores únicos para identificar cada fuente
        ram_rdata_i     = 32'hAAAA_0001;
        uart_rdata_i    = 32'hBBBB_0002;
        input_rdata_i   = 32'hCCCC_0003;
        display_rdata_i = 32'hDDDD_0004;
        led_rdata_i     = 32'hEEEE_0005;
        buzzer_rdata_i  = 32'hFFFF_0006;
        vga_rdata_i     = 32'h1234_0007;

        // Ninguna selección -> cero
        clear_select();
        check_output(32'h0000_0000);

        // RAM
        clear_select();
        sel_ram_i = 1'b1;
        check_output(32'hAAAA_0001);

        // UART
        clear_select();
        sel_uart_i = 1'b1;
        check_output(32'hBBBB_0002);

        // INPUT
        clear_select();
        sel_input_i = 1'b1;
        check_output(32'hCCCC_0003);

        // DISPLAY
        clear_select();
        sel_display_i = 1'b1;
        check_output(32'hDDDD_0004);

        // LED
        clear_select();
        sel_led_i = 1'b1;
        check_output(32'hEEEE_0005);

        // BUZZER
        clear_select();
        sel_buzzer_i = 1'b1;
        check_output(32'hFFFF_0006);

        // VGA
        clear_select();
        sel_vga_i = 1'b1;
        check_output(32'h1234_0007);

        // Volver a ninguna selección
        clear_select();
        check_output(32'h0000_0000);

        $display("========================================");
        $display(" PASS: read_mux_tb");
        $display("========================================");

        $finish;
    end

endmodule
