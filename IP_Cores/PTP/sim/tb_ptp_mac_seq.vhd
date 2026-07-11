-- tb_ptp_mac_seq.vhd — regresion del bug de estado residual: Sync -> Pdelay.
-- El peer-delay tras un Sync previo debe dar mpd=40 (residence correcto). El
-- bug era una carrera en el parser: msg_valid del mensaje anterior combinado
-- con mtype/rx_ns de la trama en curso -> t2 corrupto -> residence erroneo.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_ptp_mac_seq is
end entity;

architecture sim of tb_ptp_mac_seq is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal role_slave, send_sync, start_pdelay : std_logic := '0';
  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);
  signal mpd_ns  : std_logic_vector(63 downto 0);
  signal mpd_valid, offset_valid_o, rx_sync_ev, rx_resp_ev : std_logic;
  signal offset_ns : std_logic_vector(ERR_W-1 downto 0);
  signal rate_adj : std_logic_vector(RATE_W-1 downto 0);
  signal dbg_t1_ns, dbg_t4_ns : std_logic_vector(NS_W-1 downto 0);
  signal dbg_pd_corr : std_logic_vector(63 downto 0);
  signal dbg_pd_calc : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_mac
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, loopback => '1', role_slave => role_slave,
      clock_id => x"0011223344556677", port_num => x"0001", src_mac => x"02DECAFBADED",
      macaddr => x"0E0000C28001", kp => x"0040", ki => x"0010",
      tx_lat => x"0000", rx_lat => x"0000",
      send_sync => send_sync, start_pdelay => start_pdelay,
      now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns, mpd_valid => mpd_valid,
      offset_valid_o => offset_valid_o, rx_sync_ev => rx_sync_ev, rx_resp_ev => rx_resp_ev,
      offset_ns => offset_ns, rate_adj => rate_adj,
      dbg_rx_mvalid => open, dbg_rx_mtype => open, dbg_rx_seqid => open,
      dbg_t1_ns => dbg_t1_ns, dbg_t4_ns => dbg_t4_ns,
      dbg_pd_corr => dbg_pd_corr, dbg_pd_calc => dbg_pd_calc,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => (others => '0'), mii_rx_dv => '0');

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    variable got_mpd : boolean := false;
  begin
    rst <= '1'; step; step; step; rst <= '0';
    for i in 1 to 30 loop step; end loop;

    -- Sync primero (crea el estado que antes corrompia el t2)
    send_sync <= '1'; step; send_sync <= '0';
    for i in 1 to 4000 loop step; end loop;

    -- peer-delay despues: debe dar mpd=40 (no corrompido por el Sync)
    start_pdelay <= '1'; step; start_pdelay <= '0';
    for i in 1 to 6000 loop
      step;
      if mpd_valid = '1' then
        got_mpd := true;
        step;
        assert to_integer(signed(mpd_ns)) = 40
          report "FALLO: mpd=" & integer'image(to_integer(signed(mpd_ns))) &
                 " esperado 40 (residence corrompido tras Sync)" severity failure;
        report "OK Sync->Pdelay: meanPathDelay=40 (t2 correcto tras el fix de la carrera)";
      end if;
    end loop;

    assert got_mpd report "FALLO: no se calculo mpd tras Sync" severity failure;
    report "=== PTP_MAC_SEQ: Sync->Pdelay mpd=40 PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
