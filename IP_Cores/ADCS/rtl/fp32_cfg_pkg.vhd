-- ============================================================================
-- fp32_cfg_pkg.vhd -- FMA implementation selection (audit 2026-11).
-- DEFAULT / ASIC / simulation file set: portable pipelined RTL FMA.
-- The AMD/Xilinx FPGA flow compiles fp32_cfg_pkg_xil.vhd INSTEAD of this file
-- (same package name, C_FMA_IMPL = FMA_IMPL_XIL) to use the Floating-Point
-- Operator core. Never compile both.
-- ============================================================================
package fp32_cfg_pkg is
  constant FMA_IMPL_RTL   : natural := 0;   -- fp32_fma_rtl (synthesizable, portable)
  constant FMA_IMPL_XIL   : natural := 1;   -- fp32_fma_xil (FPO core, FPGA only)
  constant FMA_IMPL_BEHAV : natural := 2;   -- fp32_pkg.fma_fp32 reference (sim only)
  constant C_FMA_IMPL     : natural := FMA_IMPL_RTL;
end package fp32_cfg_pkg;
