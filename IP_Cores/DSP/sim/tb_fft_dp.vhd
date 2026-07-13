-------------------------------------------------------------------------------
-- tb_fft_dp.vhd  --  Layer 1a entrega 1: testbench FFT compleja.
-- Lee tb_fft.mem: NCASES; por caso "CASE LOG2N INV N" + N lineas
--   "re_in im_in re_exp im_exp". Carga, corre, compara bit-exacto.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_fft_dp is
end entity;

architecture sim of tb_fft_dp is
  constant CLK_P : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal log2n : std_logic_vector(3 downto 0) := (others=>'0');
  signal inv   : std_logic := '0';
  signal wr_en : std_logic := '0';
  signal wr_idx: std_logic_vector(9 downto 0) := (others=>'0');
  signal wr_re, wr_im : std_logic_vector(15 downto 0) := (others=>'0');
  signal start : std_logic := '0';
  signal done, busy : std_logic;
  signal rd_idx: std_logic_vector(9 downto 0) := (others=>'0');
  signal rd_re, rd_im : std_logic_vector(15 downto 0);
  signal sim_done : boolean := false;

  type mem_t is array (0 to 1023) of std_logic_vector(15 downto 0);
  signal exp_re, exp_im : mem_t;
begin

  dut : entity work.fft_dp
    generic map (NMAX=>1024, LOG2MAX=>10)
    port map (clk=>clk, rst=>rst, log2n=>log2n, inv=>inv,
              wr_en=>wr_en, wr_idx=>wr_idx, wr_re=>wr_re, wr_im=>wr_im,
              start=>start, done=>done, busy=>busy,
              rd_idx=>rd_idx, rd_re=>rd_re, rd_im=>rd_im);

  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    file fh : text open read_mode is "tb_fft.mem";
    variable ln : line;
    variable ncases, l2, invf, n : integer;
    variable tag : string(1 to 4);
    variable vri, vii, vre, vie : std_logic_vector(15 downto 0);
    variable errors, total : integer := 0;
  begin
    rst<='1'; wait for 4*CLK_P; rst<='0'; wait for 2*CLK_P;
    readline(fh, ln); read(ln, ncases);

    for c in 0 to ncases-1 loop
      readline(fh, ln);
      read(ln, tag); read(ln, l2); read(ln, invf); read(ln, n);

      -- cargar entrada y guardar esperado
      for t in 0 to n-1 loop
        readline(fh, ln);
        hread(ln, vri); hread(ln, vii); hread(ln, vre); hread(ln, vie);
        wr_idx <= std_logic_vector(to_unsigned(t,10));
        wr_re <= vri; wr_im <= vii; wr_en <= '1';
        exp_re(t) <= vre; exp_im(t) <= vie;
        wait until rising_edge(clk);
      end loop;
      wr_en <= '0';

      -- configurar y lanzar
      log2n <= std_logic_vector(to_unsigned(l2,4));
      inv   <= '1' when invf=1 else '0';
      wait until rising_edge(clk);
      start <= '1'; wait until rising_edge(clk); start <= '0';

      -- esperar done (guarda amplia: N*log2N butterflies + margen)
      for w in 0 to 200000 loop
        wait until rising_edge(clk);
        exit when done='1';
      end loop;
      assert done='1' report "TIMEOUT caso "&integer'image(c) severity failure;

      -- comparar
      for t in 0 to n-1 loop
        rd_idx <= std_logic_vector(to_unsigned(t,10));
        wait until rising_edge(clk); wait until rising_edge(clk);
        wait until rising_edge(clk);   -- latencia BRAM: ADDRA reg + DOUTA reg
        if rd_re /= exp_re(t) or rd_im /= exp_im(t) then
          errors := errors + 1;
          if errors <= 6 then
            report "FFT mismatch c="&integer'image(c)&" k="&integer'image(t)&
              " got("&to_hstring(rd_re)&","&to_hstring(rd_im)&")"&
              " exp("&to_hstring(exp_re(t))&","&to_hstring(exp_im(t))&")"
              severity warning;
          end if;
        end if;
        total := total + 1;
      end loop;
    end loop;

    file_close(fh);
    report "FFT total="&integer'image(total)&" errores="&integer'image(errors);
    assert errors=0 report "MUTANTE VIVO: "&integer'image(errors)&" mismatches"
      severity failure;
    report "FFT OK - firma bit-exacta contra oraculo";
    sim_done <= true; wait;
  end process;
end architecture;
