-- tb_m1553_l4.vhd
-- Capa 4: SoC. Un maestro de bus de comportamiento ejecuta el MISMO guion que
-- correra el firmware RV32, atravesando el decode REAL (mem_subsys_m1553) hacia
-- el m1553_mmio REAL en 0xC000_0000, y hacia los registros DMA reales en
-- 0x4000_0000 y la RAM local en 0x0000_0000. Al final vuelca la firma de 8
-- palabras por DMA (doorbell) a la DDR simulada y la compara contra la firma
-- del ISS (iss_signature.txt). Firma temporal determinista.
-- Mensajes de FALLO sin tildes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_m1553_l4 is
end entity tb_m1553_l4;

architecture sim of tb_m1553_l4 is

  constant T_CLK : time := 10 ns;
  constant AXI_AW : natural := 40;

  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- bus dmem del "core"
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t := (others => '0');
  signal dmem_wstrb : std_logic_vector(3 downto 0) := "0000";
  signal dmem_req, dmem_ready : std_logic := '0';

  signal ddr_base : std_logic_vector(AXI_AW-1 downto 0) := (others => '0');

  -- region 1553
  signal m_sel  : std_logic;
  signal m_addr : std_logic_vector(7 downto 0);
  signal m_rdata : word_t;

  -- puerto MMIO
  signal m_sel_req, m_we : std_logic;
  signal m_irq : std_logic;
  signal bus_rx : std_logic := '0';
  signal bus_tx, bus_txen : std_logic;

  -- AXI maestro (colgado)
  signal m_axi_awaddr, m_axi_araddr : std_logic_vector(AXI_AW-1 downto 0);
  signal m_axi_awlen, m_axi_arlen : std_logic_vector(7 downto 0);
  signal m_axi_awsize, m_axi_arsize : std_logic_vector(2 downto 0);
  signal m_axi_awburst, m_axi_arburst : std_logic_vector(1 downto 0);
  signal m_axi_awvalid, m_axi_arvalid, m_axi_wvalid, m_axi_wlast : std_logic;
  signal m_axi_wdata, m_axi_rdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal m_axi_wstrb : std_logic_vector(3 downto 0);
  signal m_axi_bvalid, m_axi_rvalid, m_axi_rlast : std_logic := '0';
  signal m_axi_bresp, m_axi_rresp : std_logic_vector(1 downto 0) := "00";
  signal m_axi_awready, m_axi_wready, m_axi_bready : std_logic := '1';
  signal m_axi_arready, m_axi_rready : std_logic := '1';

  -- offsets 1553
  constant O_CTRL   : integer := 16#00#;
  constant O_RTAD   : integer := 16#04#;
  constant O_CMD    : integer := 16#08#;
  constant O_MSG    : integer := 16#0C#;
  constant O_STAT   : integer := 16#10#;
  constant O_TXD    : integer := 16#14#;
  constant O_RXD    : integer := 16#18#;
  constant O_RESULT : integer := 16#20#;

begin

  aclk <= not aclk after T_CLK/2;

  m_sel_req <= m_sel and dmem_req;
  m_we      <= '1' when dmem_wstrb /= "0000" else '0';

  u_mem : entity work.mem_subsys_m1553
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => aclk, aresetn => aresetn, ddr_base => ddr_base,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      m_sel => m_sel, m_addr => m_addr, m_rdata => m_rdata,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready);

  u_ip : entity work.m1553_mmio
    port map (
      clk => aclk, rst => (not aresetn),
      sel => m_sel_req, we => m_we, addr => m_addr,
      wdata => dmem_wdata, rdata => m_rdata, irq => m_irq,
      bus_rx_i => bus_rx, bus_tx_o => bus_tx, bus_txen_o => bus_txen);

  ------------------------------------------------------------------
  -- maestro de bus de comportamiento = firmware RV32 (mismo guion)
  ------------------------------------------------------------------
  fw : process
    -- transaccion de escritura al bus dmem
    procedure bwr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      dmem_addr <= std_logic_vector(to_unsigned(a, 32));
      dmem_wdata <= d;
      dmem_wstrb <= "1111";
      dmem_req <= '1';
      wait until rising_edge(aclk);
      dmem_wstrb <= "0000";
      dmem_req <= '0';
    end procedure;

    procedure brd(a : integer; res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      dmem_addr <= std_logic_vector(to_unsigned(a, 32));
      dmem_wstrb <= "0000";
      dmem_req <= '1';
      wait until rising_edge(aclk);   -- rdata registrado por la RAM/mmio
      wait for 1 ns;
      res := dmem_rdata;
      dmem_req <= '0';
    end procedure;

    procedure bwr_v(a : std_logic_vector(31 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      dmem_addr <= a; dmem_wdata <= d; dmem_wstrb <= "1111"; dmem_req <= '1';
      wait until rising_edge(aclk);
      dmem_wstrb <= "0000"; dmem_req <= '0';
    end procedure;

    procedure brd_v(a : std_logic_vector(31 downto 0); res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      dmem_addr <= a; dmem_wstrb <= "0000"; dmem_req <= '1';
      wait for 1 ns;                    -- rdata es combinacional para la region IP
      res := dmem_rdata;
      wait until rising_edge(aclk);      -- un solo ciclo de req: un solo pop
      dmem_req <= '0';
    end procedure;

    constant MMIO : std_logic_vector(31 downto 0) := x"C0000000";
    constant DMAR : std_logic_vector(31 downto 0) := x"40000000";

    procedure ip_wr(off : integer; d : std_logic_vector(31 downto 0)) is
    begin bwr_v(std_logic_vector(unsigned(MMIO) + off), d); end procedure;
    procedure ip_rd(off : integer; res : out std_logic_vector(31 downto 0)) is
    begin brd_v(std_logic_vector(unsigned(MMIO) + off), res); end procedure;

    function msgw(rtrt, tr : integer; rt, sa, wc, rt2, sa2 : integer)
      return std_logic_vector is
      variable v : std_logic_vector(31 downto 0) := (others => '0');
    begin
      v(0) := '1' when rtrt=1 else '0';
      v(1) := '1' when tr=1 else '0';
      v(6 downto 2)   := std_logic_vector(to_unsigned(rt,5));
      v(11 downto 7)  := std_logic_vector(to_unsigned(sa,5));
      v(16 downto 12) := std_logic_vector(to_unsigned(wc,5));
      v(21 downto 17) := std_logic_vector(to_unsigned(rt2,5));
      v(26 downto 22) := std_logic_vector(to_unsigned(sa2,5));
      return v;
    end function;

    variable r : std_logic_vector(31 downto 0);
    variable guard : integer;
    variable sig : integer;

    procedure go_wait is
    begin
      ip_wr(O_CMD, x"00000004");     -- GO
      guard := 0;
      loop
        ip_rd(O_STAT, r);
        exit when r(16) = '1';       -- DONE
        guard := guard + 1;
        assert guard < 40000
          report "FALLO: DONE no llego" severity failure;
      end loop;
    end procedure;

    -- firma en RAM local (word index)
    procedure store_sig(idx : integer; d : std_logic_vector(31 downto 0)) is
    begin
      bwr_v(std_logic_vector(to_unsigned(idx*4,32)), d);
    end procedure;

    variable s0,s1,s2,s3 : std_logic_vector(31 downto 0);
    variable acc : unsigned(15 downto 0);
    variable d0,d1,d2 : std_logic_vector(31 downto 0);
    -- verificacion de firma
    file fh : text;
    variable ln : line;
    variable expw : std_logic_vector(31 downto 0);
    variable open_ok : file_open_status;
  begin
    -- reset
    aresetn <= '0';
    wait for 200 ns;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 1 us;

    -- Paso 1: configurar
    ip_wr(O_RTAD, x"00000905");        -- RT1=9 (b12:8), RT0=5 (b4:0)
    ip_wr(O_CTRL, x"00000003");        -- EN + LOOP_INT
    wait for 3 us;

    ---------------------------------------------- Paso 2: BC->RT0 wc=4
    ip_wr(O_TXD, x"0000B100");
    ip_wr(O_TXD, x"0000B101");
    ip_wr(O_TXD, x"0000B102");
    ip_wr(O_TXD, x"0000B103");
    ip_wr(O_MSG, msgw(0,0,5,3,4,0,0));
    go_wait;
    ip_rd(O_RESULT, s0);
    store_sig(0, x"0000" & s0(15 downto 0));   -- sig[0]=stat1
    acc := (others => '0');
    for i in 0 to 3 loop
      ip_rd(O_RXD, r);
      assert r(31) = '1' report "FALLO P2: RXD sin valid" severity failure;
      acc := acc + unsigned(r(15 downto 0));
    end loop;
    store_sig(1, x"0000" & std_logic_vector(acc));  -- sig[1]=suma
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 20 us;

    ---------------------------------------------- Paso 3: RT0->BC wc=3
    ip_wr(O_TXD, x"0000E200");
    ip_wr(O_TXD, x"0000E201");
    ip_wr(O_TXD, x"0000E202");
    ip_wr(O_MSG, msgw(0,1,5,2,3,0,0));
    go_wait;
    ip_rd(O_RESULT, s0);
    store_sig(2, x"0000" & s0(15 downto 0));
    ip_rd(O_RXD, d0);
    ip_rd(O_RXD, d1);
    ip_rd(O_RXD, d2);
    store_sig(3, x"0000" & (d0(15 downto 0) xor d1(15 downto 0) xor d2(15 downto 0)));
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 20 us;

    ---------------------------------------------- Paso 4: RT0->RT1 wc=2
    ip_wr(O_TXD, x"0000F300");
    ip_wr(O_TXD, x"0000F301");
    ip_wr(O_MSG, msgw(1,0,5,4,2,9,4));
    go_wait;
    ip_rd(O_RESULT, s0);               -- b15:0 stat1, b31:16 stat2
    store_sig(4, s0);
    ip_rd(O_RXD, d0);
    ip_rd(O_RXD, d1);
    store_sig(5, x"0000" & (d0(15 downto 0) and d1(15 downto 0)));
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 20 us;

    ---------------------------------------------- Paso 5: broadcast wc=2
    ip_wr(O_TXD, x"0000B4B4");
    ip_wr(O_TXD, x"0000B5B5");
    ip_wr(O_MSG, msgw(0,0,31,6,2,0,0));
    go_wait;
    wait for 5 us;
    ip_rd(O_STAT, r);
    sig := 0;
    if r(26) = '1' then sig := sig + 2; end if;   -- RT0_BCR
    if r(27) = '1' then sig := sig + 1; end if;   -- RT1_BCR
    store_sig(6, std_logic_vector(to_unsigned(sig,32)));
    for i in 0 to 3 loop
      ip_rd(O_RXD, r);
      assert r(23) = '1' report "FALLO P5: RXD sin bcast" severity failure;
    end loop;
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 20 us;

    ---------------------------------------------- Paso 6: timeout (RT 12)
    ip_wr(O_MSG, msgw(0,1,12,2,2,0,0));
    go_wait;
    ip_rd(O_STAT, r);
    if r(18) = '1' then
      store_sig(7, x"0000DEAD");
    else
      store_sig(7, x"00000000");
    end if;
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 10 us;

    ---------------------------------------------- Paso 7: DMA doorbell
    -- volcar 8 palabras desde RAM local (word 0..7) a DDR
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#00#), x"00000000");   -- SRC = local 0
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#04#), x"00000000");   -- DST = DDR offset 0
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#08#), x"00000008");   -- LEN = 8
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#0C#), x"00000003");   -- CTRL: start + dir=1
    -- esperar a que el busy pegajoso baje
    guard := 0;
    loop
      brd_v(std_logic_vector(unsigned(DMAR) + 16#10#), r);
      exit when r(0) = '0';
      guard := guard + 1;
      assert guard < 10000 report "FALLO: DMA no termino" severity failure;
    end loop;
    wait for 2 us;

    ---------------------------------------------- comprobar firma vs ISS
    file_open(open_ok, fh, "iss_signature.txt", read_mode);
    assert open_ok = OPEN_OK
      report "FALLO: no se pudo abrir iss_signature.txt" severity failure;

    for i in 0 to 7 loop
      readline(fh, ln);
      hread(ln, expw);
      case i is
        when 0 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr0 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 0" severity failure;
        when 1 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr1 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 1" severity failure;
        when 2 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr2 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 2" severity failure;
        when 3 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr3 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 3" severity failure;
        when 4 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr4 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 4" severity failure;
        when 5 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr5 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 5" severity failure;
        when 6 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr6 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 6" severity failure;
        when 7 => assert << signal .tb_m1553_l4.u_mem.u_dma.dbg_ddr7 : word_t >> = expw
                    report "FALLO firma capa 4: palabra 7" severity failure;
      end case;
    end loop;
    file_close(fh);

    report "M1553 CAPA 4 PASS";
    finish;
  end process;

end architecture sim;
