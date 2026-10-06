# ============================================================================
# Batalla Naval - Proyecto 3
# Firmware principal RV32I
# ============================================================================

.option norvc
.option norelax

.section .text
.global _start

# MMIO
.equ UART_STATUS,     0x00010040
.equ UART_TX,         0x00010044
.equ UART_RX,         0x00010048
.equ INPUT,           0x00010120
.equ DISPLAY,         0x00010130
.equ LED,             0x00010138
.equ BUZZER,          0x00010140
.equ VGA_BASE,        0x00011000

# RAM
.equ GAME_STATE,      0x00002000
.equ TURN,            0x00002004
.equ CURSOR_ROW,      0x00002008
.equ CURSOR_COL,      0x0000200c
.equ ORIENTATION,     0x00002010
.equ CURRENT_SHIP,    0x00002014
.equ PLACED_J1,       0x00002018
.equ PLACED_J2,       0x0000201c
.equ WINS_J1,         0x00002020
.equ WINS_J2,         0x00002024

.equ BOARD_J1,        0x00002100
.equ BOARD_J2,        0x00002200
.equ SHOTS_J1,        0x00002300
.equ SHOTS_J2,        0x00002400

# Estado del parser UART
.equ UART_LAST_BYTE,   0x00002500
.equ UART_PARSE_STATE, 0x00002504
.equ UART_SHIP,        0x00002508
.equ UART_ROW,         0x0000250C
.equ UART_COL,         0x00002510
.equ UART_ORIENT,      0x00002514
.equ UART_FRAME_READY, 0x00002518
.equ J2_SHIP_MASK,     0x0000251C

# Tipo de trama UART
.equ UART_CMD,         0x00002520
.equ UART_CMD_PLACE,   1
.equ UART_CMD_SHOT,    2

# Estados
.equ STATE_PLACEMENT, 0
.equ STATE_BATTLE,    1
.equ STATE_FINISHED,  2

# Casillas
.equ CELL_WATER,      0
.equ CELL_SHIP,       1
.equ CELL_HIT,        2
.equ CELL_MISS,       3

# Botones
.equ BTN_UP,          0x01
.equ BTN_DOWN,        0x02
.equ BTN_LEFT,        0x04
.equ BTN_RIGHT,       0x08
.equ BTN_SEL,         0x10
.equ BTN_OK,          0x20
.equ BTN_RST,         0x40

# LED
.equ LED_PLACEMENT,   1
.equ LED_BATTLE,      2
.equ LED_FINISHED,    4

# ============================================================================
# Inicio
# ============================================================================

_start:
    lui     s0, 0x2              # RAM  = 0x00002000
    lui     s1, 0x10             # MMIO = 0x00010000
    lui     s2, 0x11             # VGA  = 0x00011000

    # Victorias se inicializan solamente al arrancar el sistema.
    sw      zero, 32(s0)
    sw      zero, 36(s0)

    jal     ra, init_game

main_loop:
    # Revisar si existe un byte UART pendiente.
    jal     ra, poll_uart

    # Procesar una trama UART completa, si existe.
    jal     ra, process_uart_frame

    # Leer pulsos de botones.
    lw      t0, 0x120(s1)

    andi    t1, t0, BTN_RST
    bne     t1, zero, restart_game

    # Despachar controles locales segun el estado del juego.
    lw      t1, 0(s0)

    addi    t2, zero, STATE_PLACEMENT
    beq     t1, t2, controls_placement

    addi    t2, zero, STATE_BATTLE
    beq     t1, t2, controls_battle

    # STATE_FINISHED: solamente BTN_RST permanece activo.
    jal     zero, main_loop

controls_placement:
    andi    t1, t0, BTN_UP
    bne     t1, zero, cursor_up

    andi    t1, t0, BTN_DOWN
    bne     t1, zero, cursor_down

    andi    t1, t0, BTN_LEFT
    bne     t1, zero, cursor_left

    andi    t1, t0, BTN_RIGHT
    bne     t1, zero, cursor_right

    andi    t1, t0, BTN_SEL
    bne     t1, zero, toggle_orientation

    andi    t1, t0, BTN_OK
    bne     t1, zero, place_ship_j1

    jal     zero, main_loop

controls_battle:
    # Los botones locales solo actuan durante el turno de J1.
    lw      t1, 4(s0)
    addi    t2, zero, 1
    bne     t1, t2, main_loop

    andi    t1, t0, BTN_UP
    bne     t1, zero, cursor_up

    andi    t1, t0, BTN_DOWN
    bne     t1, zero, cursor_down

    andi    t1, t0, BTN_LEFT
    bne     t1, zero, cursor_left

    andi    t1, t0, BTN_RIGHT
    bne     t1, zero, cursor_right

    andi    t1, t0, BTN_OK
    bne     t1, zero, shot_j1

    jal     zero, main_loop

restart_game:
    jal     ra, init_game
    jal     zero, main_loop

cursor_up:
    lw      t1, 8(s0)
    beq     t1, zero, main_loop
    addi    t1, t1, -1
    sw      t1, 8(s0)
    jal     zero, main_loop

cursor_down:
    lw      t1, 8(s0)
    addi    t2, zero, 7
    bge     t1, t2, main_loop
    addi    t1, t1, 1
    sw      t1, 8(s0)
    jal     zero, main_loop

cursor_left:
    lw      t1, 12(s0)
    beq     t1, zero, main_loop
    addi    t1, t1, -1
    sw      t1, 12(s0)
    jal     zero, main_loop

cursor_right:
    lw      t1, 12(s0)
    addi    t2, zero, 7
    bge     t1, t2, main_loop
    addi    t1, t1, 1
    sw      t1, 12(s0)
    jal     zero, main_loop

toggle_orientation:
    lw      t1, 16(s0)
    xori    t1, t1, 1
    sw      t1, 16(s0)
    jal     zero, main_loop

# ============================================================================
# Recepcion UART
#
# Etapa inicial de validacion:
#   - consulta RX_VALID
#   - lee UART_RX
#   - guarda el byte recibido en UART_LAST_BYTE
#   - limpia RX_VALID escribiendo bit 1 en UART_STATUS
#
# Posteriormente esta rutina alimentara el parser del protocolo.
# ============================================================================

poll_uart:
    # STATUS bit 1 = RX_VALID.
    lw      t0, 0x040(s1)
    andi    t1, t0, 2
    beq     t1, zero, poll_uart_done

    # Leer byte recibido.
    lw      t0, 0x048(s1)

    # Base del estado UART = 0x2500.
    addi    t2, s0, 1280

    # Conservar ultimo byte recibido.
    sw      t0, 0(t2)

    # Limpiar RX_VALID inmediatamente.
    addi    t1, zero, 2
    sw      t1, 0x040(s1)

    # Estado actual del parser.
    lw      t1, 4(t2)

    # Estados 0..9:
    # 0:P  1:,  2:ship  3:,  4:row
    # 5:,  6:col  7:,  8:H/V  9:\n
    beq     t1, zero, uart_state_0

    addi    t3, zero, 1
    beq     t1, t3, uart_state_1
    addi    t3, zero, 2
    beq     t1, t3, uart_state_2
    addi    t3, zero, 3
    beq     t1, t3, uart_state_3
    addi    t3, zero, 4
    beq     t1, t3, uart_state_4
    addi    t3, zero, 5
    beq     t1, t3, uart_state_5
    addi    t3, zero, 6
    beq     t1, t3, uart_state_6
    addi    t3, zero, 7
    beq     t1, t3, uart_state_7
    addi    t3, zero, 8
    beq     t1, t3, uart_state_8
    addi    t3, zero, 9
    beq     t1, t3, uart_state_9

    addi    t3, zero, 10
    beq     t1, t3, uart_state_10

    addi    t3, zero, 11
    beq     t1, t3, uart_state_11

    addi    t3, zero, 12
    beq     t1, t3, uart_state_12

    addi    t3, zero, 13
    beq     t1, t3, uart_state_13

    addi    t3, zero, 14
    beq     t1, t3, uart_state_14

    jal     zero, uart_parser_reset

uart_state_0:
    # 'P' = trama de colocacion.
    addi    t3, zero, 80
    beq     t0, t3, uart_start_place

    # 'S' = trama de disparo.
    addi    t3, zero, 83
    beq     t0, t3, uart_start_shot

    jal     zero, uart_parser_reset


uart_start_place:
    addi    t3, zero, UART_CMD_PLACE
    sw      t3, 32(t2)

    # Estado 1: esperar ','.
    addi    t1, zero, 1
    sw      t1, 4(t2)

    jal     zero, poll_uart_done


uart_start_shot:
    addi    t3, zero, UART_CMD_SHOT
    sw      t3, 32(t2)

    # Estado 10: esperar ',' despues de S.
    addi    t1, zero, 10
    sw      t1, 4(t2)

    jal     zero, poll_uart_done

uart_state_1:
    # Esperar ',' = 0x2C.
    addi    t3, zero, 44
    bne     t0, t3, uart_parser_reset
    addi    t1, zero, 2
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_2:
    # Barco ASCII '0'..'2'.
    addi    t3, zero, 48
    blt     t0, t3, uart_parser_reset
    addi    t4, zero, 51
    bge     t0, t4, uart_parser_reset
    addi    t0, t0, -48
    sw      t0, 8(t2)
    addi    t1, zero, 3
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_3:
    addi    t3, zero, 44
    bne     t0, t3, uart_parser_reset
    addi    t1, zero, 4
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_4:
    # Fila ASCII '0'..'7'.
    addi    t3, zero, 48
    blt     t0, t3, uart_parser_reset
    addi    t4, zero, 56
    bge     t0, t4, uart_parser_reset
    addi    t0, t0, -48
    sw      t0, 12(t2)
    addi    t1, zero, 5
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_5:
    addi    t3, zero, 44
    bne     t0, t3, uart_parser_reset
    addi    t1, zero, 6
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_6:
    # Columna ASCII '0'..'7'.
    addi    t3, zero, 48
    blt     t0, t3, uart_parser_reset
    addi    t4, zero, 56
    bge     t0, t4, uart_parser_reset
    addi    t0, t0, -48
    sw      t0, 16(t2)
    addi    t1, zero, 7
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_7:
    addi    t3, zero, 44
    bne     t0, t3, uart_parser_reset
    addi    t1, zero, 8
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_8:
    # H = 0, V = 1.
    addi    t3, zero, 72
    beq     t0, t3, uart_orientation_h

    addi    t3, zero, 86
    beq     t0, t3, uart_orientation_v

    jal     zero, uart_parser_reset

uart_orientation_h:
    sw      zero, 20(t2)
    addi    t1, zero, 9
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_orientation_v:
    addi    t3, zero, 1
    sw      t3, 20(t2)
    addi    t1, zero, 9
    sw      t1, 4(t2)
    jal     zero, poll_uart_done

uart_state_9:
    # Fin de trama: LF = 0x0A.
    addi    t3, zero, 10
    bne     t0, t3, uart_parser_reset

    # Trama P completa y valida.
    sw      zero, 4(t2)
    addi    t3, zero, 1
    sw      t3, 24(t2)
    jal     zero, poll_uart_done


uart_state_10:
    # Esperar ',' despues de 'S'.
    addi    t3, zero, 44
    bne     t0, t3, uart_parser_reset

    # Estado 11: fila.
    addi    t1, zero, 11
    sw      t1, 4(t2)

    jal     zero, poll_uart_done


uart_state_11:
    # Fila ASCII '0'..'7'.
    addi    t3, zero, 48
    blt     t0, t3, uart_parser_reset

    addi    t4, zero, 56
    bge     t0, t4, uart_parser_reset

    addi    t0, t0, -48
    sw      t0, 12(t2)

    # Estado 12: esperar ','.
    addi    t1, zero, 12
    sw      t1, 4(t2)

    jal     zero, poll_uart_done


uart_state_12:
    # Esperar ',' entre fila y columna.
    addi    t3, zero, 44
    bne     t0, t3, uart_parser_reset

    # Estado 13: columna.
    addi    t1, zero, 13
    sw      t1, 4(t2)

    jal     zero, poll_uart_done


uart_state_13:
    # Columna ASCII '0'..'7'.
    addi    t3, zero, 48
    blt     t0, t3, uart_parser_reset

    addi    t4, zero, 56
    bge     t0, t4, uart_parser_reset

    addi    t0, t0, -48
    sw      t0, 16(t2)

    # Estado 14: esperar LF.
    addi    t1, zero, 14
    sw      t1, 4(t2)

    jal     zero, poll_uart_done


uart_state_14:
    # Fin de trama: LF = 0x0A.
    addi    t3, zero, 10
    bne     t0, t3, uart_parser_reset

    # Trama S completa y valida.
    sw      zero, 4(t2)

    addi    t3, zero, 1
    sw      t3, 24(t2)

    jal     zero, poll_uart_done


uart_parser_reset:
    # Descartar trama malformada.
    sw      zero, 4(t2)

poll_uart_done:
    jalr    zero, 0(ra)

# ============================================================================
# Procesamiento de colocacion UART del Jugador 2
#
# Consume una trama P ya validada sintacticamente por poll_uart.
#
# BOARD_J2:
#   0 = agua
#   1 = barco 0
#   2 = barco 1
#   3 = barco 2
#
# Longitudes:
#   barco 0 -> 4
#   barco 1 -> 3
#   barco 2 -> 2
#
# UART_ORIENT:
#   0 = horizontal
#   1 = vertical
# ============================================================================

# ============================================================================
# Transmision UART de un caracter
#
# Entrada:
#   a0 = caracter ASCII a transmitir
#
# Retorno:
#   mediante t6, para permitir llamadas desde rutinas que conservan ra.
#
# Espera hasta que STATUS.TX_BUSY = 0 y escribe el byte en UART_TX.
# ============================================================================

uart_putc:
uart_putc_wait:
    lw      t0, 0x040(s1)
    andi    t0, t0, 1
    bne     t0, zero, uart_putc_wait

    sw      a0, 0x044(s1)
    jalr    zero, 0(t6)


process_uart_frame:
    # Base del parser UART = 0x2500.
    addi    t0, s0, 1280

    # No hacer nada si no existe una trama completa.
    lw      t1, 24(t0)
    beq     t1, zero, process_uart_done

    # Consumir FRAME_READY inmediatamente.
    sw      zero, 24(t0)

    # Determinar tipo de trama.
    lw      t1, 32(t0)          # UART_CMD

    addi    t2, zero, UART_CMD_PLACE
    beq     t1, t2, process_uart_place

    addi    t2, zero, UART_CMD_SHOT
    beq     t1, t2, process_uart_shot

    jal     zero, process_uart_done


process_uart_place:
    # Solo aceptar colocaciones durante STATE_PLACEMENT.
    lw      t1, 0(s0)
    bne     t1, zero, process_uart_done

    # Cargar campos.
    lw      t1, 8(t0)          # ship
    lw      t2, 12(t0)         # row
    lw      t3, 16(t0)         # col
    lw      t4, 20(t0)         # orient

    # ------------------------------------------------------------
    # Verificar que este ship ID no haya sido colocado antes.
    # mascara = 1 << ship
    # ------------------------------------------------------------
    addi    t5, zero, 1
    sll     t5, t5, t1

    lw      t6, 28(t0)         # J2_SHIP_MASK
    and     t6, t6, t5
    bne     t6, zero, j2_reject_overlap

    # ------------------------------------------------------------
    # longitud = 4 - ship
    # ------------------------------------------------------------
    addi    t6, zero, 4
    sub     t6, t6, t1         # t6 = longitud

    # ------------------------------------------------------------
    # Validar limites.
    # Horizontal: col + longitud <= 8
    # Vertical:   row + longitud <= 8
    # ------------------------------------------------------------
    bne     t4, zero, j2_check_vertical_bounds

    add     t5, t3, t6
    addi    t4, zero, 8
    blt     t4, t5, j2_reject_bounds
    jal     zero, j2_check_overlap_setup

j2_check_vertical_bounds:
    add     t5, t2, t6
    addi    t4, zero, 8
    blt     t4, t5, j2_reject_bounds
    jal     zero, j2_check_overlap_setup

# ------------------------------------------------------------
# Rechazo por fuera de tablero:
#
#     PR,barco,F\n
# ------------------------------------------------------------
j2_reject_bounds:
    add     a1, t1, zero        # conservar ship ID

    addi    a0, zero, 80        # 'P'
    jal     t6, uart_putc

    addi    a0, zero, 82        # 'R'
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, a1, 48          # ship -> ASCII
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, zero, 70        # 'F'
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    jal     zero, process_uart_done

j2_check_overlap_setup:
    # Recuperar orientacion porque t4 se uso en limites.
    lw      t4, 20(t0)

    # t5 = contador de celdas.
    addi    t5, zero, 0

j2_check_overlap_loop:
    bge     t5, t6, j2_place_setup

    # Calcular fila/columna de la celda actual.
    # a0 = row, a1 = col
    add     a0, t2, zero
    add     a1, t3, zero

    beq     t4, zero, j2_overlap_horizontal

    # Vertical: row += contador.
    add     a0, a0, t5
    jal     zero, j2_overlap_address

j2_overlap_horizontal:
    # Horizontal: col += contador.
    add     a1, a1, t5

j2_overlap_address:
    # indice = row*8 + col
    slli    a2, a0, 3
    add     a2, a2, a1
    slli    a2, a2, 2

    # BOARD_J2 = 0x2200 = s0 + 512.
    addi    a3, s0, 512
    add     a3, a3, a2

    lw      a4, 0(a3)
    bne     a4, zero, j2_reject_overlap

    addi    t5, t5, 1
    jal     zero, j2_check_overlap_loop

# ------------------------------------------------------------
# Rechazo por traslape o ship ID duplicado:
#
#     PR,barco,O\n
# ------------------------------------------------------------
j2_reject_overlap:
    add     a1, t1, zero        # conservar ship ID

    addi    a0, zero, 80        # 'P'
    jal     t6, uart_putc

    addi    a0, zero, 82        # 'R'
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, a1, 48          # ship -> ASCII
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, zero, 79        # 'O'
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    jal     zero, process_uart_done

j2_place_setup:
    addi    t5, zero, 0

    # Valor almacenado = ship + 1.
    addi    a5, t1, 1

j2_place_loop:
    bge     t5, t6, j2_place_complete

    add     a0, t2, zero
    add     a1, t3, zero

    beq     t4, zero, j2_place_horizontal

    add     a0, a0, t5
    jal     zero, j2_place_address

j2_place_horizontal:
    add     a1, a1, t5

j2_place_address:
    slli    a2, a0, 3
    add     a2, a2, a1
    slli    a2, a2, 2

    addi    a3, s0, 512
    add     a3, a3, a2

    sw      a5, 0(a3)

    addi    t5, t5, 1
    jal     zero, j2_place_loop

j2_place_complete:
    # Conservar ship ID para actualizar la mascara y responder por UART.
    add     a1, t1, zero

    # PLACED_J2++.
    lw      t2, 28(s0)
    addi    t2, t2, 1
    sw      t2, 28(s0)

    # J2_SHIP_MASK |= (1 << ship).
    addi    t0, s0, 1280
    addi    t2, zero, 1
    sll     t2, t2, a1

    lw      t3, 28(t0)
    or      t3, t3, t2
    sw      t3, 28(t0)

    # ------------------------------------------------------------
    # Respuesta de colocacion aceptada:
    #
    #     PA,barco\n
    # ------------------------------------------------------------

    addi    a0, zero, 80       # 'P'
    jal     t6, uart_putc

    addi    a0, zero, 65       # 'A'
    jal     t6, uart_putc

    addi    a0, zero, 44       # ','
    jal     t6, uart_putc

    addi    a0, a1, 48         # ship -> ASCII
    jal     t6, uart_putc

    addi    a0, zero, 10       # LF
    jal     t6, uart_putc

    # ------------------------------------------------------------
    # Iniciar batalla cuando ambas flotas esten completas.
    # ------------------------------------------------------------
    lw      t0, 24(s0)          # PLACED_J1
    addi    t1, zero, 3
    bne     t0, t1, process_uart_done

    lw      t0, 28(s0)          # PLACED_J2
    bne     t0, t1, process_uart_done

    # GAME_STATE = STATE_BATTLE.
    addi    t0, zero, STATE_BATTLE
    sw      t0, 0(s0)

    # Jugador 1 inicia.
    addi    t0, zero, 1
    sw      t0, 4(s0)           # TURN = 1

    # LED de estado: batalla.
    addi    t0, zero, 2
    sw      t0, 0x138(s1)

    # ------------------------------------------------------------
    # Notificar inicio de batalla:
    #
    #     B\n
    # ------------------------------------------------------------
    addi    a0, zero, 66        # 'B'
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    # ------------------------------------------------------------
    # Notificar turno inicial:
    #
    #     T,1\n
    # ------------------------------------------------------------
    addi    a0, zero, 84        # 'T'
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, zero, 49        # '1'
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc


process_uart_shot:
    # ------------------------------------------------------------
    # Disparo del Jugador 2 mediante UART:
    #
    #     S,row,col\n
    #
    # Solo valido durante STATE_BATTLE y TURN=2.
    # ------------------------------------------------------------

    # ------------------------------------------------------------
    # Verificar estado de batalla.
    # ------------------------------------------------------------
    lw      t1, 0(s0)
    addi    t2, zero, STATE_BATTLE
    bne     t1, t2, process_uart_done

    # ------------------------------------------------------------
    # Verificar turno del Jugador 2.
    # ------------------------------------------------------------
    lw      t1, 4(s0)
    addi    t2, zero, 2
    bne     t1, t2, process_uart_done

    # ------------------------------------------------------------
    # Cargar fila y columna recibidas por UART.
    # ------------------------------------------------------------
    lw      t1, 12(t0)          # row
    lw      t2, 16(t0)          # col

    # ------------------------------------------------------------
    # indice = fila*8 + columna
    # ------------------------------------------------------------
    slli    t3, t1, 3
    add     t3, t3, t2

    # offset = indice * 4
    slli    t4, t3, 2

    # ------------------------------------------------------------
    # SHOTS_J2 = 0x2400 = s0 + 1024
    # ------------------------------------------------------------
    addi    t5, s0, 1024
    add     t5, t5, t4

    # ------------------------------------------------------------
    # No permitir disparar dos veces la misma casilla.
    # ------------------------------------------------------------
    lw      t6, 0(t5)
    bne     t6, zero, process_uart_done

    # ------------------------------------------------------------
    # Consultar BOARD_J1 = 0x2100 = s0 + 256.
    # ------------------------------------------------------------
    addi    t6, s0, 256
    add     t6, t6, t4

    lw      a0, 0(t6)

    # ------------------------------------------------------------
    # Determinar resultado:
    #
    # 0     -> MISS
    # != 0  -> HIT
    #
    # Si hay impacto, conservar la identidad del barco de J1.
    # ------------------------------------------------------------
    beq     a0, zero, j2_shot_miss

    add     a4, a0, zero        # identidad del barco: 1..3
    addi    a1, zero, CELL_HIT
    jal     zero, j2_shot_store

j2_shot_miss:
    addi    a1, zero, CELL_MISS

j2_shot_store:
    # ------------------------------------------------------------
    # Registrar resultado en SHOTS_J2.
    # ------------------------------------------------------------
    sw      a1, 0(t5)

    # ------------------------------------------------------------
    # Actualizar VGA del tablero de J1.
    #
    # J1 ocupa columnas visuales 0..7.
    # tile = fila*20 + columna
    # ------------------------------------------------------------
    slli    a2, t1, 4
    slli    a3, t1, 2
    add     a2, a2, a3
    add     a2, a2, t2
    slli    a2, a2, 2
    add     a2, s2, a2

    sw      a1, 0(a2)

    # ------------------------------------------------------------
    # Determinar caracter de resultado UART:
    #
    # F -> fallo
    # I -> impacto
    # H -> barco hundido
    #
    # a5 conserva el caracter durante uart_putc.
    # ------------------------------------------------------------
    addi    a0, zero, CELL_HIT
    bne     a1, a0, j2_shot_result_miss

    add     a0, a4, zero
    jal     ra, check_ship_sunk_j1

    beq     a0, zero, j2_shot_result_hit

    addi    a5, zero, 72        # 'H'
    jal     zero, j2_shot_send_result

j2_shot_result_hit:
    addi    a5, zero, 73        # 'I'
    jal     zero, j2_shot_send_result

j2_shot_result_miss:
    addi    a5, zero, 70        # 'F'

j2_shot_send_result:
    # ------------------------------------------------------------
    # Recargar fila y columna del parser.
    #
    # t0 no puede conservarse durante uart_putc porque uart_putc
    # utiliza t0 internamente.
    # ------------------------------------------------------------
    addi    a4, s0, 1280
    lw      a2, 12(a4)          # row
    lw      a3, 16(a4)          # col

    # Enviar:
    #
    #     SR,row,col,resultado\n
    # ------------------------------------------------------------
    addi    a0, zero, 83        # 'S'
    jal     t6, uart_putc

    addi    a0, zero, 82        # 'R'
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, a2, 48          # row ASCII
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    addi    a0, a3, 48          # col ASCII
    jal     t6, uart_putc

    addi    a0, zero, 44        # ','
    jal     t6, uart_putc

    add     a0, a5, zero        # F / I / H
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    # ------------------------------------------------------------
    # Comprobar victoria de J2.
    #
    # Se recorren BOARD_J1 y SHOTS_J2. J2 gana cuando toda celda
    # perteneciente a un barco de J1 contiene CELL_HIT.
    # ------------------------------------------------------------
    jal     ra, check_win_j2
    bne     a0, zero, win_j2

    # Si aun no gano, pasa el turno al Jugador 1.
    addi    a0, zero, 1
    sw      a0, 4(s0)

    # Informar cambio de turno: T,1\n
    addi    a0, zero, 84        # T
    jal     t6, uart_putc

    addi    a0, zero, 44        # ,
    jal     t6, uart_putc

    addi    a0, zero, 49        # 1
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    jal     zero, main_loop


# ============================================================================
# check_win_j2
#
# Salida:
#   a0 = 1 -> todos los barcos de J1 fueron destruidos
#   a0 = 0 -> queda al menos una celda de barco sin impactar
#
# BOARD_J1 = s0 + 256
# SHOTS_J2 = s0 + 1024
# ============================================================================
check_win_j2:
    addi    a1, zero, 0

check_win_j2_loop:
    addi    a2, zero, 64
    bge     a1, a2, check_win_j2_yes

    slli    a2, a1, 2

    # BOARD_J1[index]
    addi    a3, s0, 256
    add     a3, a3, a2
    lw      a4, 0(a3)

    # Agua: continuar.
    beq     a4, zero, check_win_j2_next

    # Celda de barco: debe estar impactada.
    addi    a3, s0, 1024
    add     a3, a3, a2
    lw      a4, 0(a3)

    addi    a3, zero, CELL_HIT
    bne     a4, a3, check_win_j2_no

check_win_j2_next:
    addi    a1, a1, 1
    jal     zero, check_win_j2_loop

check_win_j2_no:
    addi    a0, zero, 0
    jalr    zero, 0(ra)

check_win_j2_yes:
    addi    a0, zero, 1
    jalr    zero, 0(ra)


# ============================================================================
# win_j2
#
# Finaliza la partida, incrementa WINS_J2 y envia:
#
#     FIN,2\n
# ============================================================================
win_j2:
    # STATE_FINISHED.
    addi    a0, zero, STATE_FINISHED
    sw      a0, 0(s0)

    # Incrementar WINS_J2.
    lw      a0, 36(s0)
    addi    a0, a0, 1
    sw      a0, 36(s0)

    # Actualizar marcador de victorias en display.
    jal     t6, update_display

    # LED de partida terminada.
    addi    a0, zero, LED_FINISHED
    sw      a0, 0x138(s1)

    # FIN,2\n
    addi    a0, zero, 70        # F
    jal     t6, uart_putc

    addi    a0, zero, 73        # I
    jal     t6, uart_putc

    addi    a0, zero, 78        # N
    jal     t6, uart_putc

    addi    a0, zero, 44        # ,
    jal     t6, uart_putc

    addi    a0, zero, 50        # 2
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    jal     zero, main_loop


# ============================================================================
# check_ship_sunk_j1
#
# Comprueba si un barco del Jugador 1 esta completamente hundido.
#
# Entrada:
#   a0 = valor almacenado en BOARD_J1 (1, 2 o 3)
#
# Salida:
#   a0 = 1 -> hundido
#   a0 = 0 -> aun quedan celdas sin impactar
#
# BOARD_J1 = s0 + 256
# SHOTS_J2 = s0 + 1024
# ============================================================================
check_ship_sunk_j1:
    add     a1, a0, zero        # identidad del barco
    addi    a2, zero, 0         # indice

check_ship_sunk_j1_loop:
    addi    a3, zero, 64
    bge     a2, a3, check_ship_sunk_j1_yes

    # offset = indice * 4
    slli    a3, a2, 2

    # BOARD_J1[indice]
    addi    a4, s0, 256
    add     a4, a4, a3
    lw      a5, 0(a4)

    # Si esta celda no pertenece al barco, continuar.
    bne     a5, a1, check_ship_sunk_j1_next

    # Si pertenece al barco, SHOTS_J2 debe contener CELL_HIT.
    addi    a4, s0, 1024
    add     a4, a4, a3
    lw      a5, 0(a4)

    addi    a4, zero, CELL_HIT
    bne     a5, a4, check_ship_sunk_j1_no

check_ship_sunk_j1_next:
    addi    a2, a2, 1
    jal     zero, check_ship_sunk_j1_loop

check_ship_sunk_j1_no:
    addi    a0, zero, 0
    jalr    zero, 0(ra)

check_ship_sunk_j1_yes:
    addi    a0, zero, 1
    jalr    zero, 0(ra)


process_uart_done:
    jalr    zero, 0(ra)


# ============================================================================
# Colocacion local del Jugador 1
#
# CURRENT_SHIP:
#   0 -> longitud 4
#   1 -> longitud 3
#   2 -> longitud 2
# ============================================================================

# ============================================================================
# Disparo local del Jugador 1
#
# Usa CURSOR_ROW/CURSOR_COL sobre el tablero del Jugador 2.
#
# SHOTS_J1:
#   0 = no disparado
#   2 = impacto
#   3 = fallo
#
# VGA tablero enemigo:
#   filas    0..7
#   columnas 10..17
# ============================================================================

shot_j1:
    lw      t1, 8(s0)            # fila
    lw      t2, 12(s0)           # columna

    # indice = fila*8 + columna
    slli    t3, t1, 3
    add     t3, t3, t2

    # offset en bytes.
    slli    t4, t3, 2

    # ------------------------------------------------------------
    # No permitir disparar dos veces a la misma casilla.
    # ------------------------------------------------------------
    addi    t5, s0, 768          # SHOTS_J1 = 0x2300
    add     t5, t5, t4

    lw      t6, 0(t5)
    bne     t6, zero, main_loop

    # ------------------------------------------------------------
    # Consultar BOARD_J2.
    # ------------------------------------------------------------
    addi    t6, s0, 512          # BOARD_J2 = 0x2200
    add     t6, t6, t4

    lw      a0, 0(t6)
    beq     a0, zero, shot_j1_miss

    # ------------------------------------------------------------
    # Impacto.
    #
    # Conservar temporalmente la identidad del barco (1..3).
    # La identidad permanece en BOARD_J2; SHOTS_J1 solamente
    # almacena HIT/MISS.
    # ------------------------------------------------------------
    add     a4, a0, zero
    addi    a1, zero, CELL_HIT
    jal     zero, shot_j1_store

shot_j1_miss:
    addi    a1, zero, CELL_MISS

shot_j1_store:
    # Registrar resultado en SHOTS_J1.
    sw      a1, 0(t5)

    # ------------------------------------------------------------
    # Actualizar VGA del tablero enemigo.
    #
    # tile = fila*20 + (10 + columna)
    # ------------------------------------------------------------
    slli    a2, t1, 4            # fila*16
    slli    a3, t1, 2            # fila*4
    add     a2, a2, a3           # fila*20

    addi    a3, t2, 10
    add     a2, a2, a3

    slli    a2, a2, 2
    add     a2, s2, a2

    sw      a1, 0(a2)

    # ------------------------------------------------------------
    # Determinar resultado UART del disparo.
    #
    # DR,row,col,F\n -> fallo
    # DR,row,col,I\n -> impacto
    # DR,row,col,H\n -> barco hundido
    #
    # a5 contiene el caracter ASCII del resultado.
    # ------------------------------------------------------------
    addi    a0, zero, CELL_HIT
    bne     a1, a0, shot_j1_result_miss

    # Fue impacto: comprobar si el barco quedo hundido.
    add     a0, a4, zero
    jal     ra, check_ship_sunk_j2

    beq     a0, zero, shot_j1_result_hit

    addi    a5, zero, 72         # 'H'
    jal     zero, shot_j1_send_result

shot_j1_result_hit:
    addi    a5, zero, 73         # 'I'
    jal     zero, shot_j1_send_result

shot_j1_result_miss:
    addi    a5, zero, 70         # 'F'

shot_j1_send_result:
    # ------------------------------------------------------------
    # Enviar:
    #
    #     DR,row,col,resultado\n
    #
    # t1 = fila
    # t2 = columna
    # a5 = F / I / H
    #
    # uart_putc solamente utiliza t0 internamente, por lo que
    # t1, t2 y a5 permanecen disponibles durante la respuesta.
    # ------------------------------------------------------------

    addi    a0, zero, 68         # 'D'
    jal     t6, uart_putc

    addi    a0, zero, 82         # 'R'
    jal     t6, uart_putc

    addi    a0, zero, 44         # ','
    jal     t6, uart_putc

    addi    a0, t1, 48           # row -> ASCII
    jal     t6, uart_putc

    addi    a0, zero, 44         # ','
    jal     t6, uart_putc

    addi    a0, t2, 48           # col -> ASCII
    jal     t6, uart_putc

    addi    a0, zero, 44         # ','
    jal     t6, uart_putc

    add     a0, a5, zero         # F / I / H
    jal     t6, uart_putc

    addi    a0, zero, 10         # LF
    jal     t6, uart_putc

    # ------------------------------------------------------------
    # Comprobar victoria de J1.
    #
    # Se recorren BOARD_J2 y SHOTS_J1. J1 gana cuando toda celda
    # perteneciente a un barco de J2 contiene CELL_HIT.
    # ------------------------------------------------------------
    jal     ra, check_win_j1
    bne     a0, zero, win_j1

    # Si aun no gano, pasa el turno al Jugador 2.
    addi    a0, zero, 2
    sw      a0, 4(s0)

    # Informar cambio de turno: T,2\n
    addi    a0, zero, 84        # T
    jal     t6, uart_putc

    addi    a0, zero, 44        # ,
    jal     t6, uart_putc

    addi    a0, zero, 50        # 2
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    jal     zero, main_loop


# ============================================================================
# check_win_j1
#
# Salida:
#   a0 = 1 -> todos los barcos de J2 fueron destruidos
#   a0 = 0 -> queda al menos una celda de barco sin impactar
#
# BOARD_J2 = s0 + 512
# SHOTS_J1 = s0 + 768
# ============================================================================
check_win_j1:
    addi    a1, zero, 0

check_win_j1_loop:
    addi    a2, zero, 64
    bge     a1, a2, check_win_j1_yes

    slli    a2, a1, 2

    # BOARD_J2[index]
    addi    a3, s0, 512
    add     a3, a3, a2
    lw      a4, 0(a3)

    # Agua: no importa.
    beq     a4, zero, check_win_j1_next

    # Celda de barco: debe estar impactada.
    addi    a3, s0, 768
    add     a3, a3, a2
    lw      a4, 0(a3)

    addi    a3, zero, CELL_HIT
    bne     a4, a3, check_win_j1_no

check_win_j1_next:
    addi    a1, a1, 1
    jal     zero, check_win_j1_loop

check_win_j1_no:
    addi    a0, zero, 0
    jalr    zero, 0(ra)

check_win_j1_yes:
    addi    a0, zero, 1
    jalr    zero, 0(ra)


# ============================================================================
# win_j1
#
# Finaliza la partida, incrementa WINS_J1 y envia:
#
#     FIN,1\n
# ============================================================================
win_j1:
    # STATE_FINISHED
    addi    a0, zero, STATE_FINISHED
    sw      a0, 0(s0)

    # Incrementar WINS_J1.
    lw      a0, 32(s0)
    addi    a0, a0, 1
    sw      a0, 32(s0)

    # Actualizar marcador de victorias en display.
    jal     t6, update_display

    # LED de partida terminada.
    addi    a0, zero, LED_FINISHED
    sw      a0, 0x138(s1)

    # FIN,1\n
    addi    a0, zero, 70        # F
    jal     t6, uart_putc

    addi    a0, zero, 73        # I
    jal     t6, uart_putc

    addi    a0, zero, 78        # N
    jal     t6, uart_putc

    addi    a0, zero, 44        # ,
    jal     t6, uart_putc

    addi    a0, zero, 49        # 1
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    # STATE_FINISHED queda esperando BTN_RST en main_loop.
    jal     zero, main_loop


# ============================================================================
# check_ship_sunk_j2
#
# Comprueba si un barco del Jugador 2 esta completamente hundido.
#
# Entrada:
#   a0 = valor almacenado en BOARD_J2 (1, 2 o 3)
#
# Salida:
#   a0 = 1 -> hundido
#   a0 = 0 -> aun quedan celdas sin impactar
#
# BOARD_J2  = s0 + 512
# SHOTS_J1  = s0 + 768
#
# No modifica BOARD_J2 ni SHOTS_J1.
# ============================================================================
check_ship_sunk_j2:
    add     a1, a0, zero        # identidad del barco
    addi    a2, zero, 0         # indice = 0

check_ship_sunk_j2_loop:
    addi    a3, zero, 64
    bge     a2, a3, check_ship_sunk_j2_yes

    # offset = indice * 4
    slli    a3, a2, 2

    # Leer BOARD_J2[indice].
    addi    a4, s0, 512
    add     a4, a4, a3
    lw      a5, 0(a4)

    # Si esta celda no pertenece al barco, continuar.
    bne     a5, a1, check_ship_sunk_j2_next

    # La celda pertenece al barco. Debe existir HIT en SHOTS_J1.
    addi    a4, s0, 768
    add     a4, a4, a3
    lw      a5, 0(a4)

    addi    a4, zero, CELL_HIT
    bne     a5, a4, check_ship_sunk_j2_no

check_ship_sunk_j2_next:
    addi    a2, a2, 1
    jal     zero, check_ship_sunk_j2_loop

check_ship_sunk_j2_no:
    addi    a0, zero, 0
    jalr    zero, 0(ra)

check_ship_sunk_j2_yes:
    addi    a0, zero, 1
    jalr    zero, 0(ra)


place_ship_j1:
    lw      t0, 20(s0)           # identificador de barco

    # La flota local ya esta completa.
    # Ignorar nuevos intentos de colocacion mientras se espera al J2.
    addi    t1, zero, 3
    bge     t0, t1, main_loop

    # Obtener longitud = 4 - CURRENT_SHIP.
    addi    t1, zero, 4
    sub     t1, t1, t0           # t1 = longitud

    lw      t2, 8(s0)            # fila
    lw      t3, 12(s0)           # columna
    lw      t4, 16(s0)           # 0=H, 1=V

    # ------------------------------------------------------------
    # Comprobar limites.
    # ------------------------------------------------------------

    bne     t4, zero, check_vertical_bounds

    # Horizontal: columna + longitud <= 8.
    add     t5, t3, t1
    addi    t6, zero, 8
    blt     t6, t5, invalid_placement
    jal     zero, check_overlap_setup

check_vertical_bounds:
    # Vertical: fila + longitud <= 8.
    add     t5, t2, t1
    addi    t6, zero, 8
    blt     t6, t5, invalid_placement

check_overlap_setup:
    # Dirección inicial:
    # BOARD_J1 + ((fila * 8 + columna) * 4)
    slli    t5, t2, 3
    add     t5, t5, t3
    slli    t5, t5, 2

    addi    t6, s0, 256
    add     t5, t6, t5           # t5 = puntero actual

    # Paso: H = 4 bytes, V = 32 bytes.
    beq     t4, zero, overlap_horizontal
    addi    t6, zero, 32
    jal     zero, overlap_loop_start

overlap_horizontal:
    addi    t6, zero, 4

overlap_loop_start:
    addi    a0, t1, 0            # contador

check_overlap_loop:
    lw      a1, 0(t5)
    bne     a1, zero, invalid_placement

    add     t5, t5, t6
    addi    a0, a0, -1
    bne     a0, zero, check_overlap_loop

    # ------------------------------------------------------------
    # Colocacion aceptada.
    # Reconstruir dirección inicial.
    # ------------------------------------------------------------

    slli    t5, t2, 3
    add     t5, t5, t3
    slli    t5, t5, 2

    addi    a1, s0, 256
    add     t5, a1, t5

    beq     t4, zero, place_horizontal
    addi    t6, zero, 32
    jal     zero, place_loop_setup

place_horizontal:
    addi    t6, zero, 4

place_loop_setup:
    addi    a0, t1, 0

    # BOARD_J1 conserva la identidad del barco:
    # 1 = barco 0, 2 = barco 1, 3 = barco 2.
    lw      a1, 20(s0)
    addi    a1, a1, 1

place_loop:
    sw      a1, 0(t5)

    # ------------------------------------------------------------
    # Escribir también la casilla correspondiente en VGA.
    #
    # Tablero J1 ocupa filas 0..7, columnas 0..7.
    # tile = fila*20 + columna
    # ------------------------------------------------------------

    # Obtener índice RAM de la casilla actual:
    # (puntero - BOARD_J1) / 4
    addi    a2, s0, 256
    sub     a3, t5, a2
    srli    a3, a3, 2

    # fila = indice >> 3
    srli    a4, a3, 3

    # columna = indice & 7
    andi    a5, a3, 7

    # tile = fila*20 + columna
    slli    a6, a4, 4            # fila*16
    slli    a7, a4, 2            # fila*4
    add     a6, a6, a7           # fila*20
    add     a6, a6, a5
    slli    a6, a6, 2            # byte offset VGA
    add     a6, s2, a6

    # VGA solo necesita saber que existe un barco.
    addi    a2, zero, CELL_SHIP
    sw      a2, 0(a6)

    add     t5, t5, t6
    addi    a0, a0, -1
    bne     a0, zero, place_loop

    # Un barco más colocado.
    lw      t0, 20(s0)
    addi    t0, t0, 1
    sw      t0, 20(s0)
    sw      t0, 24(s0)

    # Volver cursor/orientacion al origen para el siguiente.
    sw      zero, 8(s0)
    sw      zero, 12(s0)
    sw      zero, 16(s0)

    # Si ya colocó los tres barcos, esperar al jugador 2.
    addi    t1, zero, 3
    bge     t0, t1, placement_j1_complete

    jal     zero, main_loop

placement_j1_complete:
    # J1 ya completo su flota. Si J2 tambien habia terminado,
    # iniciar inmediatamente la batalla.
    lw      t0, 28(s0)          # PLACED_J2
    addi    t1, zero, 3
    bne     t0, t1, main_loop

    # GAME_STATE = STATE_BATTLE.
    addi    t0, zero, STATE_BATTLE
    sw      t0, 0(s0)

    # Jugador 1 inicia.
    addi    t0, zero, 1
    sw      t0, 4(s0)           # TURN = 1

    # LED de estado: batalla.
    addi    t0, zero, LED_BATTLE
    sw      t0, 0x138(s1)

    # Notificar inicio de batalla: B\n
    addi    a0, zero, 66        # B
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    # Notificar turno inicial: T,1\n
    addi    a0, zero, 84        # T
    jal     t6, uart_putc

    addi    a0, zero, 44        # ,
    jal     t6, uart_putc

    addi    a0, zero, 49        # 1
    jal     t6, uart_putc

    addi    a0, zero, 10        # LF
    jal     t6, uart_putc

    jal     zero, main_loop

invalid_placement:
    # tone_sel=011 (colocacion invalida), buzz_start=1.
    # 0b1011 = 0x0B.
    addi    t0, zero, 11
    sw      t0, 0x140(s1)

    jal     zero, main_loop

# ============================================================================
# init_game
# Inicializa una nueva partida.
# ============================================================================

# ============================================================================
# update_display
#
# Actualiza el display de 7 segmentos con el marcador de victorias.
#
# Formato BCD:
#
#     [15:12] [11:8] [7:4]    [3:0]
#        0       0    WINS_J1  WINS_J2
#
# Cada contador se muestra modulo 10 para garantizar un digito BCD valido.
# ============================================================================
update_display:
    # WINS_J1 mod 10.
    lw      t0, 32(s0)

update_display_j1_mod:
    addi    t2, zero, 10
    blt     t0, t2, update_display_j1_ready
    addi    t0, t0, -10
    jal     zero, update_display_j1_mod

update_display_j1_ready:
    # WINS_J2 mod 10.
    lw      t1, 36(s0)

update_display_j2_mod:
    addi    t2, zero, 10
    blt     t1, t2, update_display_j2_ready
    addi    t1, t1, -10
    jal     zero, update_display_j2_mod

update_display_j2_ready:
    # J1 ocupa el segundo nibble; J2 el primero.
    slli    t0, t0, 4
    or      t0, t0, t1

    # DISPLAY = 0x00010130 = s1 + 0x130.
    sw      t0, 0x130(s1)

    jalr    zero, 0(t6)


init_game:
    # Variables de estado.
    sw      zero, 0(s0)          # GAME_STATE = colocacion
    addi    t0, zero, 1
    sw      t0, 4(s0)            # TURN = J1
    sw      zero, 8(s0)          # CURSOR_ROW
    sw      zero, 12(s0)         # CURSOR_COL
    sw      zero, 16(s0)         # ORIENTATION = horizontal
    sw      zero, 20(s0)         # CURRENT_SHIP
    sw      zero, 24(s0)         # PLACED_J1
    sw      zero, 28(s0)         # PLACED_J2

    # Estado del parser UART: 0x2500--0x251C.
    addi    t0, s0, 1280
    sw      zero, 0(t0)          # UART_LAST_BYTE
    sw      zero, 4(t0)          # UART_PARSE_STATE
    sw      zero, 8(t0)          # UART_SHIP
    sw      zero, 12(t0)         # UART_ROW
    sw      zero, 16(t0)         # UART_COL
    sw      zero, 20(t0)         # UART_ORIENT
    sw      zero, 24(t0)         # UART_FRAME_READY
    sw      zero, 28(t0)         # J2_SHIP_MASK

    # BOARD_J1: 64 palabras.
    addi    t0, s0, 256
    addi    t1, zero, 64

clear_board_j1:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bne     t1, zero, clear_board_j1

    # BOARD_J2: 64 palabras.
    addi    t0, s0, 512
    addi    t1, zero, 64

clear_board_j2:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bne     t1, zero, clear_board_j2

    # SHOTS_J1: conocimiento del tablero rival.
    addi    t0, s0, 768
    addi    t1, zero, 64

clear_shots_j1:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bne     t1, zero, clear_shots_j1

    # SHOTS_J2: disparos realizados por J2 sobre J1.
    addi    t0, s0, 1024
    addi    t1, zero, 64

clear_shots_j2:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bne     t1, zero, clear_shots_j2

    # VGA: limpiar las 300 posiciones de la cuadricula 20x15.
    addi    t0, s2, 0
    addi    t1, zero, 300

clear_vga:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bne     t1, zero, clear_vga

    # Indicar fase de colocacion.
    addi    t0, zero, LED_PLACEMENT
    sw      t0, 0x138(s1)

    # Mostrar marcador actual. Los contadores de victorias no se
    # borran en init_game, por lo que BTN_RST conserva el marcador.
    jal     t6, update_display

    jalr    zero, 0(ra)
