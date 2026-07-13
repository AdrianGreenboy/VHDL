-- ============================================================================
-- tb_mpc_dot_row.vhd — Capa 1b del IP ADCS: mpc_dot_row vs oraculo Python.
--
-- Lee vectors_dot.txt (T; luego por test: "NDIM ESPERADO" / fila H / vector U
-- en hex), lanza cada dot con start y espera done con limite de iteraciones
-- (un cuelgue cuenta como fallo). Criterio de PASS: ERRORES=0, firma
-- bit-identica al oraculo y timestamp determinista para LAT_FMA dado.
-- La misma firma debe salir con cualquier LAT_FMA (el orden de acumulacion
-- no depende de la latencia): el runner lo exige con LAT=8 y LAT=20.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use std.env.all;
use work.adcs_pkg.all;

entity tb_mpc_dot_row is
  generic (
    MUT      : natural := 0;
    LAT_FMA  : natural := 8;
    VEC_FILE : string  := "vectors_dot.txt"
  );
end entity tb_mpc_dot_row;

architecture sim of tb_mpc_dot_row is
  constant TCLK     : time    := 4 ns;      -- 250 MHz
  constant MAXT     : natural := 512;
  constant POLL_LIM : natural := 20000;     -- ciclos max por test

  type slv32_arr is array (natural range <>) of std_logic_vector(31 downto 0);
  type row_arr   is array (natural range <>) of std_logic_vector(D*FP_W-1 downto 0);
  type nd_arr    is array (natural range <>) of integer;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal start  : std_logic := '0';
  signal n_dim  : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal h_row  : std_logic_vector(D*FP_W-1 downto 0) := (others => '0');
  signal u_vec  : std_logic_vector(D*FP_W-1 downto 0) := (others => '0');
  signal done   : std_logic;
  signal result : std_logic_vector(FP_W-1 downto 0);
  signal fin    : boolean := false;
begin

  clk <= not clk after TCLK/2 when not fin else '0';

  u_dut : entity work.mpc_dot_row
    generic map (LAT_FMA => LAT_FMA, MUT => MUT)
    port map (
      clk => clk, rst_n => rst_n, start => start, n_dim => n_dim,
      h_row => h_row, u_vec => u_vec, done => done, result => result);

  p_main : process
    file     f    : text;
    variable l    : line;
    variable t, nd : integer;
    variable w    : std_logic_vector(31 downto 0);
    variable tnd  : nd_arr(0 to MAXT-1);
    variable texp : slv32_arr(0 to MAXT-1);
    variable th   : row_arr(0 to MAXT-1);
    variable tu   : row_arr(0 to MAXT-1);
    variable errores : integer := 0;
    variable sig  : std_logic_vector(31 downto 0) := (others => '0');
    variable got  : boolean;
    variable polls : natural;
  begin
    file_open(f, VEC_FILE, read_mode);
    readline(f, l);
    read(l, t);
    assert t > 0 and t <= MAXT
      report "Numero de tests fuera de rango" severity failure;
    for i in 0 to t-1 loop
      readline(f, l);
      read(l, nd);  hread(l, w);
      tnd(i) := nd; texp(i) := w;
      readline(f, l);
      for gi in 0 to D-1 loop
        hread(l, w);
        th(i)((gi+1)*FP_W-1 downto gi*FP_W) := w;
      end loop;
      readline(f, l);
      for gi in 0 to D-1 loop
        hread(l, w);
        tu(i)((gi+1)*FP_W-1 downto gi*FP_W) := w;
      end loop;
    end loop;
    file_close(f);

    rst_n <= '0';
    wait for 5*TCLK;
    wait until rising_edge(clk);
    rst_n <= '1';
    wait until rising_edge(clk);

    for i in 0 to t-1 loop
      h_row <= th(i);
      u_vec <= tu(i);
      n_dim <= std_logic_vector(to_unsigned(tnd(i), IDX_W));
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      -- espera guardada con limite (un done perdido = cuelgue = fallo)
      got   := false;
      polls := 0;
      while (not got) and (polls < POLL_LIM) loop
        wait until rising_edge(clk);
        wait for 1 ns;
        if done = '1' then got := true; end if;
        polls := polls + 1;
      end loop;

      if not got then
        report "TIMEOUT en test " & integer'image(i) severity failure;
      end if;

      sig := sig(30 downto 0) & sig(31);
      sig := sig xor result;
      if result /= texp(i) then
        errores := errores + 1;
        if errores <= 10 then
          report "DESACUERDO test " & integer'image(i) severity note;
        end if;
      end if;
      wait until rising_edge(clk);
    end loop;

    report "T=" & integer'image(t) &
           " ERRORES=" & integer'image(errores) &
           " FIRMA_L1B=0x" & to_hstring(sig) &
           " T=" & time'image(now);

    assert errores = 0
      report "CAPA 1B FALLO: hay desacuerdos con el oraculo" severity failure;

    fin <= true;
    finish;
  end process;

end architecture sim;
