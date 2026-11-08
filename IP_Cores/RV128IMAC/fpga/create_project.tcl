# create_project.tcl - RV128IMAC bare-metal prototype on the TE0950 (VE2302). Vivado 2025.2.1.
# Three phases (BOARD_GUIDE.md):
#   1) vivado -mode batch -source fpga/create_project.tcl          project + sources
#   2) GUI: Block Design design_1 with CIPS (+ NoC/LPDDR4 as in your TE0950 projects),
#      M_AXI_FPD enabled, pl0_ref_clk 50 MHz + pl0_resetn
#   3) vivado -mode batch -source fpga/bd_insert_rv128.tcl -tclargs <xpr> design_1
set part xcve2302-sfva784-1LP-e-S
if {[info exists ::env(BOARD_PART)]} {
  set bp $::env(BOARD_PART)
} else {
  set bp [lindex [lsort -decreasing [get_board_parts -quiet *te0950*]] 0]
}
if {$bp eq ""} { error "no TE0950 board files (get_board_parts *te0950* is empty): install them or export BOARD_PART" }
set here [file normalize [file dirname [info script]]]
set root [file normalize $here/..]
set proj rv128_proto_te0950
create_project $proj $here/$proj -part $part -force
set_property board_part $bp [current_project]
set_property target_language VHDL [current_project]
foreach f {rv128_pkg rv128_mmu_pkg rv128_tlb rv128_ptw rv128_muldiv rv128_csr rv128_core} { add_files -norecurse $root/rtl/$f.vhd }
add_files -norecurse $here/rv128_proto_top.vhd
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
add_files -norecurse $here/rv128_proto_wrap.v
update_compile_order -fileset sources_1
puts "project $proj created ($part, $bp)"
puts "next: Block Design with CIPS by GUI (BOARD_GUIDE.md), then bd_insert_rv128.tcl"
