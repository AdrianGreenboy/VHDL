-- tb_ptp_tstamp.vhd — capa 1a del bloque de timestamping SFD.
-- Aplica la MISMA secuencia que iss_ptp_tstamp.py y compara ts_sec/ts_ns/
-- ts_valid/ts_overrun contra ref_tstamp.csv. Bit-identico. Asserts en
-- espanol, severity failure.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ptp_pkg.all;

entity tb_ptp_tstamp is
end entity;

architecture sim of tb_ptp_tstamp is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal now_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal now_ns  : std_logic_vector(NS_W-1 downto 0)  := (others => '0');
  signal lat_ns  : std_logic_vector(15 downto 0) := (others => '0');
  signal sfd_pulse, rd_ack : std_logic := '0';
  signal ts_sec  : std_logic_vector(SEC_W-1 downto 0);
  signal ts_ns   : std_logic_vector(NS_W-1 downto 0);
  signal ts_valid, ts_overrun : std_logic;
  constant TCK : time := 10 ns;
  signal done : boolean := false;

  type iarr is array (0 to 6) of integer;
begin

  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_tstamp
    port map (
      clk => clk, rst => rst,
      now_sec => now_sec, now_ns => now_ns, lat_ns => lat_ns,
      sfd_pulse => sfd_pulse, rd_ack => rd_ack,
      ts_sec => ts_sec, ts_ns => ts_ns,
      ts_valid => ts_valid, ts_overrun => ts_overrun);

  stim : process
    file fh     : text;
    variable ln : line;
    variable idx, field, fnum : integer;
    variable c  : character;
    variable k  : integer := 0;
    variable r_sec, r_ns, r_val, r_ovr : iarr := (others => 0);

    procedure step is begin wait until rising_edge(clk); end procedure;

    -- aplica un evento en este flanco; la comprobacion del resultado se hace
    -- en la LLAMADA SIGUIENTE, porque el snapshot del DUT esta registrado y
    -- aparece un ciclo despues (latencia de registro). check_prev compara.
    procedure apply(s_sec, s_ns, s_lat : integer; s_sfd, s_ack : std_logic) is
    begin
      now_sec   <= std_logic_vector(to_unsigned(s_sec, SEC_W));
      now_ns    <= std_logic_vector(to_unsigned(s_ns, NS_W));
      lat_ns    <= std_logic_vector(to_unsigned(s_lat, 16));
      sfd_pulse <= s_sfd;
      rd_ack    <= s_ack;
      step;
    end procedure;

    procedure check_prev(tag : string; ki : integer) is
    begin
      assert to_integer(unsigned(ts_sec)) = r_sec(ki)
        report "FALLO ts_sec en " & tag & ": rtl=" &
               integer'image(to_integer(unsigned(ts_sec))) &
               " esperado=" & integer'image(r_sec(ki)) severity failure;
      assert to_integer(unsigned(ts_ns)) = r_ns(ki)
        report "FALLO ts_ns en " & tag & ": rtl=" &
               integer'image(to_integer(unsigned(ts_ns))) &
               " esperado=" & integer'image(r_ns(ki)) severity failure;
      assert (ts_valid = '1' and r_val(ki) = 1) or (ts_valid = '0' and r_val(ki) = 0)
        report "FALLO ts_valid en " & tag severity failure;
      assert (ts_overrun = '1' and r_ovr(ki) = 1) or (ts_overrun = '0' and r_ovr(ki) = 0)
        report "FALLO ts_overrun en " & tag severity failure;
      report "OK " & tag & " ts=" & integer'image(to_integer(unsigned(ts_sec))) &
             "." & integer'image(to_integer(unsigned(ts_ns))) &
             " v=" & std_logic'image(ts_valid) & " o=" & std_logic'image(ts_overrun);
    end procedure;

  begin
    -- cargar CSV: tag,sec,ns,valid,overrun
    file_open(fh, "ref_tstamp.csv", read_mode);
    idx := 0;
    while not endfile(fh) and idx < 7 loop
      readline(fh, ln);
      field := 0; fnum := 0;
      for p in ln'range loop
        c := ln(p);
        if c = ',' then
          if field = 1 then r_sec(idx) := fnum; end if;
          if field = 2 then r_ns(idx)  := fnum; end if;
          if field = 3 then r_val(idx) := fnum; end if;
          field := field + 1; fnum := 0;
        elsif c >= '0' and c <= '9' then
          fnum := fnum*10 + (character'pos(c) - character'pos('0'));
        end if;
      end loop;
      r_ovr(idx) := fnum;   -- ultimo campo
      idx := idx + 1;
    end loop;
    file_close(fh);

    rst <= '1'; step; step; rst <= '0';

    -- Cada evento: aplicar estimulo 1 ciclo, luego bajar pulsos y observar en
    -- el ciclo siguiente (el snapshot registrado ya es visible). El modelo
    -- Python captura en el mismo tick; el TB observa 1 ciclo despues por el
    -- registro de salida. Los estimulos NO solapan pulsos entre eventos.
    apply(5, 1000, 40, '1', '0'); apply(5, 1000, 40, '0', '0'); check_prev("T1", 0);
    apply(5, 1010, 40, '0', '0'); apply(5, 1010, 40, '0', '0'); check_prev("T2", 1);
    apply(5, 1020, 40, '0', '1'); apply(5, 1020, 40, '0', '0'); check_prev("T3", 2);
    apply(7,   20, 40, '1', '0'); apply(7,   20, 40, '0', '0'); check_prev("T4", 3);
    apply(8,  500, 40, '1', '0'); apply(8,  500, 40, '0', '0'); check_prev("T5", 4);
    apply(9,  700, 40, '1', '1'); apply(9,  700, 40, '0', '0'); check_prev("T6", 5);
    apply(9,  710, 40, '0', '1'); apply(9,  710, 40, '0', '0'); check_prev("T7", 6);

    sfd_pulse <= '0'; rd_ack <= '0';
    report "=== PTP_TSTAMP LAYER 1a PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
