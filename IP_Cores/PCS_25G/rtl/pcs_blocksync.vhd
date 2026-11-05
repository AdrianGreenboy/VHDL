-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- pcs_blocksync: IEEE 802.3 clause 49 block synchronisation + BER monitor
-- (audit 2026-11, fixes A3/M2).
--
-- Lock state machine (Fig. 49-14 / 49-15), ported from the silicon-proven
-- MAC_10G eth21_blocklock and made explicit at the window boundary:
--   * a sync header is VALID when its two bits differ ("01" or "10"); the
--     test does not depend on which of the two codes means data
--   * not locked: any invalid header -> SLIP (restart the count);
--     LOCK_CNT (64) consecutive valid headers -> block_lock
--   * locked: windows of WIN (64) headers; INV_LIM (16) invalid headers
--     inside one window -> block_lock lost + SLIP. The invalid header that
--     lands exactly on the window boundary (64th header) IS counted before
--     the window is restarted (fix B2; eth21_blocklock gave the same result
--     only because its threshold branch was evaluated first).
--   * SLIP: 1-cycle pulse to the gearbox; for SLIP_WAIT cycles afterwards
--     the input is ignored (the slip takes effect in the gearbox / GT with
--     some latency). SLIP_WAIT = 0 tests the very next header.
--
-- BER monitor (Fig. 49-13), only while block_lock = 1:
--   * a timer of HIBER_WINDOW clk cycles is (re)started at lock and at every
--     expiry; ber_cnt counts invalid headers inside the current window
--   * ber_cnt reaching HIBER_THR (16) -> hi_ber = 1 at once
--   * timer expiry with ber_cnt < HIBER_THR -> hi_ber = 0 (GOOD_BER)
--   * block_lock = 0 -> hi_ber = 0, monitor re-initialised (BER_MT_INIT)
--   Default HIBER_WINDOW = 48828 cycles = 125 us at 390.625 MHz (one
--   66-bit block per cycle). For 10GBASE-R at 156.25 MHz use 19531. NOTE:
--   these are the clause-49 (10GBASE-R) values; 25GBASE-R (clause 107)
--   reuses the clause-49 monitor but the integrator must confirm window and
--   threshold against the exact edition of IEEE 802.3 in force (generics).
--
-- resync (pulse): forces lock loss and a fresh acquisition (no slip).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_blocksync is
  generic (
    SLIP_WAIT    : natural := 4;        -- cycles ignored after a slip
    LOCK_CNT     : natural := 64;       -- valid headers to lock
    WIN          : natural := 64;       -- window length while locked
    INV_LIM      : natural := 16;       -- invalid headers per window to unlock
    HIBER_WINDOW : natural := 48828;    -- BER window in clk cycles (125 us)
    HIBER_THR    : natural := 16        -- invalid headers per window -> hi_ber
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    resync    : in  std_logic := '0';
    in_valid  : in  std_logic;                       -- one header tested
    in_header : in  std_logic_vector(1 downto 0);
    slip      : out std_logic;                       -- 1-cycle pulse
    lock      : out std_logic;
    hi_ber    : out std_logic;
    ev_goodsh : out std_logic;                       -- tested header valid
    ev_badsh  : out std_logic;                       -- tested header invalid
    ev_slip   : out std_logic;
    ev_gained : out std_logic;
    ev_lost   : out std_logic;
    ev_hiber  : out std_logic                        -- hi_ber 0 -> 1
  );
end entity pcs_blocksync;

architecture rtl of pcs_blocksync is
  signal lock_r   : std_logic := '0';
  signal sh_cnt   : unsigned(7 downto 0) := (others => '0');
  signal inv_cnt  : unsigned(7 downto 0) := (others => '0');
  signal waitc    : unsigned(9 downto 0) := (others => '0');
  signal hb_r     : std_logic := '0';
  signal ber_cnt  : unsigned(7 downto 0) := (others => '0');
  signal tmr      : unsigned(23 downto 0) := (others => '0');
  signal slip_r, e_good, e_bad, e_slip, e_gain, e_lost, e_hb : std_logic := '0';
begin

  process(clk)
    variable shv     : boolean;
    variable lock_v  : std_logic;
    variable inv_n   : unsigned(7 downto 0);
    variable do_slip : boolean;
    variable hb_v    : std_logic;
    variable ber_n   : unsigned(7 downto 0);
    variable tmr_n   : unsigned(23 downto 0);
  begin
    if rising_edge(clk) then
      slip_r <= '0'; e_good <= '0'; e_bad <= '0'; e_slip <= '0';
      e_gain <= '0'; e_lost <= '0'; e_hb <= '0';
      if rst = '1' then
        lock_r <= '0'; sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
        waitc <= (others => '0'); hb_r <= '0'; ber_cnt <= (others => '0');
        tmr <= (others => '0');
      elsif resync = '1' then
        if lock_r = '1' then e_lost <= '1'; end if;
        lock_r <= '0'; sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
        waitc <= (others => '0'); hb_r <= '0'; ber_cnt <= (others => '0');
        tmr <= (others => '0');
      else
        lock_v  := lock_r;
        do_slip := false;
        hb_v    := hb_r;
        ber_n   := ber_cnt;
        tmr_n   := tmr;

        -- ---------------- lock state machine (Fig. 49-15) ----------------
        if waitc /= 0 then
          waitc <= waitc - 1;
        elsif in_valid = '1' then
          shv := (in_header(0) /= in_header(1));
          if shv then e_good <= '1'; else e_bad <= '1'; end if;
          if lock_r = '0' then
            if not shv then
              do_slip := true;
            elsif sh_cnt = LOCK_CNT - 1 then
              lock_v := '1'; e_gain <= '1';
              sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
            else
              sh_cnt <= sh_cnt + 1;
            end if;
          else
            inv_n := inv_cnt;
            if not shv then inv_n := inv_cnt + 1; end if;
            if inv_n = INV_LIM then
              lock_v := '0'; e_lost <= '1';
              do_slip := true;
            elsif sh_cnt = WIN - 1 then
              sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
            else
              sh_cnt <= sh_cnt + 1; inv_cnt <= inv_n;
            end if;
            -- BER monitor counts invalid headers while locked
            if not shv and ber_n /= HIBER_THR then ber_n := ber_n + 1; end if;
          end if;
          if do_slip then
            slip_r <= '1'; e_slip <= '1';
            waitc <= to_unsigned(SLIP_WAIT, 10);
            sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
          end if;
        end if;

        -- ---------------- BER monitor (Fig. 49-13) ----------------
        if lock_v = '0' then
          hb_v := '0'; ber_n := (others => '0'); tmr_n := (others => '0');
        elsif lock_r = '0' then
          -- lock just gained: START_TIMER
          ber_n := (others => '0'); tmr_n := (others => '0');
        else
          if ber_n = HIBER_THR then hb_v := '1'; end if;
          if tmr = HIBER_WINDOW - 1 then
            -- timer done: GOOD_BER if the window stayed below threshold
            if ber_n /= HIBER_THR then hb_v := '0'; end if;
            ber_n := (others => '0'); tmr_n := (others => '0');
          else
            tmr_n := tmr + 1;
          end if;
        end if;
        if hb_r = '0' and hb_v = '1' then e_hb <= '1'; end if;

        lock_r  <= lock_v;
        hb_r    <= hb_v;
        ber_cnt <= ber_n;
        tmr     <= tmr_n;
      end if;
    end if;
  end process;

  slip      <= slip_r;
  lock      <= lock_r;
  hi_ber    <= hb_r;
  ev_goodsh <= e_good;
  ev_badsh  <= e_bad;
  ev_slip   <= e_slip;
  ev_gained <= e_gain;
  ev_lost   <= e_lost;
  ev_hiber  <= e_hb;

end architecture rtl;
