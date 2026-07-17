-- tb_datapath.vhd - Verifica rf_datapath con tone_ftw=0 (banda base DC 29491).
-- Carga coeficientes passthrough del FIR RX, habilita rx, y captura 64 muestras
-- de la RX FIFO por el puerto de lectura. Calcula el checksum canonico y lo
-- compara con el golden 0xB74940EB del modelo Python.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_datapath is
end entity tb_datapath;

architecture sim of tb_datapath is
  constant C_TCLK : time := 10 ns;
  constant FTW_RX : std_logic_vector(31 downto 0) := x"0293A800";
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal rx_en : std_logic := '0';
  signal coef_we : std_logic := '0';
  signal coef_addr : std_logic_vector(3 downto 0) := (others=>'0');
  signal coef_data : std_logic_vector(15 downto 0) := (others=>'0');
  signal rssi : std_logic_vector(15 downto 0);
  signal rd_en : std_logic := '0';
  signal rd_data : std_logic_vector(31 downto 0);
  signal empty, full : std_logic;
  signal level : std_logic_vector(9 downto 0);
  signal fin : boolean := false;
begin
  clk <= '0' when fin else not clk after C_TCLK/2;

  dut : entity work.rf_datapath
    port map (clk_i=>clk, aresetn_i=>aresetn, rx_en_i=>rx_en,
              ftw_i=>FTW_RX, tone_ftw_i=>x"00000000",
              coef_we_i=>coef_we, coef_addr_i=>coef_addr, coef_data_i=>coef_data,
              rssi_o=>rssi, rxf_rd_en_i=>rd_en, rxf_rd_data_o=>rd_data,
              rxf_empty_o=>empty, rxf_full_o=>full, rxf_level_o=>level);

  proc : process
    variable chk : unsigned(31 downto 0) := (others=>'0');
    variable w : std_logic_vector(31 downto 0);
    variable n : integer := 0;
    constant GOLDEN : std_logic_vector(31 downto 0) := x"B74940EB";
  begin
    aresetn <= '0';
    wait for 3*C_TCLK;
    aresetn <= '1';
    wait until rising_edge(clk);
    -- cargar coeficientes passthrough: tap0 = 0x7FFF, tap1..15 = 0
    coef_addr <= x"0"; coef_data <= x"7FFF"; coef_we <= '1';
    wait until rising_edge(clk);
    coef_we <= '0';
    for k in 1 to 15 loop
      coef_addr <= std_logic_vector(to_unsigned(k,4)); coef_data <= x"0000"; coef_we <= '1';
      wait until rising_edge(clk);
      coef_we <= '0';
      wait until rising_edge(clk);
    end loop;
    -- habilitar rx
    rx_en <= '1';
    -- capturar 64 muestras
    while n < 64 loop
      wait until rising_edge(clk);
      if empty = '0' then
        w := rd_data;
        rd_en <= '1';
        wait until rising_edge(clk);
        rd_en <= '0';
        chk := (chk(30 downto 0) & chk(31)) xor unsigned(w);
        n := n + 1;
      end if;
    end loop;
    if std_logic_vector(chk) = GOLDEN then
      report "FIN SIMULACION DATAPATH: PASS CHK=0x"&to_hstring(chk)&" N=64 @ "&time'image(now) severity note;
    else
      report "FIN SIMULACION DATAPATH: FAIL CHK=0x"&to_hstring(chk)&" esp=0x"&to_hstring(GOLDEN) severity error;
    end if;
    fin <= true;
    wait;
  end process;
end architecture sim;
