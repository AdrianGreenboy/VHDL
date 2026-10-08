#==============================================================================
# HERCOSSNUX Core 20 - MAC 25G - construccion completa hasta PDI y XSA.
# Vivado 2025.2.1, Trenz TE0950 (xcve2302-sfva784-1LP-e-S).
#
# Batch:   cd IP_Cores/MAC_25G && vivado -mode batch -source vivado/build_mac_soc.tcl
# Consola: ejecutar las secciones de una en una, leyendo la respuesta de cada
#          una antes de seguir (regla del Core 19). Antes: bash gen_mac_bd_tcl.sh
#
# Fuentes: SOLO del repo (IP_Cores/RV32i, PCS_25G/rtl, MAC_25G/rtl). El
# mem_subsys_dma es el del repo, sin la ventana AXI-Lite del PTP.
#==============================================================================

# --- 0. rutas (nunca '~': no se expande en el Tcl de Vivado) ----------------
set HERE [file normalize [file dirname [info script]]]
set CORE [file normalize $HERE/..]
set IPC  [file normalize $CORE/..]
set PROJ $HERE/mac_soc
puts "CORE = $CORE"

# --- 1. proyecto -------------------------------------------------------------
create_project mac_soc $PROJ -part xcve2302-sfva784-1LP-e-S -force
set_property BOARD_PART trenz.biz:te0950_23_1lse:part0:1.2 [current_project]
set_property target_language VHDL [current_project]

# --- 2. fuentes ----------------------------------------------------------------
set RV $IPC/RV32i
set PCS $IPC/PCS_25G/rtl
set MAC $CORE/rtl
set SRCS [list \
  $RV/riscv_pkg.vhd $RV/alu.vhd $RV/immgen.vhd $RV/regfile.vhd $RV/control.vhd \
  $RV/muldiv.vhd $RV/csr.vhd $RV/clint.vhd $RV/cpu_pipeline.vhd $RV/dp_ram.vhd \
  $RV/axi4_master.vhd $RV/dma_burst.vhd $RV/mem_subsys_dma.vhd $RV/axil_soc.vhd \
  $PCS/pcs_scrambler.vhd $PCS/pcs_gearbox_tx.vhd $PCS/pcs_gearbox_rx.vhd \
  $PCS/pcs_rx_datapath.vhd $PCS/pcs_mmio_bridge.vhd \
  $MAC/mac25g_pkg.vhd $MAC/mac25g_sync.vhd $MAC/mac25g_pcs_tx.vhd \
  $MAC/mac25g_gen.vhd $MAC/mac25g_tx.vhd $MAC/mac25g_rx.vhd $MAC/mac25g_chk.vhd \
  $MAC/mac25g_datapath.vhd $MAC/mac25g_top.vhd $MAC/soc_top_mac.vhd]
add_files -norecurse $SRCS
set_property FILE_TYPE {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
add_files -norecurse $MAC/soc_top_mac_wrap.v
add_files -fileset constrs_1 -norecurse $HERE/mac25g_cdc.xdc
update_compile_order -fileset sources_1

# --- 3. Block Design (trasplante del Core 19, CIPS/NoC intactos) -------------
source $HERE/mac_soc_bd.tcl

# --- 4. reloj del datapath: 390.625 MHz desde pl0_ref_clk (como el Core 19) --
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard clk_wizard_0
set_property -dict [list CONFIG.CLKOUT_USED {true} \
  CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {390.625} CONFIG.USE_LOCKED {true}] \
  [get_bd_cells clk_wizard_0]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins clk_wizard_0/clk_in1]
connect_bd_net [get_bd_pins clk_wizard_0/clk_out1] [get_bd_pins soc_mac_0/clk_dp]
connect_bd_net [get_bd_pins clk_wizard_0/locked]   [get_bd_pins soc_mac_0/dp_locked]
validate_bd_design
save_bd_design

# --- 5. wrapper del BD como top ----------------------------------------------
set BD [get_files mac_soc_bd.bd]
make_wrapper -files $BD -top
set WRAP [glob -nocomplain $PROJ/mac_soc.gen/sources_1/bd/mac_soc_bd/hdl/mac_soc_bd_wrapper.*]
if {[llength $WRAP] != 1} { error "wrapper del BD no encontrado: $WRAP" }
add_files -norecurse $WRAP
set_property top mac_soc_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

# --- 6. estrategia de implementacion (la que cerro el Core 19) ---------------
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]

# --- 7. sintesis + implementacion + PDI --------------------------------------
launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1

# --- 8. informes y artefactos -------------------------------------------------
open_run impl_1
report_timing_summary -max_paths 20 -file $HERE/timing_summary.txt
report_cdc -details -file $HERE/cdc_report.txt
report_utilization -hierarchical -hierarchical_depth 4 -file $HERE/utilization.txt
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "== WNS = $wns ns   WHS = $whs ns =="
file mkdir $CORE/petalinux
foreach pdi [glob -nocomplain $PROJ/mac_soc.runs/impl_1/*.pdi] {
  file copy -force $pdi $HERE/mac_soc.pdi
}
write_hw_platform -fixed -include_bit -force $CORE/petalinux/mac_soc.xsa
puts "== PDI: $HERE/mac_soc.pdi   XSA: $CORE/petalinux/mac_soc.xsa =="
