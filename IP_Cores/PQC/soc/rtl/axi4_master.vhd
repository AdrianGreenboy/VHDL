-- =============================================================================
--  axi4_master.vhd  -  Bridge maestro AXI4 (single-beat) para el core RISC-V
--  Licencia: MIT
--
--  Traduce un acceso simple del core (dir, dato, wstrb, we, req) en una
--  transaccion AXI4 de UN beat (AWLEN/ARLEN = 0) sobre los 5 canales, y
--  devuelve el dato leido con un pulso 'done'. Mientras la transaccion esta en
--  vuelo, 'busy' = '1' (el core se congela via dmem_ready = not busy).
--
--  Data de 32 bits, direccion configurable (ADDR_W). Un solo acceso a la vez.
--  Este bridge es la base; la version con bursts se agrega despues para el
--  motor de copia por bloques.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity axi4_master is
  generic (
    ADDR_W : natural := 40           -- direcciones de 40 bits (espacio del NoC)
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;

    -- lado del core (request simple)
    req     : in  std_logic;                         -- '1' inicia un acceso
    we      : in  std_logic;                         -- '1' = escritura
    addr    : in  std_logic_vector(ADDR_W-1 downto 0);
    wdata   : in  std_logic_vector(31 downto 0);
    wstrb   : in  std_logic_vector(3 downto 0);
    rdata   : out std_logic_vector(31 downto 0);
    done    : out std_logic;                         -- pulso 1 ciclo al terminar
    busy    : out std_logic;                         -- '1' mientras hay transaccion

    -- maestro AXI4 (32-bit data)
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
end entity axi4_master;

architecture rtl of axi4_master is
  type state_t is (S_IDLE,
                   S_AW, S_W, S_B,          -- escritura
                   S_AR, S_R);             -- lectura
  signal state : state_t := S_IDLE;

  signal addr_q  : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal wdata_q : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb_q : std_logic_vector(3 downto 0) := (others => '0');
  signal rdata_q : std_logic_vector(31 downto 0) := (others => '0');
begin

  -- constantes AXI4 para un beat de 32 bits
  m_axi_awlen   <= (others => '0');          -- 1 beat
  m_axi_arlen   <= (others => '0');
  m_axi_awsize  <= "010";                    -- 4 bytes
  m_axi_arsize  <= "010";
  m_axi_awburst <= "01";                     -- INCR
  m_axi_arburst <= "01";
  m_axi_wlast   <= '1';                      -- unico beat = last

  m_axi_awaddr <= addr_q;
  m_axi_araddr <= addr_q;
  m_axi_wdata  <= wdata_q;
  m_axi_wstrb  <= wstrb_q;
  rdata        <= rdata_q;

  busy <= '0' when state = S_IDLE else '1';

  m_axi_awvalid <= '1' when state = S_AW else '0';
  m_axi_wvalid  <= '1' when state = S_W  else '0';
  m_axi_bready  <= '1' when state = S_B  else '0';
  m_axi_arvalid <= '1' when state = S_AR else '0';
  m_axi_rready  <= '1' when state = S_R  else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        state <= S_IDLE;
        done  <= '0';
      else
        done <= '0';
        case state is
          when S_IDLE =>
            if req = '1' then
              addr_q  <= addr;
              wdata_q <= wdata;
              wstrb_q <= wstrb;
              if we = '1' then state <= S_AW; else state <= S_AR; end if;
            end if;

          -- escritura
          when S_AW =>
            if m_axi_awready = '1' then state <= S_W; end if;
          when S_W =>
            if m_axi_wready = '1' then state <= S_B; end if;
          when S_B =>
            if m_axi_bvalid = '1' then
              done  <= '1';
              state <= S_IDLE;
            end if;

          -- lectura
          when S_AR =>
            if m_axi_arready = '1' then state <= S_R; end if;
          when S_R =>
            if m_axi_rvalid = '1' then
              rdata_q <= m_axi_rdata;
              done    <= '1';
              state   <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
