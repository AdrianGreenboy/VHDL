set part xcve2302-sfva784-1LP-e-S
read_vhdl -vhdl2008 [glob rtl/*.vhd]
synth_design -top serdes256g_top -part $part -mode out_of_context
create_clock -name tx_clk -period 4.000 [get_ports tx_clk]
create_clock -name rx_clk -period 4.000 [get_ports rx_clk]
for {set i 0} {$i < 8} {incr i} {
  create_clock -name rxl$i -period 4.000 [get_ports gt_rxusrclk[$i]]
}
set_clock_groups -asynchronous -group tx_clk -group rx_clk \
  -group rxl0 -group rxl1 -group rxl2 -group rxl3 \
  -group rxl4 -group rxl5 -group rxl6 -group rxl7
opt_design
report_utilization -file vivado/ooc/util.rpt
report_timing_summary -file vivado/ooc/timing.rpt
report_timing -max_paths 20 -nworst 1 -file vivado/ooc/worst_paths.rpt
