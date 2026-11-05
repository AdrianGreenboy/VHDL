-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4
-- kem_core_sx: kem_core with the Keccak sponge lifted to ports.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Derived from the Decaps top, which already carries the superset of datapath
-- signals: both codecs and the rejected flag. The three sequencers are muxed
-- onto that datapath by an operation register. Only one runs at a time, so
-- this is a mux, not an arbiter: the unselected sequencers see start low and
-- stay idle. This is the same structure as dsa_core, one algorithm over.
--
-- op encoding:  "00" KeyGen   "01" Encaps   "10" Decaps   ("11" rejected)
--
-- AUDIT 2026-11 changes:
--  * op is LATCHED when a start is accepted and held until done; a start is
--    accepted only while the core is idle and op /= "11" (otherwise cmd_err
--    pulses and nothing runs). The sequencer mux can no longer be moved, or
--    driven out of range, by the host mid-operation.
--  * The FO implicit-rejection flag of Decaps is NOT exported: it would be a
--    plaintext-checking oracle. kem_decaps keeps it only behind G_DEBUG_REJ
--    for verification wrappers.
--  * Host byte port is gated: it has no effect while the core is busy
--    (operation or zeroization), and host READS return 0x00 outside the
--    staging/output windows of the last operation (see host_rd_ok).
--  * Zeroization (G_ZEROIZE): at the end of every operation the core wipes
--    the byte regions that hold secrets or intermediates but are not
--    outputs, the whole polynomial memory and the sponge state, and only
--    then pulses done. A zeroize pulse wipes everything (aborting a running
--    operation); zdone pulses when that wipe completes.
-- =============================================================================
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;

entity kem_core_sx is
  generic (
    G_K       : integer := 3;
    G_STOP_AT : integer := 0;
    G_ZEROIZE : boolean := true);
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
    -- zeroization and command status
    zeroize : in  std_logic := '0';      -- pulse: wipe everything
    zbusy   : out std_logic;             -- a wipe (auto or command) runs
    zdone   : out std_logic;             -- pulse: commanded wipe complete
    cmd_err : out std_logic;             -- pulse: start rejected
    -- polynomial inspection port, for checkpoint comparison only
    insp_en   : in  std_logic;
    insp_slot : in  integer range 0 to C_SLOTS - 1;
    insp_addr : in  std_logic_vector(7 downto 0);
    insp_data : out std_logic_vector(15 downto 0);
    xsp_mode  : out std_logic_vector(1 downto 0);
    xsp_init  : out std_logic;
    xsp_din   : out std_logic_vector(7 downto 0);
    xsp_we    : out std_logic;
    xsp_adone : out std_logic;
    xsp_dout  : in  std_logic_vector(7 downto 0);
    xsp_re    : out std_logic;
    xsp_dvalid : in  std_logic;
    xsp_ready : in  std_logic;
    xsp_zero  : out std_logic;
    xsp_zbusy : in  std_logic := '0');
end entity kem_core_sx;

architecture rtl of kem_core_sx is

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
  signal bm_dre    : std_logic;   -- basemul destination read strobe
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

  -- operation latch and start qualification
  signal op_r      : std_logic_vector(1 downto 0) := "00";
  signal start_ok  : std_logic;
  signal seq_done  : std_logic;
  signal seq_busy  : std_logic;
  signal core_busy : std_logic;
  signal srst_n    : std_logic;            -- datapath reset (abort on zeroize)
  signal abort_r   : std_logic := '0';

  -- host gating
  signal host_act  : std_logic;
  signal hrd_ok_q  : std_logic := '0';

  -- zeroization controller
  type t_zst is (Z_IDLE, Z_ISSUE, Z_W1, Z_WAIT, Z_TAIL);
  signal zst       : t_zst := Z_IDLE;
  signal zmode     : integer range 0 to 3 := 0;   -- 0..2 = op, 3 = everything
  signal zk        : integer range 0 to 3 := 0;
  signal zauto     : std_logic := '0';
  signal zdone_r   : std_logic := '0';
  signal adone_r   : std_logic := '0';
  signal bz_start  : std_logic := '0';
  signal bz_lo, bz_hi : integer range 0 to 1023 := 0;
  signal bz_busy   : std_logic;
  signal pz_start  : std_logic := '0';
  signal pz_busy   : std_logic;
  signal spz_r     : std_logic := '0';
  -- a zeroize command that arrives while an automatic wipe is running is
  -- held here and served as soon as that wipe ends
  signal zreq      : std_logic := '0';

  -- Byte regions (8-byte words, inclusive) wiped after each operation.
  --  KeyGen : d, z, rho, sigma            [0,128)
  --  Encaps : m, (K is the output at 32), r, H(ek) [0,32) [64,128), and the
  --           tail of a previous dk beyond ct     [3136,4448)
  --  Decaps : m2, K2, r2, Kbar  [1152,1280), dk input [2048,4448),
  --           re-encrypted c2   [4608,5696)
  --  all    : the whole 8 KB
  type t_zr is array (0 to 3, 0 to 2) of integer;
  constant C_ZLO : t_zr := ((0, 0, 0),    (0, 8, 392),    (144, 256, 576),
                            (0, 0, 0));
  constant C_ZHI : t_zr := ((15, 15, 15), (3, 15, 555),   (159, 555, 711),
                            (1023, 1023, 1023));
  type t_zn is array (0 to 3) of integer;
  constant C_ZN  : t_zn := (1, 3, 3, 1);

  -- Host read windows per last operation (byte addresses, [lo, hi)).
  function host_rd_ok (o : std_logic_vector(1 downto 0);
                       a : std_logic_vector(12 downto 0)) return boolean is
    variable x : integer;
  begin
    x := to_integer(unsigned(a));
    -- host scratch / park area, always readable
    if x >= 5760 then
      return true;
    end if;
    case o is
      when "00" =>                          -- KeyGen: d||z, ek, dk
        return x < 64 or (x >= 512 and x < 1696) or
               (x >= 2048 and x < 4448);
      when "01" =>                          -- Encaps: m, K, ek, ct
        return x < 64 or (x >= 512 and x < 1696) or
               (x >= 2048 and x < 3136);
      when others =>                        -- Decaps: c, Kout, dk
        return x < 1088 or (x >= 1280 and x < 1312) or
               (x >= 2048 and x < 4448);
    end case;
  end function host_rd_ok;

begin

  srst_n <= rst_n and not abort_r;

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
              bm_daddr => bm_daddr, bm_dre => bm_dre, bm_drdata => bm_drdata,
              bm_dwdata => bm_dwdata, bm_dwe => bm_dwe,
              sm_waddr => sm_waddr, sm_wdata => sm_wdata, sm_we => sm_we,
              fsm_raddr => mem_raddr, fsm_rdata => fsm_rdata,
              fsm_waddr => fsm_waddr, fsm_wdata => fsm_wdata, fsm_we => fsm_we,
              z_start => pz_start, z_busy => pz_busy);

  xsp_mode  <= sp_mode;
  xsp_init  <= sp_init;
  xsp_din   <= sp_din;
  xsp_we    <= sp_we;
  xsp_adone <= sp_adone;
  sp_dout   <= xsp_dout;
  xsp_re    <= sp_re;
  sp_dvalid <= xsp_dvalid;
  sp_ready  <= xsp_ready;

  u_s1 : entity work.sampler_ntt_k
    port map (clk => clk, rst_n => srst_n, start => s1_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s1_re,
              co_addr => s1_addr, co_data => s1_data, co_we => s1_we,
              busy => open, done => s1_done);

  u_s2 : entity work.sampler_cbd_k
    port map (clk => clk, rst_n => srst_n, start => s2_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s2_re,
              co_addr => s2_addr, co_data => s2_data, co_we => s2_we,
              busy => open, done => s2_done);

  u_ntt : entity work.ntt_unit
    generic map (G_Q => C_QK, G_QINV => C_QINVK, G_RBITS => 16,
                 G_WIDTH => 16, G_LAYERS => 7, G_SCALE => C_SK)
    port map (clk => clk, rst_n => srst_n, start => ntt_start,
              inverse => ntt_inv,
              rd_addr => ntt_raddr, rd_data => ntt_rdata,
              wr_addr => ntt_waddr, wr_data => ntt_wdata, wr_en => ntt_we,
              busy => open, done => ntt_done);

  u_bm : entity work.basemul_k
    port map (clk => clk, rst_n => srst_n, start => bm_start, accum => bm_accum,
              a_addr => bm_aaddr, a_data => bm_adata,
              b_addr => bm_baddr, b_data => bm_bdata,
              d_addr => bm_daddr, d_re => bm_dre, d_rdata => bm_drdata,
              d_wdata => bm_dwdata, d_we => bm_dwe,
              busy => open, done => bm_done);

  u_codec : entity work.codec_12
    port map (clk => clk, rst_n => srst_n, start => cd_start,
              decode => cd_decode, base => cd_base,
              p_raddr => cd_praddr, p_rdata => fsm_rdata,
              p_waddr => cd_pwaddr, p_wdata => cd_pwdata, p_we => cd_pwe,
              b_addr => cd_baddr, b_rdata => bmem_do,
              b_wdata => cd_bwdata, b_we => cd_bwe,
              busy => cd_busy, done => cd_done);

  u_codec_ct : entity work.codec_ct
    port map (clk => clk, rst_n => srst_n, start => cct_start,
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
              b_addr => bmem_rd, b_dout => bmem_rdo,
              z_start => bz_start, z_lo => bz_lo, z_hi => bz_hi,
              z_busy => bz_busy);

  -- A start is accepted only when the whole core is idle and op is legal.
  -- In the accepting cycle the mux follows op directly (exactly the old
  -- timing); afterwards it follows the latched op_r until the next start.
  start_ok <= '1' when start = '1' and core_busy = '0' and op /= "11"
              else '0';
  cmd_err  <= '1' when start = '1' and start_ok = '0' else '0';
  sel      <= to_integer(unsigned(op)) when start_ok = '1'
              else to_integer(unsigned(op_r));
  st_kg    <= start_ok when op = "00" else '0';
  st_en    <= start_ok when op = "01" else '0';
  st_de    <= start_ok when op = "10" else '0';

  op_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        op_r <= "00";
      elsif start_ok = '1' then
        op_r <= op;
      end if;
    end if;
  end process;

  u_kg : entity work.kem_keygen
    generic map (G_K => G_K)
    port map (clk => clk, rst_n => srst_n, start => st_kg,
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
    port map (clk => clk, rst_n => srst_n, start => st_en,
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
    port map (clk => clk, rst_n => srst_n, start => st_de,
              done => de_done, busy => de_busy, rejected => open,
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
  -- done/busy are taken from the latched op (done) and from all three
  -- sequencers (busy), not from sel: sel depends on start_ok, which depends
  -- on busy, and that would close a combinational loop.
  seq_done  <= kg_done when op_r = "00" else
               en_done when op_r = "01" else de_done;
  seq_busy  <= kg_busy or en_busy or de_busy;
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
  -- The host owns the byte memory only while the core is idle.
  host_act <= h_sel and not core_busy;

  bmem_a   <= h_addr    when host_act = '1' else
              cd_baddr  when cd_busy  = '1' else
              cct_baddr when cct_busy = '1' else
              by_addr;
  bmem_din <= h_din     when host_act = '1' else
              cd_bwdata when cd_busy  = '1' else
              cct_bwdata when cct_busy = '1' else
              by_din;
  bmem_we  <= h_we      when host_act = '1' else
              cd_bwe    when cd_busy  = '1' else
              cct_bwe   when cct_busy = '1' else
              by_we;

  bmem_rd <= h_addr    when host_act = '1' else
             cd_baddr  when cd_busy  = '1' else
             cct_baddr when cct_busy = '1' else
             by_addr;

  by_dout <= bmem_rdo;

  -- Host read data is masked to zero unless the address presented in the
  -- previous cycle was a host access inside a window of the last operation.
  -- The window check is registered alongside the memory read, so the read
  -- latency seen by the host is unchanged.
  hrd_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        hrd_ok_q <= '0';
      elsif host_act = '1' and host_rd_ok(op_r, h_addr) then
        hrd_ok_q <= '1';
      else
        hrd_ok_q <= '0';
      end if;
    end if;
  end process;
  h_dout <= bmem_rdo when hrd_ok_q = '1' else (others => '0');

  ----------------------------------------------------------------------
  -- Zeroization controller.
  ----------------------------------------------------------------------
  core_busy <= '1' when seq_busy = '1' or zst /= Z_IDLE or abort_r = '1' or
                        (G_ZEROIZE and seq_done = '1')
               else '0';
  busy      <= core_busy;
  done      <= adone_r when G_ZEROIZE else seq_done;
  zbusy     <= '1' when zst /= Z_IDLE or abort_r = '1' or zreq = '1'
               else '0';
  zdone     <= zdone_r;
  xsp_zero  <= spz_r;

  zctl : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        zst      <= Z_IDLE;
        zmode    <= 0;
        zk       <= 0;
        zauto    <= '0';
        zdone_r  <= '0';
        adone_r  <= '0';
        bz_start <= '0';
        pz_start <= '0';
        spz_r    <= '0';
        abort_r  <= '0';
        bz_lo    <= 0;
        bz_hi    <= 0;
        zreq     <= '0';
      else
        zdone_r  <= '0';
        adone_r  <= '0';
        bz_start <= '0';
        pz_start <= '0';
        spz_r    <= '0';
        abort_r  <= '0';
        if zeroize = '1' and zst /= Z_IDLE then
          zreq <= '1';
        end if;
        case zst is
          when Z_IDLE =>
            if zeroize = '1' or zreq = '1' then
              zreq     <= '0';
              -- commanded wipe of everything; abort a running operation
              abort_r  <= seq_busy;
              zmode    <= 3;
              zk       <= 0;
              zauto    <= '0';
              pz_start <= '1';
              spz_r    <= '1';
              zst      <= Z_ISSUE;
            elsif G_ZEROIZE and seq_done = '1' then
              zmode    <= to_integer(unsigned(op_r));
              zk       <= 0;
              zauto    <= '1';
              pz_start <= '1';
              spz_r    <= '1';
              zst      <= Z_ISSUE;
            end if;

          when Z_ISSUE =>
            bz_lo    <= C_ZLO(zmode, zk);
            bz_hi    <= C_ZHI(zmode, zk);
            bz_start <= '1';
            zst      <= Z_W1;

          when Z_W1 =>
            -- bz_busy rises in this cycle
            zst <= Z_WAIT;

          when Z_WAIT =>
            if bz_busy = '0' then
              if zk = C_ZN(zmode) - 1 then
                zst <= Z_TAIL;
              else
                zk  <= zk + 1;
                zst <= Z_ISSUE;
              end if;
            end if;

          when Z_TAIL =>
            if pz_busy = '0' and xsp_zbusy = '0' then
              if zauto = '1' then
                adone_r <= '1';
              else
                zdone_r <= '1';
              end if;
              -- One-cycle soft reset of the sequencers and datapath blocks:
              -- clears the registers that have a reset clause (accumulators,
              -- masks, counters) so less secret residue stays in flops.
              abort_r <= '1';
              zst     <= Z_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
