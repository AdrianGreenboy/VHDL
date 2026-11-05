-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4
-- dsa_core_sx: dsa_core with the Keccak sponge lifted to ports, so a
-- wrapper can share ONE sponge instance between the KEM and DSA cores.
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
--
-- AUDIT 2026-11 changes:
--  * op is LATCHED when a start is accepted and held until done; a start is
--    accepted only while the core is idle and op /= "11" (otherwise cmd_err
--    pulses).
--  * Host byte port: no effect while the core is busy; host READS return
--    0x00 outside the staging/output windows of the last operation.
--  * Zeroization (G_ZEROIZE): after KeyGen and Sign the core wipes the byte
--    regions holding secrets/intermediates that are not outputs, the whole
--    polynomial memory and the sponge state before pulsing done. Verify
--    handles public data only and is not followed by a wipe (its cycle count
--    is unchanged). A zeroize pulse wipes everything, aborting a running
--    operation. If Sign hits its iteration bound, sign_err is raised with
--    done and the partial signature region is wiped as well.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;
use work.poly_mem_d_pkg.all;

entity dsa_core_sx is
  generic (
    G_K : integer := 6;
    G_L : integer := 5;
    G_ZEROIZE : boolean := true;
    G_SIGN_MAX_ITER : integer := 814);
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
    h_dout    : out std_logic_vector(7 downto 0);
    -- zeroization and command status
    zeroize   : in  std_logic := '0';    -- pulse: wipe everything
    zbusy     : out std_logic;           -- a wipe (auto or command) runs
    zdone     : out std_logic;           -- pulse: commanded wipe complete
    cmd_err   : out std_logic;           -- pulse: start rejected
    sign_err  : out std_logic;           -- Sign aborted at its bound (level)
    -- Keccak sponge, lifted out so one instance is shared at the wrapper
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
end entity dsa_core_sx;

architecture rtl of dsa_core_sx is

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

  -- operation latch and start qualification
  signal op_r      : std_logic_vector(1 downto 0) := "00";
  signal start_ok  : std_logic;
  signal seq_done  : std_logic;
  signal seq_busy  : std_logic;
  signal core_busy : std_logic;
  signal srst_n    : std_logic;
  signal abort_r   : std_logic := '0';
  signal sg_err    : std_logic;
  signal zero_op   : boolean;

  -- host gating
  signal host_act  : std_logic;
  signal hrd_ok_q  : std_logic := '0';

  -- zeroization controller
  type t_zst is (Z_IDLE, Z_ISSUE, Z_W1, Z_WAIT, Z_TAIL);
  signal zst       : t_zst := Z_IDLE;
  signal zmode     : integer range 0 to 4 := 0;
  signal zk        : integer range 0 to 3 := 0;
  signal zauto     : std_logic := '0';
  signal zdone_r   : std_logic := '0';
  signal adone_r   : std_logic := '0';
  signal bz_start  : std_logic := '0';
  signal bz_lo, bz_hi : integer range 0 to 2047 := 0;
  signal bz_busy   : std_logic;
  signal pz_start  : std_logic := '0';
  signal pz_busy   : std_logic;
  signal spz_r     : std_logic := '0';
  -- a zeroize command that arrives while an automatic wipe is running is
  -- held here and served as soon as that wipe ends
  signal zreq      : std_logic := '0';

  -- Byte regions (8-byte words, inclusive):
  --  0 KeyGen : xi, seed (rho, rho', K)          [0,256)
  --  1 Sign   : sk input [0,4096), rho'' c~ w1 and the tail of a previous
  --             KeyGen sk [4160,6336); mu (public) and sig are kept
  --  2 Verify : not used (no wipe)
  --  3 all    : the whole 16 KB
  --  4 Sign aborted at its bound: as 1, plus the partial sig [8192,11520)
  type t_zr is array (0 to 4, 0 to 2) of integer;
  constant C_ZLO : t_zr := ((0, 0, 0), (0, 520, 520), (0, 0, 0),
                            (0, 0, 0), (0, 520, 1024));
  constant C_ZHI : t_zr := ((31, 31, 31), (511, 791, 791), (0, 0, 0),
                            (2047, 2047, 2047), (511, 791, 1439));
  type t_zn is array (0 to 4) of integer;
  constant C_ZN  : t_zn := (1, 2, 1, 1, 3);

  -- Host read windows per last operation (byte addresses, [lo, hi)).
  function host_rd_ok (o : std_logic_vector(1 downto 0);
                       a : std_logic_vector(13 downto 0)) return boolean is
    variable x : integer;
  begin
    x := to_integer(unsigned(a));
    -- host scratch area, always readable
    if x >= 11520 then
      return true;
    end if;
    case o is
      when "00" =>                          -- KeyGen: xi, pk, sk
        return x < 32 or (x >= 256 and x < 2208) or
               (x >= 2304 and x < 6336);
      when "01" =>                          -- Sign: sk, mu, sig
        return x < 4032 or (x >= 4096 and x < 4160) or
               (x >= 8192 and x < 11501);
      when others =>                        -- Verify: pk, mu, sig
        return x < 1952 or (x >= 2048 and x < 2112) or
               (x >= 2176 and x < 5485);
    end case;
  end function host_rd_ok;

begin

  srst_n <= rst_n and not abort_r;

  -- A start is accepted only when the whole core is idle and op is legal.
  start_ok <= '1' when start = '1' and core_busy = '0' and op /= "11"
              else '0';
  cmd_err  <= '1' when start = '1' and start_ok = '0' else '0';
  sel      <= to_integer(unsigned(op)) when start_ok = '1'
              else to_integer(unsigned(op_r));

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

  -- Only the selected sequencer sees start; the others stay idle and drive
  -- nothing that reaches the shared datapath.
  st_kg <= start_ok when op = "00" else '0';
  st_sg <= start_ok when op = "01" else '0';
  st_vf <= start_ok when op = "10" else '0';

  u_kg : entity work.dsa_keygen
    generic map (G_K => G_K, G_L => G_L)
    port map (clk => clk, rst_n => srst_n, start => st_kg,
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
    generic map (G_K => G_K, G_L => G_L, G_MAX_ITER => G_SIGN_MAX_ITER)
    port map (clk => clk, rst_n => srst_n, start => st_sg,
              done => q_done(1), busy => q_busy(1), kappa_out => open,
              err => sg_err,
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
    port map (clk => clk, rst_n => srst_n, start => st_vf, siglen => siglen,
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

  -- done from the latched op, busy from all sequencers (no loop via sel)
  seq_done <= q_done(0) when op_r = "00" else
              q_done(1) when op_r = "01" else q_done(2);
  seq_busy <= q_busy(0) or q_busy(1) or q_busy(2);
  sign_err <= sg_err;

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
    port map (clk => clk, rst_n => srst_n, start => ntt_start_s,
              op => ntt_op_s, done => ntt_done_s, busy => ntt_busy,
              a_raddr => n_araddr, a_rdata => m_ardata,
              a_waddr => n_awaddr, a_wdata => n_awdata, a_we => n_awe,
              b_raddr => n_braddr, b_rdata => m_brdata);

  u_smp : entity work.sampler_d
    port map (clk => clk, rst_n => srst_n, start => smp_start_s,
              mode => smp_mode_s, done => smp_done_s, busy => smp_busy,
              sp_dout => sp_dout, sp_re => s_spre, sp_dvalid => sp_dvalid,
              p_waddr => s_waddr, p_wdata => s_wdata, p_we => s_we,
              p_raddr => s_raddr, p_rdata => m_ardata);

  u_cod : entity work.codec_d
    port map (clk => clk, rst_n => srst_n, start => cod_start_s,
              mode => cod_mode_s, base => cod_base_s,
              done => cod_done_s, busy => cod_busy, valid => cod_valid_s,
              p_raddr => c_raddr, p_rdata => m_ardata,
              p_waddr => c_waddr, p_wdata => c_wdata, p_we => c_we,
              p_row => cod_row,
              b_addr => c_baddr, b_rdata => b_dout,
              b_wdata => c_bwdata, b_we => c_bwe);

  u_pmem : entity work.poly_mem_d
    port map (clk => clk, rst_n => rst_n,
              z_start => pz_start, z_busy => pz_busy,
              a_slot => m_aslot, a_raddr => m_araddr, a_rdata => m_ardata,
              a_waddr => m_awaddr, a_wdata => m_awdata, a_we => m_awe,
              b_slot => m_bslot, b_raddr => m_braddr, b_rdata => m_brdata);

  u_bmem : entity work.byte_mem_d
    port map (clk => clk, rst_n => rst_n, addr => b_addr, din => b_din,
              we => b_we, dout => b_dout,
              z_start => bz_start, z_lo => bz_lo, z_hi => bz_hi,
              z_busy => bz_busy);

  -- sponge signals routed to the boundary; the wrapper owns the instance
  xsp_mode  <= sp_mode;
  xsp_init  <= sp_init;
  xsp_din   <= sp_din;
  xsp_we    <= sp_we_s;
  xsp_adone <= sp_adone;
  sp_dout   <= xsp_dout;
  xsp_re    <= sp_re;
  sp_dvalid <= xsp_dvalid;
  sp_ready  <= xsp_ready;

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

  -- The host owns the byte memory only while the core is idle.
  host_act <= h_sel and not core_busy;

  b_addr <= h_addr when host_act = '1' else
            c_baddr when cod_busy = '1' else
            q_byaddr(sel);
  b_din  <= h_din    when host_act = '1' else
            c_bwdata when cod_busy = '1' else
            q_bydin(sel);
  b_we   <= h_we  when host_act = '1' else
            c_bwe when cod_busy = '1' else
            q_bywe(sel);

  -- Host read data is masked to zero outside the windows of the last
  -- operation; the check is registered alongside the memory read.
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
  h_dout <= b_dout when hrd_ok_q = '1' else (others => '0');

  ----------------------------------------------------------------------
  -- Zeroization controller (same structure as kem_core_sx).
  ----------------------------------------------------------------------
  zero_op   <= G_ZEROIZE and op_r /= "10";
  core_busy <= '1' when seq_busy = '1' or zst /= Z_IDLE or abort_r = '1' or
                        (zero_op and seq_done = '1')
               else '0';
  busy      <= core_busy;
  done      <= adone_r when zero_op else seq_done;
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
              abort_r  <= seq_busy;
              zmode    <= 3;
              zk       <= 0;
              zauto    <= '0';
              pz_start <= '1';
              spz_r    <= '1';
              zst      <= Z_ISSUE;
            elsif zero_op and seq_done = '1' then
              if op_r = "01" and sg_err = '1' then
                zmode <= 4;
              else
                zmode <= to_integer(unsigned(op_r));
              end if;
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
