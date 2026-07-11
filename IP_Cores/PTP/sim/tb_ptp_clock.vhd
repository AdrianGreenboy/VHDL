-- tb_ptp_clock.vhd — capa 1a del reloj + servo PI.
-- Lee ref_clock.csv (generado por iss_ptp_clock.py) y compara los snapshots
-- (ns, rate_adj, offset_applied) del RTL contra el ISS. Criterio:
-- bit-identico. Asserts en espanol, severity failure, fallo LIMPIO.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ptp_pkg.all;

entity tb_ptp_clock is
end entity;

architecture sim of tb_ptp_clock is

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal role_slave   : std_logic := '0';
  signal clr_servo    : std_logic := '0';
  signal kp, ki       : std_logic_vector(15 downto 0) := (others => '0');
  signal offset_err   : std_logic_vector(ERR_W-1 downto 0) := (others => '0');
  signal offset_valid : std_logic := '0';
  signal now_sec      : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns       : std_logic_vector(NS_W-1 downto 0);
  signal rate_adj_o   : std_logic_vector(RATE_W-1 downto 0);
  signal offset_applied_o : std_logic;

  constant TCK : time := 10 ns;
  signal done : boolean := false;

  type ref_arr is array (0 to 10) of integer;

begin

  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_clock
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (
      clk => clk, rst => rst,
      role_slave => role_slave, clr_servo => clr_servo,
      kp => kp, ki => ki,
      offset_err => offset_err, offset_valid => offset_valid,
      now_sec => now_sec, now_ns => now_ns,
      rate_adj_o => rate_adj_o, offset_applied_o => offset_applied_o);

  stim : process
    variable ns_i, rate_i : integer;
    variable err : integer := 200;
    variable errn : integer := -180;
    variable e   : integer;
    variable ov  : std_logic;
    file fh      : text;
    variable ln  : line;
    variable idx : integer := 0;
    variable c      : character;
    variable field  : integer;
    variable fnum   : integer;
    variable neg    : boolean := false;
    variable rec_ns   : ref_arr := (others => 0);
    variable rec_rate : ref_arr := (others => 0);

    procedure step is
    begin
      wait until rising_edge(clk);
    end procedure;

    procedure check(tag : string; k : integer; exp_appl : std_logic) is
    begin
      ns_i   := to_integer(unsigned(now_ns));
      rate_i := to_integer(signed(rate_adj_o));   -- signed 32b
      assert ns_i = rec_ns(k)
        report "FALLO ns en " & tag & ": rtl=" & integer'image(ns_i) &
               " esperado(ISS)=" & integer'image(rec_ns(k)) severity failure;
      assert rate_i = rec_rate(k)
        report "FALLO rate_adj en " & tag & ": rtl=" & integer'image(rate_i) &
               " esperado(ISS)=" & integer'image(rec_rate(k)) severity failure;
      assert offset_applied_o = exp_appl
        report "FALLO offset_applied en " & tag severity failure;
      report "OK " & tag & "  ns=" & integer'image(ns_i) &
             " rate=" & integer'image(rate_i);
    end procedure;

  begin
    file_open(fh, "ref_clock.csv", read_mode);
    idx := 0;
    while not endfile(fh) and idx < 11 loop
      readline(fh, ln);
      field := 0; fnum := 0; neg := false;
      for p in ln'range loop
        c := ln(p);
        if c = ',' then
          if field = 2 then rec_ns(idx)   := fnum; end if;
          if field = 4 then
            if neg then rec_rate(idx) := -fnum; else rec_rate(idx) := fnum; end if;
          end if;
          field := field + 1; fnum := 0; neg := false;
        elsif c = '-' then
          neg := true;
        elsif c >= '0' and c <= '9' then
          fnum := fnum*10 + (character'pos(c) - character'pos('0'));
        end if;
      end loop;
      idx := idx + 1;
    end loop;
    file_close(fh);

    rst <= '1'; step; step; rst <= '0';
    kp <= x"0040"; ki <= x"0010";

    for i in 1 to 101 loop step; end loop;
    check("A_end", 0, '0');

    -- fase B: offset_valid alto 2 steps. La deteccion de flanco hace que solo
    -- el primero aplique el salto; el segundo es no-op de offset (ov_d ya '1').
    role_slave <= '1';
    offset_err <= std_logic_vector(to_signed(1234, ERR_W));
    offset_valid <= '1';
    step;                                   -- flanco: aplica el salto
    step;                                   -- sin flanco: no reprocesa
    offset_valid <= '0';
    check("B_jump", 1, '1');

    for i in 0 to 299 loop
      if (i mod 10) = 0 then ov := '1'; else ov := '0'; end if;
      if ov = '1' then e := err; else e := 0; end if;
      offset_err   <= std_logic_vector(to_signed(e, ERR_W));
      offset_valid <= ov;
      step;
      if ov = '1' then
        err := err - err/8;
      end if;
      if i = 49  then check("C_49",  2, '1'); end if;
      if i = 99  then check("C_99",  3, '1'); end if;
      if i = 149 then check("C_149", 4, '1'); end if;
      if i = 199 then check("C_199", 5, '1'); end if;
      if i = 249 then check("C_249", 6, '1'); end if;
      if i = 299 then check("C_299", 7, '1'); end if;
    end loop;


    -- fase D: error NEGATIVO sostenido (esclavo adelantado -> frenar). Ejercita
    -- el signo del servo en ambos sentidos.
    errn := -180;
    for i in 0 to 199 loop
      if (i mod 10) = 0 then ov := '1'; else ov := '0'; end if;
      if ov = '1' then e := errn; else e := 0; end if;
      offset_err   <= std_logic_vector(to_signed(e, ERR_W));
      offset_valid <= ov;
      step;
      if ov = '1' then
        errn := errn - errn/8;
      end if;
      if i = 49  then check("D_49",  8,  '1'); end if;
      if i = 149 then check("D_149", 9,  '1'); end if;
      if i = 199 then check("D_199", 10, '1'); end if;
    end loop;
    offset_valid <= '0';
    report "=== PTP_CLOCK LAYER 1a PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
