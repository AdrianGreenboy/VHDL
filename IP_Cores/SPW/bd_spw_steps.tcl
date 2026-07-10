# ============================================================================
#  bd_spw_steps.tcl - Trasplante del BD del SoC + IP SpaceWire (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto Vivado del CAN (que hereda del I3C/USART el BD
#  bd_soc_usart con CIPS, NoC NUM_SI=7, axi_smc, reset y address map ya
#  auditados) y sustituir el module reference u_soc_can por u_soc_spw.
#
#  DIFERENCIA CLAVE frente al CAN: el SpaceWire v1 NO tiene pads. El puerto
#  externo can_bus del BD se ELIMINA y no se crea ninguno (los pares LVDS
#  del CRUVI/HDIO son pregunta abierta de v1.1). Sin XDC de pines. Y el SPW
#  NO usa byte_fifo (lleva su spw_fifo de 9 bits): TODOS los byte_fifo del
#  proyecto clonado sobran (leccion #7: fuentes ajenas fuera para sintesis
#  determinista).
#
#  Lecciones aplicadas (README USART #13 / IIC / I3C / CAN):
#   - source_mgmt_mode All en los clones
#   - save_project_as CLONA runs sucios: reset_run synth_1/impl_1 y borrar
#     el incremental_checkpoint tras clonar
#   - la propiedad STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_CHECKPOINT NO existe
#     en Versal 2025.2: usar INCREMENTAL_CHECKPOINT del run (leccion CAN #6)
#   - ~ NO se expande en Tcl: usar $env(HOME)
#   - conectar por PIN DE ORIGEN, descubriendo con get_bd_* antes de conectar
#   - NUNCA Connection Automation para maestros del PL
#   - el SI del NoC del PL lleva SU PROPIA aclk (S06_AXI con aclk6): verificar
#   - assign_bd_address explicito; validate_bd_design dice OK aunque este
#     validamente equivocado -> auditar con bd_review.tcl
#   - top de implementacion = wrapper del BD (bd_soc_usart_wrapper)
#   - PL CLK0 a 100 MHz (el core corre a aclk = pl0_ref_clk)
#   - barrer con foreach f [get_files -all *] buscando referencias a otros
#     proyectos (.bd remoto, wrapper .v, .dcp, nocattrs.dat) tras el clon
# ============================================================================

# ---------- 0) clonar el proyecto del CAN ----------
open_project $env(HOME)/can_ip/vivado_can/can_soc.xpr
save_project_as spw_soc $env(HOME)/spw_ip/vivado_spw -force
set_property source_mgmt_mode All [current_project]

# save_project_as arrastra los runs del original: resetearlos y limpiar el
# checkpoint incremental heredado ANTES de tocar nada mas.
reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/spw_ip/vivado_spw/spw_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre (leccion #5): anotar
# cualquier ruta que apunte a can_ip/vivado_can y resolverla antes de seguir
foreach f [get_files -all *] { if {[string match *can_ip* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del CAN ----------
open_bd_design [get_files bd_soc_usart.bd]
# descubrir la celda y sus conexiones ANTES de borrar (anotar respuestas):
get_bd_cells
get_bd_intf_pins u_soc_can/*
get_bd_nets -of_objects [get_bd_pins u_soc_can/*]
delete_bd_objs [get_bd_cells u_soc_can]

# ---------- 2) sustituir fuentes CAN -> SPW ----------
# el SPW no usa byte_fifo: fuera TODAS las copias (spi_ip y can_ip)
remove_files [get_files -quiet {*byte_fifo.vhd *can_engine.vhd *can_mmio.vhd \
  *mem_subsys_can.vhd *soc_top_can.vhd *soc_top_can_wrap.v}]
remove_files -fileset constrs_1 [get_files -quiet *can_pins.xdc]
add_files -norecurse [list \
  $env(HOME)/spw_ip/spw_fifo.vhd \
  $env(HOME)/spw_ip/spw_tx.vhd \
  $env(HOME)/spw_ip/spw_rx.vhd \
  $env(HOME)/spw_ip/spw_link.vhd \
  $env(HOME)/spw_ip/spw_codec.vhd \
  $env(HOME)/spw_ip/spw_mmio.vhd \
  $env(HOME)/spw_ip/mem_subsys_spw.vhd \
  $env(HOME)/spw_ip/soc_top_spw.vhd \
  $env(HOME)/spw_ip/soc_top_spw_wrap.v]
set_property file_type {VHDL 2008} [get_files $env(HOME)/spw_ip/*.vhd]
# sin XDC de pines: el SPW v1 no tiene pads
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_spw_wrap u_soc_spw

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset (descubrir el nombre real de la red del clk y del aresetn):
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_spw/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_spw/aresetn]

# esclavo s_axi <- salida del smartconnect (descubrir el M0x libre):
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_spw/s_axi]

# maestro del PL -> SI dedicado del NoC (S06_AXI con aclk6, heredado):
connect_bd_intf_net [get_bd_intf_pins u_soc_spw/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
# verificar la asociacion de relojes (leccion #5): aclk6 SOLO S06_AXI y
# aclk0 SIN S06_AXI en su ASSOCIATED_BUSIF:
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk0]

# IRQs
connect_bd_net [get_bd_pins u_soc_spw/irq_out]     [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins u_soc_spw/spw_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# pads: el BD del CAN tenia UN puerto externo (can_bus). El SPW v1 no tiene
# ninguno: eliminarlo y NO crear puertos nuevos.
get_bd_ports
delete_bd_objs [get_bd_ports can_bus]

# ---------- 5) address map (EXPLICITO) ----------
# el maestro del PL sigue apuntando a la DDR fisica reservada; la region
# 0xB000_0000 del SPW es del bus dmem INTERNO del RV32, no se mapea en el NoC.
assign_bd_address -target_address_space /u_soc_spw/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_spw/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl

# ---------- 7) top y salvado (el wrapper del BD no cambia: mismos puertos) ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# (van en run_synth_spw.tcl y run_impl_spw.tcl)
# PDI: <proyecto>.runs/impl_1/bd_soc_usart_wrapper.pdi
# plataforma para PetaLinux:
# write_hw_platform -fixed -include_bit -force $env(HOME)/spw_ip/spw_soc.xsa
