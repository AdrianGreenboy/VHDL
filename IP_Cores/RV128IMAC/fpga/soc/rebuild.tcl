# rebuild.tcl - re-implement the existing TE0950 project after an RTL change (the BD made
# by bd_insert.tcl stays as is). The previous synth_1/impl_1 results are kept: this creates
# new runs synth_<tag>/impl_<tag> and leaves the PDI, reports and the XSA next to the .xpr.
#
#   vivado -mode batch -source fpga/soc/rebuild.tcl \
#       -tclargs fpga/soc/rv128_soc_te0950/rv128_soc_te0950.xpr v14 2>&1 | tee fpga/soc/rebuild_v14.log
set xpr [file normalize [lindex $argv 0]]   ;# absolute: open_project changes the cwd
set tag [lindex $argv 1]
if {$tag eq ""} { set tag new }
open_project $xpr
set dir [file dirname $xpr]

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

launch_runs $iname -to_step write_device_image -jobs 4
wait_on_run $iname
if {[get_property PROGRESS [get_runs $iname]] ne "100%"} { error "$iname did not finish" }

open_run $iname
report_timing_summary -file $dir/timing_summary_$tag.rpt
report_utilization -file $dir/utilization_$tag.rpt
report_utilization -hierarchical -hierarchical_depth 4 -file $dir/utilization_hier_$tag.rpt
write_hw_platform -fixed -include_bit -force $dir/rv128_soc_$tag.xsa
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "== $iname  WNS = $wns ns"
puts "== PDI: [glob -nocomplain [get_property DIRECTORY [get_runs $iname]]/*.pdi]"
puts "== XSA: $dir/rv128_soc_$tag.xsa"
