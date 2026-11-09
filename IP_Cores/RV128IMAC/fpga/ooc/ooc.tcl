# ooc.tcl - out-of-context implementation on the VE2302 (TE0950): resources and timing.
#   vivado -mode batch -source fpga/ooc/ooc.tcl -tclargs <top> [period_ns]
#     top: core128 (rv128_core) | core64 (rv64_core, from ../RV64IMAC) | proto (rv128_proto_top)
#          cpu128 (rv128_cpu: core + I$/D$ + AXI4 128) | cpu64 (rv64_cpu) | soc128 (rv128_soc)
# Reports in fpga/ooc/<top>/; last line of the log: RESULT top=... LUT=... FF=... WNS=... fmax=...
set top    [lindex $argv 0]
set period [lindex $argv 1]
if {$period eq ""} { set period 10.000 }
set root [file normalize [file dirname [info script]]/../..]
set r64  [file normalize $root/../RV64IMAC/rtl]
set out  $root/fpga/ooc/$top
file mkdir $out
create_project -in_memory -part xcve2302-sfva784-1LP-e-S
switch -- $top {
  core128 {
    foreach f {rv128_pkg rv128_mmu_pkg rv128_tlb rv128_ptw rv128_muldiv rv128_csr rv128_core} { read_vhdl -vhdl2008 $root/rtl/$f.vhd }
    set ent rv128_core
  }
  core64 {
    foreach f {rv64_pkg rv64_mmu_pkg rv64_tlb rv64_ptw rv64_muldiv rv64_csr rv64_core} { read_vhdl -vhdl2008 $r64/$f.vhd }
    set ent rv64_core
  }
  proto {
    foreach f {rv128_pkg rv128_mmu_pkg rv128_tlb rv128_ptw rv128_muldiv rv128_csr rv128_core} { read_vhdl -vhdl2008 $root/rtl/$f.vhd }
    read_vhdl -vhdl2008 $root/fpga/rv128_proto_top.vhd
    set ent rv128_proto_top
  }
  cpu128 - soc128 {
    foreach f {rv128_pkg rv128_mmu_pkg rv128_tlb rv128_ptw rv128_muldiv rv128_csr rv128_core
               sram_1rw rv128_axi_master rv128_dcache rv128_icache rv128_cpu} { read_vhdl -vhdl2008 $root/rtl/$f.vhd }
    if {$top eq "soc128"} {
      foreach f {rv128_bootrom_pkg rv128_clint rv128_plic rv128_uart rv128_periph rv128_soc} { read_vhdl -vhdl2008 $root/rtl/$f.vhd }
      set ent rv128_soc
    } else {
      set ent rv128_cpu
    }
  }
  cpu64 {
    foreach f {rv64_pkg rv64_mmu_pkg rv64_tlb rv64_ptw rv64_muldiv rv64_csr rv64_core
               sram_1rw rv64_axi_master rv64_dcache rv64_icache rv64_cpu} { read_vhdl -vhdl2008 $r64/$f.vhd }
    set ent rv64_cpu
  }
  default { error "top desconocido: $top (core128 | core64 | proto | cpu128 | cpu64 | soc128)" }
}
synth_design -top $ent -mode out_of_context -flatten_hierarchy rebuilt
create_clock -name clk -period $period [get_ports clk]
report_utilization -file $out/util_synth.rpt
opt_design; place_design; phys_opt_design; route_design
report_timing_summary -max_paths 20 -file $out/timing.rpt
report_utilization -file $out/util.rpt
report_utilization -hierarchical -file $out/util_hier.rpt
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set lut  [llength [get_cells -hier -quiet -filter {REF_NAME =~ LUT*}]]
set ff   [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == REGISTER}]]
set dsp  [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == ARITHMETIC}]]
set bram [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == BLOCKRAM}]]
set lram [llength [get_cells -hier -quiet -filter {REF_NAME =~ RAM32* || REF_NAME =~ RAM64* || REF_NAME =~ RAM16* || REF_NAME =~ RAM128* || REF_NAME =~ RAM256*}]]
set fmax [format %.1f [expr {1000.0 / ($period - $wns)}]]
puts "RESULT top=$top LUT=$lut FF=$ff LUTRAM=$lram DSP=$dsp BRAM=$bram period=$period WNS=$wns fmax=${fmax}MHz"
