-- =============================================================================
--  tb_usart_axi.vhd  -  Testbench autoverificable de la capa 3 (IP completo:
--                       usart_axi_top contra axi_ddr_sim).
--
--  La DDR falsa se instancia con DEPTH=2048 (8 KB = DOS paginas de 4 KB) para
--  poder provocar cruces de frontera reales; sus asserts internos ("BURST
--  CRUZA LIMITE DE 4KB") vigilan el troceo de ambos canales gratis. dbg_addr/
--  dbg_data inspeccionan la memoria palabra a palabra. FIFO_LOG2=4 como en
--  capa 2 (rafagas cortas = mas casos de borde ejercitados).
--
--  El pipeline de datos usa loop_int: PIO/DMA-TX -> FIFO TX -> motor ->
--  loopback -> FIFO RX -> DMA-RX -> DDR. Todo a 2 Mbaud.
--
--  Tests
--    A1  RX DMA solo: siembra 48 bytes (PIO->loop->DMA) en DDR, cierre por
--        cuenta, RX_COUNT=48, datos verificados palabra a palabra
--    A2  CANALES CONCURRENTES: TX DMA lee la region de A1 mientras RX DMA
--        escribe otra region; un solo write arranca ambos; DDR B == DDR A
--    A3  cruce de 4 KB en ambos canales: (a) escritura RX cruzando 0x1000,
--        (b) lectura TX cruzando 0x1000 con RX concurrente sin cruce
--    A4  idle-flush: canal RX armado para 64, llegan 10 -> cierra por idle
--        con rx_flushed, RX_COUNT=10 y residuo con wstrb parcial en DDR
--    A5  sin flush espurio con count=0 (canal armado espera mas alla del
--        idle) + rx_abort limpio con RX_COUNT=0
--    A6  IRQ de tx_done: sube con el done, cae al limpiar DMA_STAT; drenado
--        PIO posterior verifica convivencia PIO/DMA y cero stickies al final
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_usart_axi is
end entity;

architecture sim of tb_usart_axi is

  constant CLK_P : time := 10 ns;
  constant BITP  : time := 500 ns;                      -- 2 Mbaud
  constant K_2M  : natural := natural(2000000.0 * 16.0 / 100.0e6 * 2.0**32);
  constant LOG2  : natural := 4;
  constant AW    : natural := 40;

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal sel   : std_logic := '0';
  signal req   : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0)  := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq_out : std_logic;

  signal rxd_i, txd_line_i : std_logic := '1';
  signal txd_o, txd_t, rts_n_o : std_logic;
  signal cts_n_i : std_logic := '0';

  -- AXI entre el IP y la DDR falsa
  signal axi_awaddr  : std_logic_vector(AW-1 downto 0);
  signal axi_awlen   : std_logic_vector(7 downto 0);
  signal axi_awsize  : std_logic_vector(2 downto 0);
  signal axi_awburst : std_logic_vector(1 downto 0);
  signal axi_awvalid, axi_awready : std_logic;
  signal axi_wdata   : std_logic_vector(31 downto 0);
  signal axi_wstrb   : std_logic_vector(3 downto 0);
  signal axi_wlast, axi_wvalid, axi_wready : std_logic;
  signal axi_bresp   : std_logic_vector(1 downto 0);
  signal axi_bvalid, axi_bready : std_logic;
  signal axi_araddr  : std_logic_vector(AW-1 downto 0);
  signal axi_arlen   : std_logic_vector(7 downto 0);
  signal axi_arsize  : std_logic_vector(2 downto 0);
  signal axi_arburst : std_logic_vector(1 downto 0);
  signal axi_arvalid, axi_arready : std_logic;
  signal axi_rdata   : std_logic_vector(31 downto 0);
  signal axi_rresp   : std_logic_vector(1 downto 0);
  signal axi_rlast, axi_rvalid, axi_rready : std_logic;

  signal dbg_addr : natural := 0;
  signal dbg_data : word_t;

  -- offsets MMIO (capa 2) + DMA (capa 3)
  constant A_CTRL : std_logic_vector(7 downto 0) := x"00";
  constant A_STAT : std_logic_vector(7 downto 0) := x"04";
  constant A_BAUD : std_logic_vector(7 downto 0) := x"08";
  constant A_TXD  : std_logic_vector(7 downto 0) := x"0C";
  constant A_RXD  : std_logic_vector(7 downto 0) := x"10";
  constant A_TXL  : std_logic_vector(7 downto 0) := x"14";
  constant A_RXL  : std_logic_vector(7 downto 0) := x"18";
  constant A_ITO  : std_logic_vector(7 downto 0) := x"28";
  constant D_TXA  : std_logic_vector(7 downto 0) := x"30";
  constant D_TXL  : std_logic_vector(7 downto 0) := x"34";
  constant D_RXA  : std_logic_vector(7 downto 0) := x"38";
  constant D_RXL  : std_logic_vector(7 downto 0) := x"3C";
  constant D_CTL  : std_logic_vector(7 downto 0) := x"40";
  constant D_STA  : std_logic_vector(7 downto 0) := x"44";
  constant D_CNT  : std_logic_vector(7 downto 0) := x"48";

begin

  clk <= not clk after CLK_P / 2;

  dut : entity work.usart_axi_top
    generic map (FIFO_LOG2 => LOG2, ADDR_W => AW)
    port map (
      clk => clk, aresetn => aresetn,
      ddr_base => (others => '0'),
      sel => sel, req => req, addr => addr,
      wdata => wdata, wstrb => wstrb, rdata => rdata,
      irq_out => irq_out,
      m_axi_awaddr => axi_awaddr, m_axi_awlen => axi_awlen,
      m_axi_awsize => axi_awsize, m_axi_awburst => axi_awburst,
      m_axi_awvalid => axi_awvalid, m_axi_awready => axi_awready,
      m_axi_wdata => axi_wdata, m_axi_wstrb => axi_wstrb,
      m_axi_wlast => axi_wlast, m_axi_wvalid => axi_wvalid,
      m_axi_wready => axi_wready,
      m_axi_bresp => axi_bresp, m_axi_bvalid => axi_bvalid,
      m_axi_bready => axi_bready,
      m_axi_araddr => axi_araddr, m_axi_arlen => axi_arlen,
      m_axi_arsize => axi_arsize, m_axi_arburst => axi_arburst,
      m_axi_arvalid => axi_arvalid, m_axi_arready => axi_arready,
      m_axi_rdata => axi_rdata, m_axi_rresp => axi_rresp,
      m_axi_rlast => axi_rlast, m_axi_rvalid => axi_rvalid,
      m_axi_rready => axi_rready,
      rxd_i => rxd_i, txd_line_i => txd_line_i,
      txd_o => txd_o, txd_t => txd_t,
      cts_n_i => cts_n_i, rts_n_o => rts_n_o
    );

  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AW, DEPTH => 2048, RD_LAT => 4)
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => axi_awaddr, s_axi_awlen => axi_awlen,
      s_axi_awvalid => axi_awvalid, s_axi_awready => axi_awready,
      s_axi_wdata => axi_wdata, s_axi_wstrb => axi_wstrb,
      s_axi_wlast => axi_wlast, s_axi_wvalid => axi_wvalid,
      s_axi_wready => axi_wready,
      s_axi_bresp => axi_bresp, s_axi_bvalid => axi_bvalid,
      s_axi_bready => axi_bready,
      s_axi_araddr => axi_araddr, s_axi_arlen => axi_arlen,
      s_axi_arvalid => axi_arvalid, s_axi_arready => axi_arready,
      s_axi_rdata => axi_rdata, s_axi_rresp => axi_rresp,
      s_axi_rlast => axi_rlast, s_axi_rvalid => axi_rvalid,
      s_axi_rready => axi_rready,
      dbg_addr => dbg_addr, dbg_data => dbg_data
    );

  watchdog : process
  begin
    wait for 10 ms;
    report "TIMEOUT: testbench hung" severity failure;
  end process;

  ------------------------------------------------------------------------------
  stim : process
    variable d  : std_logic_vector(31 downto 0);
    variable w  : std_logic_vector(31 downto 0);

    procedure mm_wr(constant a : in std_logic_vector(7 downto 0);
                    constant v : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; req <= '1'; addr <= a; wdata <= v; wstrb <= "1111";
      wait until rising_edge(clk);
      sel <= '0'; req <= '0'; wstrb <= "0000";
    end procedure;

    procedure mm_rd(constant a : in  std_logic_vector(7 downto 0);
                    variable v : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; req <= '1'; addr <= a; wstrb <= "0000";
      wait until rising_edge(clk);
      v := rdata;
      sel <= '0'; req <= '0';
    end procedure;

    -- espera a que un bit de un registro suba, con tope de tiempo
    procedure poll_bit(constant a    : in std_logic_vector(7 downto 0);
                       constant bitn : in natural;
                       constant tmax : in time;
                       constant tag  : in string) is
      variable r  : std_logic_vector(31 downto 0);
      variable ts : time := now;
    begin
      loop
        mm_rd(a, r);
        exit when r(bitn) = '1';
        assert (now - ts) < tmax
          report tag & ": timeout esperando bit " & integer'image(bitn)
          severity failure;
        wait for 2 us;
      end loop;
    end procedure;

    -- push PIO con ritmo (respeta el nivel del FIFO TX, DEPTH=16)
    procedure push_pio(constant b : in natural) is
      variable r : std_logic_vector(31 downto 0);
    begin
      loop
        mm_rd(A_TXL, r);
        exit when to_integer(unsigned(r)) < 16;
        wait for 3 us;
      end loop;
      mm_wr(A_TXD, std_logic_vector(to_unsigned(b, 32)));
    end procedure;

    -- empuja nbytes con patron (k*m + a) mod 256
    procedure push_region(constant nbytes, m, a : in natural) is
    begin
      for k in 0 to nbytes - 1 loop
        push_pio((k * m + a) mod 256);
      end loop;
    end procedure;

    -- verifica nbytes en DDR desde la palabra widx0 contra el mismo patron
    procedure chk_region(constant widx0, nbytes, m, a : in natural;
                         constant tag : in string) is
      variable k, e : natural;
    begin
      for j in 0 to (nbytes + 3) / 4 - 1 loop
        dbg_addr <= widx0 + j;
        wait for 1 ns;
        w := dbg_data;
        for b in 0 to 3 loop
          k := j * 4 + b;
          if k < nbytes then
            e := (k * m + a) mod 256;
            assert w(b*8+7 downto b*8) = std_logic_vector(to_unsigned(e, 8))
              report tag & ": byte " & integer'image(k) & " en DDR = 0x" &
                     to_hstring(w(b*8+7 downto b*8)) & ", esperado 0x" &
                     to_hstring(to_unsigned(e, 8)) severity failure;
          end if;
        end loop;
      end loop;
    end procedure;

  begin
    aresetn <= '0';
    wait for 200 ns;
    aresetn <= '1';
    wait for 200 ns;

    -- configuracion comun: 2 Mbaud, idle 20 bits (10 us), loopback interno
    mm_wr(A_BAUD, std_logic_vector(to_unsigned(K_2M, 32)));
    mm_wr(A_ITO, std_logic_vector(to_unsigned(20, 32)));
    mm_wr(A_CTRL, x"00000087");                         -- en|tx|rx|loop_int

    ----------------------------------------------------------------------------
    report "[A1] RX DMA: siembra por cuenta (48 bytes -> 0x0100)";
    mm_wr(D_RXA, x"00000100");
    mm_wr(D_RXL, std_logic_vector(to_unsigned(48, 32)));
    mm_wr(D_CTL, x"00000002");                          -- rx_start
    push_region(48, 7, 3);
    poll_bit(D_STA, 3, 500 us, "A1-rxdone");
    mm_rd(D_CNT, d);
    assert to_integer(unsigned(d)) = 48
      report "A1: RX_COUNT /= 48" severity failure;
    mm_rd(D_STA, d);
    assert d(4) = '0' report "A1: flushed sin razon (cierre por cuenta)"
      severity failure;
    chk_region(64, 48, 7, 3, "A1");
    mm_wr(D_STA, x"00000000");
    report "[A1] PASS";

    ----------------------------------------------------------------------------
    report "[A2] canales TX y RX CONCURRENTES (0x0100 -> loop -> 0x0800)";
    mm_wr(D_TXA, x"00000100");
    mm_wr(D_TXL, std_logic_vector(to_unsigned(48, 32)));
    mm_wr(D_RXA, x"00000800");
    mm_wr(D_RXL, std_logic_vector(to_unsigned(48, 32)));
    mm_wr(D_CTL, x"00000003");                          -- ambos en un write
    poll_bit(D_STA, 2, 500 us, "A2-txdone");
    poll_bit(D_STA, 3, 500 us, "A2-rxdone");
    mm_rd(D_CNT, d);
    assert to_integer(unsigned(d)) = 48
      report "A2: RX_COUNT /= 48" severity failure;
    chk_region(512, 48, 7, 3, "A2");
    mm_wr(D_STA, x"00000000");
    report "[A2] PASS";

    ----------------------------------------------------------------------------
    report "[A3a] escritura RX cruzando la frontera de 4 KB (0x0FF8 + 16)";
    mm_wr(D_RXA, x"00000FF8");
    mm_wr(D_RXL, std_logic_vector(to_unsigned(16, 32)));
    mm_wr(D_CTL, x"00000002");
    push_region(16, 11, 5);
    poll_bit(D_STA, 3, 300 us, "A3a-rxdone");
    chk_region(1022, 16, 11, 5, "A3a");
    mm_wr(D_STA, x"00000000");
    report "[A3a] PASS";

    ----------------------------------------------------------------------------
    report "[A3b] lectura TX cruzando 4 KB + RX concurrente (0x0FF8 -> 0x1800)";
    mm_wr(D_TXA, x"00000FF8");
    mm_wr(D_TXL, std_logic_vector(to_unsigned(16, 32)));
    mm_wr(D_RXA, x"00001800");
    mm_wr(D_RXL, std_logic_vector(to_unsigned(16, 32)));
    mm_wr(D_CTL, x"00000003");
    poll_bit(D_STA, 2, 300 us, "A3b-txdone");
    poll_bit(D_STA, 3, 300 us, "A3b-rxdone");
    chk_region(1536, 16, 11, 5, "A3b");
    mm_wr(D_STA, x"00000000");
    report "[A3b] PASS";

    ----------------------------------------------------------------------------
    report "[A4] idle-flush: armado para 64, llegan 10 (residuo wstrb parcial)";
    mm_wr(D_RXA, x"00000400");
    mm_wr(D_RXL, std_logic_vector(to_unsigned(64, 32)));
    mm_wr(D_CTL, x"00000002");
    push_region(10, 13, 1);
    poll_bit(D_STA, 3, 300 us, "A4-rxdone");
    mm_rd(D_STA, d);
    assert d(4) = '1' report "A4: rx_flushed no marcado" severity failure;
    mm_rd(D_CNT, d);
    assert to_integer(unsigned(d)) = 10
      report "A4: RX_COUNT /= 10, es " & integer'image(to_integer(unsigned(d)))
      severity failure;
    chk_region(256, 10, 13, 1, "A4");
    mm_wr(D_STA, x"00000000");
    report "[A4] PASS";

    ----------------------------------------------------------------------------
    report "[A5] sin flush espurio con count=0 + abort limpio";
    mm_wr(D_RXA, x"00000500");
    mm_wr(D_RXL, std_logic_vector(to_unsigned(32, 32)));
    mm_wr(D_CTL, x"00000002");
    wait for 30 us;                                     -- >> idle de 10 us
    mm_rd(D_STA, d);
    assert d(1) = '1' and d(3) = '0'
      report "A5: flush espurio sin haber recibido nada" severity failure;
    mm_wr(D_CTL, x"00000004");                          -- rx_abort
    poll_bit(D_STA, 3, 50 us, "A5-abort");
    mm_rd(D_STA, d);
    assert d(1) = '0' and d(4) = '0'
      report "A5: estado post-abort incorrecto" severity failure;
    mm_rd(D_CNT, d);
    assert to_integer(unsigned(d)) = 0
      report "A5: RX_COUNT /= 0 tras abort" severity failure;
    mm_wr(D_STA, x"00000000");
    report "[A5] PASS";

    ----------------------------------------------------------------------------
    report "[A6] IRQ de tx_done + drenado PIO posterior";
    mm_wr(D_TXA, x"00000100");
    mm_wr(D_TXL, std_logic_vector(to_unsigned(8, 32)));
    mm_wr(D_CTL, x"00000011");                          -- tx_start + irq_en_tx
    wait until irq_out = '1' for 100 us;
    assert irq_out = '1' report "A6: irq de tx_done no disparo" severity failure;
    mm_wr(D_STA, x"00000000");                          -- limpiar stickies
    wait for 1 us;
    assert irq_out = '0' report "A6: irq no cayo al limpiar DMA_STAT"
      severity failure;
    -- los 8 bytes siguen su camino por la linea; drenarlos por PIO
    poll_bit(A_STAT, 1, 100 us, "A6-txempty");          -- STAT.tx_empty
    wait for 10 us;                                     -- ultimo char en vuelo
    mm_rd(A_RXL, d);
    assert to_integer(unsigned(d)) = 8
      report "A6: RXLVL /= 8 tras el drenado de linea" severity failure;
    for k in 0 to 7 loop
      mm_rd(A_RXD, d);
      assert to_integer(unsigned(d(7 downto 0))) = (k * 7 + 3) mod 256
        report "A6: byte PIO " & integer'image(k) & " corrupto"
        severity failure;
    end loop;
    mm_rd(A_STAT, d);
    assert d(9 downto 5) = "00000"
      report "A6: stickies de error/overflow al final de la corrida: " &
             to_hstring(d) severity failure;
    report "[A6] PASS";

    ----------------------------------------------------------------------------
    report "==================================================";
    report "tb_usart_axi: ALL TESTS PASSED";
    report "==================================================";
    std.env.finish;
  end process;

end architecture sim;
