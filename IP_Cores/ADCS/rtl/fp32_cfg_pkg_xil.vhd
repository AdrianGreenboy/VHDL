-- ============================================================================
-- fp32_cfg_pkg_xil.vhd -- FMA implementation selection for the AMD/Xilinx
-- FPGA flow (audit 2026-11): compile this file INSTEAD of fp32_cfg_pkg.vhd.
-- ============================================================================
package fp32_cfg_pkg is
  constant FMA_IMPL_RTL   : natural := 0;
  constant FMA_IMPL_XIL   : natural := 1;
  constant FMA_IMPL_BEHAV : natural := 2;
  constant C_FMA_IMPL     : natural := FMA_IMPL_XIL;
end package fp32_cfg_pkg;
