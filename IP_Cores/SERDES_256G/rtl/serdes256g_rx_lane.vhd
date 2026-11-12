-------------------------------------------------------------------------------
-- SERDES_256G - RX lane (recovered-clock domain of ONE GT channel)
--
--   gt_rxdata (128 bit, raw) -> gearbox 128 -> 132 with bit slip
--                            -> block lock (IEEE 802.3 clause 49 thresholds)
--                            -> alignment marker lock
--                            -> write side of the lane deskew FIFO
--
-- Gearbox: the last three GT words form a 384-bit window; 'p' is the offset
-- of the next 132-bit lane word inside the oldest GT word. Every clock the
-- window base advances 128 bits:
--     p <  128 : emit window(p+131 downto p),  p <= p + 4
--     p >= 128 : no word this clock,           p <= p - 128
-- A slip adds 1 (block lock) or 66 (block-pair phase, from the marker lock)
-- to p. The shifter is feed-forward and split in two registered stages
-- (coarse 16-bit steps, fine 1-bit steps).
--
-- Block lock: both sync headers of a lane word are checked.
--   not locked : any invalid header -> slip 1 bit; 64 consecutive valid
--                headers (32 words) -> lock
--   locked     : 16 invalid headers inside a 64-header window -> lock lost
-- Block lock alone cannot tell block 0 from block 1 of the lane word; the
-- marker lock does: AM_A found in block 1 -> slip 66 bits.
--
-- Marker lock: AM_A & AM_B must be seen twice, exactly G_AM_PERIOD lane words
-- apart. Once locked, every lane word is written to the deskew FIFO with a
-- flag on the marker position (the flag follows the counter, so one corrupted
-- marker does not disturb the deskew). Four consecutive bad markers, loss of
-- block lock or a full FIFO drop the lock.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.serdes256g_pkg.all;

entity serdes256g_rx_lane is
  generic (
    G_AM_PERIOD : positive := 16384;
    G_SLIP_WAIT : positive := 8          -- lane words ignored after a slip
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    gt_rxdata  : in  std_logic_vector(127 downto 0);
    -- deskew FIFO, write side
    fifo_full  : in  std_logic;
    fifo_wr    : out std_logic;
    fifo_din   : out std_logic_vector(132 downto 0);   -- is_am & lane word
    -- status (this clock domain)
    block_lock : out std_logic;
    am_lock    : out std_logic
  );
end entity serdes256g_rx_lane;

architecture rtl of serdes256g_rx_lane is
  -- gearbox
  signal w0, w1, w2 : std_logic_vector(127 downto 0) := (others => '0');
  signal p          : unsigned(8 downto 0) := (others => '0');
  signal a_tmp      : unsigned(147 downto 0) := (others => '0');
  signal a_fine     : unsigned(3 downto 0) := (others => '0');
  signal a_valid    : std_logic := '0';
  signal b_word     : std_logic_vector(131 downto 0) := (others => '0');
  signal b_valid    : std_logic := '0';
  signal slip1      : std_logic := '0';
  signal slip66     : std_logic := '0';

  -- block lock
  signal lock  : std_logic := '0';
  signal hcnt  : unsigned(4 downto 0) := (others => '0');   -- words in window
  signal inv   : unsigned(6 downto 0) := (others => '0');
  signal waitc : integer range 0 to G_SLIP_WAIT := 0;

  -- marker lock
  type t_amst is (AM_SEARCH, AM_CONFIRM, AM_LOCKED);
  signal amst    : t_amst := AM_SEARCH;
  signal amc     : integer range 0 to G_AM_PERIOD-1 := 0;
  signal miss    : unsigned(1 downto 0) := (others => '0');
  signal amlk_r  : std_logic := '0';
  signal wr_r    : std_logic := '0';
  signal din_r   : std_logic_vector(132 downto 0) := (others => '0');
begin

  -----------------------------------------------------------------------------
  -- gearbox 128 -> 132 with slip
  -----------------------------------------------------------------------------
  process(clk)
    variable win : unsigned(383 downto 0);
    variable pn  : unsigned(8 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        w0 <= (others => '0'); w1 <= (others => '0'); w2 <= (others => '0');
        p       <= (others => '0');
        a_tmp   <= (others => '0');
        a_fine  <= (others => '0');
        a_valid <= '0';
        b_word  <= (others => '0');
        b_valid <= '0';
      else
        w2 <= gt_rxdata;
        w1 <= w2;
        w0 <= w1;

        win := unsigned(w2) & unsigned(w1) & unsigned(w0);
        if p < 128 then
          a_tmp   <= resize(shift_right(win, 16*to_integer(p(6 downto 4))), 148);
          a_fine  <= p(3 downto 0);
          a_valid <= '1';
          pn := p + 4;
        else
          a_valid <= '0';
          pn := p - 128;
        end if;
        if slip1 = '1' then
          pn := pn + 1;
        end if;
        if slip66 = '1' then
          pn := pn + 66;
        end if;
        p <= pn;

        b_word  <= std_logic_vector(
                     resize(shift_right(a_tmp, to_integer(a_fine)), 132));
        b_valid <= a_valid;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- block lock + marker lock + FIFO write
  -----------------------------------------------------------------------------
  process(clk)
    variable ninv   : unsigned(6 downto 0);
    variable t      : unsigned(6 downto 0);
    variable v_lock : std_logic;
    variable m0, m1 : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        slip1  <= '0';
        slip66 <= '0';
        lock   <= '0';
        hcnt   <= (others => '0');
        inv    <= (others => '0');
        waitc  <= 0;
        amst   <= AM_SEARCH;
        amc    <= 0;
        miss   <= (others => '0');
        amlk_r <= '0';
        wr_r   <= '0';
        din_r  <= (others => '0');
      else
        slip1  <= '0';
        slip66 <= '0';
        wr_r   <= '0';

        if b_valid = '1' then
          if waitc /= 0 then
            waitc <= waitc - 1;
          else
            -------------------------------------------------------------------
            -- block lock
            -------------------------------------------------------------------
            ninv := (others => '0');
            if b_word(0) = b_word(1) then
              ninv := ninv + 1;
            end if;
            if b_word(66) = b_word(67) then
              ninv := ninv + 1;
            end if;

            v_lock := lock;
            if lock = '0' then
              if ninv /= 0 then
                slip1 <= '1';
                waitc <= G_SLIP_WAIT;
                hcnt  <= (others => '0');
              elsif hcnt = 31 then
                lock <= '1';
                hcnt <= (others => '0');
                inv  <= (others => '0');
              else
                hcnt <= hcnt + 1;
              end if;
            else
              t := inv + ninv;
              if t >= 16 then
                lock   <= '0';
                v_lock := '0';
                slip1  <= '1';
                waitc  <= G_SLIP_WAIT;
                hcnt   <= (others => '0');
                inv    <= (others => '0');
              elsif hcnt = 31 then
                hcnt <= (others => '0');
                inv  <= (others => '0');
              else
                hcnt <= hcnt + 1;
                inv  <= t;
              end if;
            end if;

            -------------------------------------------------------------------
            -- marker lock
            -------------------------------------------------------------------
            m0 := f_is_am_a(b_word(65 downto 0)) and
                  f_is_am_b(b_word(131 downto 66));
            m1 := f_is_am_a(b_word(131 downto 66));

            if v_lock = '0' then
              amst   <= AM_SEARCH;
              amlk_r <= '0';
            else
              -- position counter (overridden below when a search hits)
              if amc = G_AM_PERIOD-1 then
                amc <= 0;
              else
                amc <= amc + 1;
              end if;

              case amst is
                when AM_SEARCH =>
                  amlk_r <= '0';
                  if m0 then
                    amc  <= 1 mod G_AM_PERIOD;
                    amst <= AM_CONFIRM;
                  elsif m1 then
                    slip66 <= '1';
                    waitc  <= G_SLIP_WAIT;
                  end if;

                when AM_CONFIRM =>
                  if amc = 0 then
                    if m0 then
                      amst   <= AM_LOCKED;
                      amlk_r <= '1';
                      miss   <= (others => '0');
                    else
                      amst <= AM_SEARCH;
                    end if;
                  end if;

                when AM_LOCKED =>
                  if fifo_full = '1' then
                    amst   <= AM_SEARCH;
                    amlk_r <= '0';
                  else
                    wr_r <= '1';
                    if amc = 0 then
                      din_r <= '1' & b_word;
                      if m0 then
                        miss <= (others => '0');
                      elsif miss = 3 then
                        amst   <= AM_SEARCH;
                        amlk_r <= '0';
                      else
                        miss <= miss + 1;
                      end if;
                    else
                      din_r <= '0' & b_word;
                    end if;
                  end if;
              end case;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  fifo_wr    <= wr_r;
  fifo_din   <= din_r;
  block_lock <= lock;
  am_lock    <= amlk_r;

end architecture rtl;
