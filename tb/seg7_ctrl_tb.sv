`timescale 1ns/1ps

module seg7_ctrl_tb;

    logic        clk_i;
    logic        rst_i;
    logic [31:0] wdata_i;
    logic        we_i;
    logic [6:0]  seg_o;
    logic [3:0]  anode_o;
    logic [31:0] rdata_o;

    // Valor pequeño para acelerar la simulacion.
    localparam int TEST_HOLD_CYCLES = 4;

    seg7_ctrl #(
        .DIGIT_HOLD_CYCLES(TEST_HOLD_CYCLES)
    ) dut (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .wdata_i (wdata_i),
        .we_i    (we_i),
        .seg_o   (seg_o),
        .anode_o (anode_o),
        .rdata_o (rdata_o)
    );

    // Reloj de 100 MHz
    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    task automatic check_digit(
        input logic [3:0] expected_anode,
        input logic [6:0] expected_seg,
        input string      name
    );
        begin
            #1;
            if ((anode_o !== expected_anode) ||
                (seg_o   !== expected_seg)) begin

                $display(
                    "[FAIL] %s: anode=%b esperado=%b, seg=%b esperado=%b",
                    name, anode_o, expected_anode,
                    seg_o, expected_seg
                );
                $fatal;
            end

            $display(
                "[PASS] %s: anode=%b seg=%b",
                name, anode_o, seg_o
            );
        end
    endtask

    initial begin
        rst_i   = 1'b1;
        we_i    = 1'b0;
        wdata_i = 32'b0;

        repeat (2) @(posedge clk_i);
        #1;
        rst_i = 1'b0;

        // Escribir cuatro digitos BCD: 1, 2, 3, 4.
        // disp_data[3:0]   = 1
        // disp_data[7:4]   = 2
        // disp_data[11:8]  = 3
        // disp_data[15:12] = 4
        @(negedge clk_i);
        wdata_i = 32'h0000_4321;
        we_i    = 1'b1;

        @(posedge clk_i);
        #1;

        we_i = 1'b0;

        // Verificar lectura del registro.
        if (rdata_o !== 32'h0000_4321) begin
            $display(
                "[FAIL] rdata_o=%h esperado=00004321",
                rdata_o
            );
            $fatal;
        end

        $display("[PASS] Registro BCD escrito y leido correctamente");

        // Digito 0 = 1
        check_digit(4'b1110, 7'b1111001, "Digito 0 = 1");

        // Esperar cambio al digito 1.
        repeat (TEST_HOLD_CYCLES) @(posedge clk_i);
        check_digit(4'b1101, 7'b0100100, "Digito 1 = 2");

        // Digito 2.
        repeat (TEST_HOLD_CYCLES) @(posedge clk_i);
        check_digit(4'b1011, 7'b0110000, "Digito 2 = 3");

        // Digito 3.
        repeat (TEST_HOLD_CYCLES) @(posedge clk_i);
        check_digit(4'b0111, 7'b0011001, "Digito 3 = 4");

        $display("=== TODAS LAS PRUEBAS PASARON ===");
        $finish;
    end

endmodule