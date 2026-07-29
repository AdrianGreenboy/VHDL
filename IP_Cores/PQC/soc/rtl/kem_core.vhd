-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4
-- kem_core: KeyGen, Encaps and Decaps over one shared ML-KEM datapath.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Derived from the Decaps top, which already carries the superset of datapath
-- signals: both codecs and the rejected flag. The three sequencers are muxed
-- onto that datapath by an operation register. Only one runs at a time, so
-- this is a mux, not an arbiter: the unselected sequencers see start low and
-- stay idle. This is the same structure as dsa_core, one algorithm over.
--
-- op encoding:  "00" KeyGen   "01" Encaps   "10" Decaps
-- =============================================================================
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;

entity kem_core is
  generic (
    G_K       : integer := 3;
    G_STOP_AT : integer := 0);
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    op      : in  std_logic_vector(1 downto 0);
    start   : in  std_logic;
    done    : out std_logic;
    busy    : out std_logic;
    -- host access to byte memory (seed staging and key readback)
    h_addr  : in  std_logic_vector(12 downto 0);
    h_din   : in  std_logic_vector(7 downto 0);
    h_we    : in  std_logic;
    h_sel   : in  std_logic;               -- '1' host owns byte memory
    h_dout  : out std_logic_vector(7 downto 0);
    rejected : out std_logic;
    -- polynomial inspection port, for checkpoint comparison only
    insp_en   : in  std_logic;
    insp_slot : in  integer range 0 to C_SLOTS - 1;
    insp_addr : in  std_logic_vector(7 downto 0);
    insp_data : out std_logic_vector(15 downto 0));
end entity kem_core;

architecture rtl of kem_core is

  -- polynomial memory
  signal st_kg, st_en, st_de : std_logic;
  signal sel : integer range 0 to 2;
  signal kg_done, en_done, de_done : std_logic;
  signal kg_busy, en_busy, de_busy : std_logic;

  -- per-sequencer datapath outputs, muxed by sel
  type t_slot is array (0 to 2) of integer range 0 to C_SLOTS - 1;
  type t_grant is array (0 to 2) of integer range 0 to 4;
  type t_a8 is array (0 to 2) of std_logic_vector(7 downto 0);
  type t_a16 is array (0 to 2) of std_logic_vector(15 downto 0);
  type t_a13 is array (0 to 2) of std_logic_vector(12 downto 0);
  type t_a2 is array (0 to 2) of std_logic_vector(1 downto 0);
  type t_a1v is array (0 to 2) of std_logic;
  type t_a1 is array (0 to 2) of std_logic;
  signal g_grant : t_grant;
  signal g_srd, g_srd2, g_swr : t_slot;
  signal g_raddr, g_waddr : t_a8;
  signal g_wdata : t_a16;
  signal g_we : t_a1;
  signal g_spmode : t_a2;
  signal g_spinit, g_spwe, g_spadone, g_spre : t_a1;
  signal g_spdin : t_a8;
  signal g_s1start, g_s2start, g_samprun, g_nttstart, g_nttinv : t_a1;
  signal g_sampsel : t_a1v;
  signal g_bmstart, g_bmaccum : t_a1;
  signal g_cdstart, g_cddecode : t_a1;
  signal g_cdbase : t_a13;
  signal g_cctstart, g_cctdecode : t_a1;
  signal g_cctdsel : t_a2;
  signal g_cctbase : t_a13;
  signal g_byaddr : t_a13;
  signal g_bydin : t_a8;
  signal g_bywe : t_a1;

  signal grant    : integer range 0 to 4;
  signal slot_rd  : integer range 0 to C_SLOTS - 1;
  signal slot_rd2 : integer range 0 to C_SLOTS - 1;
  signal slot_wr  : integer range 0 to C_SLOTS - 1;

  signal ntt_raddr : std_logic_vector(7 downto 0);
  signal ntt_rdata : std_logic_vector(15 downto 0);
  signal ntt_waddr : std_logic_vector(7 downto 0);
  signal ntt_wdata : std_logic_vector(15 downto 0);
  signal ntt_we    : std_logic;

  signal bm_aaddr  : std_logic_vector(7 downto 0);
  signal bm_adata  : std_logic_vector(15 downto 0);
  signal bm_baddr  : std_logic_vector(7 downto 0);
  signal bm_bdata  : std_logic_vector(15 downto 0);
  signal bm_daddr  : std_logic_vector(7 downto 0);
  signal bm_drdata : std_logic_vector(15 downto 0);
  signal bm_dwdata : std_logic_vector(15 downto 0);
  signal bm_dwe    : std_logic;

  signal sm_waddr : std_logic_vector(7 downto 0);
  signal sm_wdata : std_logic_vector(15 downto 0);
  signal sm_we    : std_logic;

  signal mem_grant   : integer range 0 to 4;
  signal mem_slot_rd : integer range 0 to C_SLOTS - 1;
  signal mem_raddr   : std_logic_vector(7 downto 0);
  signal fsm_raddr : std_logic_vector(7 downto 0);   -- muxed into poly_mem
  signal seq_raddr : std_logic_vector(7 downto 0);   -- from the sequencer
  signal fsm_rdata : std_logic_vector(15 downto 0);
  signal fsm_waddr : std_logic_vector(7 downto 0);
  signal seq_waddr : std_logic_vector(7 downto 0);
  signal fsm_wdata : std_logic_vector(15 downto 0);
  signal seq_wdata : std_logic_vector(15 downto 0);
  signal fsm_we    : std_logic;
  signal seq_we    : std_logic;

  -- codec shares the FSM read port and the sampler write port
  signal cd_praddr : std_logic_vector(7 downto 0);
  signal cd_pwaddr : std_logic_vector(7 downto 0);
  signal cd_pwdata : std_logic_vector(15 downto 0);
  signal cd_pwe    : std_logic;
  signal cd_baddr  : std_logic_vector(12 downto 0);
  signal cd_bwdata : std_logic_vector(7 downto 0);
  signal cd_bwe    : std_logic;
  signal cd_start  : std_logic;
  signal cd_decode : std_logic;
  signal cd_base   : std_logic_vector(12 downto 0);
  signal cd_done   : std_logic;
  signal cd_busy   : std_logic;

  -- codec_ct, the ciphertext compression codec
  signal cct_praddr : std_logic_vector(7 downto 0);
  signal cct_pwaddr : std_logic_vector(7 downto 0);
  signal cct_pwdata : std_logic_vector(15 downto 0);
  signal cct_pwe    : std_logic;
  signal cct_baddr  : std_logic_vector(12 downto 0);
  signal cct_bwdata : std_logic_vector(7 downto 0);
  signal cct_bwe    : std_logic;
  signal cct_start  : std_logic;
  signal cct_decode : std_logic;
  signal cct_dsel   : std_logic_vector(1 downto 0);
  signal cct_base   : std_logic_vector(12 downto 0);
  signal cct_done   : std_logic;
  signal cct_busy   : std_logic;

  -- sponge
  signal sp_mode   : std_logic_vector(1 downto 0);
  signal sp_init   : std_logic;
  signal sp_din    : std_logic_vector(7 downto 0);
  signal sp_we     : std_logic;
  signal sp_adone  : std_logic;
  signal sp_dout   : std_logic_vector(7 downto 0);
  signal sp_re     : std_logic;   -- muxed
  signal seq_re    : std_logic;   -- from the sequencer
  signal sp_dvalid : std_logic;
  signal sp_ready  : std_logic;

  -- samplers
  signal s1_start, s1_done, s2_start, s2_done : std_logic;
  signal s1_re, s2_re : std_logic;
  signal s1_addr, s2_addr : std_logic_vector(7 downto 0);
  signal s1_data, s2_data : std_logic_vector(15 downto 0);
  signal s1_we, s2_we     : std_logic;
  signal samp_sel : std_logic;
  signal samp_run : std_logic;

  -- compute blocks
  signal ntt_start, ntt_inv, ntt_done : std_logic;
  signal bm_start, bm_accum, bm_done  : std_logic;

  -- byte memory
  signal by_addr  : std_logic_vector(12 downto 0);
  signal by_din   : std_logic_vector(7 downto 0);
  signal by_we    : std_logic;
  signal by_dout  : std_logic_vector(7 downto 0);
  signal bmem_a   : std_logic_vector(12 downto 0);
  signal bmem_din : std_logic_vector(7 downto 0);
  signal bmem_we  : std_logic;
  signal bmem_do  : std_logic_vector(7 downto 0);
  -- Dedicated read port. The sequencer frequently reads one address while
  -- writing another in the same cycle (squeeze into byte memory, byte copies),
  -- which a single shared address bus cannot express.
  signal bmem_rd  : std_logic_vector(12 downto 0);
  signal bmem_rdo : std_logic_vector(7 downto 0);

begin

  -- While insp_en is high the inspection port owns the read path. The
  -- sequencer is halted at that point, so there is no contention.
  mem_grant   <= C_CLI_FSM when insp_en = '1' else grant;
  mem_slot_rd <= insp_slot when insp_en = '1' else slot_rd;
  mem_raddr   <= insp_addr when insp_en = '1' else fsm_raddr;
  insp_data   <= fsm_rdata;

  u_mem : entity work.poly_mem
    port map (clk => clk, rst_n => rst_n, grant => mem_grant,
              slot_rd => mem_slot_rd, slot_rd2 => slot_rd2, slot_wr => slot_wr,
              ntt_raddr => ntt_raddr, ntt_rdata => ntt_rdata,
              ntt_waddr => ntt_waddr, ntt_wdata => ntt_wdata, ntt_we => ntt_we,
              bm_aaddr => bm_aaddr, bm_adata => bm_adata,
              bm_baddr => bm_baddr, bm_bdata => bm_bdata,
              bm_daddr => bm_daddr, bm_drdata => bm_drdata,
              bm_dwdata => bm_dwdata, bm_dwe => bm_dwe,
              sm_waddr => sm_waddr, sm_wdata => sm_wdata, sm_we => sm_we,
              fsm_raddr => mem_raddr, fsm_rdata => fsm_rdata,
              fsm_waddr => fsm_waddr, fsm_wdata => fsm_wdata, fsm_we => fsm_we);

  u_sponge : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => sp_mode, init => sp_init,
              din => sp_din, din_we => sp_we, absorb_done => sp_adone,
              dout => sp_dout, dout_re => sp_re, dout_valid => sp_dvalid,
              ready => sp_ready);

  u_s1 : entity work.sampler_ntt_k
    port map (clk => clk, rst_n => rst_n, start => s1_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s1_re,
              co_addr => s1_addr, co_data => s1_data, co_we => s1_we,
              busy => open, done => s1_done);

  u_s2 : entity work.sampler_cbd_k
    port map (clk => clk, rst_n => rst_n, start => s2_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s2_re,
              co_addr => s2_addr, co_data => s2_data, co_we => s2_we,
              busy => open, done => s2_done);

  u_ntt : entity work.ntt_unit
    generic map (G_Q => C_QK, G_QINV => C_QINVK, G_RBITS => 16,
                 G_WIDTH => 16, G_LAYERS => 7, G_SCALE => C_SK)
    port map (clk => clk, rst_n => rst_n, start => ntt_start,
              inverse => ntt_inv,
              rd_addr => ntt_raddr, rd_data => ntt_rdata,
              wr_addr => ntt_waddr, wr_data => ntt_wdata, wr_en => ntt_we,
              busy => open, done => ntt_done);

  u_bm : entity work.basemul_k
    port map (clk => clk, rst_n => rst_n, start => bm_start, accum => bm_accum,
              a_addr => bm_aaddr, a_data => bm_adata,
              b_addr => bm_baddr, b_data => bm_bdata,
              d_addr => bm_daddr, d_rdata => bm_drdata,
              d_wdata => bm_dwdata, d_we => bm_dwe,
              busy => open, done => bm_done);

  u_codec : entity work.codec_12
    port map (clk => clk, rst_n => rst_n, start => cd_start,
              decode => cd_decode, base => cd_base,
              p_raddr => cd_praddr, p_rdata => fsm_rdata,
              p_waddr => cd_pwaddr, p_wdata => cd_pwdata, p_we => cd_pwe,
              b_addr => cd_baddr, b_rdata => bmem_do,
              b_wdata => cd_bwdata, b_we => cd_bwe,
              busy => cd_busy, done => cd_done);

  u_codec_ct : entity work.codec_ct
    port map (clk => clk, rst_n => rst_n, start => cct_start,
              decode => cct_decode, dsel => cct_dsel, base => cct_base,
              p_raddr => cct_praddr, p_rdata => fsm_rdata,
              p_waddr => cct_pwaddr, p_wdata => cct_pwdata, p_we => cct_pwe,
              b_addr => cct_baddr, b_rdata => bmem_rdo,
              b_wdata => cct_bwdata, b_we => cct_bwe,
              busy => cct_busy, done => cct_done);

  u_bytes : entity work.byte_mem
    generic map (G_SIZE => 8192)
    port map (clk => clk, rst_n => rst_n,
              a_addr => bmem_a, a_din => bmem_din, a_we => bmem_we,
              a_dout => bmem_do,
              b_addr => bmem_rd, b_dout => bmem_rdo);

  sel   <= to_integer(unsigned(op));
  st_kg <= start when op = "00" else '0';
  st_en <= start when op = "01" else '0';
  st_de <= start when op = "10" else '0';

  u_kg : entity work.kem_keygen
    generic map (G_K => G_K)
    port map (clk => clk, rst_n => rst_n, start => st_kg,
              done => kg_done, busy => kg_busy,
              grant => g_grant(0), slot_rd => g_srd(0), slot_rd2 => g_srd2(0),
              slot_wr => g_swr(0),
              fsm_raddr => g_raddr(0), fsm_rdata => fsm_rdata,
              fsm_waddr => g_waddr(0), fsm_wdata => g_wdata(0),
              fsm_we => g_we(0),
              sp_mode => g_spmode(0), sp_init => g_spinit(0),
              sp_din => g_spdin(0), sp_we => g_spwe(0),
              sp_adone => g_spadone(0), sp_dout => sp_dout,
              sp_re => g_spre(0), sp_dvalid => sp_dvalid, sp_ready => sp_ready,
              s1_start => g_s1start(0), s1_done => s1_done,
              s2_start => g_s2start(0), s2_done => s2_done,
              samp_sel => g_sampsel(0), samp_run => g_samprun(0),
              ntt_start => g_nttstart(0), ntt_inv => g_nttinv(0),
              ntt_done => ntt_done,
              bm_start => g_bmstart(0), bm_accum => g_bmaccum(0),
              bm_done => bm_done,
              cd_start => g_cdstart(0), cd_decode => g_cddecode(0),
              cd_base => g_cdbase(0), cd_done => cd_done,
              by_addr => g_byaddr(0), by_din => g_bydin(0),
              by_we => g_bywe(0), by_dout => by_dout);

  u_en : entity work.kem_encaps
    generic map (G_K => G_K)
    port map (clk => clk, rst_n => rst_n, start => st_en,
              done => en_done, busy => en_busy,
              grant => g_grant(1), slot_rd => g_srd(1), slot_rd2 => g_srd2(1),
              slot_wr => g_swr(1),
              fsm_raddr => g_raddr(1), fsm_rdata => fsm_rdata,
              fsm_waddr => g_waddr(1), fsm_wdata => g_wdata(1),
              fsm_we => g_we(1),
              sp_mode => g_spmode(1), sp_init => g_spinit(1),
              sp_din => g_spdin(1), sp_we => g_spwe(1),
              sp_adone => g_spadone(1), sp_dout => sp_dout,
              sp_re => g_spre(1), sp_dvalid => sp_dvalid, sp_ready => sp_ready,
              s1_start => g_s1start(1), s1_done => s1_done,
              s2_start => g_s2start(1), s2_done => s2_done,
              samp_sel => g_sampsel(1), samp_run => g_samprun(1),
              ntt_start => g_nttstart(1), ntt_inv => g_nttinv(1),
              ntt_done => ntt_done,
              bm_start => g_bmstart(1), bm_accum => g_bmaccum(1),
              bm_done => bm_done,
              c12_start => g_cdstart(1), c12_decode => g_cddecode(1),
              c12_base => g_cdbase(1), c12_done => cd_done,
              cct_start => g_cctstart(1), cct_decode => g_cctdecode(1),
              cct_dsel => g_cctdsel(1), cct_base => g_cctbase(1),
              cct_done => cct_done,
              by_addr => g_byaddr(1), by_din => g_bydin(1),
              by_we => g_bywe(1), by_dout => by_dout);

  u_de : entity work.kem_decaps
    generic map (G_K => G_K)
    port map (clk => clk, rst_n => rst_n, start => st_de,
              done => de_done, busy => de_busy, rejected => rejected,
              grant => g_grant(2), slot_rd => g_srd(2), slot_rd2 => g_srd2(2),
              slot_wr => g_swr(2),
              fsm_raddr => g_raddr(2), fsm_rdata => fsm_rdata,
              fsm_waddr => g_waddr(2), fsm_wdata => g_wdata(2),
              fsm_we => g_we(2),
              sp_mode => g_spmode(2), sp_init => g_spinit(2),
              sp_din => g_spdin(2), sp_we => g_spwe(2),
              sp_adone => g_spadone(2), sp_dout => sp_dout,
              sp_re => g_spre(2), sp_dvalid => sp_dvalid, sp_ready => sp_ready,
              s1_start => g_s1start(2), s1_done => s1_done,
              s2_start => g_s2start(2), s2_done => s2_done,
              samp_sel => g_sampsel(2), samp_run => g_samprun(2),
              ntt_start => g_nttstart(2), ntt_inv => g_nttinv(2),
              ntt_done => ntt_done,
              bm_start => g_bmstart(2), bm_accum => g_bmaccum(2),
              bm_done => bm_done,
              c12_start => g_cdstart(2), c12_decode => g_cddecode(2),
              c12_base => g_cdbase(2), c12_done => cd_done,
              cct_start => g_cctstart(2), cct_decode => g_cctdecode(2),
              cct_dsel => g_cctdsel(2), cct_base => g_cctbase(2),
              cct_done => cct_done,
              by_addr => g_byaddr(2), by_din => g_bydin(2),
              by_we => g_bywe(2), by_dout => by_dout);

  -- mux the selected sequencer onto the shared datapath
  done      <= kg_done when sel = 0 else en_done when sel = 1 else de_done;
  busy      <= kg_busy when sel = 0 else en_busy when sel = 1 else de_busy;
  grant     <= g_grant(sel);
  slot_rd   <= g_srd(sel);
  slot_rd2  <= g_srd2(sel);
  slot_wr   <= g_swr(sel);
  seq_raddr <= g_raddr(sel);
  seq_waddr <= g_waddr(sel);
  seq_wdata <= g_wdata(sel);
  seq_we    <= g_we(sel);
  sp_mode   <= g_spmode(sel);
  sp_init   <= g_spinit(sel);
  sp_din    <= g_spdin(sel);
  sp_we     <= g_spwe(sel);
  sp_adone  <= g_spadone(sel);
  seq_re    <= g_spre(sel);
  s1_start  <= g_s1start(sel);
  s2_start  <= g_s2start(sel);
  samp_sel  <= g_sampsel(sel);
  samp_run  <= g_samprun(sel);
  ntt_start <= g_nttstart(sel);
  ntt_inv   <= g_nttinv(sel);
  bm_start  <= g_bmstart(sel);
  bm_accum  <= g_bmaccum(sel);
  cd_start  <= g_cdstart(sel);
  cd_decode <= g_cddecode(sel);
  cd_base   <= g_cdbase(sel);
  cct_start <= g_cctstart(sel) when sel /= 0 else '0';
  cct_decode <= g_cctdecode(sel) when sel /= 0 else '0';
  cct_dsel  <= g_cctdsel(sel) when sel /= 0 else "00";
  cct_base  <= g_cctbase(sel) when sel /= 0 else (others => '0');
  by_addr   <= g_byaddr(sel);
  by_din    <= g_bydin(sel);
  by_we     <= g_bywe(sel);

  -- Squeeze port ownership. The sequencer pulls bytes itself while absorbing
  -- and while storing hash output; a sampler pulls them while it runs. Three
  -- drivers on one signal would resolve to 'X' and stall the sponge silently,
  -- so the mux is explicit and the sequencer holds samp_run low outside a
  -- sampler run.
  sp_re <= s1_re when (samp_run = '1' and samp_sel = '0') else
           s2_re when (samp_run = '1' and samp_sel = '1') else
           seq_re;

  sm_waddr <= s1_addr when samp_sel = '0' else s2_addr;
  sm_wdata <= s1_data when samp_sel = '0' else s2_data;
  sm_we    <= s1_we   when samp_sel = '0' else s2_we;

  -- Polynomial port muxing. The codec owns the read port while it streams an
  -- encode, and the write port while it streams a decode. Outside that window
  -- the sequencer owns both. The two are never active together because the
  -- sequencer waits on cd_done before touching the port again.
  -- Only one codec runs at a time: the sequencer waits on the matching done
  -- before starting the other, so the priority order here never arbitrates a
  -- genuine simultaneous access.
  fsm_raddr <= cd_praddr  when cd_busy  = '1' else
               cct_praddr when cct_busy = '1' else seq_raddr;
  fsm_waddr <= cd_pwaddr  when cd_busy  = '1' else
               cct_pwaddr when cct_busy = '1' else seq_waddr;
  fsm_wdata <= cd_pwdata  when cd_busy  = '1' else
               cct_pwdata when cct_busy = '1' else seq_wdata;
  fsm_we    <= cd_pwe     when cd_busy  = '1' else
               cct_pwe    when cct_busy = '1' else seq_we;

  -- Byte memory arbitration: host during staging and readback, codec while
  -- it streams, FSM otherwise.
  bmem_a   <= h_addr    when h_sel   = '1' else
              cd_baddr  when cd_busy  = '1' else
              cct_baddr when cct_busy = '1' else
              by_addr;
  bmem_din <= h_din     when h_sel   = '1' else
              cd_bwdata when cd_busy  = '1' else
              cct_bwdata when cct_busy = '1' else
              by_din;
  bmem_we  <= h_we      when h_sel   = '1' else
              cd_bwe    when cd_busy  = '1' else
              cct_bwe   when cct_busy = '1' else
              by_we;

  bmem_rd <= h_addr    when h_sel   = '1' else
             cd_baddr  when cd_busy  = '1' else
             cct_baddr when cct_busy = '1' else
             by_addr;

  by_dout <= bmem_rdo;
  h_dout  <= bmem_rdo;

end architecture rtl;
