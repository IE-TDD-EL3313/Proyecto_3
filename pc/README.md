# Aplicación de PC - Jugador 2

Aplicación de escritorio para el Jugador 2 del proyecto Batalla Naval.

La aplicación funciona como una interfaz remota y se comunica con la FPGA
mediante UART. La lógica principal del juego se ejecuta en el procesador
RISC-V de la FPGA; la aplicación de PC se limita a enviar las acciones del
usuario y mostrar la información confirmada por la FPGA.

## Requisitos

- Python 3
- Tkinter 8.6 o compatible
- pyserial 3.5 o compatible

## Comunicación UART

La comunicación utiliza:

- Baud rate: 115200
- Bits de datos: 8
- Paridad: ninguna
- Bits de parada: 1
- Codificación: ASCII
- Terminación de trama: `\n`

Configuración: **115200 8N1**.

## Ejecución

Desde la raíz del repositorio:

```bash
PYTHONPATH=pc/src python3 pc/src/player2.py --port /dev/ttyUSB0
```

El puerto puede modificarse según el dispositivo conectado. Por ejemplo,
también puede utilizarse `/dev/ttyACM0`.

## Funcionalidad

La aplicación permite:

- visualizar el tablero propio de 8x8;
- visualizar el estado conocido del tablero rival;
- seleccionar barco, posición y orientación;
- enviar solicitudes de colocación;
- mostrar colocaciones aceptadas o rechazadas;
- mostrar el motivo de rechazo;
- seleccionar y enviar disparos;
- mostrar fallo, impacto o barco hundido;
- mostrar el turno actual;
- mostrar el resultado final;
- generar un resumen de la partida;
- detectar datos y tramas UART inválidas.

La aplicación no implementa las reglas principales de Batalla Naval.
La validación definitiva de las acciones corresponde a la FPGA.

## Protocolo

### PC hacia FPGA

Colocación:

```text
P,barco,fila,columna,orientacion
```

Disparo:

```text
S,fila,columna
```

### FPGA hacia PC

```text
PA,barco
PR,barco,motivo
B
T,jugador
SR,fila,columna,resultado
DR,fila,columna,resultado
FIN,ganador
```

Motivos de rechazo:

- `O`: traslape.
- `F`: fuera del tablero.

Resultados de disparo:

- `F`: fallo.
- `I`: impacto.
- `H`: barco hundido.

## Pruebas

Ejecutar desde la raíz del repositorio:

```bash
python3 -m unittest discover -s pc/tests -p 'test_*.py' -v
```

Las pruebas verifican el protocolo, la comunicación serial simulada, el
estado del Jugador 2 y un flujo completo de partida sin hardware.

La validación final mediante UART física queda pendiente hasta disponer
de la integración completa con la FPGA.

## Estructura

```text
pc/
├── README.md
├── src/
│   ├── player2.py
│   ├── player2_state.py
│   ├── protocol.py
│   └── serial_link.py
└── tests/
    ├── test_game_flow.py
    ├── test_player2_state.py
    ├── test_protocol.py
    └── test_serial_link.py
```
