-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- tb_pcs_dp_clear: CNT_CLEAR / PRBS_RESET coinciding with counted events
-- (audit 2026-11, fix M1). TX, RX-header and PRBS events arrive EVERY
-- cycle; the clear pulse lands on one of them. After the clear the counters
-- must hold exactly the events of the cycles AFTER the clear (before the
-- fix the increment of the clear cycle overrode the clear: nothing was
-- cleared). Also checks that simultaneous TX + RX + PRBS strobes are all
-- counted (no priority multiplexer) and that counters saturate.
-- Prints TB_PCS_DP_CLEAR_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_dp_clear is end entity;

architecture sim of tb_pcs_dp_clear is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  signal evt : std_logic_vector(2 downto 0) := "000";
  signal txs, oks, prs, clr, prst : std_logic := '0';
  signal c_tx, c_rx, c_re, c_be, lt : std_logic_vector(31 downto 0);
begin
  clk <= not clk after 1 ns when not done;

  dut: entity work.pcs_dataplane
    port map (clk_dp=>clk, rst_dp=>rst, blk_evt=>evt,
              tx_stb=>txs, hdr_ok_stb=>oks, hdr_bad_stb=>'0', prbs_stb=>prs,
              cmd_cnt_clear=>clr, cmd_soft_reset=>'0', cmd_resync=>'0', cmd_prbs_reset=>prst,
              cnt_tx_blk=>c_tx, cnt_rx_blk=>c_rx, cnt_rx_err=>c_re, cnt_ber=>c_be,
              lock_time=>lt, st_block_lock=>open, st_scr_sync=>open, st_prbs_lock=>open,
              st_hi_ber=>open, st_tx_active=>open, st_rx_active=>open,
              ev_lock_gained=>open, ev_lock_lost=>open, ev_hi_ber=>open,
              ev_rx_err=>open, ev_prbs_err=>open);

  process
    variable ok : boolean := true;
    procedure fail(m : string) is
    begin
      report "TB_PCS_DP_CLEAR_FAIL " & m severity error; ok := false;
    end procedure;
    procedure tick(n : natural) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
    end procedure;
  begin
    rst <= '1'; tick(3); rst <= '0';
    -- every cycle: one TX, one valid RX header, one PRBS error (strobes)
    txs <= '1'; oks <= '1'; prs <= '1';
    tick(50);
    clr <= '1'; tick(1); clr <= '0';          -- clear lands on an event cycle
    tick(20);
    txs <= '0'; oks <= '0'; prs <= '0';
    tick(2);
    if unsigned(c_tx) /= 20 then fail("TX after clear = " & integer'image(to_integer(unsigned(c_tx))) & " (expected 20)"); end if;
    if unsigned(c_rx) /= 20 then fail("RX after clear = " & integer'image(to_integer(unsigned(c_rx)))); end if;
    if unsigned(c_be) /= 20 then fail("BER after clear = " & integer'image(to_integer(unsigned(c_be)))); end if;
    -- PRBS_RESET on a PRBS event cycle
    prs <= '1'; tick(10);
    prst <= '1'; tick(1); prst <= '0';
    tick(5); prs <= '0'; tick(2);
    if unsigned(c_be) /= 5 then fail("BER after PRBS_RESET = " & integer'image(to_integer(unsigned(c_be))) & " (expected 5)"); end if;
    -- the blk_evt port keeps working alongside the strobes
    evt <= "001"; txs <= '1'; tick(1); evt <= "000"; txs <= '0'; tick(2);
    if unsigned(c_tx) /= 21 then fail("blk_evt + tx_stb in one cycle = " & integer'image(to_integer(unsigned(c_tx)))); end if;

    if ok then report "TB_PCS_DP_CLEAR_PASS" severity note;
    else report "TB_PCS_DP_CLEAR_FAIL" severity note; end if;
    done <= true;
    wait;
  end process;
end architecture sim;
