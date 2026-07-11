# ============================================================================
#  ptp_soc_steps.tcl - Trasplante del BD del SoC + IP PTP/802.1AS (TE0950)
#
#  NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la consola Tcl de
#  Vivado, leyendo cada respuesta (leccion USART #4: un connect_bd_net fallo
#  SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto ETH (que hereda el BD bd_soc_usart con CIPS, NoC,
#  axi_smc, reset y address map ya auditados) y sustituir el module reference
#  u_soc_eth por u_soc_ptp.
#
#  DIFERENCIA CLAVE frente al ETH: el ETH exponia ~16 pines MII + eth_irq_out.
#  El PTP en Opcion B va EMBEBIDO en soc_top_master (maestro AXI-Lite interno a
#  0x6000_0000 hacia ptp_axil). NO expone NINGUN puerto nuevo: solo s_axi,
#  m_axi e irq_out (identicos a los que el BD ya conecta). Por tanto NO se
#  crean puertos MII ni IRQ extra: el trasplante es mas simple que el del ETH.
#
#  El wrapper Verilog es soc_top_master_wrap (instancia soc_top_master, que ya
#  lleva mem_subsys_dma + ptp_axil dentro). Mapa interno del core:
#    0x0000_0000 RAM local | 0x4000_0000 regs DMA | 0x6000_0000 IP PTP
#  Nada de eso se mapea en el BD (es el bus dmem INTERNO del RV32).
# ============================================================================

# ---------- 0) clonar el proyecto del ETH ----------
open_project $env(HOME)/eth_ip/vivado_eth/eth_soc.xpr
save_project_as ptp_soc $env(HOME)/vhdl_repo/IP_Cores/PTP/vivado_ptp -force
set_property source_mgmt_mode All [current_project]

# save_project_as arrastra los runs del original: resetearlos y limpiar el
# checkpoint incremental heredado ANTES de tocar nada mas.
reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre (leccion #5)
foreach f [get_files -all *] { if {[string match *eth_ip/vivado_eth* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del ETH ----------
open_bd_design [get_files bd_soc_usart.bd]
# descubrir la celda y sus conexiones ANTES de borrar (anotar respuestas):
get_bd_cells
get_bd_intf_pins u_soc_eth/*
get_bd_nets -of_objects [get_bd_pins u_soc_eth/*]
# los pines MII del ETH quedaran como puertos externos huerfanos: anotarlos
# para borrarlos despues (el PTP no los usa).
get_bd_ports
delete_bd_objs [get_bd_cells u_soc_eth]
generate_target all [get_files bd_soc_usart.bd]

# ---------- 1b) borrar los puertos MII externos del ETH (el PTP no expone) ----
# El ETH creo mii_txd, mii_tx_en, mii_rxd, mii_rx_dv como puertos del BD. El
# PTP no los necesita (LOOP_INT interno). Borrarlos UNO POR UNO tras confirmar
# que existen con get_bd_ports:
catch {delete_bd_objs [get_bd_ports mii_txd]}
catch {delete_bd_objs [get_bd_ports mii_tx_en]}
catch {delete_bd_objs [get_bd_ports mii_rxd]}
catch {delete_bd_objs [get_bd_ports mii_rx_dv]}

# ---------- 2) sustituir fuentes ETH -> PTP ----------
# fuera las fuentes del ETH (el soc_top_eth y su subsistema)
remove_files [get_files -quiet {*eth_mmio.vhd *mem_subsys_eth.vhd \
  *soc_top_eth.vhd *soc_top_eth_wrap.v}]
# el spw_fifo canonico SE QUEDA (WIDTH=9 lo usa el MAC del PTP tambien). Si no
# estuviera, se re-anade sin duplicar.
if {[llength [get_files -quiet *spw_fifo.vhd]] == 0} {
  add_files -norecurse $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/spw_fifo.vhd
}

# anadir TODO el RTL del PTP + core con DMA + wrapper. RTL del IP en
# ~/vhdl_repo/IP_Cores/PTP/rtl ; el core y el subsistema modificados en ~/rv32i.
add_files -norecurse [list \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_msg_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/eth_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_clock.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_tstamp.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_pdelay.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_pdelay_fsm.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_tx.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_rx.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/eth_tx_mii.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/eth_rx_mii.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/eth_mac.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_mac.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_regs.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_top.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/ptp_axil.vhd \
  $env(HOME)/rv32i/ptp_axil_master.vhd \
  $env(HOME)/rv32i/mem_subsys_dma.vhd \
  $env(HOME)/rv32i/soc_top_master.vhd \
  $env(HOME)/rv32i/soc_top_master_wrap.v]
# dependencias del core que quiza ya esten en el proyecto (dp_ram, dma_burst,
# cpu_pipeline, alu, etc.). Anadir solo las que falten -> comprobar con:
#   get_files -quiet *cpu_pipeline.vhd
# y anadir desde ~/rv32i las ausentes:
foreach dep {riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
             csr.vhd dp_ram.vhd dma_burst.vhd cpu_pipeline.vhd axil_soc.vhd} {
  if {[llength [get_files -quiet *$dep]] == 0} {
    add_files -norecurse $env(HOME)/rv32i/$dep
  }
}
set_property file_type {VHDL 2008} [get_files $env(HOME)/vhdl_repo/IP_Cores/PTP/rtl/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/rv32i/*.vhd]
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_master_wrap u_soc_ptp

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset (descubrir el nombre real de la red del clk y del aresetn):
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_ptp/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_ptp/aresetn]

# esclavo s_axi <- salida del smartconnect (descubrir el M0x libre):
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_ptp/s_axi]

# maestro del PL -> SI dedicado del NoC (S06_AXI con aclk6, heredado):
connect_bd_intf_net [get_bd_intf_pins u_soc_ptp/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
# verificar la asociacion de relojes (leccion #5):
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]

# IRQ (solo una: el doorbell del core; el PTP NO expone IRQ extra en Opcion B):
connect_bd_net [get_bd_pins u_soc_ptp/irq_out] [get_bd_pins versal_cips_0/pl_ps_irq0]

# ---------- 5) address map (EXPLICITO) ----------
# el maestro del PL apunta a la DDR fisica reservada (para la firma por DMA);
# la region 0x6000_0000 del PTP es del bus dmem INTERNO del RV32, no se mapea.
assign_bd_address -target_address_space /u_soc_ptp/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_ptp/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl
# bd_review.tcl busca u_soc; con u_soc_ptp la seccion reloj/reset saldra vacia.
# Verificar A MANO:
get_bd_nets -of_objects [get_bd_pins u_soc_ptp/aclk]
get_bd_nets -of_objects [get_bd_pins u_soc_ptp/aresetn]

# ---------- 7) top y salvado (el wrapper del BD no cambia: mismos puertos) ----
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# reset_run synth_1 ; launch_runs synth_1 -jobs 30 ; wait_on_run synth_1
# launch_runs impl_1 -to_step write_device_image -jobs 30 ; wait_on_run impl_1
# PDI:  ptp_soc.runs/impl_1/bd_soc_usart_wrapper.pdi
# XSA:  write_hw_platform -fixed -include_bit -force $env(HOME)/vhdl_repo/IP_Cores/PTP/ptp_soc.xsa
