-- ============================================================================
-- tb_fp32_fma.vhd — Capa 1a del IP ADCS: fp32_fma vs oraculo Python (Fraction).
--
-- Lee vectors_fma.txt (N en la primera linea; luego "A B C ESPERADO" en hex),
-- alimenta el DUT a throughput pleno (1 vector/ciclo, valida el pipeline) y
-- compara cada salida. Criterio de PASS: ERRORES=0, firma bit-identica al
-- oraculo y timestamp final determinista.
--   FIRMA = fold( sig := rotl(sig,1) xor result )
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use std.env.all;

entity tb_fp32_fma is
  generic (
    MUT      : natural := 0;
    VEC_FILE : string  := "vectors_fma.txt"
  );
end entity tb_fp32_fma;

architecture sim of tb_fp32_fma is
  constant TCLK : time    := 4 ns;          -- 250 MHz
  constant LAT  : natural := 8;
  constant MAXV : natural := 65536;

  type slv32_arr is array (natural range <>) of std_logic_vector(31 downto 0);

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal in_valid  : std_logic := '0';
  signal a, b, c   : std_logic_vector(31 downto 0) := (others => '0');
  signal out_valid : std_logic;
  signal result    : std_logic_vector(31 downto 0);
  signal fin       : boolean := false;
begin

  clk <= not clk after TCLK/2 when not fin else '0';

  u_dut : entity work.fp32_fma
    generic map (LAT_FMA => LAT, MUT => MUT)
    port map (
      clk => clk, rst_n => rst_n, in_valid => in_valid,
      a => a, b => b, c => c,
      out_valid => out_valid, result => result);

  p_main : process
    file     f       : text;
    variable l       : line;
    variable n       : integer;
    variable va, vb, vc, vr : std_logic_vector(31 downto 0);
    variable ta      : slv32_arr(0 to MAXV-1);
    variable tb      : slv32_arr(0 to MAXV-1);
    variable tc      : slv32_arr(0 to MAXV-1);
    variable texp    : slv32_arr(0 to MAXV-1);
    variable idx_out : integer := 0;
    variable errores : integer := 0;
    variable sig     : std_logic_vector(31 downto 0) := (others => '0');
  begin
    file_open(f, VEC_FILE, read_mode);
    readline(f, l);
    read(l, n);
    assert n > 0 and n <= MAXV
      report "Numero de vectores fuera de rango" severity failure;
    for i in 0 to n-1 loop
      readline(f, l);
      hread(l, va); hread(l, vb); hread(l, vc); hread(l, vr);
      ta(i) := va; tb(i) := vb; tc(i) := vc; texp(i) := vr;
    end loop;
    file_close(f);

    rst_n <= '0';
    wait for 5*TCLK;
    wait until rising_edge(clk);
    rst_n <= '1';

    for k in 0 to n + LAT + 4 loop
      wait until rising_edge(clk);
      wait for 1 ns;                        -- muestrear tras propagacion
      if out_valid = '1' then
        sig := sig(30 downto 0) & sig(31);  -- rotl 1
        sig := sig xor result;
        if result /= texp(idx_out) then
          errores := errores + 1;
          if errores <= 10 then
            report "DESACUERDO vec " & integer'image(idx_out) severity note;
          end if;
        end if;
        idx_out := idx_out + 1;
      end if;
      if k < n then
        a <= ta(k); b <= tb(k); c <= tc(k);
        in_valid <= '1';
      else
        in_valid <= '0';
      end if;
    end loop;

    assert idx_out = n
      report "Salidas recibidas /= N (pipeline roto)" severity failure;

    report "N=" & integer'image(n) &
           " ERRORES=" & integer'image(errores) &
           " FIRMA_L1A=0x" & to_hstring(sig) &
           " T=" & time'image(now);

    assert errores = 0
      report "CAPA 1A FALLO: hay desacuerdos con el oraculo" severity failure;

    fin <= true;
    finish;
  end process;

end architecture sim;
