`timescale 1ns/1ps

module vga_timing_tb;

    logic       clk_pix_i = 1'b0;
    logic       rst_i;
    logic [9:0] hcount_o;
    logic [9:0] vcount_o;
    logic       hsync_o;
    logic       vsync_o;
    logic       video_on_o;

    int errores = 0;
    int ciclos  = 0;

    // 25 MHz -> periodo de 40 ns
    always #20 clk_pix_i = ~clk_pix_i;

    vga_timing dut (
        .clk_pix_i (clk_pix_i),
        .rst_i     (rst_i),
        .hcount_o  (hcount_o),
        .vcount_o  (vcount_o),
        .hsync_o   (hsync_o),
        .vsync_o   (vsync_o),
        .video_on_o(video_on_o)
    );

    initial begin
        rst_i = 1'b1;

        // Aplicar reset durante algunos ciclos
        repeat (3) @(posedge clk_pix_i);
        #1;

        if ((hcount_o !== 10'd0) || (vcount_o !== 10'd0)) begin
            $error("ERROR: los contadores no se reiniciaron correctamente.");
            errores++;
        end

        rst_i = 1'b0;

        // Verificar un frame completo: 800 x 525 = 420000 píxeles
        repeat (420000) begin
            @(negedge clk_pix_i);

            // Rango de los contadores
            if (hcount_o > 10'd799) begin
                $error("ERROR: hcount fuera de rango: %0d", hcount_o);
                errores++;
            end

            if (vcount_o > 10'd524) begin
                $error("ERROR: vcount fuera de rango: %0d", vcount_o);
                errores++;
            end

            // HSYNC activo en bajo entre 656 y 751
            if (hsync_o !== !((hcount_o >= 10'd656) &&
                              (hcount_o <  10'd752))) begin
                $error(
                    "ERROR HSYNC: h=%0d hsync=%b",
                    hcount_o, hsync_o
                );
                errores++;
            end

            // VSYNC activo en bajo entre líneas 490 y 491
            if (vsync_o !== !((vcount_o >= 10'd490) &&
                              (vcount_o <  10'd492))) begin
                $error(
                    "ERROR VSYNC: v=%0d vsync=%b",
                    vcount_o, vsync_o
                );
                errores++;
            end

            // Región visible: 640 x 480
            if (video_on_o !== ((hcount_o < 10'd640) &&
                                (vcount_o < 10'd480))) begin
                $error(
                    "ERROR VIDEO_ON: h=%0d v=%0d video_on=%b",
                    hcount_o, vcount_o, video_on_o
                );
                errores++;
            end

            ciclos++;
        end

        // Después de un frame completo deben regresar al origen.
        // El siguiente flanco completa el frame y reinicia los contadores
        @(posedge clk_pix_i);
        #1;

        if ((hcount_o !== 10'd0) || (vcount_o !== 10'd0)) begin
            $error(
                "ERROR: fin de frame esperado (0,0), obtenido (%0d,%0d)",
                hcount_o, vcount_o
            );
            errores++;
        end

        if (errores == 0)
            $display(
                "PASS: vga_timing supero %0d ciclos de un frame completo.",
                ciclos
            );
        else
            $fatal(1, "FAIL: se detectaron %0d errores.", errores);

        $finish;
    end

endmodule
