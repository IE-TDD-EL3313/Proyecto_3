`timescale 1ns/1ps

module mmio_interconnect_tb;

    logic [31:0] DataAddress;
    logic        we;

    logic sel_ram;
    logic sel_uart;
    logic sel_input;
    logic sel_display;
    logic sel_led;
    logic sel_buzzer;
    logic sel_vga;

    logic we_ram;
    logic we_uart;
    logic we_display;
    logic we_led;
    logic we_buzzer;
    logic we_vga;

    logic [31:0] ram_rdata;
    logic [31:0] uart_rdata;
    logic [31:0] input_rdata;
    logic [31:0] display_rdata;
    logic [31:0] led_rdata;
    logic [31:0] buzzer_rdata;
    logic [31:0] vga_rdata;

    logic [31:0] DataIn;

    address_decoder u_decoder (
        .DataAddress_i (DataAddress),
        .we_i          (we),

        .sel_ram_o     (sel_ram),
        .sel_uart_o    (sel_uart),
        .sel_input_o   (sel_input),
        .sel_display_o (sel_display),
        .sel_led_o     (sel_led),
        .sel_buzzer_o  (sel_buzzer),
        .sel_vga_o     (sel_vga),

        .we_ram_o      (we_ram),
        .we_uart_o     (we_uart),
        .we_display_o  (we_display),
        .we_led_o      (we_led),
        .we_buzzer_o   (we_buzzer),
        .we_vga_o      (we_vga)
    );

    read_mux u_read_mux (
        .ram_rdata_i     (ram_rdata),
        .uart_rdata_i    (uart_rdata),
        .input_rdata_i   (input_rdata),
        .display_rdata_i (display_rdata),
        .led_rdata_i     (led_rdata),
        .buzzer_rdata_i  (buzzer_rdata),
        .vga_rdata_i     (vga_rdata),

        .sel_ram_i       (sel_ram),
        .sel_uart_i      (sel_uart),
        .sel_input_i     (sel_input),
        .sel_display_i   (sel_display),
        .sel_led_i       (sel_led),
        .sel_buzzer_i    (sel_buzzer),
        .sel_vga_i       (sel_vga),

        .DataIn_o        (DataIn)
    );

    task automatic check_read(
        input logic [31:0] addr,
        input logic [31:0] expected
    );
        begin
            DataAddress = addr;
            we = 1'b0;
            #1;

            if (DataIn !== expected)
                $error(
                    "FAIL READ: addr=%h DataIn=%h expected=%h",
                    addr, DataIn, expected
                );
        end
    endtask

    initial begin
        ram_rdata     = 32'hAAAA_0001;
        uart_rdata    = 32'hBBBB_0002;
        input_rdata   = 32'hCCCC_0003;
        display_rdata = 32'hDDDD_0004;
        led_rdata     = 32'hEEEE_0005;
        buzzer_rdata  = 32'hFFFF_0006;
        vga_rdata     = 32'h1234_0007;

        DataAddress = 32'b0;
        we = 1'b0;

        // Lecturas por dirección real del mapa
        check_read(32'h0000_2000, 32'hAAAA_0001);
        check_read(32'h0000_2FFF, 32'hAAAA_0001);

        check_read(32'h0001_0040, 32'hBBBB_0002);
        check_read(32'h0001_0044, 32'hBBBB_0002);
        check_read(32'h0001_0048, 32'hBBBB_0002);

        check_read(32'h0001_0120, 32'hCCCC_0003);
        check_read(32'h0001_0130, 32'hDDDD_0004);
        check_read(32'h0001_0138, 32'hEEEE_0005);
        check_read(32'h0001_0140, 32'hFFFF_0006);

        check_read(32'h0001_1000, 32'h1234_0007);
        check_read(32'h0001_17FF, 32'h1234_0007);

        // Dirección no mapeada -> cero
        check_read(32'hDEAD_BEEF, 32'h0000_0000);

        // Escritura al LED
        DataAddress = 32'h0001_0138;
        we = 1'b1;
        #1;

        if (!sel_led || !we_led)
            $error("FAIL WRITE LED: sel_led=%b we_led=%b",
                   sel_led, we_led);

        if (we_ram || we_uart || we_display ||
            we_buzzer || we_vga)
            $error("FAIL WRITE LED: otro destino recibio WE");

        // Escritura al VGA
        DataAddress = 32'h0001_1000;
        we = 1'b1;
        #1;

        if (!sel_vga || !we_vga)
            $error("FAIL WRITE VGA");

        // INPUT: selección válida pero sin WE propio
        DataAddress = 32'h0001_0120;
        we = 1'b1;
        #1;

        if (!sel_input)
            $error("FAIL INPUT: no fue seleccionado");

        if (we_ram || we_uart || we_display ||
            we_led || we_buzzer || we_vga)
            $error("FAIL INPUT: genero escritura");

        $display("========================================");
        $display(" PASS: mmio_interconnect_tb");
        $display("========================================");

        $finish;
    end

endmodule
