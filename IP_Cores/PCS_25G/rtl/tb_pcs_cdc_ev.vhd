-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- tb_pcs_cdc_ev: dp -> AXI event crossing of pcs_cdc (audit 2026-11, M7).
--
-- Property (the AXI side only sets sticky bits, so events may COALESCE but
-- must never be LOST): after every input event an output pulse occurs that
-- is strictly later than the event, within a bounded latency; never more
-- output pulses than input events; no output without input.
-- The schedule mixes back-to-back events with gaps around the old
-- COOLDOWN_N (24 dp cycles) and long idles, for any clock ratio (generics):
-- the old toggle + cooldown lost events when clk_axi was slower than ~1/12
-- of clk_dp, or when two events were closer than the cooldown.
-- Prints TB_PCS_CDC_EV_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_cdc_ev is
  generic (TDP_PS : natural := 2560; TAXI_PS : natural := 25000);
end entity;

architecture sim of tb_pcs_cdc_ev is
  constant TDP  : time := TDP_PS * 1 ps;
  constant TAXI : time := TAXI_PS * 1 ps;
  constant TMAX : time := 8 * TAXI + 8 * TDP;       -- req + ack round trip
  signal clk_dp, clk_axi : std_logic := '0';
  signal rst_dp, rst_axi : std_logic := '1';
  signal ev, ev_o : std_logic := '0';
  signal done : boolean := false;
  signal n_in, n_out : natural := 0;
  signal pend : boolean := false;
  signal pend_t : time := 0 ns;
  signal last_in : time := 0 ns;
  signal bad_s : boolean := false;
  signal z32 : std_logic_vector(31 downto 0) := (others => '0');
begin
  clk_dp  <= not clk_dp  after TDP / 2  when not done;
  clk_axi <= not clk_axi after TAXI / 2 when not done;

  dut: entity work.pcs_cdc
    port map (clk_dp=>clk_dp, rst_dp=>rst_dp, clk_axi=>clk_axi, rst_axi=>rst_axi,
      dp_block_lock=>'0', dp_scr_sync=>'0', dp_prbs_lock=>'0', dp_hi_ber=>'0',
      dp_tx_active=>'0', dp_rx_active=>'0',
      axi_block_lock=>open, axi_scr_sync=>open, axi_prbs_lock=>open, axi_hi_ber=>open,
      axi_tx_active=>open, axi_rx_active=>open,
      dp_ev_lock_gained=>ev, dp_ev_lock_lost=>'0', dp_ev_hi_ber=>'0',
      dp_ev_rx_err=>'0', dp_ev_prbs_err=>'0',
      axi_ev_lock_gained=>ev_o, axi_ev_lock_lost=>open, axi_ev_hi_ber=>open,
      axi_ev_rx_err=>open, axi_ev_prbs_err=>open,
      axi_snap_req=>'0', dp_cnt_tx=>z32, dp_cnt_rx=>z32, dp_cnt_re=>z32,
      dp_cnt_be=>z32, dp_lock_t=>z32,
      axi_sh_tx=>open, axi_sh_rx=>open, axi_sh_re=>open, axi_sh_be=>open,
      axi_sh_lt=>open, axi_snap_done=>open);

  -- event source (dp domain)
  src: process
    type gaps_t is array (natural range <>) of natural;
    -- pairs / bursts of events, each followed by a long idle so that a later
    -- event can never "cover" a lost one
    constant GAPS : gaps_t := (5000, 1, 5000, 2, 5000, 5, 5000, 12, 5000, 23, 5000,
                               24, 5000, 25, 5000, 26, 5000, 30, 5000, 40, 5000,
                               60, 5000, 1, 1, 1, 5000, 3, 3, 5000);
  begin
    rst_dp <= '1';
    for i in 1 to 8 loop wait until rising_edge(clk_dp); end loop;
    rst_dp <= '0';
    for g in GAPS'range loop
      for i in 1 to GAPS(g) loop wait until rising_edge(clk_dp); end loop;
      ev <= '1'; wait until rising_edge(clk_dp); ev <= '0';
    end loop;
    wait;
  end process;

  process
  begin
    rst_axi <= '1';
    for i in 1 to 6 loop wait until rising_edge(clk_axi); end loop;
    rst_axi <= '0';
    wait;
  end process;

  -- input side bookkeeping (sampled on the dp edge that registers ev)
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if ev = '1' then
        n_in <= n_in + 1;
        last_in <= now;
      end if;
    end if;
  end process;

  -- output side: an output pulse covers every input event before it
  process(clk_axi)
  begin
    if rising_edge(clk_axi) then
      if ev_o = '1' then n_out <= n_out + 1; end if;
    end if;
  end process;

  chk: process
    variable covered_upto : time := 0 ns;
    variable first_unc    : time := 0 ns;
    variable unc          : boolean := false;
  begin
    loop
      wait until rising_edge(clk_dp) or rising_edge(clk_axi);
      if rising_edge(clk_dp) and ev = '1' then
        if not unc then unc := true; first_unc := now; end if;
      end if;
      if rising_edge(clk_axi) and ev_o = '1' then
        if n_in = 0 and not unc then
          report "output pulse without any input event" severity error; bad_s <= true;
        end if;
        -- the pulse covers all events registered before this instant
        if unc and first_unc < now then unc := false; end if;
      end if;
      if unc and now - first_unc > TMAX then
        report "event at " & time'image(first_unc) & " never reached the AXI side"
          severity error;
        bad_s <= true; unc := false;
      end if;
      exit when done;
    end loop;
    wait;
  end process;

  fin: process
  begin
    wait for 82000 * TDP + 300 * TAXI;   -- schedule (~80000 dp cycles) + drain
    if bad_s or n_out > n_in or n_out = 0 then
      report "TB_PCS_CDC_EV_FAIL in=" & integer'image(n_in) & " out=" & integer'image(n_out)
        severity note;
    else
      report "TB_PCS_CDC_EV_PASS in=" & integer'image(n_in) & " out=" & integer'image(n_out)
        severity note;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
