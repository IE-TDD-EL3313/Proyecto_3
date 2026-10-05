`timescale 1ns/1ps
// Los perifericos son un MODELO de prueba, no hardware para entregar a otros equipos.
module tb_processor_subsystem;
 logic clk_i=0,rst_i=1;
 always #10 clk_i=~clk_i;
 wire [31:0] mmio_addr_o,mmio_wdata_o,pc_o;
 wire mmio_sel_o,mmio_we_o;
 logic [31:0] mmio_rdata_i;
 integer writes=0,cycles=0;
 processor_subsystem dut(.*);
 always @* begin
  mmio_rdata_i=0;
  if(mmio_sel_o && mmio_addr_o==32'h10120) mmio_rdata_i=32'h2;
 end
 initial begin
  repeat(3) @(negedge clk_i); rst_i=0;
  wait(writes==3);
  @(negedge clk_i);
  if(dut.ram.words[0]!==32'h12345678 || dut.ram.words[1023]!==32'h12345678)
   $fatal(1,"RAM: primera/ultima palabra");
  if(dut.ram.words[1]!==2) $fatal(1,"Lectura de periferico no llego a RAM");
  rst_i=1; #1;
  if(mmio_sel_o!==0 || mmio_we_o!==0) $fatal(1,"MMIO durante reset");
  @(posedge clk_i); #1;
  if(pc_o!==0) $fatal(1,"Vector de reset");
  if(dut.ram.words[0]!==32'h12345678) $fatal(1,"RAM no debe borrarse con reset");
  $display("PASS: entrega CPU+ROM+RAM, MMIO externo y reset, 3 escrituras");
  $finish;
 end
 always @(posedge clk_i) if(!rst_i) begin
  cycles++;
  if(mmio_we_o) begin
   if(!mmio_sel_o) $fatal(1,"WE sin seleccion");
   case(writes)
    0:if(mmio_addr_o!==32'h10138 || mmio_wdata_o!==5) $fatal(1,"Escritura LED inicial");
    1:if(mmio_addr_o!==32'h11000 || mmio_wdata_o!==2) $fatal(1,"Escritura VGA");
    2:if(mmio_addr_o!==32'h10138 || mmio_wdata_o!==1) $fatal(1,"Fin del programa");
    default:$fatal(1,"Escritura extra");
   endcase
   writes++;
  end
  if(cycles>100) $fatal(1,"Timeout entrega PC=%h",pc_o);
 end
endmodule
