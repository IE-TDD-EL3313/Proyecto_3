// Entrega del equipo CPU: procesador + ROM + RAM, sin implementaciones de perifericos.
// Todos los accesos son palabras de 32 bits con direccion expresada en bytes.
// Lecturas combinacionales, escrituras en flanco ascendente; no hay ready/stall.
module processor_subsystem #(parameter ROM_FILE="firmware/handoff.hex") (
 input logic clk_i, rst_i,
 input logic [31:0] mmio_rdata_i,
 output logic [31:0] mmio_addr_o, mmio_wdata_o,
 output logic mmio_sel_o, mmio_we_o,
 output logic [31:0] pc_o
);
 wire [31:0] instruction, address, wdata, rdata, ram_data;
 wire core_we;
 wire aligned=(address[1:0]==2'b00);
 wire ram_sel=aligned && address>=32'h2000 && address<32'h3000;
 // Seleccion del espacio periferico; cada equipo decodifica su rango exacto.
 assign mmio_sel_o=!rst_i && aligned && address>=32'h10000 && address<32'h20000;
 assign mmio_we_o=core_we && mmio_sel_o;
 assign mmio_addr_o=address;
 assign mmio_wdata_o=wdata;
 assign rdata=ram_sel ? ram_data : (mmio_sel_o ? mmio_rdata_i : 32'b0);
 riscv_core core(.clk_i(clk_i),.rst_i(rst_i),.ProgIn_i(instruction),.DataIn_i(rdata),
  .ProgAddress_o(pc_o),.DataAddress_o(address),.DataOut_o(wdata),.we_o(core_we));
 program_rom #(.INIT_FILE(ROM_FILE)) rom(.addr_i(pc_o),.instr_o(instruction));
 data_ram ram(.clk_i(clk_i),.we_i(core_we && ram_sel && !rst_i),
  .addr_i(address[11:2]),.wdata_i(wdata),.rdata_o(ram_data));
endmodule
