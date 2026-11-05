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
-- AUDIT 2026-11 changes:
--  * The sponge mux select is the LATCHED algorithm: alg is sampled while
--    both cores are idle and held while either is busy, so a CTRL write in
--    the middle of an operation can no longer steal the sponge. A start for
--    the algorithm that is not selected, or for either core while the other
--    one is busy, is ignored and flagged in err(1).
--  * The KEM implicit-rejection flag (kem_rej) is removed from the port
--    list: it was a plaintext-checking oracle.
--  * zeroize: wipes both cores' memories and the sponge state (aborting a
--    running operation); zdone pulses when everything is clear. Both cores
--    also wipe automatically at the end of each operation (G_ZEROIZE).
--  * err: sticky status, cleared by err_clr:
--      0 sponge protocol error (dropped command)
--      1 command rejected (busy, illegal op, or alg mismatch)
--      2 ML-DSA Sign reached its iteration bound
--      3 reserved
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
  generic (
    G_ZEROIZE       : boolean := true;
    G_SIGN_MAX_ITER : integer := 814);
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
    dsa_hdout : out std_logic_vector(7 downto 0);

    -- zeroization and status
    zeroize   : in  std_logic := '0';
    zbusy     : out std_logic;
    zdone     : out std_logic;
    err       : out std_logic_vector(3 downto 0);
    err_clr   : in  std_logic := '0');
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

  signal sp_zero, sp_zbusy, sp_err : std_logic;
  signal k_zero, d_zero : std_logic;
  signal kem_busy_i, dsa_busy_i : std_logic;
  signal kem_start_g, dsa_start_g : std_logic;
  signal k_zbusy, d_zbusy, k_zdone, d_zdone : std_logic;
  signal k_cerr, d_cerr, d_serr : std_logic;
  signal any_busy : std_logic;
  signal alg_q, alg_eff : std_logic := '0';
  signal err_r : std_logic_vector(3 downto 0) := (others => '0');
  signal zpend : std_logic := '0';
  signal zwait : integer range 0 to 3 := 0;
  signal zdone_r : std_logic := '0';
  signal zcmd_r  : std_logic := '0';
  signal dsa_done_i : std_logic;

begin

  -- Algorithm latch: follows alg while both cores are idle, frozen while
  -- either is busy (operation or zeroization).
  any_busy <= kem_busy_i or dsa_busy_i or k_zbusy or d_zbusy or zpend;
  alg_eff  <= alg when any_busy = '0' else alg_q;

  alg_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        alg_q <= '0';
      elsif any_busy = '0' then
        alg_q <= alg;
      end if;
    end if;
  end process;

  -- A start reaches a core only when that core's algorithm is selected and
  -- the other core is idle; each core additionally rejects starts while it
  -- is itself busy.
  kem_start_g <= kem_start when alg_eff = '0' and dsa_busy_i = '0' and
                                d_zbusy = '0' else '0';
  dsa_start_g <= dsa_start when alg_eff = '1' and kem_busy_i = '0' and
                                k_zbusy = '0' else '0';

  kem_busy <= kem_busy_i;
  dsa_busy <= dsa_busy_i;
  dsa_done <= dsa_done_i;

  u_kem : entity work.kem_core_sx
    generic map (G_ZEROIZE => G_ZEROIZE)
    port map (clk => clk, rst_n => rst_n, op => kem_op, start => kem_start_g,
              done => kem_done, busy => kem_busy_i,
              zeroize => zcmd_r, zbusy => k_zbusy, zdone => k_zdone,
              cmd_err => k_cerr, xsp_zero => k_zero, xsp_zbusy => sp_zbusy,
              h_addr => kem_haddr, h_din => kem_hdin, h_we => kem_hwe,
              h_sel => kem_hsel, h_dout => kem_hdout,
              insp_en => '0', insp_slot => 0,
              insp_addr => (others => '0'), insp_data => kem_insp_data,
              xsp_mode => k_mode, xsp_init => k_init, xsp_din => k_din,
              xsp_we => k_we, xsp_adone => k_adone, xsp_dout => sp_dout,
              xsp_re => k_re, xsp_dvalid => sp_dvalid, xsp_ready => sp_ready);

  u_dsa : entity work.dsa_core_sx
    generic map (G_ZEROIZE => G_ZEROIZE, G_SIGN_MAX_ITER => G_SIGN_MAX_ITER)
    port map (clk => clk, rst_n => rst_n, op => dsa_op, start => dsa_start_g,
              siglen => dsa_siglen, done => dsa_done_i, busy => dsa_busy_i,
              zeroize => zcmd_r, zbusy => d_zbusy, zdone => d_zdone,
              cmd_err => d_cerr, sign_err => d_serr,
              xsp_zero => d_zero, xsp_zbusy => sp_zbusy,
              result => dsa_result, reason => dsa_reason,
              h_sel => dsa_hsel, h_addr => dsa_haddr, h_din => dsa_hdin,
              h_we => dsa_hwe, h_dout => dsa_hdout,
              xsp_mode => d_mode, xsp_init => d_init, xsp_din => d_din,
              xsp_we => d_we, xsp_adone => d_adone, xsp_dout => sp_dout,
              xsp_re => d_re, xsp_dvalid => sp_dvalid, xsp_ready => sp_ready);

  -- The single sponge, selected by alg. The unselected core sees its own
  -- sponge outputs (dout, dvalid, ready) driven by the shared instance too,
  -- but it is idle and reads none of them.
  sp_mode  <= d_mode  when alg_eff = '1' else k_mode;
  sp_init  <= d_init  when alg_eff = '1' else k_init;
  sp_din   <= d_din   when alg_eff = '1' else k_din;
  sp_we    <= d_we    when alg_eff = '1' else k_we;
  sp_adone <= d_adone when alg_eff = '1' else k_adone;
  sp_re    <= d_re    when alg_eff = '1' else k_re;
  -- wipe requests are honoured from either core and from the command
  sp_zero  <= k_zero or d_zero or zcmd_r;

  u_sponge : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => sp_mode, init => sp_init,
              din => sp_din, din_we => sp_we, absorb_done => sp_adone,
              dout => sp_dout, dout_re => sp_re, dout_valid => sp_dvalid,
              ready => sp_ready, zero => sp_zero, zbusy => sp_zbusy,
              err => sp_err, err_clr => err_clr);

  -- Commanded zeroization: one pulse to both cores and the sponge, then wait
  -- until every wipe has finished.
  zbusy <= zpend;
  zdone <= zdone_r;
  err   <= err_r;

  zcmd_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        zcmd_r  <= '0';
        zpend   <= '0';
        zwait   <= 0;
        zdone_r <= '0';
        err_r   <= (others => '0');
      else
        zcmd_r  <= '0';
        zdone_r <= '0';
        if zeroize = '1' and zpend = '0' then
          zcmd_r <= '1';
          zpend  <= '1';
          zwait  <= 3;
        elsif zpend = '1' then
          if zwait /= 0 then
            zwait <= zwait - 1;
          elsif k_zbusy = '0' and d_zbusy = '0' and sp_zbusy = '0' then
            zpend   <= '0';
            zdone_r <= '1';
          end if;
        end if;

        -- sticky error bits
        if err_clr = '1' then
          err_r <= (others => '0');
        end if;
        err_r(0) <= sp_err;
        if k_cerr = '1' or d_cerr = '1' or
           (kem_start = '1' and kem_start_g = '0') or
           (dsa_start = '1' and dsa_start_g = '0') then
          err_r(1) <= '1';
        end if;
        if d_serr = '1' and dsa_done_i = '1' then
          err_r(2) <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
