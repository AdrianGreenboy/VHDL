# ============================================================================
#  i2c_pins.xdc - Pines del IP IIC en el TE0950 (xcve2302)
#
#  Herencia deliberada de los pines del USART/SPI: CRUVI LS1, banco 302 HDIO,
#  LVCMOS33. SCL toma el pad de TXD (D10) y SDA el de RXD (C10). PULLUP
#  interno en ambos para el bring-up con loop_int a 100 kHz sin pull-ups
#  externos; para bus externo real a 400k/1M se recomiendan pull-ups fisicos
#  (2.2k-4.7k) en el adaptador CR00025.
# ============================================================================

set_property PACKAGE_PIN D10 [get_ports scl]
set_property PACKAGE_PIN C10 [get_ports sda]

set_property IOSTANDARD LVCMOS33 [get_ports {scl sda}]
set_property PULLUP true [get_ports {scl sda}]
