# ============================================================================
#  adc_soc_steps.tcl - Trasplante del BD del SoC + ADC delta-sigma soft IP v1
#  (TE0950 / Versal xcve2302-sfva784-1LP-e-S). Adaptado del tsn_soc_steps.tcl
#  probado en silicio.
#
#  NO SE "SOURCEA" COMPLETO: comandos UNO POR UNO en la consola Tcl de Vivado,
#  leyendo cada respuesta (leccion de la familia: connect_bd_net fallo
#  SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto TSN (hereda el BD con CIPS, NoC, axi_smc, reset y
#  address map auditados) y sustituir el module reference u_soc_tsn por
#  u_soc_adc.
#
#  El ADC es ESCLAVO DMEM DIRECTO, integrado en mem_subsys_adc en 0x6000_0000
#  (bus dmem interno del RV32, NO se mapea en el BD). NO hay maestro embebido
#  del IP: el movimiento a DDR usa el dma_burst del mem_subsys (patron de la
#  familia). El hook B (pdm_ext_i/pdm_fb_o) queda interno en v1: NO se exponen
#  pines a pads.
#
#  IMPORTANTE: mem_subsys_adc y soc_top_master son las COPIAS LOCALES del IP
#  ADC (con el adc_soc dentro), NO las de ~/rv32i ni las del TSN. Validadas en
#  GHDL: la cadena RTL local cierra sin residuos.
# ============================================================================

# ---------- 0) clonar el proyecto del TSN ----------
open_project $env(HOME)/vhdl_repo/IP_Cores/TSN/vivado_tsn/tsn_soc.xpr
save_project_as adc_soc $env(HOME)/vhdl_repo/IP_Cores/ADC/vivado_adc -force
set_property source_mgmt_mode All [current_project]

reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/vhdl_repo/IP_Cores/ADC/vivado_adc/adc_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre:
foreach f [get_files -all *] { if {[string match *TSN/vivado_tsn* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del TSN ----------
open_bd_design [get_files bd_soc_usart.bd]
get_bd_cells
get_bd_intf_pins u_soc_tsn/*
get_bd_nets -of_objects [get_bd_pins u_soc_tsn/*]
get_bd_ports
delete_bd_objs [get_bd_cells u_soc_tsn]
generate_target all [get_files bd_soc_usart.bd]

# (el TSN no exponia puertos externos; nada que borrar en 1b)

# ---------- 2) sustituir fuentes TSN -> ADC ----------
remove_files [get_files -quiet {*tsn_pkg.vhd *tsn_fifo.vhd *tsn_ingress.vhd \
  *tsn_xbar.vhd *tsn_tx_adapt.vhd *tsn_inject.vhd *tsn_regs.vhd *tsn_top.vhd \
  *tsn_soc.vhd *eth_pkg.vhd *eth_rx_mii.vhd *eth_tx_mii.vhd}]
# CLAVE: quitar las copias locales del TSN de mem_subsys/soc_top_master para
# que no colisionen con las copias locales del ADC.
remove_files [get_files -quiet {*TSN/mem_subsys_dma.vhd *TSN/soc_top_master.vhd \
  *TSN/soc_top_master_wrap.v}]

# anadir el RTL del ADC + copias locales. Orden de dependencia validado en GHDL.
add_files -norecurse [list \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_sin_lut_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_pdmgen.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_cic.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_core.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_fifo.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_regs.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_mmio.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_soc.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/mem_subsys_adc.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/soc_top_master.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/soc_top_master_wrap.v]

# dependencias del core que quiza ya esten (clonadas). Anadir las que falten:
foreach dep {riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
             csr.vhd dp_ram.vhd dma_burst.vhd cpu_pipeline.vhd axil_soc.vhd} {
  if {[llength [get_files -quiet *$dep]] == 0} {
    add_files -norecurse $env(HOME)/rv32i/$dep
  }
}
set_property file_type {VHDL 2008} [get_files $env(HOME)/vhdl_repo/IP_Cores/ADC/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/rv32i/*.vhd]
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_master_wrap u_soc_adc

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_adc/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_adc/aresetn]

get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_adc/s_axi]

connect_bd_intf_net [get_bd_intf_pins u_soc_adc/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]

connect_bd_net [get_bd_pins u_soc_adc/irq_out] [get_bd_pins versal_cips_0/pl_ps_irq0]

# ---------- 5) address map ----------
assign_bd_address -target_address_space /u_soc_adc/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_adc/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
# (bd_review.tcl canonico: ~/vhdl_repo/IP_Cores/USART/bd_review.tcl)
validate_bd_design
get_bd_nets -of_objects [get_bd_pins u_soc_adc/aclk]
get_bd_nets -of_objects [get_bd_pins u_soc_adc/aresetn]

# ---------- 7) top y salvado ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# reset_run synth_1 ; launch_runs synth_1 -jobs 30 ; wait_on_run synth_1
# Auditoria post-sintesis: el BRAM de la FIFO (molde SDP) debe inferirse como
#   RAMB, y la LUT senoidal como ROM en BRAM. Revisar el utilization report.
# launch_runs impl_1 -to_step write_device_image -jobs 30 ; wait_on_run impl_1
# PDI:  vivado_adc/adc_soc.runs/impl_1/bd_soc_usart_wrapper.pdi
# XSA:  write_hw_platform -fixed -include_bit -force $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_soc.xsa
