-------------------------------------------------------------------------------
-- tb_fir_dp.vhd  --  Layer 1a testbench del datapath FIR simetrico.
--
-- Lee tb_fir.mem (dsp_oracle.py --dump):
--   linea 1: NCASES
--   por caso: "CASE L HALF NX", luego HALF coefs (hex), luego NX pares "x y".
-- Para cada caso: carga coefs+LEN, empuja NX muestras, compara y[n] bit-exacto.
--
-- Pass: fin determinista con "FIR OK" y errores=0. Mutacion -> "MUTANTE VIVO".
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_fir_dp is
end entity;

architecture sim of tb_fir_dp is
  constant CLK_P : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal cfg_len  : std_logic_vector(6 downto 0) := (others => '0');
  signal coef_we  : std_logic := '0';
  signal coef_idx : std_logic_vector(5 downto 0) := (others => '0');
  signal coef_dat : std_logic_vector(15 downto 0) := (others => '0');
  signal push     : std_logic := '0';
  signal x_in     : std_logic_vector(15 downto 0) := (others => '0');
  signal y_out    : std_logic_vector(15 downto 0);
  signal valid, busy : std_logic;

  signal sim_done : boolean := false;
begin

  dut : entity work.fir_dp
    generic map (MAXTAPS => 64)
    port map (clk=>clk, rst=>rst, cfg_len=>cfg_len,
              coef_we=>coef_we, coef_idx=>coef_idx, coef_dat=>coef_dat,
              push=>push, x_in=>x_in, y_out=>y_out, valid=>valid, busy=>busy);

  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    file     fh : text open read_mode is "tb_fir.mem";
    variable ln : line;
    variable ncases, L, half, nx : integer;
    variable tag : string(1 to 4);
    variable cval : std_logic_vector(15 downto 0);
    variable xval, yexp : std_logic_vector(15 downto 0);
    variable errors : integer := 0;
    variable total  : integer := 0;
  begin
    rst <= '1'; wait for 4*CLK_P; rst <= '0'; wait for 2*CLK_P;

    readline(fh, ln); read(ln, ncases);

    for c in 0 to ncases-1 loop
      readline(fh, ln);
      read(ln, tag);            -- "CASE"
      read(ln, L); read(ln, half); read(ln, nx);

      -- limpiar linea de retardo entre casos (estado inicial cero, como oraculo)
      rst <= '1'; wait until rising_edge(clk); wait until rising_edge(clk);
      rst <= '0'; wait until rising_edge(clk);

      -- cargar coeficientes
      for i in 0 to half-1 loop
        readline(fh, ln); hread(ln, cval);
        coef_idx <= std_logic_vector(to_unsigned(i, 6));
        coef_dat <= cval;
        coef_we  <= '1';
        wait until rising_edge(clk);
      end loop;
      coef_we <= '0';
      cfg_len <= std_logic_vector(to_unsigned(L, 7));
      wait until rising_edge(clk);

      -- empujar muestras y comparar
      for n in 0 to nx-1 loop
        readline(fh, ln);
        hread(ln, xval); hread(ln, yexp);
        x_in <= xval;
        push <= '1';
        wait until rising_edge(clk);
        push <= '0';
        -- esperar valid (guarda anti-deadlock)
        for w in 0 to 127 loop
          wait until rising_edge(clk);
          exit when valid = '1';
        end loop;
        assert valid = '1'
          report "TIMEOUT caso " & integer'image(c) & " n=" & integer'image(n)
          severity failure;
        if y_out /= yexp then
          errors := errors + 1;
          report "FIR mismatch L=" & integer'image(L) &
                 " n=" & integer'image(n) &
                 " got=" & to_hstring(y_out) & " exp=" & to_hstring(yexp)
            severity warning;
        end if;
        total := total + 1;
      end loop;
    end loop;

    file_close(fh);
    report "FIR casos_totales=" & integer'image(total) &
           " errores=" & integer'image(errors);
    assert errors = 0
      report "MUTANTE VIVO: " & integer'image(errors) & " mismatches"
      severity failure;
    report "FIR OK - firma bit-exacta contra oraculo";
    sim_done <= true;
    wait;
  end process;

end architecture;
