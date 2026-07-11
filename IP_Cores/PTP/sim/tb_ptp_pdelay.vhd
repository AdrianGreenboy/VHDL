-- tb_ptp_pdelay.vhd — capa 1a del calculo de meanPathDelay.
-- Aplica los mismos 5 casos que iss_ptp_pdelay.py y compara delay_ns contra
-- ref_pdelay.csv. Bit-identico. Cubre loopback, cruce de segundo, delay
-- negativo, correctionField fraccionario y delay cero.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ptp_pkg.all;

entity tb_ptp_pdelay is
end entity;

architecture sim of tb_ptp_pdelay is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal calc : std_logic := '0';
  signal t1_sec, t4_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal t1_ns, t4_ns   : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal corr_field : std_logic_vector(63 downto 0) := (others => '0');
  signal delay_ns : std_logic_vector(63 downto 0);
  signal valid : std_logic;

  type iarr is array (0 to 4) of integer;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_pdelay
    port map (clk => clk, rst => rst, calc => calc,
              t1_sec => t1_sec, t1_ns => t1_ns, t4_sec => t4_sec, t4_ns => t4_ns,
              corr_field => corr_field, delay_ns => delay_ns, valid => valid);

  stim : process
    file fh : text;
    variable ln : line;
    variable idx, fnum, fld : integer;
    variable c : character;
    variable neg : boolean;
    variable ref_d : iarr := (others => 0);

    procedure step is begin wait until rising_edge(clk); end procedure;

    procedure run(tag : string; k : integer;
                  t1s, t1n, t4s, t4n : integer; corr : integer) is
      variable got : integer;
    begin
      t1_sec <= std_logic_vector(to_unsigned(t1s, SEC_W));
      t1_ns  <= std_logic_vector(to_unsigned(t1n, NS_W));
      t4_sec <= std_logic_vector(to_unsigned(t4s, SEC_W));
      t4_ns  <= std_logic_vector(to_unsigned(t4n, NS_W));
      corr_field <= std_logic_vector(to_signed(corr, 64));
      calc <= '1'; step; calc <= '0'; step;   -- 1 ciclo de latencia registrada
      got := to_integer(signed(delay_ns));
      assert got = ref_d(k)
        report "FALLO delay en " & tag & ": rtl=" & integer'image(got) &
               " esperado(ISS)=" & integer'image(ref_d(k)) severity failure;
      report "OK " & tag & " delay=" & integer'image(got);
    end procedure;
  begin
    -- cargar ref_pdelay.csv: tag,delay (delay puede ser negativo)
    file_open(fh, "ref_pdelay.csv", read_mode);
    idx := 0;
    while not endfile(fh) and idx < 5 loop
      readline(fh, ln);
      fld := 0; fnum := 0; neg := false;
      for p in ln'range loop
        c := ln(p);
        if c = ',' then
          fld := 1; fnum := 0; neg := false;
        elsif c = '-' then
          neg := true;
        elsif c >= '0' and c <= '9' then
          fnum := fnum*10 + (character'pos(c) - character'pos('0'));
        end if;
      end loop;
      if neg then ref_d(idx) := -fnum; else ref_d(idx) := fnum; end if;
      idx := idx + 1;
    end loop;
    file_close(fh);

    rst <= '1'; step; step; rst <= '0';

    run("LOOP", 0, 0, 1000, 0, 1400, 100*65536);
    run("XSEC", 1, 0, 999_999_900, 1, 300, 0);
    run("NEG",  2, 0, 1000, 0, 1200, 400*65536);
    run("FRAC", 3, 0, 2000, 0, 2600, 9863168);
    run("ZERO", 4, 0, 5000, 0, 5200, 200*65536);

    report "=== PTP_PDELAY LAYER 1a PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
