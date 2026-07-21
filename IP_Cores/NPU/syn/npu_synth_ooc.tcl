#===========================================================================
# HERCOSSNUX NPU - Layer 5, sintesis exploratoria out-of-context
#
# Objetivo UNICO de esta pasada: averiguar donde acabaron las memorias.
#   w2_ram (1152 B), w3_ram (2560 B), in_ram (512 B), c2_ram (1024 B),
#   img_ram (256 B), out_ram (512 B), p2_ram (256 B)
# Tras el Paso 9, w2_ram y w_ram tienen una sola lectura por ciclo y
# DEBERIAN mapear a BRAM. in_ram (8 lecturas) y c2_ram (4) siguen sin tocar.
#
# No hay AXI ni NoC todavia: eso viene despues, cuando sepamos si cabe.
#
# Uso:
#   cd ~/vhdl_repo/IP_Cores/NPU
#   vivado -mode batch -source syn/npu_synth_ooc.tcl
#
# Notas de entorno (lecciones previas):
#   - '~' NO se expande en Vivado Tcl: se usa $env(HOME)
#   - la sintesis out-of-context cambia el top del proyecto; aqui se crea un
#     proyecto desechable, asi que no afecta a ningun otro
#   - INCREMENTAL_CHECKPOINT se limpia para que no aborte la sintesis
#===========================================================================

set NPU_DIR  "$env(HOME)/vhdl_repo/IP_Cores/NPU"
set PROJ_DIR "$NPU_DIR/syn/proj_ooc"
set PART     "xcve2302-sfva784-1LP-e-S"
set TOP      "npu_top"
set PERIOD   10.0

puts "=========================================================="
puts "HERCOSSNUX NPU - sintesis exploratoria OOC"
puts "  parte    : $PART"
puts "  top      : $TOP"
puts "  periodo  : $PERIOD ns"
puts "=========================================================="

# --- Comprobacion de fuentes antes de crear nada -------------------------
set SRCS [list \
  "$NPU_DIR/rtl/npu_pkg.vhd" \
  "$NPU_DIR/rtl/npu_array.vhd" \
  "$NPU_DIR/rtl/npu_seq_conv1.vhd" \
  "$NPU_DIR/rtl/npu_seq_full.vhd" \
  "$NPU_DIR/rtl/npu_top.vhd" ]

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
create_project npu_ooc $PROJ_DIR -part $PART -force

# VHDL-2008 explicito en cada archivo
foreach f $SRCS {
  add_files -norecurse $f
  set_property FILE_TYPE {VHDL 2008} [get_files $f]
}
set_property top $TOP [current_fileset]
update_compile_order -fileset sources_1

# --- Restricciones minimas: solo reloj -----------------------------------
set XDC "$PROJ_DIR/npu_ooc.xdc"
set fh [open $XDC w]
puts $fh "create_clock -period $PERIOD -name clk \[get_ports clk\]"
puts $fh "set_false_path -from \[get_ports rst_n\]"
close $fh
add_files -fileset constrs_1 -norecurse $XDC

# --- Sintesis ------------------------------------------------------------
# El checkpoint incremental aborta la sintesis si quedo de una corrida previa
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
  -value {-mode out_of_context} -objects [get_runs synth_1]

puts "\n>>> Lanzando sintesis (puede tardar varios minutos)..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
  puts "FALLO: la sintesis no completo. Revisa el log:"
  puts "  $PROJ_DIR/npu_ooc.runs/synth_1/runme.log"
  exit 1
}
puts ">>> Sintesis completada."

open_run synth_1 -name netlist_1

# --- Reportes ------------------------------------------------------------
set RPT "$NPU_DIR/syn/reportes"
file mkdir $RPT

report_utilization       -file "$RPT/utilizacion.rpt"
report_utilization -hierarchical -file "$RPT/utilizacion_jerarquica.rpt"
report_timing_summary    -file "$RPT/timing.rpt"
report_ram_utilization   -file "$RPT/ram.rpt" -quiet

puts "\n=========================================================="
puts "RESUMEN"
puts "=========================================================="

# --- Memorias: la pregunta que motiva esta pasada ------------------------
# En Versal la primitiva de BRAM es RAMB18E5_INT; se filtra por REF_NAME.
set bram18 [get_cells -hier -filter {REF_NAME =~ RAMB18*} -quiet]
set bram36 [get_cells -hier -filter {REF_NAME =~ RAMB36*} -quiet]
set uram   [get_cells -hier -filter {REF_NAME =~ URAM*}   -quiet]
set lutram [get_cells -hier -filter {REF_NAME =~ RAM*X*}  -quiet]
set dsps   [get_cells -hier -filter {REF_NAME =~ DSP58}    -quiet]
set ffs    [get_cells -hier -filter {REF_NAME =~ FD*}     -quiet]

puts "BRAM18   : [llength $bram18]"
puts "BRAM36   : [llength $bram36]"
puts "URAM     : [llength $uram]"
puts "LUTRAM   : [llength $lutram]"
puts "DSP      : [llength $dsps]"
puts "FF       : [llength $ffs]"

# Interpretacion directa del resultado
set total_bram [expr {[llength $bram18] + [llength $bram36]}]
if {$total_bram == 0} {
  puts "\nATENCION: cero BRAM inferidas."
  puts "  Las memorias se convirtieron en registros/LUTRAM."
  puts "  Revisa utilizacion_jerarquica.rpt para ver que modulo las consume."
} else {
  puts "\nBRAM inferidas: $total_bram"
  puts "  Revisa ram.rpt para ver que arrays mapearon y cuales no."
}

# --- Timing --------------------------------------------------------------
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "\nWNS (setup): $wns ns"
if {$wns < 0} {
  puts "  NO cierra a [expr {1000.0/$PERIOD}] MHz."
  puts "  Camino critico probable: arbol de reduccion del array + requantize."
  puts "  Revisa timing.rpt."
} else {
  puts "  Cierra con holgura de $wns ns."
}

puts "\nReportes en: $RPT"
puts "=========================================================="
puts "NPU SINTESIS OOC COMPLETADA"
