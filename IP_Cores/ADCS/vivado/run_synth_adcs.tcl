open_project $env(HOME)/adcs_ip/vivado_adcs/adcs_soc.xpr

# el ADCS no usa byte_fifo ni spw_fifo: comprobar que NO quedan (leccion #7)
puts "FIFOs ajenos restantes (debe estar vacio):"
foreach f [get_files -all -quiet {*byte_fifo.vhd *spw_fifo.vhd}] {
  puts "  SOBRA: $f"
  remove_files $f
}

# CRITICO: la arquitectura behav (fp32_fma.vhd, acumulador 480b) NO debe estar
# en el fileset de sintesis. Solo fp32_fma_xil.vhd. Comprobar y sacar.
puts "fp32_fma.vhd (behav) en sintesis (debe estar vacio):"
foreach f [get_files -all -quiet *fp32_fma.vhd] {
  if {![string match *fp32_fma_xil.vhd $f]} {
    puts "  SOBRA (behav no sintetizable): $f"
    remove_files $f
  }
}

# confirmar que el core fp_fma existe (generado por package_fpo.tcl)
puts "fp_fma IP:"
foreach ip [get_ips -quiet fp_fma] {
  puts "  $ip  latencia=[get_property CONFIG.C_Latency $ip]  op=[get_property CONFIG.Operation_Type $ip]"
}

# barrido de referencias remotas al proyecto padre (leccion #5)
foreach f [get_files -all *] { if {[string match *spw_ip* $f]} { puts "REMOTA: $f" } }

# desactivar el checkpoint incremental heredado del clon
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]

update_compile_order -fileset sources_1
puts "TOP = [get_property top [current_fileset]]"

# resetear y sintetizar (bloqueante)
reset_run synth_1
launch_runs synth_1 -jobs 30
wait_on_run synth_1

puts "SYNTH STATUS   = [get_property STATUS [get_runs synth_1]]"
puts "SYNTH PROGRESS = [get_property PROGRESS [get_runs synth_1]]"
