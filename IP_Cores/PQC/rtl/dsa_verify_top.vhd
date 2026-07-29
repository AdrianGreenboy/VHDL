-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- dsa_verify_top: wires the Verify sequencer to the ML-DSA datapath.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Arbitration is by explicit mux rather than by tri-state or by priority
-- guesswork: the sequencer waits on each block's done before starting
-- another, so at most one of the NTT unit, the sampler and the codec is ever
-- driving the polynomial ports. The muxes below encode that invariant rather
-- than resolving a genuine race.
--
-- One subtlety in the slot addressing. The hint codec walks its six rows
-- internally and exposes the current row on p_row, while the sequencer picks
-- a slot with slot_a. The effective slot is slot_a + p_row while the codec
-- is busy, which keeps the codec unaware of the slot map and the sequencer
-- unaware of the row walk.
--
-- sp_re has exactly one driver, selected here. Two concurrent drivers on that
-- line resolve to 'X' and stall the sponge silently, which cost most of a day
-- during the ML-KEM KeyGen bring-up.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;
use work.poly_mem_d_pkg.all;

entity dsa_verify_top is
  generic (
    G_K       : integer := 6;
    G_L       : integer := 5;
    G_STOP_AT : integer := 0);
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    done      : out std_logic;
    busy      : out std_logic;
    siglen    : in  std_logic_vector(15 downto 0);
    result    : out std_logic;
    reason    : out std_logic_vector(2 downto 0);

    -- host access to the byte memory
    h_sel     : in  std_logic;
    h_addr    : in  std_logic_vector(13 downto 0);
    h_din     : in  std_logic_vector(7 downto 0);
    h_we      : in  std_logic;
    h_dout    : out std_logic_vector(7 downto 0);

    -- host access to the polynomial memory, for checkpoint inspection
    hp_sel    : in  std_logic;
    hp_slot   : in  integer range 0 to C_SLOTS_D - 1;
    hp_addr   : in  std_logic_vector(7 downto 0);
    hp_dout   : out std_logic_vector(C_CW - 1 downto 0));
end entity dsa_verify_top;

architecture rtl of dsa_verify_top is

  -- sequencer side
  signal q_slot_a, q_slot_b : integer range 0 to C_SLOTS_D - 1;
  signal q_raddr, q_braddr, q_waddr : std_logic_vector(7 downto 0);
  signal q_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal q_we    : std_logic;
  signal q_byaddr : std_logic_vector(13 downto 0);
  signal q_bydin  : std_logic_vector(7 downto 0);
  signal q_bywe   : std_logic;

  signal ntt_start, ntt_done, ntt_busy : std_logic;
  signal ntt_op : std_logic_vector(1 downto 0);
  signal smp_start, smp_done, smp_busy : std_logic;
  signal smp_mode : std_logic_vector(1 downto 0);
  signal cod_start, cod_done, cod_busy, cod_valid : std_logic;
  signal cod_mode : std_logic_vector(3 downto 0);
  signal cod_base : std_logic_vector(13 downto 0);
  signal cod_row  : integer range 0 to 5;

  -- NTT unit ports
  signal n_araddr, n_awaddr, n_braddr : std_logic_vector(7 downto 0);
  signal n_awdata : std_logic_vector(C_CW - 1 downto 0);
  signal n_awe    : std_logic;

  -- sampler ports
  signal s_waddr, s_raddr : std_logic_vector(7 downto 0);
  signal s_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal s_we    : std_logic;

  -- codec ports
  signal c_raddr, c_waddr : std_logic_vector(7 downto 0);
  signal c_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal c_we    : std_logic;
  signal c_baddr : std_logic_vector(13 downto 0);
  signal c_bwdata : std_logic_vector(7 downto 0);
  signal c_bwe   : std_logic;

  -- memory ports
  signal m_aslot, m_bslot : integer range 0 to C_SLOTS_D - 1;
  signal m_araddr, m_awaddr, m_braddr : std_logic_vector(7 downto 0);
  signal m_awdata : std_logic_vector(C_CW - 1 downto 0);
  signal m_awe    : std_logic;
  signal m_ardata, m_brdata : std_logic_vector(C_CW - 1 downto 0);

  signal b_addr : std_logic_vector(13 downto 0);
  signal b_din  : std_logic_vector(7 downto 0);
  signal b_we   : std_logic;
  signal b_dout : std_logic_vector(7 downto 0);

  -- sponge
  signal sp_mode  : std_logic_vector(1 downto 0);
  signal sp_init  : std_logic;
  signal sp_din   : std_logic_vector(7 downto 0);
  signal sp_we    : std_logic;
  signal sp_adone : std_logic;
  signal sp_dout  : std_logic_vector(7 downto 0);
  signal sp_re    : std_logic;
  signal q_spre, s_spre : std_logic;
  signal sp_dvalid, sp_ready : std_logic;

begin

  u_seq : entity work.dsa_verify
    generic map (G_K => G_K, G_L => G_L, G_STOP_AT => G_STOP_AT)
    port map (clk => clk, rst_n => rst_n, start => start, siglen => siglen,
              done => done, busy => busy, result => result, reason => reason,
              slot_a => q_slot_a, slot_b => q_slot_b,
              p_raddr => q_raddr, p_rdata => m_ardata,
              p_braddr => q_braddr, p_brdata => m_brdata,
              p_waddr => q_waddr, p_wdata => q_wdata, p_we => q_we,
              ntt_start => ntt_start, ntt_op => ntt_op, ntt_done => ntt_done,
              smp_start => smp_start, smp_mode => smp_mode,
              smp_done => smp_done,
              cod_start => cod_start, cod_mode => cod_mode,
              cod_base => cod_base, cod_done => cod_done,
              cod_valid => cod_valid,
              sp_mode => sp_mode, sp_init => sp_init, sp_din => sp_din,
              sp_we => sp_we, sp_adone => sp_adone, sp_dout => sp_dout,
              sp_re => q_spre, sp_dvalid => sp_dvalid, sp_ready => sp_ready,
              by_addr => q_byaddr, by_din => q_bydin, by_we => q_bywe,
              by_dout => b_dout);

  u_ntt : entity work.ntt_d_unit
    port map (clk => clk, rst_n => rst_n, start => ntt_start, op => ntt_op,
              done => ntt_done, busy => ntt_busy,
              a_raddr => n_araddr, a_rdata => m_ardata,
              a_waddr => n_awaddr, a_wdata => n_awdata, a_we => n_awe,
              b_raddr => n_braddr, b_rdata => m_brdata);

  u_smp : entity work.sampler_d
    port map (clk => clk, rst_n => rst_n, start => smp_start,
              mode => smp_mode, done => smp_done, busy => smp_busy,
              sp_dout => sp_dout, sp_re => s_spre, sp_dvalid => sp_dvalid,
              p_waddr => s_waddr, p_wdata => s_wdata, p_we => s_we,
              p_raddr => s_raddr, p_rdata => m_ardata);

  u_cod : entity work.codec_d
    port map (clk => clk, rst_n => rst_n, start => cod_start,
              mode => cod_mode, base => cod_base,
              done => cod_done, busy => cod_busy, valid => cod_valid,
              p_raddr => c_raddr, p_rdata => m_ardata,
              p_waddr => c_waddr, p_wdata => c_wdata, p_we => c_we,
              p_row => cod_row,
              b_addr => c_baddr, b_rdata => b_dout,
              b_wdata => c_bwdata, b_we => c_bwe);

  u_pmem : entity work.poly_mem_d
    port map (clk => clk,
              a_slot => m_aslot, a_raddr => m_araddr, a_rdata => m_ardata,
              a_waddr => m_awaddr, a_wdata => m_awdata, a_we => m_awe,
              b_slot => m_bslot, b_raddr => m_braddr, b_rdata => m_brdata);

  u_bmem : entity work.byte_mem_d
    port map (clk => clk, addr => b_addr, din => b_din, we => b_we,
              dout => b_dout);

  u_sponge : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => sp_mode, init => sp_init,
              din => sp_din, din_we => sp_we, absorb_done => sp_adone,
              dout => sp_dout, dout_re => sp_re, dout_valid => sp_dvalid,
              ready => sp_ready);

  ----------------------------------------------------------------------
  -- sp_re: one driver only. The sampler owns it while it is running, the
  -- sequencer otherwise.
  ----------------------------------------------------------------------
  sp_re <= s_spre when smp_busy = '1' else q_spre;

  ----------------------------------------------------------------------
  -- Polynomial memory arbitration. The codec's row walk is added to the
  -- slot the sequencer selected, which is the base of the six hint slots
  -- when the hint codec runs and irrelevant otherwise (cod_row stays 0).
  ----------------------------------------------------------------------
  m_aslot <= hp_slot            when hp_sel   = '1' else
             q_slot_a + cod_row when cod_busy = '1' else
             q_slot_a;
  m_bslot <= q_slot_b;

  m_araddr <= hp_addr  when hp_sel   = '1' else
              n_araddr when ntt_busy = '1' else
              s_raddr  when smp_busy = '1' else
              c_raddr  when cod_busy = '1' else
              q_raddr;
  m_braddr <= n_braddr when ntt_busy = '1' else q_braddr;

  m_awaddr <= n_awaddr when ntt_busy = '1' else
              s_waddr  when smp_busy = '1' else
              c_waddr  when cod_busy = '1' else
              q_waddr;
  m_awdata <= n_awdata when ntt_busy = '1' else
              s_wdata  when smp_busy = '1' else
              c_wdata  when cod_busy = '1' else
              q_wdata;
  m_awe    <= '0'      when hp_sel   = '1' else
              n_awe    when ntt_busy = '1' else
              s_we     when smp_busy = '1' else
              c_we     when cod_busy = '1' else
              q_we;

  hp_dout <= m_ardata;

  ----------------------------------------------------------------------
  -- Byte memory arbitration.
  ----------------------------------------------------------------------
  b_addr <= h_addr when h_sel = '1' else
            c_baddr when cod_busy = '1' else
            q_byaddr;
  b_din  <= h_din    when h_sel = '1' else
            c_bwdata when cod_busy = '1' else
            q_bydin;
  b_we   <= h_we    when h_sel = '1' else
            c_bwe   when cod_busy = '1' else
            q_bywe;

  h_dout <= b_dout;

end architecture rtl;
