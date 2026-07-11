-- tb_ptp_axil.vhd — verifica el wrapper AXI4-Lite del IP PTP.
-- Escribe CONTROL y SERVO por AXI, los lee de vuelta, dispara un Sync por CMD
-- en loopback y comprueba que STATUS refleja rx_sync. Valida la traduccion
-- AXI-Lite -> MMIO y el camino completo por el bus del SoC.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity tb_ptp_axil is
end entity;

architecture sim of tb_ptp_axil is
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal awaddr : std_logic_vector(15 downto 0) := (others => '0');
  signal awvalid, awready : std_logic := '0';
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := "1111";
  signal wvalid, wready : std_logic := '0';
  signal bresp : std_logic_vector(1 downto 0);
  signal bvalid, bready : std_logic := '0';
  signal araddr : std_logic_vector(15 downto 0) := (others => '0');
  signal arvalid, arready : std_logic := '0';
  signal rdata : std_logic_vector(31 downto 0);
  signal rresp : std_logic_vector(1 downto 0);
  signal rvalid, rready : std_logic := '0';
  signal irq : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;

  -- offsets de BYTE (palabra*4)
  constant CTRL:integer:=16#00#; constant SERVO:integer:=16#04#;
  constant CMD:integer:=16#0C#; constant STATUS:integer:=16#24#;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_axil
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (s_axi_aclk => clk, s_axi_aresetn => aresetn,
      s_axi_awaddr => awaddr, s_axi_awvalid => awvalid, s_axi_awready => awready,
      s_axi_wdata => wdata, s_axi_wstrb => wstrb, s_axi_wvalid => wvalid, s_axi_wready => wready,
      s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
      s_axi_araddr => araddr, s_axi_arvalid => arvalid, s_axi_arready => arready,
      s_axi_rdata => rdata, s_axi_rresp => rresp, s_axi_rvalid => rvalid, s_axi_rready => rready,
      irq => irq, mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => (others => '0'), mii_rx_dv => '0');

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;

    -- escritura AXI-Lite
    procedure axi_wr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      awaddr <= std_logic_vector(to_unsigned(a, 16));
      wdata <= d; awvalid <= '1'; wvalid <= '1'; bready <= '1';
      loop step; exit when awready = '1' and wready = '1'; end loop;
      awvalid <= '0'; wvalid <= '0';
      loop step; exit when bvalid = '1'; end loop;
      bready <= '0';
    end procedure;

    -- lectura AXI-Lite
    procedure axi_rd(a : integer; result : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, 16));
      arvalid <= '1'; rready <= '1';
      loop step; exit when arready = '1'; end loop;
      arvalid <= '0';
      loop step; exit when rvalid = '1'; end loop;
      result := rdata;
      rready <= '0';
    end procedure;

    variable v : std_logic_vector(31 downto 0);
  begin
    aresetn <= '0'; step; step; aresetn <= '1'; step;

    -- escribir CONTROL (loopback+enable) y leerlo de vuelta
    axi_wr(CTRL, x"00000006");
    axi_rd(CTRL, v);
    assert v = x"00000006"
      report "FALLO AXI CONTROL readback: " & to_hstring(v) severity failure;
    report "OK AXI escritura/lectura CONTROL = " & to_hstring(v);

    axi_wr(SERVO, x"00400010");
    axi_rd(SERVO, v);
    assert v = x"00400010" report "FALLO AXI SERVO readback" severity failure;
    report "OK AXI escritura/lectura SERVO = " & to_hstring(v);

    -- limpiar STATUS, disparar Sync, esperar y comprobar rx_sync
    axi_wr(STATUS, x"0000000F");
    axi_wr(CMD, x"00000001");
    for i in 1 to 4000 loop step; end loop;
    axi_rd(STATUS, v);
    assert v(0) = '1'
      report "FALLO: el Sync no armo rx_sync via AXI (STATUS=" & to_hstring(v) & ")" severity failure;
    report "OK AXI: Sync disparado, rx_sync armado (STATUS=" & to_hstring(v) & ")";

    report "=== PTP_AXIL: wrapper AXI4-Lite PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
