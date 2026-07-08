-- =============================================================================
--  tb_spi_engine.vhd  -  Valida el motor SPI en aislamiento (sin bus AXI)
--  Licencia: MIT
--
--  Tres grupos de pruebas:
--    A) Loopback (MISO <= MOSI): streams de 8 bytes back-to-back en los 4
--       modos con div=1 (SCLK = 50 MHz con clk = 100 MHz), LSB-first, div=4
--       y sample_late. Verifica rx == tx byte a byte y que el bus vuelve a
--       idle (CS alto, SCLK = CPOL).
--    B) Esclavo de comportamiento (modo 0 y modo 3, MSB primero): el esclavo
--       manda su propio patron por MISO y captura MOSI con la semantica de
--       flancos del estandar. Verifica la direccion ABSOLUTA de los flancos
--       (un error simetrico de muestreo pasaria el loopback pero no esto).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_engine is
end entity tb_spi_engine;

architecture sim of tb_spi_engine is
  constant TCK : time := 10 ns;   -- 100 MHz, como el SoC en el TE0950

  type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);
  constant PAT : byte_arr_t(0 to 7) :=
    (x"A5", x"3C", x"F0", x"0F", x"81", x"7E", x"00", x"FF");

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- configuracion
  signal cpol, cpha, lsb_first, sample_late : std_logic := '0';
  signal clkdiv : unsigned(15 downto 0) := to_unsigned(1, 16);

  -- streams
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid : std_logic := '0';
  signal tx_ready : std_logic;
  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal busy     : std_logic;

  -- bus SPI
  signal sclk, mosi, cs_n : std_logic;
  signal miso     : std_logic;
  signal miso_slv : std_logic := '0';

  -- esclavo de comportamiento
  signal use_slave : std_logic := '0';
  signal slv_tx    : std_logic_vector(7 downto 0) := x"96";  -- no palindromo
  signal slv_cap   : std_logic_vector(7 downto 0) := (others => '0');

  -- monitor de RX
  signal rxbuf  : byte_arr_t(0 to 15) := (others => (others => '0'));
  signal rxcnt  : natural := 0;
  signal rx_clr : std_logic := '0';
begin

  clk <= not clk after TCK/2;

  -- loopback por default; esclavo cuando use_slave = '1'
  miso <= miso_slv when use_slave = '1' else mosi;

  dut : entity work.spi_engine
    generic map (DIV_W => 16)
    port map (
      clk => clk, aresetn => aresetn,
      cpol => cpol, cpha => cpha, lsb_first => lsb_first,
      clkdiv => clkdiv, sample_late => sample_late,
      tx_data => tx_data, tx_valid => tx_valid, tx_ready => tx_ready,
      rx_data => rx_data, rx_valid => rx_valid, busy => busy,
      sclk_o => sclk, mosi_o => mosi, miso_i => miso, cs_n_o => cs_n
    );

  -- junta los bytes recibidos
  mon : process(clk)
  begin
    if rising_edge(clk) then
      if rx_clr = '1' then
        rxcnt <= 0;
      elsif rx_valid = '1' then
        rxbuf(rxcnt) <= rx_data;
        rxcnt <= rxcnt + 1;
      end if;
    end if;
  end process;

  -- esclavo SPI de comportamiento (un byte por asercion de CS, MSB primero)
  slave : process
    variable si : std_logic_vector(7 downto 0);
  begin
    wait until cs_n'event and cs_n = '0';
    if use_slave = '1' then
      si := (others => '0');
      if cpha = '0' then
        miso_slv <= slv_tx(7);            -- primer bit al bajar CS
      end if;
      for b in 0 to 7 loop
        if cpha = '0' then
          -- muestrea MOSI en el flanco lider, cambia MISO en la cola
          wait until sclk'event and sclk = (not cpol);
          si(7 - b) := mosi;
          if b < 7 then
            wait until sclk'event and sclk = cpol;
            miso_slv <= slv_tx(6 - b);
          end if;
        else
          -- presenta MISO en el flanco lider, muestrea MOSI en la cola
          wait until sclk'event and sclk = (not cpol);
          miso_slv <= slv_tx(7 - b);
          wait until sclk'event and sclk = cpol;
          si(7 - b) := mosi;
        end if;
      end loop;
      slv_cap <= si;
      wait until cs_n'event and cs_n = '1';
    end if;
  end process;

  stim : process
    -- manda n bytes back-to-back en loopback y verifica el eco
    procedure run_loopback(n : natural; msg : string) is
    begin
      rx_clr <= '1';
      wait until rising_edge(clk);
      rx_clr <= '0';
      wait until rising_edge(clk);

      tx_valid <= '1';
      for k in 0 to n - 1 loop
        tx_data <= PAT(k);
        wait until rising_edge(clk) and tx_ready = '1';
      end loop;
      tx_valid <= '0';

      wait until busy = '0';
      for i in 1 to 20 loop wait until rising_edge(clk); end loop;

      assert rxcnt = n
        report msg & ": rxcnt = " & integer'image(rxcnt)
               & ", esperaba " & integer'image(n)
        severity failure;
      for k in 0 to n - 1 loop
        assert rxbuf(k) = PAT(k)
          report msg & ": byte " & integer'image(k)
                 & " esperado " & to_hstring(PAT(k))
                 & " leido "    & to_hstring(rxbuf(k))
          severity failure;
      end loop;
      assert cs_n = '1' and sclk = cpol
        report msg & ": el bus no volvio a idle (CS/SCLK)"
        severity failure;
      report msg & " OK";
    end procedure;

    -- transferencia de 1 byte contra el esclavo de comportamiento
    procedure run_slave(msg : string) is
      constant TXB : std_logic_vector(7 downto 0) := x"D3";  -- no palindromo
    begin
      rx_clr <= '1';
      wait until rising_edge(clk);
      rx_clr <= '0';
      use_slave <= '1';
      wait until rising_edge(clk);

      tx_data  <= TXB;
      tx_valid <= '1';
      wait until rising_edge(clk) and tx_ready = '1';
      tx_valid <= '0';

      wait until busy = '0';
      for i in 1 to 20 loop wait until rising_edge(clk); end loop;

      assert rxcnt = 1
        report msg & ": rxcnt = " & integer'image(rxcnt) severity failure;
      assert rxbuf(0) = slv_tx
        report msg & ": RX esperado " & to_hstring(slv_tx)
               & " leido " & to_hstring(rxbuf(0))
        severity failure;
      assert slv_cap = TXB
        report msg & ": el esclavo capturo " & to_hstring(slv_cap)
               & ", esperaba " & to_hstring(TXB)
        severity failure;
      use_slave <= '0';
      report msg & " OK";
    end procedure;
  begin
    aresetn <= '0';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;
    aresetn <= '1';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- A) loopback: 4 modos, MSB primero, div=1 (SCLK = 50 MHz)
    clkdiv <= to_unsigned(1, 16); lsb_first <= '0'; sample_late <= '0';
    cpol <= '0'; cpha <= '0'; run_loopback(8, "loopback modo0 div1");
    cpol <= '0'; cpha <= '1'; run_loopback(8, "loopback modo1 div1");
    cpol <= '1'; cpha <= '0'; run_loopback(8, "loopback modo2 div1");
    cpol <= '1'; cpha <= '1'; run_loopback(8, "loopback modo3 div1");

    -- A) LSB primero
    lsb_first <= '1';
    cpol <= '0'; cpha <= '0'; run_loopback(8, "loopback modo0 lsb");
    cpol <= '1'; cpha <= '1'; run_loopback(8, "loopback modo3 lsb");
    lsb_first <= '0';

    -- A) divisor mas lento (SCLK = 12.5 MHz)
    clkdiv <= to_unsigned(4, 16);
    cpol <= '0'; cpha <= '0'; run_loopback(4, "loopback modo0 div4");
    cpol <= '1'; cpha <= '1'; run_loopback(4, "loopback modo3 div4");
    clkdiv <= to_unsigned(1, 16);

    -- A) muestreo retardado de MISO
    sample_late <= '1';
    cpol <= '0'; cpha <= '0'; run_loopback(8, "loopback modo0 late");
    cpol <= '1'; cpha <= '1'; run_loopback(8, "loopback modo3 late");
    sample_late <= '0';

    -- B) esclavo de comportamiento (direccion absoluta de los flancos)
    cpol <= '0'; cpha <= '0'; run_slave("esclavo modo0");
    cpol <= '1'; cpha <= '1'; run_slave("esclavo modo3");

    report "TEST PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
