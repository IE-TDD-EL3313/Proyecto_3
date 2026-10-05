// 4 KiB, direccion local de PALABRA. No se borra en reset: inicializar en software.
// Lectura asincrona; no presupone inferencia de block RAM con salida registrada.
module data_ram (
 input logic clk_i, we_i,
 input logic [9:0] addr_i,
 input logic [31:0] wdata_i,
 output logic [31:0] rdata_o
);
 logic [31:0] words [0:1023];
 always_ff @(posedge clk_i)
  if (we_i) words[addr_i] <= wdata_i;
 assign rdata_o=words[addr_i];
endmodule
