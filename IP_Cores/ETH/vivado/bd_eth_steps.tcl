# ============================================================================
#  bd_eth_steps.tcl - Trasplante del BD del SoC + IP Ethernet MAC (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto Vivado del 1553 (que hereda del SPW/CAN/I3C/USART
#  el BD bd_soc_usart con CIPS, NoC NUM_SI=7, axi_smc, reset y address map ya
#  auditados) y sustituir el module reference u_soc_m1553 por u_soc_eth.
#
#  DIFERENCIA CLAVE frente al 1553: el 1553 exponia 3 pines single-ended. El
#  MAC Ethernet MII expone ~16 pines (TXD[3:0], TX_EN, TX_CLK, RXD[3:0],
#  RX_DV, RX_CLK, CRS, COL, MDC, MDIO). En LOOP_INT v1 son INERTES (el mux
#  interno realimenta TX->RX en el PL y los pads quedan sin efecto aguas
#  abajo), pero se crean como puertos externos y se restringen por XDC en el
#  banco 302 HDIO (LVCMOS33). El TX_CLK/RX_CLK de 25 MHz se generan/dividen
#  internamente desde los 100 MHz del core (/4) - no hay reloj de entrada del
#  PHY en v1.
#
#  Lecciones aplicadas (USART #13 / IIC / I3C / CAN / SPW / 1553):
#   - source_mgmt_mode All en los clones
#   - save_project_as CLONA runs sucios: reset_run synth_1/impl_1 y borrar
#     el INCREMENTAL_CHECKPOINT tras clonar (la propiedad
#     STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_CHECKPOINT NO existe en Versal
#     2025.2: usar INCREMENTAL_CHECKPOINT del run)
#   - ~ NO se expande en Tcl: usar $env(HOME)
#   - conectar por PIN DE ORIGEN, descubriendo con get_bd_* antes de conectar
#   - NUNCA Connection Automation para maestros del PL
#   - el SI del NoC del PL lleva SU PROPIA aclk (S06_AXI con aclk6): verificar
#   - assign_bd_address explicito; validate_bd_design dice OK aunque este
#     validamente equivocado -> auditar con bd_review.tcl
#   - top de implementacion = wrapper del BD (bd_soc_usart_wrapper)
#   - PL CLK0 a 100 MHz (el core corre a aclk = pl0_ref_clk)
#   - barrer con foreach f [get_files -all *] tras el clon
#   - bd_review.tcl busca la celda u_soc; si es u_soc_eth, la seccion
#     reloj/reset del reporte sale VACIA -> verificar a mano
# ============================================================================

# ---------- 0) clonar el proyecto del 1553 ----------
open_project $env(HOME)/m1553_ip/vivado_m1553/m1553_soc.xpr
save_project_as eth_soc $env(HOME)/eth_ip/vivado_eth -force
set_property source_mgmt_mode All [current_project]

# save_project_as arrastra los runs del original: resetearlos y limpiar el
# checkpoint incremental heredado ANTES de tocar nada mas.
reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/eth_ip/vivado_eth/eth_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre (leccion #5): anotar
# cualquier ruta que apunte a m1553_ip/vivado_m1553 y resolverla antes de seguir
foreach f [get_files -all *] { if {[string match *m1553_ip/vivado_m1553* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del 1553 ----------
open_bd_design [get_files bd_soc_usart.bd]
# descubrir la celda y sus conexiones ANTES de borrar (anotar respuestas):
get_bd_cells
get_bd_intf_pins u_soc_m1553/*
get_bd_nets -of_objects [get_bd_pins u_soc_m1553/*]
delete_bd_objs [get_bd_cells u_soc_m1553]
# residuo del module reference (leccion 1553): al borrar la celda queda un .xci
# huerfano en sources_1 que remove_files rechaza; se limpia regenerando el BD.
generate_target all [get_files bd_soc_usart.bd]

# ---------- 2) sustituir fuentes 1553 -> Ethernet ----------
# el Ethernet no usa las fuentes del 1553: fuera todas
remove_files [get_files -quiet {*m1553_word_tx.vhd *m1553_word_rx.vhd \
  *m1553_rt_core.vhd *m1553_bc_core.vhd *m1553_mmio.vhd *mem_subsys_m1553.vhd \
  *soc_top_m1553.vhd *soc_top_m1553_wrap.v}]
# el spw_fifo canonico SE QUEDA (parametrizable, WIDTH=9 para el MAC). Si por
# algun motivo no estuviera, se re-anade desde ~/spw_ip sin duplicar la fuente.
if {[llength [get_files -quiet *spw_fifo.vhd]] == 0} {
  add_files -norecurse $env(HOME)/spw_ip/spw_fifo.vhd
}
add_files -norecurse [list \
  $env(HOME)/eth_ip/rtl/eth_pkg.vhd \
  $env(HOME)/eth_ip/rtl/eth_tx_mii.vhd \
  $env(HOME)/eth_ip/rtl/eth_rx_mii.vhd \
  $env(HOME)/eth_ip/rtl/eth_mac.vhd \
  $env(HOME)/eth_ip/rtl/eth_mmio.vhd \
  $env(HOME)/eth_ip/rtl/mem_subsys_eth.vhd \
  $env(HOME)/eth_ip/rtl/soc_top_eth.vhd \
  $env(HOME)/eth_ip/rtl/soc_top_eth_wrap.v]
set_property file_type {VHDL 2008} [get_files $env(HOME)/eth_ip/rtl/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/spw_ip/spw_fifo.vhd]
# XDC de pines MII (banco 302 HDIO, LVCMOS33). Verificar PACKAGE_PIN antes.
add_files -fileset constrs_1 -norecurse $env(HOME)/eth_ip/eth_pins.xdc
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_eth_wrap u_soc_eth

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset (descubrir el nombre real de la red del clk y del aresetn):
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_eth/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_eth/aresetn]

# esclavo s_axi <- salida del smartconnect (descubrir el M0x libre):
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_eth/s_axi]

# maestro del PL -> SI dedicado del NoC (S06_AXI con aclk6, heredado):
connect_bd_intf_net [get_bd_intf_pins u_soc_eth/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
# verificar la asociacion de relojes (leccion #5): aclk6 SOLO S06_AXI y
# aclk0 SIN S06_AXI en su ASSOCIATED_BUSIF:
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk0]

# IRQs
connect_bd_net [get_bd_pins u_soc_eth/irq_out]     [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins u_soc_eth/eth_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# ---------- 4b) pads MII (DIFERENCIA vs 1553): ~16 puertos externos ----------
# En LOOP_INT v1 son inertes, pero se crean y restringen por XDC. Los de
# entrada del PHY (RXD/RX_DV/RX_CLK/CRS/COL/MDIO-in) se atan a 0 dentro del
# soc_top (no hay PHY); aqui solo se exponen los que el wrapper declara.
# Salidas:
create_bd_port -dir O -from 3 -to 0 mii_txd
create_bd_port -dir O mii_tx_en
# Entradas (inertes en LOOP_INT; el wrapper las ignora salvo en v1.1):
create_bd_port -dir I -from 3 -to 0 mii_rxd
create_bd_port -dir I mii_rx_dv
connect_bd_net [get_bd_pins u_soc_eth/mii_txd]   [get_bd_ports mii_txd]
connect_bd_net [get_bd_pins u_soc_eth/mii_tx_en] [get_bd_ports mii_tx_en]
connect_bd_net [get_bd_ports mii_rxd]            [get_bd_pins u_soc_eth/mii_rxd]
connect_bd_net [get_bd_ports mii_rx_dv]          [get_bd_pins u_soc_eth/mii_rx_dv]

# ---------- 5) address map (EXPLICITO) ----------
# el maestro del PL sigue apuntando a la DDR fisica reservada; la region
# 0xD000_0000 del Ethernet es del bus dmem INTERNO del RV32, no se mapea aqui.
assign_bd_address -target_address_space /u_soc_eth/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_eth/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl
# NOTA: bd_review.tcl busca la celda u_soc; con u_soc_eth la seccion
# reloj/reset saldra vacia. Verificar A MANO:
get_bd_nets -of_objects [get_bd_pins u_soc_eth/aclk]
get_bd_nets -of_objects [get_bd_pins u_soc_eth/aresetn]

# ---------- 7) top y salvado (el wrapper del BD no cambia: mismos puertos) ----
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# (van en run_synth_eth.tcl y run_impl_eth.tcl)
# PDI: <proyecto>.runs/impl_1/bd_soc_usart_wrapper.pdi
# plataforma para PetaLinux:
# write_hw_platform -fixed -include_bit -force $env(HOME)/eth_ip/eth_soc.xsa
