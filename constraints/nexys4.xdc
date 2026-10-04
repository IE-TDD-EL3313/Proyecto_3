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
