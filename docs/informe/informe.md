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

<!-- Sugerencia general: un apartado por bloque, todos con los mismos subtítulos ####.
Incluir al inicio de la sección la figura del diagrama de tercer nivel del procesador. -->

### 7.1 Núcleo

#### Entradas y salidas

<!-- Sugerencia: tabla de señales con nombre, ancho, dirección y descripción. -->

#### Diagrama del datapath

<!-- Sugerencia: figura del datapath con buses, anchos y señales de control. -->

#### Funcionamiento

<!-- Sugerencia: cómo se ejecuta cada tipo de instrucción y cómo se accede a RAM y
periféricos. -->

#### Relación con el sistema

### 7.2 Unidad de control

#### Entradas y salidas

#### Tabla de señales de control

<!-- Sugerencia: tabla instrucción → señales de control. -->

#### Funcionamiento

#### Relación con el sistema

### 7.3 Banco de registros

#### Entradas y salidas

#### Funcionamiento

#### Relación con el sistema

### 7.4 ALU

#### Entradas y salidas

#### Operaciones soportadas

<!-- Sugerencia: tabla código de operación → operación → instrucciones que la usan. -->

#### Funcionamiento

#### Relación con el sistema

### 7.5 Generador de inmediatos y lógica de saltos

#### Entradas y salidas

#### Funcionamiento

#### Relación con el sistema

### 7.6 Memorias ROM y RAM

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: tamaños, inicialización de la ROM, acceso de la RAM y alineación. -->

#### Relación con el sistema

### 7.7 Decodificador de direcciones y multiplexor de lectura

#### Entradas y salidas

#### Funcionamiento

<!-- Sugerencia: cómo se generan las selecciones y habilitaciones de escritura y cómo se
elige el dato de lectura. -->

#### Relación con el sistema

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
