-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Modelo de simulacion de un canal GTYP en 64B66B_ASYNC (solo testbench):
--   * TX: cada ciclo forma 66 bits de cable a partir de txheader/txdata con
--     el orden de bits "real" del GT (GT_REV / GT_SWAP; ambos 0 = cabecera
--     bit 0 primero y datos LSB primero) y, si DUMPF /= "", los escribe (una
--     linea de 66 caracteres '0'/'1', el primero transmitido a la izquierda)
--   * fuente del cable para RX: el propio TX (loopback) o un archivo INF con
--     el mismo formato (flujo IEEE generado por el oraculo)
--   * RX: ventana de 66 bits con desplazamiento OFF0 (0..65) sobre el flujo
--     de cable; rxgearboxslip desplaza la ventana 1 bit SLIP_LAT ciclos
--     despues del pulso (como el gearbox del GT)
--   * err_inj: invierte un bit del cable (bit ERR_BIT) en ese ciclo
-- Un solo reloj para TX y RX (la diferencia de ppm no se modela).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity eth21_gt_model is
  generic (
    GT_REV   : boolean := false;
    GT_SWAP  : boolean := false;
    OFF0     : natural := 17;
    SLIP_LAT : natural := 8;
    ERR_BIT  : natural := 40;
    INF      : string  := "";
    DUMPF    : string  := ""
  );
  port (
    clk      : in  std_logic;
    txdata   : in  std_logic_vector(63 downto 0);
    txheader : in  std_logic_vector(1 downto 0);
    rxdata   : out std_logic_vector(63 downto 0);
    rxheader : out std_logic_vector(1 downto 0);
    rxvalid  : out std_logic;
    rxslip   : in  std_logic;
    err_inj  : in  std_logic;
    in_eof   : out std_logic
  );
end entity eth21_gt_model;

architecture sim of eth21_gt_model is
  signal prev, cur : std_logic_vector(0 to 65) := (others => '0');
  signal off  : natural range 0 to 65 := OFF0;
  signal slip_pipe : std_logic_vector(0 to 31) := (others => '0');
  signal eof  : std_logic := '0';
begin

  process(clk)
    file fi : text;
    file fo : text;
    variable opened_i, opened_o : boolean := false;
    variable l : line;
    variable w : std_logic_vector(0 to 65);
    variable c : character;
    variable good : boolean;
  begin
    if rising_edge(clk) then
      -- cable a partir del TX
      if GT_SWAP then
        w(0) := txheader(1); w(1) := txheader(0);
      else
        w(0) := txheader(0); w(1) := txheader(1);
      end if;
      for i in 0 to 63 loop
        if GT_REV then w(2 + i) := txdata(63 - i); else w(2 + i) := txdata(i); end if;
      end loop;
      if DUMPF /= "" then
        if not opened_o then file_open(fo, DUMPF, write_mode); opened_o := true; end if;
        for i in 0 to 65 loop
          if w(i) = '1' then write(l, character'('1')); else write(l, character'('0')); end if;
        end loop;
        writeline(fo, l);
      end if;
      -- fuente del RX
      if INF /= "" then
        if not opened_i then file_open(fi, INF, read_mode); opened_i := true; end if;
        if not endfile(fi) then
          readline(fi, l);
          for i in 0 to 65 loop
            read(l, c, good);
            if good and c = '1' then w(i) := '1'; else w(i) := '0'; end if;
          end loop;
        else
          w := (others => '0'); eof <= '1';
        end if;
      end if;
      if err_inj = '1' then w(ERR_BIT) := not w(ERR_BIT); end if;
      prev <= cur;
      cur  <= w;
      -- slip con latencia
      slip_pipe <= rxslip & slip_pipe(0 to 30);
      if slip_pipe(SLIP_LAT - 1) = '1' then
        if off = 65 then off <= 0; else off <= off + 1; end if;
      end if;
    end if;
  end process;

  -- ventana de recepcion (combinacional sobre prev & cur, registrada abajo)
  process(clk)
    variable a : std_logic_vector(0 to 131);
    variable r : std_logic_vector(0 to 65);
  begin
    if rising_edge(clk) then
      a := prev & cur;
      r := a(off to off + 65);
      if GT_SWAP then
        rxheader(0) <= r(1); rxheader(1) <= r(0);
      else
        rxheader(0) <= r(0); rxheader(1) <= r(1);
      end if;
      for i in 0 to 63 loop
        if GT_REV then rxdata(63 - i) <= r(2 + i); else rxdata(i) <= r(2 + i); end if;
      end loop;
      rxvalid <= '1';
    end if;
  end process;

  in_eof <= eof;
end architecture sim;
