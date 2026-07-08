-- =============================================================================
--  tb_spi_axi.vhd  -  Valida el IP SPI completo: registros + FIFOs + motor +
--                     DMA maestro AXI4 contra la DDR falsa (axi_ddr_sim)
--  Licencia: MIT
--
--  MISO en loopback: lo que el DMA saca de la DDR y el motor manda por MOSI
--  regresa por MISO y el DMA lo escribe en otra region de la DDR. Verificar
--  destino == fuente prueba TODO el camino de ida y vuelta.
--
--  La DDR falsa arranca con spi_ddr.mem:
--    palabras 0..63    : patron incremental (byte n = n)
--    palabras 384..387 : 0xDEADBEEF (para probar el wstrb parcial de T2)
--  FIFO_LOG2 = 4 (16 bytes): las transferencias de 64 bytes obligan multiples
--  rellenos/drenados, ejercitando el control de flujo del DMA.
--
--  T1: full-duplex 64 bytes, DDR[0x400] == DDR[0x000], IRQ sube y se limpia
--  T2: LEN=13 (cola parcial): 3 palabras + 1 byte con wstrb "0001" sobre
--      0xDEADBEEF -> 0xDEADBE0C (los otros 3 bytes intactos)
--  T3: tx_en=0 (dummy 0x5A): la DDR destino recibe puros 0x5A
--  T4: rx_en=0 (puro TX): termina sin colgarse, RX drenado sin overflow
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_axi is
end entity tb_spi_axi;

architecture sim of tb_spi_axi is
  constant TCK    : time    := 10 ns;
  constant AXI_AW : natural := 40;
  constant FLOG   : natural := 4;

  constant A_CTRL    : std_logic_vector(7 downto 0) := x"00";
  constant A_STATUS  : std_logic_vector(7 downto 0) := x"04";
  constant A_CLKDIV  : std_logic_vector(7 downto 0) := x"08";
  constant A_RXLVL   : std_logic_vector(7 downto 0) := x"18";
  constant A_DMATXA  : std_logic_vector(7 downto 0) := x"1C";
  constant A_DMARXA  : std_logic_vector(7 downto 0) := x"20";
  constant A_DMALEN  : std_logic_vector(7 downto 0) := x"24";
  constant A_DMACTRL : std_logic_vector(7 downto 0) := x"28";

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal sel, req : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0)  := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;

  signal sclk, mosi, cs_n : std_logic;
  signal miso : std_logic;
  signal ext_loop : std_logic := '0';   -- '0': pads "rotos" (prueba loop_int)

  signal ddr_base : std_logic_vector(AXI_AW-1 downto 0) := (others => '0');

  -- AXI maestro DUT <-> DDR falsa
  signal aw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal aw_len  : std_logic_vector(7 downto 0);
  signal aw_size : std_logic_vector(2 downto 0);
  signal aw_burst: std_logic_vector(1 downto 0);
  signal aw_valid, aw_ready : std_logic;
  signal w_data  : std_logic_vector(31 downto 0);
  signal w_strb  : std_logic_vector(3 downto 0);
  signal w_last, w_valid, w_ready : std_logic;
  signal b_resp  : std_logic_vector(1 downto 0);
  signal b_valid, b_ready : std_logic;
  signal ar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal ar_len  : std_logic_vector(7 downto 0);
  signal ar_size : std_logic_vector(2 downto 0);
  signal ar_burst: std_logic_vector(1 downto 0);
  signal ar_valid, ar_ready : std_logic;
  signal r_data  : std_logic_vector(31 downto 0);
  signal r_resp  : std_logic_vector(1 downto 0);
  signal r_last, r_valid, r_ready : std_logic;

  -- puerto de inspeccion de la DDR
  signal dbg_addr : natural := 0;
  signal dbg_data : std_logic_vector(31 downto 0);

  -- palabra k del patron: byte j = 4k + j
  function pat_word(k : natural) return std_logic_vector is
    variable w : std_logic_vector(31 downto 0);
  begin
    w(7 downto 0)   := std_logic_vector(to_unsigned((4*k)     mod 256, 8));
    w(15 downto 8)  := std_logic_vector(to_unsigned((4*k + 1) mod 256, 8));
    w(23 downto 16) := std_logic_vector(to_unsigned((4*k + 2) mod 256, 8));
    w(31 downto 24) := std_logic_vector(to_unsigned((4*k + 3) mod 256, 8));
    return w;
  end function;
begin

  clk  <= not clk after TCK/2;
  miso <= mosi when ext_loop = '1' else '0';   -- loopback externo conmutable

  dut : entity work.spi_axi_top
    generic map (DIV_W => 16, FIFO_LOG2 => FLOG, ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      sel => sel, req => req, addr => addr,
      wdata => wdata, wstrb => wstrb, rdata => rdata,
      irq_out => irq,
      m_axi_awaddr => aw_addr, m_axi_awlen => aw_len, m_axi_awsize => aw_size,
      m_axi_awburst => aw_burst, m_axi_awvalid => aw_valid, m_axi_awready => aw_ready,
      m_axi_wdata => w_data, m_axi_wstrb => w_strb, m_axi_wlast => w_last,
      m_axi_wvalid => w_valid, m_axi_wready => w_ready,
      m_axi_bresp => b_resp, m_axi_bvalid => b_valid, m_axi_bready => b_ready,
      m_axi_araddr => ar_addr, m_axi_arlen => ar_len, m_axi_arsize => ar_size,
      m_axi_arburst => ar_burst, m_axi_arvalid => ar_valid, m_axi_arready => ar_ready,
      m_axi_rdata => r_data, m_axi_rresp => r_resp, m_axi_rlast => r_last,
      m_axi_rvalid => r_valid, m_axi_rready => r_ready,
      sclk_o => sclk, mosi_o => mosi, miso_i => miso, cs_n_o => cs_n
    );

  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4,
                 INIT_FILE => "spi_ddr.mem")
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len,
      s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last,
      s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len,
      s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last,
      s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => dbg_addr, dbg_data => dbg_data
    );

  stim : process
    variable d : std_logic_vector(31 downto 0);

    procedure wr32(a : std_logic_vector(7 downto 0);
                   v : std_logic_vector(31 downto 0)) is
    begin
      addr <= a; wdata <= v; wstrb <= "1111"; sel <= '1'; req <= '1';
      wait until rising_edge(clk);
      sel <= '0'; req <= '0'; wstrb <= (others => '0');
    end procedure;

    procedure rd32(a : std_logic_vector(7 downto 0);
                   variable v : out std_logic_vector(31 downto 0)) is
    begin
      addr <= a; wstrb <= (others => '0'); sel <= '1'; req <= '1';
      wait until falling_edge(clk);
      v := rdata;
      wait until rising_edge(clk);
      sel <= '0'; req <= '0';
    end procedure;

    -- espera fin de DMA (busy pegajoso abajo + done arriba) con timeout
    procedure wait_dma is
      variable s : std_logic_vector(31 downto 0);
      variable n : natural := 0;
    begin
      loop
        rd32(A_STATUS, s);
        exit when s(7) = '0' and s(8) = '1';
        n := n + 1;
        assert n < 100000 report "TIMEOUT esperando al DMA" severity failure;
      end loop;
    end procedure;

    -- compara una palabra de la DDR contra lo esperado
    procedure chk_ddr(widx : natural; exp : std_logic_vector(31 downto 0);
                      msg : string) is
    begin
      dbg_addr <= widx;
      wait for 1 ns;
      assert dbg_data = exp
        report msg & ": DDR[" & integer'image(widx) & "] = "
               & to_hstring(dbg_data) & ", esperaba " & to_hstring(exp)
        severity failure;
    end procedure;

    procedure chk(cond : boolean; msg : string) is
    begin
      assert cond report msg severity failure;
      report msg & " OK";
    end procedure;
  begin
    aresetn <= '0';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;
    aresetn <= '1';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ---------------------------------------------------------------------------
    -- T0: loopback INTERNO (CTRL[7]) con los pads "rotos" (ext_loop = 0)
    ---------------------------------------------------------------------------
    wr32(A_CLKDIV, x"00000001");
    wr32(A_CTRL,   x"000000C1");         -- en + irq_en + loop_int
    wr32(A_DMATXA,  x"00000000");
    wr32(A_DMARXA,  x"00000C00");        -- palabra 768 (region de scratch)
    wr32(A_DMALEN,  x"00000008");
    wr32(A_DMACTRL, x"00000007");
    wait_dma;
    chk_ddr(768, pat_word(0), "T0");
    chk_ddr(769, pat_word(1), "T0");
    report "T0 loopback interno (pads rotos) OK";
    wr32(A_STATUS, x"00000000");

    -- de aqui en adelante: loopback EXTERNO real, loop_int apagado
    ext_loop <= '1';
    wr32(A_CTRL,   x"00000041");

    ---------------------------------------------------------------------------
    -- T1: full-duplex 64 bytes, DDR[0x000..0x03F] -> SPI -> DDR[0x400..0x43F]
    ---------------------------------------------------------------------------
    wr32(A_DMATXA,  x"00000000");
    wr32(A_DMARXA,  x"00000400");
    wr32(A_DMALEN,  x"00000040");        -- 64 bytes
    wr32(A_DMACTRL, x"00000007");        -- start + tx_en + rx_en
    wait_dma;
    chk(irq = '1', "T1 IRQ activa al terminar");
    for k in 0 to 15 loop
      chk_ddr(256 + k, pat_word(k), "T1");
    end loop;
    report "T1 eco full-duplex de 64 bytes OK";
    rd32(A_STATUS, d);
    chk(d(5) = '0', "T1 sin rx_ovf durante el DMA");
    wr32(A_STATUS, x"00000000");         -- limpia done -> IRQ baja
    for i in 1 to 2 loop wait until rising_edge(clk); end loop;
    chk(irq = '0', "T1 IRQ limpia tras escribir STATUS");

    ---------------------------------------------------------------------------
    -- T2: LEN=13, cola parcial con wstrb sobre 0xDEADBEEF
    ---------------------------------------------------------------------------
    wr32(A_DMARXA,  x"00000600");
    wr32(A_DMALEN,  x"0000000D");        -- 13 bytes
    wr32(A_DMACTRL, x"00000007");
    wait_dma;
    chk_ddr(384, pat_word(0), "T2");
    chk_ddr(385, pat_word(1), "T2");
    chk_ddr(386, pat_word(2), "T2");
    chk_ddr(387, x"DEADBE0C", "T2");     -- solo el byte 0 escrito
    report "T2 cola parcial de 13 bytes OK";
    wr32(A_STATUS, x"00000000");

    ---------------------------------------------------------------------------
    -- T3: tx_en=0, dummy=0x5A: el destino recibe puros dummies
    ---------------------------------------------------------------------------
    wr32(A_DMARXA,  x"00000800");
    wr32(A_DMALEN,  x"00000008");        -- 8 bytes
    wr32(A_DMACTRL, x"00005A05");        -- start + rx_en + dummy 0x5A
    wait_dma;
    chk_ddr(512, x"5A5A5A5A", "T3");
    chk_ddr(513, x"5A5A5A5A", "T3");
    report "T3 inyeccion de dummies OK";
    wr32(A_STATUS, x"00000000");

    ---------------------------------------------------------------------------
    -- T4: rx_en=0 (puro TX): termina y descarta RX sin overflow
    ---------------------------------------------------------------------------
    wr32(A_DMATXA,  x"00000040");        -- palabras 16..19
    wr32(A_DMALEN,  x"00000010");        -- 16 bytes
    wr32(A_DMACTRL, x"00000003");        -- start + tx_en
    wait_dma;
    rd32(A_RXLVL, d);
    chk(to_integer(unsigned(d)) = 0, "T4 FIFO RX drenado");
    rd32(A_STATUS, d);
    chk(d(5) = '0', "T4 sin rx_ovf");
    report "T4 puro TX con descarte OK";

    report "TEST PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
