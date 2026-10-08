# Informe técnico: Batalla Naval — juego de dos jugadores sobre un microprocesador RISC-V con periférico VGA

<!--
PLANTILLA — Proyecto 3, EL3313 Taller de Diseño Digital

Convención de esta plantilla:
  - Cada sección trae su título y un comentario "Sugerencia" con lo que conviene
    incluir. Reemplazar el comentario por el contenido y borrar el comentario.
  - Solo la Introducción (1.1) y los Objetivos (2) vienen redactados, porque
    salen directamente del enunciado.

Categorías de la rúbrica "Documentación técnica (informe)":
  - Fundamentación teórica ........................ 20%
  - Presentación de resultados ..................... 30%
  - Análisis e interpretación de resultados ........ 25%
  - Conclusiones y aprendizaje obtenido ............ 15%
  - Calidad y organización del documento ........... 10%

Reglas de formato:
  - Jerarquía de encabezados consistente: ## secciones, ### subsecciones,
    #### sub-subsecciones (p. ej. "Entradas y salidas", "Funcionamiento",
    "Relación con el sistema" dentro de cada módulo). Nunca usar "##" para estos.
  - Cada figura, tabla o forma de onda lleva numeración y una leyenda que explica
    qué muestra y qué se debe observar en ella.
  - La sección de resultados (12) solo presenta datos y evidencia; la
    interpretación crítica va en la sección 13.
  - Los nombres de módulos deben coincidir exactamente con los del código final.
  - Borrar todos los comentarios antes de la entrega.

Lista de verificación antes de entregar (lecciones de informes anteriores):
  [ ] Existe una sección explícita de presentación de resultados (sección 12).
  [ ] Se incluye el uso de recursos (LUT, FF, BRAM, DSP, IO) copiado del reporte de Vivado.
  [ ] Se incluye el análisis de timing (WNS, TNS, hold slack) copiado del reporte.
  [ ] Se incluye al menos una fotografía del sistema físico en la FPGA.
  [ ] Se sigue la estructura sugerida y los niveles de encabezado son consistentes.
-->

## Resumen

<!-- Sugerencia: escribirlo al final. Uno o dos párrafos que cubran qué se construyó
(procesador, memorias, periféricos, programa en ensamblador, aplicación de PC),
cómo se reparte el trabajo entre hardware, software y PC, qué se logró demostrar
(simulación, síntesis, timing, partida completa en la tarjeta) y qué limitaciones
quedaron. Citar solo cifras que aparezcan en la sección 12. -->

---

## 1. Introducción

### 1.1 Contexto

Este tercer proyecto del curso integra, por primera vez, el diseño de un microprocesador propio basado en la arquitectura RISC-V con el desarrollo de periféricos mapeados en memoria y la generación de video mediante VGA. A diferencia de los Proyectos 1 y 2, donde el control de la aplicación se describía mediante lógica combinacional, secuencial y máquinas de estado dedicadas en SystemVerilog, en este proyecto el comportamiento de la aplicación se describe como un **programa en lenguaje ensamblador** que se ejecuta sobre un procesador diseñado por el equipo. El hardware desarrollado deja entonces de ser la aplicación en sí misma y pasa a ser la plataforma computacional —núcleo, memorias y periféricos— sobre la cual dicha aplicación corre.

La aplicación es una versión simplificada del clásico juego de Batalla Naval (*Battleship*) para dos jugadores. El **Jugador 1** interactúa físicamente con la tarjeta de FPGA: observa su tablero y el del oponente en un monitor VGA, y coloca barcos y dispara mediante los botones locales. El **Jugador 2** interactúa de forma remota mediante una aplicación de PC, desarrollada por el equipo, que se comunica con la FPGA por UART: despliega en la PC el tablero propio y el estado conocido del tablero rival, y transmite hacia la FPGA las coordenadas de colocación de barcos y de disparo. Todo el control de la partida —colocación, turnos, validación de disparos, detección de barcos hundidos y condición de victoria— se ejecuta exclusivamente en el microprocesador RISC-V dentro de la FPGA; la aplicación de PC es una terminal de entrada/salida remota, de forma análoga al rol que cumplía la PC en el Proyecto 2.

Cada jugador cuenta con un tablero propio de 8×8 casillas y coloca una flota de tres barcos, de tamaños 4, 3 y 2 casillas, en orientación horizontal o vertical, sin traslapes y sin salir del tablero. Una casilla puede encontrarse en uno de cuatro estados visibles: agua, barco propio (visible únicamente a su dueño), impacto o fallo. Un barco se considera hundido cuando todas sus casillas han sido impactadas, y la partida se gana cuando un jugador hunde toda la flota contraria. Como cada jugador dispone de su propia pantalla (VGA para el Jugador 1, aplicación de PC para el Jugador 2), ninguno puede observar la disposición de barcos del otro antes de descubrirla mediante disparos.

### 1.2 Solución desarrollada

<!-- Sugerencia: resumen de alto nivel de la arquitectura implementada, con el nombre
real del módulo top-level. Listar en viñetas los bloques principales (núcleo,
ROM/RAM, interconexión MMIO, VGA, entradas, UART, displays/LED/buzzer, relojes,
programa en ensamblador, aplicación de PC), una línea por bloque, y explicar qué
reside en hardware y qué en software. -->

### 1.3 Alcance y limitaciones

<!-- Sugerencia: redactar en prosa al final del proyecto. Indicar el alcance real
logrado, las decisiones que se apartaron del planteamiento (documentadas como
decisiones, no como errores) y las limitaciones conocidas. -->

---

## 2. Objetivos

### 2.1 Objetivo general

Diseñar e implementar, sobre una FPGA, un microprocesador RISC-V de 32 bits (subconjunto rv32i) capaz de ejecutar un programa en ensamblador que controle por completo un juego de Batalla Naval de dos jugadores, coordinando un jugador local mediante VGA y botones y un jugador remoto conectado por UART mediante una aplicación de PC.

### 2.2 Objetivos específicos

1. Diseñar e implementar un microprocesador rv32i, sintetizable, con memorias de programa y de datos accedidas mediante buses independientes.
2. Diseñar el mapa de memoria del sistema y la interconexión de periféricos mapeados en memoria que integra la RAM y los periféricos.
3. Diseñar un periférico de video VGA de 640×480 a 60 Hz basado en un mapa de tiles, con reloj de píxel de 25 MHz generado mediante PLL, que permita actualizar una casilla con una única escritura del CPU.
4. Diseñar un periférico de entradas del Jugador 1 con antirrebote, y los periféricos de salida locales (displays de 7 segmentos, LED de estado y buzzer).
5. Reutilizar el periférico UART del Proyecto 2 como único canal del Jugador 2 y definir el protocolo de aplicación sobre UART entre la aplicación de PC y el microprocesador.
6. Implementar en ensamblador RISC-V la lógica completa del juego: colocación de barcos de ambos jugadores, alternancia de turnos, validación de disparos, detección de barcos hundidos y determinación de la partida.
7. Implementar la aplicación de PC del Jugador 2 como terminal de entrada/salida remota, sin lógica de juego propia.
8. Garantizar que ningún jugador pueda observar la disposición de barcos del otro antes de descubrirla mediante disparos.
9. Verificar el sistema mediante testbenches autoverificables y simulación post-implementación temporizada, y validar su funcionamiento en la FPGA.
10. Aplicar una metodología de diseño modular y validación por etapas, separando el núcleo, las memorias y cada periférico como bloques independientes y verificables, y analizar cómo las decisiones de arquitectura condicionan el programa que se ejecuta sobre ellos.

---

## 3. Especificaciones

### 3.1 Requisitos funcionales

<!-- Sugerencia: tabla con tres columnas (Requisito | Valor especificado | Implementación
final). Incluir tablero, flota, orientación, estados de casilla, condición de victoria,
colocación concurrente, disparo repetido, procesador, memorias, relojes, video,
entradas, UART, displays, LED, buzzer y comportamiento de BTN_RST. Completar la
tercera columna con los valores reales del diseño final. -->

### 3.2 Mapa de memoria

<!-- Sugerencia: tabla con las regiones (ROM, RAM, periféricos, memoria de video), su
rango de direcciones y contenido, más una figura del mapa con leyenda. -->

### 3.3 Direcciones de periféricos

<!-- Sugerencia: tabla (Periférico | Registro | Offset | Dirección). Verificar que
coincide con las constantes del ensamblador y con el decodificador de direcciones. -->

### 3.4 Conjunto de instrucciones soportado

<!-- Sugerencia: tabla de las instrucciones realmente implementadas, agrupadas por
formato (R, I, S, B, J), con opcode/funct. Indicar cualquier instrucción adicional. -->

### 3.5 Interfaz estándar de periféricos

<!-- Sugerencia: tabla de señales (nombre, ancho, dirección, descripción) de la interfaz
común. Indicar cómo se decodifican los periféricos de una palabra y de varios
registros, la excepción del VGA, y si el reset es síncrono o asíncrono. -->

### 3.6 Memoria de video del periférico VGA

<!-- Sugerencia: fórmula de dirección de cada casilla, formato de la palabra de tile
(tabla de bits), codificación de colores, tamaño de la cuadrícula elegida con su
justificación, comportamiento fuera de rango y quién limpia la pantalla. -->

### 3.7 Registro de entradas del Jugador 1

<!-- Sugerencia: tabla con el mapeo exacto de bits del registro de estado (navegación,
selección, confirmación y reinicio) y qué representa cada bit (nivel o pulso). -->

### 3.8 Registros del periférico UART

<!-- Sugerencia: tabla de registros con dirección, bits y descripción (control/estado,
datos TX, datos RX). Indicar cualquier cambio respecto al Proyecto 2. -->

### 3.9 Protocolo de aplicación sobre UART

<!-- Sugerencia: describir la trama física (baudios, formato) y el formato de las tramas
de aplicación (delimitadores, separadores, terminador). Incluir tablas de mensajes
PC → FPGA y FPGA → PC con sus campos y códigos, el manejo de datos inválidos y un
ejemplo de intercambio. Cubrir todos los eventos que exige el enunciado. -->

#### Trama física UART

#### Mensajes PC → FPGA

#### Mensajes FPGA → PC

#### Manejo de datos inválidos

#### Ejemplo de intercambio

### 3.10 Organización de datos en RAM

<!-- Sugerencia: tabla con cada región o variable (tableros, información de barcos, fase,
turno, contadores, variables auxiliares), su dirección base, tamaño y codificación de
cada casilla. -->

### 3.11 Requisitos eléctricos

<!-- Sugerencia: estándar lógico de la tarjeta, conexión de VGA, UART-USB, buzzer y
botones. Indicar el modelo exacto de la tarjeta usada. -->

---

## 4. Fundamentación teórica

<!-- Sugerencia general: peso 20% de la rúbrica. Cada subsección debe terminar conectando
el concepto con lo implementado en el proyecto; no basta con teoría abstracta. -->

### 4.1 Arquitectura RISC-V y el subconjunto rv32i

<!-- Sugerencia: formatos de instrucción, codificación, banco de registros y qué
subconjunto se implementó. -->

### 4.2 Datapath de ciclo único y unidad de control

<!-- Sugerencia: organización del ciclo único, señales de control, generación de
inmediatos y relación entre el camino crítico y la frecuencia de operación. -->

### 4.3 Memorias y buses independientes de programa y datos

<!-- Sugerencia: por qué buses separados para instrucciones y datos y su efecto en el
ciclo de instrucción. -->

### 4.4 Entrada/salida mapeada en memoria

<!-- Sugerencia: concepto, decodificación de direcciones y registros de control, estado
y datos. -->

### 4.5 Generación de video VGA

<!-- Sugerencia: sincronismos horizontal y vertical, resolución, tabla de temporización
(zona visible, front porch, pulso, back porch, total), reloj de píxel y cálculo de la
frecuencia de refresco. -->

### 4.6 Gráficos orientados a tiles frente a framebuffer

<!-- Sugerencia: por qué un framebuffer completo no es práctico aquí y cómo el mapa de
tiles reduce memoria y trabajo del CPU. Comparar tamaños de memoria. -->

### 4.7 Memorias de doble puerto y cruce de dominios de reloj

<!-- Sugerencia: memoria con puertos en relojes distintos, tratamiento de la
sincronización entre dominios y generación del reloj de píxel con PLL. -->

### 4.8 Metaestabilidad y sincronización de entradas asíncronas

<!-- Sugerencia: sincronizador de dos etapas aplicado a botones y a la recepción UART. -->

### 4.9 Antirrebote de pulsadores

<!-- Sugerencia: rebote mecánico, filtro temporizado, detección de flanco y su
aplicación al periférico de entradas. -->

### 4.10 Protocolo UART asíncrono

<!-- Sugerencia: trama, baud rate, ciclos de reloj por bit y muestreo del receptor. -->

### 4.11 Programación en ensamblador RISC-V

<!-- Sugerencia: convención de llamado, uso de registros y de la pila, pseudoinstrucciones
y proceso para cargar el programa en la ROM. -->

### 4.12 Reglas del juego de Batalla Naval

<!-- Sugerencia: colocación, disparo, impacto, fallo y hundido, condición de victoria y
por qué la información oculta debe permanecer dentro del procesador. -->

---

## 5. Metodología

### 5.1 Diseño modular

<!-- Sugerencia: referencia al planteamiento del diseño, niveles de abstracción y
separación entre núcleo, memorias y periféricos. -->

### 5.2 Flujo de desarrollo y validación por etapas

<!-- Sugerencia: orden real seguido, desde los bloques del núcleo hasta la integración,
el programa del juego, la aplicación de PC y las pruebas en la tarjeta. -->

### 5.3 Herramientas

<!-- Sugerencia: lista con versiones reales (síntesis e implementación, simulación,
HDL, ensamblador, aplicación de PC, tarjeta de desarrollo). -->

---

## 6. Arquitectura general

### 6.1 Jerarquía de módulos

<!-- Sugerencia: árbol de módulos tomado del código fuente final, en un bloque de código,
y nota sobre cualquier diferencia respecto al planteamiento. -->

### 6.2 Diagramas de bloques

<!-- Sugerencia: figura del sistema completo (primer y segundo nivel) con leyenda. Los
diagramas más detallados se colocan al inicio de las secciones 7 y 8. -->

### 6.3 Flujo de la partida

<!-- Sugerencia: descripción numerada o diagrama de flujo: inicialización, colocación
concurrente, batalla, fin de partida y reinicio. -->

---

## 7. Procesador RISC-V

El procesador está implementado en SystemVerilog y utiliza una arquitectura uniciclo de 32 bits. El diseño separa el núcleo, las memorias y la interconexión con periféricos, permitiendo verificar cada componente de forma independiente.

### 7.1 Núcleo

El módulo `riscv_core.sv` conecta el datapath y la unidad de control. Ejecuta un subconjunto de 29 instrucciones RV32I y proporciona buses independientes para instrucciones y datos.

#### Entradas y salidas

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `clk_i` | Entrada | 1 bit | Reloj del procesador |
| `rst_i` | Entrada | 1 bit | Reset síncrono activo alto |
| `ProgIn_i` | Entrada | 32 bits | Instrucción entregada por la ROM |
| `DataIn_i` | Entrada | 32 bits | Dato leído desde RAM o periféricos |
| `ProgAddress_o` | Salida | 32 bits | Dirección de la instrucción actual |
| `DataAddress_o` | Salida | 32 bits | Dirección de datos calculada por la ALU |
| `DataOut_o` | Salida | 32 bits | Dato del segundo registro fuente para escritura |
| `we_o` | Salida | 1 bit | Habilitación de escritura de datos, bloqueada durante reset |

Las direcciones se expresan en bytes.

#### Diagrama del datapath

El siguiente esquema representa las conexiones funcionales principales. La ROM y la RAM/periféricos se encuentran fuera de `riscv_core`.

```text
                    +-------------------+
             +----->| Registro PC       |-----> ROM externa
             |      +-------------------+          |
             |               |                     | Instrucción
             |               v                     v
             |             PC + 4          Decodificación y control
             |               |                  |          |
             |               |                  v          v
             |               |          Banco de       Generador de
             |               |          registros      inmediatos
             |               |           |     |            |
             |               |          RD1   RD2           Imm
             |               |           |     |            |
             |               |           +-- MUX A/B -------+
             |               |                  |
             |               |                  v
             |               |                 ALU
             |               |                  |
             |               |             ALUResult
             |               |                  |
             |               |        RAM / MMIO externos
             |               |                  |
             |               |               DataIn
             |               |                  |
             |               +----> MUX de escritura <---- ALUResult
             |                              |
             |                              v
             |                       Banco de registros
             |
             +---- MUX siguiente PC <---- PC + 4
                            ^
                            |
                    Destino de salto
                            ^
                            |
                 PC / RD1 / Imm / comparación
```

El dato de escritura hacia RAM o MMIO proviene directamente de `RD2`. La lógica de saltos calcula su destino mediante un sumador independiente de la ALU.

#### Funcionamiento

Durante cada ciclo:

1. El PC presenta la dirección de la instrucción.
2. La ROM entrega la instrucción de forma combinacional.
3. El decodificador extrae los campos y la unidad de control genera las señales.
4. El banco de registros entrega los operandos y se construye el inmediato.
5. La ALU calcula el resultado o la dirección de datos.
6. Se seleccionan el dato de escritura y el siguiente PC.
7. En el flanco ascendente se actualizan los elementos habilitados.

Estas operaciones pertenecen a un mismo ciclo; no corresponden a etapas de un pipeline.

El reset devuelve el PC a cero y borra los registros modificables. Las escrituras externas se bloquean mientras `rst_i` está activo.

#### Relación con el sistema

El núcleo ejecuta el programa ensamblador que controla el juego. Obtiene instrucciones desde ROM y utiliza el bus de datos para acceder a RAM y periféricos.

El módulo `processor_subsystem.sv` integra el núcleo con ROM, RAM y selección del espacio MMIO. El núcleo también puede conectarse directamente a una interconexión externa si el top del equipo administra las memorias.

### 7.2 Unidad de control

El módulo `control_unit.sv` identifica la instrucción y genera las señales que coordinan el datapath.

#### Entradas y salidas

| Señal | Dirección | Ancho | Función |
| --- | --- | --- | --- |
| `opcode` | Entrada | 7 bits | Identifica la familia de instrucciones |
| `funct3` | Entrada | 3 bits | Especifica la operación |
| `funct7` | Entrada | 7 bits | Distingue variantes de instrucciones |
| `RegWrite` | Salida | 1 bit | Habilita escritura en el banco de registros |
| `ALUSrcA` | Salida | 1 bit | Selecciona RD1 o PC |
| `ALUSrcB` | Salida | 1 bit | Selecciona RD2 o inmediato |
| `ALUControl` | Salida | 4 bits | Selecciona la operación de la ALU |
| `ImmSrc` | Salida | 3 bits | Selecciona el formato del inmediato |
| `ResultSrc` | Salida | 2 bits | Selecciona el dato que se escribe en un registro |
| `BranchCtrl` | Salida | 2 bits | Selecciona la condición de bifurcación |
| `Branch` | Salida | 1 bit | Indica bifurcación condicional |
| `Jump` | Salida | 1 bit | Indica salto incondicional |
| `JALR` | Salida | 1 bit | Selecciona la base y el ajuste del salto indirecto |
| `MemWrite` | Salida | 1 bit | Solicita escritura en memoria o MMIO |

#### Tabla de señales de control

| Señal | Codificación |
| --- | --- |
| `ALUSrcA` | 0: RD1; 1: PC |
| `ALUSrcB` | 0: RD2; 1: inmediato |
| `ImmSrc` | 000: I; 001: S; 010: B; 011: J; 100: U |
| `ResultSrc` | 00: ALU; 01: dato leído; 10: PC+4; 11: cero |
| `BranchCtrl` | 00: BEQ; 01: BNE; 10: BLT; 11: BGE |

La siguiente tabla resume las señales principales por grupo. El símbolo `—` indica que la señal no afecta el resultado de esa instrucción; el RTL asigna valores definidos.

| Instrucción o grupo | RegWrite | ALUSrcA | ALUSrcB | ImmSrc | ResultSrc | MemWrite | Branch | Jump | JALR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Operaciones entre registros | 1 | 0 | 0 | — | 00 | 0 | 0 | 0 | 0 |
| Operaciones con inmediato | 1 | 0 | 1 | 000 | 00 | 0 | 0 | 0 | 0 |
| LW | 1 | 0 | 1 | 000 | 01 | 0 | 0 | 0 | 0 |
| SW | 0 | 0 | 1 | 001 | — | 1 | 0 | 0 | 0 |
| BEQ, BNE, BLT, BGE | 0 | — | — | 010 | — | 0 | 1 | 0 | 0 |
| JAL | 1 | — | — | 011 | 10 | 0 | 0 | 1 | 0 |
| JALR | 1 | — | — | 000 | 10 | 0 | 0 | 1 | 1 |
| LUI | 1 | 0 | 1 | 100 | 00 | 0 | 0 | 0 | 0 |
| AUIPC | 1 | 1 | 1 | 100 | 00 | 0 | 0 | 0 | 0 |

`ALUControl` depende de la operación concreta y se describe en la sección 7.4.

#### Funcionamiento

La unidad es combinacional: sus salidas dependen de los campos de la instrucción actual.

Primero establece valores por defecto que deshabilitan escrituras y cambios de flujo. Después activa las señales correspondientes a la instrucción reconocida. Para LUI selecciona el inmediato superior como resultado; para AUIPC selecciona el PC y lo suma al inmediato superior.

Las instrucciones no soportadas no escriben registros ni memoria y permiten que el PC avance secuencialmente, sin generar una excepción.

#### Relación con el sistema

La unidad de control coordina los componentes internos del procesador. No contiene reglas del juego ni lógica específica de periféricos: estas acciones dependen del programa ejecutado y de las direcciones utilizadas.

### 7.3 Banco de registros

El módulo `register_file.sv` almacena los operandos y resultados temporales del procesador.

#### Entradas y salidas

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `clk_i` | Entrada | 1 bit | Reloj |
| `rst_i` | Entrada | 1 bit | Reset síncrono activo alto |
| `RegWrite` | Entrada | 1 bit | Habilitación de escritura |
| `rs1` | Entrada | 5 bits | Índice del primer registro fuente |
| `rs2` | Entrada | 5 bits | Índice del segundo registro fuente |
| `rd` | Entrada | 5 bits | Índice del registro destino |
| `WriteData` | Entrada | 32 bits | Dato a almacenar |
| `RD1` | Salida | 32 bits | Contenido del primer registro fuente |
| `RD2` | Salida | 32 bits | Contenido del segundo registro fuente |

#### Funcionamiento

El banco presenta 32 registros arquitectónicos de 32 bits. El registro x0 es una constante y las escrituras dirigidas a él se ignoran; únicamente x1 a x31 necesitan almacenamiento.

Los dos puertos de lectura son combinacionales. La escritura se realiza en el flanco ascendente si `RegWrite=1`, `rd` es diferente de cero y el reset no está activo.

El reset tiene prioridad sobre la escritura y coloca x1 a x31 en cero.

#### Relación con el sistema

`RD1` y `RD2` alimentan las operaciones del datapath. Además, `RD2` proporciona el dato utilizado por SW y ambos operandos se emplean para evaluar bifurcaciones.

`WriteData` recibe el resultado seleccionado por el multiplexor de escritura: ALU, memoria o PC+4.

### 7.4 ALU

El módulo `alu.sv` implementa la unidad aritmético-lógica de 32 bits.

#### Entradas y salidas

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `ALUOperandA` | Entrada | 32 bits | Primer operando |
| `ALUOperandB` | Entrada | 32 bits | Segundo operando |
| `ALUControl` | Entrada | 4 bits | Operación seleccionada |
| `ALUResult` | Salida | 32 bits | Resultado |

#### Operaciones soportadas

| ALUControl | Operación | Resultado |
| --- | --- | --- |
| 0000 | ADD | A + B |
| 0001 | SUB | A − B |
| 0010 | AND | AND bit a bit |
| 0011 | OR | OR bit a bit |
| 0100 | XOR | XOR bit a bit |
| 0101 | SLL | Desplazamiento lógico a la izquierda |
| 0110 | SRL | Desplazamiento lógico a la derecha |
| 0111 | SRA | Desplazamiento aritmético a la derecha |
| 1000 | SLT | 1 si A < B con signo; 0 en otro caso |
| 1001 | SLTU | 1 si A < B sin signo; 0 en otro caso |
| 1010 | PASS_B | Entrega B para implementar LUI |

#### Funcionamiento

La ALU es combinacional y no almacena resultados. Los desplazamientos utilizan los cinco bits inferiores del segundo operando, por lo que el desplazamiento efectivo está entre 0 y 31 posiciones.

SRA conserva el signo del operando al desplazar hacia la derecha. SLT interpreta los operandos con signo, mientras que SLTU los interpreta sin signo. Los códigos de control reservados producen cero.

#### Relación con el sistema

La ALU realiza los cálculos del programa y genera las direcciones de LW y SW. También ejecuta la suma PC más inmediato superior para AUIPC.

Las condiciones de branch y los destinos de salto se calculan en bloques separados.

### 7.5 Generador de inmediatos y lógica de saltos

Estos componentes construyen las constantes de las instrucciones y determinan los cambios de flujo del programa.

#### Entradas y salidas

**Generador de inmediatos: `immediate_generator.sv`**

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `ProgIn_i` | Entrada | 32 bits | Instrucción actual |
| `ImmSrc` | Entrada | 3 bits | Formato del inmediato |
| `Imm` | Salida | 32 bits | Inmediato construido |

**Comparador: `branch_comparator.sv`**

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `RD1`, `RD2` | Entrada | 32 bits cada una | Operandos de comparación |
| `BranchCtrl` | Entrada | 2 bits | Condición que se evalúa |
| `BranchTaken` | Salida | 1 bit | Resultado de la condición |

**Lógica de saltos: `branch_jump_logic.sv`**

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `PC` | Entrada | 32 bits | Dirección actual |
| `RD1` | Entrada | 32 bits | Base para JALR |
| `Imm` | Entrada | 32 bits | Desplazamiento |
| `BranchTaken` | Entrada | 1 bit | Resultado del comparador |
| `Branch`, `Jump`, `JALR` | Entrada | 1 bit cada una | Señales de control |
| `TargetPC` | Salida | 32 bits | Destino calculado |
| `PCSrc` | Salida | 1 bit | Selección del destino frente a PC+4 |

#### Funcionamiento

El generador reconstruye los inmediatos según el formato:

| Formato | Construcción |
| --- | --- |
| I | Bits `[31:20]`, extendidos con signo |
| S | Bits `[31:25]` y `[11:7]`, extendidos con signo |
| B | Bits `[31]`, `[7]`, `[30:25]`, `[11:8]` y un cero final, extendidos con signo |
| J | Bits `[31]`, `[19:12]`, `[20]`, `[30:21]` y un cero final, extendidos con signo |
| U | Bits `[31:12]` seguidos de 12 ceros |

Los inmediatos B y J ya incluyen el bit inferior cero y no requieren un desplazamiento adicional.

El comparador evalúa igualdad, desigualdad, menor que y mayor o igual. BLT y BGE utilizan comparación con signo.

La lógica calcula:

- Branch y JAL: `TargetPC = PC + Imm`.
- JALR: `TargetPC = (RD1 + Imm) & 0xFFFFFFFE`.
- Selección: `PCSrc = Jump | (Branch & BranchTaken)`.

Si `PCSrc=0`, se utiliza PC+4. Para JALR se limpia únicamente el bit cero; no se fuerza a cero el bit uno.

#### Relación con el sistema

Estos bloques permiten ejecutar condiciones, ciclos y llamadas del programa ensamblador. JAL y JALR también seleccionan PC+4 como dirección de retorno para el registro destino.

### 7.6 Memorias ROM y RAM

Las memorias se implementan en `program_rom.sv` y `data_ram.sv`.

#### Entradas y salidas

**ROM**

| Elemento | Tipo | Ancho | Descripción |
| --- | --- | --- | --- |
| `INIT_FILE` | Parámetro | Cadena | Ruta del archivo hexadecimal |
| `addr_i` | Entrada | 32 bits | Dirección de byte de la instrucción |
| `instr_o` | Salida | 32 bits | Instrucción leída |

**RAM**

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `clk_i` | Entrada | 1 bit | Reloj de escritura |
| `we_i` | Entrada | 1 bit | Habilitación de escritura |
| `addr_i` | Entrada | 10 bits | Índice local de palabra |
| `wdata_i` | Entrada | 32 bits | Dato a escribir |
| `rdata_o` | Salida | 32 bits | Dato leído |

#### Funcionamiento

La ROM contiene 2048 palabras de 32 bits, equivalentes a 8 KiB. Se inicializa con instrucciones NOP y, cuando se especifica `INIT_FILE`, carga el archivo mediante `$readmemh`.

Su lectura es combinacional. Para direcciones alineadas menores que `0x00002000`, selecciona la palabra mediante `addr_i[12:2]`. Una dirección inválida devuelve NOP.

La RAM contiene 1024 palabras de 32 bits, equivalentes a 4 KiB. Su dirección de entrada es un índice de palabra, no una dirección global de byte. El subsistema selecciona el rango `0x00002000–0x00002FFF` y utiliza los bits `[11:2]` para obtener el índice.

La lectura de RAM es combinacional y la escritura ocurre en el flanco ascendente cuando `we_i=1`. La memoria no se borra durante reset ni tiene inicialización automática de datos.

#### Relación con el sistema

La ROM proporciona el programa que ejecuta el núcleo. La RAM almacena variables y estructuras de datos utilizadas por ese programa.

Los buses separados permiten buscar instrucciones y acceder a datos durante el mismo ciclo. El archivo `handoff.hex` incluido en la entrega contiene un diagnóstico de RAM y MMIO, no el programa completo de Batalla Naval.

### 7.7 Decodificador de direcciones y multiplexor de lectura

En la entrega local, la selección de RAM y del espacio MMIO se encuentra dentro de `processor_subsystem.sv`. La decodificación individual de cada periférico corresponde a la interconexión externa del equipo.

#### Entradas y salidas

Las señales internas utilizadas por la lógica son:

| Señal | Origen o destino | Ancho | Descripción |
| --- | --- | --- | --- |
| `address` | Desde el núcleo | 32 bits | Dirección de datos |
| `wdata` | Desde el núcleo | 32 bits | Dato de escritura |
| `core_we` | Desde el núcleo | 1 bit | Solicitud de escritura |
| `ram_data` | Desde RAM | 32 bits | Dato leído de RAM |
| `rdata` | Hacia el núcleo | 32 bits | Dato seleccionado |

La interfaz MMIO externa es:

| Señal | Dirección | Ancho | Descripción |
| --- | --- | --- | --- |
| `mmio_rdata_i` | Entrada | 32 bits | Lectura seleccionada por la interconexión externa |
| `mmio_addr_o` | Salida | 32 bits | Dirección completa de byte |
| `mmio_wdata_o` | Salida | 32 bits | Dato de escritura |
| `mmio_sel_o` | Salida | 1 bit | Selección válida del espacio MMIO |
| `mmio_we_o` | Salida | 1 bit | Escritura MMIO habilitada |

#### Funcionamiento

La lógica verifica primero que los dos bits inferiores de la dirección sean cero. Esto identifica accesos alineados a palabras de cuatro bytes.

| Recurso | Condición de selección |
| --- | --- |
| RAM | Dirección alineada desde `0x00002000` hasta `0x00002FFF` |
| MMIO | Dirección alineada desde `0x00010000` hasta `0x0001FFFF`, fuera de reset |

La escritura RAM requiere `core_we`, selección RAM y reset inactivo. La escritura MMIO se obtiene mediante:

```systemverilog
assign mmio_we_o = core_we && mmio_sel_o;
```

El multiplexor devuelve el dato de RAM cuando está seleccionada, el dato MMIO cuando corresponde a ese espacio y cero en los demás casos:

```systemverilog
assign rdata = ram_sel ? ram_data :
               (mmio_sel_o ? mmio_rdata_i : 32'b0);
```

Los accesos de datos desalineados se ignoran al escribir y devuelven cero al leer. No generan una excepción.

`mmio_sel_o` depende de la dirección, no de una señal de lectura. Por ello, no debe emplearse por sí sola para consumir datos UART o limpiar banderas.

#### Relación con el sistema

La interconexión externa identifica el periférico específico, habilita únicamente su escritura y selecciona su dato de lectura. Si una dirección MMIO no corresponde a ningún dispositivo, esa interconexión debe devolver cero.

---

## 8. Periféricos

<!-- Sugerencia general: incluir al inicio de la sección los diagramas de tercer nivel de
los periféricos. -->

### 8.1 Periférico VGA

#### Entradas y salidas

#### Diagrama interno

<!-- Sugerencia: figura con generador de temporización, memoria de tiles, generador de
color y los dos dominios de reloj. -->

#### Funcionamiento

<!-- Sugerencia: temporización, cálculo de la casilla, sincronización entre dominios y
justificación de la cuadrícula elegida. -->

#### Relación con el sistema

### 8.2 Periférico de entradas del Jugador 1

#### Entradas y salidas

#### Funcionamiento

#### Relación con el sistema

### 8.3 Periférico UART

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: qué se reutilizó del Proyecto 2 y qué se ajustó. -->

#### Relación con el sistema

### 8.4 Displays de 7 segmentos

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: multiplexado, frecuencia de refresco, polaridad de las señales y formato
del dato. -->

#### Relación con el sistema

### 8.5 LED de estado

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: tabla de codificación del LED por fase del juego. -->

#### Relación con el sistema

### 8.6 Buzzer

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: tabla de eventos y su patrón sonoro (frecuencia y duración) y quién
controla la duración. -->

#### Relación con el sistema

### 8.7 Generación de relojes

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: relojes generados, señal de bloqueo del PLL y su uso en el reset. -->

#### Relación con el sistema

---

## 9. Programa en ensamblador

### 9.1 Estructura general del programa

<!-- Sugerencia: secciones del programa, constantes de direcciones, etiquetas
principales y flujo general. -->

### 9.2 Convenciones de llamado y uso de registros

<!-- Sugerencia: tabla registro → uso, paso de argumentos y retorno, manejo de la pila. -->

### 9.3 Máquina de estados del juego

<!-- Sugerencia: diagrama de estados del control principal con las condiciones de
transición. -->

### 9.4 Subrutinas principales

<!-- Sugerencia: tabla (Subrutina | Entradas | Salidas | Descripción). -->

### 9.5 Fase de colocación de barcos

<!-- Sugerencia: cursor, rotación, validación, colocación concurrente de ambos jugadores y
control de quién terminó. -->

### 9.6 Fase de batalla

<!-- Sugerencia: turnos, lectura de entradas y tramas, validación de disparo repetido,
actualización de tableros y de los periféricos. -->

### 9.7 Fin de la partida

<!-- Sugerencia: resultado en VGA, resumen enviado por UART, contadores y reinicio. -->

### 9.8 Ocultamiento de información

<!-- Sugerencia: cómo se garantiza que ningún jugador recibe la disposición de la flota del
otro. -->

---

## 10. Aplicación de PC del Jugador 2

### 10.1 Arquitectura de la aplicación

<!-- Sugerencia: lenguaje, librería serial, configuración del puerto y estructura. -->

### 10.2 Interfaz de usuario

<!-- Sugerencia: tablero propio, estado conocido del tablero rival e indicador de turno. -->

### 10.3 Validación de entradas y manejo de errores

### 10.4 Interpretación de paquetes

### 10.5 Instrucciones de ejecución

---

## 11. Asignación de pines

<!-- Sugerencia: tabla copiada del archivo de restricciones (señal, pin, estándar) que cubra
reloj, botones, UART, VGA, displays, LED y buzzer. -->

---

## 12. Presentación de resultados

<!--
Sugerencia general: peso 30% de la rúbrica. Debe ser explícita y autocontenida, y solo
mostrar evidencia (sin análisis crítico; eso va en la sección 13). Mínimo obligatorio:
  (a) simulaciones autoverificables del núcleo y de los periféricos,
  (b) simulación post-implementación temporizada (fragmento del programa y validación de un disparo),
  (c) evidencia física: VGA, aplicación de PC, buzzer, displays y LED,
  (d) evidencia de que ningún jugador ve la flota del otro,
  (e) fotografía del sistema completo en la FPGA,
  (f) utilización de recursos y timing copiados literalmente de los reportes de Vivado.
-->

### 12.1 Verificación por simulación

#### Testbenches

<!-- Sugerencia: tabla (Testbench | Qué verifica | Resultado) para núcleo, memorias,
interconexión, VGA, entradas, UART, displays/buzzer y sistema completo. -->

#### Resultado de los testbenches autoverificables

<!-- Sugerencia: captura de consola con PASS/FAIL y número de comprobaciones. -->

#### Formas de onda relevantes

<!-- Sugerencia: reset y primera instrucción, accesos a RAM y periféricos, salto
condicional, escritura de un tile, sincronismos, trama UART y validación de un disparo. -->

#### Simulación post-implementación temporizada

<!-- Sugerencia: fragmento representativo del programa y validación de un disparo. -->

#### Tabla de casos de prueba

<!-- Sugerencia: tabla (Caso | Estímulo | Resultado esperado | Resultado obtenido) con
colocaciones válidas e inválidas, impacto, fallo, disparo repetido, hundido, victoria,
BTN_RST y byte UART inválido. -->

### 12.2 Resultados físicos y funcionales

#### Fase de colocación

<!-- Sugerencia: captura o foto de la pantalla VGA durante la colocación. -->

#### Fase de batalla

<!-- Sugerencia: captura o foto de ambos tableros y del HUD. -->

#### Fin de la partida

<!-- Sugerencia: pantalla de resultado con el jugador ganador. -->

#### Aplicación de PC del Jugador 2

<!-- Sugerencia: captura de la aplicación con el tablero propio y el estado del rival. -->

#### Información oculta

<!-- Sugerencia: evidencia de que cada jugador solo ve impactos y fallos del rival. -->

#### Indicadores locales

<!-- Sugerencia: displays, LED por fase y los cinco sonidos del buzzer. -->

#### Fotografía del sistema completo

<!-- Sugerencia: OBLIGATORIA. Foto del montaje con la tarjeta, el monitor VGA y la PC. -->

### 12.3 Síntesis, implementación y utilización de recursos

#### Utilización de recursos

<!-- Sugerencia: tabla (Recurso | Utilizado | Disponible | % Utilización) con LUT, FF,
slices, BRAM, DSP, IO y PLL/MMCM, copiada del reporte de Vivado. -->

#### Análisis de timing

<!-- Sugerencia: WNS, TNS y hold slack copiados del reporte, confirmando si se cumple el
timing para el reloj de 100 MHz y el de píxel, con captura del reporte. -->

#### Evidencia de síntesis e implementación

<!-- Sugerencia: RTL elaborado, vista del dispositivo, ausencia de latches y de errores
críticos, y modelo exacto de la FPGA. -->

---

## 13. Análisis e interpretación de resultados

<!-- Sugerencia general: peso 25% de la rúbrica. Comparar valores teóricos, simulados y
experimentales e identificar causas de diferencias o errores. Referenciar los datos de
la sección 12 por número de figura o tabla sin repetirlos. -->

### 13.1 Análisis del procesador

<!-- Sugerencia: comportamiento observado, camino crítico y frecuencia máxima frente a la
real. -->

### 13.2 Análisis del periférico VGA

<!-- Sugerencia: estabilidad de la imagen, refresco teórico frente a observado y efecto del
cruce de dominios de reloj. -->

### 13.3 Análisis de la comunicación UART y la aplicación de PC

<!-- Sugerencia: protocolo especificado frente a tramas observadas, confiabilidad y
pérdidas. -->

### 13.4 Análisis del programa en ensamblador

<!-- Sugerencia: tamaño del programa frente a la ROM, uso de RAM y coordinación de turnos y
de la colocación concurrente. -->

### 13.5 Análisis de síntesis, timing y recursos

<!-- Sugerencia: margen de timing, módulos que más consumen y escalabilidad. -->

### 13.6 Problemas y soluciones

<!-- Sugerencia: tabla (Problema | Causa probable | Diagnóstico | Solución aplicada o
recomendada). -->

---

## 14. Conclusiones

<!-- Sugerencia: peso 15% de la rúbrica. Conclusiones numeradas, fundamentadas y
conectadas con los objetivos (sección 2) y los resultados (secciones 12 y 13). Incluir
lecciones aprendidas sobre la relación entre hardware y software, limitaciones y
mejoras futuras. -->

---

## Anexos (opcional)

<!-- Sugerencia: código ensamblador completo, tabla completa de pines y cualquier material
de soporte que no encaje en el cuerpo del informe. -->

## Referencias

<!-- Sugerencia: documentación de RISC-V, manual de la tarjeta, estándar VGA y demás
fuentes usadas. -->
