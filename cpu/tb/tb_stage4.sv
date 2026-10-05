`timescale 1ns/1ps
// Testbench no sintetizable: control, campos y destinos de salto.
module tb_stage4;
 logic [31:0] ProgIn_i;
 logic [6:0] opcode,funct7;
 logic [2:0] funct3;
 logic [4:0] rs1,rs2,rd;
 logic RegWrite,ALUSrcA,ALUSrcB,Branch,Jump,JALR,MemWrite;
 logic [3:0] ALUControl;
 logic [2:0] ImmSrc;
 logic [1:0] ResultSrc,BranchCtrl;
 logic [31:0] PC=32'h100,RD1=32'h201,Imm=32'hfffffffc,TargetPC;
 logic BranchTaken=0,PCSrc;
 integer checks=0;
 instruction_decoder decoder(.*);
 control_unit control(.*);
 branch_jump_logic jumps(.*);
 task automatic verify(input logic ok,input string label);
  begin checks++; if(ok !== 1'b1) $fatal(1,"Fallo: %s",label); end
 endtask
 // Valores esperados de la tabla de control, independientes del one-hot interno.
 task automatic decode_test(input string label,input logic [6:0] opc,
 input logic [2:0] f3,input logic [6:0] f7,
 input logic wr,srcb,input logic [3:0] alu,
 input logic [2:0] immfmt,input logic [1:0] wb,bc,
 input logic br,j,jr,mw);
  begin
   ProgIn_i={f7,5'd19,5'd7,f3,5'd11,opc}; #1;
   verify({RegWrite,ALUSrcA,ALUSrcB,ALUControl,ImmSrc,ResultSrc,BranchCtrl,Branch,Jump,JALR,MemWrite}
       === {wr,1'b0,srcb,alu,immfmt,wb,bc,br,j,jr,mw},label);
   verify({opcode,funct3,funct7,rs1,rs2,rd} === {opc,f3,f7,5'd7,5'd19,5'd11},"Campos");
  end
 endtask
 initial begin
  decode_test("lw",3,2,0,1,1,0,0,1,0,0,0,0,0);
  decode_test("sw",35,2,0,0,1,0,1,0,0,0,0,0,1);
  decode_test("add",51,0,0,1,0,0,0,0,0,0,0,0,0);
  decode_test("sub",51,0,32,1,0,1,0,0,0,0,0,0,0);
  decode_test("sll",51,1,0,1,0,5,0,0,0,0,0,0,0);
  decode_test("srl",51,5,0,1,0,6,0,0,0,0,0,0,0);
  decode_test("sra",51,5,32,1,0,7,0,0,0,0,0,0,0);
  decode_test("and",51,7,0,1,0,2,0,0,0,0,0,0,0);
  decode_test("or",51,6,0,1,0,3,0,0,0,0,0,0,0);
  decode_test("xor",51,4,0,1,0,4,0,0,0,0,0,0,0);
  decode_test("slt",51,2,0,1,0,8,0,0,0,0,0,0,0);
  decode_test("sltu",51,3,0,1,0,9,0,0,0,0,0,0,0);
  decode_test("addi negativo",19,0,127,1,1,0,0,0,0,0,0,0,0);
  decode_test("andi negativo",19,7,127,1,1,2,0,0,0,0,0,0,0);
  decode_test("ori negativo",19,6,127,1,1,3,0,0,0,0,0,0,0);
  decode_test("xori negativo",19,4,127,1,1,4,0,0,0,0,0,0,0);
  decode_test("slti negativo",19,2,127,1,1,8,0,0,0,0,0,0,0);
  decode_test("sltiu negativo",19,3,127,1,1,9,0,0,0,0,0,0,0);
  decode_test("slli",19,1,0,1,1,5,0,0,0,0,0,0,0);
  decode_test("srli",19,5,0,1,1,6,0,0,0,0,0,0,0);
  decode_test("srai",19,5,32,1,1,7,0,0,0,0,0,0,0);
  decode_test("beq",99,0,127,0,0,0,2,0,0,1,0,0,0);
  decode_test("bne",99,1,127,0,0,0,2,0,1,1,0,0,0);
  decode_test("blt",99,4,127,0,0,0,2,0,2,1,0,0,0);
  decode_test("bge",99,5,127,0,0,0,2,0,3,1,0,0,0);
  decode_test("jal",111,7,127,1,0,0,3,2,0,0,1,0,0);
  decode_test("jalr",103,0,127,1,0,0,0,2,0,0,1,1,0);
  decode_test("M no soportada",51,0,1,0,0,0,0,0,0,0,0,0,0);
  decode_test("funct7 invalido",51,7,32,0,0,0,0,0,0,0,0,0,0);
  decode_test("shift invalido",19,1,32,0,0,0,0,0,0,0,0,0,0);
  decode_test("srli invalido",19,5,1,0,0,0,0,0,0,0,0,0,0);
  decode_test("lb",3,0,0,0,0,0,0,0,0,0,0,0,0);
  decode_test("sb",35,0,0,0,0,0,0,0,0,0,0,0,0);
  decode_test("bltu",99,6,0,0,0,0,0,0,0,0,0,0,0);
  decode_test("jalr invalido",103,1,0,0,0,0,0,0,0,0,0,0,0);
  decode_test("opcode invalido",0,0,0,0,0,0,0,0,0,0,0,0,0);
  // Bifurcacion negativa, condicion falsa y verdadera.
  ProgIn_i=32'h00000063; BranchTaken=0; #1;
  verify(TargetPC===32'hfc && PCSrc===0,"Branch no tomado");
  BranchTaken=1; #1;
  verify(TargetPC===32'hfc && PCSrc===1,"Branch tomado");
  // Una condicion verdadera no cambia flujo sin Branch.
  ProgIn_i=32'h00000013; #1;
  verify(PCSrc===0,"Condicion ignorada fuera de branch");
  // JAL usa PC, no PC+4 ni RD1.
  ProgIn_i=32'h0000006f; BranchTaken=0; Imm=8; #1;
  verify(TargetPC===32'h108 && PCSrc===1,"JAL");
  // JALR suma antes de limpiar bit cero y conserva bit uno.
  ProgIn_i=32'h00000067; RD1=32'h201; Imm=2; #1;
  verify(TargetPC===32'h202 && PCSrc===1,"JALR impar y bit uno");
  RD1=32'h201; Imm=1; #1;
  verify(TargetPC===32'h202,"Mascara despues de sumar");
  RD1=32'h100; Imm=32'hfffffffc; #1;
  verify(TargetPC===32'hfc,"JALR negativo");
  RD1=32'hffffffff; Imm=2; #1;
  verify(TargetPC===0,"Desbordamiento y mascara");
  $display("PASS: Etapa 4, %0d comprobaciones",checks);
  $finish;
 end
 initial begin #1000; $fatal(1,"Timeout"); end
endmodule
