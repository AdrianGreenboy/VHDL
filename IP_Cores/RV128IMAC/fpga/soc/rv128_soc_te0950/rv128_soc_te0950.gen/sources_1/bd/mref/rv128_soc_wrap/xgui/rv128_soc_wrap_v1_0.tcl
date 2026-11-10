# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DRAM_MASK" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DRAM_PHYS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TICK_DIV" -parent ${Page_0}


}

proc update_PARAM_VALUE.DRAM_MASK { PARAM_VALUE.DRAM_MASK } {
	# Procedure called to update DRAM_MASK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DRAM_MASK { PARAM_VALUE.DRAM_MASK } {
	# Procedure called to validate DRAM_MASK
	return true
}

proc update_PARAM_VALUE.DRAM_PHYS { PARAM_VALUE.DRAM_PHYS } {
	# Procedure called to update DRAM_PHYS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DRAM_PHYS { PARAM_VALUE.DRAM_PHYS } {
	# Procedure called to validate DRAM_PHYS
	return true
}

proc update_PARAM_VALUE.TICK_DIV { PARAM_VALUE.TICK_DIV } {
	# Procedure called to update TICK_DIV when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TICK_DIV { PARAM_VALUE.TICK_DIV } {
	# Procedure called to validate TICK_DIV
	return true
}


proc update_MODELPARAM_VALUE.TICK_DIV { MODELPARAM_VALUE.TICK_DIV PARAM_VALUE.TICK_DIV } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TICK_DIV}] ${MODELPARAM_VALUE.TICK_DIV}
}

proc update_MODELPARAM_VALUE.DRAM_PHYS { MODELPARAM_VALUE.DRAM_PHYS PARAM_VALUE.DRAM_PHYS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DRAM_PHYS}] ${MODELPARAM_VALUE.DRAM_PHYS}
}

proc update_MODELPARAM_VALUE.DRAM_MASK { MODELPARAM_VALUE.DRAM_MASK PARAM_VALUE.DRAM_MASK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DRAM_MASK}] ${MODELPARAM_VALUE.DRAM_MASK}
}

