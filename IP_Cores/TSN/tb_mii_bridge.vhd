-- tb_mii_bridge.vhd - Riesgo aislado: envios CONSECUTIVOS por el eth_tx_mii
-- real, con su salida MII cableada al eth_rx_mii real (patron LOOP_INT).
-- Prototipo del riesgo del adaptador: confirma que el motor TX arranca envios
-- espalda-con-espalda si se respeta tx_busy. Referencia historica del
-- fantasma del PTP (segundo envio consecutivo del motor TX).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mii_bridge is
end entity;

architecture sim of tb_mii_bridge is
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal mii_ce : std_logic := '0';

  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid, tx_last, tx_ready, tx_busy, underrun : std_logic := '0';
  signal txd : std_logic_vector(3 downto 0);
  signal tx_en : std_logic;

  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last, ev_ok, ev_crc, ev_runt, ev_drop : std_logic;

  constant NF : integer := 5;
  type lens_t is array (0 to NF-1) of integer;
  constant LENS : lens_t := (60, 64, 60, 123, 60);

  type frm_t is array (0 to 4, 0 to 199) of integer;
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

  tx : entity work.eth_tx_mii
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready, tx_busy => tx_busy, underrun => underrun,
      txd => txd, tx_en => tx_en);

  rx : entity work.eth_rx_mii
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      macaddr => x"000000000000", promisc => '1',
      rxd => txd, rx_dv => tx_en,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      ev_ok => ev_ok, ev_crc => ev_crc, ev_runt => ev_runt, ev_drop => ev_drop);

  p_feed : process
    variable s : unsigned(15 downto 0) := x"5A5A";
  begin
    wait for 30 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    for f in 0 to NF-1 loop
      for k in 0 to LENS(f)-1 loop
        if k = 0 then frm(f,k) <= 16#A0# + f;
        elsif k = 1 then frm(f,k) <= f;
        else s := lfsr_next(s); frm(f,k) <= to_integer(s(7 downto 0)); end if;
      end loop;
      wait until rising_edge(clk);
      while tx_busy = '1' loop wait until rising_edge(clk); end loop;
      for k in 0 to LENS(f)-1 loop
        tx_data  <= std_logic_vector(to_unsigned(frm(f,k), 8));
        tx_valid <= '1';
        tx_last  <= '1' when k = LENS(f)-1 else '0';
        loop
          wait until rising_edge(clk);
          exit when tx_ready = '1';
        end loop;
      end loop;
      tx_valid <= '0'; tx_last <= '0';
    end loop;
    done_tx <= true;
    wait;
  end process;

  p_check : process
    variable k : integer := 0;
    variable nfrm : integer := 0;
    variable cur  : integer := 0;
  begin
    wait until rst = '0';
    loop
      wait until rising_edge(clk);
      if rx_valid = '1' then
        if k = 0 then
          cur := to_integer(unsigned(rx_data)) - 16#A0#;
          assert cur >= 0 and cur < NF
            report "id de trama fuera de rango" severity failure;
        end if;
        assert to_integer(unsigned(rx_data)) = frm(cur, k)
          report "trama " & integer'image(cur) & " byte " & integer'image(k)
                 severity failure;
        k := k + 1;
        if rx_last = '1' then
          assert k = LENS(cur)
            report "trama " & integer'image(cur) & " len mal" severity failure;
          nfrm := nfrm + 1;
          k := 0;
        end if;
      end if;
      if done_tx and nfrm = NF then exit; end if;
    end loop;
    assert ev_crc = '0' and ev_runt = '0'
      report "evento de error inesperado" severity failure;
    report "mii_bridge: tramas_ok=" & integer'image(nfrm) severity note;
    report "TB_MII_BRIDGE PASS" severity note;
    std.env.finish;
  end process;
end architecture;
