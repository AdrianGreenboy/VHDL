-- rv128_axi_master.vhd - maestro AXI4 de 128 bit compartido por D$ (cliente 0,
-- prioridad) e I$ (cliente 1). Una transaccion en vuelo (igual que rv64_axi_master).
--   RD_LINE / WR_LINE: rafaga INCR de 4 beats de 16 bytes (linea de 64 B)
--   RD_ONE  / WR_ONE : beat unico de 1/2/4/8/16 bytes (no cacheable, por carriles)
-- Direcciones AXI de 64 bit: la PMA garantiza PA[127:32] = 0 en toda transaccion.
-- Errores SLVERR/DECERR se notifican al cliente en 'done'.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;

package rv128_axi_pkg is
  constant AX_RD_LINE : std_logic_vector(1 downto 0) := "00";
  constant AX_WR_LINE : std_logic_vector(1 downto 0) := "01";
  constant AX_RD_ONE  : std_logic_vector(1 downto 0) := "10";
  constant AX_WR_ONE  : std_logic_vector(1 downto 0) := "11";
  subtype line_t is std_logic_vector(511 downto 0);
  subtype aaddr_t is std_logic_vector(63 downto 0);  -- direccion AXI
  subtype dword is std_logic_vector(63 downto 0);    -- registros de 64 bit de los perifericos
  constant DZERO : dword := (others => '0');
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;
use work.rv128_axi_pkg.all;

entity rv128_axi_master is
  port (
    clk, rst : in std_logic;
    -- cliente 0: D$
    c0_req    : in  std_logic;
    c0_kind   : in  std_logic_vector(1 downto 0);
    c0_addr   : in  xword;
    c0_size   : in  std_logic_vector(2 downto 0);
    c0_wline  : in  line_t;
    c0_wdata  : in  xword;
    c0_wstrb  : in  std_logic_vector(15 downto 0);
    c0_cache  : in  std_logic;
    c0_beat   : out std_logic;                       -- beat de lectura (linea o unico)
    c0_done   : out std_logic;                       -- fin de transaccion (registrado)
    c0_acc    : out std_logic;                       -- este ciclo se acepta la peticion de c0
    -- cliente 1: I$ (solo lecturas)
    c1_req    : in  std_logic;
    c1_kind   : in  std_logic_vector(1 downto 0);
    c1_addr   : in  xword;
    c1_size   : in  std_logic_vector(2 downto 0);
    c1_cache  : in  std_logic;
    c1_beat   : out std_logic;
    c1_done   : out std_logic;
    -- comun a ambos clientes
    beat_idx  : out std_logic_vector(1 downto 0);
    rdata     : out xword;
    err       : out std_logic;                       -- valido con done
    -- AXI4
    m_awid    : out std_logic_vector(3 downto 0);
    m_awaddr  : out aaddr_t;
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);
    m_awcache : out std_logic_vector(3 downto 0);
    m_awprot  : out std_logic_vector(2 downto 0);
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_wdata   : out xword;
    m_wstrb   : out std_logic_vector(15 downto 0);
    m_wlast   : out std_logic;
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_bid     : in  std_logic_vector(3 downto 0);
    m_bresp   : in  std_logic_vector(1 downto 0);
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic;
    m_arid    : out std_logic_vector(3 downto 0);
    m_araddr  : out aaddr_t;
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

architecture rtl of rv128_axi_master is
  type st_t is (IDLE, AR, R, AW, W, B);
  signal st     : st_t;
  signal cli    : std_logic;                         -- 0: D$, 1: I$
  signal kind   : std_logic_vector(1 downto 0);
  signal addr   : aaddr_t;
  signal size   : std_logic_vector(2 downto 0);
  signal cache  : std_logic;
  signal wline  : line_t;
  signal wd     : xword;
  signal ws     : std_logic_vector(15 downto 0);
  signal beat   : unsigned(1 downto 0);
  signal errs   : std_logic;
  signal line_k : boolean;
  signal c0_done_r, c1_done_r : std_logic;
begin
  c0_done <= c0_done_r; c1_done <= c1_done_r;
  line_k <= kind = AX_RD_LINE or kind = AX_WR_LINE;

  -- canal AR
  m_arid    <= "000" & cli;
  m_araddr  <= addr;
  m_arlen   <= x"03" when line_k else x"00";
  m_arsize  <= "100" when line_k else size;
  m_arburst <= "01";                                   -- INCR
  m_arcache <= "0011" when cache = '1' else "0000";
  m_arprot  <= "000";
  m_arvalid <= '1' when st = AR else '0';
  m_rready  <= '1' when st = R else '0';
  -- canales AW/W/B
  m_awid    <= "000" & cli;                           -- same ID scheme as AR (only D$ writes)
  m_awaddr  <= addr;
  m_awlen   <= x"03" when line_k else x"00";
  m_awsize  <= "100" when line_k else size;
  m_awburst <= "01";
  m_awcache <= "0011" when cache = '1' else "0000";
  m_awprot  <= "000";
  m_awvalid <= '1' when st = AW else '0';
  m_wvalid  <= '1' when st = W else '0';
  m_wdata   <= wline(128 * to_integer(beat) + 127 downto 128 * to_integer(beat)) when line_k else wd;
  m_wstrb   <= x"FFFF" when line_k else ws;
  m_wlast   <= '1' when (not line_k) or beat = 3 else '0';
  m_bready  <= '1' when st = B else '0';

  -- hacia los clientes
  c0_acc   <= '1' when st = IDLE and c0_done_r = '0' and c1_done_r = '0' and c0_req = '1' else '0';
  beat_idx <= std_logic_vector(beat);
  rdata    <= m_rdata;
  c0_beat  <= '1' when st = R and m_rvalid = '1' and cli = '0' else '0';
  c1_beat  <= '1' when st = R and m_rvalid = '1' and cli = '1' else '0';

  process (clk)
    variable fin : boolean;
    variable e   : std_logic;
  begin
    if rising_edge(clk) then
      c0_done_r <= '0'; c1_done_r <= '0';
      if rst = '1' then
        st <= IDLE;
      else
        fin := false; e := errs;
        case st is
          when IDLE =>
            errs <= '0'; beat <= "00";
            -- no arrancar en el ciclo de 'done': el cliente aun no ha bajado su req
            if c0_done_r = '1' or c1_done_r = '1' then
              null;
            elsif c0_req = '1' then
              cli <= '0'; kind <= c0_kind; addr <= c0_addr(63 downto 0); size <= c0_size; cache <= c0_cache;
              wline <= c0_wline; wd <= c0_wdata; ws <= c0_wstrb;
              if c0_kind(0) = '1' then st <= AW; else st <= AR; end if;
            elsif c1_req = '1' then
              cli <= '1'; kind <= c1_kind; addr <= c1_addr(63 downto 0); size <= c1_size; cache <= c1_cache;
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
              if (not line_k) or beat = 3 then st <= B; end if;
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
          if cli = '0' then c0_done_r <= '1'; else c1_done_r <= '1'; end if;
          st <= IDLE;
        end if;
      end if;
    end if;
  end process;
end architecture;
