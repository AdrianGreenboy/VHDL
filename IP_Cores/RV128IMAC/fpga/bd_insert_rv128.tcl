# bd_insert_rv128.tcl - inserts the RV128 prototype into a Block Design that already has
# the CIPS configured by GUI, connects it to M_AXI_FPD and runs implementation to PDI + XSA.
#   vivado -mode batch -source fpga/bd_insert_rv128.tcl -tclargs <project.xpr> [design_1]
set xpr [lindex $argv 0]
set bd  [lindex $argv 1]
if {$bd eq ""} { set bd design_1 }
open_project $xpr
open_bd_design [get_files $bd.bd]

set CIPS versal_cips_0
set CLK  $CIPS/pl0_ref_clk
set RSTN $CIPS/pl0_resetn
set CTRL_BASE 0xA4000000
if {[get_bd_cells -quiet $CIPS] eq ""} { error "no cell $CIPS in the BD (BOARD_GUIDE.md)" }
if {[get_bd_intf_pins -quiet $CIPS/M_AXI_FPD] eq ""} { error "M_AXI_FPD not enabled in the CIPS" }

create_bd_cell -type module -reference rv128_proto_wrap rv128
set_property -dict [list CONFIG.MEM_KB {128} CONFIG.TICK_DIV {50}] [get_bd_cells rv128]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl0
connect_bd_net [get_bd_pins $CLK] [get_bd_pins rst_pl0/slowest_sync_clk] [get_bd_pins rv128/clk]
connect_bd_net [get_bd_pins $RSTN] [get_bd_pins rst_pl0/ext_reset_in]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins rv128/aresetn]

create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_ctrl
set_property CONFIG.NUM_SI {1} [get_bd_cells sc_ctrl]
connect_bd_intf_net [get_bd_intf_pins $CIPS/M_AXI_FPD] [get_bd_intf_pins sc_ctrl/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sc_ctrl/M00_AXI] [get_bd_intf_pins rv128/s_axi_ctrl]
connect_bd_net [get_bd_pins $CLK] [get_bd_pins sc_ctrl/aclk] [get_bd_pins $CIPS/m_axi_fpd_aclk]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins sc_ctrl/aresetn]

assign_bd_address -target_address_space /$CIPS/M_AXI_FPD [get_bd_addr_segs rv128/s_axi_ctrl/reg0] -range 256K -offset $CTRL_BASE
validate_bd_design
save_bd_design

make_wrapper -files [get_files $bd.bd] -top -import -force
set_property top ${bd}_wrapper [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_device_image -jobs 4
wait_on_run impl_1
open_run impl_1
set d [file dirname $xpr]
report_timing_summary -file $d/timing_summary.rpt
report_utilization -file $d/utilization.rpt
write_hw_platform -fixed -include_bit -force $d/rv128_proto_te0950.xsa
puts "WNS: [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]"
puts "PDI: [glob -nocomplain $d/*.runs/impl_1/*.pdi]"
puts "XSA: $d/rv128_proto_te0950.xsa"
