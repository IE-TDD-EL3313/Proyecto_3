`timescale 1ns/1ps

module led_reg_tb;

    logic        clk_i;
    logic        rst_i;
    logic [31:0] wdata_i;
    logic        we_i;
    logic [2:0]  led_o;
    logic [31:0] rdata_o;

    led_reg dut (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .wdata_i (wdata_i),
        .we_i    (we_i),
        .led_o   (led_o),
        .rdata_o (rdata_o)
    );

    // Reloj de 100 MHz
    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    task automatic check_outputs(
        input logic [2:0] expected_led,
        input string      name
    );
        begin
            #1;

            if (led_o !== expected_led) begin
                $display(
                    "[FAIL] %s: led_o=%b esperado=%b",
                    name, led_o, expected_led
                );
                $fatal;
            end

            if (rdata_o !== {29'b0, expected_led}) begin
                $display(
                    "[FAIL] %s: rdata_o=%h esperado=%h",
                    name, rdata_o, {29'b0, expected_led}
                );
                $fatal;
            end

            $display(
                "[PASS] %s: led_o=%b rdata_o=%h",
                name, led_o, rdata_o
            );
        end
    endtask

    initial begin
        rst_i   = 1'b1;
        we_i    = 1'b0;
        wdata_i = 32'b0;

        // Verificar reset.
        repeat (2) @(posedge clk_i);
        #1;
        check_outputs(3'b000, "Reset");

        rst_i = 1'b0;

        // Fase de colocacion: 001.
        @(negedge clk_i);
        wdata_i = 32'h0000_0001;
        we_i    = 1'b1;

        @(posedge clk_i);
        #1;
        we_i = 1'b0;

        check_outputs(3'b001, "Fase de colocacion");

        // Fase de batalla: 010.
        @(negedge clk_i);
        wdata_i = 32'h0000_0002;
        we_i    = 1'b1;

        @(posedge clk_i);
        #1;
        we_i = 1'b0;

        check_outputs(3'b010, "Fase de batalla");

        // Resultado final: 100.
        @(negedge clk_i);
        wdata_i = 32'h0000_0004;
        we_i    = 1'b1;

        @(posedge clk_i);
        #1;
        we_i = 1'b0;

        check_outputs(3'b100, "Resultado final");

        // Con we_i = 0 el registro debe conservar el valor.
        @(negedge clk_i);
        wdata_i = 32'hFFFF_FFFF;
        we_i    = 1'b0;

        repeat (2) @(posedge clk_i);
        check_outputs(3'b100, "Mantiene valor con we_i = 0");

        // Solo deben almacenarse wdata_i[2:0].
        @(negedge clk_i);
        wdata_i = 32'hFFFF_FFFB; // bits [2:0] = 011
        we_i    = 1'b1;

        @(posedge clk_i);
        #1;
        we_i = 1'b0;

        check_outputs(3'b011, "Solo almacena bits [2:0]");

        // Verificar nuevamente reset.
        @(negedge clk_i);
        rst_i = 1'b1;

        @(posedge clk_i);
        #1;

        check_outputs(3'b000, "Reset final");

        $display("=== TODAS LAS PRUEBAS PASARON ===");
        $finish;
    end

endmodule