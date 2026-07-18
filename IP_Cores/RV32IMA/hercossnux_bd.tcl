#!/usr/bin/env tclsh
# =============================================================
# hercossnux_bd.tcl - Paso 7b: block design del SoC HERCOSSNUX
# para Trenz TE0950 (AMD Versal xcve2302-sfva784-1LP-e-S).
#
# IMPORTANTE - por que este script existe:
#   En Versal, la Connection Automation rutea el master AXI de la
#   PL a S_AXI_LPD, que NO tiene camino a la DDR. El resultado es
#   un diseno que implementa sin errores y falla en silicio con
#   lecturas a cero. Todo el cableado del NoC se hace aqui a mano.
#
#   Ademas Vivado NO expande '~' en Tcl: todas las rutas usan
#   $env(HOME).
#
# Uso (desde la consola Tcl de Vivado, NO por bloques pegados):
#   source $env(HOME)/rv32ima/hercossnux_bd.tcl
#
# Si se ejecuta interactivamente, mejor comando a comando leyendo
# la respuesta de cada uno: los fallos silenciosos viven en los
# bloques pegados.
# =============================================================

set PRJ_DIR  $env(HOME)/vivado/hercossnux
set PRJ_NAME hercossnux
set SRC_DIR  $env(HOME)/rv32ima
set PART     xcve2302-sfva784-1LP-e-S
set BD_NAME  hercossnux_bd

# direcciones (deben coincidir con los generics del top y el DTS)
set DDR_RESERVED_BASE 0x70000000
set DDR_RESERVED_SIZE 64M
set CTRL_BASE         0x80000000
set CTRL_RANGE        64K

puts "== creando proyecto en $PRJ_DIR =="
file mkdir $PRJ_DIR
create_project $PRJ_NAME $PRJ_DIR -part $PART -force

# ---- fuentes RTL del SoC ----
set RTL_FILES [list \
  $SRC_DIR/rv32_csr_trap.vhd \
  $SRC_DIR/rv32_amo_unit.vhd \
  $SRC_DIR/rv32ima_core.vhd \
  $SRC_DIR/rv32_mem_adapter.vhd \
  $SRC_DIR/rv32_uart.vhd \
  $SRC_DIR/rv32_syscon.vhd \
  $SRC_DIR/rv32_clint.vhd \
  $SRC_DIR/rv32_mmio_bus.vhd \
  $SRC_DIR/rv32ima_soc_top.vhd ]
add_files -norecurse $RTL_FILES
set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets sources_1]]
update_compile_order -fileset sources_1

# =============================================================
# BLOCK DESIGN
# =============================================================
puts "== creando block design =="
create_bd_design $BD_NAME

# ---- CIPS (PS de Versal) ----
puts "== CIPS =="
create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0
# Preset de la placa: expone PS-PL y habilita el LPD/FPD segun la TE0950.
# Si el preset del board no esta disponible, se configura a mano abajo.
set_property -dict [list \
  CONFIG.PS_PMC_CONFIG {PMC_QSPI_PERIPHERAL_ENABLE 1 \
                        PS_USE_M_AXI_FPD 1 \
                        PS_USE_M_AXI_LPD 0 \
                        PS_NUM_FABRIC_RESETS 1} \
] [get_bd_cells versal_cips_0]

# ---- NoC ----
# El master del SoC entra al NoC y sale al controlador de DDR. Este es
# el camino que la Connection Automation NO construye correctamente.
puts "== NoC =="
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_0
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {0} \
  CONFIG.NUM_CLKS {2} \
  CONFIG.NUM_MC {1} \
  CONFIG.NUM_MCP {1} \
  CONFIG.MC_CHAN_REGION0 {DDR_CH1} \
] [get_bd_cells axi_noc_0]

# el unico slave interface del NoC recibe el master del SoC y su
# destino es el controlador de memoria (MC), no otro puerto AXI
set_property -dict [list \
  CONFIG.CONNECTIONS {MC_0 {read_bw {1720} write_bw {1720} read_avg_burst {4} write_avg_burst {4}}} \
] [get_bd_intf_pins /axi_noc_0/S00_AXI]

set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S00_AXI}] \
  [get_bd_pins /axi_noc_0/aclk0]

# ---- el SoC como modulo RTL ----
puts "== SoC RV32IMA =="
create_bd_cell -type module -reference rv32ima_soc_top rv32ima_soc_0

# ---- interconnect para el banco de control (PS -> SoC) ----
puts "== interconnect de control =="
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_0
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] \
  [get_bd_cells smartconnect_0]

# ---- reset ----
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_0

puts "== conexiones (a mano, sin Connection Automation) =="

# reloj del PL: pl_clk0 del CIPS alimenta todo
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]

connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] \
               [get_bd_pins rv32ima_soc_0/aclk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins rv32ima_soc_0/aresetn]

connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] \
               [get_bd_pins smartconnect_0/aclk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins smartconnect_0/aresetn]

connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] \
               [get_bd_pins axi_noc_0/aclk0]

# camino de control: PS (M_AXI_FPD) -> smartconnect -> S_AXI del SoC
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_FPD] \
                    [get_bd_intf_pins smartconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] \
                    [get_bd_intf_pins rv32ima_soc_0/S_AXI]

# camino de datos: SoC (M_AXI) -> NoC -> DDR
# ESTE es el enlace que la automation rutea mal en Versal
connect_bd_intf_net [get_bd_intf_pins rv32ima_soc_0/M_AXI] \
                    [get_bd_intf_pins axi_noc_0/S00_AXI]

puts "== mapa de direcciones =="
# el banco de control visible desde el PS
assign_bd_address -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] \
  [get_bd_addr_segs rv32ima_soc_0/S_AXI/reg0] -force
set_property offset $CTRL_BASE [get_bd_addr_segs \
  versal_cips_0/M_AXI_FPD/SEG_rv32ima_soc_0_reg0]
set_property range $CTRL_RANGE [get_bd_addr_segs \
  versal_cips_0/M_AXI_FPD/SEG_rv32ima_soc_0_reg0]

# el espacio de DDR visible desde el master del SoC
assign_bd_address -target_address_space [get_bd_addr_spaces rv32ima_soc_0/M_AXI] \
  [get_bd_addr_segs axi_noc_0/S00_AXI/C0_DDR_LOW0] -force

puts "== validando =="
validate_bd_design
save_bd_design

# ---- wrapper HDL ----
make_wrapper -files [get_files $PRJ_DIR/$PRJ_NAME.srcs/sources_1/bd/$BD_NAME/$BD_NAME.bd] -top
add_files -norecurse $PRJ_DIR/$PRJ_NAME.gen/sources_1/bd/$BD_NAME/hdl/${BD_NAME}_wrapper.vhd
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "=============================================="
puts " BD creado. Verificaciones antes de implementar:"
puts ""
puts " 1) el master del SoC llega a la DDR (NO a S_AXI_LPD):"
puts "    get_bd_addr_segs -of \[get_bd_addr_spaces rv32ima_soc_0/M_AXI\]"
puts "    -> debe listar C0_DDR_LOW0, y NINGUN segmento LPD"
puts ""
puts " 2) el offset de DDR asignado coincide con DDR_BASE_PHYS"
puts "    del top (0x70000000) y con la reserva del device tree"
puts ""
puts " 3) lanzar sintesis e implementacion:"
puts "    launch_runs impl_1 -to_step write_device_image -jobs 8"
puts "=============================================="
