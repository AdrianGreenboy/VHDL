-- tb_pd_repeat.vhd — reproduccion del bug de fase del Pdelay.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;
entity tb_pd_repeat is
end entity;
architecture sim of tb_pd_repeat is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;
  signal role_slave : std_logic := '0';
  signal send_sync, start_pdelay : std_logic := '0';
  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);
  signal mpd_ns  : std_logic_vector(63 downto 0);
  signal mpd_valid : std_logic;
  signal offset_ns : std_logic_vector(ERR_W-1 downto 0);
  signal rate_adj : std_logic_vector(RATE_W-1 downto 0);
  signal dbg_rx_mvalid : std_logic;
  signal dbg_rx_mtype : std_logic_vector(3 downto 0);
  signal dbg_rx_seqid : std_logic_vector(15 downto 0);
  signal dbg_t1_ns, dbg_t4_ns : std_logic_vector(NS_W-1 downto 0);
  signal dbg_pd_corr : std_logic_vector(63 downto 0);
  signal dbg_pd_calc : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;
  constant CLOCK_ID : std_logic_vector(63 downto 0) := x"0011223344556677";
  constant PORT_NUM : std_logic_vector(15 downto 0) := x"0001";
  constant SRC_MAC  : std_logic_vector(47 downto 0) := x"02DECAFBADED";
  constant MACADDR  : std_logic_vector(47 downto 0) := x"0E0000C28001";
  signal mpd_count : integer := 0;   -- unico driver: el observador
begin
  clk <= not clk after TCK/2 when not done else '0';
  dut : entity work.ptp_mac
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, loopback => '1',
              role_slave => role_slave, clock_id => CLOCK_ID, port_num => PORT_NUM,
              src_mac => SRC_MAC, macaddr => MACADDR,
              kp => x"0040", ki => x"0010", tx_lat => x"0000", rx_lat => x"0000",
              send_sync => send_sync, start_pdelay => start_pdelay,
              now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns, mpd_valid => mpd_valid,
              offset_ns => offset_ns, rate_adj => rate_adj,
              dbg_rx_mvalid => dbg_rx_mvalid, dbg_rx_mtype => dbg_rx_mtype, dbg_rx_seqid => dbg_rx_seqid,
              dbg_t1_ns => dbg_t1_ns, dbg_t4_ns => dbg_t4_ns,
              dbg_pd_corr => dbg_pd_corr, dbg_pd_calc => dbg_pd_calc,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => (others => '0'), mii_rx_dv => '0');
  obs : process(clk)
  begin
    if rising_edge(clk) then
      if mpd_valid = '1' then mpd_count <= mpd_count + 1; end if;
    end if;
  end process;
  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    variable guard : integer;
    variable ok_count : integer := 0;
    variable fail_iter : integer := -1;
    variable base_count : integer;
  begin
    rst <= '1'; step; step; step; rst <= '0';
    for i in 1 to 30 loop step; end loop;
    for iter in 0 to 7 loop
      for p in 0 to iter loop step; end loop;
      base_count := mpd_count;   -- snapshot antes de disparar
      report ">>> iter " & integer'image(iter) & " (fase aprox " &
             integer'image(iter mod 4) & "): disparando start_pdelay";
      start_pdelay <= '1'; step; start_pdelay <= '0';
      guard := 0;
      while (mpd_count = base_count) and (guard < 5000) loop
        step; guard := guard + 1;
      end loop;
      if mpd_count > base_count then
        ok_count := ok_count + 1;
        report "    iter " & integer'image(iter) & ": mpd OK en " &
               integer'image(guard) & " ciclos, mpd=" &
               integer'image(to_integer(signed(mpd_ns))) & " ns";
      else
        if fail_iter < 0 then fail_iter := iter; end if;
        report "    iter " & integer'image(iter) &
               ": TIMEOUT - mpd NUNCA (fase " & integer'image(iter mod 4) & ")"
               severity warning;
      end if;
      for i in 1 to 40 loop step; end loop;
    end loop;
    report "=== RESULTADO: " & integer'image(ok_count) & "/8 iteraciones con mpd OK ===";
    if fail_iter >= 0 then
      report "BUG REPRODUCIDO: primera iteracion fallida = " &
             integer'image(fail_iter) severity note;
    else
      report "todas pasaron: el bug NO se reproduce variando fase asi";
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
