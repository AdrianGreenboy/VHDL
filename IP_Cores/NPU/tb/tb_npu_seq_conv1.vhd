-- HERCOSSNUX NPU - testbench del secuenciador conv1 + pool1.
-- Criterio de PASS: firma de pool1 identica a la del oraculo (0xE4C64381)
-- sobre las 8 imagenes reales.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_npu_seq_conv1 is
  generic (
    G_MUT     : natural := 0;
    G_VECFILE : string  := "vec/vec_l3_conv1.txt"
  );
end entity tb_npu_seq_conv1;

architecture sim of tb_npu_seq_conv1 is

  constant CP : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal img_we   : std_logic := '0';
  signal img_addr : unsigned(7 downto 0) := (others => '0');
  signal img_data : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal w_we     : std_logic := '0';
  signal w_addr   : unsigned(6 downto 0) := (others => '0');
  signal w_data   : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b_we     : std_logic := '0';
  signal b_addr   : unsigned(2 downto 0) := (others => '0');
  signal b_data   : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal mult_in  : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal start    : std_logic := '0';
  signal busy     : std_logic;
  signal done_s   : std_logic;
  signal out_addr : unsigned(8 downto 0) := (others => '0');
  signal out_data : signed(C_DATA_W-1 downto 0);
  signal sim_done : boolean := false;

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

  clk <= not clk after CP/2 when not sim_done else '0';

  dut : entity work.npu_seq_conv1
    generic map (G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n,
              img_we => img_we, img_addr => img_addr, img_data => img_data,
              w_we => w_we, w_addr => w_addr, w_data => w_data,
              b_we => b_we, b_addr => b_addr, b_data => b_data,
              mult_in => mult_in, start => start, busy => busy, done => done_s,
              out_addr => out_addr, out_data => out_data);

  stim : process
    file     fh   : text;
    variable ln   : line;
    variable st   : file_open_status;
    variable ok   : boolean;
    variable s2   : string(1 to 2);
    variable s8   : string(1 to 8);
    variable c    : character;
    variable tok  : string(1 to 4);
    variable m1v  : integer;
    variable nimg : natural := 0;
    variable nerr : natural := 0;
    variable sig  : unsigned(31 downto 0) := C_SIG_INIT;
    variable expv : signed(C_DATA_W-1 downto 0);
    variable line_ok : boolean;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_npu_seq_conv1: no se pudo abrir el archivo" severity failure;

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    -- cabecera: leer M1 del comentario
    readline(fh, ln);                      -- "# ... N=8"
    readline(fh, ln);                      -- "# M1=... SHIFT=31"
    -- se fija el multiplicador conocido de la spec
    mult_in <= to_signed(5064654, C_MULT_W);

    -- pesos W1
    readline(fh, ln);                      -- comentario W1
    for o in 0 to 7 loop
      readline(fh, ln);
      for j in 0 to 8 loop
        read(ln, s2, ok);
        w_we <= '1';
        w_addr <= to_unsigned(o*9 + j, 7);
        w_data <= signed(hex2slv(s2));
        wait until rising_edge(clk);
        if j < 8 then read(ln, c, ok); end if;
      end loop;
    end loop;
    w_we <= '0';

    -- bias B1
    readline(fh, ln);                      -- comentario B1
    readline(fh, ln);
    for o in 0 to 7 loop
      read(ln, s8, ok);
      b_we <= '1';
      b_addr <= to_unsigned(o, 3);
      b_data <= signed(hex2slv(s8));
      wait until rising_edge(clk);
      if o < 7 then read(ln, c, ok); end if;
    end loop;
    b_we <= '0';

    readline(fh, ln);                      -- comentario imagenes

    -- ---- bucle de imagenes ----
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length = 0 then next; end if;

      if ln'length >= 9 and ln(ln'low to ln'low+8) = "SIGNATURE" then
        exit;
      end if;

      if ln'length >= 3 and ln(ln'low to ln'low+2) = "IMG" then
        -- cargar imagen
        for y in 0 to 15 loop
          readline(fh, ln);
          for x in 0 to 15 loop
            read(ln, s2, ok);
            img_we <= '1';
            img_addr <= to_unsigned(y*16 + x, 8);
            img_data <= signed(hex2slv(s2));
            wait until rising_edge(clk);
            if x < 15 then read(ln, c, ok); end if;
          end loop;
        end loop;
        img_we <= '0';

        -- arrancar
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until rising_edge(clk);

        -- esperar fin (guardado: no usar wait until si ya es falso)
        while busy = '1' loop
          wait until rising_edge(clk);
        end loop;
        wait until rising_edge(clk);

        -- leer POOL1 esperado y comparar
        readline(fh, ln);                  -- "POOL1"
        for ch in 0 to 7 loop
          for y in 0 to 7 loop
            readline(fh, ln);
            for x in 0 to 7 loop
              read(ln, s2, ok);
              expv := signed(hex2slv(s2));
              out_addr <= to_unsigned(ch*64 + y*8 + x, 9);
              wait for CP/4;
              if out_data /= expv then
                nerr := nerr + 1;
                if nerr <= 5 then
                  report "tb_npu_seq_conv1: img " & integer'image(nimg)
                       & " ch=" & integer'image(ch)
                       & " y=" & integer'image(y) & " x=" & integer'image(x)
                       & " obtenido " & integer'image(to_integer(out_data))
                       & " esperado " & integer'image(to_integer(expv))
                    severity warning;
                end if;
              end if;
              sig := sig_update(sig, out_data);
              wait for 3*CP/4;
              if x < 7 then read(ln, c, ok); end if;
            end loop;
          end loop;
        end loop;

        nimg := nimg + 1;
      end if;
    end loop;

    file_close(fh);

    if nerr = 0 then
      report "TB_SEQ_CONV1 PASS imgs=" & integer'image(nimg)
           & " SIG=0x" & to_hstring(sig) severity note;
    else
      report "TB_SEQ_CONV1 FAIL imgs=" & integer'image(nimg)
           & " errores=" & integer'image(nerr)
           & " SIG=0x" & to_hstring(sig) severity note;
    end if;

    sim_done <= true;
    wait;
  end process;

end architecture sim;
