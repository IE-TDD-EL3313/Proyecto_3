// Memoria de video — ficha de cuarto nivel 7.3
// Fusiona: cálculo de dirección de tile + memoria de tiles de doble puerto.
// Puerto A (escritura, dominio clk_i / 100 MHz): CPU vía decodificador MMIO.
// Puerto B (lectura, dominio clk_pix_i / 25 MHz): lógica de video.

module vga_memory (
    // Puerto A: escritura desde el CPU
    input  logic        clk_i,        // 100 MHz
    input  logic        vga_we_i,
    input  logic [8:0]  vga_addr_i,   // 0-299
    input  logic [31:0] vga_wdata_i,

    // Puerto B: lectura desde la lógica de video
    input  logic        clk_pix_i,    // 25 MHz
    input  logic [9:0]  hcount_i,
    input  logic [9:0]  vcount_i,
    output logic [31:0] tile_data_o
);

    localparam int NUM_COLS  = 20;
    localparam int NUM_TILES = 300; // 20 x 15

    // Memoria de tiles: no se limpia por hardware (el software la inicializa)
    logic [31:0] mem [0:NUM_TILES-1];

    // Puerto A: escritura síncrona a clk_i
    always_ff @(posedge clk_i) begin
        if (vga_we_i && (vga_addr_i < NUM_TILES))
            mem[vga_addr_i] <= vga_wdata_i;
    end

    // Cálculo de dirección de tile: 32 es potencia de 2 -> desplazamiento, no división real
    logic [4:0] tile_col; // 0-19
    logic [3:0] tile_row; // 0-14
    logic [8:0] tile_addr;

    assign tile_col  = hcount_i[9:5];
    assign tile_row  = vcount_i[9:5];
    assign tile_addr = (tile_row * NUM_COLS) + tile_col;

    // Puerto B: lectura síncrona a clk_pix_i (latencia de 1 ciclo)
    always_ff @(posedge clk_pix_i) begin
        if (tile_addr < NUM_TILES)
            tile_data_o <= mem[tile_addr];
        else
            tile_data_o <= 32'b0;
    end
endmodule
