// Extraccion combinacional: no interpreta ni valida instrucciones.
module instruction_decoder (
 input logic [31:0] ProgIn_i,
 output logic [6:0] opcode, funct7,
 output logic [2:0] funct3,
 output logic [4:0] rs1, rs2, rd
);
 assign opcode = ProgIn_i[6:0];
 assign funct3 = ProgIn_i[14:12];
 assign funct7 = ProgIn_i[31:25];
 assign rs1 = ProgIn_i[19:15];
 assign rs2 = ProgIn_i[24:20];
 assign rd = ProgIn_i[11:7];
endmodule
