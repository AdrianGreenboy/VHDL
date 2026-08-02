# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# Synthesis, implementation, and XSA export (Vivado 2025.2.1)
# Run after build_bd.tcl completed and the BD wrapper is the top.
# =============================================================================

# make sure the BD wrapper (not an OOC synth artifact) is the top
set_property top mipi_soc_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ---- synthesis --------------------------------------------------------------
launch_runs synth_1 -jobs 8
wait_on_run synth_1
open_run synth_1 -name synth_1

# sanity: confirm the framebuffers mapped to Versal BRAM (RAMB18E5_INT), not FFs
puts "== BRAM primitives (expect RAMB18E5_INT for framebuffers) =="
report_utilization -cells [get_cells -hierarchical -filter {REF_NAME =~ RAMB*}] -return_string

# ---- implementation ---------------------------------------------------------
launch_runs impl_1 -jobs 8
wait_on_run impl_1
open_run impl_1

# ---- timing check -----------------------------------------------------------
# 100 MHz PL clock -> 10 ns period. Confirm WNS >= 0.
puts "== timing summary (WNS must be >= 0 at 100 MHz) =="
report_timing_summary -delay_type min_max -report_unconstrained \
  -check_timing_verbose -max_paths 10 -input_pins -return_string
# If WNS < 0: reduce PL clock (PMC_CRP_PL0_REF_CTRL_FREQMHZ) to 50 MHz in the
# CIPS and re-run. The design was scoped with margin for this.

# ---- bitstream (PDI) + XSA --------------------------------------------------
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1

# export XSA (with bitstream/PDI) for PetaLinux
set XSA_OUT $env(HOME)/vhdl_repo/IP_Cores/MIPI/petalinux/mipi_soc.xsa
write_hw_platform -fixed -include_bit -force -file $XSA_OUT
puts "== XSA exported to $XSA_OUT =="
