# SERDES_256G - out-of-context synthesis + place + route for timing estimation
# Run from the core directory:
#   vivado -mode batch -source vivado/ooc_impl.tcl -log vivado/ooc/vivado.log -journal vivado/ooc/vivado.jou
# Nothing is deleted; reports and checkpoints in vivado/ooc are overwritten.
set part   xcve2302-sfva784-1LP-e-S
set period 4.000
set outdir vivado/ooc
file mkdir $outdir

read_vhdl -vhdl2008 [glob rtl/*.vhd]
synth_design -top serdes256g_top -part $part -mode out_of_context

create_clock -name tx_clk -period $period [get_ports tx_clk]
create_clock -name rx_clk -period $period [get_ports rx_clk]
set groups [list -group tx_clk -group rx_clk]
for {set i 0} {$i < 8} {incr i} {
  create_clock -name rxl$i -period $period [get_ports gt_rxusrclk[$i]]
  lappend groups -group rxl$i
}
# estimation only: the real design uses vivado/serdes256g_cdc.xdc instead
set_clock_groups -asynchronous {*}$groups

# one line per distinct endpoint register array, worst slack first
proc report_unique {file} {
  set fh [open $file w]
  set seen [dict create]
  foreach p [get_timing_paths -setup -max_paths 5000 -nworst 1] {
    set ep  [get_property ENDPOINT_PIN $p]
    set key $ep
    regsub -all {\[[0-9]+\]} $key {} key
    regsub -all {_rep(__[0-9]+)?} $key {} key
    if {![dict exists $seen $key]} {
      dict set seen $key 1
      puts $fh [format "%7.3f  lvl=%-3s %s -> %s" \
        [get_property SLACK $p] [get_property LOGIC_LEVELS $p] \
        [get_property STARTPOINT_PIN $p] $ep]
    }
  }
  close $fh
}

opt_design
write_checkpoint -force $outdir/post_synth.dcp
report_utilization -file $outdir/util.rpt
report_unique $outdir/unique_paths_synth.rpt

place_design
phys_opt_design
route_design
write_checkpoint -force $outdir/post_route.dcp
report_timing_summary -file $outdir/timing_route.rpt
report_unique $outdir/unique_paths_route.rpt
puts "OOC_IMPL_DONE"
