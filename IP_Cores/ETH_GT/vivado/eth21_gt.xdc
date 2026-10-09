# -----------------------------------------------------------------------------
# HERCOSSNUX Core 21 - ETH GT - restricciones (TE0950 REV03, xcve2302)
#
# zQSFP J1/U12 -> banco GTYP 104 = GTYP_QUAD_X0Y1 (esquematico TE0950-03,
# paginas 12 y 24): lane 0 del QSFP = canal 0 del banco 104
#   TX0 E5/E4, RX0 F2/F1 (sin inversiones de polaridad en la placa)
# Refclk: U6 SiT9365 156.25 MHz LVDS -> GTYP_REFCLKP0/N0_104 (H7/H6)
#   = GTYP_REFCLK_X0Y2 (acoplado en AC en la placa)
# En Versal los lanes NO se fijan por PACKAGE_PIN: se fija el quad (LOC) y el
# buffer del refclk (LOC); el canal sale del orden de lanes del gt_quad_base.
# -----------------------------------------------------------------------------
set_property LOC GTYP_QUAD_X0Y1 [get_cells -hierarchical -filter {REF_NAME =~ GTYP_QUAD*}]
set_property LOC GTYP_REFCLK_X0Y2 [get_cells -hierarchical -filter {REF_NAME =~ IBUFDS_GTE*}]
create_clock -name gt_refclk -period 6.400 [get_ports gt_refclk_clk_p]

# -----------------------------------------------------------------------------
# Cruces de reloj (ver rtl/eth21_top.vhd):
#   clk_pl_0 (40 MHz, AXI + FSM de reset)  <->  TXUSRCLK / RXUSRCLK del GT
#   * bits sueltos: doble FF ASYNC_REG (mac25g_lsync/psync/evsync, gt_rst,
#     clkmeter, reset de dominio)
#   * multibit ESTABLES tras handshake: configuracion (r_*) -> t_*/x_*,
#     sombras de contadores (t_shadow/x_shadow) -> rdata
# Los datos se capturan al menos 3 ciclos del destino despues del toggle:
# basta con acotar el retardo a 2 periodos de 25G (5.12 ns).
# TX y RX del GT no tienen caminos entre si (RXUSRCLK sale del reloj
# recuperado): grupos asincronos.
# -----------------------------------------------------------------------------
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */eth21_0/tx_usrclk}]] 5.120
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */eth21_0/rx_usrclk}]] 5.120
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */eth21_0/tx_usrclk}]] -to [get_clocks clk_pl_0] 25.000
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */eth21_0/rx_usrclk}]] -to [get_clocks clk_pl_0] 25.000
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */eth21_0/tx_usrclk}]] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */eth21_0/rx_usrclk}]]
