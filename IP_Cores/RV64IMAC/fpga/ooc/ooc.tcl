# Implementacion OOC del rv64_proto_top en la VE2302 a 50 MHz: recursos y timing
set root [file normalize [file dirname [info script]]/../..]
create_project -in_memory -part xcve2302-sfva784-1LP-e-S
foreach f {rv64_pkg rv64_mmu_pkg rv64_tlb rv64_ptw rv64_muldiv rv64_csr rv64_core sram_1rw
           rv64_axi_master rv64_dcache rv64_icache rv64_cpu rv64_clint rv64_plic rv64_uart
           rv64_periph rv64_soc} {
  read_vhdl -vhdl2008 $root/rtl/$f.vhd
}
read_vhdl -vhdl2008 $root/fpga/gen/rv64_bootrom_pkg.vhd
read_vhdl -vhdl2008 $root/fpga/rv64_proto_top.vhd
synth_design -top rv64_proto_top -mode out_of_context -flatten_hierarchy rebuilt
create_clock -name clk -period 20.000 [get_ports clk]
report_utilization -file $root/fpga/ooc/util_synth.rpt
opt_design; place_design; phys_opt_design; route_design
report_timing_summary -max_paths 20 -file $root/fpga/ooc/timing.rpt
report_utilization -hierarchical -file $root/fpga/ooc/util_hier.rpt
report_ram_utilization -file $root/fpga/ooc/ram.rpt
puts "WNS: [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]"
