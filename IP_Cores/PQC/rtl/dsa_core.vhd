-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4
-- dsa_core: the three ML-DSA-65 operations over one shared datapath.
-- VHDL-2008. ASCII-only. MIT license.
--
-- KeyGen, Sign and Verify each had their own top level during Layer 3B, and
-- each instantiated its own sponge, NTT unit, sampler, codec and memories.
-- That was right for bring-up and wrong for silicon: three copies of
-- Keccak-f1600 is the single most expensive mistake available in this design.
--
-- Here the datapath exists once and the three sequencers are muxed onto it by
-- an operation register. Only one operation runs at a time, so this is a mux
-- rather than an arbiter: there is no concurrency to resolve, and encoding
-- that invariant directly is both cheaper and easier to argue about than a
-- bus would be. The unselected sequencers are held with start low and
-- therefore sit in their idle state driving nothing that reaches the memory.
--
-- op encoding:
--   "00"  KeyGen
--   "01"  Sign
--   "10"  Verify
--
-- The three sequencers keep their own byte maps, which do not overlap in the
-- shared 16 KB space:
--   KeyGen  xi@0    seed@64   pk@256   sk@2304
--   Sign    sk@0    mu@4096   ...      sig@8192
--   Verify  pk@0    mu@2048   sig@2176
-- A chained self-test therefore has to move bytes between operations rather
-- than assume they land where the next one reads, and the driver above does
-- exactly that.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;
use work.poly_mem_d_pkg.all;

entity dsa_core is
  generic (
    G_K : integer := 6;
    G_L : integer := 5);
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    op        : in  std_logic_vector(1 downto 0);
    start     : in  std_logic;
    siglen    : in  std_logic_vector(15 downto 0);
    done      : out std_logic;
    busy      : out std_logic;
    -- Verify only
    result    : out std_logic;
    reason    : out std_logic_vector(2 downto 0);

    -- host access to the byte memory
    h_sel     : in  std_logic;
    h_addr    : in  std_logic_vector(13 downto 0);
    h_din     : in  std_logic_vector(7 downto 0);
    h_we      : in  std_logic;
    h_dout    : out std_logic_vector(7 downto 0));
end entity dsa_core;

architecture rtl of dsa_core is

  -- one set of datapath signals, three sets of sequencer outputs
  type t_slot is array (0 to 2) of integer range 0 to C_SLOTS_D - 1;
  type t_a8   is array (0 to 2) of std_logic_vector(7 downto 0);
  type t_a14  is array (0 to 2) of std_logic_vector(13 downto 0);
  type t_cw   is array (0 to 2) of std_logic_vector(C_CW - 1 downto 0);
  type t_a2   is array (0 to 2) of std_logic_vector(1 downto 0);
  type t_a4   is array (0 to 2) of std_logic_vector(3 downto 0);
  type t_a1   is array (0 to 2) of std_logic;

  signal q_slot_a, q_slot_b : t_slot;
  signal q_raddr, q_braddr, q_waddr : t_a8;
  signal q_wdata : t_cw;
  signal q_we    : t_a1;
  signal q_nstart, q_ndone : t_a1;
  signal q_nop   : t_a2;
  signal q_sstart : t_a1;
  signal q_smode : t_a2;
  signal q_cstart : t_a1;
  signal q_cmode : t_a4;
  signal q_cbase : t_a14;
  signal q_spmode : t_a2;
  signal q_spinit, q_spwe, q_spadone, q_spre : t_a1;
  signal q_spdin : t_a8;
  signal q_byaddr : t_a14;
  signal q_bydin  : t_a8;
  signal q_bywe   : t_a1;
  signal q_done, q_busy : t_a1;

  signal sel : integer range 0 to 2 := 0;

  -- shared datapath
  signal m_aslot, m_bslot : integer range 0 to C_SLOTS_D - 1;
  signal m_araddr, m_awaddr, m_braddr : std_logic_vector(7 downto 0);
  signal m_awdata : std_logic_vector(C_CW - 1 downto 0);
  signal m_awe    : std_logic;
  signal m_ardata, m_brdata : std_logic_vector(C_CW - 1 downto 0);

  signal n_araddr, n_awaddr, n_braddr : std_logic_vector(7 downto 0);
  signal n_awdata : std_logic_vector(C_CW - 1 downto 0);
  signal n_awe, ntt_busy, ntt_done_s : std_logic;
  signal ntt_start_s : std_logic;
  signal ntt_op_s : std_logic_vector(1 downto 0);

  signal s_waddr, s_raddr : std_logic_vector(7 downto 0);
  signal s_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal s_we, smp_busy, smp_done_s, smp_start_s : std_logic;
  signal smp_mode_s : std_logic_vector(1 downto 0);
  signal s_spre : std_logic;

  signal c_raddr, c_waddr : std_logic_vector(7 downto 0);
  signal c_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal c_we, cod_busy, cod_done_s, cod_valid_s, cod_start_s : std_logic;
  signal c_baddr : std_logic_vector(13 downto 0);
  signal c_bwdata : std_logic_vector(7 downto 0);
  signal c_bwe : std_logic;
  signal cod_mode_s : std_logic_vector(3 downto 0);
  signal cod_base_s : std_logic_vector(13 downto 0);
  signal cod_row : integer range 0 to 5;

  signal b_addr : std_logic_vector(13 downto 0);
  signal b_din, b_dout : std_logic_vector(7 downto 0);
  signal b_we : std_logic;

  signal sp_mode : std_logic_vector(1 downto 0);
  signal sp_init, sp_we_s, sp_adone, sp_re, sp_dvalid, sp_ready : std_logic;
  signal sp_din, sp_dout : std_logic_vector(7 downto 0);
  signal q_spre_sel : std_logic;

  signal st_kg, st_sg, st_vf : std_logic;

begin

  sel <= to_integer(unsigned(op));

  -- Only the selected sequencer sees start; the others stay idle and drive
  -- nothing that reaches the shared datapath.
  st_kg <= start when op = "00" else '0';
  st_sg <= start when op = "01" else '0';
  st_vf <= start when op = "10" else '0';

  u_kg : entity work.dsa_keygen
    generic map (G_K => G_K, G_L => G_L)
    port map (clk => clk, rst_n => rst_n, start => st_kg,
              done => q_done(0), busy => q_busy(0),
              slot_a => q_slot_a(0), slot_b => q_slot_b(0),
              p_raddr => q_raddr(0), p_rdata => m_ardata,
              p_braddr => q_braddr(0), p_brdata => m_brdata,
              p_waddr => q_waddr(0), p_wdata => q_wdata(0), p_we => q_we(0),
              ntt_start => q_nstart(0), ntt_op => q_nop(0),
              ntt_done => ntt_done_s,
              smp_start => q_sstart(0), smp_mode => q_smode(0),
              smp_done => smp_done_s,
              cod_start => q_cstart(0), cod_mode => q_cmode(0),
              cod_base => q_cbase(0), cod_done => cod_done_s,
              cod_valid => cod_valid_s,
              sp_mode => q_spmode(0), sp_init => q_spinit(0),
              sp_din => q_spdin(0), sp_we => q_spwe(0),
              sp_adone => q_spadone(0), sp_dout => sp_dout,
              sp_re => q_spre(0), sp_dvalid => sp_dvalid,
              sp_ready => sp_ready,
              by_addr => q_byaddr(0), by_din => q_bydin(0),
              by_we => q_bywe(0), by_dout => b_dout);

  u_sg : entity work.dsa_sign
    generic map (G_K => G_K, G_L => G_L)
    port map (clk => clk, rst_n => rst_n, start => st_sg,
              done => q_done(1), busy => q_busy(1), kappa_out => open,
              slot_a => q_slot_a(1), slot_b => q_slot_b(1),
              p_raddr => q_raddr(1), p_rdata => m_ardata,
              p_braddr => q_braddr(1), p_brdata => m_brdata,
              p_waddr => q_waddr(1), p_wdata => q_wdata(1), p_we => q_we(1),
              ntt_start => q_nstart(1), ntt_op => q_nop(1),
              ntt_done => ntt_done_s,
              smp_start => q_sstart(1), smp_mode => q_smode(1),
              smp_done => smp_done_s,
              cod_start => q_cstart(1), cod_mode => q_cmode(1),
              cod_base => q_cbase(1), cod_done => cod_done_s,
              sp_mode => q_spmode(1), sp_init => q_spinit(1),
              sp_din => q_spdin(1), sp_we => q_spwe(1),
              sp_adone => q_spadone(1), sp_dout => sp_dout,
              sp_re => q_spre(1), sp_dvalid => sp_dvalid,
              sp_ready => sp_ready,
              by_addr => q_byaddr(1), by_din => q_bydin(1),
              by_we => q_bywe(1), by_dout => b_dout);

  u_vf : entity work.dsa_verify
    generic map (G_K => G_K, G_L => G_L)
    port map (clk => clk, rst_n => rst_n, start => st_vf, siglen => siglen,
              done => q_done(2), busy => q_busy(2),
              result => result, reason => reason,
              slot_a => q_slot_a(2), slot_b => q_slot_b(2),
              p_raddr => q_raddr(2), p_rdata => m_ardata,
              p_braddr => q_braddr(2), p_brdata => m_brdata,
              p_waddr => q_waddr(2), p_wdata => q_wdata(2), p_we => q_we(2),
              ntt_start => q_nstart(2), ntt_op => q_nop(2),
              ntt_done => ntt_done_s,
              smp_start => q_sstart(2), smp_mode => q_smode(2),
              smp_done => smp_done_s,
              cod_start => q_cstart(2), cod_mode => q_cmode(2),
              cod_base => q_cbase(2), cod_done => cod_done_s,
              cod_valid => cod_valid_s,
              sp_mode => q_spmode(2), sp_init => q_spinit(2),
              sp_din => q_spdin(2), sp_we => q_spwe(2),
              sp_adone => q_spadone(2), sp_dout => sp_dout,
              sp_re => q_spre(2), sp_dvalid => sp_dvalid,
              sp_ready => sp_ready,
              by_addr => q_byaddr(2), by_din => q_bydin(2),
              by_we => q_bywe(2), by_dout => b_dout);

  done <= q_done(sel);
  busy <= q_busy(sel);

  ----------------------------------------------------------------------
  -- Shared datapath, one instance each.
  ----------------------------------------------------------------------
  ntt_start_s <= q_nstart(sel);
  ntt_op_s    <= q_nop(sel);
  smp_start_s <= q_sstart(sel);
  smp_mode_s  <= q_smode(sel);
  cod_start_s <= q_cstart(sel);
  cod_mode_s  <= q_cmode(sel);
  cod_base_s  <= q_cbase(sel);
  sp_mode     <= q_spmode(sel);
  sp_init     <= q_spinit(sel);
  sp_din      <= q_spdin(sel);
  sp_we_s     <= q_spwe(sel);
  sp_adone    <= q_spadone(sel);
  q_spre_sel  <= q_spre(sel);

  u_ntt : entity work.ntt_d_unit
    port map (clk => clk, rst_n => rst_n, start => ntt_start_s,
              op => ntt_op_s, done => ntt_done_s, busy => ntt_busy,
              a_raddr => n_araddr, a_rdata => m_ardata,
              a_waddr => n_awaddr, a_wdata => n_awdata, a_we => n_awe,
              b_raddr => n_braddr, b_rdata => m_brdata);

  u_smp : entity work.sampler_d
    port map (clk => clk, rst_n => rst_n, start => smp_start_s,
              mode => smp_mode_s, done => smp_done_s, busy => smp_busy,
              sp_dout => sp_dout, sp_re => s_spre, sp_dvalid => sp_dvalid,
              p_waddr => s_waddr, p_wdata => s_wdata, p_we => s_we,
              p_raddr => s_raddr, p_rdata => m_ardata);

  u_cod : entity work.codec_d
    port map (clk => clk, rst_n => rst_n, start => cod_start_s,
              mode => cod_mode_s, base => cod_base_s,
              done => cod_done_s, busy => cod_busy, valid => cod_valid_s,
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
              din => sp_din, din_we => sp_we_s, absorb_done => sp_adone,
              dout => sp_dout, dout_re => sp_re, dout_valid => sp_dvalid,
              ready => sp_ready);

  sp_re <= s_spre when smp_busy = '1' else q_spre_sel;

  m_aslot <= q_slot_a(sel) + cod_row when cod_busy = '1' else q_slot_a(sel);
  m_bslot <= q_slot_b(sel);

  m_araddr <= n_araddr when ntt_busy = '1' else
              s_raddr  when smp_busy = '1' else
              c_raddr  when cod_busy = '1' else
              q_raddr(sel);
  m_braddr <= n_braddr when ntt_busy = '1' else q_braddr(sel);

  m_awaddr <= n_awaddr when ntt_busy = '1' else
              s_waddr  when smp_busy = '1' else
              c_waddr  when cod_busy = '1' else
              q_waddr(sel);
  m_awdata <= n_awdata when ntt_busy = '1' else
              s_wdata  when smp_busy = '1' else
              c_wdata  when cod_busy = '1' else
              q_wdata(sel);
  m_awe    <= n_awe    when ntt_busy = '1' else
              s_we     when smp_busy = '1' else
              c_we     when cod_busy = '1' else
              q_we(sel);

  b_addr <= h_addr when h_sel = '1' else
            c_baddr when cod_busy = '1' else
            q_byaddr(sel);
  b_din  <= h_din    when h_sel = '1' else
            c_bwdata when cod_busy = '1' else
            q_bydin(sel);
  b_we   <= h_we  when h_sel = '1' else
            c_bwe when cod_busy = '1' else
            q_bywe(sel);

  h_dout <= b_dout;

end architecture rtl;
