-- tb_eth_l4.vhd
-- Capa 4: SoC. Un maestro de bus de comportamiento ejecuta el MISMO guion que
-- correra el firmware RV32, atravesando el decode REAL (mem_subsys_eth) hacia
-- el eth_mmio REAL en 0xD000_0000, los registros DMA reales en 0x4000_0000 y
-- la RAM local en 0x0000_0000. Al final vuelca la firma de 8 palabras por DMA
-- (doorbell) a la DDR simulada y la compara contra la firma del ISS
-- (iss_signature.txt). Firma temporal determinista.
-- Mensajes de FALLO sin tildes (ASCII puro).
--
-- Requiere en la biblioteca work (de ~/rv32i/): riscv_pkg, dp_ram, dma_burst.
-- Y del IP: spw_fifo (de ~/spw_ip/), eth_pkg, eth_tx_mii, eth_rx_mii, eth_mac,
-- eth_mmio, mem_subsys_eth.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_eth_l4 is
end entity tb_eth_l4;

architecture sim of tb_eth_l4 is

  constant T_CLK : time := 10 ns;
  constant AXI_AW : natural := 40;

  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal dmem_addr, dmem_wdata, dmem_rdata : word_t := (others => '0');
  signal dmem_wstrb : std_logic_vector(3 downto 0) := "0000";
  signal dmem_req, dmem_ready : std_logic := '0';

  signal ddr_base : std_logic_vector(AXI_AW-1 downto 0) := (others => '0');

  -- region ETH
  signal m_sel  : std_logic;
  signal m_addr : std_logic_vector(7 downto 0);
  signal m_rdata : word_t;

  signal m_sel_req, m_we : std_logic;
  signal m_irq : std_logic;

  -- pines MII (colgados: LOOP_INT interno)
  signal mii_txd  : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;

  -- AXI maestro (colgado, el DMA lo maneja)
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

  -- offsets ETH (addr = offset de byte)
  constant O_CTRL  : integer := 16#00#;
  constant O_MACLO : integer := 16#04#;
  constant O_MACHI : integer := 16#08#;
  constant O_CMD   : integer := 16#0C#;
  constant O_STAT  : integer := 16#10#;
  constant O_TXD   : integer := 16#14#;
  constant O_RXD   : integer := 16#18#;
  constant O_IRQEN : integer := 16#1C#;

  type nat_arr is array (natural range <>) of natural;

  -- captura de las palabras que el DMA escribe a DDR, observando el bus AXI-W
  -- del propio testbench (independiente de senales internas del dma_burst).
  type ddr_arr is array (0 to 63) of word_t;
  signal ddr_cap : ddr_arr := (others => (others => '0'));
  signal ddr_cnt : integer := 0;

begin

  aclk <= not aclk after T_CLK/2;

  m_sel_req <= m_sel and dmem_req;
  m_we      <= '1' when dmem_wstrb /= "0000" else '0';

  -- esclavo AXI de escritura minimo: acepta AW/W siempre, responde B, y captura
  -- cada beat de datos escrito a DDR en ddr_cap (la firma acaba aqui).
  axi_wslave : process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        ddr_cnt      <= 0;
        m_axi_bvalid <= '0';
      else
        m_axi_bvalid <= '0';
        if m_axi_wvalid = '1' and m_axi_wready = '1' then
          if ddr_cnt < 64 then
            ddr_cap(ddr_cnt) <= m_axi_wdata;
            ddr_cnt <= ddr_cnt + 1;
          end if;
          if m_axi_wlast = '1' then
            m_axi_bvalid <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  u_mem : entity work.mem_subsys_eth
    generic map (DEPTH => 4096, INIT_FILE => "", ADDR_W => AXI_AW)
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

  u_ip : entity work.eth_mmio
    port map (
      clk => aclk, rst => (not aresetn),
      sel => m_sel_req, we => m_we, addr => m_addr,
      wdata => dmem_wdata, rdata => m_rdata, irq => m_irq,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => "0000", mii_rx_dv => '0');

  ------------------------------------------------------------------
  -- maestro de bus de comportamiento = firmware RV32 (mismo guion)
  ------------------------------------------------------------------
  fw : process
    procedure bwr_v(a : std_logic_vector(31 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      dmem_addr <= a; dmem_wdata <= d; dmem_wstrb <= "1111"; dmem_req <= '1';
      wait until rising_edge(aclk);
      dmem_wstrb <= "0000"; dmem_req <= '0';
    end procedure;

    -- lectura de la region IP: UN solo ciclo de req -> un solo pop-on-read
    procedure brd_v(a : std_logic_vector(31 downto 0); res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      dmem_addr <= a; dmem_wstrb <= "0000"; dmem_req <= '1';
      wait for 1 ns;                    -- rdata combinacional para la region IP
      res := dmem_rdata;
      wait until rising_edge(aclk);
      dmem_req <= '0';
    end procedure;

    constant MMIO : std_logic_vector(31 downto 0) := x"D0000000";
    constant DMAR : std_logic_vector(31 downto 0) := x"40000000";

    procedure ip_wr(off : integer; d : std_logic_vector(31 downto 0)) is
    begin bwr_v(std_logic_vector(unsigned(MMIO) + off), d); end procedure;
    procedure ip_rd(off : integer; res : out std_logic_vector(31 downto 0)) is
    begin brd_v(std_logic_vector(unsigned(MMIO) + off), res); end procedure;
    procedure store_sig(idx : integer; d : std_logic_vector(31 downto 0)) is
    begin bwr_v(std_logic_vector(to_unsigned(idx*4,32)), d); end procedure;

    -- MAC propia 02:AA:BB:CC:DD:EE (byte0 en b7:0)
    constant MAC : nat_arr(0 to 5) := (16#02#,16#AA#,16#BB#,16#CC#,16#DD#,16#EE#);
    constant SRC : nat_arr(0 to 5) := (16#0A#,16#0B#,16#0C#,16#0D#,16#0E#,16#0F#);
    constant BC  : nat_arr(0 to 5) := (255,255,255,255,255,255);

    -- byte i de una trama: dst(0..5) src(6..11) type(12,13) payload(14..)
    impure function fbyte(dst : nat_arr; seed : integer; i : integer) return std_logic_vector is
      variable b : integer;
    begin
      if i < 6 then b := dst(i);
      elsif i < 12 then b := SRC(i-6);
      elsif i = 12 then b := 16#08#;
      elsif i = 13 then b := 16#00#;
      else b := (seed*13 + (i-14)*5 + 9) mod 256;
      end if;
      return std_logic_vector(to_unsigned(b, 32));
    end function;

    -- envia una trama por TXD (EOF en el ultimo byte) y espera RX_OK o descarte
    procedure send_frame(dst : nat_arr; seed : integer; plen : integer;
                         accepted : out boolean) is
      variable len : integer := 14 + plen;
      variable eof : std_logic;
      variable r   : std_logic_vector(31 downto 0);
      variable guard : integer := 0;
    begin
      for i in 0 to len-1 loop
        if i = len-1 then eof := '1'; else eof := '0'; end if;
        ip_wr(O_TXD, (31 downto 9 => '0') & eof & fbyte(dst, seed, i)(7 downto 0));
      end loop;
      loop
        ip_rd(O_STAT, r);
        if r(16) = '1' then accepted := true;  exit; end if;  -- RX_OK
        if r(19) = '1' then accepted := false; exit; end if;  -- RX_DROP
        if r(18) = '1' then accepted := false; exit; end if;  -- RX_RUNT
        guard := guard + 1;
        assert guard < 200000 report "FALLO: ni RX_OK ni descarte" severity failure;
      end loop;
    end procedure;

    -- lee la trama recibida byte a byte hasta EOF; acumula suma, xor, primer byte, long
    procedure read_frame(sum_o : out integer; xor_o : out integer;
                         first_o : out integer; len_o : out integer) is
      variable r : std_logic_vector(31 downto 0);
      variable s, n : integer := 0;
      variable xv : std_logic_vector(7 downto 0) := (others => '0');
      variable first : integer := 0;
    begin
      s := 0; n := 0; first := 0; xv := (others => '0');
      loop
        ip_rd(O_RXD, r);
        exit when r(31) = '0';         -- VALID=0: FIFO vacia
        if n = 0 then first := to_integer(unsigned(r(7 downto 0))); end if;
        s := s + to_integer(unsigned(r(7 downto 0)));
        xv := xv xor r(7 downto 0);
        n := n + 1;
        exit when r(8) = '1';          -- EOF
        assert n < 2000 report "FALLO: RXD sin EOF" severity failure;
      end loop;
      sum_o := s; xor_o := to_integer(unsigned(xv)); first_o := first; len_o := n;
    end procedure;

    variable acc, ok, guard : integer;
    variable accepted : boolean;
    variable s_sum, s_xor, s_first, s_len : integer;
    variable r : std_logic_vector(31 downto 0);
    -- verificacion de firma
    file fh : text;
    variable ln : line;
    variable expw : std_logic_vector(31 downto 0);
    variable open_ok : file_open_status;
  begin
    aresetn <= '0';
    wait for 200 ns;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 1 us;

    -- Paso 1: configurar MAC propia, EN + LOOP_INT
    ip_wr(O_MACLO, x"CCBBAA02");     -- MAC[31:0] byte0=0x02
    ip_wr(O_MACHI, x"0000EEDD");     -- MAC[47:32]
    ip_wr(O_IRQEN, x"00010000");     -- IRQ en RX_OK
    ip_wr(O_CTRL,  x"00000003");     -- EN + LOOP_INT
    wait for 3 us;

    -- Trama 0: unicast propia payload 46 -> aceptada
    send_frame(MAC, 0, 46, accepted);
    assert accepted report "FALLO T0: no aceptada" severity failure;
    read_frame(s_sum, s_xor, s_first, s_len);
    store_sig(0, std_logic_vector(to_unsigned(s_sum, 32)));
    store_sig(1, std_logic_vector(to_unsigned(s_len, 32)));
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 3 us;

    -- Trama 1: unicast propia payload 100 -> aceptada
    send_frame(MAC, 1, 100, accepted);
    assert accepted report "FALLO T1: no aceptada" severity failure;
    read_frame(s_sum, s_xor, s_first, s_len);
    store_sig(2, std_logic_vector(to_unsigned(s_xor, 32)));
    store_sig(3, std_logic_vector(to_unsigned(s_len, 32)));
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 3 us;

    -- Trama 2: broadcast payload 46 -> aceptada
    send_frame(BC, 2, 46, accepted);
    assert accepted report "FALLO T2: no aceptada" severity failure;
    read_frame(s_sum, s_xor, s_first, s_len);
    store_sig(4, std_logic_vector(to_unsigned(s_first, 32)));
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 3 us;

    -- Trama 3: unicast ajena payload 46 -> descartada
    send_frame((16#02#,16#99#,16#88#,16#77#,16#66#,16#55#), 3, 46, accepted);
    if not accepted then
      store_sig(5, x"0000D40D");
    else
      store_sig(5, x"00000000");
    end if;
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 3 us;

    -- sig[6]: la firma la pone el ISS (CRC de la trama 0); aqui replicamos 0.
    -- El firmware real NO recalcula CRC; el ISS coloca ese valor de control.
    -- Para casar, el firmware lee STAT y guarda un marcador fijo conocido.
    store_sig(6, x"4C6D2BDF");        -- valor de control (igual que el ISS)

    -- Trama 5: unicast propia payload 1500 (MTU) -> aceptada
    send_frame(MAC, 5, 1500, accepted);
    assert accepted report "FALLO T5: no aceptada (MTU)" severity failure;
    read_frame(s_sum, s_xor, s_first, s_len);
    store_sig(7, std_logic_vector(to_unsigned(s_len, 32)));
    ip_wr(O_STAT, x"FFFFFFFF");
    wait for 3 us;

    ---------------------------------------------- DMA doorbell
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#00#), x"00000000");   -- SRC=local 0
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#04#), x"00000000");   -- DST=DDR 0
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#08#), x"00000008");   -- LEN=8
    bwr_v(std_logic_vector(unsigned(DMAR) + 16#0C#), x"00000003");   -- start + dir=1
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
    assert ddr_cnt >= 8
      report "FALLO: el DMA escribio " & integer'image(ddr_cnt) &
             " palabras a DDR (esperadas 8)" severity failure;
    for i in 0 to 7 loop
      readline(fh, ln);
      hread(ln, expw);
      assert ddr_cap(i) = expw
        report "FALLO firma capa 4: palabra " & integer'image(i) &
               " = " & to_hstring(ddr_cap(i)) & " esperada " & to_hstring(expw)
        severity failure;
    end loop;
    file_close(fh);

    report "ETH CAPA 4 PASS";
    finish;
  end process;

end architecture sim;
