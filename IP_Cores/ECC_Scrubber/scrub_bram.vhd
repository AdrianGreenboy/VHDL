-- scrub_bram.vhd - BRAM SDP de prueba para Layer 2. Molde HERCOSSNUX:
-- un puerto de escritura sincrono + un puerto de lectura sincrono (1 ciclo lat).
-- Ancho 39 bits (palabra ECC). Se preinicializa desde archivo por generic.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ecc_pkg.all;

entity scrub_bram is
  generic (
    DEPTH    : natural := 64;
    INITFILE : string  := "layer2_init.txt"
  );
  port (
    clk   : in  std_logic;
    -- puerto escritura
    we    : in  std_logic;
    waddr : in  std_logic_vector(15 downto 0);
    wdata : in  ecc_t;
    -- puerto lectura (sincrono, 1 ciclo)
    raddr : in  std_logic_vector(15 downto 0);
    rdata : out ecc_t
  );
end entity;

architecture rtl of scrub_bram is
  type mem_t is array (0 to DEPTH-1) of ecc_t;

  impure function init_mem return mem_t is
    file     f    : text;
    variable st   : file_open_status;
    variable L    : line;
    variable m    : mem_t := (others => (others => '0'));
    variable idx  : natural := 0;
    variable c    : character;
    variable ok   : boolean;
    variable acc  : unsigned(38 downto 0);
    variable nib  : integer;
    function hexv(ch : character) return integer is
    begin
      case ch is
        when '0' => return 0;  when '1' => return 1;  when '2' => return 2;
        when '3' => return 3;  when '4' => return 4;  when '5' => return 5;
        when '6' => return 6;  when '7' => return 7;  when '8' => return 8;
        when '9' => return 9;  when 'A'|'a' => return 10; when 'B'|'b' => return 11;
        when 'C'|'c' => return 12; when 'D'|'d' => return 13; when 'E'|'e' => return 14;
        when 'F'|'f' => return 15; when others => return -1;
      end case;
    end function;
  begin
    -- Guard de sintesis: con INITFILE vacio (caso silicio, la region vive en
    -- DDR) no se abre archivo alguno -> la BRAM arranca en ceros y la funcion
    -- es sintetizable. Con INITFILE con ruta (simulacion L2/L3) se precarga.
    if INITFILE = "" then
      return m;
    end if;
    file_open(st, f, INITFILE, read_mode);
    if st /= open_ok then
      return m;  -- deja en ceros si no hay archivo
    end if;
    while not endfile(f) and idx < DEPTH loop
      readline(f, L);
      if L'length > 0 and L(L'left) /= '#' then
        acc := (others => '0');
        loop
          read(L, c, ok);
          exit when not ok;
          nib := hexv(c);
          exit when nib < 0;
          acc := acc(34 downto 0) & to_unsigned(nib, 4);
        end loop;
        m(idx) := std_logic_vector(acc);
        idx := idx + 1;
      end if;
    end loop;
    file_close(f);
    return m;
  end function;

  signal mem : mem_t := init_mem;
  signal rd_q : ecc_t := (others => '0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem(to_integer(unsigned(waddr))) <= wdata;
      end if;
      rd_q <= mem(to_integer(unsigned(raddr)));
    end if;
  end process;
  rdata <= rd_q;
end architecture;
