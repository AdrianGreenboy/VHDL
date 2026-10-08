# -----------------------------------------------------------------------------
# HERCOSSNUX Core 20 - MAC 25G - restricciones de cruce de reloj.
# Relojes del BD mac_soc_bd (Vivado 2025.2.1, TE0950), mismos que el Core 19:
#   clk_pl_0          = pl0_ref_clk del CIPS (40 MHz)  -> AXI / RV32 / banco
#   clkout1_primitive = clk_wizard_0 (390.625 MHz)     -> datapath del MAC
#
# Todos los cruces del core son de uno de estos tipos (ver rtl/mac25g_top.vhd):
#   * bits sueltos con doble FF ASYNC_REG (mac25g_lsync / psync / evsync)
#   * datos multi-bit ESTABLES muestreados tras un handshake:
#       AXI -> dp : r_ctrl, r_cmd, r_mac_*, r_src_*, r_lmin/lmax/lstep, r_count
#                   (escritos antes del CMD, capturados con d_cmd_stb)
#       dp -> AXI : shadow (instantanea de contadores, congelada hasta el
#                   siguiente SNAP; el software la lee tras SNAP_DONE)
# Basta con acotar el retardo de datos a un periodo del reloj destino, igual
# que en el Core 19.
# -----------------------------------------------------------------------------
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks clkout1_primitive] 2.560
set_max_delay -datapath_only -from [get_clocks clkout1_primitive] -to [get_clocks clk_pl_0] 25.000
