# ============================================================================
#  bd_adcs_steps.tcl - Trasplante del BD del SoC + IP ADCS (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto Vivado del SPW (que hereda el BD bd_soc_usart con
#  CIPS, NoC NUM_SI=7, axi_smc, reset y address map ya auditados) y sustituir
#  el module reference u_soc_spw por u_soc_adcs.
#
#  DIFERENCIA CLAVE frente al SPW: el ADCS tiene DOS maestros AXI hacia la DDR:
#    - m_axi  : dma_burst del SoC (reporte/doorbell)      -> S06_AXI (heredado)
#    - a_axi  : maestro propio del IP ADCS (H/g/U)         -> S07_AXI (NUEVO)
#  Hay que AMPLIAR el NoC a NUM_SI=8 / NUM_CLKS=8, dar a S07 su propia aclk7,
#  y mapear AMBOS maestros a la DDR fisica. El a_axi es de 32 bits addr; el NoC
#  lo extiende. Como el SPW, el ADCS v1 NO tiene pads: sin XDC de pines.
#
#  El ADCS NO usa byte_fifo ni spw_fifo: fuera todas las copias ajenas
#  (leccion #7: fuentes ajenas fuera para sintesis determinista). El ADCS SI
#  usa el core Floating-Point Operator fp_fma (generado con package_fpo.tcl) y
#  la arquitectura fp32_fma_xil (NO la behav de 480 bits, no sintetizable).
#
#  Lecciones aplicadas (README USART #13 / IIC / I3C / CAN / SPW):
#   - source_mgmt_mode All en los clones
#   - save_project_as CLONA runs sucios: reset_run + borrar incremental
#   - INCREMENTAL_CHECKPOINT del RUN (no el arg de synth_design) en Versal
#   - ~ NO se expande en Tcl: usar $env(HOME)
#   - conectar por PIN DE ORIGEN, descubriendo con get_bd_* antes de conectar
#   - NUNCA Connection Automation para maestros del PL (van a S_AXI_LPD=0 DDR)
#   - cada SI del NoC del PL lleva SU PROPIA aclk: S06->aclk6, S07->aclk7
#   - assign_bd_address explicito; validate dice OK aunque este mal -> auditar
#   - top de implementacion = wrapper del BD (bd_soc_usart_wrapper)
#   - barrer con foreach f [get_files -all *] referencias a otros proyectos
# ============================================================================

# ---------- 0) clonar el proyecto del SPW ----------
open_project $env(HOME)/spw_ip/vivado_spw/spw_soc.xpr
save_project_as adcs_soc $env(HOME)/adcs_ip/vivado_adcs -force
set_property source_mgmt_mode All [current_project]

reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/adcs_ip/vivado_adcs/adcs_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre (leccion #5)
foreach f [get_files -all *] { if {[string match *spw_ip* $f]} { puts "REMOTA: $f" } }

# ---------- 1) generar el core Floating-Point Operator fp_fma ----------
# (config = tesis: FMA, Single, Full_Usage, NonBlocking, C_Latency=8, C_Rate=1)
source $env(HOME)/vhdl_repo/IP_Cores/ADCS/vivado/package_fpo.tcl

# ---------- 2) abrir el BD y quitar el module reference del SPW ----------
open_bd_design [get_files bd_soc_usart.bd]
get_bd_cells
get_bd_intf_pins u_soc_spw/*
get_bd_nets -of_objects [get_bd_pins u_soc_spw/*]
delete_bd_objs [get_bd_cells u_soc_spw]

# ---------- 3) sustituir fuentes SPW -> ADCS ----------
# fuera TODO lo del SPW (y cualquier byte_fifo residual)
remove_files [get_files -quiet {*spw_fifo.vhd *spw_tx.vhd *spw_rx.vhd \
  *spw_link.vhd *spw_codec.vhd *spw_mmio.vhd *mem_subsys_spw.vhd \
  *soc_top_spw.vhd *soc_top_spw_wrap.v *byte_fifo.vhd}]

# anadir el RTL del IP ADCS (arquitectura de SINTESIS: fp32_fma_xil, NO la behav)
set ADCS $env(HOME)/vhdl_repo/IP_Cores/ADCS
add_files -norecurse [list \
  $ADCS/rtl/riscv_pkg.vhd \
  $ADCS/rtl/fp32_pkg.vhd \
  $ADCS/rtl/fp32_fma_xil.vhd \
  $ADCS/rtl/adcs_pkg.vhd \
  $ADCS/rtl/mpc_dot_row.vhd \
  $ADCS/rtl/mpc_dot_x8.vhd \
  $ADCS/rtl/adcs_mem_banks.vhd \
  $ADCS/rtl/mpc_engine.vhd \
  $ADCS/rtl/adcs_regfile.vhd \
  $ADCS/rtl/axi_dma_engine.vhd \
  $ADCS/rtl/adcs_accel_top.vhd \
  $ADCS/rtl/mem_subsys_dma_adcs.vhd \
  $ADCS/rtl/soc_top_master_adcs.vhd]
# fuentes del core RV32IM compartidas (referenciadas desde origen, no duplicadas)
add_files -norecurse [glob $env(HOME)/rv32i/{alu,control,csr,immgen,muldiv,regfile,cpu_pipeline,dp_ram,axi4_master,dma_burst,axil_soc,clint}.vhd]
# CRITICO: la arquitectura behav (fp32_fma.vhd) NO debe entrar a sintesis
# (acumulador 480b no sintetizable). Solo fp32_fma_xil.vhd.
set_property file_type {VHDL 2008} [get_files $ADCS/rtl/*.vhd]
# wrapper Verilog del module-ref (si el patron de familia lo usa)
add_files -norecurse $ADCS/rtl/soc_top_master_adcs_wrap.v
update_compile_order -fileset sources_1

# ---------- 4) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_master_adcs_wrap u_soc_adcs

# ---------- 5) AMPLIAR EL NOC: S06 (m_axi) + S07 (a_axi) ----------
# el NoC heredado tiene NUM_SI=7 (S00-S05 del CIPS, S06 del PL). Ampliar a 8.
set_property -dict [list CONFIG.NUM_SI {8} CONFIG.NUM_CLKS {8}] [get_bd_cells axi_noc_0]
# el nuevo S07 va a la DDR con su propia aclk7
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500}}}] \
  [get_bd_intf_pins axi_noc_0/S07_AXI]
set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S07_AXI}] [get_bd_pins axi_noc_0/aclk7]

# ---------- 6) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_adcs/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_adcs/aresetn]

# esclavo s_axi <- smartconnect
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins u_soc_adcs/s_axi]

# MAESTRO 1: m_axi (dma_burst) -> S06_AXI (aclk6, heredado)
connect_bd_intf_net [get_bd_intf_pins u_soc_adcs/m_axi] [get_bd_intf_pins axi_noc_0/S06_AXI]
# MAESTRO 2: a_axi (maestro ADCS) -> S07_AXI (aclk7, nuevo)
connect_bd_intf_net [get_bd_intf_pins u_soc_adcs/a_axi] [get_bd_intf_pins axi_noc_0/S07_AXI]

# ambos maestros del PL comparten el pl0_ref_clk -> conectar aclk6 y aclk7 a el
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk6]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk7]
# verificar asociacion de relojes (leccion #5): aclk6->S06, aclk7->S07, sin cruces
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk7]

# IRQs (el ADCS v1 usa el doorbell del SoC via irq_out; adcs_irq queda opcional)
connect_bd_net [get_bd_pins u_soc_adcs/irq_out] [get_bd_pins versal_cips_0/pl_ps_irq0]

# pads: el ADCS v1 no tiene ninguno (como SPW). Si el BD del SPW no tenia
# puertos externos, no hay nada que borrar; verificar:
get_bd_ports

# ---------- 7) address map (EXPLICITO, ambos maestros a la DDR) ----------
# m_axi (S06) -> DDR fisica
assign_bd_address -target_address_space /u_soc_adcs/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
# a_axi (S07) -> MISMA DDR fisica (en sim eran la misma memoria; en placa es el
# mismo controlador: los dos maestros ven el mismo espacio con offset 0)
assign_bd_address -target_address_space /u_soc_adcs/a_axi \
  [get_bd_addr_segs axi_noc_0/S07_AXI/C0_DDR_LOW0] -force
# esclavo del PS -> control del SoC (0x8000_0000, 64K)
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_adcs/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 8) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl
# revisar bd_report.txt: confirmar NUM_SI=8, S07 CONNECTIONS=MC_0, aclk7->S07,
# y que AMBOS maestros (S06, S07) mapean a C0_DDR_LOW0.

# ---------- 9) top y salvado ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 10) sintesis / implementacion / imagen ----------
# (van en run_synth_adcs.tcl y run_impl_adcs.tcl)
# PDI: <proyecto>.runs/impl_1/bd_soc_usart_wrapper.pdi
# XSA: write_hw_platform -fixed -include_bit -force $env(HOME)/adcs_ip/adcs_soc.xsa
