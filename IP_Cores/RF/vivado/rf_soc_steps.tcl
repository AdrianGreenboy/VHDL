# ============================================================================
#  rf_soc_steps.tcl - Trasplante del BD del SoC + RF Digital Front-End (DDC/DUC)
#  (TE0950 / Versal xcve2302-sfva784-1LP-e-S). Adaptado del bd_adcs_steps.tcl
#  probado, que ya resolvio el patron de DOS maestros AXI.
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado). Nunca se
#  pega un bloque compuesto (leccion: la consola Tcl trunca el inicio del bloque).
#
#  RUTA: clonar el proyecto Vivado del TSN (el mas reciente; hereda el BD
#  bd_soc_usart con CIPS, NoC, axi_smc, reset y address map auditados) y
#  sustituir el module reference u_soc_tsn por u_soc_rf.
#
#  DOS maestros AXI hacia la DDR (como el ADCS):
#    - m_axi : dma_burst del SoC (reporte/doorbell)   -> S06_AXI (heredado)
#    - rf    : segundo maestro propio del RF          -> S07_AXI (NUEVO)
#  Se AMPLIA el NoC a NUM_SI=8 / NUM_CLKS=8, S07 con su propia aclk7, y AMBOS
#  maestros se mapean a la DDR fisica (C0_DDR_LOW0). Ambos maestros son de 40b.
#
#  DOS lineas IRQ:
#    - irq_out    (doorbell del core)   -> pl_ps_irq0
#    - rf_irq_out (nivel de RX FIFO)    -> pl_ps_irq1
#
#  El RF v1 NO tiene pads (sin ADC/DAC conectado en la TE0950): sin XDC de
#  pines. La banda base la genera el segundo NCO interno (tono programable por
#  MMIO, TONE_FTW). La LUT esta EMBEBIDA en rf_sincos_pkg (constante VHDL); no
#  hace falta ningun .txt/.mem/.coe en sintesis.
#
#  Lecciones aplicadas (README USART #13 / IIC / I3C / CAN / SPW / ADCS):
#   - source_mgmt_mode All en los clones
#   - save_project_as CLONA runs sucios: reset_run + vaciar INCREMENTAL_CHECKPOINT
#   - INCREMENTAL_CHECKPOINT del RUN (no el arg de synth_design) en Versal 2025.2
#   - ~ NO se expande en Tcl: usar $env(HOME)
#   - conectar por PIN DE ORIGEN, descubriendo con get_bd_* antes de conectar
#   - NUNCA Connection Automation para maestros del PL (van a S_AXI_LPD=0 DDR)
#   - cada SI del NoC del PL lleva SU PROPIA aclk: S06->aclk6, S07->aclk7
#   - assign_bd_address explicito; validate dice OK aunque este mal -> auditar
#   - top de implementacion = wrapper del BD (bd_soc_usart_wrapper)
#   - barrer con foreach f [get_files -all *] referencias a otros proyectos
#   - out-of-context synth_design cambia el top: restaurar a bd_*_wrapper
# ============================================================================

# ---------- 0) clonar el proyecto del TSN ----------
open_project $env(HOME)/vhdl_repo/IP_Cores/TSN/vivado_tsn/tsn_soc.xpr
save_project_as rf_soc $env(HOME)/rf_ip/vivado_rf -force
set_property source_mgmt_mode All [current_project]

reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/rf_ip/vivado_rf/rf_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre (leccion #5)
foreach f [get_files -all *] { if {[string match *vivado_tsn* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del TSN ----------
open_bd_design [get_files bd_soc_usart.bd]
get_bd_cells
get_bd_intf_pins u_soc_tsn/*
get_bd_nets -of_objects [get_bd_pins u_soc_tsn/*]
get_bd_ports
delete_bd_objs [get_bd_cells u_soc_tsn]

# ---------- 2) sustituir fuentes TSN -> RF ----------
# fuera TODO lo del TSN (y cualquier eth_* residual del clon del ETH)
remove_files [get_files -quiet {*tsn_pkg.vhd *tsn_fifo.vhd *tsn_ingress.vhd \
  *tsn_xbar.vhd *tsn_tx_adapt.vhd *tsn_inject.vhd *tsn_regs.vhd *tsn_top.vhd \
  *tsn_soc.vhd *eth_pkg.vhd *eth_rx_mii.vhd *eth_tx_mii.vhd \
  *mem_subsys_dma.vhd *soc_top_master.vhd *soc_top_master_wrap.v}]
# si el clon trae mem_subsys_dma/soc_top_master de ~/rv32i, quitarlos para que
# no colisionen con las fuentes propias del RF.
remove_files [get_files -quiet {*rv32i/mem_subsys_dma.vhd *rv32i/soc_top_master.vhd \
  *rv32i/soc_top_master_wrap.v}]

# anadir el RTL propio del RF. Orden de dependencia validado en GHDL.
set RF $env(HOME)/vhdl_repo/IP_Cores/RF/rtl
add_files -norecurse [list \
  $RF/rf_sincos_pkg.vhd \
  $RF/rf_nco.vhd \
  $RF/rf_loopmix.vhd \
  $RF/rf_cic_int.vhd \
  $RF/rf_cic_dec.vhd \
  $RF/rf_fir.vhd \
  $RF/rf_agc.vhd \
  $RF/word_fifo.vhd \
  $RF/rf_regs.vhd \
  $RF/rf_datapath.vhd \
  $RF/rf_dma_axi.vhd \
  $RF/mem_subsys_rf.vhd \
  $RF/rf_soc_top_master.vhd \
  $RF/rf_soc_top_master_wrap.v]

# fuentes del core RV32IM compartidas (referenciadas desde origen, no duplicadas).
# Anadir solo las que falten (el clon del TSN quiza ya las traiga).
foreach dep {riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
             csr.vhd clint.vhd dp_ram.vhd dma_burst.vhd axi4_master.vhd \
             cpu_pipeline.vhd axil_soc.vhd} {
  if {[llength [get_files -quiet *$dep]] == 0} {
    add_files -norecurse $env(HOME)/rv32i/$dep
  }
}
set_property file_type {VHDL 2008} [get_files $RF/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/rv32i/*.vhd]
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference rf_soc_top_master_wrap u_soc_rf

# ---------- 4) AMPLIAR EL NOC: S06 (m_axi) + S07 (rf) ----------
# el NoC heredado tiene NUM_SI=7 (S00-S05 del CIPS, S06 del PL). Ampliar a 8.
set_property -dict [list CONFIG.NUM_SI {8} CONFIG.NUM_CLKS {8}] [get_bd_cells axi_noc_0]
# el nuevo S07 va a la DDR con su propia aclk7
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500}}}] \
  [get_bd_intf_pins axi_noc_0/S07_AXI]
set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S07_AXI}] [get_bd_pins axi_noc_0/aclk7]

# ---------- 5) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_rf/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_rf/aresetn]

# esclavo s_axi <- smartconnect
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins u_soc_rf/s_axi]

# MAESTRO 1: m_axi (dma_burst) -> S06_AXI (aclk6, heredado)
connect_bd_intf_net [get_bd_intf_pins u_soc_rf/m_axi] [get_bd_intf_pins axi_noc_0/S06_AXI]
# MAESTRO 2: rf (segundo maestro del RF) -> S07_AXI (aclk7, nuevo)
connect_bd_intf_net [get_bd_intf_pins u_soc_rf/rf_axi] [get_bd_intf_pins axi_noc_0/S07_AXI]

# ambos SI del PL comparten el pl0_ref_clk -> conectar aclk6 y aclk7 a el
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk6]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk7]
# verificar asociacion de relojes: aclk6->S06, aclk7->S07, sin cruces
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk7]

# ---------- 5b) IRQs: doorbell -> irq0, RF -> irq1 ----------
connect_bd_net [get_bd_pins u_soc_rf/irq_out]    [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins u_soc_rf/rf_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# pads: el RF v1 no tiene ninguno. Verificar que no quedan puertos externos del TSN:
get_bd_ports

# ---------- 6) address map (EXPLICITO, ambos maestros a la DDR) ----------
# m_axi (S06) -> DDR fisica
assign_bd_address -target_address_space /u_soc_rf/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
# rf_axi (S07) -> MISMA DDR fisica (mismo controlador; offset 0)
assign_bd_address -target_address_space /u_soc_rf/rf_axi \
  [get_bd_addr_segs axi_noc_0/S07_AXI/C0_DDR_LOW0] -force
# esclavo del PS -> control del SoC (0x8000_0000, 64K)
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_rf/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 7) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl
# revisar bd_report.txt: confirmar NUM_SI=8, S07 CONNECTIONS=MC_0, aclk7->S07,
# AMBOS maestros (S06, S07) -> C0_DDR_LOW0, y las dos IRQ conectadas.
get_bd_nets -of_objects [get_bd_pins u_soc_rf/aclk]
get_bd_nets -of_objects [get_bd_pins u_soc_rf/aresetn]

# ---------- 8) top y salvado ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 9) sintesis / implementacion / imagen ----------
# (van en run_synth_rf.tcl y run_impl_rf.tcl; UNO POR UNO)
#   reset_run synth_1 ; launch_runs synth_1 -jobs 30 ; wait_on_run synth_1
#   launch_runs impl_1 -to_step write_device_image -jobs 30 ; wait_on_run impl_1
# PDI:  vivado_rf/rf_soc.runs/impl_1/bd_soc_usart_wrapper.pdi
# XSA:  write_hw_platform -fixed -include_bit -force $env(HOME)/rf_ip/rf_soc.xsa
