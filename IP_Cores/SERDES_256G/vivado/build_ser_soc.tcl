#==============================================================================
# SERDES_256G silicon test - full build to PDI and XSA.
# Vivado 2025.2.1, Trenz TE0950 (xcve2302-sfva784-1LP-e-S).
# 4 lanes on the zQSFP quad (GTYP_QUAD_X0Y1), raw mode, 128-bit user data.
# Derived from Core 21 (MAC_10G/vivado/build_eth_soc.tcl): same BD
# (CIPS/NoC/DDR untouched), same refclk, same BUFG_GT scheme.
#
#   cd IP_Cores/SERDES_256G && bash vivado/gen_ser_bd_tcl.sh
#   vivado -mode batch -source vivado/build_ser_soc.tcl -tclargs 10 bd
#   vivado -mode batch -source vivado/build_ser_soc.tcl -tclargs 10
#   vivado -mode batch -source vivado/build_ser_soc.tcl -tclargs 25
#
# Rate | line per lane   | refclk (U6) | TX/RXUSRCLK (raw, 128 b) | 4 lanes
# 10   | 10.3125 Gb/s    | 156.25 MHz  |  80.566 MHz              | 41.25 Gb/s
# 25   | 25.78125 Gb/s   | 156.25 MHz  | 201.416 MHz              | 103.1 Gb/s
#
# Mode 'bd' stops after validate_bd_design: use it first, it tells in a
# minute whether the GT accepts RAW / 128-bit at this rate.
#==============================================================================

set RATE 10
set MODE full
if {[llength $argv] >= 1} { set RATE [lindex $argv 0] }
if {[llength $argv] >= 2} { set MODE [lindex $argv 1] }
if {$RATE == 10} {
  set LR 10.3125;   set UCLK 80.566;   set UCLKS 80.566
} elseif {$RATE == 25} {
  set LR 25.78125;  set UCLK 201.416;  set UCLKS 201.416
} else { error "RATE must be 10 or 25" }
set NL 4
puts "== SERDES_256G: $NL lanes x $LR Gb/s, USRCLK $UCLK MHz, mode $MODE =="

# --- 0. paths -------------------------------------------------------------------
set HERE [file normalize [file dirname [info script]]]
set CORE [file normalize $HERE/..]
set IPC  [file normalize $CORE/..]
set PROJ $HERE/ser_soc_$RATE
set NAME ser_soc_$RATE

# --- 1. project and sources -----------------------------------------------------
create_project $NAME $PROJ -part xcve2302-sfva784-1LP-e-S -force
set_property BOARD_PART trenz.biz:te0950_23_1lse:part0:1.2 [current_project]
set_property target_language VHDL [current_project]
set SER $CORE/rtl
set ETH $IPC/MAC_10G/rtl
set SRCS [list \
  $SER/serdes256g_pkg.vhd $SER/serdes256g_tx_frame.vhd $SER/serdes256g_tx_lane.vhd \
  $SER/serdes256g_rx_lane.vhd $SER/serdes256g_afifo.vhd $SER/serdes256g_rx_align.vhd \
  $SER/serdes256g_rx_frame.vhd $SER/serdes256g_top.vhd \
  $ETH/eth21_gt_rst.vhd $ETH/eth21_clkmeter.vhd \
  $SER/serdes256g_gt_top.vhd]
add_files -norecurse $SRCS
set_property FILE_TYPE {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
add_files -norecurse $SER/serdes256g_bd_wrap.v
add_files -fileset constrs_1 -norecurse [list $HERE/serdes256g_gt.xdc $HERE/serdes256g_cdc.xdc]
# the GT clocks only exist after synthesis: XDC used in implementation only
set_property USED_IN_SYNTHESIS false [get_files serdes256g_gt.xdc]
set_property USED_IN_SYNTHESIS false [get_files serdes256g_cdc.xdc]
update_compile_order -fileset sources_1

# --- 2. block design of Core 21 with the test core at 0xA4000000 ---------------
source $HERE/ser_soc_bd.tcl
set_property CONFIG.ACLK_HZ 40000000 [get_bd_cells ser_0]

# --- 3. GT ----------------------------------------------------------------------
# 3a. refclk 156.25 MHz (U6 -> GTYP_REFCLK_X0Y2, LOC in the XDC)
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk
set_property CONFIG.FREQ_HZ 156250000 [get_bd_intf_ports gt_refclk]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf refclk_buf
set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells refclk_buf]
connect_bd_intf_net [get_bd_intf_ports gt_refclk] [get_bd_intf_pins refclk_buf/CLK_IN_D]

# 3b. gt_quad_base: 4 lanes, RAW, 128 bits, LCPLL, refclk R0
set q [create_bd_cell -type ip -vlnv xilinx.com:ip:gt_quad_base gtq]
set d [get_property CONFIG.PROT0_LR0_SETTINGS $q]
foreach {k v} [list \
    TX_LINE_RATE $LR RX_LINE_RATE $LR \
    TX_PLL_TYPE LCPLL RX_PLL_TYPE LCPLL \
    TX_REFCLK_FREQUENCY 156.25 RX_REFCLK_FREQUENCY 156.25 \
    TX_REFCLK_SOURCE R0 RX_REFCLK_SOURCE R0 \
    TX_DATA_ENCODING RAW RX_DATA_DECODING RAW \
    TX_USER_DATA_WIDTH 128 TX_INT_DATA_WIDTH 64 RX_USER_DATA_WIDTH 128 RX_INT_DATA_WIDTH 64 \
    TX_OUTCLK_SOURCE TXPROGDIVCLK TXPROGDIV_FREQ_ENABLE true TXPROGDIV_FREQ_SOURCE LCPLL \
    TXPROGDIV_FREQ_VAL $UCLKS \
    RX_OUTCLK_SOURCE RXPROGDIVCLK RXPROGDIV_FREQ_ENABLE true RXPROGDIV_FREQ_SOURCE LCPLL \
    RXPROGDIV_FREQ_VAL $UCLKS] {
  dict set d $k $v
}
set_property -dict [list CONFIG.PROT0_NO_OF_LANES $NL CONFIG.PROT0_LR0_SETTINGS $d \
                         CONFIG.APB3_CLK_FREQUENCY 100] $q
set dd [get_property CONFIG.PROT0_LR0_SETTINGS $q]
foreach k {TX_LINE_RATE TX_DATA_ENCODING TX_USER_DATA_WIDTH TX_INT_DATA_WIDTH TXPROGDIV_FREQ_VAL \
           RX_DATA_DECODING RX_USER_DATA_WIDTH RX_INT_DATA_WIDTH RXPROGDIV_FREQ_VAL TX_PLL_TYPE} {
  puts "   gtq $k = [dict get $dd $k]"
}
connect_bd_net [get_bd_pins refclk_buf/IBUF_OUT] [get_bd_pins gtq/GT_REFCLK0]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 gt_serial
connect_bd_intf_net [get_bd_intf_pins gtq/GT_Serial] [get_bd_intf_ports gt_serial]
# apb3clk of gt_quad_base: 100..300 MHz (pl0_ref_clk = 40 MHz is too slow)
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard apb_clk
set_property -dict [list CONFIG.CLKOUT_USED {true} CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {100.000} \
  CONFIG.USE_LOCKED {false}] [get_bd_cells apb_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins apb_clk/clk_in1]
connect_bd_net [get_bd_pins apb_clk/clk_out1] [get_bd_pins gtq/apb3clk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins gtq/apb3presetn]

# 3c. BUFG_GT: one for TX (ch0 TXOUTCLK -> all lanes), one per lane for RX
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant one1
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant zero1
set_property CONFIG.CONST_VAL 0 [get_bd_cells zero1]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant zero3
set_property -dict [list CONFIG.CONST_WIDTH 3 CONFIG.CONST_VAL 0] [get_bd_cells zero3]
proc mk_bufg {name uclk} {
  set b [create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt $name]
  set_property CONFIG.FREQ_HZ $uclk $b
  connect_bd_net [get_bd_pins one1/dout]  [get_bd_pins $name/gt_bufgtce]
  connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins $name/gt_bufgtcemask]
  connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins $name/gt_bufgtclr]
  connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins $name/gt_bufgtclrmask]
  connect_bd_net [get_bd_pins zero3/dout] [get_bd_pins $name/gt_bufgtdiv]
}
mk_bufg bufg_tx $UCLK
connect_bd_net [get_bd_pins gtq/ch0_txoutclk] [get_bd_pins bufg_tx/outclk]
set txl [list [get_bd_pins bufg_tx/usrclk] [get_bd_pins ser_0/tx_usrclk]]
for {set i 0} {$i < $NL} {incr i} { lappend txl [get_bd_pins gtq/ch${i}_txusrclk] }
connect_bd_net {*}$txl
for {set i 0} {$i < $NL} {incr i} {
  mk_bufg bufg_rx$i $UCLK
  connect_bd_net [get_bd_pins gtq/ch${i}_rxoutclk] [get_bd_pins bufg_rx$i/outclk]
  connect_bd_net [get_bd_pins bufg_rx$i/usrclk] [get_bd_pins gtq/ch${i}_rxusrclk] \
                 [get_bd_pins ser_0/rx_usrclk$i]
}

# 3d. channels <-> core
for {set i 0} {$i < $NL} {incr i} {
  connect_bd_intf_net [get_bd_intf_pins ser_0/TX$i]  [get_bd_intf_pins gtq/TX${i}_GT_IP_Interface]
  connect_bd_intf_net [get_bd_intf_pins ser_0/RX$i]  [get_bd_intf_pins gtq/RX${i}_GT_IP_Interface]
  connect_bd_intf_net [get_bd_intf_pins ser_0/DBG$i] [get_bd_intf_pins gtq/CH${i}_DEBUG]
}
connect_bd_net [get_bd_pins gtq/gtpowergood] [get_bd_pins ser_0/gtpowergood]
connect_bd_net [get_bd_pins gtq/hsclk0_lcplllock] [get_bd_pins ser_0/lcplllock0]
set pr [list [get_bd_pins ser_0/lcpllreset] [get_bd_pins gtq/hsclk0_lcpllreset]]
if {[llength [get_bd_pins -quiet gtq/hsclk1_lcplllock]]} {
  connect_bd_net [get_bd_pins gtq/hsclk1_lcplllock] [get_bd_pins ser_0/lcplllock1]
  lappend pr [get_bd_pins gtq/hsclk1_lcpllreset]
} else {
  connect_bd_net [get_bd_pins one1/dout] [get_bd_pins ser_0/lcplllock1]
}
connect_bd_net {*}$pr

# --- 4. validate; mode 'bd' stops here ------------------------------------------
assign_bd_address
set vr [catch {validate_bd_design} vmsg]
puts "== validate_bd_design: [expr {$vr ? "ERROR" : "OK"}]"
save_bd_design
puts "== gtq QUAD_USAGE: [get_property CONFIG.QUAD_USAGE [get_bd_cells gtq]]"
puts "== gtq pins (clocks / PLL):"
foreach p [get_bd_pins -quiet gtq/*] {
  if {[regexp {outclk|usrclk|lcpll|rpll} $p]} { puts "   $p" }
}
if {$vr} { error "validate_bd_design failed: $vmsg" }
if {$MODE eq "bd"} { puts "== mode bd: SER_BD_OK"; return }

# --- 5. BD wrapper as top -------------------------------------------------------
set BD [get_files ser_soc_bd.bd]
make_wrapper -files $BD -top
set WRAP [glob -nocomplain $PROJ/$NAME.gen/sources_1/bd/ser_soc_bd/hdl/ser_soc_bd_wrapper.*]
if {[llength $WRAP] != 1} { error "BD wrapper not found: $WRAP" }
add_files -norecurse $WRAP
set_property top ser_soc_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

# --- 6. strategy (same as Core 20/21) --------------------------------------------
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# --- 7. synthesis + implementation + PDI -----------------------------------------
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synth_1 failed" }
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1

# --- 8. reports and artefacts ----------------------------------------------------
open_run impl_1
report_timing_summary -max_paths 20 -file $HERE/timing_summary_$RATE.txt
report_clocks -file $HERE/clocks_$RATE.txt
report_cdc -details -file $HERE/cdc_report_$RATE.txt
report_utilization -hierarchical -hierarchical_depth 4 -file $HERE/utilization_$RATE.txt
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "== WNS = $wns ns   WHS = $whs ns =="
puts "== GT: [get_cells -hierarchical -filter {REF_NAME =~ GTYP_QUAD*}] LOC=[get_property LOC [get_cells -hierarchical -filter {REF_NAME =~ GTYP_QUAD*}]]"
file mkdir $CORE/petalinux_$RATE
foreach pdi [glob -nocomplain $PROJ/$NAME.runs/impl_1/*.pdi] {
  file copy -force $pdi $HERE/ser_soc_$RATE.pdi
}
write_hw_platform -fixed -include_bit -force $CORE/petalinux_$RATE/ser_soc_$RATE.xsa
puts "== PDI: $HERE/ser_soc_$RATE.pdi   XSA: $CORE/petalinux_$RATE/ser_soc_$RATE.xsa =="
puts "SER_BUILD_DONE"
