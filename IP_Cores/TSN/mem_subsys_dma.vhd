-- =============================================================================
--  mem_subsys_dma.vhd  -  Subsistema de memoria con motor DMA (bursts)
--  Licencia: MIT
--
--  Le da al core:
--    region 0x0000_0000 (bits 31:30 = "00")  -> RAM local, 1 ciclo
--    region 0x4000_0000 (bits 31:28 = "0100")-> registros del DMA, 1 ciclo
--  El DMA es el maestro AXI (owns m_axi) y mueve bloques DDR<->local con bursts.
--
--  Registros DMA (offset desde 0x4000_0000):
--    0x00 SRC   (w)   0x04 DST   (w)   0x08 LEN (w, 1..256)
--    0x0C CTRL  (w)   bit0=start, bit1=dir (0=DDR->local, 1=local->DDR)
--    0x10 STATUS(r)   bit0=busy   (busy PEGAJOSO: alto desde el start hasta que
--                                  el DMA de verdad termina, sin ventana falsa)
--
--  Audit 2026-11 (TSN-local copy):
--    * every register write (DMA regs and TSN switch) is qualified by
--      dmem_req (v1 decoded dmem_wstrb/dmem_addr even when no request was
--      issued: a stale address/strobe could start a DMA or write a register);
--    * DMA registers honour dmem_wstrb byte lanes (sb/sh update only the
--      addressed bytes; CTRL.start needs byte lane 0);
--    * TSN switch registers are 32-bit only: a partial store (wstrb not
--      "1111") is ignored instead of writing a word with garbage lanes.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity mem_subsys_dma is
  generic (
    DEPTH    : natural := 256;
    INIT_FILE: string  := "";
    ADDR_W   : natural := 40
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    ddr_base : in std_logic_vector(ADDR_W-1 downto 0);  -- base DDR (runtime)

    dmem_addr  : in  word_t;
    dmem_wdata : in  word_t;
    dmem_wstrb : in  std_logic_vector(3 downto 0);
    dmem_req   : in  std_logic;
    dmem_rdata : out word_t;
    dmem_ready : out std_logic;

    -- maestro AXI4 hacia la DDR (lo maneja el DMA)
    m_axi_awaddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    m_axi_araddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic

  );
end entity mem_subsys_dma;

architecture rtl of mem_subsys_dma is
  signal is_local, is_dmareg, is_tsn : std_logic;
  signal tsn_rdata : word_t;
  signal tsn_txd  : work.tsn_pkg.byte_arr4;
  signal tsn_txen : std_logic_vector(3 downto 0);
  signal loc_rdata  : word_t;
  signal cpu_wstrb  : std_logic_vector(3 downto 0);
  signal dmareg_rdata : word_t;

  -- registros DMA
  signal dma_src, dma_dst : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_len : std_logic_vector(8 downto 0) := (others => '0');
  signal dma_dir : std_logic := '0';
  signal dma_start, dma_busy : std_logic;
  signal dma_go, busy_sticky, dma_started : std_logic := '0';

  -- puerto DMA <-> RAM local
  signal dloc_addr  : std_logic_vector(31 downto 0);
  signal dloc_wdata : word_t;
  signal dloc_we    : std_logic;
  signal dloc_rdata : word_t;
  signal dloc_wstrb : std_logic_vector(3 downto 0);
  signal wr_req     : std_logic;                     -- qualified store
  signal tsn_we     : std_logic;

  -- byte-lane merge for the DMA registers
  function merge(old, new_v : std_logic_vector(31 downto 0);
                 st : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(31 downto 0) := old;
  begin
    for b in 0 to 3 loop
      if st(b) = '1' then r(b*8+7 downto b*8) := new_v(b*8+7 downto b*8); end if;
    end loop;
    return r;
  end function;
begin
  wr_req <= '1' when dmem_req = '1' and dmem_wstrb /= "0000" else '0';
  tsn_we <= '1' when dmem_req = '1' and dmem_wstrb = "1111" else '0';

  is_local  <= '1' when dmem_addr(31 downto 30) = "00"   else '0';
  is_dmareg <= '1' when dmem_addr(31 downto 28) = "0100" else '0';
  is_tsn    <= '1' when dmem_addr(31 downto 28) = "0110" else '0';   -- 0x6000_0000

  -- deteccion combinacional del "start" (sw a CTRL con bit0=1)
  dma_go <= '1' when (is_dmareg = '1' and wr_req = '1' and dmem_wstrb(0) = '1'
                      and dmem_addr(7 downto 0) = x"0C" and dmem_wdata(0) = '1')
            else '0';

  -- RAM local de doble puerto: cpu=core, axi=DMA
  cpu_wstrb <= dmem_wstrb when is_local = '1' else "0000";
  dloc_wstrb <= "1111" when dloc_we = '1' else "0000";

  u_local : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => INIT_FILE)
    port map (
      clk => clk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => cpu_wstrb,
      cpu_rdata => loc_rdata,
      axi_addr => dloc_addr, axi_wdata => dloc_wdata, axi_wstrb => dloc_wstrb,
      axi_rdata => dloc_rdata, axi_owns => dma_busy
    );

  u_dma : entity work.dma_burst
    generic map (ADDR_W => ADDR_W)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      src => dma_src, dst => dma_dst, len => dma_len, dir => dma_dir,
      start => dma_start, busy => dma_busy,
      loc_addr => dloc_addr, loc_wdata => dloc_wdata, loc_we => dloc_we, loc_rdata => dloc_rdata,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready
    );



  -- switch TSN 4x4 (esclavo dmem directo de 1 ciclo, patron tipo DSP):
  -- region 0x6000_0000; rst activo alto sincrono <- not aresetn; genera
  -- mii_ce interno y fija rx_src=inyector. rdata combinacional.
  u_tsn : entity work.tsn_soc
    port map (
      clk   => clk,
      rst   => not aresetn,
      sel   => (dmem_req and is_tsn),
      we    => (is_tsn and tsn_we),
      addr  => dmem_addr(8 downto 0),
      wdata => dmem_wdata,
      rdata => tsn_rdata,
      ready => open,
      irq   => open,
      mii_txd => tsn_txd, mii_tx_en => tsn_txen);

  -- escritura de registros DMA + pulso de start + busy pegajoso
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        dma_src <= (others => '0'); dma_dst <= (others => '0');
        dma_len <= (others => '0'); dma_dir <= '0'; dma_start <= '0';
        busy_sticky <= '0'; dma_started <= '0';
      else
        dma_start <= '0';
        if is_dmareg = '1' and wr_req = '1' then
          case dmem_addr(7 downto 0) is
            when x"00" => dma_src <= merge(dma_src, dmem_wdata, dmem_wstrb);
            when x"04" => dma_dst <= merge(dma_dst, dmem_wdata, dmem_wstrb);
            when x"08" =>
              if dmem_wstrb(0) = '1' then dma_len(7 downto 0) <= dmem_wdata(7 downto 0); end if;
              if dmem_wstrb(1) = '1' then dma_len(8) <= dmem_wdata(8); end if;
            when x"0C" =>
              if dmem_wstrb(0) = '1' then
                dma_dir <= dmem_wdata(1);
                if dmem_wdata(0) = '1' then dma_start <= '1'; end if;
              end if;
            when others => null;
          end case;
        end if;

        -- busy pegajoso: se pone alto al detectar el start (combinacional, mismo
        -- ciclo que el sw CTRL) y se baja solo cuando el DMA de verdad terminó.
        if dma_go = '1' then
          busy_sticky <= '1';
        end if;
        if dma_busy = '1' then
          dma_started <= '1';
        elsif dma_started = '1' then      -- el DMA estuvo activo y ya volvió a idle
          busy_sticky <= '0';
          dma_started <= '0';
        end if;
      end if;
    end if;
  end process;

  -- lectura de STATUS (reporta el busy pegajoso)
  dmareg_rdata <= (0 => busy_sticky, others => '0')
                  when dmem_addr(7 downto 0) = x"10" else (others => '0');

  -- rdata y ready hacia el core (local y registros DMA son de 1 ciclo)
  dmem_rdata <= loc_rdata    when is_local  = '1' else
                dmareg_rdata when is_dmareg = '1' else
                tsn_rdata    when is_tsn    = '1' else
                (others => '0');
  -- el TSN es esclavo de 1 ciclo (rdata combinacional): sin wait-states.
  dmem_ready <= '1';

end architecture rtl;
