-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4 fusion
-- pqc_core: ML-KEM and ML-DSA sharing ONE Keccak sponge.
-- VHDL-2008. ASCII-only. MIT license.
--
-- This is where the integration pays off. The KEM and DSA cores each drove
-- their own Keccak sponge, and Keccak-f1600 is the most expensive block in
-- the design. keccak_sponge, keccak_f1600 and keccak_pkg were confirmed
-- byte-identical in the two trees (same md5), which is what makes one shared
-- instance legitimate rather than a coincidence.
--
-- Both cores are instantiated in their _sx form, with the sponge lifted to
-- ports. The single sponge lives here and is muxed between them by an
-- algorithm register. Only one algorithm runs at a time -- the same invariant
-- that holds within each core -- so this is a mux, not an arbiter.
--
-- alg encoding:  '0' ML-KEM   '1' ML-DSA
--
-- The verification bar is strong and needs no new calibration: the fused core
-- must reproduce BOTH Layer 4 signatures, 95e07091fa5b3cc4 for KEM and
-- f93232f7ea2d1575 for DSA, back to back over the shared sponge. Those
-- signatures are already validated, and sharing the block cannot move them
-- unless the sharing is wrong.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pqc_core is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- '0' selects the ML-KEM core, '1' the ML-DSA core
    alg       : in  std_logic;

    -- ML-KEM side
    kem_op    : in  std_logic_vector(1 downto 0);
    kem_start : in  std_logic;
    kem_done  : out std_logic;
    kem_busy  : out std_logic;
    kem_rej   : out std_logic;
    kem_haddr : in  std_logic_vector(12 downto 0);
    kem_hdin  : in  std_logic_vector(7 downto 0);
    kem_hwe   : in  std_logic;
    kem_hsel  : in  std_logic;
    kem_hdout : out std_logic_vector(7 downto 0);

    -- ML-DSA side
    dsa_op    : in  std_logic_vector(1 downto 0);
    dsa_start : in  std_logic;
    dsa_siglen : in std_logic_vector(15 downto 0);
    dsa_done  : out std_logic;
    dsa_busy  : out std_logic;
    dsa_result : out std_logic;
    dsa_reason : out std_logic_vector(2 downto 0);
    dsa_haddr : in  std_logic_vector(13 downto 0);
    dsa_hdin  : in  std_logic_vector(7 downto 0);
    dsa_hwe   : in  std_logic;
    dsa_hsel  : in  std_logic;
    dsa_hdout : out std_logic_vector(7 downto 0));
end entity pqc_core;

architecture rtl of pqc_core is

  -- KEM core's sponge interface
  signal k_mode  : std_logic_vector(1 downto 0);
  signal k_init, k_we, k_adone, k_re : std_logic;
  signal k_din   : std_logic_vector(7 downto 0);

  -- DSA core's sponge interface
  signal d_mode  : std_logic_vector(1 downto 0);
  signal d_init, d_we, d_adone, d_re : std_logic;
  signal d_din   : std_logic_vector(7 downto 0);

  -- shared sponge
  signal sp_mode : std_logic_vector(1 downto 0);
  signal sp_init, sp_we, sp_adone, sp_re, sp_dvalid, sp_ready : std_logic;
  signal sp_din, sp_dout : std_logic_vector(7 downto 0);

  -- KEM inspection port is tied off; the Layer 4 test uses the host path only
  signal kem_insp_data : std_logic_vector(15 downto 0);

begin

  u_kem : entity work.kem_core_sx
    port map (clk => clk, rst_n => rst_n, op => kem_op, start => kem_start,
              done => kem_done, busy => kem_busy, rejected => kem_rej,
              h_addr => kem_haddr, h_din => kem_hdin, h_we => kem_hwe,
              h_sel => kem_hsel, h_dout => kem_hdout,
              insp_en => '0', insp_slot => 0,
              insp_addr => (others => '0'), insp_data => kem_insp_data,
              xsp_mode => k_mode, xsp_init => k_init, xsp_din => k_din,
              xsp_we => k_we, xsp_adone => k_adone, xsp_dout => sp_dout,
              xsp_re => k_re, xsp_dvalid => sp_dvalid, xsp_ready => sp_ready);

  u_dsa : entity work.dsa_core_sx
    port map (clk => clk, rst_n => rst_n, op => dsa_op, start => dsa_start,
              siglen => dsa_siglen, done => dsa_done, busy => dsa_busy,
              result => dsa_result, reason => dsa_reason,
              h_sel => dsa_hsel, h_addr => dsa_haddr, h_din => dsa_hdin,
              h_we => dsa_hwe, h_dout => dsa_hdout,
              xsp_mode => d_mode, xsp_init => d_init, xsp_din => d_din,
              xsp_we => d_we, xsp_adone => d_adone, xsp_dout => sp_dout,
              xsp_re => d_re, xsp_dvalid => sp_dvalid, xsp_ready => sp_ready);

  -- The single sponge, selected by alg. The unselected core sees its own
  -- sponge outputs (dout, dvalid, ready) driven by the shared instance too,
  -- but it is idle and reads none of them.
  sp_mode  <= d_mode  when alg = '1' else k_mode;
  sp_init  <= d_init  when alg = '1' else k_init;
  sp_din   <= d_din   when alg = '1' else k_din;
  sp_we    <= d_we    when alg = '1' else k_we;
  sp_adone <= d_adone when alg = '1' else k_adone;
  sp_re    <= d_re    when alg = '1' else k_re;

  u_sponge : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => sp_mode, init => sp_init,
              din => sp_din, din_we => sp_we, absorb_done => sp_adone,
              dout => sp_dout, dout_re => sp_re, dout_valid => sp_dvalid,
              ready => sp_ready);

end architecture rtl;
