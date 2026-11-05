-- ============================================================================
-- fp32_fma.vhd -- FMA fp32 with fixed pipeline latency (IP ADCS).
--   result = a*b + c   (IEEE-754 binary32, RNE, fused, FTZ; contract in
--   fp32_pkg.vhd)
--
-- Audit 2026-11: this entity is now a thin selector (generic IMPL, default
-- C_FMA_IMPL from fp32_cfg_pkg):
--   FMA_IMPL_RTL   (0, default, ASIC + simulation): fp32_fma_rtl, portable,
--                  synthesizable 4-stage pipeline + LAT_FMA-4 output regs,
--                  bit-exact with fp32_pkg.fma_fp32.
--   FMA_IMPL_XIL   (1, FPGA flow): fp32_fma_xil, Xilinx Floating-Point
--                  Operator (C_Latency must equal LAT_FMA, see package_fpo.tcl).
--   FMA_IMPL_BEHAV (2, simulation reference only): fma_fp32() in stage 0 +
--                  LAT_FMA-1 delay registers (480-bit accumulator, NOT
--                  synthesizable).
-- Previously the FPGA flow had to swap fp32_fma.vhd for fp32_fma_xil.vhd and
-- there was no synthesizable implementation for the ASIC at all.
-- No internal backpressure (the datapath never overlaps collisions).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp32_pkg.all;
use work.fp32_cfg_pkg.all;

entity fp32_fma is
  generic (
    LAT_FMA : natural := 8;
    MUT     : natural := 0;           -- verification only; 0 in normal use
    IMPL    : natural := C_FMA_IMPL
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    in_valid  : in  std_logic;
    a         : in  std_logic_vector(31 downto 0);
    b         : in  std_logic_vector(31 downto 0);
    c         : in  std_logic_vector(31 downto 0);
    out_valid : out std_logic;
    result    : out std_logic_vector(31 downto 0)
  );
end entity fp32_fma;

architecture top of fp32_fma is
  component fp32_fma_xil is
    generic (LAT_FMA : natural := 8; MUT : natural := 0);
    port (clk : in std_logic; rst_n : in std_logic; in_valid : in std_logic;
          a, b, c : in std_logic_vector(31 downto 0);
          out_valid : out std_logic; result : out std_logic_vector(31 downto 0));
  end component;
begin

  g_rtl : if IMPL = FMA_IMPL_RTL generate
    u_fma : entity work.fp32_fma_rtl
      generic map (LAT_FMA => LAT_FMA, MUT => MUT)
      port map (clk => clk, rst_n => rst_n, in_valid => in_valid,
                a => a, b => b, c => c, out_valid => out_valid, result => result);
  end generate;

  g_xil : if IMPL = FMA_IMPL_XIL generate
    u_fma : fp32_fma_xil
      generic map (LAT_FMA => LAT_FMA, MUT => MUT)
      port map (clk => clk, rst_n => rst_n, in_valid => in_valid,
                a => a, b => b, c => c, out_valid => out_valid, result => result);
  end generate;

  g_beh : if IMPL = FMA_IMPL_BEHAV generate
    type pipe_t is array (0 to LAT_FMA-1) of std_logic_vector(31 downto 0);
    signal pd : pipe_t;
    signal pv : std_logic_vector(LAT_FMA-1 downto 0);
  begin
    process (clk, rst_n)
    begin
      if rst_n = '0' then
        pv <= (others => '0');
        pd <= (others => (others => '0'));
      elsif rising_edge(clk) then
        if in_valid = '1' then
          pd(0) <= fma_fp32(a, b, c, MUT);
        end if;
        pv(0) <= in_valid;
        for i in 1 to LAT_FMA-1 loop
          pd(i) <= pd(i-1);
          pv(i) <= pv(i-1);
        end loop;
      end if;
    end process;
    result    <= pd(LAT_FMA-1);
    out_valid <= pv(LAT_FMA-1);
  end generate;

end architecture top;
