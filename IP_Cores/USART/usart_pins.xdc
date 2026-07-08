# ============================================================================
#  usart_pins.xdc  -  Pads USART en el CRUVI LS1 del TE0950 (banco 302, HDIO)
#  Licencia: MIT
#
#  Mapeo DELIBERADO sobre los mismos pines fisicos del SPI para reutilizar el
#  adaptador CR00025 y el mismo jumper:
#     TXD   = D10  (era MOSI)   --+-- jumper D10 -> C10 = loopback externo
#     RXD   = C10  (era MISO)   --+   (identico al MOSI->MISO del SPI)
#     RTS_n = A10  (era CS_n)   --+-- jumper A10 -> D11 = prueba de flow
#     CTS_n = D11  (era SCLK)   --+   control externo (RTS -> CTS)
#
#  PULLUP en TXD: obligatorio para half duplex / RS-485 (la linea queda en
#  Hi-Z entre frames). PULLUP en RXD: una entrada flotante se lee '1' (idle)
#  en vez de basura. PULLDOWN en CTS_n: permisivo si nadie lo conecta.
# ============================================================================

set_property PACKAGE_PIN D10 [get_ports usart_txd]
set_property PACKAGE_PIN C10 [get_ports usart_rxd]
set_property PACKAGE_PIN A10 [get_ports usart_rts_n]
set_property PACKAGE_PIN D11 [get_ports usart_cts_n]

set_property IOSTANDARD LVCMOS33 [get_ports usart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports usart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports usart_rts_n]
set_property IOSTANDARD LVCMOS33 [get_ports usart_cts_n]

set_property PULLTYPE PULLUP   [get_ports usart_txd]
set_property PULLTYPE PULLUP   [get_ports usart_rxd]
set_property PULLTYPE PULLDOWN [get_ports usart_cts_n]

# Los pads son asincronos por naturaleza (2FF en el IP); sin requisitos de
# timing hacia/desde ellos.
set_false_path -to   [get_ports usart_txd]
set_false_path -to   [get_ports usart_rts_n]
set_false_path -from [get_ports usart_rxd]
set_false_path -from [get_ports usart_cts_n]
set_false_path -from [get_ports usart_txd]
