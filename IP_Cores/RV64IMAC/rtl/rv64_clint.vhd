-- rv64_clint.vhd - CLINT (un hart): msip @0x0, mtimecmp @0x4000, mtime @0xBFF8.
-- Accesos de 4 u 8 bytes (otros tamanos -> error, como el ISS). mtime avanza un
-- tick cada TICK_DIV ciclos de reloj (frecuencia fija para Linux: timebase).
-- Interfaz de registro simple (req/rsp de un ciclo) usada por el bridge de perifericos.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_clint is
  generic (TICK_DIV : positive := 100);
  port (
    clk, rst : in  std_logic;
    req      : in  std_logic;
    we       : in  std_logic;
    addr     : in  std_logic_vector(15 downto 0);
    size     : in  std_logic_vector(1 downto 0);
    wdata    : in  xword;                              -- por carriles
    wstrb    : in  std_logic_vector(7 downto 0);
    rdata    : out xword;                              -- por carriles
    err      : out std_logic;
    mtip, msip : out std_logic;
    mtime_o  : out xword
  );
end entity;

architecture rtl of rv64_clint is
  signal msip_r   : std_logic;
  signal mtimecmp : unsigned(63 downto 0);
  signal mtime    : unsigned(63 downto 0);
  signal div      : natural range 0 to TICK_DIV - 1;
begin
  mtip <= '1' when mtime >= mtimecmp else '0';
  msip <= msip_r;
  mtime_o <= std_logic_vector(mtime);

  process (all)
    variable v : xword;
  begin
    v := XZERO;
    case addr(15 downto 3) is
      when "0000000000000" => v(0) := msip_r;
      when "0100000000000" => v := std_logic_vector(mtimecmp);   -- 0x4000
      when "1011111111111" => v := std_logic_vector(mtime);      -- 0xBFF8
      when others => null;
    end case;
    rdata <= v;
    err <= '1' when req = '1' and size /= "10" and size /= "11" else '0';
  end process;

  process (clk)
    variable m, nw : xword;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        msip_r <= '0'; mtimecmp <= (others => '1'); mtime <= (others => '0'); div <= 0;
      else
        if div = TICK_DIV - 1 then div <= 0; mtime <= mtime + 1; else div <= div + 1; end if;
        if req = '1' and we = '1' and (size = "10" or size = "11") then
          for k in 0 to 7 loop m(8 * k + 7 downto 8 * k) := (others => wstrb(k)); end loop;
          case addr(15 downto 3) is
            when "0000000000000" =>
              nw := ((63 downto 1 => '0') & msip_r);
              nw := (nw and not m) or (wdata and m);
              msip_r <= nw(0);
            when "0100000000000" =>               -- 0x4000
              mtimecmp <= unsigned((std_logic_vector(mtimecmp) and not m) or (wdata and m));
            when "1011111111111" =>
              mtime <= unsigned((std_logic_vector(mtime) and not m) or (wdata and m));
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
