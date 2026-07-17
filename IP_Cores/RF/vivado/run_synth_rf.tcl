# run_synth_rf.tcl - Sintesis del SoC RF. UNO POR UNO en la consola Tcl.
open_project $env(HOME)/rf_ip/vivado_rf/rf_soc.xpr

# FIFOs ajenos residuales del clon TSN (byte_fifo/tsn_fifo/spw_fifo): fuera (leccion #7)
puts "FIFOs ajenos restantes (debe estar vacio):"
foreach f [get_files -all -quiet {*byte_fifo.vhd *tsn_fifo.vhd *spw_fifo.vhd}] {
  puts "  SOBRA: $f"
  remove_files $f
}

# barrido de referencias remotas al proyecto padre (leccion #5)
foreach f [get_files -all *] { if {[string match *vivado_tsn* $f]} { puts "REMOTA: $f" } }

# desactivar el checkpoint incremental heredado del clon
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]

update_compile_order -fileset sources_1
puts "TOP = [get_property top [current_fileset]]"
# debe ser bd_soc_usart_wrapper; si un out-of-context lo cambio, restaurar:
if {[get_property top [current_fileset]] ne "bd_soc_usart_wrapper"} {
  set_property top bd_soc_usart_wrapper [current_fileset]
  puts "TOP restaurado a bd_soc_usart_wrapper"
}

reset_run synth_1
launch_runs synth_1 -jobs 30
wait_on_run synth_1
puts "SYNTH STATUS   = [get_property STATUS [get_runs synth_1]]"
puts "SYNTH PROGRESS = [get_property PROGRESS [get_runs synth_1]]"
