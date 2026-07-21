-- HERCOSSNUX NPU - testbench L1 del MAC.
-- Lee vec_mac.txt, corre cadenas de 9 MACs y compara el acumulador.
-- PASS = firma bit-identica y cero discrepancias.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_npu_mac is
  generic (
    G_MUT     : natural := 0;
    G_VECFILE : string  := "vec/vec_mac.txt"
  );
end entity tb_npu_mac;

architecture sim of tb_npu_mac is

  constant CP : time := 10 ns;

  signal clk     : std_logic := '0';
  signal rst_n   : std_logic := '0';
  signal en      : std_logic := '0';
  signal clr     : std_logic := '0';
  signal a_in    : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal w_in    : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal bias_in : signed(C_ACC_W-1 downto 0)  := (others => '0');
  signal acc_out : signed(C_ACC_W-1 downto 0);
  signal done    : boolean := false;

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

  dut : entity work.npu_mac
    generic map (G_ACC_W => C_ACC_W, G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n, en => en, clr => clr,
              a_in => a_in, w_in => w_in, bias_in => bias_in, acc_out => acc_out);

  stim : process
    file     fh    : text;
    variable ln    : line;
    variable st    : file_open_status;
    variable ok    : boolean;
    variable ncase : natural := 0;
    variable nerr  : natural := 0;
    variable sig   : unsigned(31 downto 0) := C_SIG_INIT;
    variable bias  : signed(C_ACC_W-1 downto 0);
    variable acts  : t_data_arr(0 to 8);
    variable wts   : t_data_arr(0 to 8);
    variable expv  : signed(C_ACC_W-1 downto 0);
    variable s8    : string(1 to 8);
    variable s2    : string(1 to 2);
    variable c     : character;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_npu_mac: no se pudo abrir el archivo de vectores" severity failure;

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    while not endfile(fh) loop
      readline(fh, ln);
      -- saltar comentarios y lineas vacias
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      -- linea 1: bias hex 8
      read(ln, s8, ok);
      assert ok report "tb_npu_mac: bias mal formado" severity failure;
      bias := signed(hex2slv(s8));

      -- linea 2: 9 activaciones
      readline(fh, ln);
      for i in 0 to 8 loop
        read(ln, s2, ok);
        assert ok report "tb_npu_mac: activacion mal formada" severity failure;
        acts(i) := signed(hex2slv(s2));
        if i < 8 then read(ln, c, ok); end if;
      end loop;

      -- linea 3: 9 pesos
      readline(fh, ln);
      for i in 0 to 8 loop
        read(ln, s2, ok);
        assert ok report "tb_npu_mac: peso mal formado" severity failure;
        wts(i) := signed(hex2slv(s2));
        if i < 8 then read(ln, c, ok); end if;
      end loop;

      -- linea 4: acumulador esperado
      readline(fh, ln);
      read(ln, s8, ok);
      assert ok report "tb_npu_mac: esperado mal formado" severity failure;
      expv := signed(hex2slv(s8));

      -- carga del bias
      en <= '1'; clr <= '1'; bias_in <= bias;
      a_in <= (others => '0'); w_in <= (others => '0');
      wait until rising_edge(clk);
      clr <= '0';

      -- 9 acumulaciones
      for i in 0 to 8 loop
        a_in <= acts(i);
        w_in <= wts(i);
        wait until rising_edge(clk);
      end loop;

      en <= '0';
      wait for CP/4;   -- muestreo estable dentro del ciclo

      if acc_out /= expv then
        nerr := nerr + 1;
        if nerr <= 5 then
          report "tb_npu_mac: discrepancia en caso " & integer'image(ncase)
               & " obtenido " & integer'image(to_integer(acc_out))
               & " esperado " & integer'image(to_integer(expv))
            severity warning;
        end if;
      end if;

      -- firma sobre los 4 bytes del acumulador
      for b in 0 to 3 loop
        sig := sig_update(sig, acc_out(8*b+7 downto 8*b));
      end loop;

      ncase := ncase + 1;
      wait until rising_edge(clk);
    end loop;

    file_close(fh);

    if nerr = 0 then
      report "TB_MAC PASS casos=" & integer'image(ncase)
           & " SIG=0x" & to_hstring(sig) severity note;
    else
      report "TB_MAC FAIL casos=" & integer'image(ncase)
           & " errores=" & integer'image(nerr)
           & " SIG=0x" & to_hstring(sig) severity note;
    end if;

    done <= true;
    wait;
  end process;

end architecture sim;
