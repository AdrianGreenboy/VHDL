# ptp_soc.tcl — construccion del SoC PTP en Vivado 2025.2.1 (TE0950 / Versal
# xcve2302-sfva784-1LP-e-S). NO ejecutar como bloque: correr comando a comando,
# leyendo cada respuesta (los comandos compuestos con puts/; se truncan al pegar).
#
# Flujo (basado en el clon del proyecto eth_soc de la familia):
#   1. Clonar el proyecto eth_soc a ptp_soc (save_project_as) y limpiar residuos
#   2. Anadir las fuentes RTL del IP PTP
#   3. Instanciar ptp_axil en el BD y cablear el NoC PL master -> S_AXI del IP
#   4. Asignar la direccion base 0x8000_0000 / 64K
#   5. Verificar pines del banco 302, generar bitstream/PDI
# ---------------------------------------------------------------------------

# --- 0. entorno (en shell, antes de abrir Vivado) ---
# source ~/Xilinx/2025.2.1/Vivado/settings64.sh
# vivado -mode tcl

# --- 1. clonar el proyecto base y limpiar (uno por uno) ---
# open_project ~/eth_soc/eth_soc.xpr
# save_project_as ptp_soc ~/vhdl_repo/IP_Cores/PTP/vivado/ptp_soc -force
# close_project
# open_project ~/vhdl_repo/IP_Cores/PTP/vivado/ptp_soc/ptp_soc.xpr

# limpiar residuos del clon (el BD queda como referencia remota al proyecto origen):
# write_bd_tcl -force ~/vhdl_repo/IP_Cores/PTP/vivado/ptp_bd.tcl
# remove_files [get_files *.bd]
# el checkpoint incremental y los .dcp/nocattrs remotos:
# set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
# foreach f [get_files -all *.dcp] { if {[string match "*eth_soc*" $f]} { remove_files $f } }
# reset_run synth_1
# reset_run impl_1

# --- 2. anadir fuentes RTL del IP PTP ---
# el orden de analisis lo resuelve Vivado, pero anadir todos:
set ptp_rtl ~/vhdl_repo/IP_Cores/PTP/rtl
add_files -norecurse [glob $ptp_rtl/*.vhd]
# marcar VHDL-2008 en todos los ficheros del IP
foreach f [get_files $ptp_rtl/*.vhd] { set_property FILE_TYPE {VHDL 2008} [get_files $f] }
update_compile_order -fileset sources_1

# --- 3. reconstruir el BD desde el tcl y anadir el IP ---
# source ~/vhdl_repo/IP_Cores/PTP/vivado/ptp_bd.tcl
# open_bd_design [get_files *.bd]

# anadir el modulo RTL ptp_axil como referencia en el BD:
# create_bd_cell -type module -reference ptp_axil ptp_0

# generar el target del modulo (necesario tras anadir la referencia):
# generate_target all [get_files *.bd]

# --- 4. cablear el NoC: PL AXI master -> S_AXI del IP ---
# En Versal, la automatizacion de conexion enruta el PL master a S_AXI_LPD
# (0 DDR). SIEMPRE cablear a mano por Tcl hacia un puerto NoC libre.
# Ejemplo (ajustar los nombres de instancia a tu BD):
#   connect_bd_intf_net [get_bd_intf_pins axi_noc_0/M06_AXI] [get_bd_intf_pins ptp_0/s_axi]
#   connect_bd_net [get_bd_pins ptp_0/s_axi_aclk]    [get_bd_pins <clk_pl_source>]
#   connect_bd_net [get_bd_pins ptp_0/s_axi_aresetn] [get_bd_pins <rstn_pl_source>]
# irq hacia el PS (o hacia un concat de interrupciones existente):
#   connect_bd_net [get_bd_pins ptp_0/irq] [get_bd_pins <irq_concat>/In<N>]

# --- 5. asignar la direccion base 0x8000_0000 / 64K ---
# assign_bd_address -target_address_space [get_bd_addr_spaces <cpu>/Data] \
#   [get_bd_addr_segs ptp_0/s_axi/reg0] -offset 0x80000000 -range 64K
# validate_bd_design
# save_bd_design

# --- 6. verificar pines del banco 302 (PTP en LOOP_INT no anade pines nuevos) ---
# El IP en v1 no expone MII a pads (LOOP_INT interno), asi que NO hay
# constraints de pin nuevos. Si en el futuro se saca MII a pads, verificar:
#   get_package_pins -filter {BANK == 302}
# antes de inventar cualquier pin (los pines inventados dan CRITICAL WARNING).

# --- 7. generar wrapper HDL, sintesis, implementacion, PDI ---
# make_wrapper -files [get_files *.bd] -top
# add_files -norecurse <ruta_al_wrapper>.vhd    ;# si no se anade solo
# update_compile_order -fileset sources_1
# reset_run synth_1
# launch_runs synth_1 -jobs 8
# wait_on_run synth_1
# launch_runs impl_1 -to_step write_device_image -jobs 8
# wait_on_run impl_1

# el PDI queda en:
#   ptp_soc/ptp_soc.runs/impl_1/<top>_wrapper.pdi
# NO hot-load: PetaLinux repackea BOOT.BIN (el PLM rechaza PDI suelto con
# Image Header Table Validation failed / 0x03024001).
