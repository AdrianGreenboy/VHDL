# ============================================================================
#  bd_m1553_steps.tcl - Trasplante del BD del SoC + IP MIL-STD-1553B (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto Vivado del SPW (que hereda del CAN/I3C/USART el BD
#  bd_soc_usart con CIPS, NoC NUM_SI=7, axi_smc, reset y address map ya
#  auditados) y sustituir el module reference u_soc_spw por u_soc_m1553.
#
#  DIFERENCIA CLAVE frente al SPW: el SPW v1 NO tenia pads (borraba el puerto
#  externo). El 1553 SI expone 3 pines single-ended (m1553_rx entra;
#  m1553_tx/m1553_txen salen). Son inocuos en LOOP_INT (el IP gatea txen a 0
#  hacia fuera), pero se crean como puertos externos y se restringen por XDC.
#  El 1553 NO usa byte_fifo ni las fuentes del SPW: TODAS fuera (leccion #7).
#
#  Lecciones aplicadas (README USART #13 / IIC / I3C / CAN / SPW):
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

# ---------- 0) clonar el proyecto del SPW ----------
open_project $env(HOME)/spw_ip/vivado_spw/spw_soc.xpr
save_project_as m1553_soc $env(HOME)/m1553_ip/vivado_m1553 -force
set_property source_mgmt_mode All [current_project]

# save_project_as arrastra los runs del original: resetearlos y limpiar el
# checkpoint incremental heredado ANTES de tocar nada mas.
reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/m1553_ip/vivado_m1553/m1553_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre (leccion #5): anotar
# cualquier ruta que apunte a spw_ip/vivado_spw y resolverla antes de seguir
foreach f [get_files -all *] { if {[string match *spw_ip/vivado_spw* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del SPW ----------
open_bd_design [get_files bd_soc_usart.bd]
# descubrir la celda y sus conexiones ANTES de borrar (anotar respuestas):
get_bd_cells
get_bd_intf_pins u_soc_spw/*
get_bd_nets -of_objects [get_bd_pins u_soc_spw/*]
delete_bd_objs [get_bd_cells u_soc_spw]

# ---------- 2) sustituir fuentes SPW -> 1553 ----------
# el 1553 no usa las fuentes del SPW: fuera todas
remove_files [get_files -quiet {*spw_fifo.vhd *spw_tx.vhd *spw_rx.vhd \
  *spw_link.vhd *spw_codec.vhd *spw_mmio.vhd *mem_subsys_spw.vhd \
  *soc_top_spw.vhd *soc_top_spw_wrap.v}]
# por si quedara algun byte_fifo de proyectos aun mas antiguos (leccion #7)
remove_files [get_files -quiet *byte_fifo.vhd]
# el 1553 SI usa una FIFO: es el spw_fifo canonico (18/24 b por generic).
# Se re-anade explicitamente desde ~/spw_ip para no duplicar la fuente.
add_files -norecurse [list \
  $env(HOME)/spw_ip/spw_fifo.vhd \
  $env(HOME)/m1553_ip/rtl/m1553_word_tx.vhd \
  $env(HOME)/m1553_ip/rtl/m1553_word_rx.vhd \
  $env(HOME)/m1553_ip/rtl/m1553_rt_core.vhd \
  $env(HOME)/m1553_ip/rtl/m1553_bc_core.vhd \
  $env(HOME)/m1553_ip/rtl/m1553_mmio.vhd \
  $env(HOME)/m1553_ip/rtl/mem_subsys_m1553.vhd \
  $env(HOME)/m1553_ip/rtl/soc_top_m1553.vhd \
  $env(HOME)/m1553_ip/rtl/soc_top_m1553_wrap.v]
set_property file_type {VHDL 2008} [get_files $env(HOME)/m1553_ip/rtl/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/spw_ip/spw_fifo.vhd]
# XDC de pines del 1553 (3 pines single-ended)
add_files -fileset constrs_1 -norecurse $env(HOME)/m1553_ip/m1553_pins.xdc
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_m1553_wrap u_soc_m1553

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset (descubrir el nombre real de la red del clk y del aresetn):
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_m1553/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_m1553/aresetn]

# esclavo s_axi <- salida del smartconnect (descubrir el M0x libre):
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_m1553/s_axi]

# maestro del PL -> SI dedicado del NoC (S06_AXI con aclk6, heredado):
connect_bd_intf_net [get_bd_intf_pins u_soc_m1553/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
# verificar la asociacion de relojes (leccion #5): aclk6 SOLO S06_AXI y
# aclk0 SIN S06_AXI en su ASSOCIATED_BUSIF:
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk0]

# IRQs
connect_bd_net [get_bd_pins u_soc_m1553/irq_out]       [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins u_soc_m1553/m1553_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# ---------- 4b) pads del 1553 (DIFERENCIA vs SPW): crear 3 puertos externos ----
# el BD del SPW no tenia ninguno; aqui creamos 3 y los conectamos por pin.
create_bd_port -dir I m1553_rx
create_bd_port -dir O m1553_tx
create_bd_port -dir O m1553_txen
connect_bd_net [get_bd_ports m1553_rx]   [get_bd_pins u_soc_m1553/m1553_rx]
connect_bd_net [get_bd_pins u_soc_m1553/m1553_tx]   [get_bd_ports m1553_tx]
connect_bd_net [get_bd_pins u_soc_m1553/m1553_txen] [get_bd_ports m1553_txen]

# ---------- 5) address map (EXPLICITO) ----------
# el maestro del PL sigue apuntando a la DDR fisica reservada; la region
# 0xC000_0000 del 1553 es del bus dmem INTERNO del RV32, no se mapea en el NoC.
assign_bd_address -target_address_space /u_soc_m1553/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_m1553/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl

# ---------- 7) top y salvado (el wrapper del BD no cambia: mismos puertos) ----
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# (van en run_synth_m1553.tcl y run_impl_m1553.tcl)
# PDI: <proyecto>.runs/impl_1/bd_soc_usart_wrapper.pdi
# plataforma para PetaLinux:
# write_hw_platform -fixed -include_bit -force $env(HOME)/m1553_ip/m1553_soc.xsa
