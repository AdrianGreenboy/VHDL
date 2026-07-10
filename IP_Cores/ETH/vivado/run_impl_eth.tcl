open_project /home/adrian/eth_ip/vivado_eth/eth_soc.xpr

# desactivar checkpoint incremental tambien en impl (heredado del clon)
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]

reset_run impl_1
launch_runs impl_1 -to_step write_device_image -jobs 30
wait_on_run impl_1

puts "IMPL STATUS   = [get_property STATUS [get_runs impl_1]]"
puts "IMPL PROGRESS = [get_property PROGRESS [get_runs impl_1]]"

# WNS/timing: confirmar que cierra
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS = $wns"

# exportar la plataforma (XSA fija con bitstream) para PetaLinux
write_hw_platform -fixed -include_bit -force /home/adrian/eth_ip/eth_soc.xsa
puts "XSA escrita: /home/adrian/eth_ip/eth_soc.xsa"
