# run_impl_rf.tcl - Implementacion + imagen del SoC RF. UNO POR UNO.
open_project $env(HOME)/rf_ip/vivado_rf/rf_soc.xpr

set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]

reset_run impl_1
launch_runs impl_1 -to_step write_device_image -jobs 30
wait_on_run impl_1
puts "IMPL STATUS   = [get_property STATUS [get_runs impl_1]]"
puts "IMPL PROGRESS = [get_property PROGRESS [get_runs impl_1]]"

# timing: confirmar que cierra
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS = $wns"
set drcs [get_msg_config -count -severity {CRITICAL WARNING}]
puts "DRC criticos = $drcs"

# exportar la plataforma (XSA fija con bitstream) para PetaLinux
write_hw_platform -fixed -include_bit -force $env(HOME)/rf_ip/rf_soc.xsa
puts "XSA escrita: $env(HOME)/rf_ip/rf_soc.xsa"
