-- soc_stubs_l4.vhd
-- Modelos de comportamiento de dp_ram y dma_burst con las interfaces EXACTAS
-- que instancia mem_subsys_m1553, para una simulacion de capa 4 autocontenida
-- (sin depender del cpu_pipeline/axil_soc reales). El programa lo ejecuta un
-- maestro de bus de comportamiento en el testbench, replicando el decode real.
-- El DMA modela el volcado local->DDR escribiendo en una memoria DDR simulada
-- accesible por el testbench via una senal jerarquica.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

-- --------------------------------------------------------------------------
-- dp_ram: RAM de doble puerto (core + DMA). El puerto axi gana cuando axi_owns.
-- --------------------------------------------------------------------------
entity dp_ram is
  generic (
    DEPTH     : natural := 256;
    INIT_FILE : string  := ""
  );
  port (
    clk       : in  std_logic;
    cpu_addr  : in  word_t;
    cpu_wdata : in  word_t;
    cpu_wstrb : in  std_logic_vector(3 downto 0);
    cpu_rdata : out word_t;
    axi_addr  : in  std_logic_vector(31 downto 0);
    axi_wdata : in  word_t;
    axi_wstrb : in  std_logic_vector(3 downto 0);
    axi_rdata : out word_t;
    axi_owns  : in  std_logic
  );
end entity dp_ram;

architecture beh of dp_ram is
  type mem_t is array (0 to DEPTH-1) of word_t;
  signal mem : mem_t := (others => (others => '0'));
  function widx(a : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(a(31 downto 2))) mod DEPTH;
  end function;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      -- puerto CPU
      if cpu_wstrb /= "0000" then
        mem(widx(cpu_addr)) <= cpu_wdata;
      end if;
      cpu_rdata <= mem(widx(cpu_addr));
      -- puerto AXI/DMA
      if axi_wstrb /= "0000" then
        mem(widx(axi_addr)) <= axi_wdata;
      end if;
      axi_rdata <= mem(widx(axi_addr));
    end if;
  end process;
end architecture beh;


-- --------------------------------------------------------------------------
-- dma_burst: modelo funcional. Copia len palabras entre RAM local y una DDR
-- simulada interna. dir: 0 = DDR->local, 1 = local->DDR. Expone la DDR
-- simulada por senal jerarquica ddr_mem para que el testbench la lea.
-- --------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity dma_burst is
  generic (ADDR_W : natural := 40);
  port (
    clk      : in  std_logic;
    aresetn  : in  std_logic;
    ddr_base : in  std_logic_vector(ADDR_W-1 downto 0);
    src      : in  std_logic_vector(31 downto 0);
    dst      : in  std_logic_vector(31 downto 0);
    len      : in  std_logic_vector(8 downto 0);
    dir      : in  std_logic;
    start    : in  std_logic;
    busy     : out std_logic;
    loc_addr : out std_logic_vector(31 downto 0);
    loc_wdata: out word_t;
    loc_we   : out std_logic;
    loc_rdata: in  word_t;
    -- maestro AXI (no usado en el modelo funcional)
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
    m_axi_rready  : out std_logic;
    -- sim-only: lectura de las primeras 8 palabras de la DDR simulada
    dbg_ddr0 : out word_t := (others=>'0');
    dbg_ddr1 : out word_t := (others=>'0');
    dbg_ddr2 : out word_t := (others=>'0');
    dbg_ddr3 : out word_t := (others=>'0');
    dbg_ddr4 : out word_t := (others=>'0');
    dbg_ddr5 : out word_t := (others=>'0');
    dbg_ddr6 : out word_t := (others=>'0');
    dbg_ddr7 : out word_t := (others=>'0')
  );
end entity dma_burst;

architecture beh of dma_burst is
  type ddr_t is array (0 to 255) of word_t;
  signal ddr_mem : ddr_t := (others => (others => '0'));
  type st_t is (IDLE, READL, WRITEL, DONE1);
  signal st : st_t := IDLE;
  signal cnt : integer range 0 to 512 := 0;
  signal la  : unsigned(31 downto 0);
  signal da  : unsigned(31 downto 0);
begin
  m_axi_awaddr <= (others=>'0'); m_axi_awlen<=(others=>'0'); m_axi_awsize<=(others=>'0');
  m_axi_awburst<=(others=>'0'); m_axi_awvalid<='0'; m_axi_wdata<=(others=>'0');
  m_axi_wstrb<=(others=>'0'); m_axi_wlast<='0'; m_axi_wvalid<='0'; m_axi_bready<='1';
  m_axi_araddr<=(others=>'0'); m_axi_arlen<=(others=>'0'); m_axi_arsize<=(others=>'0');
  m_axi_arburst<=(others=>'0'); m_axi_arvalid<='0'; m_axi_rready<='1';

  dbg_ddr0 <= ddr_mem(0); dbg_ddr1 <= ddr_mem(1);
  dbg_ddr2 <= ddr_mem(2); dbg_ddr3 <= ddr_mem(3);
  dbg_ddr4 <= ddr_mem(4); dbg_ddr5 <= ddr_mem(5);
  dbg_ddr6 <= ddr_mem(6); dbg_ddr7 <= ddr_mem(7);

  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        st <= IDLE; busy <= '0'; loc_we <= '0'; cnt <= 0;
      else
        loc_we <= '0';
        case st is
          when IDLE =>
            if start = '1' then
              busy <= '1';
              cnt  <= 0;
              la   <= unsigned(src);
              da   <= unsigned(dst);
              -- direccionar la primera lectura local
              loc_addr <= src;
              st <= READL;
            else
              busy <= '0';
            end if;
          when READL =>
            -- loc_rdata refleja la palabra local (registrada); en dir=1 copiar
            -- local->DDR. Se usa solo el sentido local->DDR en este test.
            loc_addr <= std_logic_vector(la);
            st <= WRITEL;
          when WRITEL =>
            ddr_mem(to_integer(da(9 downto 2)) mod 256) <= loc_rdata;
            cnt <= cnt + 1;
            if cnt + 1 >= to_integer(unsigned(len)) then
              st <= DONE1;
            else
              la <= la + 4;
              da <= da + 4;
              loc_addr <= std_logic_vector(la + 4);
              st <= READL;
            end if;
          when DONE1 =>
            busy <= '0';
            st <= IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture beh;
