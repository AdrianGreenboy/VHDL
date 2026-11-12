# rebuild.tcl - re-implement the existing TE0950 project after an RTL change (the BD made
# by bd_insert.tcl stays as is). The previous synth_1/impl_1 results are kept: this creates
# new runs synth_<tag>/impl_<tag> and leaves the PDI, reports and the XSA next to the .xpr.
#
#   vivado -mode batch -source fpga/soc/rebuild.tcl \
#       -tclargs $PWD/fpga/soc/rv128_soc_te0950/rv128_soc_te0950.xpr v14 [UNC_NS [STRATEGY]]
# UNC_NS > 0 probes a faster clock without touching CIPS: a setup clock uncertainty of
# UNC_NS on the PL clock (implementation only) makes the 50 MHz run close as if the period
# were 20 - UNC_NS ns (3.4 -> 60 MHz, 5.0 -> 66.7 MHz). STRATEGY: an implementation strategy,
# e.g. Performance_ExplorePostRoutePhysOpt.
set xpr [file normalize [lindex $argv 0]]   ;# absolute: open_project changes the cwd
set tag [lindex $argv 1]
if {$tag eq ""} { set tag new }
set unc [lindex $argv 2]
set strat [lindex $argv 3]
open_project $xpr
set pdir [file dirname $xpr]

# the BD instantiates rv128_soc_wrap as a module reference: pick up the new RTL
update_compile_order -fileset sources_1
foreach ip [get_ips -quiet -filter {NAME =~ *rv128*}] {
  puts "update_module_reference $ip"
  update_module_reference $ip
}
# only the top BD (the NoC carries a nested sub-design that its parent generates)
set bd [lindex [get_files -quiet */sources_1/bd/design_1/design_1.bd] 0]
if {$bd eq ""} { error "design_1.bd not found" }
puts "BD: $bd"
# TICK_DIV=<pl clock in MHz> in the environment: mtime stays at 1 MHz after a clock change
if {[info exists ::env(TICK_DIV)]} {
  open_bd_design $bd
  set_property CONFIG.TICK_DIV $::env(TICK_DIV) [get_bd_cells rv128]
  puts "rv128 TICK_DIV = [get_property CONFIG.TICK_DIV [get_bd_cells rv128]]"
  set pl0 [get_property CONFIG.FREQ_HZ [get_bd_pins rv128/clk]]
  puts "rv128/clk FREQ_HZ = $pl0"
  validate_bd_design
  save_bd_design
  close_bd_design [get_bd_designs design_1]
}
generate_target all [get_files $bd]

set s1 [get_runs synth_1]
set i1 [get_runs impl_1]
set sname synth_$tag
set iname impl_$tag
if {[get_runs -quiet $sname] ne ""} { error "run $sname already exists: use another tag" }
create_run $sname -flow [get_property FLOW $s1] -part [get_property PART $s1]
create_run $iname -parent_run $sname -flow [get_property FLOW $i1] -part [get_property PART $i1]
set_property strategy [get_property STRATEGY $s1] [get_runs $sname]
set_property strategy [get_property STRATEGY $i1] [get_runs $iname]
current_run [get_runs $sname]
current_run [get_runs $iname]

if {$unc ne "" && $unc > 0} {
  # implementation-only constraint file next to the project
  set xdc $pdir/probe_$tag.xdc
  set f [open $xdc w]
  puts $f "set_clock_uncertainty -setup $unc \[get_clocks -quiet -of_objects \[get_pins -quiet -hier -filter {NAME =~ */rv128/clk}\]\]"
  puts $f "set_clock_uncertainty -setup $unc \[get_clocks -quiet clk_pl_0*\]"
  close $f
  set fs [get_filesets -quiet probe_$tag]
  if {$fs eq ""} { create_fileset -constrset probe_$tag; set fs [get_filesets probe_$tag] }
  foreach c [get_files -quiet -of_objects [get_filesets constrs_1]] { add_files -fileset $fs $c }
  add_files -fileset $fs $xdc
  set_property USED_IN_SYNTHESIS false [get_files $xdc]
  set_property constrset $fs [get_runs $sname]
  set_property constrset $fs [get_runs $iname]
  puts "probe: setup uncertainty $unc ns (equivalent period [expr {20.0 - $unc}] ns)"
}
if {$strat ne ""} { set_property strategy $strat [get_runs $iname] }
launch_runs $iname -to_step write_device_image -jobs 4
wait_on_run $iname
if {[get_property PROGRESS [get_runs $iname]] ne "100%"} { error "$iname did not finish" }

open_run $iname
report_timing_summary -file $pdir/timing_summary_$tag.rpt
report_utilization -file $pdir/utilization_$tag.rpt
report_utilization -hierarchical -hierarchical_depth 4 -file $pdir/utilization_hier_$tag.rpt
write_hw_platform -fixed -include_bit -force $pdir/rv128_soc_$tag.xsa
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "== $iname  WNS = $wns ns"
puts "== PDI: [glob -nocomplain [get_property DIRECTORY [get_runs $iname]]/*.pdi]"
puts "== XSA: $pdir/rv128_soc_$tag.xsa"
