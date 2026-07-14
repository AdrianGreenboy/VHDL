# ============================================================================
#  tsn_soc_steps.tcl - Trasplante del BD del SoC + switch TSN 4x4 (TE0950 /
#  Versal xcve2302-sfva784-1LP-e-S). Adaptado del ptp_soc_steps.tcl probado.
#
#  NO SE "SOURCEA" COMPLETO: comandos UNO POR UNO en la consola Tcl de Vivado,
#  leyendo cada respuesta (leccion de la familia: connect_bd_net fallo
#  SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto ETH (hereda el BD con CIPS, NoC, axi_smc, reset y
#  address map auditados) y sustituir el module reference u_soc_eth por
#  u_soc_tsn.
#
#  El TSN es ESCLAVO DMEM DIRECTO, integrado en mem_subsys_dma en 0x6000_0000
#  (bus dmem interno del RV32, NO se mapea en el BD). NO hay *_axil ni maestro
#  embebido. rx_src="10" (inyector) interno => NO se exponen pines MII a pads.
#
#  IMPORTANTE: las fuentes mem_subsys_dma / soc_top_master / wrapper son las
#  COPIAS LOCALES del IP TSN (con el tsn_soc dentro y podadas del PTP), NO las
#  de ~/rv32i (que llevan el PTP+DSP y romperian la sintesis). Validadas en
#  GHDL: la cadena RTL local cierra sin residuos.
#
#  Los eth_*.vhd se referencian desde el IP ETH canonico (no se versionan
#  copiados en TSN: .gitignore).
# ============================================================================

# ---------- 0) clonar el proyecto del ETH ----------
open_project $env(HOME)/eth_ip/vivado_eth/eth_soc.xpr
save_project_as tsn_soc $env(HOME)/vhdl_repo/IP_Cores/TSN/vivado_tsn -force
set_property source_mgmt_mode All [current_project]

reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/vhdl_repo/IP_Cores/TSN/vivado_tsn/tsn_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre:
foreach f [get_files -all *] { if {[string match *eth_ip/vivado_eth* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del ETH ----------
open_bd_design [get_files bd_soc_usart.bd]
get_bd_cells
get_bd_intf_pins u_soc_eth/*
get_bd_nets -of_objects [get_bd_pins u_soc_eth/*]
get_bd_ports
delete_bd_objs [get_bd_cells u_soc_eth]
generate_target all [get_files bd_soc_usart.bd]

# ---------- 1b) borrar los puertos MII externos del ETH (el TSN no expone) ----
catch {delete_bd_objs [get_bd_ports mii_txd]}
catch {delete_bd_objs [get_bd_ports mii_tx_en]}
catch {delete_bd_objs [get_bd_ports mii_rxd]}
catch {delete_bd_objs [get_bd_ports mii_rx_dv]}

# ---------- 2) sustituir fuentes ETH -> TSN ----------
remove_files [get_files -quiet {*eth_mmio.vhd *mem_subsys_eth.vhd \
  *soc_top_eth.vhd *soc_top_eth_wrap.v}]
# CLAVE: si el proyecto ETH clonado trae su propio mem_subsys_dma/soc_top_master
# de ~/rv32i, QUITARLOS para que no colisionen con las copias locales del TSN.
remove_files [get_files -quiet {*rv32i/mem_subsys_dma.vhd *rv32i/soc_top_master.vhd \
  *rv32i/soc_top_master_wrap.v}]

# anadir el RTL del TSN + core + wrapper. Orden de dependencia validado en GHDL.
# mem_subsys_dma, soc_top_master y el wrapper son las COPIAS LOCALES del TSN.
add_files -norecurse [list \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ETH/rtl/eth_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ETH/rtl/eth_rx_mii.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ETH/rtl/eth_tx_mii.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_fifo.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_ingress.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_xbar.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_tx_adapt.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_inject.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_regs.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_top.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_soc.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/mem_subsys_dma.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/soc_top_master.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/TSN/soc_top_master_wrap.v]

# dependencias del core que quiza ya esten (clonadas del ETH). Anadir las que falten:
foreach dep {riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
             csr.vhd dp_ram.vhd dma_burst.vhd cpu_pipeline.vhd axil_soc.vhd} {
  if {[llength [get_files -quiet *$dep]] == 0} {
    add_files -norecurse $env(HOME)/rv32i/$dep
  }
}
set_property file_type {VHDL 2008} [get_files $env(HOME)/vhdl_repo/IP_Cores/TSN/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/vhdl_repo/IP_Cores/ETH/rtl/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/rv32i/*.vhd]
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_master_wrap u_soc_tsn

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_tsn/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_tsn/aresetn]

get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_tsn/s_axi]

connect_bd_intf_net [get_bd_intf_pins u_soc_tsn/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]

connect_bd_net [get_bd_pins u_soc_tsn/irq_out] [get_bd_pins versal_cips_0/pl_ps_irq0]

# ---------- 5) address map ----------
assign_bd_address -target_address_space /u_soc_tsn/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_tsn/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
validate_bd_design
get_bd_nets -of_objects [get_bd_pins u_soc_tsn/aclk]
get_bd_nets -of_objects [get_bd_pins u_soc_tsn/aresetn]

# ---------- 7) top y salvado ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# reset_run synth_1 ; launch_runs synth_1 -jobs 30 ; wait_on_run synth_1
# launch_runs impl_1 -to_step write_device_image -jobs 30 ; wait_on_run impl_1
# PDI:  vivado_tsn/tsn_soc.runs/impl_1/bd_soc_usart_wrapper.pdi
# XSA:  write_hw_platform -fixed -include_bit -force $env(HOME)/vhdl_repo/IP_Cores/TSN/tsn_soc.xsa
