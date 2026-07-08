-- =============================================================================
--  tb_usart_mmio.vhd  -  Testbench autoverificable de la capa 2 (MMIO+FIFOs).
--
--  BFM estilo dmem: sel/req de exactamente 1 ciclo con captura de rdata en el
--  mismo flanco (el pop de RXDATA es efecto secundario del acceso, igual que
--  en el SoC real). DUT instanciado con FIFO_LOG2=4 (DEPTH=16, RTS_HI=8) para
--  que overflow, watermarks e histeresis se ejerciten rapido; el SoC usa 8.
--
--  Tests
--    M1  valores de reset y readback de registros
--    M2  PIO por loop_int: push TXDATA, poll RXLVL, pop RXDATA (orden+niveles)
--    M3  overflow TX: push 17/16 -> drop + tx_ovf sticky; STAT-write limpia
--    M4  overflow RX: FIFO lleno + 1 char extra -> drop + rx_ovf; los 16
--        primeros bytes intactos (politica drop-newest, sin back-pressure)
--    M5  watermarks: IRQ por rx_wm (nivel, cae al drenar) y tx_wm (recarga)
--    M6  rx_idle: dispara tras IDLE_TO tiempos de bit, se rearma con pops,
--        refira con datos pendientes, cae al drenar (estilo 16550)
--    M7  stickies de error via rxd_i: frame_err (dato empujado), break (sin
--        push), par_err (dato empujado); STAT-write limpia
--    M8  RTS con histeresis: sube en RXLVL>=DEPTH-8, baja bajo WM.rx
--    M9  DE RS-485: half_dup+flow_en=0 -> pad RTS = tx_active; eco suprimido
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_usart_mmio is
end entity;

architecture sim of tb_usart_mmio is

  constant CLK_P : time := 10 ns;
  constant BITP  : time := 500 ns;                      -- 2 Mbaud
  constant K_2M  : natural := natural(2000000.0 * 16.0 / 100.0e6 * 2.0**32);
  constant LOG2  : natural := 4;                        -- DEPTH=16 en el TB

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal sel   : std_logic := '0';
  signal req   : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0)  := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq_o : std_logic;

  signal rxd_i, txd_line_i : std_logic := '1';
  signal txd_o, txd_t, rts_n_o : std_logic;
  signal cts_n_i : std_logic := '0';

  signal tb_rxd  : std_logic := '1';
  signal line_hd : std_logic;

  -- offsets
  constant A_CTRL : std_logic_vector(7 downto 0) := x"00";
  constant A_STAT : std_logic_vector(7 downto 0) := x"04";
  constant A_BAUD : std_logic_vector(7 downto 0) := x"08";
  constant A_TXD  : std_logic_vector(7 downto 0) := x"0C";
  constant A_RXD  : std_logic_vector(7 downto 0) := x"10";
  constant A_TXL  : std_logic_vector(7 downto 0) := x"14";
  constant A_RXL  : std_logic_vector(7 downto 0) := x"18";
  constant A_IEN  : std_logic_vector(7 downto 0) := x"1C";
  constant A_IST  : std_logic_vector(7 downto 0) := x"20";
  constant A_WM   : std_logic_vector(7 downto 0) := x"24";
  constant A_ITO  : std_logic_vector(7 downto 0) := x"28";

  ------------------------------------------------------------------------------
  -- Modelo de comportamiento independiente (solo TX, con inyeccion de errores)
  ------------------------------------------------------------------------------
  procedure uart_tx_beh(signal   l          : out std_logic;
                        constant d          : in  std_logic_vector(7 downto 0);
                        constant bp         : in  time;
                        constant paren      : in  boolean := false;
                        constant parodd     : in  boolean := false;
                        constant force_perr : in  boolean := false;
                        constant force_ferr : in  boolean := false) is
    variable p : std_logic := '0';
  begin
    l <= '0';  wait for bp;
    for i in 0 to 7 loop
      l <= d(i);
      p := p xor d(i);
      wait for bp;
    end loop;
    if paren then
      if parodd     then p := not p; end if;
      if force_perr then p := not p; end if;
      l <= p;  wait for bp;
    end if;
    if force_ferr then
      l <= '0';  wait for bp;
      l <= '1';  wait for bp;
    else
      l <= '1';  wait for bp;
    end if;
  end procedure;

begin

  clk <= not clk after CLK_P / 2;

  dut : entity work.usart_mmio
    generic map (FIFO_LOG2 => LOG2)
    port map (
      clk => clk, aresetn => aresetn,
      sel => sel, req => req, addr => addr,
      wdata => wdata, wstrb => wstrb, rdata => rdata,
      irq_o => irq_o,
      rxd_i => rxd_i, txd_line_i => txd_line_i,
      txd_o => txd_o, txd_t => txd_t,
      cts_n_i => cts_n_i, rts_n_o => rts_n_o
    );

  rxd_i <= tb_rxd;

  -- linea compartida para M9 (pull-up debil + driver tristate del DUT)
  line_hd    <= 'H';
  line_hd    <= txd_o when txd_t = '0' else 'Z';
  txd_line_i <= to_x01(line_hd);

  watchdog : process
  begin
    wait for 5 ms;
    report "TIMEOUT: testbench hung" severity failure;
  end process;

  ------------------------------------------------------------------------------
  stim : process
    variable d    : std_logic_vector(31 downto 0);
    variable t0   : time;
    variable dt   : time;

    -- BFM: escritura dmem de 1 ciclo
    procedure mm_wr(constant a : in std_logic_vector(7 downto 0);
                    constant v : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; req <= '1'; addr <= a; wdata <= v; wstrb <= "1111";
      wait until rising_edge(clk);
      sel <= '0'; req <= '0'; wstrb <= "0000";
    end procedure;

    -- BFM: lectura dmem de 1 ciclo (captura en el flanco, pop incluido)
    procedure mm_rd(constant a : in  std_logic_vector(7 downto 0);
                    variable v : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; req <= '1'; addr <= a; wstrb <= "0000";
      wait until rising_edge(clk);
      v := rdata;
      sel <= '0'; req <= '0';
    end procedure;

    -- poll de un registro de nivel hasta valor exacto, con tope de tiempo
    procedure poll_eq(constant a    : in std_logic_vector(7 downto 0);
                      constant v    : in natural;
                      constant tmax : in time;
                      constant tag  : in string) is
      variable r  : std_logic_vector(31 downto 0);
      variable ts : time := now;
    begin
      loop
        mm_rd(a, r);
        exit when to_integer(unsigned(r)) = v;
        assert (now - ts) < tmax
          report tag & ": poll timeout esperando " & integer'image(v) &
                 ", ultimo = " & integer'image(to_integer(unsigned(r)))
          severity failure;
        wait for 1 us;
      end loop;
    end procedure;

  begin
    aresetn <= '0';
    wait for 200 ns;
    aresetn <= '1';
    wait for 200 ns;

    ----------------------------------------------------------------------------
    report "[M1] valores de reset";
    mm_rd(A_CTRL, d);
    assert d = x"00000000" report "M1: CTRL reset /= 0" severity failure;
    mm_rd(A_BAUD, d);
    assert to_integer(unsigned(d)) = 79164837
      report "M1: BAUD reset /= 115200@100MHz" severity failure;
    mm_rd(A_WM, d);
    assert to_integer(unsigned(d(LOG2 downto 0))) = 8 and
           to_integer(unsigned(d(16 + LOG2 downto 16))) = 4
      report "M1: WM reset /= DEPTH/2, DEPTH/4" severity failure;
    mm_rd(A_ITO, d);
    assert to_integer(unsigned(d)) = 40
      report "M1: IDLE_TO reset /= 40" severity failure;
    mm_rd(A_STAT, d);
    assert d = x"0000000A"                              -- tx_empty | rx_empty
      report "M1: STAT reset inesperado: 0x" & to_hstring(d) severity failure;
    report "[M1] PASS";

    ----------------------------------------------------------------------------
    report "[M2] PIO por loop_int";
    mm_wr(A_BAUD, std_logic_vector(to_unsigned(K_2M, 32)));
    mm_wr(A_CTRL, x"00000087");                         -- en|tx|rx|loop_int
    mm_wr(A_TXD, x"000000DE");
    mm_wr(A_TXD, x"000000AD");
    mm_wr(A_TXD, x"000000BE");
    mm_wr(A_TXD, x"000000EF");
    poll_eq(A_RXL, 4, 60 us, "M2");
    mm_rd(A_RXD, d);
    assert d(7 downto 0) = x"DE" report "M2: byte 0" severity failure;
    mm_rd(A_RXL, d);
    assert to_integer(unsigned(d)) = 3
      report "M2: pop no decremento RXLVL" severity failure;
    mm_rd(A_RXD, d);
    assert d(7 downto 0) = x"AD" report "M2: byte 1" severity failure;
    mm_rd(A_RXD, d);
    assert d(7 downto 0) = x"BE" report "M2: byte 2" severity failure;
    mm_rd(A_RXD, d);
    assert d(7 downto 0) = x"EF" report "M2: byte 3" severity failure;
    wait for 1 us;              -- el TX termina su stop ~0.5 bit despues del push
    mm_rd(A_STAT, d);
    assert d(1) = '1' and d(0) = '0' and d(10) = '0'
      report "M2: STAT final (tx_empty/busys)" severity failure;
    report "[M2] PASS";

    ----------------------------------------------------------------------------
    report "[M3] overflow TX: drop + sticky";
    mm_wr(A_CTRL, x"00000000");                         -- motor apagado
    for i in 0 to 16 loop                               -- 17 pushes, DEPTH=16
      mm_wr(A_TXD, std_logic_vector(to_unsigned(i, 32)));
    end loop;
    mm_rd(A_TXL, d);
    assert to_integer(unsigned(d)) = 16
      report "M3: TXLVL /= 16 tras 17 pushes" severity failure;
    mm_rd(A_STAT, d);
    assert d(6) = '1' report "M3: tx_ovf no se marco" severity failure;
    assert d(5) = '0' report "M3: rx_ovf marcado sin razon" severity failure;
    mm_wr(A_STAT, x"00000000");                         -- limpia stickies
    mm_rd(A_STAT, d);
    assert d(6) = '0' report "M3: STAT-write no limpio tx_ovf" severity failure;
    report "[M3] PASS";

    ----------------------------------------------------------------------------
    report "[M4] overflow RX: drop-newest, primeros 16 intactos";
    mm_wr(A_CTRL, x"00000087");                         -- drena los 16 por loop
    poll_eq(A_RXL, 16, 120 us, "M4-drain");
    mm_rd(A_STAT, d);
    assert d(4) = '1' report "M4: rx_full no activo con RXLVL=16" severity failure;
    mm_wr(A_TXD, x"000000EE");                          -- char 17: debe caerse
    wait for 8 us;                                      -- char completo + margen
    mm_rd(A_STAT, d);
    assert d(5) = '1' report "M4: rx_ovf no se marco" severity failure;
    for i in 0 to 15 loop
      mm_rd(A_RXD, d);
      assert to_integer(unsigned(d(7 downto 0))) = i
        report "M4: byte " & integer'image(i) & " corrupto: 0x" &
               to_hstring(d(7 downto 0)) severity failure;
    end loop;
    mm_rd(A_RXL, d);
    assert to_integer(unsigned(d)) = 0
      report "M4: 0xEE no fue descartado" severity failure;
    mm_wr(A_STAT, x"00000000");
    report "[M4] PASS";

    ----------------------------------------------------------------------------
    report "[M5] watermarks e IRQ (rx_wm, tx_wm)";
    mm_wr(A_WM, x"00020004");                           -- rx_wm=4, tx_wm=2
    mm_wr(A_IEN, x"00000001");                          -- solo rx_wm
    mm_wr(A_TXD, x"00000010");
    mm_wr(A_TXD, x"00000011");
    mm_wr(A_TXD, x"00000012");
    mm_wr(A_TXD, x"00000013");
    wait until irq_o = '1' for 60 us;
    assert irq_o = '1' report "M5: irq rx_wm no disparo" severity failure;
    mm_rd(A_IST, d);
    assert d(0) = '1' report "M5: IRQ_STAT.rx_wm /= 1" severity failure;
    mm_rd(A_RXD, d);                                    -- RXLVL 4 -> 3 (< wm)
    wait for 1 us;
    assert irq_o = '0' report "M5: irq rx_wm no cayo al drenar" severity failure;
    mm_rd(A_RXD, d); mm_rd(A_RXD, d); mm_rd(A_RXD, d);
    -- tx_wm: pedir recarga cuando TXLVL <= 2
    mm_wr(A_CTRL, x"00000000");                         -- motor apagado
    mm_wr(A_IEN, x"00000002");
    for i in 0 to 4 loop
      mm_wr(A_TXD, std_logic_vector(to_unsigned(16#20# + i, 32)));
    end loop;
    wait for 1 us;
    assert irq_o = '0' report "M5: irq tx_wm activo con TXLVL=5" severity failure;
    mm_wr(A_CTRL, x"00000087");                         -- drenar
    wait until irq_o = '1' for 60 us;
    assert irq_o = '1' report "M5: irq tx_wm no disparo al drenar" severity failure;
    poll_eq(A_RXL, 5, 60 us, "M5-rx");
    mm_wr(A_IEN, x"00000000");
    for i in 0 to 4 loop
      mm_rd(A_RXD, d);
    end loop;
    report "[M5] PASS";

    ----------------------------------------------------------------------------
    report "[M6] rx_idle timeout (estilo 16550)";
    mm_wr(A_ITO, std_logic_vector(to_unsigned(20, 32)));  -- 20 bits = 10 us
    mm_wr(A_IEN, x"00000004");
    mm_wr(A_TXD, x"000000AA");
    mm_wr(A_TXD, x"00000055");
    poll_eq(A_RXL, 2, 60 us, "M6");
    t0 := now;
    wait until irq_o = '1' for 30 us;
    assert irq_o = '1' report "M6: rx_idle no disparo" severity failure;
    dt := now - t0;
    assert dt > 7 us and dt < 15 us
      report "M6: rx_idle fuera de ventana (" & time'image(dt) & ")"
      severity failure;
    mm_rd(A_RXD, d);                                    -- pop rearma el contador
    wait for 1 us;
    assert irq_o = '0' report "M6: pop no rearmo el timeout" severity failure;
    wait until irq_o = '1' for 30 us;
    assert irq_o = '1'
      report "M6: no refiro con datos pendientes" severity failure;
    mm_rd(A_RXD, d);                                    -- FIFO vacio
    wait for 15 us;
    assert irq_o = '0' report "M6: idle activo con FIFO vacio" severity failure;
    mm_wr(A_IEN, x"00000000");
    report "[M6] PASS";

    ----------------------------------------------------------------------------
    report "[M7] stickies de error via rxd_i";
    mm_wr(A_CTRL, x"00000005");                         -- en|rx_en, sin loop
    uart_tx_beh(tb_rxd, x"55", BITP, force_ferr => true);
    wait for 2 us;
    mm_rd(A_STAT, d);
    assert d(7) = '1' report "M7: frame_err no marcado" severity failure;
    mm_rd(A_RXD, d);
    assert d(7 downto 0) = x"55"
      report "M7: dato con frame error no empujado" severity failure;
    mm_wr(A_STAT, x"00000000");
    tb_rxd <= '0';                                      -- break
    wait for 13 * BITP;
    tb_rxd <= '1';
    wait for 2 us;
    mm_rd(A_STAT, d);
    assert d(9) = '1' report "M7: break no marcado" severity failure;
    mm_rd(A_RXL, d);
    assert to_integer(unsigned(d)) = 0
      report "M7: break empujo datos" severity failure;
    mm_wr(A_STAT, x"00000000");
    mm_wr(A_CTRL, x"0000000D");                         -- en|rx_en|par_en (8E1)
    uart_tx_beh(tb_rxd, x"3A", BITP, paren => true, force_perr => true);
    wait for 2 us;
    mm_rd(A_STAT, d);
    assert d(8) = '1' report "M7: par_err no marcado" severity failure;
    mm_rd(A_RXD, d);
    assert d(7 downto 0) = x"3A"
      report "M7: dato con error de paridad no empujado" severity failure;
    mm_wr(A_STAT, x"00000000");
    report "[M7] PASS";

    ----------------------------------------------------------------------------
    report "[M8] RTS con histeresis (flow_en=1)";
    mm_wr(A_CTRL, x"00000105");                         -- en|rx_en|flow_en
    wait for 1 us;
    assert rts_n_o = '0' report "M8: RTS_n /= 0 con FIFO vacio" severity failure;
    for i in 0 to 7 loop                                -- llegar a RTS_HI = 8
      uart_tx_beh(tb_rxd, std_logic_vector(to_unsigned(16#30# + i, 8)), BITP);
    end loop;
    wait for 2 us;
    mm_rd(A_RXL, d);
    assert to_integer(unsigned(d)) = 8 report "M8: RXLVL /= 8" severity failure;
    assert rts_n_o = '1'
      report "M8: RTS_n no se desactivo en RXLVL >= DEPTH-8" severity failure;
    mm_rd(A_STAT, d);
    assert d(12) = '1' report "M8: STAT.rts_n /= pin" severity failure;
    for i in 0 to 4 loop                                -- bajar a 3 < wm_rx(4)
      mm_rd(A_RXD, d);
      assert to_integer(unsigned(d(7 downto 0))) = 16#30# + i
        report "M8: dato " & integer'image(i) & " corrupto" severity failure;
    end loop;
    wait for 1 us;
    assert rts_n_o = '0'
      report "M8: RTS_n no se reactivo bajo WM.rx" severity failure;
    mm_rd(A_RXD, d); mm_rd(A_RXD, d); mm_rd(A_RXD, d);
    report "[M8] PASS";

    ----------------------------------------------------------------------------
    report "[M9] DE RS-485 (half_dup, flow_en=0) + eco suprimido";
    mm_wr(A_CTRL, x"00000207");                         -- en|tx|rx|half_dup
    wait for 1 us;
    assert rts_n_o = '0' report "M9: DE alto en reposo" severity failure;
    mm_wr(A_TXD, x"000000A5");
    wait until txd_t = '0' for 20 us;                   -- el DUT toma la linea
    assert txd_t = '0' report "M9: TX nunca tomo la linea" severity failure;
    wait for 100 ns;                    -- asentar deltas (txd_t y DE derivan del mismo tx_active)
    assert rts_n_o = '1' report "M9: DE no acompano a tx_active" severity failure;
    wait until txd_t = '1' for 20 us;                   -- frame terminado
    assert txd_t = '1' report "M9: TX nunca solto la linea" severity failure;
    wait for 1 us;
    assert rts_n_o = '0' report "M9: DE no bajo tras el frame" severity failure;
    wait for 6 us;
    mm_rd(A_RXL, d);
    assert to_integer(unsigned(d)) = 0
      report "M9: eco no suprimido en half duplex" severity failure;
    report "[M9] PASS";

    ----------------------------------------------------------------------------
    report "==================================================";
    report "tb_usart_mmio: ALL TESTS PASSED";
    report "==================================================";
    std.env.finish;
  end process;

end architecture sim;
