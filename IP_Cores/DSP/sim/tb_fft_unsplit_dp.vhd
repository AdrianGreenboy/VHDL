-------------------------------------------------------------------------------
-- tb_fft_unsplit_dp.vhd  --  Layer 1a entrega 2: testbench del unsplit real.
-- Lee tb_unsplit.mem: NCASES; por caso "CASE LOG2N2 N" + N lineas "Zr Zi"
--   + (N+1) lineas "Xr Xi". Carga Z, corre, compara X[0..N] bit-exacto.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_fft_unsplit_dp is
end entity;

architecture sim of tb_fft_unsplit_dp is
  constant CLK_P : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal log2n2 : std_logic_vector(3 downto 0) := (others=>'0');
  signal wr_en : std_logic := '0';
  signal wr_idx: std_logic_vector(9 downto 0) := (others=>'0');
  signal wr_zr, wr_zi : std_logic_vector(15 downto 0) := (others=>'0');
  signal start : std_logic := '0';
  signal done, busy : std_logic;
  signal rd_idx: std_logic_vector(9 downto 0) := (others=>'0');
  signal rd_xr, rd_xi : std_logic_vector(15 downto 0);
  signal sim_done : boolean := false;

  type mem_t is array (0 to 512) of std_logic_vector(15 downto 0);
  signal exp_xr, exp_xi : mem_t;
begin
  dut : entity work.fft_unsplit_dp
    generic map (NMAX=>512, LOG2MAX=>9)
    port map (clk=>clk, rst=>rst, log2n2=>log2n2,
              wr_en=>wr_en, wr_idx=>wr_idx, wr_zr=>wr_zr, wr_zi=>wr_zi,
              start=>start, done=>done, busy=>busy,
              rd_idx=>rd_idx, rd_xr=>rd_xr, rd_xi=>rd_xi);

  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    file fh : text open read_mode is "tb_unsplit.mem";
    variable ln : line;
    variable ncases, l2n2, n : integer;
    variable tag : string(1 to 4);
    variable a,b : std_logic_vector(15 downto 0);
    variable errors, total : integer := 0;
  begin
    rst<='1'; wait for 4*CLK_P; rst<='0'; wait for 2*CLK_P;
    readline(fh, ln); read(ln, ncases);

    for c in 0 to ncases-1 loop
      readline(fh, ln); read(ln, tag); read(ln, l2n2); read(ln, n);

      -- reset entre casos (limpiar buffers)
      rst<='1'; wait until rising_edge(clk); wait until rising_edge(clk);
      rst<='0'; wait until rising_edge(clk);

      -- cargar Z[0..n-1]
      for t in 0 to n-1 loop
        readline(fh, ln); hread(ln,a); hread(ln,b);
        wr_idx <= std_logic_vector(to_unsigned(t,10));
        wr_zr <= a; wr_zi <= b; wr_en <= '1';
        wait until rising_edge(clk);
      end loop;
      wr_en <= '0';
      -- guardar X esperado [0..n]
      for t in 0 to n loop
        readline(fh, ln); hread(ln,a); hread(ln,b);
        exp_xr(t) <= a; exp_xi(t) <= b;
      end loop;

      log2n2 <= std_logic_vector(to_unsigned(l2n2,4));
      wait until rising_edge(clk);
      start<='1'; wait until rising_edge(clk); start<='0';

      for w in 0 to 5000 loop
        wait until rising_edge(clk); exit when done='1';
      end loop;
      assert done='1' report "TIMEOUT c="&integer'image(c) severity failure;

      for t in 0 to n loop
        rd_idx <= std_logic_vector(to_unsigned(t,10));
        wait until rising_edge(clk); wait until rising_edge(clk);
        if rd_xr /= exp_xr(t) or rd_xi /= exp_xi(t) then
          errors := errors+1;
          if errors<=6 then
            report "UNSPLIT mismatch c="&integer'image(c)&" k="&integer'image(t)&
              " got("&to_hstring(rd_xr)&","&to_hstring(rd_xi)&")"&
              " exp("&to_hstring(exp_xr(t))&","&to_hstring(exp_xi(t))&")"
              severity warning;
          end if;
        end if;
        total := total+1;
      end loop;
    end loop;

    file_close(fh);
    report "UNSPLIT total="&integer'image(total)&" errores="&integer'image(errors);
    assert errors=0 report "MUTANTE VIVO: "&integer'image(errors)&" mismatches"
      severity failure;
    report "UNSPLIT OK - firma bit-exacta contra oraculo";
    sim_done <= true; wait;
  end process;
end architecture;
