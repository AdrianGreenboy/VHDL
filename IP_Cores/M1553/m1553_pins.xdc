# ============================================================================
#  m1553_pins.xdc - Pines del IP MIL-STD-1553B en el TE0950 (xcve2302)
#  Licencia: MIT
#
#  El 1553 v1 usa 3 senales single-ended (bus unico logico). Para el PASS de
#  silicio el criterio es 100% LOOP_INT: el IP gatea bus_txen_o a 0 hacia
#  fuera, asi que estos pines son inocuos durante el bring-up (no hay
#  transceptor conectado). Se restringen igual para cerrar place/route sin
#  DRC de IO sin ubicar.
#
#  Pines: CRUVI LS1, banco 302 HDIO, LVCMOS33 (mismo header que el CAN).
#    m1553_rx   <- C10  (entrada; heredada del "can_rx" documentado del CAN)
#    m1553_tx   -> D10  (salida; el pad del CAN, el mas accesible del header)
#    m1553_txen -> A10  (salida; enable del transceptor; C_LS1_SEL del CRUVI
#                        LS1. Audit 2026-11: el comentario decia E10 pero la
#                        restriccion siempre fue A10)
#
#  ------------------------------------------------------------------------
#  PREGUNTA ABIERTA (no bloqueante para el PASS en LOOP_INT):
#  ------------------------------------------------------------------------
#  El bus 1553 EXTERNO real es bidireccional por transformador y NO se conduce
#  directo desde el FPGA. Topologia v1.1 con transceptor HI-1573 (o similar):
#    - m1553_tx   -> entrada de datos del driver del transceptor
#    - m1553_txen -> habilitacion del driver (TX_INH / _EN del HI-1573)
#    - m1553_rx   <- salida del receptor del transceptor
#  y del transceptor al bus por el transformador de aislamiento + estator.
#  Verificar en el esquematico de la TE0950 que C10/D10/E10 salen a pines
#  accesibles del CRUVI LS1; si alguno choca con el uso del IIC/I3C/CAN en un
#  mismo montaje, reubicar a otros 3 pines libres del banco 302.
#  Para el PASS de esta entrega basta LOOP_INT: pads liberados.
#  ------------------------------------------------------------------------

set_property PACKAGE_PIN C10 [get_ports m1553_rx]
set_property PACKAGE_PIN D10 [get_ports m1553_tx]
set_property PACKAGE_PIN A10 [get_ports m1553_txen]

set_property IOSTANDARD LVCMOS33 [get_ports {m1553_rx m1553_tx m1553_txen}]
set_property SLEW FAST [get_ports {m1553_tx m1553_txen}]

# el bus en reposo del 1553 es silencio (0 V diferencial); pull-down suave en
# la entrada para un estado definido sin transceptor durante el bring-up
set_property PULLDOWN true [get_ports m1553_rx]

# ---------------------------------------------------------------------------
#  Bus B (dual-redundant, audit 2026-11). In the LOOP_INT bring-up the BD
#  ties m1553_rx_b low and leaves the bus-B outputs unconnected, so no pads
#  are needed. The CRUVI LS1 pins known from the other cores (A10/C10/D10/
#  D11) are not enough for 6 signals: assign bus-B pins from the transceiver
#  board schematic and uncomment.
# ---------------------------------------------------------------------------
# set_property PACKAGE_PIN <pin> [get_ports m1553_rx_b]
# set_property PACKAGE_PIN <pin> [get_ports m1553_tx_b]
# set_property PACKAGE_PIN <pin> [get_ports m1553_txen_b]
# set_property IOSTANDARD LVCMOS33 [get_ports {m1553_rx_b m1553_tx_b m1553_txen_b}]
# set_property PULLDOWN true [get_ports m1553_rx_b]
