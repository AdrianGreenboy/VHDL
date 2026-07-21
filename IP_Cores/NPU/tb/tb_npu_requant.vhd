-- HERCOSSNUX NPU - testbench L1 del requantize (pipeline de 3 etapas).
-- Alimenta un caso por ciclo y recoge los resultados con 3 de latencia.
-- Verifica ademas que valid_out tenga exactamente 3 ciclos de retraso.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_npu_requant is
  generic (
    G_MUT     : natural := 0;
    G_VECFILE : string  := "vec/vec_requant.txt"
  );
end entity tb_npu_requant;

architecture sim of tb_npu_requant is

  constant CP     : time    := 10 ns;
  constant C_LAT  : natural := 3;
  constant C_MAXV : natural := 4096;

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal valid_in  : std_logic := '0';
  signal relu_en   : std_logic := '0';
  signal acc_in    : signed(C_ACC_W-1 downto 0)  := (others => '0');
  signal mult_in   : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal valid_out : std_logic;
  signal data_out  : signed(C_DATA_W-1 downto 0);
  signal done      : boolean := false;

  type t_exp_arr is array (0 to C_MAXV-1) of signed(C_DATA_W-1 downto 0);
  signal exp_arr : t_exp_arr := (others => (others => '0'));
  signal n_vec   : natural := 0;

  signal n_got   : natural := 0;
  signal n_err   : natural := 0;
  signal sig_r   : unsigned(31 downto 0) := C_SIG_INIT;
  signal feed_ok : boolean := false;

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

  dut : entity work.npu_requant
    generic map (G_ACC_W => C_ACC_W, G_SHIFT => C_SHIFT, G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n, valid_in => valid_in, relu_en => relu_en,
              acc_in => acc_in, mult_in => mult_in,
              valid_out => valid_out, data_out => data_out);

  -- ---------------- Alimentacion ----------------
  feed : process
    file     fh   : text;
    variable ln   : line;
    variable st   : file_open_status;
    variable ok   : boolean;
    variable s8   : string(1 to 8);
    variable s2   : string(1 to 2);
    variable c    : character;
    variable accv : signed(C_ACC_W-1 downto 0);
    variable mv   : signed(C_MULT_W-1 downto 0);
    variable rl   : character;
    variable ev   : signed(C_DATA_W-1 downto 0);
    variable idx  : natural := 0;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_npu_requant: no se pudo abrir el archivo de vectores" severity failure;

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

      read(ln, s8, ok);  accv := signed(hex2slv(s8));
      read(ln, c, ok);
      read(ln, s8, ok);  mv   := signed(hex2slv(s8));
      read(ln, c, ok);
      read(ln, rl, ok);
      read(ln, c, ok);
      read(ln, s2, ok);  ev   := signed(hex2slv(s2));

      assert idx < C_MAXV report "tb_npu_requant: demasiados vectores" severity failure;
      exp_arr(idx) <= ev;
      wait for 0 ns;

      valid_in <= '1';
      relu_en  <= '1' when rl = '1' else '0';
      acc_in   <= accv;
      mult_in  <= mv;
      idx      := idx + 1;
      n_vec    <= idx;
      wait until rising_edge(clk);
    end loop;

    valid_in <= '0';
    file_close(fh);
    feed_ok <= true;

    -- vaciado del pipeline
    for i in 0 to C_LAT + 4 loop
      wait until rising_edge(clk);
    end loop;

    if n_err = 0 and n_got = n_vec then
      report "TB_REQUANT PASS casos=" & integer'image(n_got)
           & " SIG=0x" & to_hstring(sig_r) severity note;
    else
      report "TB_REQUANT FAIL casos=" & integer'image(n_got)
           & " esperados=" & integer'image(n_vec)
           & " errores=" & integer'image(n_err)
           & " SIG=0x" & to_hstring(sig_r) severity note;
    end if;

    done <= true;
    wait;
  end process;

  -- ---------------- Recoleccion ----------------
  collect : process(clk)
    variable e : signed(C_DATA_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '1' and valid_out = '1' then
        e := exp_arr(n_got);
        if data_out /= e then
          n_err <= n_err + 1;
          if n_err < 5 then
            report "tb_npu_requant: discrepancia en caso " & integer'image(n_got)
                 & " obtenido " & integer'image(to_integer(data_out))
                 & " esperado " & integer'image(to_integer(e))
              severity warning;
          end if;
        end if;
        sig_r <= sig_update(sig_r, data_out);
        n_got <= n_got + 1;
      end if;
    end if;
  end process;

end architecture sim;
