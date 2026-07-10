# ============================================================================
#  bd_can_steps.tcl - Trasplante del BD del SoC + IP CAN (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto Vivado del I3C (que hereda del USART el BD
#  bd_soc_usart con CIPS, NoC NUM_SI=7, axi_smc, reset y address map ya
#  auditados) y sustituir el module reference u_soc_i3c por u_soc_can.
#
#  DIFERENCIA CLAVE frente al I3C: el CAN tiene UN SOLO par de pads (can_tx /
#  can_rx en el transceptor externo) en vez de scl/sda. El wrapper expone un
#  unico IOBUF con T dinamico (T='1' libera, LOOP_INT interno). Ademas ya no
#  hay i3c_irq_out separado: el IP CAN saca can_irq_out a pl_ps_irq1.
#
#  Lecciones aplicadas (README USART #13 / IIC / I3C):
#   - source_mgmt_mode All en los clones
#   - save_project_as CLONA runs sucios: reset_run synth_1/impl_1 y borrar
#     el incremental_checkpoint tras clonar (leccion I3C: el clon arrastro un
#     checkpoint incremental que envenenaba la primera sintesis)
#   - ~ NO se expande en Tcl: usar $env(HOME)
#   - conectar por PIN DE ORIGEN, descubriendo con get_bd_* antes de conectar
#   - NUNCA Connection Automation para maestros del PL
#   - el SI del NoC del PL lleva SU PROPIA aclk (S06_AXI con aclk6): verificar
#   - assign_bd_address explicito; validate_bd_design dice OK aunque este
#     validamente equivocado -> auditar con bd_review.tcl
#   - top de implementacion = wrapper del BD (bd_soc_usart_wrapper)
#   - PL CLK0 a 100 MHz (el core corre a aclk = pl0_ref_clk)
# ============================================================================

# ---------- 0) clonar el proyecto del I3C ----------
open_project $env(HOME)/i3c_ip/vivado_i3c/i3c_soc.xpr
save_project_as can_soc $env(HOME)/can_ip/vivado_can -force
set_property source_mgmt_mode All [current_project]

# save_project_as arrastra los runs del original: resetearlos y limpiar el
# checkpoint incremental heredado ANTES de tocar nada mas (leccion I3C).
reset_run synth_1
reset_run impl_1
set_property -name {STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_CHECKPOINT} \
  -value {} -objects [get_runs synth_1]
file delete -force $env(HOME)/can_ip/vivado_can/can_soc.srcs/utils_1/imports

# ---------- 1) abrir el BD y quitar el module reference del I3C ----------
open_bd_design [get_files bd_soc_usart.bd]
# descubrir la celda y sus conexiones ANTES de borrar (anotar respuestas):
get_bd_cells
get_bd_intf_pins u_soc_i3c/*
get_bd_nets -of_objects [get_bd_pins u_soc_i3c/*]
delete_bd_objs [get_bd_cells u_soc_i3c]

# ---------- 2) sustituir fuentes I3C -> CAN ----------
remove_files [get_files -quiet {*i3c_controller.vhd *i3c_target.vhd \
  *i3c_mmio.vhd *mem_subsys_i3c.vhd *soc_top_i3c.vhd *soc_top_i3c_wrap.v}]
remove_files -fileset constrs_1 [get_files -quiet *i3c_pins.xdc]
add_files -norecurse [list \
  $env(HOME)/can_ip/byte_fifo.vhd \
  $env(HOME)/can_ip/can_engine.vhd \
  $env(HOME)/can_ip/can_mmio.vhd \
  $env(HOME)/can_ip/mem_subsys_can.vhd \
  $env(HOME)/can_ip/soc_top_can.vhd \
  $env(HOME)/can_ip/soc_top_can_wrap.v]
set_property file_type {VHDL 2008} [get_files $env(HOME)/can_ip/*.vhd]
add_files -fileset constrs_1 -norecurse $env(HOME)/can_ip/can_pins.xdc
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_can_wrap u_soc_can

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset (descubrir el nombre real de la red del clk y del aresetn):
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_can/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_can/aresetn]

# esclavo s_axi <- salida del smartconnect (descubrir el M0x libre):
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_can/s_axi]

# maestro del PL -> SI dedicado del NoC (S06_AXI con aclk6, heredado):
connect_bd_intf_net [get_bd_intf_pins u_soc_can/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
# verificar la asociacion de relojes (leccion #5): aclk6 SOLO S06_AXI y
# aclk0 SIN S06_AXI en su ASSOCIATED_BUSIF:
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk0]

# IRQs
connect_bd_net [get_bd_pins u_soc_can/irq_out]     [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins u_soc_can/can_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# pads: el BD del I3C tenia DOS puertos externos (scl/sda). El CAN solo usa
# UNO. Renombrar/crear un puerto inout unico "can_bus" y borrar el sobrante.
# Los puertos scl/sda sobreviven al borrado de la celda: reusar "scl" como
# el par CAN y eliminar "sda".
get_bd_ports
delete_bd_objs [get_bd_ports sda]
set_property name can_bus [get_bd_ports scl]
connect_bd_net [get_bd_pins u_soc_can/can_bus] [get_bd_ports can_bus]

# ---------- 5) address map (EXPLICITO) ----------
# el maestro del PL sigue apuntando a la DDR fisica reservada; la region
# 0xA000_0000 del CAN es del bus dmem INTERNO del RV32, no se mapea en el NoC.
assign_bd_address -target_address_space /u_soc_can/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_can/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
validate_bd_design
source $env(HOME)/vhdl_repo/IP_Cores/USART/bd_review.tcl

# ---------- 7) top y salvado (el wrapper del BD no cambia: mismos puertos) ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# launch_runs synth_1 -jobs 8
# launch_runs impl_1 -to_step write_device_image -jobs 8
# PDI: <proyecto>.runs/impl_1/bd_soc_usart_wrapper.pdi
# plataforma para PetaLinux:
# write_hw_platform -fixed -include_bit -force $env(HOME)/can_ip/can_soc.xsa
