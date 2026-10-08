`timescale 1ns/1ps

module sistema_top_tb;

    logic clk_i = 1'b0;
    logic rst_ni = 1'b0;
    logic [6:0] btn_raw_i = 7'b0000010;
    logic uart_rx_i = 1'b1;

    wire uart_tx_o;
    wire [6:0] seg_o;
    wire [3:0] anode_o;
    wire [2:0] led_o;
    wire buzz_pwm_o;
    wire hsync_o;
    wire vsync_o;
    wire [3:0] r_o;
    wire [3:0] g_o;
    wire [3:0] b_o;

    integer cycles = 0;
    integer mmio_writes = 0;

    always #5 clk_i = ~clk_i;   // 100 MHz

    sistema_top #(
        .ROM_FILE("handoff.hex")
    ) dut (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .btn_raw_i  (btn_raw_i),
        .uart_rx_i  (uart_rx_i),
        .uart_tx_o  (uart_tx_o),
        .seg_o      (seg_o),
        .anode_o    (anode_o),
        .led_o      (led_o),
        .buzz_pwm_o (buzz_pwm_o),
        .hsync_o    (hsync_o),
        .vsync_o    (vsync_o),
        .r_o        (r_o),
        .g_o        (g_o),
        .b_o        (b_o)
    );

    initial begin
        repeat (3) @(negedge clk_i);
        rst_ni = 1'b1;

        wait (mmio_writes == 3);
        @(negedge clk_i);

        // RAM interna del processor_subsystem.
        if (dut.u_processor.ram.words[0] !== 32'h12345678)
            $fatal(1, "RAM[0] incorrecta: %h",
                   dut.u_processor.ram.words[0]);

        if (dut.u_processor.ram.words[1023] !== 32'h12345678)
            $fatal(1, "RAM[1023] incorrecta: %h",
                   dut.u_processor.ram.words[1023]);

        // El firmware lee INPUT y conserva el valor en RAM[1].
        if (dut.u_processor.ram.words[1] !== dut.input_rdata)
            $fatal(1, "Lectura INPUT no llego a RAM: RAM=%h INPUT=%h",
                   dut.u_processor.ram.words[1], dut.input_rdata);

        // La misma lectura debe haberse escrito en la primera palabra VGA.
        if (dut.u_vga.u_memory.mem[0] !== dut.u_processor.ram.words[1])
            $fatal(1, "Dato INPUT no llego a VGA: VGA=%h RAM=%h",
                   dut.u_vga.u_memory.mem[0],
                   dut.u_processor.ram.words[1]);

        // El firmware marca final correcto escribiendo 1 al LED.
        if (led_o !== 3'b001)
            $fatal(1, "LED final incorrecto: %b", led_o);

        $display("PASS: sistema_top CPU+RAM+MMIO+INPUT+LED+VGA");
        $display("RAM[0]    = %h", dut.u_processor.ram.words[0]);
        $display("RAM[1023] = %h", dut.u_processor.ram.words[1023]);
        $display("RAM[1]    = %h", dut.u_processor.ram.words[1]);
        $display("VGA[0]    = %h", dut.u_vga.u_memory.mem[0]);
        $display("LED       = %b", led_o);

        $finish;
    end

    // Verifica las escrituras MMIO emitidas por el CPU.
    always @(posedge clk_i) begin
        if (rst_ni) begin
            cycles = cycles + 1;

            if (dut.mmio_we) begin
                case (mmio_writes)
                    0: begin
                        if (dut.mmio_addr !== 32'h00010138 ||
                            dut.mmio_wdata !== 32'h00000005)
                            $fatal(1,
                                "Primera escritura MMIO incorrecta: addr=%h data=%h",
                                dut.mmio_addr, dut.mmio_wdata);
                    end

                    1: begin
                        if (dut.mmio_addr !== 32'h00011000)
                            $fatal(1,
                                "Direccion VGA incorrecta: addr=%h",
                                dut.mmio_addr);

                        if (dut.mmio_wdata !== dut.u_processor.ram.words[1])
                            $fatal(1,
                                "Dato VGA no coincide con lectura INPUT: VGA=%h RAM=%h",
                                dut.mmio_wdata,
                                dut.u_processor.ram.words[1]);
                    end

                    2: begin
                        if (dut.mmio_addr !== 32'h00010138 ||
                            dut.mmio_wdata !== 32'h00000001)
                            $fatal(1,
                                "Escritura final LED incorrecta: addr=%h data=%h",
                                dut.mmio_addr, dut.mmio_wdata);
                    end

                    default:
                        $fatal(1, "Escritura MMIO inesperada");
                endcase

                mmio_writes = mmio_writes + 1;
            end

            if (cycles > 1000)
                $fatal(1, "Timeout sistema_top PC=%h", dut.pc_internal);
        end
    end

endmodule
