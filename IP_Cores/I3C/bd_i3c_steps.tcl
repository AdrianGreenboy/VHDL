# ============================================================================
#  bd_i3c_steps.tcl - Trasplante del BD del SoC + IP I3C (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto Vivado del IIC (que a su vez heredo del USART el
#  BD bd_soc_usart con CIPS, NoC NUM_SI=7, axi_smc, reset y address map ya
#  auditados) y sustituir el module reference u_soc_i2c por u_soc_i3c.
#
#  Lecciones aplicadas (README USART #13 / IIC):
#   - source_mgmt_mode All en los clones
#   - ~ NO se expande en Tcl: usar $env(HOME)
#   - conectar por PIN DE ORIGEN, descubriendo con get_bd_* antes de conectar
#   - NUNCA Connection Automation para maestros del PL
#   - S06_AXI ya tiene aclk6 asociada SOLO a el (heredado del IIC): verificar
#   - assign_bd_address explicito; validate_bd_design dice OK aunque este
#     validamente equivocado -> auditar con bd_review.tcl
#   - top de implementacion = wrapper del BD (bd_soc_usart_wrapper)
# ============================================================================

# ---------- 0) clonar el proyecto del IIC ----------
open_project $env(HOME)/i2c_ip/vivado_i2c/i2c_soc.xpr
save_project_as i3c_soc $env(HOME)/i3c_ip/vivado_i3c -force
set_property source_mgmt_mode All [current_project]

# ---------- 1) abrir el BD y quitar el module reference del IIC ----------
open_bd_design [get_files bd_soc_usart.bd]
# descubrir la celda y sus conexiones ANTES de borrar (anotar respuestas):
get_bd_cells
get_bd_intf_pins u_soc_i2c/*
get_bd_nets -of_objects [get_bd_pins u_soc_i2c/*]
delete_bd_objs [get_bd_cells u_soc_i2c]

# ---------- 2) sustituir fuentes IIC -> I3C ----------
remove_files [get_files -quiet {*i2c_master.vhd *i2c_slave.vhd *i2c_mmio.vhd \
  *mem_subsys_i2c.vhd *soc_top_i2c.vhd *soc_top_i2c_wrap.v}]
remove_files -fileset constrs_1 [get_files -quiet *i2c_pins.xdc]
add_files -norecurse [list \
  $env(HOME)/i3c_ip/i3c_controller.vhd \
  $env(HOME)/i3c_ip/i3c_target.vhd \
  $env(HOME)/i3c_ip/i3c_mmio.vhd \
  $env(HOME)/i3c_ip/mem_subsys_i3c.vhd \
  $env(HOME)/i3c_ip/soc_top_i3c.vhd \
  $env(HOME)/i3c_ip/soc_top_i3c_wrap.v]
set_property file_type {VHDL 2008} [get_files $env(HOME)/i3c_ip/*.vhd]
add_files -fileset constrs_1 -norecurse $env(HOME)/i3c_ip/i3c_pins.xdc
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_i3c_wrap u_soc_i3c

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
# reloj y reset (descubrir el nombre real de la red del clk y del aresetn):
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_i3c/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_i3c/aresetn]

# esclavo s_axi <- salida del smartconnect (descubrir el M0x libre):
get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_i3c/s_axi]

# maestro del PL -> SI dedicado del NoC (S06_AXI con aclk6, heredado):
connect_bd_intf_net [get_bd_intf_pins u_soc_i3c/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
# verificar la asociacion de relojes (leccion #5): aclk6 SOLO S06_AXI y
# aclk0 SIN S06_AXI en su ASSOCIATED_BUSIF:
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk0]

# IRQs
connect_bd_net [get_bd_pins u_soc_i3c/irq_out]     [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins u_soc_i3c/i3c_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# pads: los puertos externos scl/sda del BD sobreviven al borrado de la celda
get_bd_ports
connect_bd_net [get_bd_pins u_soc_i3c/scl] [get_bd_ports scl]
connect_bd_net [get_bd_pins u_soc_i3c/sda] [get_bd_ports sda]

# ---------- 5) address map (EXPLICITO) ----------
assign_bd_address -target_address_space /u_soc_i3c/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_i3c/s_axi/reg0] -offset 0x80000000 -range 64K -force

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
# write_hw_platform -fixed -include_bit -force $env(HOME)/i3c_ip/i3c_soc.xsa
