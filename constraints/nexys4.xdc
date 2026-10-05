## ============================================================
## Nexys 4 Rev. B - Constraints del Proyecto 3
## Bloque VGA
## ============================================================

## Reloj principal de la FPGA: 100 MHz
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk_i}]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports {clk_i}]

## VGA - Rojo
set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports {r_o[0]}]
set_property -dict { PACKAGE_PIN B4 IOSTANDARD LVCMOS33 } [get_ports {r_o[1]}]
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS33 } [get_ports {r_o[2]}]
set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports {r_o[3]}]

## VGA - Verde
set_property -dict { PACKAGE_PIN C6 IOSTANDARD LVCMOS33 } [get_ports {g_o[0]}]
set_property -dict { PACKAGE_PIN A5 IOSTANDARD LVCMOS33 } [get_ports {g_o[1]}]
set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports {g_o[2]}]
set_property -dict { PACKAGE_PIN A6 IOSTANDARD LVCMOS33 } [get_ports {g_o[3]}]

## VGA - Azul
set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports {b_o[0]}]
set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS33 } [get_ports {b_o[1]}]
set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports {b_o[2]}]
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports {b_o[3]}]

## VGA - Sincronización
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports {hsync_o}]
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports {vsync_o}]

## ============================================================
## Bloque Periféricos locales (top synthesis: perifericos_locales)
## ============================================================

## Boton CPU RESET (rojo). ACTIVO EN BAJO: vale 1 en reposo y 0 al presionar.
## Se conecta a rst_ni; el RTL lo invierte internamente.
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports {rst_ni}]

## Botones del Jugador 1
## btn_raw_i[0]=arriba [1]=abajo [2]=izquierda [3]=derecha [4]=SEL [5]=OK [6]=RST(juego)
## Los 5 pulsadores en cruz son activos en alto (0 en reposo, 1 al presionar).
## Solo hay 5 pulsadores libres (el sexto es CPU RESET), asi que SEL y RST del
## juego se asignan a switches.
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[0]}] ;# BTNU - arriba
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[1]}] ;# BTND - abajo
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[2]}] ;# BTNL - izquierda
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[3]}] ;# BTNR - derecha
set_property -dict { PACKAGE_PIN U9  IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[4]}] ;# SW0 - SEL
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[5]}] ;# BTNC - OK
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports {btn_raw_i[6]}] ;# SW1 - RST del juego (software)

## Display de 7 segmentos (seg_o y anode_o activos en bajo, como exige la placa)
set_property -dict { PACKAGE_PIN L3 IOSTANDARD LVCMOS33 } [get_ports {seg_o[0]}] ;# CA
set_property -dict { PACKAGE_PIN N1 IOSTANDARD LVCMOS33 } [get_ports {seg_o[1]}] ;# CB
set_property -dict { PACKAGE_PIN L5 IOSTANDARD LVCMOS33 } [get_ports {seg_o[2]}] ;# CC
set_property -dict { PACKAGE_PIN L4 IOSTANDARD LVCMOS33 } [get_ports {seg_o[3]}] ;# CD
set_property -dict { PACKAGE_PIN K3 IOSTANDARD LVCMOS33 } [get_ports {seg_o[4]}] ;# CE
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS33 } [get_ports {seg_o[5]}] ;# CF
set_property -dict { PACKAGE_PIN L6 IOSTANDARD LVCMOS33 } [get_ports {seg_o[6]}] ;# CG

## Solo usamos 4 de los 8 anodos disponibles (4 digitos: AN0-AN3)
set_property -dict { PACKAGE_PIN N6 IOSTANDARD LVCMOS33 } [get_ports {anode_o[0]}] ;# AN0
set_property -dict { PACKAGE_PIN M6 IOSTANDARD LVCMOS33 } [get_ports {anode_o[1]}] ;# AN1
set_property -dict { PACKAGE_PIN M3 IOSTANDARD LVCMOS33 } [get_ports {anode_o[2]}] ;# AN2
set_property -dict { PACKAGE_PIN N5 IOSTANDARD LVCMOS33 } [get_ports {anode_o[3]}] ;# AN3

## LED de estado (3 bits, usamos LED0-LED2; activos en alto)
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS33 } [get_ports {led_o[0]}]
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 } [get_ports {led_o[1]}]
set_property -dict { PACKAGE_PIN R8 IOSTANDARD LVCMOS33 } [get_ports {led_o[2]}]

## Buzzer: se usa el pin 1 del PMOD JA (B13)
set_property -dict { PACKAGE_PIN B13 IOSTANDARD LVCMOS33 } [get_ports {buzz_pwm_o}] ;# JA1