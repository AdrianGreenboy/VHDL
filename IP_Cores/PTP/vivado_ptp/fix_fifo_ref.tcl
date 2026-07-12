open_project ptp_soc.xpr
remove_files /home/adrian/spw_ip/spw_fifo.vhd
add_files -norecurse /home/adrian/vhdl_repo/IP_Cores/PTP/rtl/spw_fifo.vhd
set_property file_type {VHDL 2008} [get_files spw_fifo.vhd]
update_module_reference [get_ips]
close_project
