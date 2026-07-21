-- HERCOSSNUX NPU - testbench L2 del array sistolico.
-- Estimulo doble:
--   (a) adversario: fuerza saturacion en ambos signos, negativos y 64/64 PEs
--   (b) opcional: feature maps reales (se cubren en L3)
-- Recorre cada caso del archivo adversario, ejecuta la conv 3x3 completa
-- sobre 8x8 con 8 canales de entrada y 8 de salida, y compara la salida
-- post-requantize contra la referencia, acumulando firma.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_npu_array is
  generic (
    G_MUT     : natural := 0;
    G_VECFILE : string  := "vec/vec_adversario.txt"
  );
end entity tb_npu_array;

architecture sim of tb_npu_array is

  constant CP  : time    := 10 ns;
  constant DIM : natural := 8;   -- H = W = 8
  constant CH  : natural := 8;   -- canales in = out = PE_DIM

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

  -- requantize por canal
  signal rq_valid  : std_logic := '0';
  signal rq_relu   : std_logic := '0';
  signal rq_mult   : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal rq_dout   : t_data_arr(0 to 7);
  signal rq_vout   : std_logic_vector(0 to 7);

  type t_img is array (0 to CH-1, 0 to DIM-1, 0 to DIM-1) of signed(C_DATA_W-1 downto 0);
  signal x_img : t_img;
  signal y_exp : t_img;

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
    generic map (G_PE_DIM => 8, G_ACC_W => C_ACC_W, G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n, win_start => win_start, en => en,
              win_end => win_end, a_col => a_col, w_mat => w_mat,
              bias_in => bias_in, valid_out => arr_valid, acc_out => arr_acc);

  -- un requantize por canal de salida
  g_rq : for k in 0 to 7 generate
    u_rq : entity work.npu_requant
      generic map (G_ACC_W => C_ACC_W, G_SHIFT => C_SHIFT, G_MUT => 0)
      port map (clk => clk, rst_n => rst_n, valid_in => arr_valid,
                relu_en => rq_relu, acc_in => arr_acc(k), mult_in => rq_mult,
                valid_out => rq_vout(k), data_out => rq_dout(k));
  end generate;

  stim : process
    file     fh    : text;
    variable ln    : line;
    variable st    : file_open_status;
    variable ok    : boolean;
    variable s2    : string(1 to 2);
    variable s8    : string(1 to 8);
    variable tok   : string(1 to 32);
    variable c     : character;
    variable ncas  : natural := 0;
    variable nerr  : natural := 0;
    variable sig   : unsigned(31 downto 0) := C_SIG_INIT;
    variable wbuf  : t_data_arr(0 to 8*8*9-1);
    variable relu_v : natural;
    variable multv : signed(C_MULT_W-1 downto 0);
    variable biasv : t_acc_arr(0 to 7);
    variable iy, ix : integer;

    procedure read_hex2 (variable l : inout line; variable v : out signed(C_DATA_W-1 downto 0)) is
      variable s : string(1 to 2);
      variable o : boolean;
    begin
      read(l, s, o);
      v := signed(hex2slv(s));
    end procedure;

  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_npu_array: no se pudo abrir el archivo de vectores" severity failure;

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length = 0 then next; end if;
      if ln(ln'low) = '#' then next; end if;

      -- CASO <nombre>
      if ln'length >= 4 and ln(ln'low to ln'low+3) = "CASO" then

        -- MULT
        readline(fh, ln);
        read(ln, tok(1 to 4), ok);            -- "MULT"
        read(ln, c, ok);
        read(ln, s8, ok);
        multv := signed(hex2slv(s8));

        -- RELU
        readline(fh, ln);
        read(ln, tok(1 to 4), ok);            -- "RELU"
        read(ln, c, ok);
        read(ln, c, ok);
        relu_v := character'pos(c) - character'pos('0');

        -- BIAS
        readline(fh, ln);
        read(ln, tok(1 to 4), ok);            -- "BIAS"
        for k in 0 to 7 loop
          read(ln, c, ok);
          read(ln, s8, ok);
          biasv(k) := signed(hex2slv(s8));
        end loop;

        -- x[8][8][8]
        for cin in 0 to CH-1 loop
          for yy in 0 to DIM-1 loop
            readline(fh, ln);
            for xx in 0 to DIM-1 loop
              read(ln, s2, ok);
              x_img(cin, yy, xx) <= signed(hex2slv(s2));
              if xx < DIM-1 then read(ln, c, ok); end if;
            end loop;
          end loop;
        end loop;

        -- w[8*8*9] en lineas de 9
        for i in 0 to (8*8*9)/9 - 1 loop
          readline(fh, ln);
          for j in 0 to 8 loop
            read(ln, s2, ok);
            wbuf(i*9 + j) := signed(hex2slv(s2));
            if j < 8 then read(ln, c, ok); end if;
          end loop;
        end loop;

        -- y esperado [8][8][8]
        for o in 0 to CH-1 loop
          for yy in 0 to DIM-1 loop
            readline(fh, ln);
            for xx in 0 to DIM-1 loop
              read(ln, s2, ok);
              y_exp(o, yy, xx) <= signed(hex2slv(s2));
              if xx < DIM-1 then read(ln, c, ok); end if;
            end loop;
          end loop;
        end loop;

        wait for 0 ns;
        rq_mult <= multv;
        rq_relu <= '1' when relu_v = 1 else '0';
        bias_in <= biasv;

        -- Recorrer todas las posiciones de salida
        for yy in 0 to DIM-1 loop
          for xx in 0 to DIM-1 loop

            -- limpiar acumuladores
            win_start <= '1'; en <= '0'; win_end <= '0';
            wait until rising_edge(clk);
            win_start <= '0';

            -- 9 posiciones del kernel
            for ky in 0 to 2 loop
              for kx in 0 to 2 loop
                iy := yy + ky - 1;
                ix := xx + kx - 1;
                for r in 0 to CH-1 loop
                  if iy >= 0 and iy < DIM and ix >= 0 and ix < DIM then
                    a_col(r) <= x_img(r, iy, ix);
                  else
                    a_col(r) <= (others => '0');   -- padding same
                  end if;
                end loop;
                for k in 0 to CH-1 loop
                  for r in 0 to CH-1 loop
                    w_mat(k*8 + r) <= wbuf(((k*CH + r)*3 + ky)*3 + kx);
                  end loop;
                end loop;
                en <= '1';
                wait until rising_edge(clk);
              end loop;
            end loop;
            en <= '0';

            -- disparar reduccion
            win_end <= '1';
            wait until rising_edge(clk);
            win_end <= '0';

            -- esperar la salida del requantize (3 de reduccion + 3 de requantize)
            for w in 0 to 7 loop
              wait until rising_edge(clk);
            end loop;
            wait for CP/4;

            for o in 0 to CH-1 loop
              if rq_dout(o) /= y_exp(o, yy, xx) then
                nerr := nerr + 1;
                if nerr <= 5 then
                  report "tb_npu_array: discrepancia caso " & integer'image(ncas)
                       & " y=" & integer'image(yy) & " x=" & integer'image(xx)
                       & " o=" & integer'image(o)
                       & " obtenido " & integer'image(to_integer(rq_dout(o)))
                       & " esperado " & integer'image(to_integer(y_exp(o, yy, xx)))
                    severity warning;
                end if;
              end if;
              sig := sig_update(sig, rq_dout(o));
            end loop;

          end loop;
        end loop;

        ncas := ncas + 1;
      end if;
    end loop;

    file_close(fh);

    if nerr = 0 then
      report "TB_ARRAY PASS casos=" & integer'image(ncas)
           & " SIG=0x" & to_hstring(sig) severity note;
    else
      report "TB_ARRAY FAIL casos=" & integer'image(ncas)
           & " errores=" & integer'image(nerr)
           & " SIG=0x" & to_hstring(sig) severity note;
    end if;

    done <= true;
    wait;
  end process;

end architecture sim;
