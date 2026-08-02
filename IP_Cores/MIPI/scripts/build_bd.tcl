# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# Block Design construction (Vivado 2025.2.1, Versal xcve2302)
#
# TOPOLOGY:
#   CIPS (PS) --M_AXI_FPD (AXI4-full)--> SmartConnect --> soc_top AXI-Lite slave
#   soc_top core-DMA master  --> NoC NSU #0 --> DDR MC (shared with CIPS)
#   soc_top MIPI-DMA master  --> NoC NSU #1 --> DDR MC (shared with CIPS)
#   pl0_resetn (async) --> Processor System Reset (sync) --> all PL logic
#   soc_top irq_out --> CIPS pl_ps_irq[0]
#
# LESSONS APPLIED (Versal):
#   * BD commands ONE AT A TIME in the Tcl console, reading each response.
#     Never paste this whole file blind - silent failures. Run block by block.
#   * PL AXI masters go to DEDICATED NoC slaves of the SAME MC as the CIPS.
#     Do NOT use Connection Automation (routes PL masters to S_AXI_LPD, no DDR).
#   * M_AXI_FPD is AXI4-full -> SmartConnect adapts it down to the AXI-Lite slave.
#   * pl0_resetn is asynchronous -> Processor System Reset with dcm_locked tied
#     to an xlconstant '1'.
#   * ~ is never expanded in Tcl -> use $env(HOME).
#
# This file is annotated as a step-by-step guide. Each "STEP" is a checkpoint:
# run it, read the console, confirm before proceeding.
# =============================================================================

set BD_NAME  mipi_soc_bd
set PART     xcve2302-sfva784-1LP-e-S

# -----------------------------------------------------------------------------
# STEP 1 - create the block design
# Expected: "create_bd_design" returns the BD path; no error.
# -----------------------------------------------------------------------------
create_bd_design $BD_NAME
current_bd_design $BD_NAME

# -----------------------------------------------------------------------------
# STEP 2 - add and configure the CIPS (Versal PS + PMC)
# Expected: versal_cips_0 appears. apply_bd_automation configures boot + PS-DDR.
# Read the console: it should report the CIPS preset applied for the TE0950.
# -----------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0

# Enable one PL clock (100 MHz), one PL reset, M_AXI_FPD, and a PL->PS IRQ.
# NOTE: 100 MHz PL clock (per scope). If timing closure fails in implementation,
# drop pl0_ref_clk to 40-50 MHz here and re-run.
set_property -dict [list \
  CONFIG.CLOCK_MODE {Custom} \
  CONFIG.PS_PMC_CONFIG { \
    PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
    PS_USE_M_AXI_FPD {1} \
    PS_USE_PMCPL_CLK0 {1} \
    PS_NUM_FABRIC_RESETS {1} \
    PS_IRQ_USAGE {{CH0 1}} \
  } \
] [get_bd_cells versal_cips_0]

# -----------------------------------------------------------------------------
# STEP 3 - add the AXI NoC and configure DDR + two PL AXI slave ports (NSU)
# Expected: axi_noc_0 appears. We give it: 1 CIPS master port (from PS DDR),
# plus TWO PL AXI slave interfaces (S00_AXI, S01_AXI) for our two masters, all
# routed to the SAME DDR memory controller.
# -----------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_0

# Configure: 1 memory controller (DDR), 3 AXI slave inputs:
#   S00 = CIPS (PS traffic),  S01 = core DMA master,  S02 = MIPI DMA master.
# Number of NSI (slave interfaces) = 3, one MC port group, 1 clock per NSI.
set_property -dict [list \
  CONFIG.NUM_SI {3} \
  CONFIG.NUM_MI {0} \
  CONFIG.NUM_CLKS {4} \
  CONFIG.MC_CHANNEL_INTERLEAVING {false} \
] [get_bd_cells axi_noc_0]

# Associate each slave interface with DDR (the shared MC) and connect QoS.
# Read the NoC "Associate" dialog equivalents below carefully - this is where
# Connection Automation would go wrong, so we set it explicitly.
set_property -dict [list \
  CONFIG.CONNECTIONS {MC_0 { read_bw {5000} write_bw {5000} }} \
] [get_bd_intf_pins /axi_noc_0/S00_AXI]
set_property -dict [list \
  CONFIG.CONNECTIONS {MC_0 { read_bw {2000} write_bw {2000} }} \
] [get_bd_intf_pins /axi_noc_0/S01_AXI]
set_property -dict [list \
  CONFIG.CONNECTIONS {MC_0 { read_bw {2000} write_bw {2000} }} \
] [get_bd_intf_pins /axi_noc_0/S02_AXI]

# -----------------------------------------------------------------------------
# STEP 4 - instantiate our SoC (the Verilog wrapper as a Module Reference)
# Expected: soc_top_mipi_wrap_0 appears as a hierarchical module ref cell.
# -----------------------------------------------------------------------------
create_bd_cell -type module -reference soc_top_mipi_wrap soc_top_mipi_wrap_0

# -----------------------------------------------------------------------------
# STEP 5 - SmartConnect: adapt CIPS M_AXI_FPD (AXI4-full) to the AXI-Lite slave
# Expected: smartconnect_0 with 1 SI, 1 MI.
# -----------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_0
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells smartconnect_0]

# -----------------------------------------------------------------------------
# STEP 6 - Processor System Reset (sync pl0_resetn) + xlconstant '1' for dcm_locked
# Expected: proc_sys_reset_0 and xlconstant_1 appear.
# -----------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant xlconstant_1
set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] [get_bd_cells xlconstant_1]

# =============================================================================
# WIRING  (run each connect_bd_* individually; read the "connected" response)
# =============================================================================

# -----------------------------------------------------------------------------
# STEP 7 - clocks. One 100 MHz PL clock drives everything in the PL.
# CIPS pl0_ref_clk -> proc_sys_reset slowest_sync_clk, SoC aclk, NoC NSI clks,
# SmartConnect aclk.
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins soc_top_mipi_wrap_0/aclk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins smartconnect_0/aclk]
# NoC per-NSI clocks: aclk0=CIPS domain (PS), aclk1=PL 100MHz for our masters.
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk1]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk2]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk3]

# -----------------------------------------------------------------------------
# STEP 8 - reset. pl0_resetn (async) -> proc_sys_reset ext_reset_in;
# dcm_locked tied to '1'; peripheral_aresetn -> SoC aresetn + SmartConnect.
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins xlconstant_1/dout]        [get_bd_pins proc_sys_reset_0/dcm_locked]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins soc_top_mipi_wrap_0/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins smartconnect_0/aresetn]

# -----------------------------------------------------------------------------
# STEP 9 - control path: CIPS M_AXI_FPD -> SmartConnect -> SoC s_axi (AXI-Lite)
# -----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_FPD] [get_bd_intf_pins smartconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI]  [get_bd_intf_pins soc_top_mipi_wrap_0/s_axi]

# -----------------------------------------------------------------------------
# STEP 10 - data path: the two SoC masters -> two NoC NSU (S01, S02) -> DDR
# CIPS PS DDR traffic uses S00 (connect the CIPS DDR master interface).
# -----------------------------------------------------------------------------
# CIPS -> NoC S00 (PS DDR)
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/FPD_CCI_NOC_0] [get_bd_intf_pins axi_noc_0/S00_AXI]
# core DMA master -> NoC S01
connect_bd_intf_net [get_bd_intf_pins soc_top_mipi_wrap_0/m_axi]    [get_bd_intf_pins axi_noc_0/S01_AXI]
# MIPI DMA master -> NoC S02
connect_bd_intf_net [get_bd_intf_pins soc_top_mipi_wrap_0/mipi_axi] [get_bd_intf_pins axi_noc_0/S02_AXI]

# -----------------------------------------------------------------------------
# STEP 11 - interrupt: SoC irq_out -> CIPS pl_ps_irq0
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_pins soc_top_mipi_wrap_0/irq_out] [get_bd_pins versal_cips_0/pl_ps_irq0]

# -----------------------------------------------------------------------------
# STEP 12 - address assignment.
# The AXI-Lite slave sits at 0xA400_0000 (valid M_AXI_FPD aperture on Versal;
# 0x8000_0000 is NOT a valid aperture for this master). Assign explicitly.
# -----------------------------------------------------------------------------
assign_bd_address
# Verify the AXI-Lite slave landed at 0xA4000000; if not, force it:
set seg [get_bd_addr_segs -of_objects [get_bd_intf_pins soc_top_mipi_wrap_0/s_axi]]
catch {set_property offset 0xA4000000 [get_bd_addr_segs versal_cips_0/M_AXI_FPD/*]}
# The two PL masters see DDR at its NoC-assigned base (typically 0x0_0000_0000
# low DDR or the platform's DDR aperture); the firmware's DDR_BASE (0x70000000)
# is programmed by the PS into axil_soc DDR_BASE_LO/HI, so it must match the DDR
# aperture the NoC exposes to these masters. Confirm with report_bd_address.
report_bd_address

# -----------------------------------------------------------------------------
# STEP 13 - validate, save, generate wrapper
# Expected: validate_bd_design reports 0 errors, 0 critical warnings.
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
make_wrapper -files [get_files ${BD_NAME}.bd] -top
add_files -norecurse [file join [get_property DIRECTORY [current_project]] \
  ${BD_NAME}_wrapper.v ]
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "== BD complete. Next: synth_design, then implementation. =="
