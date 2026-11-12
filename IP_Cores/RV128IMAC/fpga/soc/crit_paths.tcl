# crit_paths.tcl - list the worst setup paths of an implemented run, as the input for
# raising the clock. Opens the run read-only; writes crit_<run>.rpt next to the .xpr.
#
#   vivado -mode batch -source fpga/soc/crit_paths.tcl \
#       -tclargs fpga/soc/rv128_soc_te0950/rv128_soc_te0950.xpr impl_v14 2>&1 | tee fpga/soc/crit.log
set xpr [file normalize [lindex $argv 0]]
set run [lindex $argv 1]
open_project $xpr
open_run $run
set out [file dirname $xpr]/crit_$run.rpt
set f [open $out w]
# 40 worst endpoints, one path each: start -> end, logic levels, data path delay
puts $f [format "%-8s %-6s %-7s %-70s %s" slack levels delay start end]
foreach p [get_timing_paths -setup -max_paths 40 -nworst 1 -sort_by slack] {
  puts $f [format "%-8.3f %-6s %-7.3f %-70s %s" [get_property SLACK $p] \
           [get_property LOGIC_LEVELS $p] [get_property DATAPATH_DELAY $p] \
           [get_property STARTPOINT_PIN $p] [get_property ENDPOINT_PIN $p]]
}
close $f
report_timing -setup -max_paths 3 -nworst 1 -input_pins -file [file dirname $xpr]/crit_${run}_detail.rpt
puts "== $out"
