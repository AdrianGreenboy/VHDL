-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- tb_pcs_blocksync: clause-49 block lock + BER monitor counts
-- (audit 2026-11, fixes A3/M2/B2). One header per clock, self-checking:
--   T1  63 valid headers: no lock; the 64th: lock
--   T2  15 invalid in a 64-header window: lock kept (twice, window restart)
--   T3  49 valid + 15 invalid = full window: kept; next 16 invalid: lost
--   T4  boundary: 48 valid + 15 invalid + invalid as the 64th header -> lost
--   T5  unlocked invalid header -> one slip, SLIP_WAIT headers ignored
--   T6  hi_ber: 16 invalid spread (4 per 64) inside one BER window while
--       locked -> hi_ber = 1 with lock kept; stays 1 across the expiry of
--       that window; cleared after a clean window
--   T7  15 invalid in a BER window: no hi_ber
--   T8  hi_ber is cleared when the lock is lost
--   T9  resync: lock dropped without slip, re-acquired after 64 headers
-- Prints TB_PCS_BLOCKSYNC_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_blocksync is end entity;

architecture sim of tb_pcs_blocksync is
  constant SW  : natural := 4;
  constant WINC: natural := 2000;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal resync, iv : std_logic := '0';
  signal hd : std_logic_vector(1 downto 0) := "10";
  signal slip, lock, hiber, eg, eb, es, egn, el, eh : std_logic;
  signal n_slip, n_bad : natural := 0;
  signal done : boolean := false;
begin
  clk <= not clk after 1 ns when not done;

  dut: entity work.pcs_blocksync
    generic map (SLIP_WAIT => SW, HIBER_WINDOW => WINC)
    port map (clk=>clk, rst=>rst, resync=>resync, in_valid=>iv, in_header=>hd,
              slip=>slip, lock=>lock, hi_ber=>hiber, ev_goodsh=>eg, ev_badsh=>eb,
              ev_slip=>es, ev_gained=>egn, ev_lost=>el, ev_hiber=>eh);

  process(clk)
  begin
    if rising_edge(clk) then
      if slip = '1' then n_slip <= n_slip + 1; end if;
      if eb = '1' then n_bad <= n_bad + 1; end if;
    end if;
  end process;

  stim: process
    variable ok : boolean := true;
    variable t0 : natural;
    variable cyc : natural := 0;

    procedure fail(m : string) is
    begin
      report "TB_PCS_BLOCKSYNC_FAIL " & m severity error; ok := false;
    end procedure;

    -- n headers, valid ('1') or invalid ('0'); one per clock
    procedure h(valid : std_logic; n : natural) is
    begin
      for i in 1 to n loop
        iv <= '1';
        if valid = '1' then
          if (cyc mod 2) = 0 then hd <= "10"; else hd <= "01"; end if;
        else
          if (cyc mod 2) = 0 then hd <= "00"; else hd <= "11"; end if;
        end if;
        wait until rising_edge(clk);
        cyc := cyc + 1;
      end loop;
      iv <= '0';
    end procedure;

    procedure settle is
    begin
      iv <= '0'; wait until rising_edge(clk); wait until rising_edge(clk); cyc := cyc + 2;
    end procedure;

    procedure relock is
    begin
      settle; h('1', 64); settle;
      if lock /= '1' then fail("relock"); end if;
    end procedure;
  begin
    rst <= '1';
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);

    -- T1
    h('1', 63); settle;
    if lock /= '0' then fail("T1 locked after 63"); end if;
    h('1', 1); settle;
    if lock /= '1' then fail("T1 no lock after 64"); end if;

    -- T2 (window starts at the lock: counters were reset)
    for k in 1 to 2 loop
      h('1', 40); h('0', 15); h('1', 9);         -- exactly one 64-header window
    end loop;
    settle;
    if lock /= '1' then fail("T2 lost lock with 15 invalid per window"); end if;

    -- T3
    h('1', 49); h('0', 15); settle;
    if lock /= '1' then fail("T3a lost lock at 15 + window end"); end if;
    h('0', 16); settle;
    if lock /= '0' then fail("T3b still locked after 16 invalid"); end if;

    -- T4 boundary: the 16th invalid header is the 64th of the window
    rst <= '1'; wait until rising_edge(clk); rst <= '0';
    h('1', 64); settle;
    if lock /= '1' then fail("T4 lock"); end if;
    h('1', 48); h('0', 15); settle;
    if lock /= '1' then fail("T4 early loss"); end if;
    h('0', 1); settle;
    if lock /= '0' then fail("T4 invalid header on the window boundary not counted"); end if;

    -- T5 slip and wait
    rst <= '1'; wait until rising_edge(clk); rst <= '0'; wait until rising_edge(clk);
    t0 := n_slip;
    h('0', 1 + SW);                     -- 1 slip, then SW ignored headers
    settle;
    if n_slip - t0 /= 1 then fail("T5 slips=" & integer'image(n_slip - t0) & " (expected 1)"); end if;
    h('0', 1); settle;
    if n_slip - t0 /= 2 then fail("T5 header after the wait not tested"); end if;

    -- T6 hi_ber: lock, then 4 invalid per 64 headers, 4 times (= 16)
    settle;
    h('1', 64);                          -- lock gained here: BER window starts
    t0 := cyc;
    for k in 1 to 4 loop h('0', 4); h('1', 60); end loop;
    settle;
    if lock /= '1' then fail("T6 lock lost"); end if;
    if hiber /= '1' then fail("T6 no hi_ber after 16 invalid in the BER window"); end if;
    -- run to just past the end of the first BER window
    h('1', WINC - (cyc - t0) + 5); settle;
    if hiber /= '1' then fail("T6 hi_ber cleared at the end of the bad window"); end if;
    -- a full clean window -> GOOD_BER
    h('1', WINC); settle;
    if hiber /= '0' then fail("T6 hi_ber not cleared after a clean window"); end if;

    -- T7 15 invalid in a BER window -> no hi_ber
    rst <= '1'; wait until rising_edge(clk); rst <= '0';
    h('1', 64);
    for k in 1 to 3 loop h('0', 5); h('1', 59); end loop;
    settle;
    if hiber /= '0' then fail("T7 hi_ber with 15 invalid"); end if;
    if lock /= '1' then fail("T7 lock"); end if;

    -- T8 hi_ber cleared on lock loss
    h('0', 1); h('1', 63); settle;       -- 16th invalid of the BER window
    if hiber /= '1' then fail("T8 hi_ber"); end if;
    h('0', 16); settle;
    if lock /= '0' or hiber /= '0' then fail("T8 hi_ber kept after lock loss"); end if;

    -- T9 resync
    relock;
    t0 := n_slip;
    resync <= '1'; wait until rising_edge(clk); resync <= '0'; settle;
    if lock /= '0' then fail("T9 resync kept lock"); end if;
    if n_slip /= t0 then fail("T9 resync slipped"); end if;
    h('1', 64); settle;
    if lock /= '1' then fail("T9 no relock"); end if;

    if ok then report "TB_PCS_BLOCKSYNC_PASS" severity note;
    else report "TB_PCS_BLOCKSYNC_FAIL" severity note; end if;
    done <= true;
    wait;
  end process;
end architecture sim;
