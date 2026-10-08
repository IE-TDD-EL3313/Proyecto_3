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

## Display de 8 digitos: AN7-AN4 apagados, AN3-AN0 para marcador
set_property -dict { PACKAGE_PIN N6 IOSTANDARD LVCMOS33 } [get_ports {anode_o[0]}] ;# AN0 - unidades J2
set_property -dict { PACKAGE_PIN M6 IOSTANDARD LVCMOS33 } [get_ports {anode_o[1]}] ;# AN1 - decenas J2
set_property -dict { PACKAGE_PIN M3 IOSTANDARD LVCMOS33 } [get_ports {anode_o[2]}] ;# AN2 - unidades J1
set_property -dict { PACKAGE_PIN N5 IOSTANDARD LVCMOS33 } [get_ports {anode_o[3]}] ;# AN3 - decenas J1
set_property -dict { PACKAGE_PIN N2 IOSTANDARD LVCMOS33 } [get_ports {anode_o[4]}] ;# AN4 - apagado
set_property -dict { PACKAGE_PIN N4 IOSTANDARD LVCMOS33 } [get_ports {anode_o[5]}] ;# AN5 - apagado
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports {anode_o[6]}] ;# AN6 - apagado
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS33 } [get_ports {anode_o[7]}] ;# AN7 - apagado

## LED de estado (3 bits, usamos LED0-LED2; activos en alto)
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS33 } [get_ports {led_o[0]}]
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 } [get_ports {led_o[1]}]
set_property -dict { PACKAGE_PIN R8 IOSTANDARD LVCMOS33 } [get_ports {led_o[2]}]

## Buzzer: se usa el pin 1 del PMOD JA (B13)
set_property -dict { PACKAGE_PIN B13 IOSTANDARD LVCMOS33 } [get_ports {buzz_pwm_o}] ;# JA1
## ============================================================
## UART USB - Jugador 2 (PC)
## Nexys 4 Rev. B, interfaz USB-RS232 integrada
## ============================================================

## PC -> FPGA
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports {uart_rx_i}]

## FPGA -> PC
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports {uart_tx_o}]

# ============================================================
# CPU RV32I - Multicycle por clock-enable
# cpu_ce permite commit una vez cada 4 ciclos de clk_i (100 MHz)
# Solo aplica al estado interno PC/Register File del CPU.
# ============================================================

set cpu_pc_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_processor/core/u_pc_register/PC_reg*
}]

set cpu_rf_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_processor/core/u_register_file/registers_reg*
}]

# PC -> PC
set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_pc_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_pc_regs

# PC -> Register File
set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_rf_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_rf_regs

# Register File -> PC
set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_pc_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_pc_regs

# Register File -> Register File
set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_rf_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_rf_regs

# ============================================================
# CPU RV32I - Multicycle hacia destinos de escritura
#
# El CPU realiza commit una vez cada 4 ciclos mediante cpu_ce.
# Las escrituras RAM/MMIO originadas por el estado del CPU
# disponen por tanto de 4 ciclos.
#
# Los caminos internos de los perifericos NO se relajan.
# ============================================================

set cpu_ram_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_processor/ram/*
}]

set cpu_buzzer_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_locales/u_buzzer_gen/*
}]

set cpu_display_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_locales/u_seg7_ctrl/disp_data_reg*
}]

set cpu_led_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_locales/u_led_reg/led_o_reg*
}]

set cpu_vga_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_vga/u_memory/mem_reg*
}]

set cpu_vga_cursor_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *vga_cursor_ctrl_reg*
}]

set cpu_uart_write_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    (
        NAME =~ *u_uart/tx_data_r_reg* ||
        NAME =~ *u_uart/tx_start_reg ||
        NAME =~ *u_uart/rx_pending_r_reg ||
        NAME =~ *u_uart/rx_frame_error_r_reg*
    )
}]

# PC -> destinos de escritura

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_ram_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_ram_regs

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_buzzer_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_buzzer_regs

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_display_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_display_regs

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_led_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_led_regs

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_vga_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_vga_regs

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_vga_cursor_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_vga_cursor_regs

set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_uart_write_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_uart_write_regs

# Register File -> destinos de escritura

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_ram_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_ram_regs

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_buzzer_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_buzzer_regs

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_display_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_display_regs

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_led_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_led_regs

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_vga_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_vga_regs

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_vga_cursor_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_vga_cursor_regs

set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_uart_write_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_uart_write_regs


# ============================================================
# CPU RV32I -> registro sticky de botones
#
# btn_status se limpia mediante input_ack_i, generado cuando el
# CPU consume INPUT durante cpu_ce. Por ello, este camino forma
# parte de la operacion multicycle de 4 ciclos del CPU.
# ============================================================

set cpu_button_status_regs [get_cells -hier -filter {
    IS_SEQUENTIAL == 1 &&
    NAME =~ *u_locales/u_btn_input/btn_status_reg*
}]

# PC -> btn_status
set_multicycle_path -setup 4 -from $cpu_pc_regs -to $cpu_button_status_regs
set_multicycle_path -hold  3 -from $cpu_pc_regs -to $cpu_button_status_regs

# Register File -> btn_status
set_multicycle_path -setup 4 -from $cpu_rf_regs -to $cpu_button_status_regs
set_multicycle_path -hold  3 -from $cpu_rf_regs -to $cpu_button_status_regs

## Punto decimal del display (activo en bajo)
set_property -dict { PACKAGE_PIN M4 IOSTANDARD LVCMOS33 } [get_ports {dp_o}] ;# DP apagado
