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

![Diagrama de primer nivel del sistema](fig/diagrama_primer_nivel.png)

---

## 5. Diagrama de segundo nivel

El segundo nivel divide el sistema completo en sus bloques funcionales principales: núcleo RISC-V, ROM, RAM, decodificación MMIO, UART, VGA, entradas del Jugador 1, displays/LED/buzzer, y la aplicación de PC como bloque externo conectado por UART.

![Diagrama de segundo nivel del sistema](fig/diagrama_segundo_nivel.jpg)

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

El subsistema de memorias, interconexión MMIO y comunicación UART
permite conectar el procesador RISC-V con la memoria de programa, la
memoria de datos y los diferentes periféricos del sistema. La
arquitectura utiliza una interfaz independiente para la memoria de
instrucciones y una interfaz compartida para el acceso a la RAM y a los
periféricos mapeados en memoria.

El procesador proporciona las señales `ProgAddress_o[31:0]` para el
acceso a la memoria de programa y `DataAddress_o[31:0]`,
`DataOut_o[31:0]` y `we_o` para las operaciones sobre memoria de datos
y periféricos. Los datos obtenidos durante una operación de lectura
regresan al procesador mediante `DataIn_i[31:0]`.

#### Memoria ROM

La memoria ROM almacena las instrucciones que ejecuta el procesador y
utiliza una interfaz independiente del bus de datos. El procesador
coloca la dirección de la instrucción requerida en
`ProgAddress_o[31:0]` y la ROM retorna la instrucción correspondiente
mediante `ProgIn_i[31:0]`.

Debido a que la ROM pertenece al espacio de programa y dispone de su
propia interfaz con el procesador, no participa en el multiplexor de
lectura utilizado por la RAM y los periféricos MMIO. Cuando sea
necesario, la dirección generada por el procesador se adapta a la
organización interna de la memoria antes de realizar el acceso.

#### Bus de datos e interconexión MMIO

La RAM y los periféricos comparten la interfaz de datos del procesador.
La dirección del acceso se presenta mediante `DataAddress_o[31:0]`,
mientras que `DataOut_o[31:0]` constituye el bus común utilizado para
transferir hacia los dispositivos el dato que debe escribirse.

La señal `we_o` indica que el procesador está realizando una operación
de escritura. Sin embargo, esta señal no se conecta directamente como
habilitación de escritura de todos los dispositivos. Primero se combina
con la señal de selección correspondiente al dispositivo direccionado,
de manera que únicamente el bloque seleccionado pueda modificar su
contenido.

#### Decodificación de direcciones

El decodificador de direcciones recibe `DataAddress_o[31:0]` y determina
qué región del mapa de memoria está siendo accedida. Como resultado,
genera señales de selección independientes para la RAM y para cada uno
de los periféricos mapeados en memoria.

Las principales señales de selección consideradas en la interconexión
son:

- `sel_RAM`
- `sel_UART`
- `sel_INPUT`
- `sel_DISPLAY`
- `sel_LED`
- `sel_BUZZER`
- `sel_VGA`

Estas señales permiten que una misma interfaz de dirección y datos sea
compartida por los diferentes dispositivos sin que más de un bloque
responda simultáneamente al mismo acceso.

#### Generación de habilitaciones de escritura

Para cada dispositivo se genera una habilitación de escritura a partir
de la señal global `we_o` y de la señal de selección obtenida mediante
la decodificación de direcciones. De forma general, la habilitación de
escritura de un dispositivo se expresa como

\[
we_x = we_o \land sel_x
\]

donde `sel_x` representa la señal de selección del dispositivo
correspondiente.

Por ejemplo, para la memoria RAM y el periférico UART se tiene

\[
we_{RAM} = we_o \land sel_{RAM}
\]

\[
we_{UART} = we_o \land sel_{UART}
\]

Con este esquema, aunque `DataOut_o[31:0]` se distribuya hacia varios
bloques, solamente el dispositivo seleccionado puede almacenar el dato
durante una operación de escritura.

#### Memoria RAM

La memoria RAM se utiliza para almacenar los datos requeridos durante la
ejecución del programa. El bloque recibe el dato de escritura desde
`DataOut_o[31:0]`, una dirección interna derivada de
`DataAddress_o[31:0]` y la habilitación `we_RAM`.

Debido a que la RAM ocupa solamente una región del espacio total de
direcciones, se utiliza una adaptación de dirección para convertir la
dirección global generada por el procesador en una dirección válida
dentro de la memoria. Para una memoria organizada en palabras de
32 bits, esta adaptación puede representarse conceptualmente como

\[
RAM\_addr =
\frac{DataAddress_o - BASE_{RAM}}{4}
\]

donde `BASE_RAM` corresponde a la dirección inicial de la región
reservada para la RAM.

Durante una operación de lectura, la RAM produce `ram_rdata[31:0]`, que
se conecta como una de las entradas del multiplexor general de lectura.

#### Adaptación de direcciones de los periféricos

Los periféricos no requieren utilizar directamente los 32 bits de
`DataAddress_o`. Una vez identificada la región correspondiente mediante
el decodificador, la dirección puede reducirse o adaptarse al formato
requerido por cada dispositivo.

En los periféricos basados en registros, esta dirección interna permite
seleccionar el registro particular que será leído o escrito. En el caso
del UART, la dirección interna permite seleccionar entre sus registros
de control/estado, transmisión y recepción. El periférico VGA utiliza
una dirección interna de mayor tamaño debido a la cantidad de posiciones
que componen su memoria de video.

#### Multiplexor de lectura

Cada dispositivo que permite operaciones de lectura genera su propia
salida de datos. Entre estas señales se encuentran `ram_rdata`,
`uart_rdata` y las salidas de lectura correspondientes a los demás
periféricos.

El multiplexor general de lectura utiliza las señales de selección
generadas por el decodificador para determinar cuál de estos datos debe
regresar al procesador. Su salida se conecta a `DataIn_i[31:0]`.

De esta manera, durante una lectura se establece el siguiente recorrido
general:

`DataAddress_o` → decodificador → selección del dispositivo →
dato de lectura → multiplexor → `DataIn_i`.

Este mecanismo permite utilizar un único bus de retorno de 32 bits para
la RAM y los diferentes periféricos MMIO.

#### Integración del periférico UART

El UART constituye uno de los periféricos conectados a la interconexión
MMIO. Desde el punto de vista del procesador, se accede a sus registros
mediante las mismas señales utilizadas para los demás dispositivos:
`DataAddress_o[31:0]`, `DataOut_o[31:0]`, `DataIn_i[31:0]` y la
habilitación de escritura correspondiente.

Internamente, el periférico se divide en un registro de control y estado,
un registro de transmisión, un registro de recepción, un transmisor
UART, un receptor UART y un generador de baud. La selección interna de
los registros permite determinar qué información debe escribirse o
retornarse durante cada acceso realizado por el procesador.

El registro de transmisión almacena la información que posteriormente
será serializada por el transmisor UART. En sentido contrario, el
receptor UART reconstruye la información recibida serialmente y permite
almacenarla en el registro de recepción. El registro de control y estado
proporciona la información necesaria para coordinar las operaciones de
transmisión y recepción.

El generador de baud obtiene, a partir del reloj principal del sistema,
la referencia temporal utilizada por los bloques de transmisión y
recepción. Finalmente, las señales físicas `uart_tx` y `uart_rx`
permiten establecer la comunicación serial entre el sistema implementado
en la FPGA y la aplicación ejecutada en la computadora.

El funcionamiento interno de los registros, el generador de baud, el
transmisor, el receptor y las máquinas de estado asociadas se desarrolla
con mayor detalle en los diagramas de cuarto nivel.

### 6.3 Periférico VGA y sistema de relojes
Bloques mínimos: PLL / generador del reloj de píxel; contadores horizontal y vertical; generadores de HSYNC/VSYNC; detector de región visible; cálculo de fila/columna del tile; memoria de tiles de doble puerto; generador de color; interfaz de escritura desde el procesador. Debe diferenciar el dominio de 100 MHz (procesador) del dominio de 25 MHz (VGA).

### 6.4 Periféricos locales
Bloques mínimos: sincronizadores de entradas; debouncing; detectores de flanco; registro de estado de botones; registro de datos de displays; selector de dígito; decodificador de 7 segmentos; registro del LED; registro de control del buzzer; selector de tono; divisor de frecuencia; contador de duración del sonido.

![Diagrama de tercer nivel del sistema1](fig/diagrama_tercer_nivel1.jpeg)

![Diagrama de tercer nivel del sistema2](fig/diagrama_tercer_nivel2.jpeg)

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

### 7.1 Registros de transmisión y recepción del UART

Los registros de transmisión y recepción constituyen la interfaz de
almacenamiento entre el procesador y los bloques encargados de realizar
la comunicación serial. El registro TX almacena temporalmente el dato
que debe ser enviado por el transmisor UART, mientras que el registro RX
mantiene el último dato recibido correctamente para que posteriormente
pueda ser leído por el procesador.

Ambos registros forman parte del periférico UART mapeado en memoria. El
registro TX se encuentra asociado a la dirección `0x0001_0044`, mientras
que el registro RX corresponde a la dirección `0x0001_0048`.

#### Registro de transmisión (TX)

El objetivo del registro TX es almacenar el dato escrito por el
procesador antes de iniciar su transmisión serial. El dato proviene del
bus `wdata_i[31:0]` y solamente debe almacenarse cuando se realiza una
operación de escritura dirigida al registro de transmisión.

La selección del registro se realiza mediante `addr_i[1:0]`. Dentro de
la interfaz del UART se utiliza `addr_i = 01` para identificar el
registro TX. Por lo tanto, la condición de carga puede expresarse como:

$$
load_{TX} = write\_enable_i \land (addr_i = 01)
$$

Cuando `load_TX` está activo, el registro captura el dato presente en
`wdata_i[31:0]`. El valor almacenado queda disponible para el bloque
transmisor UART, encargado posteriormente de realizar la conversión del
dato paralelo a la secuencia serial correspondiente.

##### Entradas del registro TX

| Señal | Ancho | Dirección | Descripción |
|---|---:|---|---|
| `clk_i` | 1 bit | Entrada | Reloj principal del sistema. |
| `rst_i` | 1 bit | Entrada | Reinicio del registro. |
| `write_enable_i` | 1 bit | Entrada | Indica una operación de escritura sobre el periférico UART. |
| `addr_i[1:0]` | 2 bits | Entrada | Selecciona el registro interno del UART. |
| `wdata_i[31:0]` | 32 bits | Entrada | Dato proveniente del procesador que será almacenado para su transmisión. |

##### Salidas del registro TX

| Señal | Ancho | Dirección | Descripción |
|---|---:|---|---|
| `tx_data` | Según implementación del UART | Salida | Dato almacenado que se entrega al transmisor UART. |

#### Registro de recepción (RX)

El registro RX realiza la función complementaria al registro TX. Su
objetivo es almacenar el dato reconstruido por el receptor UART después
de completar correctamente una recepción.

A diferencia del registro TX, el registro RX no es cargado directamente
por una escritura del procesador. El dato proviene del receptor UART
mediante `rx_data` y su almacenamiento se habilita mediante `rx_load`.
Esta señal indica que la recepción ha terminado y que el dato recibido
ha sido considerado válido.

De forma conceptual, la operación de carga del registro puede
representarse como:

$$
RX \leftarrow rx\_data
\qquad \text{si} \qquad
rx\_load = 1
$$

Una vez almacenado, el dato permanece disponible para que el procesador
pueda consultarlo mediante una operación de lectura. Dentro del
periférico UART se utiliza `addr_i = 10` para seleccionar el registro de
recepción.

##### Entradas del registro RX

| Señal | Ancho | Dirección | Descripción |
|---|---:|---|---|
| `clk_i` | 1 bit | Entrada | Reloj principal del sistema. |
| `rst_i` | 1 bit | Entrada | Reinicio del registro. |
| `rx_data` | Según implementación del UART | Entrada | Dato reconstruido por el receptor UART. |
| `rx_load` | 1 bit | Entrada | Habilita el almacenamiento de un nuevo dato recibido correctamente. |

##### Salidas del registro RX

| Señal | Ancho | Dirección | Descripción |
|---|---:|---|---|
| `rx_data_reg` | Según implementación del UART | Salida | Dato recibido y almacenado, disponible para su lectura. |

![Diagrama de cuarto nivel de los registros TX y RX del UART.](fig/registros_uart.png)

#### Relación con los demás módulos

Los registros TX y RX funcionan como elementos de enlace entre la
interfaz MMIO del procesador y los bloques internos de comunicación del
UART.

Durante una transmisión, el flujo de información es:

**Procesador → `wdata_i` → Registro TX → UART TX → `uart_tx`**

El procesador escribe el dato en el registro TX y posteriormente el
transmisor UART se encarga de convertirlo en una secuencia serial que
sale físicamente mediante `uart_tx`.

Durante una recepción, el flujo ocurre en sentido contrario:

**`uart_rx` → UART RX → Registro RX → interfaz de lectura → Procesador**

El receptor UART reconstruye el dato recibido serialmente. Cuando la
recepción finaliza correctamente, `rx_load` permite almacenar el dato en
el registro RX para que pueda ser leído posteriormente por el
procesador.

De esta manera, el procesador no necesita manipular directamente la
temporización de la comunicación serial, sino que interactúa con el
UART mediante operaciones convencionales de lectura y escritura sobre
registros mapeados en memoria.

#### Funcionamiento

El registro TX se actualiza únicamente cuando se realiza una operación
de escritura sobre su dirección interna. Su comportamiento puede
representarse como:

$$
TX_{next} =
\begin{cases}
wdata_i, & \text{si } load_{TX}=1 \\
TX, & \text{si } load_{TX}=0
\end{cases}
$$

Por su parte, el registro RX se actualiza únicamente cuando la lógica de
recepción indica que existe un nuevo dato válido:

$$
RX_{next} =
\begin{cases}
rx\_data, & \text{si } rx\_load=1 \\
RX, & \text{si } rx\_load=0
\end{cases}
$$

Esto permite que ambos registros mantengan su contenido mientras no se
presente una nueva operación válida de carga.

#### Diseño y justificación técnica

La utilización de registros independientes para transmisión y recepción
permite desacoplar el funcionamiento del procesador de la temporización
propia de la comunicación UART. El procesador trabaja con transferencias
paralelas mediante la interfaz MMIO, mientras que los bloques UART TX y
UART RX se encargan de realizar las conversiones entre representación
paralela y serial.

La separación entre TX y RX también permite que cada camino de
comunicación mantenga su propio dato sin que una operación de recepción
modifique la información almacenada para transmisión, o viceversa.

La selección mediante `addr_i[1:0]` permite además utilizar una única
interfaz MMIO para acceder a los diferentes registros internos del
periférico UART.

#### Comportamiento durante el reset

Cuando `rst_i` se encuentra activo, los registros TX y RX regresan a un
estado inicial conocido. Conceptualmente, su comportamiento durante el
reinicio puede expresarse como:

$$
rst_i = 1
\quad \Rightarrow \quad
TX = 0,\qquad RX = 0
$$

Esto evita que después de un reinicio el sistema interprete información
residual almacenada previamente como un dato válido de transmisión o
recepción.

#### Casos especiales y condiciones de borde

Una escritura dirigida a otro registro interno del UART no debe
modificar el contenido del registro TX. Por lo tanto, aunque
`write_enable_i` esté activo, el registro conserva su contenido si
`addr_i` no corresponde al registro de transmisión.

De igual forma, el registro RX solamente debe actualizarse cuando
`rx_load` indique la existencia de un nuevo dato válido. Si se detecta
una recepción inválida, el dato no debe cargarse en el registro RX y el
último valor válido almacenado debe conservarse.

Estas condiciones pueden resumirse mediante:

$$
load_{TX}=0
\quad \Rightarrow \quad
TX_{next}=TX
$$

$$
rx\_load=0
\quad \Rightarrow \quad
RX_{next}=RX
$$

La generación de `rx_load` y el tratamiento de una recepción inválida
se desarrollan posteriormente en la lógica de detección y recuperación
del receptor UART.

#### Estrategia de validación

La validación del registro TX se realizará mediante simulación,
aplicando diferentes valores sobre `wdata_i[31:0]` y verificando que el
registro solamente se actualice cuando `write_enable_i = 1` y
`addr_i = 01`. También se comprobará que las escrituras dirigidas a
otros registros internos del UART no modifiquen su contenido.

Para el registro RX se aplicarán diferentes valores de `rx_data` y se
verificará que solamente sean almacenados cuando `rx_load = 1`. Cuando
`rx_load = 0`, el registro deberá conservar el último dato almacenado.
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
