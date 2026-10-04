// Condicionador de entradas de botones — ficha de cuarto nivel 7.5
// Fusiona: sincronizador + filtro antirrebote (reciclado del Proyecto 2) +
//          detector de flanco + registro de estado (bus MMIO).
//
// Requiere compilar junto a button_debouncer.sv (sin modificar) del
// proyecto anterior.
//
// Orden de bits en btn_raw_i / btn_status:
//   [0] arriba  [1] abajo  [2] izquierda  [3] derecha
//   [4] SEL     [5] OK     [6] RST

module btn_input #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 10
) (
    input  logic        clk_i,        // 100 MHz
    input  logic        rst_i,
    input  logic [6:0]  btn_raw_i,
    output logic [31:0] rdata_o
);
    // Nota: sin addr_i. El decodificador de direcciones (P3, ficha 7.26)
    // no reenvia bits de direccion a los perifericos de una sola palabra;
    // genera un sel_INPUT/we.X dedicado por periferico en su lugar.

    // --- Generador de habilitación de 1 ms (para el debouncer reciclado) ---
    localparam int MS_COUNT = CLK_FREQ_HZ / 1000;
    localparam int MS_WIDTH = $clog2(MS_COUNT);

    logic [MS_WIDTH-1:0] ms_counter;
    logic                ce_1ms;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ms_counter <= '0;
            ce_1ms     <= 1'b0;
        end else if (ms_counter == MS_COUNT - 1) begin
            ms_counter <= '0;
            ce_1ms     <= 1'b1;
        end else begin
            ms_counter <= ms_counter + 1'b1;
            ce_1ms     <= 1'b0;
        end
    end

    // --- Sincronizador: 2 flip-flops por línea ---
    logic [6:0] btn_meta, btn_sync;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            btn_meta <= '0;
            btn_sync <= '0;
        end else begin
            btn_meta <= btn_raw_i;
            btn_sync <= btn_meta;
        end
    end

    // --- Filtro antirrebote: una instancia reciclada por botón ---
    logic [6:0] btn_stable;

    genvar i;
    generate
        for (i = 0; i < 7; i++) begin : gen_debounce
            button_debouncer #(
                .DEBOUNCE_MS(DEBOUNCE_MS)
            ) u_debounce (
                .clk         (clk_i),
                .reset       (rst_i),
                .ce_1ms      (ce_1ms),
                .button_sync (btn_sync[i]),
                .button_level(btn_stable[i])
            );
        end
    endgenerate

    // --- Detector de flanco: pulso de un ciclo por transición 0->1 ---
    logic [6:0] btn_stable_q;
    logic [6:0] btn_pulse;

    always_ff @(posedge clk_i) begin
        if (rst_i)
            btn_stable_q <= '0;
        else
            btn_stable_q <= btn_stable;
    end

    assign btn_pulse = btn_stable & ~btn_stable_q;

    // --- Registro de estado, leído por el CPU (0x0001_0120) ---
    logic [31:0] btn_status;

    always_ff @(posedge clk_i) begin
        if (rst_i)
            btn_status <= 32'b0;
        else
            btn_status <= {25'b0, btn_pulse};
    end

    assign rdata_o = btn_status;

endmodule
