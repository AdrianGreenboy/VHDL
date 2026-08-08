# -----------------------------------------------------------------------------
# Core 19 - PCS 64B/66B @ 25G - Restricciones CDC del core.
# Relojes reales del BD pcs_soc_bd (Vivado 2025.2.1, TE0950):
#   clk_pl_0          = pl0_ref_clk del CIPS (40 MHz) -> dominio AXI/CPU
#   clkout1_primitive = clk_wizard_0 (390.625 MHz)    -> dominio data plane
# Los FFs de sincronizacion llevan ASYNC_REG en el RTL (pcs_cdc, pcs_lsync,
# pcs_psync, soc_top_pcs). Aqui se presupuestan los cruces entre dominios.
# -----------------------------------------------------------------------------
set_max_delay -datapath_only -from [get_clocks clk_pl_0] -to [get_clocks clkout1_primitive] 2.560
set_max_delay -datapath_only -from [get_clocks clkout1_primitive] -to [get_clocks clk_pl_0] 25.000
