# Procesador RISC-V uniciclo — Proyecto 3

Implementación modular en SystemVerilog de un procesador de 32 bits para la
plataforma del juego Batalla Naval. Incluye el núcleo, memorias de instrucciones
y datos, una interfaz externa para periféricos y pruebas reproducibles.

Seguimiento: [issue #28](https://github.com/IE-TDD-EL3313/Proyecto_3/issues/28).

## Alcance

Esta carpeta entrega hardware del procesador y un subsistema de prueba e
integración con ROM/RAM. No contiene el programa final del juego, VGA, UART,
aplicación Python, PLL ni restricciones de pines de la tarjeta.

El procesador implementa un **subconjunto RV32I**, no la arquitectura completa.
Las pruebas funcionales del paquete están aprobadas. La integración del equipo,
la ejecución del juego, el timing del top final y la validación física siguen
pendientes. El documento `REVISION_ISSUE_28.md` registra el alcance de la revisión.

## Arquitectura y funcionamiento

El diseño es uniciclo: la ROM entrega la instrucción indicada por el PC, el
control la decodifica, el banco de registros entrega los operandos y la ALU
calcula el resultado o la dirección de datos. El multiplexor de escritura
selecciona el resultado ALU, el dato leído o PC+4. En el siguiente flanco
ascendente se actualizan los registros habilitados, el PC y cualquier escritura
de memoria. Las bifurcaciones y saltos seleccionan un destino alternativo.

- Datos, instrucciones y direcciones de 32 bits.
- Buses separados para instrucciones y datos; direcciones expresadas en bytes.
- Banco de 32 registros arquitectónicos; x0 siempre vale cero.
- Lecturas combinacionales y escrituras en flanco ascendente.
- Reset síncrono activo alto: PC y registros vuelven a cero; RAM se conserva.
- Sin pipeline, interrupciones, excepciones ni protocolo de espera ready/stall.

### Instrucciones soportadas

| Grupo | Instrucciones |
| --- | --- |
| Aritmética | ADD, SUB, ADDI |
| Lógica | AND, OR, XOR, ANDI, ORI, XORI |
| Desplazamientos | SLL, SLLI, SRL, SRLI, SRA, SRAI |
| Comparaciones | SLT, SLTI, SLTU, SLTIU |
| Memoria | LW, SW |
| Bifurcaciones | BEQ, BNE, BLT, BGE |
| Saltos | JAL, JALR |
| Inmediato superior | LUI, AUIPC |

Son 29 instrucciones. No se incluyen accesos de byte/media palabra, BLTU/BGEU,
CSR, multiplicación ni instrucciones comprimidas. Las instrucciones no
soportadas no escriben registros ni memoria y avanzan secuencialmente, sin trap.

## Contenido de la carpeta

| Ruta | Contenido |
| --- | --- |
| `src/riscv_core.sv` | Conexión del datapath y control del núcleo |
| `src/control_unit.sv`, `instruction_decoder.sv` | Decodificación y señales de control |
| `src/register_file.sv`, `alu.sv` | Registros y operaciones aritmético-lógicas |
| `src/immediate_generator.sv` | Inmediatos de formatos I, S, B, J y U |
| `src/pc_register.sv`, `pc_plus4.sv` | PC y avance secuencial |
| `src/branch_comparator.sv`, `branch_jump_logic.sv` | Comparaciones y destinos de salto |
| `src/mux_*.sv` | Selección de operandos, escritura y próximo PC |
| `src/program_rom.sv`, `data_ram.sv` | ROM de 8 KiB y RAM de 4 KiB |
| `src/processor_subsystem.sv` | Núcleo + ROM + RAM + selección MMIO |
| `core_sources.f` | Lista de los 17 módulos RTL necesarios |
| `tb/` | Cinco testbenches autoverificables |
| `firmware/` | Diagnóstico `handoff.S`, imagen `handoff.hex` y `link.ld` |
| `scripts/` | Ejecución de pruebas y regeneración del firmware |
| `evidencia/` | Logs de simulación de esta entrega |

## Memorias e interfaz externa

| Recurso | Rango de bytes | Capacidad |
| --- | --- | --- |
| ROM, bus de instrucciones | 0x00000000–0x00001FFF | 2048 palabras |
| RAM, bus de datos | 0x00002000–0x00002FFF | 1024 palabras |
| Espacio MMIO externo | 0x00010000–0x0001FFFF | Decodificación externa |

La ROM se inicializa con `$readmemh`; `ROM_FILE` selecciona el archivo HEX, con
una instrucción de 32 bits por línea. RAM no se inicializa automáticamente:
el software debe escribir antes de leer. El subsistema ignora escrituras de
datos desalineadas/fuera de rango y devuelve cero en esas lecturas. Una dirección
de instrucción inválida devuelve NOP.

| Puerto de `processor_subsystem` | Función |
| --- | --- |
| `clk_i`, `rst_i` | Reloj y reset |
| `mmio_addr_o[31:0]` | Dirección de byte del periférico |
| `mmio_wdata_o[31:0]` | Dato de escritura |
| `mmio_rdata_i[31:0]` | Dato de lectura combinacional externo |
| `mmio_sel_o` | Dirección alineada selecciona espacio MMIO; cero en reset |
| `mmio_we_o` | Escritura MMIO habilitada; cero en reset |
| `pc_o[31:0]` | PC para depuración |

`mmio_sel_o` no es una orden de lectura: puede activarse para resultados ALU
de otras instrucciones. Leer un periférico no debe consumir datos ni borrar
banderas. Un dato de lectura debe estar disponible en el mismo ciclo; una
memoria de salida registrada necesita adaptación.

## Integración

Agregar los archivos de `core_sources.f` al proyecto y elegir una opción:

1. **Núcleo independiente:** instanciar `riscv_core` y conectar sus buses a ROM,
   RAM y a la interconexión del equipo. El top resuelve selección y alineación.
2. **Subsistema completo:** instanciar `processor_subsystem` y conectar `mmio_*`
   al decodificador y multiplexor de periféricos. La RAM ya está incluida.

```systemverilog
processor_subsystem #(.ROM_FILE("firmware/handoff.hex")) cpu_mem (
    .clk_i(clk_sys),
    .rst_i(rst_sys),
    .mmio_addr_o(io_addr),
    .mmio_wdata_o(io_wdata),
    .mmio_rdata_i(io_rdata),
    .mmio_sel_o(io_sel),
    .mmio_we_o(io_we),
    .pc_o()
);
```

El fragmento es una instancia, no un top completo: el integrador declara las
señales, genera reloj/reset y conecta los periféricos. Debe existir una sola RAM
de datos. El reparto del repositorio asigna memorias/interconexión a P3; acordar
con ese responsable cuál opción utilizar.

Para inspección RTL en Vivado, seleccionar `processor_subsystem` como top y
abrir RTL Analysis → Open Elaborated Design → Schematic. Agregar el HEX como
archivo de memoria y verificar que `ROM_FILE` se resuelva desde el directorio
de ejecución de síntesis/simulación. Para la FPGA, usar el top final del equipo.

La frecuencia admisible depende de la implementación. Los periféricos actuales
del equipo están planteados para 100 MHz; esta entrega no certifica timing del
conjunto a esa frecuencia. Tampoco incluye asignación de pines.

La VGA del repositorio revisado admite escritura CPU a 300 tiles y no tiene
puerto de lectura CPU. Acordar el valor de lectura de ese rango con el integrador.
El programa debe respetar los registros y el protocolo UART definidos por el equipo.

## Reproducir las simulaciones

Requisitos: PowerShell, Icarus Verilog y `vvp` disponibles en PATH. Desde la raíz
de esta carpeta, donde está `core_sources.f`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_core.ps1
```

| Prueba | Evidencia esperada |
| --- | --- |
| `tb_stage3` | 22 comprobaciones de PC y multiplexores |
| `tb_stage4` | 80 comprobaciones de control, campos y saltos |
| `tb_riscv_core` | 27 instrucciones, 25 escrituras verificadas |
| `tb_core_edges` | LUI/AUIPC, x0, reset, inmediatos y shifts; 10 stores |
| `tb_processor_subsystem` | ROM/RAM reales, MMIO simulado y reset; 3 escrituras MMIO |

El script termina con error si falla la compilación o una comprobación.
Los logs nuevos quedan en `sim/results/`. Las pruebas son dirigidas; no equivalen
a cobertura exhaustiva ni a una partida completa.

`handoff.hex` escribe y lee la primera y última palabra de RAM, lee entradas
simuladas y escribe registros de LED/VGA. Es un diagnóstico, no el juego.
Para regenerarlo con GNU RISC-V de AMD Design Tools:

```powershell
./scripts/build_firmware.ps1 -Program handoff
# Si cambia la instalación, agregar: -Toolchain 'C:/ruta/gnu/riscv/nt/bin'
```

Usar explícitamente `-Program handoff`: la otra opción del script pertenece a la
plataforma de referencia y su firmware no está en este paquete.

## Entrega y trazabilidad

Conservar juntos fuentes, pruebas, firmware y estos documentos. Si se cambia
`src/` por `rtl/cpu/`, actualizar `core_sources.f` y volver a ejecutar las pruebas.
Los logs en `evidencia/` respaldan esta versión; nuevas modificaciones requieren
nueva validación. No subir cachés, proyectos temporales ni binarios de Vivado.

El PR puede referenciar `Refs #28`. Mantener pendiente el cierre hasta validar
el firmware final y la integración. Esta carpeta no se ha publicado automáticamente.
