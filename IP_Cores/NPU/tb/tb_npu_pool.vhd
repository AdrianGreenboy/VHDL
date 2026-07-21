-- HERCOSSNUX NPU - testbench L1 del maxpool 2x2 (1 etapa de registro).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_npu_pool is
  generic (
    G_MUT     : natural := 0;
    G_VECFILE : string  := "vec/vec_pool.txt"
  );
end entity tb_npu_pool;

architecture sim of tb_npu_pool is

  constant CP : time := 10 ns;

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal valid_in  : std_logic := '0';
  signal d00, d01, d10, d11 : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal valid_out : std_logic;
  signal data_out  : signed(C_DATA_W-1 downto 0);
  signal done      : boolean := false;

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

  dut : entity work.npu_pool
    generic map (G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n, valid_in => valid_in,
              d00 => d00, d01 => d01, d10 => d10, d11 => d11,
              valid_out => valid_out, data_out => data_out);

  stim : process
    file     fh   : text;
    variable ln   : line;
    variable st   : file_open_status;
    variable ok   : boolean;
    variable s2   : string(1 to 2);
    variable c    : character;
    variable w    : t_data_arr(0 to 3);
    variable ev   : signed(C_DATA_W-1 downto 0);
    variable ncas : natural := 0;
    variable nerr : natural := 0;
    variable sig  : unsigned(31 downto 0) := C_SIG_INIT;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_npu_pool: no se pudo abrir el archivo de vectores" severity failure;

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      for i in 0 to 3 loop
        read(ln, s2, ok);
        assert ok report "tb_npu_pool: muestra mal formada" severity failure;
        w(i) := signed(hex2slv(s2));
        read(ln, c, ok);
      end loop;
      read(ln, s2, ok);
      assert ok report "tb_npu_pool: esperado mal formado" severity failure;
      ev := signed(hex2slv(s2));

      valid_in <= '1';
      d00 <= w(0); d01 <= w(1); d10 <= w(2); d11 <= w(3);
      wait until rising_edge(clk);
      valid_in <= '0';
      wait until rising_edge(clk);
      wait for CP/4;

      if data_out /= ev then
        nerr := nerr + 1;
        if nerr <= 5 then
          report "tb_npu_pool: discrepancia en caso " & integer'image(ncas)
               & " obtenido " & integer'image(to_integer(data_out))
               & " esperado " & integer'image(to_integer(ev))
            severity warning;
        end if;
      end if;

      sig  := sig_update(sig, data_out);
      ncas := ncas + 1;
    end loop;

    file_close(fh);

    if nerr = 0 then
      report "TB_POOL PASS casos=" & integer'image(ncas)
           & " SIG=0x" & to_hstring(sig) severity note;
    else
      report "TB_POOL FAIL casos=" & integer'image(ncas)
           & " errores=" & integer'image(nerr)
           & " SIG=0x" & to_hstring(sig) severity note;
    end if;

    done <= true;
    wait;
  end process;

end architecture sim;
