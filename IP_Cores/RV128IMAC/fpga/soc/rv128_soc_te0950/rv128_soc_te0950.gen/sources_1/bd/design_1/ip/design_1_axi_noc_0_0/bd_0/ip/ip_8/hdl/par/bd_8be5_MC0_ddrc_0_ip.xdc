
#########
create_clock -period 5.0 [get_ports sys_clk_p]
########
set_property IOSTANDARD POD12  [get_ports {ch0_ddr4_dq[*]}]  
set_property IOSTANDARD DIFF_POD12 [get_ports {ch0_ddr4_dqs_t[*] ch0_ddr4_dqs_c[*]}]
 
set_property ODT RTT_40 [get_ports {ch0_ddr4_dq[*] ch0_ddr4_dqs_t[*] ch0_ddr4_dqs_c[*]}] 
#####
set_property IOSTANDARD SSTL12 [get_ports {ch0_ddr4_adr[*] ch0_ddr4_act_n ch0_ddr4_cs_n[*] ch0_ddr4_ba[*] ch0_ddr4_bg[*] ch0_ddr4_cke[*] ch0_ddr4_odt[*]}]
set_property IOSTANDARD DIFF_SSTL12  [get_ports {ch0_ddr4_ck_t[*] ch0_ddr4_ck_c[*]}]
set_property IOSTANDARD LVCMOS12  [get_ports {ch0_ddr4_reset_n}]
set_property DRIVE 8 [get_ports {ch0_ddr4_reset_n}]
#####
#####
set_property IOSTANDARD POD12 [get_ports {ch0_ddr4_dm_dbi_n[*]}]

 
set_property ODT RTT_40 [get_ports {ch0_ddr4_dm_dbi_n[*]}]

set_property SLEW FAST [get_ports {ch0_ddr4_dm_dbi_n[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ch0_ddr4_dm_dbi_n[*]}]
set_property EQUALIZATION EQ_LEVEL2 [get_ports {ch0_ddr4_dm_dbi_n[*]}]
set_property OFFSET_CNTRL CNTRL_NONE [get_ports {ch0_ddr4_dm_dbi_n[*]}]
set_property EQUALIZATION EQ_LEVEL2 [get_ports {ch0_ddr4_dq[*] ch0_ddr4_dqs_t[*] ch0_ddr4_dqs_c[*]}]
set_property OFFSET_CNTRL CNTRL_NONE [get_ports {ch0_ddr4_dq[*] ch0_ddr4_dqs_t[*] ch0_ddr4_dqs_c[*]}]
set_property SLEW FAST  [get_ports {ch0_ddr4_adr[*] ch0_ddr4_act_n ch0_ddr4_cke[*] ch0_ddr4_cs_n[*] ch0_ddr4_ba[*] ch0_ddr4_bg[*] ch0_ddr4_ck_t[*] ch0_ddr4_ck_c[*] ch0_ddr4_odt[*] ch0_ddr4_dq[*] ch0_ddr4_dqs_t[*] ch0_ddr4_dqs_c[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40  [get_ports {ch0_ddr4_adr[*] ch0_ddr4_act_n ch0_ddr4_cke[*] ch0_ddr4_cs_n[*] ch0_ddr4_ba[*] ch0_ddr4_bg[*] ch0_ddr4_ck_t[*] ch0_ddr4_ck_c[*] ch0_ddr4_odt[*] ch0_ddr4_dq[*] ch0_ddr4_dqs_t[*] ch0_ddr4_dqs_c[*]}]
#####
#####Dual-Channel###
set_property IOSTANDARD LVDS15 [get_ports {sys_clk_p sys_clk_n}]
set_property EQUALIZATION EQ_LEVEL2 [get_ports {sys_clk_p sys_clk_n}]
set_property DC_BIAS DC_BIAS_0 [get_ports {sys_clk_p sys_clk_n}]
#########
##################################
