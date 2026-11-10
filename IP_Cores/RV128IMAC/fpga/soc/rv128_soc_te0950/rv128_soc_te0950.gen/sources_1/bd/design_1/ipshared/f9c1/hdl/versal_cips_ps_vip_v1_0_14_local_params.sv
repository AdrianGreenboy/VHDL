 /********************************************************************
 * File : versal_cips_ps_vip_v1_0_14_local_params.sv
 *
 * Date : 2015-16
 *
 * Description : Parameters used in Versal CIPS PS BFM
 *
 *****************************************************************************/

// balakasa: Changed as per IP3 database
function automatic integer f_clogb2;
  //integer value;
  input [31:0] value;
  begin
      value = value - 1;
      for (f_clogb2 = 0; value > 0; f_clogb2 = f_clogb2 + 1) begin
          value = value >> 1;
      end
  end
endfunction

/////////////////////////////////////////////////Versal PS BFM parameters///////////////////////////
parameter addr_width = 44;   // maximum address width
// balakasa: Changed as per IP3 database
localparam integer data_width = 32;   // maximum data width.
//parameter integer data_width = 32;   // maximum data width.
parameter axi_mgp_data_width = 32;
parameter axi_slv_excl_support = 0; // For Slave  ports EXCL access is not supported
parameter axi_mst_excl_support = 1; // For Master ports EXCL access is supported
/* for ACP slave ports*/
parameter axi_acp_name  = "S_AXI_ACP";
parameter axi_acp_data_width = 128;
parameter axi_acp_id_width   = 5;
parameter axi_acp_rd_outstanding = 7;
parameter axi_acp_wr_outstanding = 3;
parameter axi_acp_outstanding = axi_acp_rd_outstanding + axi_acp_wr_outstanding;
parameter axi_acp_awuser_width   = 2;
parameter axi_acp_aruser_width   = 2;
parameter axi_acp_ruser_width    = 0;
parameter axi_acp_wuser_width    = 0;
parameter axi_acp_buser_width    = 0;
parameter axi_acp_region_width   = 0;

/* for ACE slave ports*/
parameter axi_ace_name  = "S_AXI_ACE";
parameter axi_ace_data_width = 128;
parameter axi_ace_id_width   = 6;
parameter axi_ace_rd_outstanding = 7;
parameter axi_ace_wr_outstanding = 3;
parameter axi_ace_outstanding = axi_ace_rd_outstanding + axi_ace_wr_outstanding;
parameter axi_ace_awuser_width   = 15;
parameter axi_ace_aruser_width   = 15;
parameter axi_ace_ruser_width    = 1;
parameter axi_ace_wuser_width    = 1;
parameter axi_ace_buser_width    = 1;
parameter axi_ace_region_width   = 4;

//slave address ranges
//parameter ocm_start_addr = 49'h0_0000_FFFC_0000;
//parameter ocm_end_addr   = 49'h0_0000_FFFF_FFFF;

parameter saxigp0_start_addr = 49'h0_0000_A000_0000;
parameter saxigp0_end_addr   = 49'h0_0000_BFFF_FFFF;

parameter saxigp1_start_addr = 49'h0_0000_8000_0000;
parameter saxigp1_end_addr   = 49'h0_0000_9FFF_FFFF;

// balakasa: Need to look into the CPMCFG slave's address range. It's conflicting with the register space
parameter pscpm_cfg_start_addr = 49'h0_0000_FC00_0000;
parameter pscpm_cfg_end_addr   = 49'h0_0000_FCFF_FFFF;

// balakasa: It'a the PCIe Region-0 space
parameter pscpmpcie_start_addr = 49'h0_0000_E000_0000;
parameter pscpmpcie_end_addr   = 49'h0_0000_EFFF_FFFF;

parameter psnocpci_axi0_start_addr = 49'h0_0006_0000_0000;
parameter psnocpci_axi0_end_addr   = 49'h0_0007_FFFF_FFFF;

parameter psnocpci_axi1_start_addr = 49'h0_0080_0000_0000;
parameter psnocpci_axi1_end_addr   = 49'h0_00BF_FFFF_FFFF;

parameter psnocnci_axi0_start_addr = 49'h0_0700_0000_0000;
parameter psnocnci_axi0_end_addr   = 49'h0_077F_FFFF_FFFF;

parameter psnocnci_axi1_start_addr = 49'h0_0780_0000_0000;
parameter psnocnci_axi1_end_addr   = 49'h0_07FF_FFFF_FFFF;

parameter pmcnoc_axi_start_addr    = 49'h0_0008_0000_0000;
parameter pmcnoc_axi_end_addr      = 49'h0_000F_FFFF_FFFF;

// balakasa: Below paramters are not used. And these are not matching with the versal cips register map also
// For PSNOCCCIAXI, the range is 0x0000_0000 to 0x7FFF_FFFF
parameter psnoccci_axi_start_addr = 49'h0_0000_0000_0000;
parameter psnoccci_axi_end_addr   = 49'h0_0000_7FFF_FFFF;

parameter psnoccci_axi0_start_addr = 49'h0_0000_0000_0000;
parameter psnoccci_axi0_end_addr   = 49'h0_0000_7FFF_FFFF;

parameter psnoccci_axi1_start_addr = 49'h0_00C0_0000_0000;
parameter psnoccci_axi1_end_addr   = 49'h0_00FF_FFFF_FFFF;

parameter psnoccci_axi2_start_addr = 49'h0_0500_0000_0000;
parameter psnoccci_axi2_end_addr   = 49'h0_05FF_FFFF_FFFF;

parameter psnoccci_axi3_start_addr = 49'h0_0600_0000_0000;
parameter psnoccci_axi3_end_addr   = 49'h0_06FF_FFFF_FFFF;

// balakasa: Modified as the versal cips reg map
parameter rpu_noc_start_addr = 64'h0000_0500_0000_0000;
parameter rpu_noc_end_addr   = 64'h0000_05FF_FFFF_FFFF;

parameter max_chars  = 128;  // max characters for file name
// balakasa: Changed as per IP3 database
localparam integer mem_width  = data_width/8; /// memory width in bytes
localparam integer shft_addr_bits = f_clogb2(mem_width); /// Address to be right shifted
//parameter integer mem_width  = data_width/8; /// memory width in bytes
//parameter integer shft_addr_bits = f_clogb2(mem_width); /// Address to be right shifted
parameter int_width  = 32; //integre width

/* for internal read/write APIs used for data transfers */
// balakasa: Changed as per the IP3 database
localparam integer max_burst_len   = 256;  /// maximum brst length on axi 
localparam integer max_data_width  = 128; // maximum data width for internal AXI bursts 
localparam integer max_burst_bits  = (max_data_width * max_burst_len); // maximum data width for internal AXI bursts 
localparam integer max_reg_data_width  = 32; // maximum data width for internal AXI bursts 
localparam integer max_reg_burst_bits  = (max_reg_data_width * max_burst_len); // maximum data width for internal AXI bursts 
localparam integer max_burst_bytes = (max_burst_bits)/8;                // maximum data bytes in each transfer 
localparam integer max_burst_bytes_width = f_clogb2(max_burst_bytes); // maximum data width for internal AXI bursts 
localparam integer max_reg_burst_bytes = (max_reg_burst_bits)/8;                // maximum data bytes in each transfer 
localparam integer max_reg_burst_bytes_width = f_clogb2(max_reg_burst_bytes); // maximum data width for internal AXI bursts 
//parameter integer max_burst_len   = 256;  /// maximum brst length on axi 
//parameter integer max_data_width  = 128; // maximum data width for internal AXI bursts 
//parameter integer max_burst_bits  = (max_data_width * max_burst_len); // maximum data width for internal AXI bursts 
//parameter integer max_burst_bytes = (max_burst_bits)/8;                // maximum data bytes in each transfer 
//parameter integer max_burst_bytes_width = f_clogb2(max_burst_bytes); // maximum data width for internal AXI bursts 
parameter all_strb_valid = 2048'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

// balakasa: Changed as per the IP3 database
localparam integer max_registers   = 32;
localparam integer max_regs_width  = f_clogb2(max_registers);
//parameter integer max_registers   = 32;
//parameter integer max_regs_width  = f_clogb2(max_registers);

parameter REG_MEM = 2'b00, DDR_MEM = 2'b01, OCM_MEM = 2'b10, INVALID_MEM_TYPE = 2'b11; 

parameter ALL_RANDOM= 2'b00;
parameter ALL_ZEROS = 2'b01;
parameter ALL_ONES  = 2'b10;

/* AXI transfer types */
parameter AXI_FIXED = 2'b00;
parameter AXI_INCR  = 2'b01;
parameter AXI_WRAP  = 2'b10;

/* Exclusive Access */
parameter AXI_NRML  = 2'b00;
parameter AXI_EXCL  = 2'b01;
parameter AXI_LOCK  = 2'b10;

/* AXI Response types */
parameter AXI_OK = 2'b00;
parameter AXI_EXCL_OK  = 2'b01;
parameter AXI_SLV_ERR  = 2'b10;
parameter AXI_DEC_ERR  = 2'b11;

/* Display */
parameter DISP_VIP = "VERSAL_CIPS_PS_VIP";
parameter DISP_INFO = "VERSAL_CIPS_PS_VIP_INFO";
parameter DISP_WARN = "VERSAL_CIPS_PS_VIP_WARNING";
parameter DISP_ERR  = "VERSAL_CIPS_PS_VIP_ERROR";
parameter DISP_INT_INFO = "VERSAL_CIPS_PS_VIP_INT_INFO";

/* Latency types */
parameter BEST_CASE  = 0;
parameter AVG_CASE   = 1;
parameter WORST_CASE = 2;
parameter RANDOM_CASE  = 3;

/* Latency Parameters ACP  */
parameter acp_wr_min   =  21;
parameter acp_wr_avg   =  16;
parameter acp_wr_max   =  27;
parameter acp_rd_min   =  34;
parameter acp_rd_avg   =  125;
parameter acp_rd_max   =  130;

/* Latency Parameters GP  */
  parameter gp_wr_min   =  21;
  parameter gp_wr_avg   =  16;
  parameter gp_wr_max   =  46;
  parameter gp_rd_min   =  38;
  parameter gp_rd_avg   =  125;
  parameter gp_rd_max   =  130; 

/* ID VALID and INVALID */
parameter secure_access_enabled = 0;
parameter id_invalid = 0;
parameter id_valid = 1;

parameter ddr_start_addr = 40'h0_0000_0000;
parameter ddr_end_addr   = 40'h0_7FFF_FFFF;
parameter high_ddr_start_addr = 40'h8_0000_0000;

parameter ocm_start_addr = 40'h0_FFFC_0000;
parameter ocm_end_addr   = 40'h0_FFFF_FFFF;

parameter reg_mem1_start_addr = 40'h0_F000_0000;
parameter reg_mem1_end_addr   = 40'h0_F7FF_FFFF; 
parameter reg_mem2_start_addr = 40'h0_F800_0000;
parameter reg_mem2_end_addr   = 40'h0_F9FF_FFFF; 
parameter reg_mem3_start_addr = 40'h0_FA00_0000;
parameter reg_mem3_end_addr   = 40'h0_FAFF_FFFF; 
parameter reg_mem4_start_addr = 40'h0_FB00_0000;
parameter reg_mem4_end_addr   = 40'h0_FB7F_FFFF; 
parameter reg_mem5_start_addr = 40'h0_FB80_0000;
parameter reg_mem5_end_addr   = 40'h0_FBBF_FFFF; 
parameter reg_mem6_start_addr = 40'h0_FBC0_0000;
parameter reg_mem6_end_addr   = 40'h0_FBDF_5980; 
parameter reg_mem7_start_addr = 40'h0_FBE0_0000;
parameter reg_mem7_end_addr   = 40'h0_FBFF_FFFF; 
parameter reg_mem8_start_addr = 40'h0_FD00_0000;  // 16MB
parameter reg_mem8_end_addr   = 40'h0_FDFF_FFFF; 
parameter reg_mem9_start_addr = 40'h0_FE00_0000;  // 16MB
parameter reg_mem9_end_addr   = 40'h0_FEFF_FFFF; 
parameter reg_mem10_start_addr = 40'h0_FF00_0000; // 8MB
parameter reg_mem10_end_addr   = 40'h0_FF7F_FFFF; 
parameter reg_mem11_start_addr = 40'h0_FF80_0000; // 4MB
parameter reg_mem11_end_addr   = 40'h0_FFBF_FFFF; 
parameter reg_mem12_start_addr = 40'h0_FFC0_0000; // 2MB
parameter reg_mem12_end_addr   = 40'h0_FFDF_FFFF; 

/* for Master port APIs and AXI protocol related signal widths*/
parameter axi_burst_len  = 256;
parameter axi_len_width  = 8;
parameter axi_size_width = 3;
parameter axi_brst_type_width = 2;
parameter axi_lock_width = 1;
parameter axi_cache_width = 4;
parameter axi_prot_width = 3;
parameter axi_rsp_width = 2;
parameter axi_qos_width  = 4;
parameter axi_max_mdata_width  = 128;
// balakasa: Changed as per the IP3 database
localparam integer max_transfer_bytes = 256; // For Master APIs.
localparam integer max_transfer_bytes_width = f_clogb2(max_transfer_bytes); // For Master APIs.
//parameter integer max_transfer_bytes = 256; // For Master APIs.
//parameter integer max_transfer_bytes_width = f_clogb2(max_transfer_bytes); // For Master APIs.

/* Interrupt bits supported */
parameter irq_width = 16;

bit	[31:0]	slverr_start_addr;
bit	[31:0]	slverr_end_addr;
bit             set_slv_err_called;

// assiciative array declaration
// Accessing slverr_start_addr_a[start_address] = end_address;

bit	[31:0]	slverr_start_addr_a[int];
//bit	[63:0]	slverr_end_addr_a[int];

