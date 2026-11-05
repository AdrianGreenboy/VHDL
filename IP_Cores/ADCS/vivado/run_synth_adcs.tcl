open_project $env(HOME)/adcs_ip/vivado_adcs/adcs_soc.xpr

# el ADCS no usa byte_fifo ni spw_fifo: comprobar que NO quedan (leccion #7)
puts "FIFOs ajenos restantes (debe estar vacio):"
foreach f [get_files -all -quiet {*byte_fifo.vhd *spw_fifo.vhd}] {
  puts "  SOBRA: $f"
  remove_files $f
}

# Audit 2026-11: fp32_fma.vhd es el selector (debe estar). La implementacion
# la fija el paquete de configuracion: en este flujo FPGA debe estar
# fp32_cfg_pkg_xil.vhd (FPO) y NO fp32_cfg_pkg.vhd (RTL portable) a la vez.
puts "configuracion FMA:"
set cfg_rtl [get_files -all -quiet */fp32_cfg_pkg.vhd]
set cfg_xil [get_files -all -quiet */fp32_cfg_pkg_xil.vhd]
if {[llength $cfg_rtl] > 0 && [llength $cfg_xil] > 0} {
  puts "  AMBOS paquetes de configuracion presentes: se quita fp32_cfg_pkg.vhd"
  remove_files $cfg_rtl
}
foreach f {fp32_pkg.vhd fp32_fma.vhd fp32_fma_rtl.vhd fp32_fma_xil.vhd} {
  if {[llength [get_files -all -quiet */$f]] == 0} { puts "  FALTA: $f" }
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
