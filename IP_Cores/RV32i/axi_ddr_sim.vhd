-- =============================================================================
--  axi_ddr_sim.vhd  -  Esclavo AXI4 de comportamiento (DDR falsa) para sim
--  Licencia: MIT
--
--  Memoria de 1024 palabras, esclavo AXI4 con soporte de BURSTS (INCR) y unos
--  ciclos de latencia de lectura para modelar la DDR. SOLO PARA SIMULACION.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

use work.riscv_pkg.all;

entity axi_ddr_sim is
  generic (
    ADDR_W    : natural := 40;
    DEPTH     : natural := 1024;
    RD_LAT    : natural := 4;
    INIT_FILE : string  := ""
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;

    s_axi_awaddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_awlen   : in  std_logic_vector(7 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wlast   : in  std_logic;
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_arlen   : in  std_logic_vector(7 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rlast   : out std_logic;
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    dbg_addr : in  natural := 0;
    dbg_data : out word_t
  );
end entity axi_ddr_sim;

architecture sim of axi_ddr_sim is
  type mem_t is array (0 to DEPTH-1) of word_t;

  impure function load(fn : string) return mem_t is
    file     f : text;
    variable l : line;
    variable w : word_t;
    variable m : mem_t := (others => (others => '0'));
    variable i : natural := 0;
    variable status : file_open_status;
  begin
    if fn = "" then return m; end if;
    file_open(status, f, fn, read_mode);
    if status /= open_ok then return m; end if;
    while not endfile(f) and i < DEPTH loop
      readline(f, l);
      if l'length > 0 then hread(l, w); m(i) := w; i := i + 1; end if;
    end loop;
    file_close(f);
    return m;
  end function;

  signal mem : mem_t := load(INIT_FILE);

  type wstate_t is (W_IDLE, W_DATA, W_RESP);
  type rstate_t is (R_IDLE, R_LAT, R_DATA);
  signal wstate : wstate_t := W_IDLE;
  signal rstate : rstate_t := R_IDLE;

  signal waddr_idx, raddr_idx : natural range 0 to DEPTH-1 := 0;
  signal rbeats : unsigned(7 downto 0) := (others => '0');   -- beats restantes-1
  signal latcnt : natural range 0 to 15 := 0;

  function idx(a : std_logic_vector) return natural is
    constant HI : natural := 1 + integer(ceil(log2(real(DEPTH))));
  begin
    return to_integer(unsigned(a(HI downto 2)));
  end function;
begin

  dbg_data <= mem(dbg_addr) when dbg_addr < DEPTH else (others => '0');

  s_axi_bresp <= "00";
  s_axi_rresp <= "00";

  s_axi_awready <= '1' when wstate = W_IDLE else '0';
  s_axi_wready  <= '1' when wstate = W_DATA else '0';
  s_axi_bvalid  <= '1' when wstate = W_RESP else '0';
  s_axi_arready <= '1' when rstate = R_IDLE else '0';
  s_axi_rvalid  <= '1' when rstate = R_DATA else '0';
  s_axi_rlast   <= '1' when (rstate = R_DATA and rbeats = 0) else '0';
  s_axi_rdata   <= mem(raddr_idx);

  -- canal de escritura (soporta burst: escribe hasta wlast)
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        wstate <= W_IDLE;
      else
        case wstate is
          when W_IDLE =>
            if s_axi_awvalid = '1' then
              assert (to_integer(unsigned(s_axi_awaddr(11 downto 0))) +
                      (to_integer(unsigned(s_axi_awlen)) + 1) * 4) <= 4096
                report "BURST DE ESCRITURA CRUZA LIMITE DE 4KB (ilegal en AXI4)"
                severity error;
              waddr_idx <= idx(s_axi_awaddr);
              wstate    <= W_DATA;
            end if;
          when W_DATA =>
            if s_axi_wvalid = '1' then
              for b in 0 to 3 loop
                if s_axi_wstrb(b) = '1' then
                  mem(waddr_idx)(b*8+7 downto b*8) <= s_axi_wdata(b*8+7 downto b*8);
                end if;
              end loop;
              waddr_idx <= waddr_idx + 1;
              if s_axi_wlast = '1' then wstate <= W_RESP; end if;
            end if;
          when W_RESP =>
            if s_axi_bready = '1' then wstate <= W_IDLE; end if;
        end case;
      end if;
    end if;
  end process;

  -- canal de lectura (soporta burst: entrega arlen+1 beats)
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        rstate <= R_IDLE;
        latcnt <= 0;
      else
        case rstate is
          when R_IDLE =>
            if s_axi_arvalid = '1' then
              assert (to_integer(unsigned(s_axi_araddr(11 downto 0))) +
                      (to_integer(unsigned(s_axi_arlen)) + 1) * 4) <= 4096
                report "BURST DE LECTURA CRUZA LIMITE DE 4KB (ilegal en AXI4)"
                severity error;
              raddr_idx <= idx(s_axi_araddr);
              rbeats    <= unsigned(s_axi_arlen);
              latcnt    <= RD_LAT;
              rstate    <= R_LAT;
            end if;
          when R_LAT =>
            if latcnt = 0 then rstate <= R_DATA;
            else latcnt <= latcnt - 1; end if;
          when R_DATA =>
            if s_axi_rready = '1' then
              if rbeats = 0 then
                rstate <= R_IDLE;
              else
                raddr_idx <= raddr_idx + 1;
                rbeats    <= rbeats - 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture sim;
