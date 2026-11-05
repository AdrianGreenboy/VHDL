-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Data plane de estadisticas (Layer 2), dominio de reloj de 390.625 MHz.
--
--   * contadores live: tx_blk, rx_blk, rx_err, ber, lock_time
--   * block lock and hi_ber per IEEE 802.3 clause 49 (audit 2026-11, fixes
--     A3/M2): the state machines are pcs_blocksync (Fig. 49-13/14/15):
--       - EXT_SYNC = false: an internal pcs_blocksync (no slip, SLIP_WAIT=0)
--         driven by the RX header events (abstract Layer 2A model)
--       - EXT_SYNC = true : lock / hi_ber come from the REAL block sync of
--         the RX datapath (ext_lock / ext_hiber), as used by pcs_stats_top
--     Previously: any single bad header dropped lock and 16 bad headers in
--     total (never windowed) latched hi_ber for ever.
--   * eventos de transicion (lock gained/lost, hi_ber, rx_err, prbs_err)
--
-- Event inputs: 'blk_evt' (one code per cycle, kept for the Layer 2A
-- testbench) OR the independent strobes tx_stb / hdr_ok_stb / hdr_bad_stb /
-- prbs_stb. pcs_stats_top uses the strobes, so simultaneous TX, RX header
-- and PRBS events are no longer lost to a priority multiplexer.
--
-- CNT_CLEAR / PRBS_RESET win over an increment in the same cycle (fix M1):
-- before, an event in the clear cycle survived the clear.
--
-- Los comandos (cnt_clear, soft_reset, resync, prbs_reset) llegan ya
-- sincronizados a este dominio (la CDC vive en el modulo superior).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_dataplane is
  generic (
    LOCK_THRESHOLD  : natural := 64;     -- sync-headers validos para lock
    HIBER_THRESHOLD : natural := 16;     -- invalid headers per window -> hi_ber
    HIBER_WINDOW    : natural := 48828;  -- BER window in clk_dp cycles (125 us)
    EXT_SYNC        : boolean := false   -- lock/hi_ber from ext_* ports
  );
  port (
    clk_dp    : in  std_logic;         -- 390.625 MHz
    rst_dp    : in  std_logic;         -- reset sincrono del data plane

    -- evento de bloque procesado este ciclo:
    --   "000" idle, "001" tx, "010" rx_ok, "011" rx_bad, "100" prbs_bad
    blk_evt   : in  std_logic_vector(2 downto 0);
    -- independent event strobes (OR-ed with blk_evt)
    tx_stb      : in  std_logic := '0';
    hdr_ok_stb  : in  std_logic := '0';
    hdr_bad_stb : in  std_logic := '0';
    prbs_stb    : in  std_logic := '0';
    -- real block sync state (EXT_SYNC = true)
    ext_lock    : in  std_logic := '0';
    ext_hiber   : in  std_logic := '0';

    -- comandos (ya sincronizados a clk_dp)
    cmd_cnt_clear  : in std_logic;
    cmd_soft_reset : in std_logic;
    cmd_resync     : in std_logic;
    cmd_prbs_reset : in std_logic;

    -- contadores live (hacia la logica de snapshot)
    cnt_tx_blk : out std_logic_vector(31 downto 0);
    cnt_rx_blk : out std_logic_vector(31 downto 0);
    cnt_rx_err : out std_logic_vector(31 downto 0);
    cnt_ber    : out std_logic_vector(31 downto 0);
    lock_time  : out std_logic_vector(31 downto 0);

    -- estado
    st_block_lock : out std_logic;
    st_scr_sync   : out std_logic;
    st_prbs_lock  : out std_logic;
    st_hi_ber     : out std_logic;
    st_tx_active  : out std_logic;
    st_rx_active  : out std_logic;

    -- pulsos de evento (1 ciclo dp) hacia el sincronizador de stickies
    ev_lock_gained : out std_logic;
    ev_lock_lost   : out std_logic;
    ev_hi_ber      : out std_logic;
    ev_rx_err      : out std_logic;
    ev_prbs_err    : out std_logic
  );
end entity pcs_dataplane;

architecture rtl of pcs_dataplane is
  constant EVT_IDLE : std_logic_vector(2 downto 0) := "000";
  constant EVT_TX   : std_logic_vector(2 downto 0) := "001";
  constant EVT_RXOK : std_logic_vector(2 downto 0) := "010";
  constant EVT_RXBAD: std_logic_vector(2 downto 0) := "011";
  constant EVT_PRBSB: std_logic_vector(2 downto 0) := "100";

  -- 32-bit counters saturate at all-ones instead of wrapping (fix B3)
  function sat_inc(c : unsigned(31 downto 0)) return unsigned is
  begin
    if c = x"FFFFFFFF" then return c; else return c + 1; end if;
  end function;

  signal r_tx    : unsigned(31 downto 0) := (others => '0');
  signal r_rx    : unsigned(31 downto 0) := (others => '0');
  signal r_rxerr : unsigned(31 downto 0) := (others => '0');
  signal r_ber   : unsigned(31 downto 0) := (others => '0');
  signal r_lockt : unsigned(31 downto 0) := (others => '0');
  signal r_cycle : unsigned(31 downto 0) := (others => '0');

  signal r_prbs    : std_logic := '0';
  signal r_txact   : std_logic := '0';
  signal r_rxact   : std_logic := '0';
  signal r_prevlock: std_logic := '0';
  signal r_prevhb  : std_logic := '0';

  signal p_lock_gained : std_logic := '0';
  signal p_lock_lost   : std_logic := '0';
  signal p_hi_ber      : std_logic := '0';
  signal p_rx_err      : std_logic := '0';
  signal p_prbs_err    : std_logic := '0';

  signal e_tx, e_ok, e_bad, e_prbs : std_logic;
  signal bs_rst   : std_logic;
  signal lock_s, hiber_s : std_logic;
  signal i_lock, i_hiber, i_gain, i_lost, i_hb : std_logic;

begin

  e_tx   <= '1' when blk_evt = EVT_TX    or tx_stb      = '1' else '0';
  e_ok   <= '1' when blk_evt = EVT_RXOK  or hdr_ok_stb  = '1' else '0';
  e_bad  <= '1' when blk_evt = EVT_RXBAD or hdr_bad_stb = '1' else '0';
  e_prbs <= '1' when blk_evt = EVT_PRBSB or prbs_stb    = '1' else '0';

  -- clause-49 lock + BER monitor (abstract model: no gearbox -> no slip wait)
  bs_rst <= rst_dp or cmd_soft_reset;
  g_int: if not EXT_SYNC generate
    u_bs: entity work.pcs_blocksync
      generic map (SLIP_WAIT => 0, LOCK_CNT => LOCK_THRESHOLD, WIN => 64,
                   INV_LIM => 16, HIBER_WINDOW => HIBER_WINDOW,
                   HIBER_THR => HIBER_THRESHOLD)
      port map (clk=>clk_dp, rst=>bs_rst, resync=>cmd_resync,
                in_valid=>e_ok or e_bad, in_header=>(e_ok & '0'),
                slip=>open, lock=>i_lock, hi_ber=>i_hiber,
                ev_goodsh=>open, ev_badsh=>open, ev_slip=>open,
                ev_gained=>i_gain, ev_lost=>i_lost, ev_hiber=>i_hb);
    lock_s  <= i_lock;
    hiber_s <= i_hiber;
  end generate;
  g_ext: if EXT_SYNC generate
    lock_s  <= ext_lock;
    hiber_s <= ext_hiber;
  end generate;

  process(clk_dp)
    variable v_tx, v_rx, v_re, v_ber : unsigned(31 downto 0);
  begin
    if rising_edge(clk_dp) then
      -- pulsos de evento por defecto a 0
      p_lock_gained <= '0';
      p_lock_lost   <= '0';
      p_hi_ber      <= '0';
      p_rx_err      <= '0';
      p_prbs_err    <= '0';

      if rst_dp = '1' then
        r_tx <= (others=>'0'); r_rx <= (others=>'0'); r_rxerr <= (others=>'0');
        r_ber <= (others=>'0'); r_lockt <= (others=>'0'); r_cycle <= (others=>'0');
        r_prbs <= '0'; r_txact <= '0'; r_rxact <= '0';
        r_prevlock <= '0'; r_prevhb <= '0';
      else
        r_cycle <= r_cycle + 1;

        -- counters: increment first, then the clear commands win
        v_tx := r_tx; v_rx := r_rx; v_re := r_rxerr; v_ber := r_ber;
        if cmd_soft_reset = '0' then
          if e_tx = '1' then v_tx := sat_inc(v_tx); r_txact <= '1'; end if;
          if e_ok = '1' or e_bad = '1' then v_rx := sat_inc(v_rx); r_rxact <= '1'; end if;
          if e_bad = '1' then v_re := sat_inc(v_re); p_rx_err <= '1'; end if;
          if e_prbs = '1' then v_ber := sat_inc(v_ber); p_prbs_err <= '1'; end if;
        end if;
        if cmd_cnt_clear = '1' then
          v_tx := (others=>'0'); v_rx := (others=>'0');
          v_re := (others=>'0'); v_ber := (others=>'0');
        end if;
        if cmd_prbs_reset = '1' then
          v_ber := (others=>'0');
        end if;
        r_tx <= v_tx; r_rx <= v_rx; r_rxerr <= v_re; r_ber <= v_ber;

        -- lock / hi_ber transitions -> sticky events, lock time stamp
        r_prevlock <= lock_s;
        r_prevhb   <= hiber_s;
        if r_prevlock = '0' and lock_s = '1' then
          p_lock_gained <= '1';
          r_lockt <= r_cycle;
        end if;
        if r_prevlock = '1' and lock_s = '0' then p_lock_lost <= '1'; end if;
        if r_prevhb = '0' and hiber_s = '1' then p_hi_ber <= '1'; end if;

        -- prbs_lock follows block lock, cleared by soft_reset/prbs_reset
        if cmd_soft_reset = '1' or cmd_prbs_reset = '1' then
          r_prbs <= '0';
        elsif lock_s = '1' then
          r_prbs <= '1';
        end if;
      end if;
    end if;
  end process;

  cnt_tx_blk <= std_logic_vector(r_tx);
  cnt_rx_blk <= std_logic_vector(r_rx);
  cnt_rx_err <= std_logic_vector(r_rxerr);
  cnt_ber    <= std_logic_vector(r_ber);
  lock_time  <= std_logic_vector(r_lockt);

  st_block_lock <= lock_s;
  st_scr_sync   <= lock_s;
  st_prbs_lock  <= r_prbs or lock_s;   -- same cycle as the lock
  st_hi_ber     <= hiber_s;
  st_tx_active  <= r_txact;
  st_rx_active  <= r_rxact;

  ev_lock_gained <= p_lock_gained;
  ev_lock_lost   <= p_lock_lost;
  ev_hi_ber      <= p_hi_ber;
  ev_rx_err      <= p_rx_err;
  ev_prbs_err    <= p_prbs_err;

end architecture rtl;
