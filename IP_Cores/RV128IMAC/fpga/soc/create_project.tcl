# create_project.tcl - RV128IMAC SoC (core dual, DDR por el NoC) en la TE0950, M5.
# Mismo flujo que RV64IMAC/fpga (validado en la TE0950). Vivado 2025.2.1.
#   1) vivado -mode batch -source fpga/soc/create_project.tcl -tclargs te0950
#   2) GUI: Block Design design_1 con CIPS + NoC (LPDDR4, M_AXI_FPD, pl0_ref_clk 60 MHz since v1.5)
#   3) vivado -mode batch -source fpga/soc/bd_insert.tcl -tclargs <xpr> design_1
set board [lindex $argv 0]
if {$board eq ""} { set board te0950 }
switch -- $board {
  te0950 { set part xcve2302-sfva784-1LP-e-S; set bpat *te0950* }
  default { error "placa desconocida: $board (te0950)" }
}
if {[info exists ::env(BOARD_PART)]} {
  set bp $::env(BOARD_PART)
} else {
  set bp [lindex [lsort -decreasing [get_board_parts -quiet $bpat]] 0]
}
if {$bp eq ""} { error "no hay board files para $board: instala los de Trenz o exporta BOARD_PART" }
set here [file normalize [file dirname [info script]]]
set root [file normalize $here/../..]
set proj rv128_soc_$board

create_project $proj $here/$proj -part $part -force
set_property board_part $bp [current_project]
puts "board part: $bp"
set_property target_language VHDL [current_project]

set rtl {
  rv128_pkg.vhd rv128_mmu_pkg.vhd rv128_tlb.vhd rv128_ptw.vhd rv128_muldiv.vhd rv128_csr.vhd
  rv128_core.vhd sram_1rw.vhd rv128_axi_master.vhd rv128_dcache.vhd rv128_icache.vhd rv128_cpu.vhd
  rv128_clint.vhd rv128_plic.vhd rv128_uart.vhd rv128_periph.vhd rv128_soc.vhd
}
foreach f $rtl { add_files -norecurse $root/rtl/$f }
# boot ROM de la placa (DTS de la placa: 60 MHz, ttyS0 115200), no la de simulacion
if {![file exists $here/gen/rv128_bootrom_pkg.vhd]} {
  error "falta fpga/soc/gen/rv128_bootrom_pkg.vhd: python3 sw/bootrom/build_bootrom.py --dts sw/bootrom/rv128_soc_fpga.dts --out fpga/soc/gen/rv128_bootrom_pkg.vhd"
}
add_files -norecurse $here/gen/rv128_bootrom_pkg.vhd
add_files -norecurse $here/rv128_soc_top.vhd
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
add_files -norecurse $here/rv128_soc_wrap.v
update_compile_order -fileset sources_1
puts "proyecto $proj creado para $part"
puts "siguiente: Block Design con CIPS + NoC por GUI (fpga/soc/BOARD_GUIDE.md), luego fpga/soc/bd_insert.tcl"
