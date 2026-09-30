// Registro del LED de estado — ficha de cuarto nivel 7.7
// Unidad minima: no se fusiona con nada, ya es un solo registro.

module led_reg (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [31:0] wdata_i,  // solo se usan los bits [2:0] (0x0001_0138)
    input  logic        we_i,
    output logic [2:0]  led_o,
    output logic [31:0] rdata_o  // lectura del registro (mux de lectura, P3 ficha 7.27)
);

    // Codificacion propuesta (ver Seccion 9 de la ficha):
    //   001 = fase de colocacion
    //   010 = fase de batalla
    //   100 = resultado final

    always_ff @(posedge clk_i) begin
        if (rst_i)
            led_o <= 3'b000;
        else if (we_i)
            led_o <= wdata_i[2:0];
    end

    assign rdata_o = {29'b0, led_o};

endmodule
