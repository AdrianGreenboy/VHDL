-- tb_ptp_axil_master.vhd — cadena completa lado-core:
--   (core emulado, protocolo dmem con stall) -> ptp_axil_master -> ptp_axil -> ptp_top
--
-- Verifica ESPECIFICAMENTE la firma del bug de silicio (corrimiento de una
-- transaccion en lecturas):
--   A1  readback inmediato de CONTROL == 0x6      (DIAG0 fallaba: leia 0)
--   A2  NOW_NS es multiplo de INC (rol maestro)   (DIAG1 fallaba: leia NOW_SEC)
--   A3  NOW_NS avanza entre dos muestras          (DIAG1==DIAG2 fallaba)
--   A4  lecturas back-to-back de 3 regs distintos devuelven cada una SU dato
--       en orden (cualquier corrimiento de N transacciones truena aqui)
--   A5  flujo Sync completo por la cadena (STATUS.rx_sync == 1)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity tb_ptp_axil_master is
end entity;

architecture sim of tb_ptp_axil_master is
  signal clk : std_logic := '0';
  signal rstn : std_logic := '0';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  -- lado core
  signal req, we, ready : std_logic := '0';
  signal addr : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := (others => '0');

  -- AXI entre maestro y ptp_axil
  signal awaddr, araddr : std_logic_vector(15 downto 0);
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic;
  signal arvalid, arready, rvalid, rready : std_logic;
  signal axi_wdata, axi_rdata : std_logic_vector(31 downto 0);
  signal axi_wstrb : std_logic_vector(3 downto 0);
  signal bresp, rresp : std_logic_vector(1 downto 0);

  signal irq : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;
begin
  clk <= not clk after TCK/2 when not done else '0';

  u_master : entity work.ptp_axil_master
    port map (clk => clk, aresetn => rstn,
              req => req, we => we, addr => addr, wdata => wdata,
              wstrb => wstrb, rdata => rdata, ready => ready,
              p_awaddr => awaddr, p_awvalid => awvalid, p_awready => awready,
              p_wdata => axi_wdata, p_wstrb => axi_wstrb, p_wvalid => wvalid,
              p_wready => wready, p_bresp => bresp, p_bvalid => bvalid,
              p_bready => bready,
              p_araddr => araddr, p_arvalid => arvalid, p_arready => arready,
              p_rdata => axi_rdata, p_rresp => rresp, p_rvalid => rvalid,
              p_rready => rready);

  u_axil : entity work.ptp_axil
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (s_axi_aclk => clk, s_axi_aresetn => rstn,
              s_axi_awaddr => awaddr, s_axi_awvalid => awvalid, s_axi_awready => awready,
              s_axi_wdata => axi_wdata, s_axi_wstrb => axi_wstrb,
              s_axi_wvalid => wvalid, s_axi_wready => wready,
              s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
              s_axi_araddr => araddr, s_axi_arvalid => arvalid, s_axi_arready => arready,
              s_axi_rdata => axi_rdata, s_axi_rresp => rresp,
              s_axi_rvalid => rvalid, s_axi_rready => rready,
              irq => irq, mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => (others => '0'), mii_rx_dv => '0');

  stim : process
    -- protocolo dmem: req/addr estables hasta ready; rdata muestreado EN ready
    procedure mwr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,16)); wdata <= d;
      we <= '1'; wstrb <= "1111"; req <= '1';
      loop
        wait until rising_edge(clk);
        exit when ready = '1';
      end loop;
      req <= '0'; we <= '0'; wstrb <= "0000";
    end procedure;
    procedure mrd(a : integer; result : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,16));
      we <= '0'; wstrb <= "0000"; req <= '1';
      loop
        wait until rising_edge(clk);
        exit when ready = '1';
      end loop;
      result := rdata;    -- capturado en el ciclo de ready (como el core)
      req <= '0';
    end procedure;
    -- lectura back-to-back: req se mantiene alto y addr cambia el ciclo
    -- siguiente al ready (peor caso para el maestro)
    procedure mrd_b2b(a : integer; result : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,16));
      we <= '0'; wstrb <= "0000"; req <= '1';
      loop
        wait until rising_edge(clk);
        exit when ready = '1';
      end loop;
      result := rdata;    -- req QUEDA en alto: siguiente acceso inmediato
    end procedure;

    variable v, n0, n1 : std_logic_vector(31 downto 0);
    variable ni0, ni1 : integer;
    variable tout : integer;
  begin
    wait for 5*TCK; rstn <= '1'; wait for 2*TCK;

    -- ============ A1: readback inmediato de CONTROL (firma DIAG0) ==========
    mwr(16#00#, x"00000006");            -- CONTROL: enable+loopback, maestro
    mrd(16#00#, v);
    assert v = x"00000006"
      report "A1 FALLA: CONTROL rdback=" & to_hstring(v) & " (esperado 6) - CORRIMIENTO" severity failure;
    report "A1 OK: CONTROL readback = 0x6";

    -- ============ A2/A3: NOW_NS multiplo de INC y avanzando (DIAG1/2) ======
    mrd(16#28#, v);                      -- NOW_SEC (congela NOW_NS)
    mrd(16#2C#, n0);                     -- NOW_NS
    for i in 0 to 199 loop wait until rising_edge(clk); end loop;
    mrd(16#28#, v);
    mrd(16#2C#, n1);
    ni0 := to_integer(unsigned(n0)); ni1 := to_integer(unsigned(n1));
    assert (ni0 mod INC_NS_NOM = 0) and (ni1 mod INC_NS_NOM = 0)
      report "A2 FALLA: NOW_NS no es multiplo de INC (ns0=" & integer'image(ni0)
             & " ns1=" & integer'image(ni1) & ") - LEYENDO OTRO REGISTRO" severity failure;
    report "A2 OK: NOW_NS multiplos de " & integer'image(INC_NS_NOM)
           & " (ns0=" & integer'image(ni0) & " ns1=" & integer'image(ni1) & ")";
    assert ni1 /= ni0
      report "A3 FALLA: NOW_NS no avanza (snapshot rancio) - CORRIMIENTO" severity failure;
    report "A3 OK: NOW_NS avanza";

    -- ============ A4: back-to-back de 3 regs distintos (anti-corrimiento) ==
    mwr(16#10#, x"00112233");            -- CLKID_HI
    mwr(16#14#, x"44556677");            -- CLKID_LO
    mwr(16#18#, x"00000001");            -- PORTNUM
    mrd_b2b(16#10#, v);
    assert v = x"00112233" report "A4 FALLA (CLKID_HI): " & to_hstring(v) severity failure;
    mrd_b2b(16#14#, v);
    assert v = x"44556677" report "A4 FALLA (CLKID_LO): " & to_hstring(v) severity failure;
    mrd(16#18#, v);
    assert v = x"00000001" report "A4 FALLA (PORTNUM): " & to_hstring(v) severity failure;
    report "A4 OK: 3 lecturas back-to-back sin corrimiento";

    -- ============ A5: flujo Sync completo por la cadena (firma DIAG3) ======
    mwr(16#04#, x"00400010");            -- SERVO_K
    mwr(16#24#, x"0000000F");            -- STATUS W1C
    mwr(16#0C#, x"00000001");            -- CMD.send_sync
    tout := 0;
    loop
      mrd(16#24#, v);
      exit when v(0) = '1';
      tout := tout + 1;
      assert tout < 20000 report "A5 FALLA: timeout esperando rx_sync" severity failure;
    end loop;
    report "A5 OK: Sync completo por core->master->axil->top (STATUS=" & to_hstring(v) & ")";

    report "=== TB_PTP_AXIL_MASTER: cadena lado-core PASS ===";
    done <= true;
    wait;
  end process;
end architecture sim;
