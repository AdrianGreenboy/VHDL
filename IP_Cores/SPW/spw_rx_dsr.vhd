-- ============================================================================
-- spw_rx_dsr.vhd -- SpaceWire receiver with Data-Strobe clock recovery
-- ============================================================================
-- Audit 2026-11 (owner decision): up to 400 Mbit/s on the ASIC target.
-- Same user interface as spw_rx (drop-in, selected by spw_codec.G_RX_MODE).
--
-- Recovered-clock domain (rclk = din xor sin, one edge per bit):
--   * every bit has exactly one transition on D or S, so rclk toggles once
--     per bit. Even bits (counted from the transmitter reset, D = S = 0)
--     end on a rising rclk edge, odd bits on a falling edge; the bit value
--     is D after the transition.
--   * rising edge : rbit  <= din                (even bit)
--     falling edge: pair  =  rbit & din          (even, odd), 4 pairs form
--                   an 8-bit word (oldest bit in the MSB) written into an
--                   asynchronous FIFO (gray pointers).
--   * the falling-edge domain also toggles an activity flag every 2 bits.
--   * reset of this domain: asynchronous assertion AND release from the
--     registered (glitch-free) rx_rst of the clk domain. The domain has no
--     clock while the line is quiet, so a synchronous reset is impossible
--     (documented exception to the synchronous-reset rule of the IP). A
--     release synchronized to rclk would swallow the first bits after the
--     line wakes up, i.e. the single NULL a remote sends before its FCT
--     burst in Connecting (found by tb_spw_1c). A reset-recovery violation
--     at release can only corrupt the bits arriving at that instant, which
--     the first-NULL hunt tolerates (STA: rx_rst -> rclk flops is a false
--     path / recovery-removal waived, see README).
--
-- System domain (clk):
--   * 2-FF synchronized gray write pointer, registered RAM read, and an
--     8-bit-per-cycle character decoder (the same character rules as spw_rx:
--     first-NULL hunt, chained odd parity, ESC handling). 8 bits per cycle
--     at 100 MHz gives 800 Mbit/s of decode capacity (2x margin at 400).
--   * up to 2 characters can end in one 8-bit word: decoded events go
--     through a 4-entry queue; a word is only read with >= 2 free slots.
--   * disconnect (ECSS 8.5.3.7.2, DISC_CYCLES after the first NULL): any
--     FIFO write (synchronized write pointer change) or activity-toggle
--     change restarts the timer. Low rates are covered by the toggle (every
--     2 bits), high rates by the FIFO writes (every 8 bits), so neither
--     aliasing of the toggle at high rate nor the 8-bit grouping at 10
--     Mbit/s can produce a false disconnect.
--
-- Not detectable in this architecture: simultaneous D/S transitions (they
-- produce no rclk edge, i.e. a lost bit). They show up as parity / escape
-- errors or as a disconnect. Use G_RX_MODE = 0 (oversampling spw_rx) where
-- direct detection is required (rates <= 50 Mbit/s at 100 MHz).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_rx_dsr is
  generic (
    DISC_CYCLES : integer := 85;
    LOG2_AF     : integer := 4          -- async FIFO depth = 2**LOG2_AF words
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;         -- synchronous, active high (clk)
    en         : in  std_logic;
    rxen       : in  std_logic;
    din        : in  std_logic;
    sin        : in  std_logic;
    first_null : out std_logic;
    got_null   : out std_logic;
    got_fct    : out std_logic;
    got_time   : out std_logic;
    time_out   : out std_logic_vector(7 downto 0);
    rx_we      : out std_logic;
    rx_data    : out std_logic_vector(8 downto 0);
    err_par    : out std_logic;
    err_esc    : out std_logic;
    err_disc   : out std_logic
  );
end entity spw_rx_dsr;

architecture rtl of spw_rx_dsr is

  constant AF : integer := 2 ** LOG2_AF;
  type ram_t is array (0 to AF - 1) of std_logic_vector(7 downto 0);
  signal ram : ram_t;

  function bin2gray(b : unsigned) return unsigned is
  begin
    return b xor shift_right(b, 1);
  end function;

  -- ---------------------------------------------------------------- rclk side
  signal rclk      : std_logic;
  signal rx_rst    : std_logic := '1';           -- from clk domain (registered)
  signal rs2       : std_logic := '1';           -- domain reset (= rx_rst)
  signal rbit      : std_logic := '0';
  signal acc6      : std_logic_vector(5 downto 0) := (others => '0');
  signal gcnt      : unsigned(1 downto 0) := (others => '0');
  signal wbin      : unsigned(LOG2_AF downto 0) := (others => '0');
  signal wgray     : unsigned(LOG2_AF downto 0) := (others => '0');
  signal rg_w1, rg_w2 : unsigned(LOG2_AF downto 0) := (others => '0'); -- rgray in rclk
  signal tog       : std_logic := '0';

  -- ----------------------------------------------------------------- clk side
  signal wg_s1, wg_s2 : unsigned(LOG2_AF downto 0) := (others => '0');
  signal wg_prev   : unsigned(LOG2_AF downto 0) := (others => '0');
  signal tg_s1, tg_s2, tg_prev : std_logic := '0';
  signal rbin      : unsigned(LOG2_AF downto 0) := (others => '0');
  signal rgray     : unsigned(LOG2_AF downto 0) := (others => '0');
  signal rd_q      : std_logic_vector(7 downto 0) := (others => '0');
  signal rd_v      : std_logic := '0';

  type st_t is (HUNT, GETP, GETF, PAY2, PAY8, HALT);
  signal st     : st_t := HUNT;
  signal sh     : std_logic_vector(7 downto 0) := (others => '0');
  signal acc    : std_logic := '0';
  signal pbit   : std_logic := '0';
  signal escf   : std_logic := '0';
  signal b1r    : std_logic := '0';
  signal payidx : unsigned(2 downto 0) := (others => '0');
  signal pay    : std_logic_vector(7 downto 0) := (others => '0');
  signal fnull  : std_logic := '0';
  signal dcnt   : integer range 0 to DISC_CYCLES := 0;

  -- event queue: type(3) & payload(9)
  constant E_NULL : std_logic_vector(2 downto 0) := "001";
  constant E_FCT  : std_logic_vector(2 downto 0) := "010";
  constant E_TIME : std_logic_vector(2 downto 0) := "011";
  constant E_DATA : std_logic_vector(2 downto 0) := "100";
  constant E_PERR : std_logic_vector(2 downto 0) := "101";
  constant E_EERR : std_logic_vector(2 downto 0) := "110";
  type evq_t is array (0 to 3) of std_logic_vector(11 downto 0);
  signal evq  : evq_t := (others => (others => '0'));
  signal evn  : integer range 0 to 4 := 0;

begin

  first_null <= fnull;

  -- ===================================================== recovered clock domain
  rclk <= din xor sin;

  rs2 <= rx_rst;

  cap_rise : process (rclk, rs2)
  begin
    if rs2 = '1' then
      rbit <= '0';
    elsif rising_edge(rclk) then
      rbit <= din;                               -- even bit
    end if;
  end process cap_rise;

  cap_fall : process (rclk, rs2)
    variable v_w    : std_logic_vector(7 downto 0);
    variable v_next : unsigned(LOG2_AF downto 0);
    variable v_full : boolean;
  begin
    if rs2 = '1' then
      acc6  <= (others => '0');
      gcnt  <= (others => '0');
      wbin  <= (others => '0');
      wgray <= (others => '0');
      rg_w1 <= (others => '0');
      rg_w2 <= (others => '0');
      tog   <= '0';
    elsif falling_edge(rclk) then
      rg_w1 <= rgray;                            -- read pointer -> rclk
      rg_w2 <= rg_w1;
      tog   <= not tog;
      v_w   := acc6 & rbit & din;                -- even bit, odd bit
      acc6  <= acc6(3 downto 0) & rbit & din;
      if gcnt = 3 then
        -- full: gray(next) equals gray(rptr) with the two MSBs inverted
        v_next := wbin + 1;
        v_full := wgray = (rg_w2 xor (to_unsigned(3, 2) & to_unsigned(0, LOG2_AF - 1)));
        if not v_full then
          ram(to_integer(wbin(LOG2_AF - 1 downto 0))) <= v_w;
          wbin  <= v_next;
          wgray <= bin2gray(v_next);
        end if;
      end if;
      gcnt <= gcnt + 1;
    end if;
  end process cap_fall;

  -- ============================================================ system domain
  sys : process (clk)
    variable v_st     : st_t;
    variable v_sh     : std_logic_vector(7 downto 0);
    variable v_acc, v_pbit, v_escf, v_b1r : std_logic;
    variable v_payidx : unsigned(2 downto 0);
    variable v_pay    : std_logic_vector(7 downto 0);
    variable v_q      : evq_t;
    variable v_n      : integer range 0 to 6;
    variable v_byte   : std_logic_vector(7 downto 0);
    variable v_act    : boolean;
    variable v_read   : boolean;
    variable v_ev     : std_logic_vector(11 downto 0);

    procedure push(t : std_logic_vector(2 downto 0); p : std_logic_vector(8 downto 0)) is
    begin
      if v_n < 4 then
        v_q(v_n) := t & p;
        v_n := v_n + 1;
      end if;
    end procedure;

    -- one bit of the character decoder (same rules as spw_rx)
    procedure step(b : std_logic) is
    begin
      case v_st is
        when HUNT =>
          v_sh := v_sh(6 downto 0) & b;
          if v_sh = "01110100" then
            v_st := GETP; v_acc := '0'; v_escf := '0';
            push(E_NULL, (others => '0'));
          end if;
        when GETP =>
          v_pbit := b;
          v_st   := GETF;
        when GETF =>
          if (v_acc xor v_pbit xor b) /= '1' then
            push(E_PERR, (others => '0'));
            v_st := HALT;
          else
            v_acc := '0';
            v_payidx := (others => '0');
            if b = '1' then v_st := PAY2; else v_st := PAY8; end if;
          end if;
        when PAY2 =>
          if v_payidx = 0 then
            v_b1r := b;
            v_payidx := to_unsigned(1, 3);
          else
            v_acc := v_b1r xor b;
            v_st  := GETP;
            if v_b1r = '0' and b = '0' then          -- FCT
              if v_escf = '1' then
                v_escf := '0';
                push(E_NULL, (others => '0'));
              else
                push(E_FCT, (others => '0'));
              end if;
            elsif v_b1r = '0' and b = '1' then       -- EOP
              if v_escf = '1' then
                push(E_EERR, (others => '0')); v_st := HALT;
              else
                push(E_DATA, "100000000");
              end if;
            elsif v_b1r = '1' and b = '0' then       -- EEP
              if v_escf = '1' then
                push(E_EERR, (others => '0')); v_st := HALT;
              else
                push(E_DATA, "100000001");
              end if;
            else                                     -- ESC
              if v_escf = '1' then
                push(E_EERR, (others => '0')); v_st := HALT;
              else
                v_escf := '1';
              end if;
            end if;
          end if;
        when PAY8 =>
          v_pay(to_integer(v_payidx)) := b;
          v_acc := v_acc xor b;
          if v_payidx = 7 then
            v_byte := v_pay;
            v_st   := GETP;
            if v_escf = '1' then
              v_escf := '0';
              push(E_TIME, '0' & v_byte);
            else
              push(E_DATA, '0' & v_byte);
            end if;
          else
            v_payidx := v_payidx + 1;
          end if;
        when HALT =>
          null;
      end case;
    end procedure;

  begin
    if rising_edge(clk) then
      got_null <= '0'; got_fct <= '0'; got_time <= '0';
      rx_we    <= '0'; err_par <= '0'; err_esc <= '0'; err_disc <= '0';
      -- pointer / activity synchronizers (always running)
      wg_s1 <= wgray; wg_s2 <= wg_s1;
      tg_s1 <= tog;   tg_s2 <= tg_s1;

      if rst = '1' or en = '0' or rxen = '0' then
        rx_rst <= '1';
        st <= HUNT; sh <= (others => '0'); acc <= '0'; escf <= '0';
        fnull <= '0'; dcnt <= 0; payidx <= (others => '0');
        rbin <= (others => '0'); rgray <= (others => '0'); rd_v <= '0';
        evn <= 0;
        wg_prev <= (others => '0'); tg_prev <= tg_s2;
        if rst = '1' then
          time_out <= (others => '0'); rx_data <= (others => '0');
        end if;
      else
        rx_rst <= '0';
        v_st := st; v_sh := sh; v_acc := acc; v_pbit := pbit; v_escf := escf;
        v_b1r := b1r; v_payidx := payidx; v_pay := pay;
        v_q := evq; v_n := evn;

        -- 1) decode the word read in the previous cycle (8 bits, MSB first)
        if rd_v = '1' then
          for i in 7 downto 0 loop
            step(rd_q(i));
          end loop;
        end if;

        -- 2) output one event per cycle
        if v_n > 0 then
          v_ev := v_q(0);
          v_q(0 to 2) := v_q(1 to 3);
          v_n := v_n - 1;
          case v_ev(11 downto 9) is
            when E_NULL => got_null <= '1'; fnull <= '1';
            when E_FCT  => got_fct  <= '1';
            when E_TIME => got_time <= '1'; time_out <= v_ev(7 downto 0);
            when E_DATA => rx_we    <= '1'; rx_data  <= v_ev(8 downto 0);
            when E_PERR => err_par  <= '1';
            when E_EERR => err_esc  <= '1';
            when others => null;
          end case;
        end if;

        -- 3) read the next FIFO word when not empty and the queue has room
        v_read := (rgray /= wg_s2) and (v_n <= 2) and v_st /= HALT;
        rd_v <= '0';
        if v_read then
          rd_q  <= ram(to_integer(rbin(LOG2_AF - 1 downto 0)));
          rd_v  <= '1';
          rbin  <= rbin + 1;
          rgray <= bin2gray(rbin + 1);
        end if;

        -- 4) disconnect timer (after the first NULL, not after an error)
        v_act := (wg_s2 /= wg_prev) or (tg_s2 /= tg_prev);
        wg_prev <= wg_s2; tg_prev <= tg_s2;
        if fnull = '1' and v_st /= HALT then
          if v_act then
            dcnt <= 0;
          elsif dcnt = DISC_CYCLES - 1 then
            err_disc <= '1';
            v_st := HALT;
            dcnt <= 0;
          else
            dcnt <= dcnt + 1;
          end if;
        else
          dcnt <= 0;
        end if;

        st <= v_st; sh <= v_sh; acc <= v_acc; pbit <= v_pbit; escf <= v_escf;
        b1r <= v_b1r; payidx <= v_payidx; pay <= v_pay;
        evq <= v_q; evn <= v_n;
      end if;
    end if;
  end process sys;

end architecture rtl;
