#===========================================================================
# HERCOSSNUX NPU - Layer 5, sintesis OOC de npu_axi_top.
#
# Segunda pasada de sintesis, ahora con las interfaces AXI incluidas:
#   npu_axi_top = npu_top + npu_dma (master) + npu_axi_slave (registros)
#
# Referencia de la pasada anterior (solo npu_top):
#   CLB LUTs 51880 (34.5%)  DSP58 51 (11%)  BRAM 1  WNS +1.599 ns
#
# Este script ademas LISTA LOS CAMINOS VIOLADOS si el timing no cierra, para
# no tener que hacerlo despues a mano con open_checkpoint (que no carga las
# restricciones y hay que anadir create_clock manualmente).
#
# Uso:
#   cd ~/vhdl_repo/IP_Cores/NPU
#   bash syn/run_synth_axi.sh
#
# Notas de entorno:
#   - '~' NO se expande en Vivado Tcl: se usa $env(HOME)
#   - proyecto desechable, no afecta a ningun otro
#   - INCREMENTAL_CHECKPOINT se limpia para que no aborte la sintesis
#===========================================================================

set NPU_DIR  "$env(HOME)/vhdl_repo/IP_Cores/NPU"
set PROJ_DIR "$NPU_DIR/syn/proj_axi"
set PART     "xcve2302-sfva784-1LP-e-S"
set TOP      "npu_axi_top"
set PERIOD   10.0

puts "=========================================================="
puts "HERCOSSNUX NPU - sintesis OOC de npu_axi_top"
puts "  parte    : $PART"
puts "  top      : $TOP"
puts "  periodo  : $PERIOD ns"
puts "=========================================================="

# --- Comprobacion de fuentes --------------------------------------------
set SRCS [list \
  "$NPU_DIR/rtl/npu_pkg.vhd" \
  "$NPU_DIR/rtl/npu_axi_pkg.vhd" \
  "$NPU_DIR/rtl/npu_array.vhd" \
  "$NPU_DIR/rtl/npu_seq_conv1.vhd" \
  "$NPU_DIR/rtl/npu_seq_full.vhd" \
  "$NPU_DIR/rtl/npu_top.vhd" \
  "$NPU_DIR/rtl/npu_dma.vhd" \
  "$NPU_DIR/rtl/npu_axi_slave.vhd" \
  "$NPU_DIR/rtl/npu_axi_top.vhd" ]

foreach f $SRCS {
  if {![file exists $f]} {
    puts "FALLO: no existe $f"
    exit 1
  }
}
puts "Fuentes localizadas: [llength $SRCS] archivos"

# --- Proyecto desechable -------------------------------------------------
file delete -force $PROJ_DIR
file mkdir $PROJ_DIR
create_project npu_axi $PROJ_DIR -part $PART -force

foreach f $SRCS {
  add_files -norecurse $f
  set_property FILE_TYPE {VHDL 2008} [get_files $f]
}
set_property top $TOP [current_fileset]
update_compile_order -fileset sources_1

# --- Restricciones -------------------------------------------------------
set XDC "$PROJ_DIR/npu_axi.xdc"
set fh [open $XDC w]
puts $fh "create_clock -period $PERIOD -name clk \[get_ports clk\]"
puts $fh "set_false_path -from \[get_ports rst_n\]"
close $fh
add_files -fileset constrs_1 -norecurse $XDC

# --- Sintesis ------------------------------------------------------------
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
  -value {-mode out_of_context} -objects [get_runs synth_1]

puts "\n>>> Lanzando sintesis (varios minutos)..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
  puts "FALLO: la sintesis no completo. Revisa el log:"
  puts "  $PROJ_DIR/npu_axi.runs/synth_1/runme.log"
  exit 1
}
puts ">>> Sintesis completada."

open_run synth_1 -name netlist_1

# --- Reportes ------------------------------------------------------------
set RPT "$NPU_DIR/syn/reportes_axi"
file delete -force $RPT
file mkdir $RPT

report_utilization       -file "$RPT/utilizacion.rpt"
report_utilization -hierarchical -file "$RPT/utilizacion_jerarquica.rpt"
report_timing_summary    -file "$RPT/timing.rpt"
report_ram_utilization   -file "$RPT/ram.rpt" -quiet

puts "\n=========================================================="
puts "RESUMEN"
puts "=========================================================="

# En Versal la primitiva de BRAM es RAMB18E5_INT; DSP58 para el DSP.
set bram18 [get_cells -hier -filter {REF_NAME =~ RAMB18*} -quiet]
set bram36 [get_cells -hier -filter {REF_NAME =~ RAMB36*} -quiet]
set uram   [get_cells -hier -filter {REF_NAME =~ URAM*}   -quiet]
set dsps   [get_cells -hier -filter {REF_NAME =~ DSP58}   -quiet]
set ffs    [get_cells -hier -filter {REF_NAME =~ FD*}     -quiet]

puts "BRAM18   : [llength $bram18]"
puts "BRAM36   : [llength $bram36]"
puts "URAM     : [llength $uram]"
puts "DSP58    : [llength $dsps]"
puts "FF       : [llength $ffs]"
puts ""
puts "Referencia npu_top solo: LUTs 51880 (34.5%), DSP58 51, BRAM 1"
puts "Los totales de LUT estan en utilizacion.rpt"

# --- Timing --------------------------------------------------------------
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "\nWNS (setup): $wns ns"

if {$wns < 0} {
  puts "  NO cierra a [expr {1000.0/$PERIOD}] MHz."
  puts ""
  puts "CAMINOS VIOLADOS:"
  set ps [get_timing_paths -max_paths 20 -slack_lesser_than 0]
  puts "  total: [llength $ps]"
  foreach p $ps {
    puts "  SLACK [get_property SLACK $p] | [get_property STARTPOINT_PIN $p] -> [get_property ENDPOINT_PIN $p]"
  }
} else {
  puts "  Cierra con holgura de $wns ns."
}

puts "\nReportes en: $RPT"
puts "=========================================================="
puts "NPU SINTESIS AXI COMPLETADA"
