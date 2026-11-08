-- ============================================================================
-- tb_spw_4.vhd -- codec A <-> codec B at 400 Mbit/s (audit 2026-11)
-- ============================================================================
-- Both codecs with G_RX_MODE = 1 (Data-Strobe clock recovery) and
-- G_TX_CLK = 1 (transmitter on a dedicated tx_clk through spw_tx_cdc).
-- Four unrelated clocks: sysA 100 MHz, sysB 97 MHz, txA 400 MHz,
-- txB 404 MHz. Wire: transport delays with D/S skew (A->B S +0.3 ns,
-- B->A D +0.35 ns). The link starts at 10 Mbit/s (div = 40) as ECSS
-- requires, then both sides switch to div = 1 (400 / 404 Mbit/s) in Run.
--   P1 link to Run at 10 Mbit/s
--   P2 rate switch to 400 Mbit/s; link stays in Run
--   P3 600 N-Chars each way (random bytes, EOP every 37) checked in order
--   P4 time-code A -> B
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spw_4 is
end entity tb_spw_4;

architecture sim of tb_spw_4 is

  constant N_CH : integer := 600;

  signal clka, clkb, txca, txcb : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '0';
  signal diva, divb : std_logic_vector(7 downto 0) := x"28";   -- 40

  signal tick_a, tick_b, tko_a, tko_b : std_logic := '0';
  signal tin_a, tin_b, tout_a, tout_b : std_logic_vector(7 downto 0) := (others => '0');
  signal txv_a, txv_b, txk_a, txk_b, rxw_a, rxw_b : std_logic := '0';
  signal txd_a, txd_b, rxd_a, rxd_b : std_logic_vector(8 downto 0) := (others => '0');
  signal st_a, st_b : std_logic_vector(2 downto 0);
  signal ep_a, ee_a, ed_a, ec_a, ep_b, ee_b, ed_b, ec_b : std_logic;
  signal da, sa, db, sb : std_logic;            -- outputs
  signal da_w, sa_w, db_w, sb_w : std_logic := '0'; -- after the wire

  type chars_t is array (0 to N_CH - 1) of std_logic_vector(8 downto 0);
  function mkseq(seed0 : integer) return chars_t is
    variable r : chars_t;
    variable x : unsigned(31 downto 0) := to_unsigned(seed0, 32);
  begin
    for i in 0 to N_CH - 1 loop
      x := resize(x * to_unsigned(1103515245, 32), 32) + 12345;
      if i mod 37 = 36 then
        r(i) := "100000000";                 -- EOP
      else
        r(i) := '0' & std_logic_vector(x(23 downto 16));
      end if;
    end loop;
    return r;
  end function;
  constant SEQ_A : chars_t := mkseq(7);
  constant SEQ_B : chars_t := mkseq(1234);

  signal ia, ib, ra, rb : integer := 0;        -- sent / received indices
  signal go_data : boolean := false;
  signal n_err : integer := 0;
  signal n_tick_b : integer := 0;

  constant S_RUN : std_logic_vector(2 downto 0) := "101";

begin

  clka <= not clka after 5 ns;
  clkb <= not clkb after 5.155 ns;               -- ~97 MHz
  txca <= not txca after 1.25 ns;                -- 400 MHz
  txcb <= not txcb after 1.2376 ns;              -- ~404 MHz

  -- wire with skew
  da_w <= transport da after 1.0 ns;
  sa_w <= transport sa after 1.3 ns;
  db_w <= transport db after 1.35 ns;
  sb_w <= transport sb after 1.0 ns;

  u_a : entity work.spw_codec
    generic map (G_RX_MODE => 1, G_TX_CLK => 1)
    port map (
      clk => clka, tx_clk => txca, rst => rst, en => en, div => diva,
      link_start => '1', link_autostart => '0', link_disable => '0',
      tick_in => tick_a, time_in => tin_a, tick_out => tko_a, time_out => tout_a,
      tx_valid => txv_a, tx_data => txd_a, tx_ack => txk_a,
      rx_we => rxw_a, rx_data => rxd_a, rx_room => "1111111",
      state => st_a, err_par => ep_a, err_esc => ee_a, err_disc => ed_a,
      err_credit => ec_a,
      din => db_w, sin => sb_w, dout => da, sout => sa);

  u_b : entity work.spw_codec
    generic map (G_RX_MODE => 1, G_TX_CLK => 1)
    port map (
      clk => clkb, tx_clk => txcb, rst => rst, en => en, div => divb,
      link_start => '0', link_autostart => '1', link_disable => '0',
      tick_in => tick_b, time_in => tin_b, tick_out => tko_b, time_out => tout_b,
      tx_valid => txv_b, tx_data => txd_b, tx_ack => txk_b,
      rx_we => rxw_b, rx_data => rxd_b, rx_room => "1111111",
      state => st_b, err_par => ep_b, err_esc => ee_b, err_disc => ed_b,
      err_credit => ec_b,
      din => da_w, sin => sa_w, dout => db, sout => sb);

  -- sources (advance on tx_ack)
  txd_a <= SEQ_A(ia) when ia < N_CH else (others => '0');
  txv_a <= '1' when go_data and ia < N_CH else '0';
  txd_b <= SEQ_B(ib) when ib < N_CH else (others => '0');
  txv_b <= '1' when go_data and ib < N_CH else '0';

  pa : process (clka)
  begin
    if rising_edge(clka) then
      if txk_a = '1' then ia <= ia + 1; end if;
      if rxw_a = '1' then
        assert rb < N_CH and rxd_a = SEQ_B(rb)
          report "FALLO: A recibio un caracter incorrecto en " & integer'image(rb)
          severity failure;
        rb <= rb + 1;
      end if;
    end if;
  end process;

  pb : process (clkb)
  begin
    if rising_edge(clkb) then
      if txk_b = '1' then ib <= ib + 1; end if;
      if rxw_b = '1' then
        assert ra < N_CH and rxd_b = SEQ_A(ra)
          report "FALLO: B recibio un caracter incorrecto en " & integer'image(ra)
          severity failure;
        ra <= ra + 1;
      end if;
      if tko_b = '1' then
        n_tick_b <= n_tick_b + 1;
        assert tout_b = x"21" report "FALLO: time-code en B" severity failure;
      end if;
    end if;
  end process;

  errs : process (ep_a, ee_a, ed_a, ec_a, ep_b, ee_b, ed_b, ec_b)
  begin
    if go_data then
      assert (ep_a or ee_a or ed_a or ec_a or ep_b or ee_b or ed_b or ec_b) /= '1'
        report "FALLO: error de enlace durante la transferencia" severity failure;
    end if;
  end process;

  stim : process
  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clka);
    rst <= '0';
    en  <= '1';
    -- P1
    report "P1: arranque a 10 Mbit/s";
    wait until st_a = S_RUN and st_b = S_RUN for 400 us;
    assert st_a = S_RUN and st_b = S_RUN
      report "FALLO: P1 los enlaces no alcanzan Run" severity failure;
    wait for 20 us;
    -- P2
    report "P2: cambio a 400 Mbit/s";
    diva <= x"01";
    divb <= x"01";
    wait for 20 us;
    assert st_a = S_RUN and st_b = S_RUN
      report "FALLO: P2 enlace caido tras el cambio de tasa" severity failure;
    -- P3
    report "P3: 600 N-Chars en cada sentido a 400 Mbit/s";
    go_data <= true;
    wait until ra = N_CH and rb = N_CH for 200 us;
    assert ra = N_CH and rb = N_CH
      report "FALLO: P3 recibidos A->B " & integer'image(ra) & " B->A "
             & integer'image(rb) severity failure;
    -- P4
    report "P4: time-code A -> B";
    wait until rising_edge(clka);
    tin_a <= x"21"; tick_a <= '1';
    wait until rising_edge(clka);
    tick_a <= '0';
    wait for 5 us;
    assert n_tick_b = 1 report "FALLO: P4 time-code no recibido" severity failure;
    assert st_a = S_RUN and st_b = S_RUN
      report "FALLO: enlace fuera de Run al final" severity failure;
    report "CAPA 4 SPW PASS: codec a 400 Mbit/s con tx_clk y reloj recuperado";
    finish;
  end process;

end architecture sim;
