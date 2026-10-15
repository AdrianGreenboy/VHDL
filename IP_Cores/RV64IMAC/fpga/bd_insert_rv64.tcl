# bd_insert_rv64.tcl - inserta el SoC RV64IMAC en un Block Design que ya tiene
# CIPS + NoC configurados por GUI (BD_GUIDE.md), lo conecta y genera el PDI.
# NO VALIDADO EN SILICIO TODAVIA (Paso 9). Ajustar los nombres de las instancias.
#
#   vivado -mode batch -source bd_insert_rv64.tcl -tclargs <proyecto.xpr> <bd>

set xpr  [lindex $argv 0]
set bd   [lindex $argv 1]
if {$bd eq ""} { set bd design_1 }
open_project $xpr
open_bd_design [get_files $bd.bd]

# --- nombres de las instancias creadas por GUI (cambiar si son otros)
set CIPS  versal_cips_0
set NOC   axi_noc_0
set CLK   $CIPS/pl0_ref_clk
set RSTN  $CIPS/pl0_resetn
set CTRL_BASE 0xA4000000              ;# como el RV32IMA: ventana valida de M_AXI_FPD

foreach c [list $CIPS $NOC] {
  if {[get_bd_cells -quiet $c] eq ""} { error "no existe la celda $c en el BD (ver BD_GUIDE.md)" }
}

# --- el SoC como module reference
create_bd_cell -type module -reference rv64_proto_wrap rv64
set_property -dict [list CONFIG.TICK_DIV {50} CONFIG.DRAM_PHYS {0x0000000070000000} \
                         CONFIG.DRAM_MASK {0x0000000007FFFFFF}] [get_bd_cells rv64]

# --- reset sincronizado de la plataforma
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl0
connect_bd_net [get_bd_pins $CLK] [get_bd_pins rst_pl0/slowest_sync_clk] [get_bd_pins rv64/clk]
connect_bd_net [get_bd_pins $RSTN] [get_bd_pins rst_pl0/ext_reset_in]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins rv64/aresetn]

# --- DRAM: una entrada AXI mas en el NoC hacia el controlador de memoria
set nsi [get_property CONFIG.NUM_SI [get_bd_cells $NOC]]
set nck [get_property CONFIG.NUM_CLKS [get_bd_cells $NOC]]
set_property -dict [list CONFIG.NUM_SI [expr {$nsi + 1}] CONFIG.NUM_CLKS [expr {$nck + 1}]] [get_bd_cells $NOC]
set si [format "S%02d_AXI" $nsi]
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {800} write_bw {800} read_avg_burst {4} write_avg_burst {4}}} \
                         CONFIG.CATEGORY {pl}] [get_bd_intf_pins $NOC/$si]
connect_bd_intf_net [get_bd_intf_pins rv64/m_axi_dram] [get_bd_intf_pins $NOC/$si]
connect_bd_net [get_bd_pins $CLK] [get_bd_pins $NOC/aclk$nck]
set_property CONFIG.ASSOCIATED_BUSIF $si [get_bd_pins $NOC/aclk$nck]

# --- banco de control desde M_AXI_FPD (SmartConnect)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_ctrl
set_property CONFIG.NUM_SI {1} [get_bd_cells sc_ctrl]
connect_bd_intf_net [get_bd_intf_pins $CIPS/M_AXI_FPD] [get_bd_intf_pins sc_ctrl/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sc_ctrl/M00_AXI] [get_bd_intf_pins rv64/s_axi_ctrl]
connect_bd_net [get_bd_pins $CLK] [get_bd_pins sc_ctrl/aclk] [get_bd_pins $CIPS/m_axi_fpd_aclk]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins sc_ctrl/aresetn]

# --- IP_Cores: sin cores, rdata a cero e irq a cero (conectar aqui la USART, etc.)
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero512
set_property -dict [list CONFIG.CONST_WIDTH {512} CONFIG.CONST_VAL {0}] [get_bd_cells zero512]
connect_bd_net [get_bd_pins zero512/dout] [get_bd_pins rv64/mm_rdata]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero16
set_property -dict [list CONFIG.CONST_WIDTH {16} CONFIG.CONST_VAL {0}] [get_bd_cells zero16]
connect_bd_net [get_bd_pins zero16/dout] [get_bd_pins rv64/irq_ip]

# --- direcciones
assign_bd_address -target_address_space /$CIPS/M_AXI_FPD [get_bd_addr_segs rv64/s_axi_ctrl/reg0] -range 64K -offset $CTRL_BASE
assign_bd_address -target_address_space /rv64/m_axi_dram [get_bd_addr_segs $NOC/$si/C0_DDR_LOW0]
validate_bd_design
save_bd_design

# --- implementacion hasta PDI
make_wrapper -files [get_files $bd.bd] -top -import -force
set_property top ${bd}_wrapper [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_device_image -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file [file dirname $xpr]/timing_summary.rpt
report_utilization -file [file dirname $xpr]/utilization.rpt
puts "PDI: [glob -nocomplain [file dirname $xpr]/*.runs/impl_1/*.pdi]"
