open_project /home/adrian/spw_ip/vivado_spw/spw_soc.xpr

# el SPW no usa byte_fifo: comprobar que NO queda ninguno (leccion #7)
puts "BYTEFIFO restantes (debe estar vacio):"
foreach f [get_files -all -quiet *byte_fifo.vhd] {
  puts "  SOBRA: $f"
  remove_files $f
}

# barrido de referencias remotas al proyecto padre (leccion #5)
foreach f [get_files -all *] { if {[string match *can_ip* $f]} { puts "REMOTA: $f" } }

# desactivar el checkpoint incremental heredado del clon
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]

update_compile_order -fileset sources_1

# confirmar top
puts "TOP = [get_property top [current_fileset]]"

# resetear y sintetizar (bloqueante gracias a wait_on_run)
reset_run synth_1
launch_runs synth_1 -jobs 30
wait_on_run synth_1

puts "SYNTH STATUS   = [get_property STATUS [get_runs synth_1]]"
puts "SYNTH PROGRESS = [get_property PROGRESS [get_runs synth_1]]"
