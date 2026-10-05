// 8 KiB, direccion de byte. Lectura combinacional para el core uniciclo.
// La inicializacion de ROM debe ser soportada por la herramienta FPGA.
module program_rom #(parameter INIT_FILE = "") (
 input logic [31:0] addr_i,
 output logic [31:0] instr_o
);
 logic [31:0] words [0:2047];
 integer i;
 initial begin
  for (i=0; i<2048; i=i+1) words[i]=32'h00000013;
  if (INIT_FILE != "") $readmemh(INIT_FILE, words);
 end
 always @* begin
  instr_o=32'h00000013;
  if (addr_i < 32'h2000 && addr_i[1:0]==0)
   instr_o=words[addr_i[12:2]];
 end
endmodule
