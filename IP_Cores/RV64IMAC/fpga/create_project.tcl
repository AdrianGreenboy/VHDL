# create_project.tcl - prototipo RV64IMAC en Versal. Vivado 2025.2.1.
# NO VALIDADO EN SILICIO TODAVIA (Paso 9).
#
# Uso (en tres fases; ver BD_GUIDE.md):
#   1) vivado -mode batch -source create_project.tcl -tclargs te0950   (o vck190)
#        crea el proyecto y anade las fuentes VHDL-2008 + el envoltorio Verilog
#   2) GUI: Block Design con CIPS + NoC (DDR, M_AXI_FPD, pl0_ref_clk 50 MHz)
#   3) vivado -mode batch -source bd_insert_rv64.tcl
#        inserta rv64_proto_wrap, lo conecta al NoC / M_AXI_FPD y genera el PDI

set board [lindex $argv 0]
if {$board eq ""} { set board te0950 }
switch -- $board {
  te0950 { set part xcve2302-sfva784-1LP-e-S; set bpat *te0950* }
  vck190 { set part xcvc1902-vsva2197-2MP-e-S; set bpat *vck190* }
  default { error "placa desconocida: $board (te0950 | vck190)" }
}
# board part: sin el, la Block Automation del NoC pone una DDR4 generica sin pines
# (error Mig 66-441 en opt_design). Se puede forzar con BOARD_PART=<nombre>.
if {[info exists ::env(BOARD_PART)]} {
  set bp $::env(BOARD_PART)
} else {
  set bp [lindex [lsort -decreasing [get_board_parts -quiet $bpat]] 0]
}
if {$bp eq ""} {
  error "no hay board files para $board (get_board_parts $bpat vacio): instala los de Trenz/AMD o exporta BOARD_PART"
}
set here [file normalize [file dirname [info script]]]
set root [file normalize $here/..]
set proj rv64_proto_$board

create_project $proj $here/$proj -part $part -force
set_property board_part $bp [current_project]
puts "board part: $bp"
set_property target_language VHDL [current_project]

# --- RTL del SoC (VHDL-2008). La boot ROM es la de la placa (fpga/gen), no la de simulacion.
set rtl {
  rv64_pkg.vhd rv64_mmu_pkg.vhd rv64_tlb.vhd rv64_ptw.vhd rv64_muldiv.vhd rv64_csr.vhd
  rv64_core.vhd sram_1rw.vhd rv64_axi_master.vhd rv64_dcache.vhd rv64_icache.vhd rv64_cpu.vhd
  rv64_clint.vhd rv64_plic.vhd rv64_uart.vhd rv64_periph.vhd rv64_soc.vhd
}
foreach f $rtl { add_files -norecurse $root/rtl/$f }
if {![file exists $here/gen/rv64_bootrom_pkg.vhd]} {
  error "falta fpga/gen/rv64_bootrom_pkg.vhd: python3 sw/bootrom/build_bootrom.py --dts sw/bootrom/rv64_soc_fpga.dts --out fpga/gen/rv64_bootrom_pkg.vhd"
}
add_files -norecurse $here/gen/rv64_bootrom_pkg.vhd
add_files -norecurse $here/rv64_proto_top.vhd
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
# --- envoltorio Verilog (el BD no acepta un top VHDL-2008 como module reference)
add_files -norecurse $here/rv64_proto_wrap.v

# --- IP_Cores opcionales: export IP_CORES=<VHDL>/IP_Cores y USE_USART=1 para la ranura 0
if {[info exists ::env(IP_CORES)] && [info exists ::env(USE_USART)]} {
  set ipc $::env(IP_CORES)
  foreach f {SPI/byte_fifo.vhd USART/usart_engine.vhd USART/usart_mmio.vhd USART/usart_dma.vhd USART/usart_axi_top.vhd} {
    add_files -norecurse $ipc/$f
    set_property file_type {VHDL 2008} [get_files [file tail $f]]
  }
}

update_compile_order -fileset sources_1
puts "proyecto $proj creado para $part"
puts "siguiente: Block Design con CIPS + NoC por GUI (BD_GUIDE.md), luego bd_insert_rv64.tcl"
