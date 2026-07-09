# ============================================================================
#  i3c_pins.xdc - Pines del IP I3C en el TE0950 (xcve2302)
#
#  Herencia deliberada de los pines del IIC/USART/SPI: CRUVI LS1, banco 302
#  HDIO, LVCMOS33. SCL toma el pad D10 y SDA el C10. PULLUP interno en ambos:
#  en I3C hace de high-keeper para los handoffs (bit T, ACK) y sostiene las
#  fases open-drain del bring-up con loop_int sin hardware externo.
#
#  Para bus I3C EXTERNO real: el spec pide pull-up/keeper debil en SDA; el
#  PULLUP interno del HDIO sirve para validacion, pero a 12.5 MHz con carga
#  real conviene el keeper del adaptador (CR00025) y trazas cortas. SLEW FAST
#  en ambos pads para los flancos push-pull.
# ============================================================================

set_property PACKAGE_PIN D10 [get_ports scl]
set_property PACKAGE_PIN C10 [get_ports sda]

set_property IOSTANDARD LVCMOS33 [get_ports {scl sda}]
set_property PULLUP true [get_ports {scl sda}]
set_property SLEW FAST [get_ports {scl sda}]
