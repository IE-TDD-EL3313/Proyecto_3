// Controlador de displays de 7 segmentos — ficha de cuarto nivel 7.6
// Fusiona: registro de datos, selector de dígito, mux de dígito,
//          decodificador de 7 segmentos y driver de ánodos.

module seg7_ctrl #(
    parameter int DIGIT_HOLD_CYCLES = 100_000
) (
    input  logic        clk_i,    // 100 MHz
    input  logic        rst_i,
    input  logic [31:0] wdata_i,  // 4 digitos BCD, 4 bits cada uno (0x0001_0130)
    input  logic        we_i,
    output logic [6:0]  seg_o,    // patron gfedcba
    output logic [3:0] anode_o,  // activo en bajo
    output logic [31:0] rdata_o   // lectura del registro de datos actual (mux de lectura, P3 ficha 7.27)
);

    // --- Registro de datos ---
    logic [15:0] disp_data;

    always_ff @(posedge clk_i) begin
        if (rst_i)
            disp_data <= 16'b0;
        else if (we_i)
            disp_data <= wdata_i[15:0];
    end

    // --- Selector de digito: recorre los 4 digitos a ~250 Hz (sin parpadeo) ---
    localparam int CNT_WIDTH = $clog2(DIGIT_HOLD_CYCLES);

    logic [CNT_WIDTH-1:0] refresh_cnt;
    logic [1:0]           digit_sel;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            refresh_cnt <= '0;
            digit_sel   <= '0;
        end else if (refresh_cnt == DIGIT_HOLD_CYCLES - 1) begin
            refresh_cnt <= '0;
            digit_sel   <= digit_sel + 2'd1;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
        end
    end

    // --- Mux de digito ---
    logic [3:0] digit_value;

    always_comb begin
        unique case (digit_sel)
            2'd0: digit_value = disp_data[3:0];
            2'd1: digit_value = disp_data[7:4];
            2'd2: digit_value = disp_data[11:8];
            2'd3: digit_value = disp_data[15:12];
        endcase
    end

    // --- Decodificador de 7 segmentos (gfedcba, activo en bajo) ---
    always_comb begin
        unique case (digit_value)
            4'h0: seg_o = 7'b1000000;
            4'h1: seg_o = 7'b1111001;
            4'h2: seg_o = 7'b0100100;
            4'h3: seg_o = 7'b0110000;
            4'h4: seg_o = 7'b0011001;
            4'h5: seg_o = 7'b0010010;
            4'h6: seg_o = 7'b0000010;
            4'h7: seg_o = 7'b1111000;
            4'h8: seg_o = 7'b0000000;
            4'h9: seg_o = 7'b0010000;
            default: seg_o = 7'b1111111; // valor no BCD: display apagado
        endcase
    end

    assign rdata_o = {16'b0, disp_data};

    // --- Driver de anodos: activo en bajo en Nexys 4 ---
    always_comb begin
        anode_o = 4'b1111;
        anode_o[digit_sel] = 1'b0;
    end

endmodule
