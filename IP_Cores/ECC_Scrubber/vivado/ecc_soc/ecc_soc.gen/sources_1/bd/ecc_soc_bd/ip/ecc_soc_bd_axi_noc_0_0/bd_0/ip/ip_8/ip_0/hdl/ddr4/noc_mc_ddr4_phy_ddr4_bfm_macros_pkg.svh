`ifndef __noc_mc_ddr4_phy_v1_0_10_DDR4_BFM_MACROS_PKG_SVH__
`define __noc_mc_ddr4_phy_v1_0_10_DDR4_BFM_MACROS_PKG_SVH__

package noc_mc_ddr4_phy_v1_0_10_ddr4_bfm_macros_pkg;


`define d4_bfm_info(TAG, VERBOSITY_ENABLE, VERBOSITY_LEVEL, MSG, MSG_LEVEL) \
  if(VERBOSITY_ENABLE) begin \
    if(MSG_LEVEL <= VERBOSITY_LEVEL) begin \
      $display("INFO: [%s] (%m) %0t : %s", TAG, $time, MSG); \
    end \
  end

`define d4_bfm_warning(TAG, VERBOSITY_DISABLE_WARNING, MSG) \
  if(!VERBOSITY_DISABLE_WARNING) begin \
    $warning("[%s] (%m) %0t : WARNING: %s", TAG, $time, MSG); \
  end

`define d4_bfm_error(TAG, VERBOSITY_ERR_TO_WARN, VERBOSITY_DISABLE_WARNING, MSG) \
  if(VERBOSITY_ERR_TO_WARN) begin \
    `d4_bfm_warning(TAG, VERBOSITY_DISABLE_WARNING, MSG) \
  end \
  else begin \
    $error("[%s] (%m) %0t : ERROR: %s", TAG, $time, MSG); \
  end

`define d4_bfm_fatal(TAG, VERBOSITY_FATAL_TO_WARN, VERBOSITY_DISABLE_WARNING, MSG) \
  if(VERBOSITY_FATAL_TO_WARN) begin \
    `d4_bfm_warning(TAG, VERBOSITY_DISABLE_WARNING, MSG) \
  end \
  else begin \
    $fatal(1,"[%s] (%m) %0t : ERROR: %s", TAG, $time, MSG); \
  end


`define ddr4_info(MSG, LEVEL) \
  `d4_bfm_info(TAG, verbosity_en, verbosity_level, $sformatf(MSG), LEVEL)

`define ddr4_warning(MSG) \
  `d4_bfm_warning(TAG, ignore_warning, MSG)

`define ddr4_error(MSG) \
  `d4_bfm_error(TAG, verbosity_err_to_warn, ignore_warning, MSG)

`define ddr4_fatal(MSG) \
  `d4_bfm_fatal(TAG, verbosity_fatal_to_warn, ignore_warning, MSG)

endpackage
  

`endif 
