open_project $env(HOME)/adcs_ip/vivado_adcs/adcs_soc.xpr

# desactivar checkpoint incremental tambien en impl (heredado del clon)
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]

reset_run impl_1
launch_runs impl_1 -to_step write_device_image -jobs 30
wait_on_run impl_1

puts "IMPL STATUS   = [get_property STATUS [get_runs impl_1]]"
puts "IMPL PROGRESS = [get_property PROGRESS [get_runs impl_1]]"

# WNS/timing: confirmar que cierra (el fp_fma a 240 MHz es la ruta critica
# probable; si WNS<0 revisar el dbg_vec registrado y el interlock del dot)
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS = $wns"

# DRC: confirmar cero violaciones antes de exportar
set drcs [get_msg_config -count -severity {CRITICAL WARNING}]
puts "DRC criticos = $drcs"

# exportar la plataforma (XSA fija con bitstream) para PetaLinux
write_hw_platform -fixed -include_bit -force $env(HOME)/adcs_ip/adcs_soc.xsa
puts "XSA escrita: $env(HOME)/adcs_ip/adcs_soc.xsa"
