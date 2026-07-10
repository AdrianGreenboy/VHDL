# ============================================================================
#  eth_pins.xdc - Pines MII del MAC Ethernet (TE0950, banco 302 HDIO, LVCMOS33)
#
#  v1 en LOOP_INT: estos pines son INERTES (el mux interno realimenta TX->RX
#  en el PL; los pads no tienen efecto aguas abajo). Se restringen igualmente
#  para que la sintesis/implementacion no deje puertos sin ubicar (UCIO).
#
#  IMPORTANTE (leccion USART / pin inventado): VERIFICAR CADA PACKAGE_PIN
#  contra el banco real ANTES de sintetizar. En la consola Vivado:
#     get_package_pins -filter {BANK == 302}
#  El 1553 uso C10/D10/A10 de este banco. Segun el listado de aquella sesion
#  quedaban libres: E11 E12 D11 D12 C12 C13 C14 D14 E13 E14 F11 F13 F14
#  A11 B11 A13 B12 A14 B13 D13 B10. Aqui se asignan 10 de ellos (los 10 que
#  el wrapper expone en v1: TXD[3:0], TX_EN, RXD[3:0], RX_DV). Si alguno de
#  estos pines ya no estuviera libre, reasignar del listado y volver a
#  verificar con get_package_pins.
#
#  Los pines de gestion/reloj del PHY (TX_CLK, RX_CLK, CRS, COL, MDC, MDIO)
#  NO se exponen en v1 (LOOP_INT genera el reloj de 25 MHz internamente por
#  /4). Se anadiran en v1.1 con el PHY RGMII real.
# ============================================================================

# --- salidas MII TX ---
set_property PACKAGE_PIN E11 [get_ports {mii_txd[0]}]
set_property PACKAGE_PIN E12 [get_ports {mii_txd[1]}]
set_property PACKAGE_PIN D11 [get_ports {mii_txd[2]}]
set_property PACKAGE_PIN D12 [get_ports {mii_txd[3]}]
set_property PACKAGE_PIN C12 [get_ports mii_tx_en]

# --- entradas MII RX (inertes en LOOP_INT) ---
set_property PACKAGE_PIN C13 [get_ports {mii_rxd[0]}]
set_property PACKAGE_PIN C14 [get_ports {mii_rxd[1]}]
set_property PACKAGE_PIN D14 [get_ports {mii_rxd[2]}]
set_property PACKAGE_PIN E13 [get_ports {mii_rxd[3]}]
set_property PACKAGE_PIN E14 [get_ports mii_rx_dv]

# --- estandar de E/S para todo el banco 302 (HDIO, 3.3V) ---
set_property IOSTANDARD LVCMOS33 [get_ports {mii_txd[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports mii_tx_en]
set_property IOSTANDARD LVCMOS33 [get_ports {mii_rxd[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports mii_rx_dv]
