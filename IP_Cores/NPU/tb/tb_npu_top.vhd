-- HERCOSSNUX NPU - testbench del top level (cierra Layer 3).
-- Inferencia completa de 32 imagenes: imagen -> clase.
-- Criterio de PASS: SIG_LOGITS y SIG_CLASE identicas al oraculo.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;

entity tb_npu_top is
  generic (
    G_MUT     : natural := 0;
    G_NIMG    : natural := 32;   -- imagenes a procesar (32 = todas)
    G_VECFILE : string  := "vec/vec_l3_top.txt"
  );
end entity tb_npu_top;

architecture sim of tb_npu_top is

  constant CP : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal img_we   : std_logic := '0';
  signal img_addr : unsigned(7 downto 0) := (others => '0');
  signal img_data : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal w1_we    : std_logic := '0';
  signal w1_addr  : unsigned(6 downto 0) := (others => '0');
  signal w1_data  : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b1_we    : std_logic := '0';
  signal b1_addr  : unsigned(2 downto 0) := (others => '0');
  signal b1_data  : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal w2_we    : std_logic := '0';
  signal w2_addr  : unsigned(10 downto 0) := (others => '0');
  signal w2_data  : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b2_we    : std_logic := '0';
  signal b2_addr  : unsigned(3 downto 0) := (others => '0');
  signal b2_data  : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal w3_we    : std_logic := '0';
  signal w3_addr  : unsigned(11 downto 0) := (others => '0');
  signal w3_data  : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b3_we    : std_logic := '0';
  signal b3_addr  : unsigned(3 downto 0) := (others => '0');
  signal b3_data  : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal mult1    : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal mult2    : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal mult3    : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal start    : std_logic := '0';
  signal busy     : std_logic;
  signal done_s   : std_logic;
  signal p1_addr  : unsigned(8 downto 0) := (others => '0');
  signal p1_data  : signed(C_DATA_W-1 downto 0);
  signal p2_addr  : unsigned(7 downto 0) := (others => '0');
  signal p2_data  : signed(C_DATA_W-1 downto 0);
  signal lg_addr  : unsigned(3 downto 0) := (others => '0');
  signal lg_data  : signed(C_DATA_W-1 downto 0);
  signal clase    : unsigned(3 downto 0);
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

  dut : entity work.npu_top
    generic map (G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n,
              img_we => img_we, img_addr => img_addr, img_data => img_data,
              w1_we => w1_we, w1_addr => w1_addr, w1_data => w1_data,
              b1_we => b1_we, b1_addr => b1_addr, b1_data => b1_data,
              w2_we => w2_we, w2_addr => w2_addr, w2_data => w2_data,
              b2_we => b2_we, b2_addr => b2_addr, b2_data => b2_data,
              w3_we => w3_we, w3_addr => w3_addr, w3_data => w3_data,
              b3_we => b3_we, b3_addr => b3_addr, b3_data => b3_data,
              mult1_in => mult1, mult2_in => mult2, mult3_in => mult3,
              start => start, busy => busy, done => done_s,
              p1_addr => p1_addr, p1_data => p1_data,
              p2_addr => p2_addr, p2_data => p2_data,
              lg_addr => lg_addr, lg_data => lg_data, clase => clase);

  stim : process
    file     fh   : text;
    variable ln   : line;
    variable st   : file_open_status;
    variable ok   : boolean;
    variable s2   : string(1 to 2);
    variable s8   : string(1 to 8);
    variable c    : character;
    variable nimg : natural := 0;
    variable e_lg, e_cl : natural := 0;
    variable sig_lg : unsigned(31 downto 0) := C_SIG_INIT;
    variable sig_cl : unsigned(31 downto 0) := C_SIG_INIT;
    variable exp_sig_lg, exp_sig_cl : unsigned(31 downto 0) := (others => '0');
    variable expv  : signed(C_DATA_W-1 downto 0);
    variable expcl : integer;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok report "tb_npu_top: no se pudo abrir el archivo" severity failure;

    mult1 <= to_signed(5064654, C_MULT_W);
    mult2 <= to_signed(5353067, C_MULT_W);
    mult3 <= to_signed(4101566, C_MULT_W);

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    readline(fh, ln);   -- cabecera

    -- W1
    readline(fh, ln);
    for o in 0 to 7 loop
      readline(fh, ln);
      for j in 0 to 8 loop
        read(ln, s2, ok);
        w1_we <= '1'; w1_addr <= to_unsigned(o*9 + j, 7);
        w1_data <= signed(hex2slv(s2));
        wait until rising_edge(clk);
        if j < 8 then read(ln, c, ok); end if;
      end loop;
    end loop;
    w1_we <= '0';

    -- B1
    readline(fh, ln); readline(fh, ln);
    for o in 0 to 7 loop
      read(ln, s8, ok);
      b1_we <= '1'; b1_addr <= to_unsigned(o, 3);
      b1_data <= signed(hex2slv(s8));
      wait until rising_edge(clk);
      if o < 7 then read(ln, c, ok); end if;
    end loop;
    b1_we <= '0';

    -- W2
    readline(fh, ln);
    for n in 0 to 127 loop
      readline(fh, ln);
      for j in 0 to 8 loop
        read(ln, s2, ok);
        w2_we <= '1'; w2_addr <= to_unsigned(n*9 + j, 11);
        w2_data <= signed(hex2slv(s2));
        wait until rising_edge(clk);
        if j < 8 then read(ln, c, ok); end if;
      end loop;
    end loop;
    w2_we <= '0';

    -- B2
    readline(fh, ln); readline(fh, ln);
    for o in 0 to 15 loop
      read(ln, s8, ok);
      b2_we <= '1'; b2_addr <= to_unsigned(o, 4);
      b2_data <= signed(hex2slv(s8));
      wait until rising_edge(clk);
      if o < 15 then read(ln, c, ok); end if;
    end loop;
    b2_we <= '0';

    -- W3
    readline(fh, ln);
    for o in 0 to 9 loop
      readline(fh, ln);
      for i in 0 to 255 loop
        read(ln, s2, ok);
        w3_we <= '1'; w3_addr <= to_unsigned(o*256 + i, 12);
        w3_data <= signed(hex2slv(s2));
        wait until rising_edge(clk);
        if i < 255 then read(ln, c, ok); end if;
      end loop;
    end loop;
    w3_we <= '0';

    -- B3
    readline(fh, ln); readline(fh, ln);
    for o in 0 to 9 loop
      read(ln, s8, ok);
      b3_we <= '1'; b3_addr <= to_unsigned(o, 4);
      b3_data <= signed(hex2slv(s8));
      wait until rising_edge(clk);
      if o < 9 then read(ln, c, ok); end if;
    end loop;
    b3_we <= '0';

    readline(fh, ln);   -- comentario imagenes

    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length = 0 then next; end if;

      if ln'length >= 10 and ln(ln'low to ln'low+9) = "SIG_LOGITS" then
        loop
          read(ln, c, ok);
          exit when (not ok) or c = ' ';
        end loop;
        read(ln, s8, ok);
        exp_sig_lg := unsigned(hex2slv(s8));
        readline(fh, ln);
        loop
          read(ln, c, ok);
          exit when (not ok) or c = ' ';
        end loop;
        read(ln, s8, ok);
        exp_sig_cl := unsigned(hex2slv(s8));
        exit;
      end if;

      if ln'length >= 3 and ln(ln'low to ln'low+2) = "IMG" then
        if nimg >= G_NIMG then
          exit;
        end if;
        for y in 0 to 15 loop
          readline(fh, ln);
          for x in 0 to 15 loop
            read(ln, s2, ok);
            img_we <= '1'; img_addr <= to_unsigned(y*16 + x, 8);
            img_data <= signed(hex2slv(s2));
            wait until rising_edge(clk);
            if x < 15 then read(ln, c, ok); end if;
          end loop;
        end loop;
        img_we <= '0';

        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until rising_edge(clk);
        while busy = '1' loop
          wait until rising_edge(clk);
        end loop;
        wait until rising_edge(clk);

        -- LOGITS
        readline(fh, ln);
        loop
          read(ln, c, ok);
          exit when (not ok) or c = ' ';
        end loop;
        for o in 0 to 9 loop
          if o > 0 then read(ln, c, ok); end if;
          read(ln, s2, ok);
          expv := signed(hex2slv(s2));
          lg_addr <= to_unsigned(o, 4);
          wait for CP/4;
          if lg_data /= expv then
            e_lg := e_lg + 1;
            if e_lg <= 3 then
              report "tb_npu_top: LOGIT img " & integer'image(nimg)
                   & " o=" & integer'image(o)
                   & " obtenido " & integer'image(to_integer(lg_data))
                   & " esperado " & integer'image(to_integer(expv))
                severity warning;
            end if;
          end if;
          sig_lg := sig_update(sig_lg, lg_data);
          wait for 3*CP/4;
        end loop;

        -- CLASE
        readline(fh, ln);
        -- Lectura robusta: descartar la etiqueta hasta el espacio.
        loop
          read(ln, c, ok);
          exit when (not ok) or c = ' ';
        end loop;
        read(ln, c, ok);
        expcl := character'pos(c) - character'pos('0');
        if to_integer(clase) /= expcl then
          e_cl := e_cl + 1;
          if e_cl <= 3 then
            report "tb_npu_top: CLASE img " & integer'image(nimg)
                 & " obtenida " & integer'image(to_integer(clase))
                 & " esperada " & integer'image(expcl)
              severity warning;
          end if;
        end if;
        sig_cl := sig_update(sig_cl, signed(resize(clase, 8)));

        nimg := nimg + 1;
      end if;
    end loop;

    file_close(fh);

    -- Las firmas globales solo son comparables si se procesaron todas las
    -- imagenes; con un subconjunto se exige unicamente cero discrepancias.
    if e_lg = 0 and e_cl = 0
       and (nimg < 32 or (sig_lg = exp_sig_lg and sig_cl = exp_sig_cl)) then
      report "TB_NPU_TOP PASS imgs=" & integer'image(nimg)
           & " SIG_LOGITS=0x" & to_hstring(sig_lg)
           & " SIG_CLASE=0x" & to_hstring(sig_cl) severity note;
    else
      report "TB_NPU_TOP FAIL imgs=" & integer'image(nimg)
           & " err_lg=" & integer'image(e_lg)
           & " err_cl=" & integer'image(e_cl)
           & " SIG_LOGITS=0x" & to_hstring(sig_lg)
           & " SIG_CLASE=0x" & to_hstring(sig_cl) severity note;
    end if;

    sim_done <= true;
    wait;
  end process;

end architecture sim;
