-- tb_tsn_tx_adapt.vhd - Capa 1a: fuente estilo-xbar -> tsn_tx_adapt ->
-- eth_tx_mii real -> eth_rx_mii real. Foco: ENVIOS CONSECUTIVOS espalda con
-- espalda respetando el back-pressure del adaptador (xbar_ready), con stalls
-- del lado xbar que vacian el skid a mitad de trama. El RX debe recuperar
-- TODAS las tramas intactas y en orden; un wire-watcher independiente verifica
-- que cada arranque de tx_en empieza con preambulo (0x5) y que hay exactamente
-- NF arranques (ni de menos por fantasma, ni de mas por armado espurio).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tsn_tx_adapt is
end entity;

architecture sim of tb_tsn_tx_adapt is
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal mii_ce : std_logic := '0';

  signal xbar_data : std_logic_vector(7 downto 0) := (others => '0');
  signal xbar_valid, xbar_last, xbar_ready : std_logic := '0';
  signal mii_data : std_logic_vector(7 downto 0);
  signal mii_valid, mii_last, mii_ready, mii_busy : std_logic;
  signal txd : std_logic_vector(3 downto 0);
  signal tx_en, underrun : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last, ev_ok, ev_crc, ev_runt, ev_drop : std_logic;

  constant NF : integer := 8;
  type lens_t is array (0 to NF-1) of integer;
  constant LENS : lens_t := (60, 60, 64, 60, 100, 60, 123, 60);

  type frm_t is array (0 to NF-1, 0 to 199) of integer;
  signal frm : frm_t;
  signal done_tx : boolean := false;

  function lfsr_next(s : unsigned(15 downto 0)) return unsigned is
  begin
    return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10));
  end;
begin
  clk <= not clk after 5 ns;

  p_ce : process(clk)
    variable d : integer := 0;
  begin
    if rising_edge(clk) then
      if d = 3 then mii_ce <= '1'; d := 0; else mii_ce <= '0'; d := d + 1; end if;
    end if;
  end process;

  adapt : entity work.tsn_tx_adapt
    port map (clk => clk, rst => rst,
      xbar_data => xbar_data, xbar_valid => xbar_valid, xbar_last => xbar_last,
      xbar_ready => xbar_ready,
      mii_data => mii_data, mii_valid => mii_valid, mii_last => mii_last,
      mii_ready => mii_ready, mii_busy => mii_busy);

  tx : entity work.eth_tx_mii
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      tx_data => mii_data, tx_valid => mii_valid, tx_last => mii_last,
      tx_ready => mii_ready, tx_busy => mii_busy, underrun => underrun,
      txd => txd, tx_en => tx_en);

  rx : entity work.eth_rx_mii
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      macaddr => x"000000000000", promisc => '1',
      rxd => txd, rx_dv => tx_en,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      ev_ok => ev_ok, ev_crc => ev_crc, ev_runt => ev_runt, ev_drop => ev_drop);

  p_feed : process
    variable s : unsigned(15 downto 0) := x"3C3C";
  begin
    wait for 30 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    for f in 0 to NF-1 loop
      for kk in 0 to LENS(f)-1 loop
        if kk = 0 then frm(f,kk) <= 16#A0# + f;
        elsif kk = 1 then frm(f,kk) <= f;
        else s := lfsr_next(s); frm(f,kk) <= to_integer(s(7 downto 0)); end if;
      end loop;
      wait until rising_edge(clk);
      for kk in 0 to LENS(f)-1 loop
        -- stall pseudoaleatorio ANTES de presentar: hueco con valid=0
        s := lfsr_next(s);
        if s(2 downto 0) = "000" then
          xbar_valid <= '0';
          for w in 1 to 1 + to_integer(s(5 downto 3)) loop
            wait until rising_edge(clk);
          end loop;
        end if;
        xbar_data  <= std_logic_vector(to_unsigned(frm(f,kk), 8));
        xbar_valid <= '1';
        xbar_last  <= '1' when kk = LENS(f)-1 else '0';
        loop
          wait until rising_edge(clk);
          exit when xbar_ready = '1';
        end loop;
      end loop;
      xbar_valid <= '0'; xbar_last <= '0';
    end loop;
    done_tx <= true;
    wait;
  end process;

  -- wire-watcher independiente del MII: no comparte estado con el datapath.
  p_watch : process
    variable prev_en : std_logic := '0';
    variable starts  : integer := 0;
    variable innib   : integer := 0;
  begin
    wait until rst = '0';
    loop
      wait until rising_edge(clk);
      exit when done_tx and mii_busy = '0';
      if mii_ce = '1' then
        if tx_en = '1' and prev_en = '0' then
          starts := starts + 1;
          assert txd = x"5"
            report "arranque " & integer'image(starts) &
                   ": primer nibble no es preambulo 0x5 (fantasma?)"
            severity failure;
          innib := 1;
        elsif tx_en = '1' then
          innib := innib + 1;
        end if;
        prev_en := tx_en;
      end if;
    end loop;
    assert starts = NF
      report "wire-watcher: arranques=" & integer'image(starts) &
             " esperados=" & integer'image(NF) &
             " (fantasma o armado espurio)" severity failure;
    report "wire-watcher: arranques limpios=" & integer'image(starts)
      severity note;
    wait;
  end process;

  p_check : process
    variable k    : integer := 0;
    variable nfrm : integer := 0;
    variable cur  : integer := 0;
    variable hash : unsigned(31 downto 0) := (others => '0');
  begin
    wait until rst = '0';
    loop
      wait until rising_edge(clk);
      if rx_valid = '1' then
        if k = 0 then
          cur := to_integer(unsigned(rx_data)) - 16#A0#;
          assert cur >= 0 and cur < NF
            report "id de trama fuera de rango" severity failure;
          assert cur = nfrm
            report "orden roto: llego trama " & integer'image(cur)
                   & " esperaba " & integer'image(nfrm) severity failure;
        end if;
        assert to_integer(unsigned(rx_data)) = frm(cur, k)
          report "trama " & integer'image(cur) & " byte " & integer'image(k)
                 & ": rx=" & integer'image(to_integer(unsigned(rx_data)))
                 & " esp=" & integer'image(frm(cur, k)) severity failure;
        hash := resize(hash * 33, 32) xor to_unsigned(frm(cur,k), 32);
        k := k + 1;
        if rx_last = '1' then
          assert k = LENS(cur)
            report "trama " & integer'image(cur) & " len " & integer'image(k)
                   & " /= " & integer'image(LENS(cur)) severity failure;
          nfrm := nfrm + 1;
          k := 0;
        end if;
      end if;
      if done_tx and nfrm = NF then exit; end if;
    end loop;
    assert ev_crc = '0' and ev_runt = '0'
      report "evento de error inesperado" severity failure;
    report "tx_adapt: tramas_ok=" & integer'image(nfrm) &
           " hash=" & integer'image(to_integer(hash(30 downto 0)));
    report "TB_TSN_TX_ADAPT PASS" severity note;
    std.env.finish;
  end process;
end architecture;
