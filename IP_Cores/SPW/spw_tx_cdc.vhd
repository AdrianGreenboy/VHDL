-- ============================================================================
-- spw_tx_cdc.vhd -- SpaceWire transmitter on a dedicated bit clock (tx_clk)
-- ============================================================================
-- Audit 2026-11 (owner decision, 400 Mbit/s ASIC target): spw_tx runs in the
-- tx_clk domain (MIN_DIV = 1, so tx_clk = bit rate x div); this wrapper
-- presents exactly the spw_tx interface to the system (clk) domain.
--
-- Clock-domain crossings (clk -> tx_clk unless noted):
--   * rst / en / txen / allow_fct / allow_nchar : 2-FF level synchronizers.
--     The tx domain is held in (synchronous) reset while en and txen are
--     low, so D/S go to 0 exactly as with spw_tx (ECSS 8.4.2).
--   * div : captured in clk, a toggle announces a change; the tx domain
--     takes the (stable) bus after the toggle is synchronized (no torn
--     multi-bit sample).
--   * FCT and Time-Code requests: toggle handshake. One request in flight;
--     the ack pulse in clk is generated when the tx-domain ack toggle comes
--     back (round trip ~3 clk + 3 tx_clk cycles; FCTs are rare).
--   * N-Chars: asynchronous FIFO (gray pointers, 2-FF synchronized, depth
--     2**LOG2_AF). d_ack (clk) means "committed to the transmitter" (the
--     link layer counts credit on it); the FIFO is flushed in both domains
--     while txen is low, which matches the link-reset semantics.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_tx_cdc is
  generic (
    LOG2_AF : integer := 3
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;            -- synchronous, active high (clk)
    tx_clk      : in  std_logic;
    en          : in  std_logic;
    div         : in  std_logic_vector(7 downto 0);
    txen        : in  std_logic;
    allow_fct   : in  std_logic;
    allow_nchar : in  std_logic;
    fct_req     : in  std_logic;
    fct_ack     : out std_logic;
    time_req    : in  std_logic;
    time_val    : in  std_logic_vector(7 downto 0);
    time_ack    : out std_logic;
    d_valid     : in  std_logic;
    d_data      : in  std_logic_vector(8 downto 0);
    d_ack       : out std_logic;
    dout        : out std_logic;
    sout        : out std_logic
  );
end entity spw_tx_cdc;

architecture rtl of spw_tx_cdc is

  constant AF : integer := 2 ** LOG2_AF;
  type ram_t is array (0 to AF - 1) of std_logic_vector(8 downto 0);
  signal ram : ram_t;

  function bin2gray(b : unsigned) return unsigned is
  begin
    return b xor shift_right(b, 1);
  end function;

  -- clk domain
  signal run_c    : std_logic;
  signal fq_tog, tq_tog, dv_tog : std_logic := '0';
  signal fq_busy, tq_busy : std_logic := '0';
  signal fq_cool, tq_cool : std_logic := '0';  -- 1-cycle cooldown after ack
  signal fa_s1, fa_s2, fa_p, ta_s1, ta_s2, ta_p : std_logic := '0';
  signal div_c    : std_logic_vector(7 downto 0) := x"0A";
  signal tval_c   : std_logic_vector(7 downto 0) := (others => '0');
  signal wbin, wgray : unsigned(LOG2_AF downto 0) := (others => '0');
  signal rg_c1, rg_c2 : unsigned(LOG2_AF downto 0) := (others => '0');
  signal dack_r   : std_logic := '0';

  -- tx domain
  signal rst_t1, rst_t2 : std_logic := '1';
  signal txen_t1, txen_t2, af_t1, af_t2, an_t1, an_t2 : std_logic := '0';
  signal fq_t1, fq_t2, fq_seen, tq_t1, tq_t2, tq_seen : std_logic := '0';
  signal dv_t1, dv_t2, dv_seen : std_logic := '0';
  signal fa_tog, ta_tog : std_logic := '0';
  signal div_t    : std_logic_vector(7 downto 0) := x"0A";
  signal rbin, rgray : unsigned(LOG2_AF downto 0) := (others => '0');
  signal wg_t1, wg_t2 : unsigned(LOG2_AF downto 0) := (others => '0');
  signal t_fct_req, t_time_req, t_dvalid : std_logic;
  signal t_fct_ack, t_time_ack, t_dack : std_logic;
  signal t_head   : std_logic_vector(8 downto 0) := (others => '0');
  signal t_hv     : std_logic := '0';
  signal t_rst, t_en : std_logic;

begin

  run_c <= en and txen;

  -- ================================================================ clk side
  c_p : process (clk)
    variable v_full : boolean;
  begin
    if rising_edge(clk) then
      fct_ack  <= '0';
      time_ack <= '0';
      dack_r   <= '0';
      fa_s1 <= fa_tog; fa_s2 <= fa_s1;
      ta_s1 <= ta_tog; ta_s2 <= ta_s1;
      rg_c1 <= rgray;  rg_c2 <= rg_c1;
      if rst = '1' then
        fq_busy <= '0'; tq_busy <= '0'; fq_cool <= '0'; tq_cool <= '0';
        fq_tog <= '0'; tq_tog <= '0'; fa_p <= '0'; ta_p <= '0';
        dv_tog <= '0'; div_c <= x"0A";
        wbin <= (others => '0'); wgray <= (others => '0');
      else
        -- div: announce changes with a toggle
        if div /= div_c then
          div_c  <= div;
          dv_tog <= not dv_tog;
        end if;
        -- FCT handshake
        fa_p <= fa_s2;
        -- (the requester drops its level one cycle after our ack pulse: a
        --  cooldown cycle prevents a duplicate FCT / Time-Code)
        fq_cool <= '0';
        if fq_cool = '1' then
          fq_busy <= '0';
        elsif fq_busy = '0' and fct_req = '1' and allow_fct = '1' and run_c = '1' then
          fq_tog  <= not fq_tog;
          fq_busy <= '1';
        elsif fq_busy = '1' and fa_s2 /= fa_p then
          fct_ack <= '1';
          fq_cool <= '1';
        elsif run_c = '0' then
          fq_busy <= '0';
        end if;
        -- Time-Code handshake
        ta_p <= ta_s2;
        tq_cool <= '0';
        if tq_cool = '1' then
          tq_busy <= '0';
        elsif tq_busy = '0' and time_req = '1' and allow_nchar = '1' and run_c = '1' then
          tval_c  <= time_val;
          tq_tog  <= not tq_tog;
          tq_busy <= '1';
        elsif tq_busy = '1' and ta_s2 /= ta_p then
          time_ack <= '1';
          tq_cool  <= '1';
        elsif run_c = '0' then
          tq_busy <= '0';
        end if;
        -- N-Char async FIFO write side (flushed while not running)
        if run_c = '0' then
          wbin <= (others => '0'); wgray <= (others => '0');
        else
          v_full := wgray = (rg_c2 xor (to_unsigned(3, 2) & to_unsigned(0, LOG2_AF - 1)));
          if d_valid = '1' and dack_r = '0' and not v_full then
            ram(to_integer(wbin(LOG2_AF - 1 downto 0))) <= d_data;
            wbin   <= wbin + 1;
            wgray  <= bin2gray(wbin + 1);
            dack_r <= '1';
          end if;
        end if;
      end if;
    end if;
  end process c_p;

  d_ack <= dack_r;

  -- ============================================================= tx_clk side
  t_p : process (tx_clk)
  begin
    if rising_edge(tx_clk) then
      rst_t1 <= rst or not en;  rst_t2 <= rst_t1;
      txen_t1 <= txen;          txen_t2 <= txen_t1;
      af_t1 <= allow_fct;       af_t2 <= af_t1;
      an_t1 <= allow_nchar;     an_t2 <= an_t1;
      fq_t1 <= fq_tog;          fq_t2 <= fq_t1;
      tq_t1 <= tq_tog;          tq_t2 <= tq_t1;
      dv_t1 <= dv_tog;          dv_t2 <= dv_t1;
      wg_t1 <= wgray;           wg_t2 <= wg_t1;
      if rst_t2 = '1' then
        fq_seen <= fq_t2; tq_seen <= tq_t2; dv_seen <= dv_t2;
        div_t <= div_c;            -- re-sample (no transmission during reset)
        rbin <= (others => '0'); rgray <= (others => '0'); t_hv <= '0';
      else
        if dv_t2 /= dv_seen then
          dv_seen <= dv_t2;
          div_t   <= div_c;                     -- stable for >= 2 tx_clk
        end if;
        if t_fct_ack = '1' then
          fq_seen <= fq_t2;
          fa_tog  <= not fa_tog;
        end if;
        if t_time_ack = '1' then
          tq_seen <= tq_t2;
          ta_tog  <= not ta_tog;
        end if;
        -- N-Char FIFO read side: registered head + valid
        if txen_t2 = '0' then
          rbin <= (others => '0'); rgray <= (others => '0'); t_hv <= '0';
          fq_seen <= fq_t2; tq_seen <= tq_t2;     -- drop stale requests
        else
          if t_dack = '1' then
            t_hv <= '0';
          elsif t_hv = '0' and rgray /= wg_t2 then
            t_head <= ram(to_integer(rbin(LOG2_AF - 1 downto 0)));
            t_hv   <= '1';
            rbin   <= rbin + 1;
            rgray  <= bin2gray(rbin + 1);
          end if;
        end if;
      end if;
    end if;
  end process t_p;

  t_fct_req  <= '1' when fq_t2 /= fq_seen else '0';
  t_time_req <= '1' when tq_t2 /= tq_seen else '0';
  t_dvalid   <= t_hv;
  t_rst      <= rst_t2;
  t_en       <= not rst_t2;

  u_tx : entity work.spw_tx
    generic map (MIN_DIV => 1)
    port map (
      clk => tx_clk, rst => t_rst, en => t_en, div => div_t,
      txen => txen_t2, allow_fct => af_t2, allow_nchar => an_t2,
      fct_req => t_fct_req, fct_ack => t_fct_ack,
      time_req => t_time_req, time_val => tval_c, time_ack => t_time_ack,
      d_valid => t_dvalid, d_data => t_head, d_ack => t_dack,
      dout => dout, sout => sout);

end architecture rtl;
