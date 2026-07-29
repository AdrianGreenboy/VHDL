-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- kem_keygen_top: wires the KeyGen sequencer to every verified block.
-- VHDL-2008. ASCII-only. MIT license.
--
-- This is the first point in the project where the whole ML-KEM datapath runs
-- as one machine: sponge, samplers, NTT, basemul, codec and both memories,
-- each of which was verified standalone before being connected here.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;

entity kem_keygen_top is
  generic (
    G_K       : integer := 3;
    G_STOP_AT : integer := 0);
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    start   : in  std_logic;
    done    : out std_logic;
    busy    : out std_logic;
    -- host access to byte memory (seed staging and key readback)
    h_addr  : in  std_logic_vector(12 downto 0);
    h_din   : in  std_logic_vector(7 downto 0);
    h_we    : in  std_logic;
    h_sel   : in  std_logic;               -- '1' host owns byte memory
    h_dout  : out std_logic_vector(7 downto 0);
    -- polynomial inspection port, for checkpoint comparison only
    insp_en   : in  std_logic;
    insp_slot : in  integer range 0 to C_SLOTS - 1;
    insp_addr : in  std_logic_vector(7 downto 0);
    insp_data : out std_logic_vector(15 downto 0));
end entity kem_keygen_top;

architecture rtl of kem_keygen_top is

  -- polynomial memory
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

  u_bytes : entity work.byte_mem
    generic map (G_SIZE => 8192)
    port map (clk => clk, rst_n => rst_n,
              a_addr => bmem_a, a_din => bmem_din, a_we => bmem_we,
              a_dout => bmem_do,
              b_addr => bmem_rd, b_dout => bmem_rdo);

  u_fsm : entity work.kem_keygen
    generic map (G_K => G_K, G_STOP_AT => G_STOP_AT)
    port map (clk => clk, rst_n => rst_n, start => start,
              done => done, busy => busy,
              grant => grant, slot_rd => slot_rd, slot_rd2 => slot_rd2,
              slot_wr => slot_wr,
              fsm_raddr => seq_raddr, fsm_rdata => fsm_rdata,
              fsm_waddr => seq_waddr, fsm_wdata => seq_wdata,
              fsm_we => seq_we,
              sp_mode => sp_mode, sp_init => sp_init, sp_din => sp_din,
              sp_we => sp_we, sp_adone => sp_adone, sp_dout => sp_dout,
              sp_re => seq_re, sp_dvalid => sp_dvalid,
              sp_ready => sp_ready,
              s1_start => s1_start, s1_done => s1_done,
              s2_start => s2_start, s2_done => s2_done,
              samp_sel => samp_sel, samp_run => samp_run,
              ntt_start => ntt_start, ntt_inv => ntt_inv, ntt_done => ntt_done,
              bm_start => bm_start, bm_accum => bm_accum, bm_done => bm_done,
              cd_start => cd_start, cd_decode => cd_decode, cd_base => cd_base,
              cd_done => cd_done,
              by_addr => by_addr, by_din => by_din, by_we => by_we,
              by_dout => by_dout);

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
  fsm_raddr <= cd_praddr when cd_busy = '1' else seq_raddr;
  fsm_waddr <= cd_pwaddr when cd_busy = '1' else seq_waddr;
  fsm_wdata <= cd_pwdata when cd_busy = '1' else seq_wdata;
  fsm_we    <= cd_pwe    when cd_busy = '1' else seq_we;

  -- Byte memory arbitration: host during staging and readback, codec while
  -- it streams, FSM otherwise.
  bmem_a   <= h_addr   when h_sel = '1' else
              cd_baddr when cd_busy = '1' else
              by_addr;
  bmem_din <= h_din    when h_sel = '1' else
              cd_bwdata when cd_busy = '1' else
              by_din;
  bmem_we  <= h_we     when h_sel = '1' else
              cd_bwe   when cd_busy = '1' else
              by_we;

  bmem_rd <= h_addr   when h_sel = '1' else
             cd_baddr when cd_busy = '1' else
             by_addr;

  by_dout <= bmem_rdo;
  h_dout  <= bmem_rdo;

end architecture rtl;
