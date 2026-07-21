-- HERCOSSNUX NPU - Layer 3, SONDA 2: protocolo de un tile.
--
-- Verifica que el array del Paso 3 produce las sumas parciales CRUDAS
-- (sin bias, sin requantize) de un tile real de conv2, sobre datos reales.
-- Comparar la suma cruda es mas estricto que comparar la salida final:
-- el requantize podria enmascarar errores de acumulacion.
--
-- Si esta sonda no pasa, no se construye el secuenciador.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_l3_sonda is
  generic (
    G_VECFILE : string := "vec/vec_l3_tile.txt"
  );
end entity tb_l3_sonda;

architecture sim of tb_l3_sonda is

  constant CP  : time    := 10 ns;
  constant DIM : natural := 8;
  constant CH  : natural := 8;

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal win_start : std_logic := '0';
  signal en        : std_logic := '0';
  signal win_end   : std_logic := '0';
  signal a_col     : t_data_arr(0 to 7) := (others => (others => '0'));
  signal w_mat     : t_data_arr(0 to 63) := (others => (others => '0'));
  signal bias_in   : t_acc_arr(0 to 7) := (others => (others => '0'));
  signal arr_valid : std_logic;
  signal arr_acc   : t_acc_arr(0 to 7);
  signal done      : boolean := false;

  type t_in  is array (0 to CH-1, 0 to DIM-1, 0 to DIM-1) of signed(C_DATA_W-1 downto 0);
  signal x_in : t_in;

  function hex2slv (s : string) return std_logic_vector is
    variable r : std_logic_vector(4*s'length-1 downto 0);
    variable d : natural;
  begin
    for i in s'range loop
      case s(i) is
        when '0' to '9' => d := character'pos(s(i)) - character'pos('0');
        when 'a' to 'f' => d := character'pos(s(i)) - character'pos('a') + 10;
        when 'A' to 'F' => d := character'pos(s(i)) - character'pos('A') + 10;
        when others     => d := 0;
      end case;
      r(r'high - 4*(i - s'low) downto r'high - 4*(i - s'low) - 3) :=
        std_logic_vector(to_unsigned(d, 4));
    end loop;
    return r;
  end function;

begin

  clk <= not clk after CP/2 when not done else '0';

  dut : entity work.npu_array
    generic map (G_PE_DIM => 8, G_ACC_W => C_ACC_W, G_MUT => 0)
    port map (clk => clk, rst_n => rst_n, win_start => win_start, en => en,
              win_end => win_end, a_col => a_col, w_mat => w_mat,
              bias_in => bias_in, valid_out => arr_valid, acc_out => arr_acc);

  stim : process
    file     fh   : text;
    variable ln   : line;
    variable st   : file_open_status;
    variable ok   : boolean;
    variable s2   : string(1 to 2);
    variable s8   : string(1 to 8);
    variable c    : character;
    variable wbuf : t_data_arr(0 to 8*8*9-1);
    variable expv : t_acc_arr(0 to 7);
    variable nerr : natural := 0;
    variable npix : natural := 0;
    variable sig  : unsigned(31 downto 0) := C_SIG_INIT;
    variable iy, ix : integer;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_l3_sonda: no se pudo abrir el archivo" severity failure;

    -- bias en cero: se compara la suma CRUDA
    bias_in <= (others => (others => '0'));

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    -- ---- leer entrada: 8 canales 8x8 ----
    readline(fh, ln);   -- comentario cabecera
    readline(fh, ln);   -- comentario entrada
    for cin in 0 to CH-1 loop
      for y in 0 to DIM-1 loop
        readline(fh, ln);
        for x in 0 to DIM-1 loop
          read(ln, s2, ok);
          x_in(cin, y, x) <= signed(hex2slv(s2));
          if x < DIM-1 then read(ln, c, ok); end if;
        end loop;
      end loop;
    end loop;

    -- ---- leer pesos: 64 lineas de 9 ----
    readline(fh, ln);   -- comentario pesos
    for n in 0 to 63 loop
      readline(fh, ln);
      for j in 0 to 8 loop
        read(ln, s2, ok);
        wbuf(n*9 + j) := signed(hex2slv(s2));
        if j < 8 then read(ln, c, ok); end if;
      end loop;
    end loop;

    readline(fh, ln);   -- comentario psum
    wait for 0 ns;

    -- ---- recorrer pixeles ----
    for y in 0 to DIM-1 loop
      for x in 0 to DIM-1 loop

        -- leer psum esperado de este pixel (8 canales)
        readline(fh, ln);
        for o in 0 to 7 loop
          read(ln, s8, ok);
          expv(o) := signed(hex2slv(s8));
          if o < 7 then read(ln, c, ok); end if;
        end loop;

        -- limpiar acumuladores
        win_start <= '1'; en <= '0'; win_end <= '0';
        wait until rising_edge(clk);
        win_start <= '0';

        -- 9 posiciones del kernel
        for ky in 0 to 2 loop
          for kx in 0 to 2 loop
            iy := y + ky - 1;
            ix := x + kx - 1;
            for r in 0 to CH-1 loop
              if iy >= 0 and iy < DIM and ix >= 0 and ix < DIM then
                a_col(r) <= x_in(r, iy, ix);
              else
                a_col(r) <= (others => '0');
              end if;
            end loop;
            -- w_mat(k*8 + r) = peso del par (canal_out k, canal_in r)
            for k in 0 to CH-1 loop
              for r in 0 to CH-1 loop
                w_mat(k*8 + r) <= wbuf((k*CH + r)*9 + ky*3 + kx);
              end loop;
            end loop;
            en <= '1';
            wait until rising_edge(clk);
          end loop;
        end loop;
        en <= '0';

        -- disparar reduccion y esperar los 3 niveles
        win_end <= '1';
        wait until rising_edge(clk);
        win_end <= '0';
        for w in 0 to 3 loop
          wait until rising_edge(clk);
        end loop;
        wait for CP/4;

        for o in 0 to 7 loop
          if arr_acc(o) /= expv(o) then
            nerr := nerr + 1;
            if nerr <= 5 then
              report "tb_l3_sonda: discrepancia y=" & integer'image(y)
                   & " x=" & integer'image(x) & " o=" & integer'image(o)
                   & " obtenido " & integer'image(to_integer(arr_acc(o)))
                   & " esperado " & integer'image(to_integer(expv(o)))
                severity warning;
            end if;
          end if;
          for b in 0 to 3 loop
            sig := sig_update(sig, arr_acc(o)(8*b+7 downto 8*b));
          end loop;
        end loop;

        npix := npix + 1;
        wait until rising_edge(clk);
      end loop;
    end loop;

    file_close(fh);

    if nerr = 0 then
      report "TB_L3_SONDA PASS pixeles=" & integer'image(npix)
           & " SIG=0x" & to_hstring(sig) severity note;
    else
      report "TB_L3_SONDA FAIL pixeles=" & integer'image(npix)
           & " errores=" & integer'image(nerr)
           & " SIG=0x" & to_hstring(sig) severity note;
    end if;

    done <= true;
    wait;
  end process;

end architecture sim;
