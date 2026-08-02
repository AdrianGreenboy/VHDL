# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# Vivado project creation script (Vivado 2025.2.1)
#   Target: Trenz TE0950, AMD Versal xcve2302-sfva784-1LP-e-S
#
# Run:  vivado -mode batch -source create_project.tcl
#   or paste line-by-line in the Tcl console (recommended for BD later).
#
# Lessons applied:
#   - $env(HOME) instead of ~ (Vivado never expands ~ in Tcl)
#   - all RTL analyzed as VHDL-2008
#   - the Verilog wrapper is the top (Vivado will not accept VHDL-2008 as a BD
#     module reference top)
# =============================================================================

set PROJ_NAME  mipi_csi2_rx
set PART       xcve2302-sfva784-1LP-e-S
set REPO       $env(HOME)/vhdl_repo/IP_Cores/MIPI
set RTL        $REPO/rtl
set PROJ_DIR   $env(HOME)/vivado/$PROJ_NAME

# ---- create project ---------------------------------------------------------
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# ---- add RV32 core sources (from the RV32IMA core repo) ---------------------
# Adjust RV32_SRC to wherever your validated RV32 lives.
set RV32_SRC $env(HOME)/vhdl_repo/IP_Cores/RV32i
set rv32_files [list \
  $RV32_SRC/riscv_pkg.vhd \
  $RV32_SRC/control.vhd \
  $RV32_SRC/immgen.vhd \
  $RV32_SRC/regfile.vhd \
  $RV32_SRC/alu.vhd \
  $RV32_SRC/muldiv.vhd \
  $RV32_SRC/csr.vhd \
  $RV32_SRC/cpu_pipeline.vhd \
  $RV32_SRC/dp_ram.vhd \
  $RV32_SRC/dmem.vhd \
  $RV32_SRC/axi4_master.vhd \
  $RV32_SRC/mem_subsys.vhd \
  $RV32_SRC/dma_burst.vhd \
  $RV32_SRC/mem_subsys_dma.vhd \
  $RV32_SRC/axil_soc.vhd \
]

# ---- add MIPI CSI-2 RX sources ---------------------------------------------
set mipi_files [list \
  $RTL/csi2_pkg.vhd \
  $RTL/csi2_ecc.vhd \
  $RTL/csi2_crc16.vhd \
  $RTL/csi2_packet_rx.vhd \
  $RTL/raw12_unpack.vhd \
  $RTL/framebuffer.vhd \
  $RTL/csi2_dual_rx.vhd \
  $RTL/frame_gen.vhd \
  $RTL/dphy_model.vhd \
  $RTL/byte_fifo.vhd \
  $RTL/csi2_selftest.vhd \
  $RTL/csi2_mmio.vhd \
  $RTL/mipi_dma_burst.vhd \
  $RTL/mipi_soc_top.vhd \
  $RTL/soc_top_mipi.vhd \
]

add_files -norecurse $rv32_files
add_files -norecurse $mipi_files
add_files -norecurse $RTL/soc_top_mipi_wrap.v

# force VHDL-2008 on every .vhd
foreach f [concat $rv32_files $mipi_files] {
  set_property file_type {VHDL 2008} [get_files $f]
}

# the Verilog wrapper is the design top
set_property top soc_top_mipi_wrap [current_fileset]

update_compile_order -fileset sources_1

puts "== project created =="
puts "== files loaded; run report to confirm =="
report_compile_order -fileset sources_1
puts ""
puts "== NEXT: build the Block Design interactively following BD_GUIDE.md =="
puts "==       open the project GUI or run build_bd.tcl STEP by STEP =="
