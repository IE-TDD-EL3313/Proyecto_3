`timescale 1ns/1ps

module vga_memory_tb;

    logic        clk_i = 1'b0;
    logic        clk_pix_i = 1'b0;
    logic        vga_we_i;
    logic [8:0]  vga_addr_i;
    logic [31:0] vga_wdata_i;
    logic [9:0]  hcount_i;
    logic [9:0]  vcount_i;
    logic [31:0] tile_data_o;

    int errores = 0;

    // 100 MHz
    always #5 clk_i = ~clk_i;

    // 25 MHz
    always #20 clk_pix_i = ~clk_pix_i;

    vga_memory dut (
        .clk_i       (clk_i),
        .vga_we_i    (vga_we_i),
        .vga_addr_i  (vga_addr_i),
        .vga_wdata_i (vga_wdata_i),
        .clk_pix_i   (clk_pix_i),
        .hcount_i    (hcount_i),
        .vcount_i    (vcount_i),
        .tile_data_o (tile_data_o)
    );

    task automatic escribir_tile(
        input logic [8:0] addr,
        input logic [31:0] data
    );
        begin
            @(negedge clk_i);
            vga_addr_i  = addr;
            vga_wdata_i = data;
            vga_we_i    = 1'b1;

            @(posedge clk_i);
            #1;

            vga_we_i = 1'b0;
        end
    endtask

    task automatic comprobar_tile(
        input logic [9:0] h,
        input logic [9:0] v,
        input logic [31:0] esperado
    );
        begin
            @(negedge clk_pix_i);
            hcount_i = h;
            vcount_i = v;

            @(posedge clk_pix_i);
            #1;

            if (tile_data_o !== esperado) begin
                $error(
                    "ERROR: h=%0d v=%0d esperado=%h obtenido=%h",
                    h, v, esperado, tile_data_o
                );
                errores++;
            end
        end
    endtask

    initial begin
        vga_we_i    = 1'b0;
        vga_addr_i  = '0;
        vga_wdata_i = '0;
        hcount_i    = '0;
        vcount_i    = '0;

        // ----------------------------------------------------
        // Prueba 1: tile (0,0) -> dirección 0
        // ----------------------------------------------------
        escribir_tile(9'd0, 32'h1234_ABCD);
        comprobar_tile(10'd0, 10'd0, 32'h1234_ABCD);

        // ----------------------------------------------------
        // Prueba 2: tile (5,3)
        // Dirección = 3*20 + 5 = 65
        // Cada tile mide 32x32 píxeles
        // ----------------------------------------------------
        escribir_tile(9'd65, 32'hCAFE_BABE);
        comprobar_tile(10'd160, 10'd96, 32'hCAFE_BABE);

        // Otro píxel dentro del mismo tile
        comprobar_tile(10'd191, 10'd127, 32'hCAFE_BABE);

        // ----------------------------------------------------
        // Prueba 3: último tile válido (19,14)
        // Dirección = 14*20 + 19 = 299
        // ----------------------------------------------------
        escribir_tile(9'd299, 32'hDEAD_BEEF);
        comprobar_tile(10'd608, 10'd448, 32'hDEAD_BEEF);

        // ----------------------------------------------------
        // Prueba 4: dirección calculada fuera de rango
        // tile (0,15) -> dirección 300
        // Debe entregar cero y no acceder mem[300].
        // ----------------------------------------------------
        comprobar_tile(10'd0, 10'd480, 32'h0000_0000);

        // ----------------------------------------------------
        // Prueba 5: intento de escritura fuera de rango
        // No debe afectar una posición válida.
        // ----------------------------------------------------
        escribir_tile(9'd10, 32'hA5A5_5A5A);
        escribir_tile(9'd300, 32'hFFFF_FFFF);
        comprobar_tile(10'd320, 10'd0, 32'hA5A5_5A5A);

        if (errores == 0)
            $display("PASS: vga_memory supero todas las pruebas.");
        else
            $fatal(1, "FAIL: se detectaron %0d errores.", errores);

        $finish;
    end

endmodule
