# Planteamiento del diseño
## Proyecto 3 – Batalla Naval: juego de dos jugadores sobre un microprocesador RISC-V con periférico VGA

---

## 1. Introducción y comprensión del problema

Este documento presenta el planteamiento del diseño del sistema **Batalla Naval**. A diferencia de los proyectos anteriores, donde el comportamiento de la aplicación se describía mediante lógica combinacional, secuencial y máquinas de estado dedicadas en SystemVerilog, en este proyecto dicho comportamiento se describe como un programa en lenguaje ensamblador que se ejecuta sobre un procesador propio, diseñado por el equipo. El hardware desarrollado deja entonces de ser la aplicación en sí misma y pasa a ser la plataforma computacional —núcleo, memorias y periféricos— sobre la cual dicha aplicación corre.

La aplicación a implementar es una versión simplificada del clásico juego de Batalla Naval para dos jugadores. El **Jugador 1** interactúa físicamente con la tarjeta de FPGA: observa su tablero y el del oponente en un monitor VGA, y coloca barcos y dispara mediante botones locales. El **Jugador 2** interactúa de forma remota mediante una aplicación de PC desarrollada en Python, que se comunica con la FPGA por UART; dicha aplicación despliega en la PC el tablero propio del Jugador 2 y el estado conocido del tablero rival, y transmite hacia la FPGA las coordenadas de colocación de barcos y de disparo. Todo el control de la partida —colocación, turnos, validación de disparos, detección de barcos hundidos y condición de victoria— se ejecuta exclusivamente en el microprocesador RISC-V dentro de la FPGA; la aplicación de PC funciona como una terminal de entrada/salida remota, sin lógica de juego propia, de forma análoga al rol que cumplía la PC en el Proyecto 2.

Cada jugador cuenta con un tablero propio de 8×8 casillas y coloca una flota de tres barcos, de tamaños 4, 3 y 2 casillas, en orientación horizontal o vertical, sin que los barcos se traslapen ni salgan del tablero. Una casilla puede encontrarse en uno de cuatro estados visibles: agua, barco propio (visible únicamente a su dueño), impacto o fallo. Un barco se considera hundido cuando todas sus casillas han sido impactadas, y la partida se gana cuando un jugador hunde toda la flota contraria. Una restricción central del diseño es que, en ningún momento, un jugador puede observar la disposición de barcos del otro antes de descubrirla mediante disparos: ni el Jugador 1 en su pantalla VGA, ni la aplicación de PC del Jugador 2 a través de la información que recibe por UART.

El problema de diseño consiste entonces en construir, desde cero, tanto la plataforma de cómputo (núcleo RISC-V, memorias y periféricos mapeados en memoria) como el software que corre sobre ella (el programa en ensamblador que implementa las reglas del juego) y el protocolo de comunicación que conecta a ambos jugadores. Los periféricos únicamente deben exponer recursos de entrada/salida —video, botones, sonido, comunicación serial— sin contener lógica de reglas del juego; la única excepción es el manejo de bajo nivel estrictamente necesario para operar cada periférico (por ejemplo, temporización VGA, antirrebote de botones o formación de tramas UART a nivel de bit), el cual sí corresponde al hardware del periférico.

---

## 2. Objetivos del proyecto

**Objetivo general:** diseñar e implementar, sobre una FPGA, un microprocesador RISC-V de 32 bits (subconjunto rv32i) capaz de ejecutar un programa en ensamblador que controle por completo un juego de Batalla Naval de dos jugadores, coordinando un jugador local por VGA/botones y un jugador remoto conectado por UART.

**Objetivos específicos:**

1. Diseñar e implementar un microprocesador rv32i de ciclo único, sintetizable, con memorias de programa y datos accedidas mediante buses independientes.
2. Diseñar periféricos mapeados en memoria para generación de video VGA, lectura de entradas del jugador local e indicadores locales (displays de 7 segmentos, LED, buzzer), reutilizando el periférico UART del Proyecto 2 para la comunicación con el jugador remoto.
3. Implementar en ensamblador RISC-V la lógica completa de Batalla Naval: colocación de barcos, alternancia de turnos, validación de disparos y determinación de la partida.
4. Diseñar la aplicación de PC (Python) que actúa como interfaz remota del Jugador 2, y el protocolo de comunicación sobre UART entre dicha aplicación y el microprocesador.
5. Aplicar una metodología de diseño modular y validación por etapas, separando núcleo, memorias y cada periférico como bloques independientes y verificables.

---

## 3. Arquitectura general y subsistemas

El sistema integra una plataforma de cómputo embebida en la FPGA, compuesta por el núcleo RV32I, una memoria ROM de programa, una memoria RAM de datos y un conjunto de periféricos mapeados en memoria. La comunicación serial permite enlazar al segundo jugador desde una PC.

La memoria de programa se conecta al núcleo mediante un bus **dedicado** (`ProgAddress`/`ProgIn`), de forma que el fetch de instrucción nunca se ve bloqueado por un acceso a datos. La memoria de datos y todos los periféricos —UART, entradas del Jugador 1, VGA, buzzer y displays— comparten en cambio un mismo bus de datos de tres líneas (`address`, `write`, `read`), seleccionados mediante decodificación de direcciones.

Los principales bloques funcionales considerados son:

- Núcleo RISC-V (datapath + unidad de control).
- Memoria ROM de programa y memoria RAM de datos.
- Decodificación de direcciones (MMIO) y multiplexor de lectura del bus compartido.
- Periférico UART (reutilizado del Proyecto 2), único canal de interacción del Jugador 2.
- Periférico VGA, expuesto como memoria de video de doble puerto (mapa de tiles).
- Periférico de entradas del Jugador 1, con antirrebote.
- Periféricos de salida: displays de 7 segmentos, LED de estado, buzzer.
- Generación de relojes: reloj principal de 100 MHz y, mediante PLL, el reloj de píxel de 25 MHz para VGA.
- Aplicación de PC en Python, como interfaz remota del Jugador 2.

**Distribución hardware / software:**

- **Hardware (FPGA):** núcleo RISC-V, decodificador de direcciones, memorias, controlador VGA con doble puerto, controlador UART, periférico de botones con antirrebote, y drivers de displays, LED y buzzer.
- **Software (ensamblador RV32I):** control del flujo del juego, gestión de tableros en RAM, validación de reglas, control de fases y turnos.
- **Software externo (PC):** interfaz para visualización del tablero y envío de comandos del Jugador 2, sin lógica de juego propia.

---

## 4. Diagrama de primer nivel

El diagrama de primer nivel representa el sistema completo de la FPGA como un único bloque funcional, identificando únicamente sus interfaces físicas con el exterior.

**Entradas:**

| Señal | Descripción |
|---|---|
| `CLK` | Reloj principal de 100 MHz. |
| `BTN_RST` | Reinicio general del sistema. |
| `arriba`, `abajo`, `izquierda`, `derecha` | Navegación del cursor del Jugador 1. |
| `BTN_SEL` | Selección / rotación de barco. |
| `BTN_OK` | Confirmación de colocación o disparo. |
| `UART_RX` | Recepción serial desde la PC del Jugador 2. |

**Salidas:**

| Señal | Descripción |
|---|---|
| `VGA_HS`, `VGA_VS`, RGB | Sincronismos y color para el monitor VGA. |
| `UART_TX` | Transmisión serial hacia la PC del Jugador 2. |
| `DISP_SEG`, `DISP_AN` | Multiplexación de los displays de 7 segmentos. |
| `LEDs` | Indicadores de fase del juego. |
| `Buzzer` | Retroalimentación sonora. |

El sistema recibe las interacciones físicas locales y remotas, procesa las acciones del juego de manera autónoma mediante el código ensamblador, y actualiza en tiempo real las pantallas y los indicadores de estado. En este nivel no se especifica cómo se realizan internamente estas funciones.

![Diagrama de primer nivel del sistema]fig/diagrama_primer_nivel.png

---

## 5. Diagrama de segundo nivel

El segundo nivel divide el sistema completo en sus bloques funcionales principales: núcleo RISC-V, ROM, RAM, decodificación MMIO, UART, VGA, entradas del Jugador 1, displays/LED/buzzer, y la aplicación de PC como bloque externo conectado por UART.

![Diagrama de segundo nivel del sistema]fig/diagrama_segundo_nivel.png

---

## 6. Diagramas de tercer nivel

El tercer nivel presenta los bloques funcionales internos de la solución, organizado en cuatro diagramas principales.

### 6.1 Procesador RISC-V

El diagrama de tercer nivel muestra el datapath de ciclo único del
microprocesador RV32I: el datapath principal (instrucción, registros,
ALU y memoria de datos) y la lógica de siguiente PC (branches y saltos).

#### Señales de entrada

| Señal            | Ancho  | Origen                     | Descripción                                   |
|-------------------|--------|----------------------------|------------------------------------------------|
| `clk_i`            | 1 bit  | Externo                    | Reloj del sistema.                              |
| `rst_i`            | 1 bit  | Externo                    | Reinicio del procesador.                        |
| `ProgIn_i[31:0]`   | 32 bits| ROM                        | Instrucción leída de la memoria de programa.    |
| `DataIn_i[31:0]`   | 32 bits| RAM / periféricos          | Dato leído de la memoria de datos (para `lw`).  |

#### Señales de salida

| Señal               | Ancho  | Destino            | Descripción                                        |
|----------------------|--------|---------------------|------------------------------------------------------|
| `ProgAddress_o[31:0]`| 32 bits| ROM                  | Dirección de la siguiente instrucción a leer (`PC`).  |
| `DataAddress_o[31:0]`| 32 bits| RAM / periféricos    | Dirección de memoria de datos (`ALU_Result`).         |
| `DataOut_o[31:0]`    | 32 bits| RAM / periféricos    | Dato a escribir en memoria (`RD2`, para `sw`).        |
| `we_o`                | 1 bit  | RAM / periféricos    | Habilita escritura en memoria de datos (`MemWrite`).  |

#### Señales de control (generadas por la Unidad de Control)

| Señal        | Ancho    | Bloque que controla        | Descripción                                                        |
|---------------|----------|------------------------------|-----------------------------------------------------------------------|
| `RegWrite`    | 1 bit    | Banco de Registros           | Habilita escritura de `WriteData` en el registro `rd`.                |
| `ImmSrc`      | N bits   | Generador de Inmediatos      | Selecciona el formato del inmediato (I, S, B, U, J).                  |
| `ALUSrcA`     | 1 bit    | MUX A                        | Selecciona entre `RD1` y `PC` como entrada A de la ALU.               |
| `ALUSrcB`     | 1 bit    | MUX B                        | Selecciona entre `RD2` e `Imm` como entrada B de la ALU.               |
| `ALUControl`  | N bits   | ALU                          | Selecciona la operación de la ALU (suma, resta, lógicas, comparación).|
| `ResultSrc`   | N bits   | MUX Writeback                | Selecciona entre `ALU_Result`, `DataIn_i` y `PC_plus_4`.               |
| `Branch_Ctrl` | N bits   | Comparador y Lógica de Saltos| Indica el tipo de bifurcación (`beq`, `bne`, `blt`, `bge`, `jal`, `jalr`) o ausencia de ella. |

#### Explicación del datapath

**Camino del PC e instrucción.** El `Registro PC` mantiene la dirección
de la instrucción actual. La señal `PC[31:0]` se distribuye hacia tres
destinos: `ProgAddress_o`, el bloque `PC + 4` (dirección secuencial
siguiente) y el `MUX A`. La ROM responde por `ProgIn_i[31:0]`, que entra
al `Decodificador de instrucción`, el cual extrae `opcode/funct`,
`rs1/rs2/rd` y los campos inmediatos.

**Unidad de control.** A partir de `opcode/funct` genera todas las
señales de control de la tabla anterior, que gobiernan el resto del
datapath.

**Banco de registros y generador de inmediatos.** El `Banco de
Registros` lee `RD1` y `RD2` a partir de `rs1`/`rs2`, y escribe
`WriteData` en `rd` cuando `RegWrite` está activo. El `Generador de
Inmediatos` decodifica el campo inmediato según `ImmSrc` y produce
`Imm[31:0]`.

**ALU.** El `MUX A` selecciona entre `RD1` y `PC`. El `MUX B` selecciona entre
`RD2` e `Imm`. La `ALU` produce `ALU_Result` según `ALUControl`, que se
usa como `DataAddress_o`. `RD2` se envía directamente como `DataOut_o`
(para `sw`).

**Escritura de resultado (Writeback).** El `MUX Writeback` selecciona,
según `ResultSrc`, entre `ALU_Result`, `DataIn_i` y `PC_plus_4` (para
`jal`/`jalr`). El resultado (`WriteData`) regresa al Banco de Registros.

**Lógica de siguiente PC.** El `Comparador de Bifurcaciones` recibe
`RD1`, `RD2` y `Branch_Ctrl`, y produce `BranchTaken`. La `Lógica
Branch/Saltos` recibe `PC`, `Imm`, `RD1`, `BranchTaken` y `Branch_Ctrl`,
y calcula `TargetPC` junto con `PCsrc`
(`PCsrc = Jump | (Branch & BranchTaken)`). El `MUX Next PC` selecciona,
según `PCsrc`, entre `PC_plus_4` y `TargetPC`, produciendo
`NextPC[31:0]`, que regresa al `Registro PC`.

### 6.2 Memorias, interconexión MMIO y UART
Bloques mínimos: ROM de instrucciones; RAM de datos; decodificador de direcciones; señales de selección para RAM y periféricos; generación de write enable por dispositivo; multiplexor de datos de lectura; registros de control/estado, TX y RX del UART; transmisor y receptor UART; generador de baud. Debe indicar `DataAddress`, `DataOut`, `DataIn`, `write_enable`, `uart_tx`, `uart_rx`.

### 6.3 Periférico VGA y sistema de relojes
Bloques mínimos: PLL / generador del reloj de píxel; contadores horizontal y vertical; generadores de HSYNC/VSYNC; detector de región visible; cálculo de fila/columna del tile; memoria de tiles de doble puerto; generador de color; interfaz de escritura desde el procesador. Debe diferenciar el dominio de 100 MHz (procesador) del dominio de 25 MHz (VGA).

### 6.4 Periféricos locales
Bloques mínimos: sincronizadores de entradas; debouncing; detectores de flanco; registro de estado de botones; registro de datos de displays; selector de dígito; decodificador de 7 segmentos; registro del LED; registro de control del buzzer; selector de tono; divisor de frecuencia; contador de duración del sonido.

![Diagrama de tercer nivel del sistema]fig/diagrama_tercer_nivel.png

---

## 7. Diagramas de cuarto nivel

Cada módulo funcional identificado en el nivel anterior se documenta individualmente con:

1. Nombre del módulo.
2. Diagrama modular (entradas/salidas).
3. Objetivo.
4. Tabla de entradas y tabla de salidas.
5. Relación con los demás módulos.
6. Explicación de funcionamiento.
7. Diseño y justificación técnica.
8. Ecuaciones, tablas de verdad o máquinas de estado, cuando correspondan.
9. Comportamiento durante el reset.
10. Casos especiales y condiciones de borde.
11. Estrategia de validación.

**Formato de tabla de señales:**

| Señal | Ancho | Dirección | Descripción |
|---|---|---|---|
| `clk_i` | 1 bit | Entrada | Reloj principal del módulo. |
| `rst_i` | 1 bit | Entrada | Reinicio del módulo. |
| `data_i` | 32 bits | Entrada | Dato recibido desde el módulo anterior. |
| `data_o` | 32 bits | Salida | Resultado producido por el módulo. |

**Módulos a documentar** (uno por cada uno, siguiendo el formato anterior):

- **Procesador y memoria:** registro del PC, sumador PC+4, banco de registros, ALU, generador de inmediatos, unidad de control, comparador de bifurcaciones, multiplexores de operandos y de write-back, ROM, RAM, decodificador de direcciones, multiplexor de lectura.
- **VGA y periféricos locales:** PLL, contadores H/V, generadores HSYNC/VSYNC, detector de región visible, cálculo de dirección de tile, memoria de tiles, generador de color, sincronizador y debouncer de botones, detector de flanco, controlador de displays, registro del LED, generador del buzzer.
- **UART:** registro de control/estado, registro TX, registro RX, generador de baud, transmisor, receptor, lógica de detección/descarte de datos inválidos.

![Diagrama de cuarto nivel del sistema]fig/diagrama_cuarto_nivel.png

---

## 8. Mapa de memoria, registros y organización de datos

### 8.1 Mapa de memoria

| Rango de direcciones | Componente |
|---|---|
| `0x0000_0000 – 0x0000_1FFF` | ROM de programa |
| `0x0000_2000 – 0x0000_2FFF` | RAM de datos |
| `0x0001_0000 – 0x0001_FFFF` | Periféricos mapeados en memoria |
| `0x0001_1000 – 0x0001_17FF` | Memoria de video VGA |

### 8.2 Registros de periféricos

| Periférico | Registro | Dirección |
|---|---|---|
| UART | Control/Estado | `0x0001_0040` |
| UART | Datos TX | `0x0001_0044` |
| UART | Datos RX | `0x0001_0048` |
| Entradas J1 | Estado | `0x0001_0120` |
| Displays 7-seg | Datos | `0x0001_0130` |
| LED de estado | Datos | `0x0001_0138` |
| Buzzer | Control | `0x0001_0140` |

### 8.3 Organización de tableros en RAM
*(Redactar: estructura propuesta por tablero, p. ej. arreglo de 64 posiciones, campos de turno, contadores de partidas ganadas, variables temporales de la partida)*

### 8.4 Interfaz estándar de periféricos
Todos los periféricos de registro comparten la interfaz de 32 bits (`clk_i`, `rst_i`, `write_enable_i`, `addr_i[1:0]`, `wdata_i[31:0]`, `rdata_o[31:0]`). El VGA es la excepción: usa un campo de dirección más ancho por comportarse como memoria de video.

---

## 9. Protocolo UART, flujo del programa y aplicación de PC

### 9.1 Protocolo de aplicación sobre UART
*(Redactar: formato de trama; mensajes PC→FPGA —colocación de barco, disparo—; mensajes FPGA→PC —aceptación/rechazo, inicio de batalla, cambio de turno, resultado de disparo propio y recibido, resultado final—; manejo de tramas inválidas; ejemplos byte a byte)*

### 9.2 Flujo del programa ensamblador
Inicialización → colocación concurrente (J1 por VGA/botones, J2 por UART) → fase de batalla (turnos, disparos, actualización) → fin de partida → reinicio (`BTN_RST`) conservando el contador de partidas ganadas.

*(Redactar: propuesta de subrutinas y convención de registros)*

### 9.3 Aplicación de PC en Python
*(Redactar: arquitectura de la aplicación, uso de pyserial, visualización de tablero propio y estado conocido del rival, validación de entradas del usuario)*

---

## 10. Decisiones de diseño y justificación

- **Arquitectura del núcleo:** *(justificar ciclo único vs. multiciclo, tipo de unidad de control)*
- **Organización de memoria:** *(justificar bus dedicado de ROM vs. bus compartido de RAM/periféricos)*
- **Diseño VGA:** *(justificar resolución de la cuadrícula de tiles y sincronización entre dominio de 100 MHz y 25 MHz en la memoria de doble puerto)*
- **Diseño UART:** *(justificar reutilización del Proyecto 2 y ajustes necesarios)*
- **Organización de tableros:** *(justificar estructura de datos elegida)*
- **Protocolo de comunicación:** *(justificar formato de trama elegido)*

---

## 11. Estrategia de validación y plan de implementación

### 11.1 Validación por bloque

| Bloque | Prueba | Resultado esperado |
|---|---|---|
| Núcleo RISC-V | Testbench autoverificable por instrucción | Registros/memoria coinciden con el valor esperado |
| ROM / RAM | Lectura/escritura en direcciones de borde | Sin corrupción de datos |
| UART | Loopback TX→RX | Trama recibida coincide con la transmitida a 115200 baudios |
| Entradas J1 | Rebotes simulados | Antirrebote entrega un único flanco limpio |
| VGA | Inspección de temporización | `VGA_HS`/`VGA_VS` cumplen 640×480@60Hz |

### 11.2 Plan de implementación
*(Redactar: orden progresivo, p. ej. generadores de habilitación → memorias → UART → núcleo con testbench propio → VGA → entradas → integración → ensamblador del juego → aplicación Python → simulación integral → pruebas en placa)*

### 11.3 Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| | |

---

## 12. Distribución del trabajo

| Persona | Área principal |
|---|---|
| P1 | Procesador RISC-V: datapath, unidad de control, banco de registros, ALU, interfaz del procesador |
| P2 | VGA y periféricos locales: controlador VGA, memoria de tiles, sistema de relojes, botones, displays, LED, buzzer |
| P3 | Memorias, interconexión y comunicación: ROM, RAM, decodificación MMIO, UART, organización de datos, protocolo, software |
| Todos | Integración: interfaces, nombres de señales, anchos de buses, comportamiento del reset, revisión cruzada |

*(Completar tabla de revisión cruzada y cronograma si se desea documentar aquí)*

---

## 13. Referencias

*(Listar fuentes utilizadas para RISC-V, VGA, UART, debouncing, Python y demás decisiones técnicas)*

## Referencias

1. L. Llamas, *"Controlador VGA con FPGA"*, [En línea]. Disponible en: https://www.luisllamas.es/fpga-vga-hdmi-generacion-video/ [Accedido: 2026-09-24].
2. Y. Alkattan, *"640x480 VGA framebuffer en FPGA"*, Repositorio de GitHub. Disponible en: https://github.com/Yousef-Alkattan/640x480-VGAframebuffer
3. Enciclopedia Académica, *"Señal de sincronismo VGA"*, [En línea]. Disponible en: https://es-academic.com/dic.nsf/eswiki/495866
