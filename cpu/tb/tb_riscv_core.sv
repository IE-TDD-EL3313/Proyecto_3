`timescale 1ns/1ps
// ROM y RAM solo para simulacion: externas al core, lectura combinacional.
module tb_riscv_core;
 logic clk_i=0, rst_i=1;
 always #5 clk_i=~clk_i;
 wire [31:0] ProgAddress_o,DataAddress_o,DataOut_o;
 wire we_o;
 logic [31:0] ProgIn_i,DataIn_i;
 logic [31:0] rom[0:255],ram[0:255],expected[0:63];
 integer n,stores=0,cycles=0;
 riscv_core dut(.*);
 always @* begin
  ProgIn_i=32'h00000013;
  if(ProgAddress_o < 1024) ProgIn_i=rom[ProgAddress_o[9:2]];
 end
 always @* begin
  DataIn_i=0;
  if(DataAddress_o>=32'h2000 && DataAddress_o<32'h2400)
   DataIn_i=ram[DataAddress_o[9:2]];
 end
 initial begin
  for(n=0;n<256;n=n+1) begin rom[n]=32'h00000013;ram[n]=0; end
  rom[0]=32'h00200f93; // addi x31,x0,2
  rom[1]=32'h00cf9f93; // slli x31,x31,12: RAM base 0x2000
  rom[2]=32'hfff00093; // x1=-1
  rom[3]=32'h00300113; // x2=3
  rom[4]=32'h00100193; // x3=1
  rom[5]=32'h00208233; // add
  rom[6]=32'h004fa023; // sw x4, 0(x31)
  rom[7]=32'h40310233; // sub
  rom[8]=32'h004fa223; // sw x4, 4(x31)
  rom[9]=32'h0020f233; // and
  rom[10]=32'h004fa423; // sw x4, 8(x31)
  rom[11]=32'h00316233; // or
  rom[12]=32'h004fa623; // sw x4, 12(x31)
  rom[13]=32'h00314233; // xor
  rom[14]=32'h004fa823; // sw x4, 16(x31)
  rom[15]=32'h00219233; // sll
  rom[16]=32'h004faa23; // sw x4, 20(x31)
  rom[17]=32'h0020d233; // srl
  rom[18]=32'h004fac23; // sw x4, 24(x31)
  rom[19]=32'h4020d233; // sra
  rom[20]=32'h004fae23; // sw x4, 28(x31)
  rom[21]=32'h0020a233; // slt
  rom[22]=32'h024fa023; // sw x4, 32(x31)
  rom[23]=32'h0020b233; // sltu
  rom[24]=32'h024fa223; // sw x4, 36(x31)
  rom[25]=32'hffc10213; // addi
  rom[26]=32'h024fa423; // sw x4, 40(x31)
  rom[27]=32'h00f0f213; // andi
  rom[28]=32'h024fa623; // sw x4, 44(x31)
  rom[29]=32'h0041e213; // ori
  rom[30]=32'h024fa823; // sw x4, 48(x31)
  rom[31]=32'hfff14213; // xori
  rom[32]=32'h024faa23; // sw x4, 52(x31)
  rom[33]=32'h01f19213; // slli
  rom[34]=32'h024fac23; // sw x4, 56(x31)
  rom[35]=32'h01f0d213; // srli
  rom[36]=32'h024fae23; // sw x4, 60(x31)
  rom[37]=32'h41f0d213; // srai
  rom[38]=32'h044fa023; // sw x4, 64(x31)
  rom[39]=32'h0000a213; // slti
  rom[40]=32'h044fa223; // sw x4, 68(x31)
  rom[41]=32'hfff13213; // sltiu
  rom[42]=32'h044fa423; // sw x4, 72(x31)
  rom[43]=32'h07b00013; // intento escritura x0
  rom[44]=32'h040fa623; // sw x0, 76(x31)
  rom[45]=32'h000fa283; // lw x5,0(x31)
  rom[46]=32'h045fa823; // sw x5, 80(x31)
  rom[47]=32'h00210463; // branch a b0
  rom[48]=32'h3e1fae23; // FALLO si no toma branch
  rom[49]=32'h06208063; // branch a fail
  rom[50]=32'h00209463; // branch a b1
  rom[51]=32'h3e1fae23; // FALLO si no toma branch
  rom[52]=32'h04211a63; // branch a fail
  rom[53]=32'h0020c463; // branch a b4
  rom[54]=32'h3e1fae23; // FALLO si no toma branch
  rom[55]=32'h04114463; // branch a fail
  rom[56]=32'h00115463; // branch a b5
  rom[57]=32'h3e1fae23; // FALLO si no toma branch
  rom[58]=32'h0220de63; // branch a fail
  rom[59]=32'h00300313; // contador=3
  rom[60]=32'hfff30313; // contador--
  rom[61]=32'hfe031ee3; // branch a loop
  rom[62]=32'h046faa23; // sw x6, 84(x31)
  rom[63]=32'h008003ef; // jal x7, after_jal
  rom[64]=32'h3e1fae23; // FALLO si no toma jal
  rom[65]=32'h047fac23; // sw x7, 88(x31)
  rom[66]=32'h11500413; // base impar JALR
  rom[67]=32'h00040467; // jalr x8,0(x8)
  rom[68]=32'h3e1fae23; // FALLO si no toma jalr
  rom[69]=32'h048fae23; // sw x8, 92(x31)
  rom[70]=32'hffffffff; // instruccion no soportada: sin efectos
  rom[71]=32'h062fa023; // sw x2, 96(x31)
  rom[72]=32'h0000006f; // jal x0, done
  rom[73]=32'h3e1fae23; // FALLO branch no debia tomarse
  rom[74]=32'hffdff06f; // jal x0, fail
  expected[0]=32'h00000002;
  expected[1]=32'h00000002;
  expected[2]=32'h00000003;
  expected[3]=32'h00000003;
  expected[4]=32'h00000002;
  expected[5]=32'h00000008;
  expected[6]=32'h1fffffff;
  expected[7]=32'hffffffff;
  expected[8]=32'h00000001;
  expected[9]=32'h00000000;
  expected[10]=32'hffffffff;
  expected[11]=32'h0000000f;
  expected[12]=32'h00000005;
  expected[13]=32'hfffffffc;
  expected[14]=32'h80000000;
  expected[15]=32'h00000001;
  expected[16]=32'hffffffff;
  expected[17]=32'h00000001;
  expected[18]=32'h00000001;
  expected[19]=32'h00000000;
  expected[20]=32'h00000002;
  expected[21]=32'h00000000;
  expected[22]=32'h00000100;
  expected[23]=32'h00000110;
  expected[24]=32'h00000003;
  repeat(2) @(posedge clk_i);
  @(negedge clk_i);
  if(ProgAddress_o!==0 || we_o!==0) $fatal(1,"Reset incorrecto");
  rst_i=0;
 end
 always @(posedge clk_i) begin
  if(rst_i) begin
   if(we_o!==0) $fatal(1,"Escritura durante reset");
  end else begin
   cycles=cycles+1;
   if(ProgAddress_o[1:0]!==0 || ProgAddress_o>=1024)
    $fatal(1,"PC invalido %h",ProgAddress_o);
   if(we_o) begin
    if(stores>=25) $fatal(1,"Escritura extra");
    if(DataAddress_o !== (32'h2000+4*stores) || DataOut_o!==expected[stores])
     $fatal(1,"Store %0d: direccion=%h dato=%h esperado=%h",stores,DataAddress_o,DataOut_o,expected[stores]);
    ram[DataAddress_o[9:2]] <= DataOut_o;
    stores=stores+1;
   end
   if(ProgAddress_o==32'h00000120) begin
    if(stores!=25) $fatal(1,"Faltan escrituras: %0d",stores);
    $display("PASS: core integrado, 27 instrucciones, %0d escrituras verificadas, %0d ciclos",stores,cycles);
    $finish;
   end
   if(cycles>500) $fatal(1,"Timeout de ejecucion");
  end
 end
 initial begin #10000; $fatal(1,"Timeout global"); end
endmodule
