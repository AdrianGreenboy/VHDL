#==============================================================================
# HERCOSSNUX Core 21 - ETH GT - construccion completa hasta PDI y XSA.
# Vivado 2025.2.1, Trenz TE0950 (xcve2302-sfva784-1LP-e-S).
#
#   cd IP_Cores/ETH_GT && bash vivado/gen_eth_bd_tcl.sh
#   vivado -mode batch -source vivado/build_eth_soc.tcl -tclargs 10       (10G)
#   vivado -mode batch -source vivado/build_eth_soc.tcl -tclargs 25       (25G)
#   vivado -mode batch -source vivado/build_eth_soc.tcl -tclargs 10 bd    (solo BD
#          + validate: para iterar rapido sobre la conexion del GT)
#
# Tasa  | linea           | refclk (U6) | TX/RXUSRCLK (64B66B_ASYNC, 64 b)
# 10    | 10.3125 Gb/s    | 156.25 MHz  | 156.25 MHz
# 25    | 25.78125 Gb/s   | 156.25 MHz  | 390.625 MHz
#
# El BD (CIPS/NoC/DDR) es el del Core 20 tal cual (gen_eth_bd_tcl.sh); aqui
# se anaden: buffer del refclk, gt_quad_base (1 lane, X0Y1 canal 0), dos
# BUFG_GT (TXOUTCLK/RXOUTCLK) con CE = 1, y las interfaces del canal 0 hacia
# el wrapper del core.
#==============================================================================

set RATE 10
set MODE full
if {[llength $argv] >= 1} { set RATE [lindex $argv 0] }
if {[llength $argv] >= 2} { set MODE [lindex $argv 1] }
if {$RATE == 10} {
  set LR 10.3125;   set UCLK 156.25;   set UCLKS 156.250
} elseif {$RATE == 25} {
  set LR 25.78125;  set UCLK 390.625;  set UCLKS 390.625
} else { error "RATE debe ser 10 o 25" }
puts "== Core 21: linea $LR Gb/s, USRCLK $UCLK MHz, modo $MODE =="

# --- 0. rutas ------------------------------------------------------------------
set HERE [file normalize [file dirname [info script]]]
set CORE [file normalize $HERE/..]
set IPC  [file normalize $CORE/..]
set PROJ $HERE/eth_soc_$RATE
set NAME eth_soc_$RATE

# --- 1. wrapper Verilog: nombre logico del loopback de CH0_DEBUG --------------
set lb ""
set xmls [glob -nocomplain $::env(XILINX_VIVADO)/data/ip/interfaces/*/gt_channel_debug*_rtl.xml]
if {[llength $xmls] == 0} {
  catch {set xmls [split [exec find $::env(XILINX_VIVADO)/data -name "gt_channel_debug*rtl*.xml"] "\n"]}
}
foreach x $xmls {
  if {$x eq ""} continue
  set fh [open $x r]; set t [read $fh]; close $fh
  foreach {all n} [regexp -all -inline {<spirit:logicalName>([^<]*loopback[^<]*)</spirit:logicalName>} $t] {
    set lb $n
  }
}
set fh [open $CORE/rtl/eth21_bd_wrap.v.tpl r]; set tpl [read $fh]; close $fh
if {$lb ne ""} {
  puts "== loopback de CH0_DEBUG: nombre logico '$lb'"
  set tpl [string map [list @LB_LOGICAL@ $lb "// @DBG_ASSIGN@" "    assign dbg0_loopback = loopback_w;"] $tpl]
} else {
  puts "AVISO: no se encontro la definicion de gt_channel_debug: sin loopback PMA (el selftest necesita un cable/loopback externo)"
  regsub {// @DBG_BEGIN@.*// @DBG_END@\n} $tpl "" tpl
  set tpl [string map [list "// @DBG_ASSIGN@" ""] $tpl]
}
set WRAPV $HERE/eth21_bd_wrap.v
set fh [open $WRAPV w]; puts -nonewline $fh $tpl; close $fh

# --- 2. proyecto y fuentes -----------------------------------------------------
create_project $NAME $PROJ -part xcve2302-sfva784-1LP-e-S -force
set_property BOARD_PART trenz.biz:te0950_23_1lse:part0:1.2 [current_project]
set_property target_language VHDL [current_project]
set PCS $IPC/PCS_25G/rtl
set MAC $IPC/MAC_25G/rtl
set ETH $CORE/rtl
set SRCS [list \
  $PCS/pcs_scrambler.vhd \
  $MAC/mac25g_crc_pkg.vhd $MAC/mac25g_pkg.vhd $MAC/mac25g_sync.vhd \
  $MAC/mac25g_tx.vhd $MAC/mac25g_rx.vhd $MAC/mac25g_pcs66.vhd \
  $ETH/eth21_pkg.vhd $ETH/eth21_udp_gen.vhd $ETH/eth21_udp_chk.vhd $ETH/eth21_blocklock.vhd \
  $ETH/eth21_gtmap.vhd $ETH/eth21_txpath.vhd $ETH/eth21_rxpath.vhd $ETH/eth21_gt_rst.vhd \
  $ETH/eth21_clkmeter.vhd $ETH/eth21_top.vhd]
add_files -norecurse $SRCS
set_property FILE_TYPE {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]
add_files -norecurse $WRAPV
add_files -fileset constrs_1 -norecurse $HERE/eth21_gt.xdc
update_compile_order -fileset sources_1

# --- 3. BD del Core 20 (CIPS/NoC intactos) con el core en 0xA4000000 ----------
source $HERE/eth_soc_bd.tcl
set_property CONFIG.ACLK_HZ 40000000 [get_bd_cells eth21_0]

# --- 4. GT ----------------------------------------------------------------------
# 4a. refclk 156.25 MHz (U6 -> H7/H6 = GTYP_REFCLK_X0Y2, LOC en el XDC)
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_refclk
set_property CONFIG.FREQ_HZ 156250000 [get_bd_intf_ports gt_refclk]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf refclk_buf
set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells refclk_buf]
connect_bd_intf_net [get_bd_intf_ports gt_refclk] [get_bd_intf_pins refclk_buf/CLK_IN_D]

# 4b. gt_quad_base: 1 lane, 64B66B_ASYNC 64 bits, LCPLL, refclk R0
set q [create_bd_cell -type ip -vlnv xilinx.com:ip:gt_quad_base gtq]
set d [get_property CONFIG.PROT0_LR0_SETTINGS $q]
foreach {k v} [list \
    TX_LINE_RATE $LR RX_LINE_RATE $LR \
    TX_PLL_TYPE LCPLL RX_PLL_TYPE LCPLL \
    TX_REFCLK_FREQUENCY 156.25 RX_REFCLK_FREQUENCY 156.25 \
    TX_REFCLK_SOURCE R0 RX_REFCLK_SOURCE R0 \
    TX_DATA_ENCODING 64B66B_ASYNC RX_DATA_DECODING 64B66B_ASYNC \
    TX_USER_DATA_WIDTH 64 TX_INT_DATA_WIDTH 64 RX_USER_DATA_WIDTH 64 RX_INT_DATA_WIDTH 64 \
    TX_OUTCLK_SOURCE TXPROGDIVCLK TXPROGDIV_FREQ_ENABLE true TXPROGDIV_FREQ_SOURCE LCPLL \
    TXPROGDIV_FREQ_VAL $UCLKS \
    RX_OUTCLK_SOURCE RXPROGDIVCLK RXPROGDIV_FREQ_ENABLE true RXPROGDIV_FREQ_SOURCE LCPLL \
    RXPROGDIV_FREQ_VAL $UCLKS] {
  dict set d $k $v
}
set_property -dict [list CONFIG.PROT0_NO_OF_LANES 1 CONFIG.PROT0_LR0_SETTINGS $d \
                         CONFIG.APB3_CLK_FREQUENCY 40] $q
set dd [get_property CONFIG.PROT0_LR0_SETTINGS $q]
foreach k {TX_LINE_RATE TX_DATA_ENCODING TX_USER_DATA_WIDTH TXPROGDIV_FREQ_VAL RX_DATA_DECODING RXPROGDIV_FREQ_VAL TX_PLL_TYPE} {
  puts "   gtq $k = [dict get $dd $k]"
}
connect_bd_net [get_bd_pins refclk_buf/IBUF_OUT] [get_bd_pins gtq/GT_REFCLK0]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 gt_serial
connect_bd_intf_net [get_bd_intf_pins gtq/GT_Serial] [get_bd_intf_ports gt_serial]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins gtq/apb3clk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins gtq/apb3presetn]

# 4c. BUFG_GT de TX y RX (CE = 1, CLR = 0, DIV = 0)
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant one1
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant zero1
set_property CONFIG.CONST_VAL 0 [get_bd_cells zero1]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant zero3
set_property -dict [list CONFIG.CONST_WIDTH 3 CONFIG.CONST_VAL 0] [get_bd_cells zero3]
foreach dir {tx rx} {
  set b [create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_$dir]
  set_property CONFIG.FREQ_HZ $UCLK $b
  connect_bd_net [get_bd_pins gtq/ch0_${dir}outclk] [get_bd_pins bufg_$dir/outclk]
  connect_bd_net [get_bd_pins one1/dout]  [get_bd_pins bufg_$dir/gt_bufgtce]
  connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins bufg_$dir/gt_bufgtcemask]
  connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins bufg_$dir/gt_bufgtclr]
  connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins bufg_$dir/gt_bufgtclrmask]
  connect_bd_net [get_bd_pins zero3/dout] [get_bd_pins bufg_$dir/gt_bufgtdiv]
  connect_bd_net [get_bd_pins bufg_$dir/usrclk] [get_bd_pins gtq/ch0_${dir}usrclk] \
                 [get_bd_pins eth21_0/${dir}_usrclk]
}

# 4d. canal 0 <-> core
connect_bd_intf_net [get_bd_intf_pins eth21_0/TX0] [get_bd_intf_pins gtq/TX0_GT_IP_Interface]
connect_bd_intf_net [get_bd_intf_pins eth21_0/RX0] [get_bd_intf_pins gtq/RX0_GT_IP_Interface]
if {$lb ne ""} {
  connect_bd_intf_net [get_bd_intf_pins eth21_0/DBG0] [get_bd_intf_pins gtq/CH0_DEBUG]
}
connect_bd_net [get_bd_pins gtq/gtpowergood] [get_bd_pins eth21_0/gtpowergood]
connect_bd_net [get_bd_pins gtq/hsclk0_lcplllock] [get_bd_pins eth21_0/lcplllock]
set pr [list [get_bd_pins eth21_0/lcpllreset] [get_bd_pins gtq/hsclk0_lcpllreset]]
if {[llength [get_bd_pins -quiet gtq/hsclk1_lcpllreset]]} { lappend pr [get_bd_pins gtq/hsclk1_lcpllreset] }
connect_bd_net {*}$pr

# --- 5. validar; en modo 'bd' parar aqui ---------------------------------------
assign_bd_address
set vr [catch {validate_bd_design} vmsg]
puts "== validate_bd_design: [expr {$vr ? "ERROR" : "OK"}]"
save_bd_design
set gq [get_bd_cells gtq]
puts "== gtq QUAD_USAGE: [get_property CONFIG.QUAD_USAGE $gq]"
puts "== direcciones:"
foreach s [get_bd_addr_segs -of_objects [get_bd_addr_spaces versal_cips_0/M_AXI_FPD]] {
  puts "   $s offset=[get_property OFFSET $s] range=[get_property RANGE $s]"
}
if {$vr} { error "validate_bd_design fallo: $vmsg" }
if {$MODE eq "bd"} { puts "== modo bd: fin"; return }

# --- 6. wrapper del BD como top ----------------------------------------------
set BD [get_files eth_soc_bd.bd]
make_wrapper -files $BD -top
set WRAP [glob -nocomplain $PROJ/$NAME.gen/sources_1/bd/eth_soc_bd/hdl/eth_soc_bd_wrapper.*]
if {[llength $WRAP] != 1} { error "wrapper del BD no encontrado: $WRAP" }
add_files -norecurse $WRAP
set_property top eth_soc_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

# --- 7. estrategia (la del Core 20) ----------------------------------------------
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# --- 8. sintesis + implementacion + PDI ------------------------------------------
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synth_1 fallo" }
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1

# --- 9. informes y artefactos ----------------------------------------------------
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
  file copy -force $pdi $HERE/eth_soc_$RATE.pdi
}
write_hw_platform -fixed -include_bit -force $CORE/petalinux_$RATE/eth_soc_$RATE.xsa
puts "== PDI: $HERE/eth_soc_$RATE.pdi   XSA: $CORE/petalinux_$RATE/eth_soc_$RATE.xsa =="
