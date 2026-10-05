`timescale 1ns/1ps
module tb_core_edges;
 logic clk_i=0, rst_i=1;
 always #5 clk_i=~clk_i;
 logic [31:0] ProgIn_i, DataIn_i=0;
 wire [31:0] ProgAddress_o,DataAddress_o,DataOut_o;
 wire we_o;
 logic [31:0] rom[0:63];
 logic [31:0] expected[0:9];
 integer stores=0,n;
 riscv_core dut(.*);
 assign ProgIn_i=rom[ProgAddress_o[7:2]];
 function automatic [31:0] itype(input integer imm,rs,f3,rd);
  itype=((imm & 4095)<<20)|(rs<<15)|(f3<<12)|(rd<<7)|32'h13;
 endfunction
 function automatic [31:0] store_word(input integer rs,offset);
  store_word=((offset>>5)<<25)|(rs<<20)|(2<<12)|((offset & 31)<<7)|32'h23;
 endfunction
 initial begin
  for(n=0;n<64;n=n+1) rom[n]=32'h0000006f;
  rom[0]=itype(99,0,0,1);
  // Immediate contains rs1 field=1: LUI must ignore the nonzero x1.
  rom[1]=32'h00008137; // lui x2,8
  rom[2]=store_word(2,0); expected[0]=32'h8000;
  rom[3]=32'hfffff197; // auipc x3,fffff at PC=12
  rom[4]=store_word(3,4); expected[1]=32'hfffff00c;
  rom[5]=32'h80000237; // lui x4,80000
  rom[6]=store_word(4,8); expected[2]=32'h80000000;
  rom[7]=32'h000002b7; // lui x5,0
  rom[8]=store_word(5,12); expected[3]=0;
  rom[9]=32'h12345037; // lui x0,12345
  rom[10]=32'h00001017; // auipc x0,1
  rom[11]=store_word(0,16); expected[4]=0;
  rom[12]=itype(-2048,0,0,6);
  rom[13]=store_word(6,20); expected[5]=32'hfffff800;
  rom[14]=itype(2047,6,0,6);
  rom[15]=store_word(6,24); expected[6]=32'hffffffff;
  rom[16]=itype(32,0,0,7);
  rom[17]=32'h00721333; // sll x6,x4,x7: shamt 32 masks to 0
  rom[18]=store_word(6,28); expected[7]=32'h80000000;
  rom[19]=itype(-1,0,0,7);
  rom[20]=32'h00725333; // srl x6,x4,x7: shamt 31
  rom[21]=store_word(6,32); expected[8]=1;
  rom[22]=32'h40725333; // sra x6,x4,x7
  rom[23]=store_word(6,36); expected[9]=32'hffffffff;
  rom[24]=store_word(4,40); // Se bloquea al afirmar reset antes del siguiente flanco.
  repeat(2) @(negedge clk_i); rst_i=0;
  wait(stores==10); @(negedge clk_i);
  // Reset during an instruction that would write RAM, then resume from PC=0.
  rst_i=1;
  @(posedge clk_i); #1;
  if(ProgAddress_o!==0 || we_o!==0) $fatal(1,"Reset del core");
  if(dut.u_register_file.registers[4]!==0) $fatal(1,"Reset de registros");
  $display("PASS: LUI/AUIPC, limites de inmediatos/shifts y x0, 10 stores");
  $finish;
 end
 always @(posedge clk_i) if(!rst_i && we_o) begin
  if(stores>=10) $fatal(1,"Store extra");
  if(DataAddress_o!==4*stores || DataOut_o!==expected[stores])
   $fatal(1,"Store %0d: %h esperado %h",stores,DataOut_o,expected[stores]);
  stores=stores+1;
 end
 initial begin #10000; $fatal(1,"Timeout edges"); end
endmodule
