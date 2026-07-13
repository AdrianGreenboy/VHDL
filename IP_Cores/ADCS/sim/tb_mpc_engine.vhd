-- ============================================================================
-- tb_mpc_engine.vhd — Capa 1c del IP ADCS: mpc_engine + bancos vs oraculo.
--
-- Integra h_bank + g_bank + u_bank + mpc_engine exactamente como los cablea
-- el top (iter_tick -> snap_tick). Por test: carga H y g por los puertos de
-- escritura (como hara el DMA), lanza start, espera done con limite, verifica
-- iter_cnt == maxiter-1 y lee U[0..n-1] por el puerto externo del u_bank.
-- Firma = fold sobre TODAS las palabras U de todos los tests.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use std.env.all;
use work.adcs_pkg.all;

entity tb_mpc_engine is
  generic (
    MUT      : natural := 0;
    LAT_FMA  : natural := 8;
    VEC_FILE : string  := "vectors_mpc.txt"
  );
end entity tb_mpc_engine;

architecture sim of tb_mpc_engine is
  constant TCLK     : time    := 4 ns;
  constant POLL_LIM : natural := 600000;

  signal clk, rst_n : std_logic := '0';

  -- engine <-> bancos
  signal start, busy, done, iter_tick : std_logic;
  signal n_dim   : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal maxiter : std_logic_vector(15 downto 0) := (others => '0');
  signal step_f, umax_f : std_logic_vector(31 downto 0) := (others => '0');
  signal iter_cnt : std_logic_vector(15 downto 0);

  signal h_rd_en  : std_logic;
  signal h_rd_row : std_logic_vector(IDX_W-1 downto 0);
  signal h_row_d  : std_logic_vector(D*FP_W-1 downto 0);
  signal g_rd_en  : std_logic;
  signal g_rd_a   : std_logic_vector(IDX_W-1 downto 0);
  signal g_rd_d   : std_logic_vector(FP_W-1 downto 0);
  signal u_rd_en, u_wr_en : std_logic;
  signal u_rd_a, u_wr_a   : std_logic_vector(IDX_W-1 downto 0);
  signal u_rd_d, u_wr_d   : std_logic_vector(FP_W-1 downto 0);
  signal u_vec    : std_logic_vector(D*FP_W-1 downto 0);

  -- puertos de carga del TB (rol del DMA)
  signal hw_en   : std_logic := '0';
  signal hw_row, hw_col : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal hw_d    : std_logic_vector(FP_W-1 downto 0) := (others => '0');
  signal gw_en   : std_logic := '0';
  signal gw_a    : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal gw_d    : std_logic_vector(FP_W-1 downto 0) := (others => '0');
  signal ext_a   : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal ext_d   : std_logic_vector(FP_W-1 downto 0);

  signal fin : boolean := false;
begin


  clk <= not clk after TCLK/2 when not fin else '0';

  u_h : entity work.h_bank
    port map (clk => clk,
              wr_en => hw_en, wr_row => hw_row, wr_col => hw_col, wr_data => hw_d,
              rd_en => h_rd_en, rd_row => h_rd_row, row_data => h_row_d);

  u_g : entity work.g_bank
    port map (clk => clk,
              wr_en => gw_en, wr_addr => gw_a, wr_data => gw_d,
              rd_en => g_rd_en, rd_addr => g_rd_a, rd_data => g_rd_d);

  u_u : entity work.u_bank
    port map (clk => clk, rst_n => rst_n,
              wr_en => u_wr_en, wr_addr => u_wr_a, wr_data => u_wr_d,
              rd_en => u_rd_en, rd_addr => u_rd_a, rd_data => u_rd_d,
              snap_tick => iter_tick, u_vec => u_vec,
              ext_rd_addr => ext_a, ext_rd_data => ext_d);

  u_eng : entity work.mpc_engine
    generic map (LAT_FMA => LAT_FMA, LAT_ADD => 6, NLANES => 8, MUT => MUT)
    port map (
      clk => clk, rst_n => rst_n,
      start => start, n_dim => n_dim, maxiter => maxiter,
      step_f => step_f, umax_f => umax_f,
      busy => busy, done => done, iter_cnt => iter_cnt, iter_tick => iter_tick,
      h_rd_en => h_rd_en, h_rd_row => h_rd_row, h_row_data => h_row_d,
      g_rd_en => g_rd_en, g_rd_addr => g_rd_a, g_rd_data => g_rd_d,
      u_rd_en => u_rd_en, u_rd_addr => u_rd_a, u_rd_data => u_rd_d,
      u_wr_en => u_wr_en, u_wr_addr => u_wr_a, u_wr_data => u_wr_d,
      u_vec_data => u_vec);

  p_main : process
    file     f : text;
    variable l : line;
    variable t, n, mi : integer;
    variable w : std_logic_vector(31 downto 0);
    type mat_t is array (0 to D-1, 0 to D-1) of std_logic_vector(31 downto 0);
    type vec_t is array (0 to D-1) of std_logic_vector(31 downto 0);
    variable hm   : mat_t;
    variable gv, uexp : vec_t;
    variable errores : integer := 0;
    variable sig : std_logic_vector(31 downto 0) := (others => '0');
    variable got : boolean;
    variable polls : natural;
  begin
    start <= '0';
    rst_n <= '0';
    wait for 5*TCLK;
    wait until rising_edge(clk);
    rst_n <= '1';
    wait until rising_edge(clk);

    file_open(f, VEC_FILE, read_mode);
    readline(f, l);
    read(l, t);

    for tt in 0 to t-1 loop
      readline(f, l);
      read(l, n); read(l, mi); hread(l, w); step_f <= w;
      hread(l, w); umax_f <= w;
      for i in 0 to n-1 loop
        readline(f, l);
        for j in 0 to n-1 loop
          hread(l, w); hm(i, j) := w;
        end loop;
      end loop;
      readline(f, l);
      for i in 0 to n-1 loop hread(l, w); gv(i) := w; end loop;
      readline(f, l);
      for i in 0 to n-1 loop hread(l, w); uexp(i) := w; end loop;

      -- cargar H (rol del DMA LOAD_H) y g (LOAD_G)
      for i in 0 to n-1 loop
        for j in 0 to n-1 loop
          hw_en <= '1';
          hw_row <= std_logic_vector(to_unsigned(i, IDX_W));
          hw_col <= std_logic_vector(to_unsigned(j, IDX_W));
          hw_d   <= hm(i, j);
          wait until rising_edge(clk);
        end loop;
      end loop;
      hw_en <= '0';
      for i in 0 to n-1 loop
        gw_en <= '1';
        gw_a  <= std_logic_vector(to_unsigned(i, IDX_W));
        gw_d  <= gv(i);
        wait until rising_edge(clk);
      end loop;
      gw_en <= '0';

      -- configurar y lanzar
      n_dim   <= std_logic_vector(to_unsigned(n, IDX_W));
      maxiter <= std_logic_vector(to_unsigned(mi, 16));
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      got := false; polls := 0;
      while (not got) and (polls < POLL_LIM) loop
        wait until rising_edge(clk);
        wait for 1 ns;
        if done = '1' then got := true; end if;
        polls := polls + 1;
      end loop;
      if not got then
        report "TIMEOUT en test " & integer'image(tt) severity failure;
      end if;

      if unsigned(iter_cnt) /= to_unsigned(mi-1, 16) then
        errores := errores + 1;
        report "ITER_CNT incorrecto en test " & integer'image(tt) severity note;
      end if;

      -- leer U por el puerto externo (registrado, sin enable: 2 ciclos)
      for i in 0 to n-1 loop
        ext_a <= std_logic_vector(to_unsigned(i, IDX_W));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        sig := sig(30 downto 0) & sig(31);
        sig := sig xor ext_d;
        if ext_d /= uexp(i) then
          errores := errores + 1;
          if errores <= 10 then
            report "DESACUERDO test " & integer'image(tt) &
                   " U[" & integer'image(i) & "] got=0x" & to_hstring(ext_d) &
                   " exp=0x" & to_hstring(uexp(i)) severity note;
          end if;
        end if;
      end loop;
      wait until rising_edge(clk);
    end loop;
    file_close(f);

    report "T=" & integer'image(t) &
           " ERRORES=" & integer'image(errores) &
           " FIRMA_L1C=0x" & to_hstring(sig) &
           " T=" & time'image(now);

    assert errores = 0
      report "CAPA 1C FALLO: hay desacuerdos con el oraculo" severity failure;

    fin <= true;
    finish;
  end process;

end architecture sim;
