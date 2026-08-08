-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- TB del puente MMIO -> AXI-Lite contra pcs_stats_top real.
-- Ejecuta la secuencia de firmware del silicon pass VIA MMIO, exactamente como
-- la ejecutara el RV32 (lw/sw a la ventana 0xD000_0000).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_mmio is end entity;

architecture sim of tb_pcs_mmio is
  signal clk_axi : std_logic := '0';
  signal clk_dp  : std_logic := '0';
  signal rstn    : std_logic := '0';
  signal rst_dp  : std_logic := '1';

  -- MMIO
  signal sel   : std_logic := '0';
  signal wstrb : std_logic_vector(3 downto 0) := (others=>'0');
  signal addr  : std_logic_vector(7 downto 0) := (others=>'0');
  signal wdat  : std_logic_vector(31 downto 0) := (others=>'0');
  signal rdat  : std_logic_vector(31 downto 0);
  signal rdy   : std_logic;

  -- AXI puente <-> pcs
  signal awaddr, araddr : std_logic_vector(7 downto 0);
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic;
  signal arvalid, arready, rvalid, rready : std_logic;
  signal wdata, rdata : std_logic_vector(31 downto 0);
  signal wstrb_a : std_logic_vector(3 downto 0);
  signal bresp, rresp : std_logic_vector(1 downto 0);
  signal irq : std_logic;
  signal dma_addr, dma_db : std_logic_vector(31 downto 0);

  signal errors : natural := 0;
begin
  clk_axi <= not clk_axi after 5 ns;
  clk_dp  <= not clk_dp  after 1.28 ns;

  u_br: entity work.pcs_mmio_bridge
    port map (
      clk=>clk_axi, aresetn=>rstn,
      sel=>sel, wstrb=>wstrb, addr=>addr, wdata=>wdat, rdata=>rdat, ready=>rdy,
      m_awaddr=>awaddr, m_awvalid=>awvalid, m_awready=>awready,
      m_wdata=>wdata, m_wstrb=>wstrb_a, m_wvalid=>wvalid, m_wready=>wready,
      m_bresp=>bresp, m_bvalid=>bvalid, m_bready=>bready,
      m_araddr=>araddr, m_arvalid=>arvalid, m_arready=>arready,
      m_rdata=>rdata, m_rresp=>rresp, m_rvalid=>rvalid, m_rready=>rready
    );

  u_pcs: entity work.pcs_stats_top
    port map (
      s_axi_aclk=>clk_axi, s_axi_aresetn=>rstn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb_a, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
      irq_out=>irq, clk_dp=>clk_dp, rst_dp=>rst_dp,
      dma_addr=>dma_addr, dma_doorbell=>dma_db, dma_busy=>'0', dma_done_pulse=>'0'
    );

  main: process
    variable rd : std_logic_vector(31 downto 0);

    -- sw: como lo hara el RV32 (req sostenido hasta ready)
    procedure mm_wr(a : std_logic_vector(7 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      addr <= a; wdat <= d; wstrb <= "1111"; sel <= '1';
      loop
        wait until rising_edge(clk_axi);
        if rdy = '1' then exit; end if;
      end loop;
      sel <= '0'; wstrb <= "0000";
      wait until rising_edge(clk_axi);
    end procedure;

    -- lw
    procedure mm_rd(a : std_logic_vector(7 downto 0); d : out std_logic_vector(31 downto 0)) is
    begin
      addr <= a; wstrb <= "0000"; sel <= '1';
      loop
        wait until rising_edge(clk_axi);
        if rdy = '1' then d := rdat; exit; end if;
      end loop;
      sel <= '0';
      wait until rising_edge(clk_axi);
    end procedure;
  begin
    rstn <= '0'; rst_dp <= '1';
    wait for 100 ns;
    wait until rising_edge(clk_axi); rstn <= '1';
    wait until rising_edge(clk_dp);  rst_dp <= '0';
    wait for 100 ns; wait until rising_edge(clk_axi);

    -- FW1: ID
    mm_rd(x"00", rd);
    assert rd = x"50435319" report "MM1 FAIL ID" severity error;
    if rd /= x"50435319" then errors <= errors + 1; end if;
    report "MM1 ID = 0x" & to_hstring(rd);

    -- FW2/3: config
    mm_wr(x"1C", x"00000003");   -- PRBS_CTRL gen+chk
    mm_wr(x"08", x"0000000F");   -- CTRL pcs+tx+rx+loopback

    -- FW4: soft reset atomico + bring-up + prbs reset
    mm_wr(x"0C", x"00000001");   -- SOFT_RESET
    wait for 2 us;
    mm_wr(x"0C", x"00000008");   -- PRBS_RESET

    -- FW5: ventana limpia + snapshot + lecturas
    wait for 5 us;
    mm_wr(x"20", x"00000001");   -- STATS_SNAP
    wait for 1 us;
    mm_rd(x"30", rd);            -- CNT_BER
    assert unsigned(rd) = 0 report "MM5 FAIL BER no cero: " & to_hstring(rd) severity error;
    if unsigned(rd) /= 0 then errors <= errors + 1; end if;
    mm_rd(x"24", rd);            -- CNT_TX
    assert unsigned(rd) > 0 report "MM5 FAIL CNT_TX cero" severity error;
    if unsigned(rd) = 0 then errors <= errors + 1; end if;
    report "MM5 limpio: CNT_TX=0x" & to_hstring(rd);
    mm_rd(x"10", rd);            -- STATUS
    assert rd(0) = '1' and rd(3) = '1'
      report "MM5 FAIL sin block_lock/prbs_lock: " & to_hstring(rd) severity error;
    if not (rd(0) = '1' and rd(3) = '1') then errors <= errors + 1; end if;
    report "MM5 STATUS = 0x" & to_hstring(rd);

    -- FW6: inyeccion + snapshot + BER=9
    mm_wr(x"1C", x"00000007");   -- INJ
    wait for 2 us;
    mm_wr(x"20", x"00000001");
    wait for 1 us;
    mm_rd(x"30", rd);
    assert unsigned(rd) = 9 report "MM6 FAIL BER /= 9: " & to_hstring(rd) severity error;
    if unsigned(rd) /= 9 then errors <= errors + 1; end if;
    report "MM6 BER tras inyeccion = 0x" & to_hstring(rd) & " (esperado 9)";

    wait for 10 ns;
    if errors = 0 then
      report "LAYER4MMIO_PASS secuencia RV32 via puente MMIO OK" severity note;
    else
      report "LAYER4MMIO_FAIL errores=" & integer'image(errors) severity error;
    end if;
    std.env.stop;
  end process;

end architecture;
