-------------------------------------------------------------------------------
-- tb_cordic_dp.vhd  --  Layer 1a testbench del datapath CORDIC.
--
-- Lee tb_cordic.mem (generado por dsp_oracle.py --dump):
--   mode x_in y_in z_in  x_exp y_exp z_exp   (7 campos hex por linea)
-- Alimenta cada caso, espera 'done', compara bit-exacto contra el oraculo.
--
-- Criterio de pass: fin de simulacion en timestamp DETERMINISTA con
-- "CORDIC OK" y contador de errores = 0. Cualquier mutacion del datapath
-- rompe el bit-exacto y dispara "MUTANTE VIVO" (assert failure).
--
-- Mensajes de assert en ASCII (GHDL rechaza no-ASCII).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_cordic_dp is
end entity;

architecture sim of tb_cordic_dp is

  constant CLK_P : time := 10 ns;

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal start : std_logic := '0';
  signal mode  : std_logic := '0';
  signal x_in, y_in, z_in : std_logic_vector(15 downto 0) := (others => '0');
  signal x_out, y_out, z_out : std_logic_vector(15 downto 0);
  signal busy, done : std_logic;

  signal sim_done : boolean := false;

begin

  dut : entity work.cordic_dp
    generic map (ITERS => 16)
    port map (
      clk => clk, rst => rst, start => start, mode => mode,
      x_in => x_in, y_in => y_in, z_in => z_in,
      x_out => x_out, y_out => y_out, z_out => z_out,
      busy => busy, done => done
    );

  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    file     fh    : text open read_mode is "tb_cordic.mem";
    variable ln    : line;
    variable v_mode : integer;
    variable v_xin, v_yin, v_zin : std_logic_vector(15 downto 0);
    variable v_xexp, v_yexp, v_zexp : std_logic_vector(15 downto 0);
    variable errors : integer := 0;
    variable ncases : integer := 0;

    -- lee un campo hex de 4 digitos
    procedure rd_hex(variable l : inout line; v : out std_logic_vector(15 downto 0)) is
    begin
      hread(l, v);
    end procedure;

  begin
    -- reset
    rst <= '1';
    wait for 4*CLK_P;
    rst <= '0';
    wait for 2*CLK_P;

    while not endfile(fh) loop
      readline(fh, ln);
      read(ln, v_mode);           -- primer campo: modo (0/1) decimal
      hread(ln, v_xin);
      hread(ln, v_yin);
      hread(ln, v_zin);
      hread(ln, v_xexp);
      hread(ln, v_yexp);
      hread(ln, v_zexp);

      -- cargar estimulo
      mode <= '0' when v_mode = 0 else '1';
      x_in <= v_xin;
      y_in <= v_yin;
      z_in <= v_zin;
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      -- esperar done (con guarda anti-deadlock)
      for w in 0 to 63 loop
        wait until rising_edge(clk);
        exit when done = '1';
      end loop;
      assert done = '1'
        report "TIMEOUT: done nunca se activo en caso " & integer'image(ncases)
        severity failure;

      -- comparar bit-exacto (segun modo, comparamos los campos relevantes)
      if v_mode = 0 then
        -- rotacion: x_out=cos, y_out=sin
        if x_out /= v_xexp or y_out /= v_yexp then
          errors := errors + 1;
          report "ROT mismatch caso " & integer'image(ncases) &
                 " z=" & to_hstring(v_zin) &
                 " got(" & to_hstring(x_out) & "," & to_hstring(y_out) & ")" &
                 " exp(" & to_hstring(v_xexp) & "," & to_hstring(v_yexp) & ")"
            severity warning;
        end if;
      else
        -- vectoring: x_out=mag, z_out=fase
        if x_out /= v_xexp or z_out /= v_zexp then
          errors := errors + 1;
          report "VEC mismatch caso " & integer'image(ncases) &
                 " x=" & to_hstring(v_xin) & " y=" & to_hstring(v_yin) &
                 " got_mag=" & to_hstring(x_out) & " got_ph=" & to_hstring(z_out) &
                 " exp_mag=" & to_hstring(v_xexp) & " exp_ph=" & to_hstring(v_zexp)
            severity warning;
        end if;
      end if;

      ncases := ncases + 1;
    end loop;

    file_close(fh);

    report "CORDIC casos=" & integer'image(ncases) &
           " errores=" & integer'image(errors);
    assert errors = 0
      report "MUTANTE VIVO: " & integer'image(errors) & " mismatches"
      severity failure;
    report "CORDIC OK - firma bit-exacta contra oraculo";

    sim_done <= true;
    wait;
  end process;

end architecture;
