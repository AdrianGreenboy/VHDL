# ============================================================================
#  can_pins.xdc - Pines del IP CAN en el TE0950 (xcve2302)
#
#  Un solo pad logico (can_bus) en el CRUVI LS1, banco 302 HDIO, LVCMOS33.
#  Hereda el pad D10 del SCL del IIC/I3C (el mas accesible del header). PULLUP
#  interno: en CAN el bus recesivo es el estado en reposo, y el pull-up del
#  HDIO lo sostiene durante el bring-up en LOOP_INT sin hardware externo.
#
#  ------------------------------------------------------------------------
#  PREGUNTA ABIERTA (no bloqueante para el PASS en LOOP_INT):
#  ------------------------------------------------------------------------
#  Para un bus CAN EXTERNO real hace falta un transceptor (el FPGA no conduce
#  el par diferencial CAN_H/CAN_L). El candidato es el SN65HVD230 (3.3 V,
#  1 Mbit/s, modo standby). En esa topologia:
#    - can_bus NO va al par CAN_H/CAN_L: va al pin TXD del transceptor.
#    - el RXD del transceptor necesita un SEGUNDO pad de vuelta al FPGA.
#  Es decir, el bus externo pide DOS pines (TXD hacia el transceptor, RXD de
#  vuelta), mientras que este XDC declara UNO solo porque el bring-up de
#  silicio corre en LOOP_INT con los pads liberados (can_tx_t='1' siempre).
#
#  Si se decide el bus externo:
#    - anadir un pin C10 para can_rx (RXD del SN65HVD230),
#    - separar el IOBUF del wrapper en OBUF (D10->TXD) + IBUF (C10<-RXD),
#    - exponer can_tx_o/can_tx_t y can_rx_i por separado al BD,
#    - alimentar el SN65HVD230 a 3.3 V y su Rs (pin 8) a GND para velocidad
#      plena (o via resistencia para slew controlado).
#  Para el PASS de esta entrega basta LOOP_INT: un solo pad, pads liberados.
#  ------------------------------------------------------------------------

set_property PACKAGE_PIN D10 [get_ports can_bus]

set_property IOSTANDARD LVCMOS33 [get_ports can_bus]
set_property PULLUP true [get_ports can_bus]
set_property SLEW FAST [get_ports can_bus]

# --- lineas para el modo transceptor externo (comentadas: ver arriba) ---
# set_property PACKAGE_PIN C10 [get_ports can_rx]
# set_property IOSTANDARD LVCMOS33 [get_ports {can_bus can_rx}]
# set_property SLEW FAST [get_ports {can_bus can_rx}]
