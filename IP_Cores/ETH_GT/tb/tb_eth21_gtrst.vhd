-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Capa 1D: secuencia de reset del GT (eth21_gt_rst) contra un modelo de
-- estado del quad. ACLK_HZ = 1 MHz -> T_TMO = 10000 ciclos.
--   SCN 0: arranque normal: tx_ready y rx_ready, sin reinicios
--   SCN 1: el RX nunca termina (sin cable): tx_ready sube y NO vuelve a caer,
--          el PLL no se vuelve a resetear, rxmstreset se reintenta solo
--   SCN 2: cae el lock del PLL en servicio: reinicio completo y recuperacion
--   SCN 3: el reloj de usuario de TX no corre: txuserrdy nunca sube; RX ok
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity tb_eth21_gtrst is
  generic (SCN : natural := 0);
end entity tb_eth21_gtrst;

architecture sim of tb_eth21_gtrst is
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal pll, txm, rxm, txu, rxu, txr, rxr : std_logic;
  signal lock, txd, rxd : std_logic := '0';
  signal pll_kill : std_logic := '0';
  signal st : std_logic_vector(3 downto 0);
  signal txa, rxa : std_logic := '1';
  signal n_txr_fall, n_pll_rise, n_rxm_rise, n_txr_rise, n_rxr_rise : natural := 0;
  signal txr_d, rxr_d : std_logic := '0';
  signal pll_d, rxm_d : std_logic := '1';   -- arrancan en reset
begin
  clk <= not clk after 20 ns when not fin;

  -- modelo del quad
  process
  begin
    loop
      wait until pll = '0' and pll_kill = '0';
      wait for 2 us;
      if pll = '0' and pll_kill = '0' then lock <= '1'; end if;
      wait until pll = '1' or pll_kill = '1';
      lock <= '0';
    end loop;
  end process;
  process(clk)
    variable ct, cr : natural := 0;
  begin
    if rising_edge(clk) then
      if txm = '1' or txu = '0' or lock = '0' then ct := 0; txd <= '0';
      elsif ct < 50 then ct := ct + 1; else txd <= '1'; end if;
      if SCN = 1 then
        rxd <= '0';
      elsif rxm = '1' or rxu = '0' or lock = '0' then cr := 0; rxd <= '0';
      elsif cr < 70 then cr := cr + 1; else rxd <= '1'; end if;
    end if;
  end process;
  txa <= '0' when SCN = 3 else '1';

  u: entity work.eth21_gt_rst
    generic map (ACLK_HZ => 1_000_000)
    port map (clk=>clk, rst=>'0', restart=>'0', manual=>'0', man_pllrst=>'0',
              man_txmst=>'0', man_rxmst=>'0', man_txusr=>'0', man_rxusr=>'0',
              gtpowergood=>'1', lcplllock=>lock, txmstdone=>txd, rxmstdone=>rxd,
              tx_alive=>txa, rx_alive=>rxa,
              lcpllreset=>pll, txmstreset=>txm, rxmstreset=>rxm, txuserrdy=>txu,
              rxuserrdy=>rxu, tx_ready=>txr, rx_ready=>rxr, state=>st,
              s_pg=>open, s_lock=>open, s_txd=>open, s_rxd=>open);

  process(clk)
  begin
    if rising_edge(clk) then
      txr_d <= txr; pll_d <= pll; rxm_d <= rxm; rxr_d <= rxr;
      if txr_d = '1' and txr = '0' then n_txr_fall <= n_txr_fall + 1; end if;
      if txr_d = '0' and txr = '1' then n_txr_rise <= n_txr_rise + 1; end if;
      if rxr_d = '0' and rxr = '1' then n_rxr_rise <= n_rxr_rise + 1; end if;
      if pll_d = '0' and pll = '1' then n_pll_rise <= n_pll_rise + 1; end if;
      if rxm_d = '0' and rxm = '1' then n_rxm_rise <= n_rxm_rise + 1; end if;
    end if;
  end process;

  process
    variable e : natural := 0;
    procedure expect(c : boolean; m : string) is
    begin
      if not c then report "FALLO SCN" & integer'image(SCN) & ": " & m severity error; e := e + 1; end if;
    end procedure;
  begin
    case SCN is
      when 0 =>
        wait for 200 us;
        expect(txr = '1' and rxr = '1', "no listos");
        expect(n_txr_fall = 0 and n_pll_rise = 0 and n_rxm_rise = 0, "reinicios espurios");
        expect(st = "1111", "estado " );
      when 1 =>
        wait for 1500 us;          -- > 3 timeouts de 400 us
        expect(txr = '1', "tx_ready no esta a 1");
        expect(n_txr_fall = 0, "tx_ready cayo " & integer'image(n_txr_fall) & " veces");
        expect(n_pll_rise = 0, "PLL reseteado " & integer'image(n_pll_rise) & " veces");
        expect(n_rxm_rise >= 2, "rxmstreset reintentado solo " & integer'image(n_rxm_rise) & " veces");
        expect(rxr = '0', "rx_ready sin rxmstresetdone");
      when 2 =>
        wait for 200 us;
        expect(txr = '1' and rxr = '1', "no listos antes del fallo");
        pll_kill <= '1'; wait for 20 us; pll_kill <= '0';
        wait for 5 us;
        expect(n_pll_rise = 1, "sin reinicio del PLL");
        expect(txr = '0' and rxr = '0', "ready no caen con el PLL");
        wait for 300 us;
        expect(txr = '1' and rxr = '1', "sin recuperacion tras el PLL");
        expect(n_txr_rise = 2 and n_rxr_rise = 2, "subidas de ready");
      when others =>
        wait for 1000 us;
        expect(txu = '0' and txr = '0', "TX listo sin reloj de usuario");
        expect(rxr = '1', "RX afectado por el TX");
        expect(n_pll_rise = 0, "PLL reseteado por el TX");
    end case;
    if e = 0 then report "LAYER1D GTRST SCN" & integer'image(SCN) & " PASS";
    else report "LAYER1D GTRST SCN" & integer'image(SCN) & " FAIL" severity error; end if;
    fin <= true; wait;
  end process;
end architecture sim;
