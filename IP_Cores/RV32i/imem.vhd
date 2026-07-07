-- =============================================================================
--  imem.vhd  -  Memoria de instrucciones (ROM) para el datapath single-cycle
--  Licencia: MIT
--
--  Carga un programa desde un archivo de texto en hexadecimal (una palabra de
--  32 bits por linea, estilo $readmemh). Lectura asincrona: la palabra en la
--  direccion 'addr' aparece de forma combinacional (adecuado para single-cycle).
--
--  El programa se compila aparte (ver sim/asm.py) y se coloca en el directorio
--  desde donde se corre la simulacion.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

use work.riscv_pkg.all;

entity imem is
  generic (
    DEPTH     : natural := 256;          -- numero de palabras
    INIT_FILE : string  := "program.mem"
  );
  port (
    addr  : in  word_t;                  -- direccion de byte (se usa [.. :2])
    instr : out word_t
  );
end entity imem;

architecture rtl of imem is
  type mem_t is array (0 to DEPTH-1) of word_t;

  impure function load(fn : string) return mem_t is
    file     f : text;
    variable l : line;
    variable w : word_t;
    variable m : mem_t := (others => (others => '0'));
    variable i : natural := 0;
    variable status : file_open_status;
  begin
    file_open(status, f, fn, read_mode);
    if status /= open_ok then
      report "imem: no se pudo abrir '" & fn & "'" severity warning;
      return m;
    end if;
    while not endfile(f) and i < DEPTH loop
      readline(f, l);
      if l'length > 0 then
        hread(l, w);
        m(i) := w;
        i := i + 1;
      end if;
    end loop;
    file_close(f);
    return m;
  end function;

  constant ROM : mem_t := load(INIT_FILE);

  -- indice de palabra: quita los 2 bits bajos de la direccion de byte
  constant IDX_HI : natural := 1 + integer(ceil(log2(real(DEPTH))));
begin
  instr <= ROM(to_integer(unsigned(addr(IDX_HI downto 2))));
end architecture rtl;
