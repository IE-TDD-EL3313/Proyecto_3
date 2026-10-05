# Procesador RISC-V uniciclo — Proyecto 3

Procesador de 32 bits implementado en SystemVerilog, acompañado de ROM, RAM y pruebas funcionales.

## Arquitectura

El diseño es uniciclo y tiene buses separados para instrucciones y datos. El PC selecciona una instrucción de la ROM; la unidad de control la decodifica y el banco de registros entrega los operandos. La ALU calcula el resultado o la dirección de datos. El multiplexor de escritura selecciona el resultado ALU, el dato leído o PC+4. Las bifurcaciones y saltos permiten cambiar el flujo del programa.

Las lecturas son combinacionales. En el flanco ascendente se actualizan el PC, los registros habilitados y las escrituras de memoria. Estas operaciones corresponden a una misma instrucción, no a etapas de un pipeline.

| Característica | Implementación |
| --- | --- |
| Datos, instrucciones y direcciones | 32 bits |
| Banco de registros | 32 registros arquitectónicos; x0 siempre vale cero |
| ROM de instrucciones | 8 KiB: 2048 palabras de 32 bits |
| RAM de datos | 4 KiB: 1024 palabras de 32 bits |
| Direccionamiento | Direcciones en bytes; palabras alineadas a 4 bytes |
| Entrada/salida | Periféricos mapeados en memoria mediante MMIO |
| Reset | Síncrono activo alto: reinicia PC y registros; conserva RAM |

El núcleo implementa un subconjunto RV32I, sin interrupciones, excepciones ni protocolo de espera ready/stall. La ROM se carga desde un archivo hexadecimal y el software debe inicializar los datos de RAM antes de leerlos.

## Las 29 instrucciones soportadas

| Grupo | Instrucciones | Función |
| --- | --- | --- |
| Aritmética | ADD, SUB, ADDI | Suma y resta |
| Lógica | AND, OR, XOR, ANDI, ORI, XORI | Operaciones lógicas bit a bit |
| Desplazamientos | SLL, SLLI, SRL, SRLI, SRA, SRAI | Desplazamientos lógicos y aritméticos |
| Comparaciones | SLT, SLTI, SLTU, SLTIU | Menor que, con y sin signo |
| Memoria | LW, SW | Lectura y escritura de palabras de 32 bits |
| Bifurcaciones | BEQ, BNE, BLT, BGE | Cambio condicional del PC |
| Saltos | JAL, JALR | Salto con dirección de retorno |
| Inmediato superior | LUI, AUIPC | Carga de inmediato superior y suma de inmediato superior al PC |

## Carpetas y archivos

| Ruta | Contenido |
| --- | --- |
| `src/` | Los 17 módulos SystemVerilog del núcleo y las memorias |
| `tb/` | Cinco testbenches autoverificables |
| `firmware/` | Diagnóstico en ensamblador, imagen HEX y script de enlazado |
| `scripts/` | Scripts de simulación y generación del firmware |
| `evidencia/` | Logs conservados de las simulaciones de la entrega |
| `sim/results/` | Compilados y logs generados al ejecutar las pruebas; no incluidos en el ZIP |
| `core_sources.f` | Lista de fuentes RTL utilizada por Icarus Verilog |
| `README.md` | Arquitectura, contenido y simulaciones |
| `REVISION_ISSUE_28.md` | Revisión de requisitos y evidencia del issue del procesador |

### Módulos de src/

| Archivo | Función |
| --- | --- |
| `riscv_core.sv` | Conecta datapath, control y buses externos del procesador |
| `instruction_decoder.sv` | Extrae opcode, funct3, funct7 y los índices rs1, rs2 y rd |
| `control_unit.sv` | Genera las señales de operación, selección y escritura |
| `register_file.sv` | Implementa dos lecturas y una escritura; mantiene x0 en cero |
| `alu.sv` | Ejecuta aritmética, lógica, desplazamientos, comparaciones y paso del inmediato para LUI |
| `immediate_generator.sv` | Construye los inmediatos I, S, B, J y U |
| `pc_register.sv` | Almacena el PC y lo actualiza en el flanco ascendente |
| `pc_plus4.sv` | Calcula la dirección secuencial PC+4 |
| `branch_comparator.sv` | Evalúa BEQ, BNE, BLT y BGE |
| `branch_jump_logic.sv` | Calcula destinos de branch, JAL y JALR y decide el cambio de flujo |
| `mux_a.sv` | Selecciona RD1 o PC como primer operando de la ALU |
| `mux_b.sv` | Selecciona RD2 o el inmediato como segundo operando de la ALU |
| `mux_writeback.sv` | Selecciona resultado ALU, dato leído o PC+4 para escribir un registro |
| `mux_next_pc.sv` | Selecciona PC+4 o el destino de salto como siguiente PC |
| `program_rom.sv` | Almacena instrucciones y las entrega con lectura combinacional |
| `data_ram.sv` | Almacena datos con lectura combinacional y escritura síncrona |
| `processor_subsystem.sv` | Une núcleo, ROM y RAM; selecciona el espacio MMIO externo |

### Firmware y scripts

| Archivo | Función |
| --- | --- |
| `firmware/handoff.S` | Diagnóstico de los extremos de RAM, lectura de entradas y escritura LED/VGA mediante MMIO; no contiene el juego |
| `firmware/handoff.hex` | Imagen de instrucciones del diagnóstico cargada por la ROM |
| `firmware/link.ld` | Define la disposición del programa para el enlazador |
| `scripts/test_core.ps1` | Compila y ejecuta las cinco pruebas con Icarus Verilog y vvp |
| `scripts/build_firmware.ps1` | Genera la imagen HEX; para este paquete se utiliza `-Program handoff` |

## Testbenches y simulaciones

Se utiliza **Icarus Verilog** para compilar SystemVerilog y **vvp** para ejecutar las simulaciones. Los testbenches comparan los resultados con valores esperados y detienen la ejecución con error si una comprobación falla.

| Testbench | Qué verifica | Resultado registrado |
| --- | --- | --- |
| `tb_stage3.sv` | PC, reset, suma PC+4 y selección de multiplexores | PASS: 22 comprobaciones |
| `tb_stage4.sv` | Campos de instrucción, control, instrucciones inválidas y destinos de branch/JAL/JALR | PASS: 80 comprobaciones |
| `tb_riscv_core.sv` | Ejecución integrada de las 27 instrucciones originales, comprobando direcciones y datos escritos | PASS: 25 escrituras verificadas en 71 ciclos |
| `tb_core_edges.sv` | LUI/AUIPC, x0, reset y límites de inmediatos y desplazamientos | PASS: 10 escrituras verificadas |
| `tb_processor_subsystem.sv` | Núcleo con ROM/RAM del RTL, extremos de RAM, MMIO simulado y reset | PASS: 3 escrituras MMIO verificadas |

Desde la raíz de la carpeta, con Icarus Verilog y vvp disponibles en PATH:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_core.ps1
```

Los resultados nuevos quedan en `sim/results/`; los logs de la entrega están en `evidencia/`. Son pruebas dirigidas del procesador y las memorias con periféricos simulados; no constituyen una simulación del juego completo.
