open_project ptp_soc.xpr
update_module_reference [get_ips]
reset_run synth_1 -prev_step
reset_run impl_1 -prev_step
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1
open_run impl_1
report_timing_summary -delay_type max -max_paths 3 -file timing_check.rpt
write_hw_platform -fixed -force ../ptp_soc.xsa
