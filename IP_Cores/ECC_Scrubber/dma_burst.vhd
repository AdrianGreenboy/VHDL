-- =============================================================================
--  dma_burst.vhd  -  Motor DMA con bursts AXI4 (DDR <-> RAM local)
--  Licencia: MIT
--
--  Mueve LEN palabras entre la DDR (via bursts AXI4) y la RAM local. El motor
--  TROCEA la transferencia en fronteras de 4 KB: AXI4 prohibe que un burst
--  cruce un limite de 4 KB, asi que cada burst se limita a las palabras que
--  quepan hasta el proximo 0x...000. Se emiten tantos bursts como haga falta.
--
--  Registros (desde el core):
--    src   : DDR (lectura) o indice local (escritura), byte address
--    dst   : indice local (lectura) o DDR (escritura), byte address
--    len   : numero total de palabras (1..256)
--    dir   : '0' = DDR->local ; '1' = local->DDR
--    start : pulso ; busy : '1' mientras transfiere
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity dma_burst is
  generic (
    ADDR_W   : natural := 40
  );
  port (
    clk      : in  std_logic;
    aresetn  : in  std_logic;
    ddr_base : in  std_logic_vector(ADDR_W-1 downto 0);

    src   : in  std_logic_vector(31 downto 0);
    dst   : in  std_logic_vector(31 downto 0);
    len   : in  std_logic_vector(8 downto 0);
    dir   : in  std_logic;
    start : in  std_logic;
    busy  : out std_logic;

    loc_addr  : out std_logic_vector(31 downto 0);
    loc_wdata : out word_t;
    loc_we    : out std_logic;
    loc_rdata : in  word_t;

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
end entity dma_burst;

architecture rtl of dma_burst is
  type state_t is (D_IDLE, D_CALC,
                   R_AR, R_DATA,
                   W_AW, W_DATA, W_RESP);
  signal state : state_t := D_IDLE;

  signal ddr_addr   : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal loc_idx    : unsigned(31 downto 0) := (others => '0');
  signal words_left : unsigned(8 downto 0) := (others => '0');  -- total restante
  signal burst_cnt  : unsigned(8 downto 0) := (others => '0');  -- palabras de este burst
  signal beats      : std_logic_vector(7 downto 0) := (others => '0');
  signal is_write   : std_logic := '0';

  -- palabras hasta la proxima frontera de 4 KB desde ddr_addr:
  --   (0x1000 - (ddr_addr mod 0x1000)) / 4
  signal words_to_4k : unsigned(10 downto 0);   -- 1..1024
begin

  m_axi_awsize  <= "010";
  m_axi_arsize  <= "010";
  m_axi_awburst <= "01";
  m_axi_arburst <= "01";
  m_axi_awlen   <= beats;
  m_axi_arlen   <= beats;
  m_axi_awaddr  <= std_logic_vector(ddr_addr);
  m_axi_araddr  <= std_logic_vector(ddr_addr);
  m_axi_wstrb   <= "1111";
  m_axi_wdata   <= loc_rdata;
  m_axi_wlast   <= '1' when (state = W_DATA and burst_cnt = 1) else '0';

  m_axi_awvalid <= '1' when state = W_AW   else '0';
  m_axi_wvalid  <= '1' when state = W_DATA else '0';
  m_axi_bready  <= '1' when state = W_RESP else '0';
  m_axi_arvalid <= '1' when state = R_AR   else '0';
  m_axi_rready  <= '1' when state = R_DATA else '0';

  busy <= '0' when state = D_IDLE else '1';

  loc_addr  <= std_logic_vector(loc_idx(29 downto 0) & "00");
  loc_wdata <= m_axi_rdata;
  loc_we    <= '1' when (state = R_DATA and m_axi_rvalid = '1') else '0';

  -- palabras hasta el proximo limite de 4 KB (1024 palabras/pagina). Se calcula
  -- sobre el indice de palabra ddr_addr(11:2) (0..1023) para evitar que el 4096
  -- se desborde al convertirse a 12 bits.
  words_to_4k <= 1024 - resize(unsigned(ddr_addr(11 downto 2)), 11);

  process(clk)
    variable this_burst : unsigned(8 downto 0);
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        state <= D_IDLE;
      else
        case state is
          when D_IDLE =>
            if start = '1' then
              words_left <= unsigned(len);
              is_write   <= dir;
              if dir = '0' then
                ddr_addr <= unsigned(ddr_base) + resize(unsigned(src(30 downto 0)), ADDR_W);
                loc_idx  <= unsigned(dst) srl 2;
              else
                ddr_addr <= unsigned(ddr_base) + resize(unsigned(dst(30 downto 0)), ADDR_W);
                loc_idx  <= unsigned(src) srl 2;
              end if;
              state <= D_CALC;
            end if;

          -- calcula el tamano del proximo burst (limitado a 4 KB)
          when D_CALC =>
            if words_left = 0 then
              state <= D_IDLE;
            else
              if resize(words_left, 11) <= words_to_4k then
                this_burst := words_left;
              else
                this_burst := resize(words_to_4k, 9);
              end if;
              burst_cnt <= this_burst;
              beats     <= std_logic_vector(resize(this_burst - 1, 8));
              if is_write = '0' then state <= R_AR; else state <= W_AW; end if;
            end if;

          -- lectura DDR -> local
          when R_AR =>
            if m_axi_arready = '1' then state <= R_DATA; end if;
          when R_DATA =>
            if m_axi_rvalid = '1' then
              loc_idx    <= loc_idx + 1;
              ddr_addr   <= ddr_addr + 4;
              burst_cnt  <= burst_cnt - 1;
              words_left <= words_left - 1;
              if m_axi_rlast = '1' then state <= D_CALC; end if;
            end if;

          -- escritura local -> DDR
          when W_AW =>
            if m_axi_awready = '1' then state <= W_DATA; end if;
          when W_DATA =>
            if m_axi_wready = '1' then
              loc_idx    <= loc_idx + 1;
              ddr_addr   <= ddr_addr + 4;
              burst_cnt  <= burst_cnt - 1;
              words_left <= words_left - 1;
              if burst_cnt = 1 then state <= W_RESP; end if;
            end if;
          when W_RESP =>
            if m_axi_bvalid = '1' then state <= D_CALC; end if;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
