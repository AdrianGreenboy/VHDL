-- rv64_axi_master.vhd - maestro AXI4 de 64 bit compartido por D$ (cliente 0,
-- prioridad) e I$ (cliente 1). Una transaccion en vuelo (spec v1).
--   RD_LINE / WR_LINE: rafaga INCR de 8 beats de 8 bytes (linea de 64 B)
--   RD_ONE  / WR_ONE : beat unico de 1/2/4/8 bytes (no cacheable, por carriles)
-- Errores SLVERR/DECERR se notifican al cliente en 'done'.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

package rv64_axi_pkg is
  constant AX_RD_LINE : std_logic_vector(1 downto 0) := "00";
  constant AX_WR_LINE : std_logic_vector(1 downto 0) := "01";
  constant AX_RD_ONE  : std_logic_vector(1 downto 0) := "10";
  constant AX_WR_ONE  : std_logic_vector(1 downto 0) := "11";
  subtype line_t is std_logic_vector(511 downto 0);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_axi_pkg.all;

entity rv64_axi_master is
  port (
    clk, rst : in std_logic;
    -- cliente 0: D$
    c0_req    : in  std_logic;
    c0_kind   : in  std_logic_vector(1 downto 0);
    c0_addr   : in  xword;
    c0_size   : in  std_logic_vector(1 downto 0);
    c0_wline  : in  line_t;
    c0_wdata  : in  xword;
    c0_wstrb  : in  std_logic_vector(7 downto 0);
    c0_cache  : in  std_logic;
    c0_beat   : out std_logic;                       -- beat de lectura (linea o unico)
    c0_done   : out std_logic;                       -- fin de transaccion (registrado)
    -- cliente 1: I$ (solo lecturas)
    c1_req    : in  std_logic;
    c1_kind   : in  std_logic_vector(1 downto 0);
    c1_addr   : in  xword;
    c1_size   : in  std_logic_vector(1 downto 0);
    c1_cache  : in  std_logic;
    c1_beat   : out std_logic;
    c1_done   : out std_logic;
    -- comun a ambos clientes
    beat_idx  : out std_logic_vector(2 downto 0);
    rdata     : out xword;
    err       : out std_logic;                       -- valido con done
    -- AXI4
    m_awid    : out std_logic_vector(3 downto 0);
    m_awaddr  : out xword;
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);
    m_awcache : out std_logic_vector(3 downto 0);
    m_awprot  : out std_logic_vector(2 downto 0);
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_wdata   : out xword;
    m_wstrb   : out std_logic_vector(7 downto 0);
    m_wlast   : out std_logic;
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_bid     : in  std_logic_vector(3 downto 0);
    m_bresp   : in  std_logic_vector(1 downto 0);
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic;
    m_arid    : out std_logic_vector(3 downto 0);
    m_araddr  : out xword;
    m_arlen   : out std_logic_vector(7 downto 0);
    m_arsize  : out std_logic_vector(2 downto 0);
    m_arburst : out std_logic_vector(1 downto 0);
    m_arcache : out std_logic_vector(3 downto 0);
    m_arprot  : out std_logic_vector(2 downto 0);
    m_arvalid : out std_logic;
    m_arready : in  std_logic;
    m_rid     : in  std_logic_vector(3 downto 0);
    m_rdata   : in  xword;
    m_rresp   : in  std_logic_vector(1 downto 0);
    m_rlast   : in  std_logic;
    m_rvalid  : in  std_logic;
    m_rready  : out std_logic
  );
end entity;

architecture rtl of rv64_axi_master is
  type st_t is (IDLE, AR, R, AW, W, B);
  signal st     : st_t;
  signal cli    : std_logic;                         -- 0: D$, 1: I$
  signal kind   : std_logic_vector(1 downto 0);
  signal addr   : xword;
  signal size   : std_logic_vector(1 downto 0);
  signal cache  : std_logic;
  signal wline  : line_t;
  signal wd     : xword;
  signal ws     : std_logic_vector(7 downto 0);
  signal beat   : unsigned(2 downto 0);
  signal errs   : std_logic;
  signal line_k : boolean;
begin
  line_k <= kind = AX_RD_LINE or kind = AX_WR_LINE;

  -- canal AR
  m_arid    <= "000" & cli;
  m_araddr  <= addr;
  m_arlen   <= x"07" when line_k else x"00";
  m_arsize  <= "011" when line_k else '0' & size;
  m_arburst <= "01";                                   -- INCR
  m_arcache <= "0011" when cache = '1' else "0000";
  m_arprot  <= "000";
  m_arvalid <= '1' when st = AR else '0';
  m_rready  <= '1' when st = R else '0';
  -- canales AW/W/B
  m_awid    <= "0000";
  m_awaddr  <= addr;
  m_awlen   <= x"07" when line_k else x"00";
  m_awsize  <= "011" when line_k else '0' & size;
  m_awburst <= "01";
  m_awcache <= "0011" when cache = '1' else "0000";
  m_awprot  <= "000";
  m_awvalid <= '1' when st = AW else '0';
  m_wvalid  <= '1' when st = W else '0';
  m_wdata   <= wline(64 * to_integer(beat) + 63 downto 64 * to_integer(beat)) when line_k else wd;
  m_wstrb   <= x"FF" when line_k else ws;
  m_wlast   <= '1' when (not line_k) or beat = 7 else '0';
  m_bready  <= '1' when st = B else '0';

  -- hacia los clientes
  beat_idx <= std_logic_vector(beat);
  rdata    <= m_rdata;
  c0_beat  <= '1' when st = R and m_rvalid = '1' and cli = '0' else '0';
  c1_beat  <= '1' when st = R and m_rvalid = '1' and cli = '1' else '0';

  process (clk)
    variable fin : boolean;
    variable e   : std_logic;
  begin
    if rising_edge(clk) then
      c0_done <= '0'; c1_done <= '0';
      if rst = '1' then
        st <= IDLE;
      else
        fin := false; e := errs;
        case st is
          when IDLE =>
            errs <= '0'; beat <= "000";
            -- no arrancar en el ciclo de 'done': el cliente aun no ha bajado su req
            if c0_done = '1' or c1_done = '1' then
              null;
            elsif c0_req = '1' then
              cli <= '0'; kind <= c0_kind; addr <= c0_addr; size <= c0_size; cache <= c0_cache;
              wline <= c0_wline; wd <= c0_wdata; ws <= c0_wstrb;
              if c0_kind(0) = '1' then st <= AW; else st <= AR; end if;
            elsif c1_req = '1' then
              cli <= '1'; kind <= c1_kind; addr <= c1_addr; size <= c1_size; cache <= c1_cache;
              st <= AR;
            end if;
          when AR =>
            if m_arready = '1' then st <= R; end if;
          when R =>
            if m_rvalid = '1' then
              e := errs or m_rresp(1);
              errs <= e;
              beat <= beat + 1;
              if m_rlast = '1' then fin := true; end if;
            end if;
          when AW =>
            if m_awready = '1' then st <= W; end if;
          when W =>
            if m_wready = '1' then
              if (not line_k) or beat = 7 then st <= B; end if;
              beat <= beat + 1;
            end if;
          when B =>
            if m_bvalid = '1' then
              e := errs or m_bresp(1);
              fin := true;
            end if;
        end case;
        if fin then
          err <= e;
          if cli = '0' then c0_done <= '1'; else c1_done <= '1'; end if;
          st <= IDLE;
        end if;
      end if;
    end if;
  end process;
end architecture;
