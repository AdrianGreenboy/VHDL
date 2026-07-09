# ============================================================================
#  bd_i2c_steps.tcl - Pasos del block design del SoC + IP IIC (TE0950)
#
#  ESTE ARCHIVO NO SE "SOURCEA" COMPLETO: los comandos van UNO POR UNO en la
#  consola Tcl de Vivado, leyendo cada respuesta (leccion USART #4: un
#  connect_bd_net fallo SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA RECOMENDADA (mas rapida y de menor riesgo): clonar el proyecto Vivado
#  del USART, quitar usart_axi_top del BD y sus fuentes, agregar las fuentes
#  del IIC y sustituir el module reference. El BD del USART ya tiene CIPS,
#  NoC, resets, relojes y address map correctos y auditados. Los pasos de
#  abajo son la construccion desde cero por si prefieres proyecto limpio.
#
#  Lecciones USART aplicadas (README USART §13, NO repetir errores):
#   (3) NUNCA Connection Automation para maestros del PL -> conectar por Tcl
#       a un SI dedicado del NoC y auditar con bd_review.tcl ANTES de sintesis
#   (4) fabric reset habilitado en el CIPS; Tcl de reparacion uno por uno
#   (5) SI nuevo del NoC: asociar su aclk dedicada Y quitar la asociacion de
#       aclk0, o hay CDC silencioso
#   (6) assign_bd_address explicito del SI nuevo a DDR_LOW0 (los warnings
#       BD 41-2670 delatan segmentos faltantes; validate pasa igual)
#   (7) el top de implementacion es el WRAPPER DEL BD (make_wrapper)
#   (8) PL CLK0 del CIPS a 100 MHz (todo el stack asume 100M)
# ============================================================================

# ---------- 0) proyecto ----------
create_project i2c_soc ~/i2c_ip/vivado_i2c -part xcve2302-sfva784-1LP-e-S
set_property target_language Verilog [current_project]

# fuentes compartidas del SoC (desde su origen, no se duplican)
add_files -norecurse [glob ~/rv32i/riscv_pkg.vhd ~/rv32i/alu.vhd ~/rv32i/regfile.vhd \
  ~/rv32i/muldiv.vhd ~/rv32i/immgen.vhd ~/rv32i/control.vhd ~/rv32i/csr.vhd \
  ~/rv32i/dp_ram.vhd ~/rv32i/cpu_pipeline.vhd ~/rv32i/dma_burst.vhd ~/rv32i/axil_soc.vhd]
add_files -norecurse ~/spi_ip/byte_fifo.vhd
add_files -norecurse [glob ~/i2c_ip/i2c_master.vhd ~/i2c_ip/i2c_slave.vhd \
  ~/i2c_ip/i2c_mmio.vhd ~/i2c_ip/mem_subsys_i2c.vhd ~/i2c_ip/soc_top_i2c.vhd \
  ~/i2c_ip/soc_top_i2c_wrap.v]
set_property file_type {VHDL 2008} [get_files *.vhd]
add_files -fileset constrs_1 -norecurse ~/i2c_ip/i2c_pins.xdc

# ---------- 1) BD: CIPS + NoC ----------
create_bd_design "bd_i2c"

create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0
# Block Automation del CIPS con el preset del TE0950 (como en el USART).
# DESPUES, a mano en el GUI o por Tcl:
#   - PL CLK0 = 100 MHz  (leccion #8: el default 240 MHz rompe WNS en muldiv)
#   - fabric reset habilitado (pl_resetn0)  (leccion #4)
#   - un maestro PS (M_AXI_FPD o via NoC) para el s_axi del SoC
#   - IRQ ports pl_ps_irq0 y pl_ps_irq1 habilitados

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_0
# Configurar el NoC:
#   - un SI dedicado para el maestro del PL (p. ej. S06_AXI si sigues la
#     numeracion del USART), NUM_SI acorde
#   - NUM_CLKS += 1 y una aclk dedicada (p. ej. aclk6) para ese SI
#   - MC/DDR segun el preset del TE0950 (igual que el proyecto USART)

# ---------- 2) module reference del SoC ----------
create_bd_cell -type module -reference soc_top_i2c_wrap soc_i2c_0

# ---------- 3) conexiones (UNO POR UNO, leyendo cada respuesta) ----------
# reloj y reset del PL
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins soc_i2c_0/aclk]
# (si usas proc_sys_reset: instancialo sobre pl0_ref_clk y conecta su
#  peripheral_aresetn a soc_i2c_0/aresetn; el USART lo hizo asi)

# maestro del PL -> SI dedicado del NoC (leccion #3: NADA de Connection Automation)
connect_bd_intf_net [get_bd_intf_pins soc_i2c_0/m_axi] [get_bd_intf_pins axi_noc_0/S06_AXI]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk6]
# leccion #5: asociar el SI nuevo a SU aclk y QUITAR la asociacion de aclk0
set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S06_AXI}] [get_bd_pins /axi_noc_0/aclk6]
# (verificar que aclk0 ya no lista S06_AXI en su ASSOCIATED_BUSIF)

# esclavo s_axi <- maestro del PS (smartconnect si hace falta ancho/protocolo)
# connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_FPD] [get_bd_intf_pins soc_i2c_0/s_axi]

# IRQs
connect_bd_net [get_bd_pins soc_i2c_0/irq_out]     [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins soc_i2c_0/i2c_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

# pads IIC del wrapper -> puertos externos del BD
make_bd_pins_external [get_bd_pins soc_i2c_0/scl]
make_bd_pins_external [get_bd_pins soc_i2c_0/sda]
# renombrar los puertos externos a 'scl' y 'sda' para que casen con el XDC
set_property name scl [get_bd_ports scl_0]
set_property name sda [get_bd_ports sda_0]

# ---------- 4) address map (leccion #6: EXPLICITO) ----------
# maestro del PL hacia la DDR por el SI nuevo:
assign_bd_address -target_address_space /soc_i2c_0/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
# esclavo del SoC visto por el PS en 0x8000_0000, 64 KB:
# assign_bd_address -target_address_space /versal_cips_0/M_AXI_FPD \
#   [get_bd_addr_segs soc_i2c_0/s_axi/reg0] -offset 0x80000000 -range 64K

# ---------- 5) auditoria ANTES de gastar sintesis ----------
# validate_bd_design dice OK aunque el diseno este validamente equivocado
# (leccion #3): correr bd_review.tcl (agnostico al BD, vive en ambos proyectos)
validate_bd_design
source ~/rv32i/bd_review.tcl

# ---------- 6) wrapper del BD = top de implementacion (leccion #7) ----------
make_wrapper -files [get_files bd_i2c.bd] -top
add_files -norecurse [get_property DIRECTORY [current_project]]/i2c_soc.gen/sources_1/bd/bd_i2c/hdl/bd_i2c_wrapper.v
set_property top bd_i2c_wrapper [current_fileset]

# ---------- 7) sintesis / implementacion / bitstream ----------
# launch_runs synth_1 -jobs 8
# launch_runs impl_1 -to_step write_device_image -jobs 8
