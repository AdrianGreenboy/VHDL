-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Puente MMIO -> AXI4-Lite: conecta la ventana dmem del RV32 (interfaz simple
-- sel/we/addr/wdata/rdata/ready) al esclavo AXI4-Lite del pcs_stats_top.
--
-- El CPU asserta dmem_req y se ESTANCA hasta que ready='1'; el puente ejecuta
-- la transaccion AXI completa (AW+W...B para escritura, AR...R para lectura) y
-- asserta ready exactamente 1 ciclo, presentando rdata capturado EN EL MISMO
-- ciclo que ready (contrato del dmem: rdata combinacionalmente valido con
-- ready; un rdata registrado un ciclo tarde pasa tests unitarios pero rompe
-- cada lw en el SoC).
--
-- Ambos lados en aclk (el banco del PCS corre en el dominio AXI; clk_dp es
-- interno al pcs_stats_top).
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_mmio_bridge is
  port (
    clk      : in  std_logic;
    aresetn  : in  std_logic;

    -- lado MMIO (ventana dmem del RV32)
    sel      : in  std_logic;                       -- region seleccionada y req
    wstrb    : in  std_logic_vector(3 downto 0);    -- /="0000" => escritura
    addr     : in  std_logic_vector(7 downto 0);    -- offset de registro
    wdata    : in  std_logic_vector(31 downto 0);
    rdata    : out std_logic_vector(31 downto 0);
    ready    : out std_logic;

    -- lado maestro AXI4-Lite (hacia pcs_stats_top)
    m_awaddr : out std_logic_vector(7 downto 0);
    m_awvalid: out std_logic;
    m_awready: in  std_logic;
    m_wdata  : out std_logic_vector(31 downto 0);
    m_wstrb  : out std_logic_vector(3 downto 0);
    m_wvalid : out std_logic;
    m_wready : in  std_logic;
    m_bresp  : in  std_logic_vector(1 downto 0);
    m_bvalid : in  std_logic;
    m_bready : out std_logic;
    m_araddr : out std_logic_vector(7 downto 0);
    m_arvalid: out std_logic;
    m_arready: in  std_logic;
    m_rdata  : in  std_logic_vector(31 downto 0);
    m_rresp  : in  std_logic_vector(1 downto 0);
    m_rvalid : in  std_logic;
    m_rready : out std_logic
  );
end entity pcs_mmio_bridge;

architecture rtl of pcs_mmio_bridge is
  type st_t is (IDLE, WR_AW, WR_B, RD_AR, RD_R, RESP);
  signal st : st_t := IDLE;
  signal aw_done, w_done : std_logic := '0';
  signal rdata_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal addr_lat  : std_logic_vector(7 downto 0) := (others => '0');
  signal wdata_lat : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb_lat : std_logic_vector(3 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        st <= IDLE; aw_done <= '0'; w_done <= '0';
        rdata_reg <= (others => '0');
      else
        case st is
          when IDLE =>
            if sel = '1' then
              addr_lat  <= addr;
              wdata_lat <= wdata;
              wstrb_lat <= wstrb;
              aw_done   <= '0';
              w_done    <= '0';
              if wstrb /= "0000" then st <= WR_AW; else st <= RD_AR; end if;
            end if;
          when WR_AW =>
            if m_awready = '1' and aw_done = '0' then aw_done <= '1'; end if;
            if m_wready  = '1' and w_done  = '0' then w_done  <= '1'; end if;
            if (aw_done = '1' or m_awready = '1') and
               (w_done  = '1' or m_wready  = '1') then
              st <= WR_B;
            end if;
          when WR_B =>
            if m_bvalid = '1' then st <= RESP; end if;
          when RD_AR =>
            if m_arready = '1' then st <= RD_R; end if;
          when RD_R =>
            if m_rvalid = '1' then
              rdata_reg <= m_rdata;
              st <= RESP;
            end if;
          when RESP =>
            st <= IDLE;   -- ready se asserta este ciclo (combinacional abajo)
        end case;
      end if;
    end if;
  end process;

  -- lado AXI: valids sostenidos hasta handshake
  m_awaddr  <= addr_lat;
  m_awvalid <= '1' when (st = WR_AW and aw_done = '0') else '0';
  m_wdata   <= wdata_lat;
  m_wstrb   <= wstrb_lat;
  m_wvalid  <= '1' when (st = WR_AW and w_done = '0') else '0';
  m_bready  <= '1' when st = WR_B else '0';
  m_araddr  <= addr_lat;
  m_arvalid <= '1' when st = RD_AR else '0';
  m_rready  <= '1' when st = RD_R else '0';

  -- lado MMIO: ready 1 ciclo con rdata estable en ese mismo ciclo
  ready <= '1' when st = RESP else '0';
  rdata <= rdata_reg;

end architecture rtl;
