`timescale 1ns/1ps

module perifericos_locales_tb;

    logic        clk_i;
    logic        rst_i;

    logic [6:0]  btn_raw_i;
    logic [31:0] rdata_input_o;

    logic [31:0] disp_wdata_i;
    logic        disp_we_i;
    logic [6:0]  seg_o;
    logic [3:0]  anode_o;
    logic [31:0] rdata_display_o;

    logic [31:0] led_wdata_i;
    logic        led_we_i;
    logic [2:0]  led_o;
    logic [31:0] rdata_led_o;

    logic [31:0] buzz_wdata_i;
    logic        buzz_we_i;
    logic        buzz_pwm_o;
    logic [31:0] rdata_buzzer_o;


    // ---------------------------------------------------------
    // DUT
    // ---------------------------------------------------------

    perifericos_locales dut (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .btn_raw_i      (btn_raw_i),
        .rdata_input_o  (rdata_input_o),

        .disp_wdata_i   (disp_wdata_i),
        .disp_we_i      (disp_we_i),
        .seg_o          (seg_o),
        .anode_o        (anode_o),
        .rdata_display_o(rdata_display_o),

        .led_wdata_i    (led_wdata_i),
        .led_we_i       (led_we_i),
        .led_o          (led_o),
        .rdata_led_o    (rdata_led_o),

        .buzz_wdata_i   (buzz_wdata_i),
        .buzz_we_i      (buzz_we_i),
        .buzz_pwm_o     (buzz_pwm_o),
        .rdata_buzzer_o (rdata_buzzer_o)
    );


    // ---------------------------------------------------------
    // Reloj
    // ---------------------------------------------------------

    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;


    // ---------------------------------------------------------
    // Escritura al display
    // ---------------------------------------------------------

    task automatic write_display(input logic [31:0] data);
        begin
            @(negedge clk_i);

            disp_wdata_i = data;
            disp_we_i    = 1'b1;

            @(posedge clk_i);
            #1;

            @(negedge clk_i);

            disp_we_i    = 1'b0;
            disp_wdata_i = 32'b0;
        end
    endtask


    // ---------------------------------------------------------
    // Escritura al LED
    // ---------------------------------------------------------

    task automatic write_led(input logic [31:0] data);
        begin
            @(negedge clk_i);

            led_wdata_i = data;
            led_we_i    = 1'b1;

            @(posedge clk_i);
            #1;

            @(negedge clk_i);

            led_we_i    = 1'b0;
            led_wdata_i = 32'b0;
        end
    endtask


    // ---------------------------------------------------------
    // Escritura al buzzer
    // ---------------------------------------------------------

    task automatic write_buzzer(
        input logic [2:0] tone
    );
        begin
            @(negedge clk_i);

            buzz_wdata_i = {28'b0, 1'b1, tone};
            buzz_we_i    = 1'b1;

            @(posedge clk_i);
            #1;

            @(negedge clk_i);

            buzz_we_i    = 1'b0;
            buzz_wdata_i = 32'b0;
        end
    endtask


    // ---------------------------------------------------------
    // Secuencia de prueba
    // ---------------------------------------------------------

    initial begin

        rst_i = 1'b1;

        btn_raw_i = 7'b0;

        disp_wdata_i = 32'b0;
        disp_we_i    = 1'b0;

        led_wdata_i = 32'b0;
        led_we_i    = 1'b0;

        buzz_wdata_i = 32'b0;
        buzz_we_i    = 1'b0;


        // -----------------------------------------------------
        // RESET
        // -----------------------------------------------------

        repeat (3) @(posedge clk_i);
        #1;

        if (rdata_display_o !== 32'b0 ||
            rdata_led_o     !== 32'b0 ||
            rdata_buzzer_o  !== 32'b0) begin

            $display("[FAIL] Reset de perifericos");

            $display(
                "display=%h led=%h buzzer=%h",
                rdata_display_o,
                rdata_led_o,
                rdata_buzzer_o
            );

            $fatal;
        end

        $display("[PASS] Reset de perifericos");

        rst_i = 1'b0;


        // -----------------------------------------------------
        // DISPLAY
        // -----------------------------------------------------

        write_display(32'h0000_4321);

        if (rdata_display_o !== 32'h0000_4321) begin
            $display(
                "[FAIL] Display: esperado=00004321 obtenido=%h",
                rdata_display_o
            );
            $fatal;
        end

        if (rdata_led_o !== 32'b0 ||
            rdata_buzzer_o !== 32'b0) begin

            $display(
                "[FAIL] Escritura al display modifico otro periferico"
            );
            $fatal;
        end

        $display(
            "[PASS] Display escrito sin afectar LED ni buzzer"
        );


        // -----------------------------------------------------
        // LED
        // -----------------------------------------------------

        write_led(32'h0000_0002);

        if (rdata_led_o !== 32'h0000_0002) begin
            $display(
                "[FAIL] LED: esperado=00000002 obtenido=%h",
                rdata_led_o
            );
            $fatal;
        end

        if (rdata_display_o !== 32'h0000_4321 ||
            rdata_buzzer_o !== 32'b0) begin

            $display(
                "[FAIL] Escritura al LED modifico otro periferico"
            );
            $fatal;
        end

        $display(
            "[PASS] LED escrito sin afectar display ni buzzer"
        );


        // -----------------------------------------------------
        // BUZZER
        // -----------------------------------------------------

        write_buzzer(3'b000);

        if (rdata_buzzer_o[3] !== 1'b1 ||
            rdata_buzzer_o[2:0] !== 3'b000) begin

            $display(
                "[FAIL] Buzzer no inicio correctamente: rdata=%h",
                rdata_buzzer_o
            );
            $fatal;
        end

        if (rdata_display_o !== 32'h0000_4321 ||
            rdata_led_o !== 32'h0000_0002) begin

            $display(
                "[FAIL] Escritura al buzzer modifico otro periferico"
            );
            $fatal;
        end

        $display(
            "[PASS] Buzzer iniciado sin afectar display ni LED"
        );


        // -----------------------------------------------------
        // RESET GLOBAL
        // -----------------------------------------------------

        @(negedge clk_i);
        rst_i = 1'b1;

        @(posedge clk_i);
        #1;

        if (rdata_display_o !== 32'b0 ||
            rdata_led_o     !== 32'b0 ||
            rdata_buzzer_o  !== 32'b0 ||
            buzz_pwm_o      !== 1'b0) begin

            $display("[FAIL] Reset global");

            $display(
                "display=%h led=%h buzzer=%h pwm=%b",
                rdata_display_o,
                rdata_led_o,
                rdata_buzzer_o,
                buzz_pwm_o
            );

            $fatal;
        end

        $display("[PASS] Reset global de perifericos");

        $display(
            "=== TODAS LAS PRUEBAS DE INTEGRACION PASARON ==="
        );

        $finish;
    end

endmodule