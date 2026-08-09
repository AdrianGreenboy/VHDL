-- tb_layer2.vhd - Testbench Layer 2 del scrubber. Core 20 HERCOSSNUX.
-- Preinicializa la BRAM desde layer2_init.txt, corre un barrido completo,
-- y verifica contadores + sticky + memoria final contra layer2_exp.txt.
-- PASS si todo coincide (equivalente a firma bit-identica del oraculo).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ecc_pkg.all;

entity tb_layer2 is
end entity;

architecture sim of tb_layer2 is
  constant DEPTH : natural := 64;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start : std_logic := '0';

  signal we    : std_logic;
  signal waddr : std_logic_vector(15 downto 0);
  signal wdata : ecc_t;
  signal raddr : std_logic_vector(15 downto 0);
  signal rdata : ecc_t;

  signal busy, done : std_logic;
  signal ce_count, ded_count : std_logic_vector(31 downto 0);
  signal first_addr, last_addr : std_logic_vector(31 downto 0);
  signal first_syn, last_syn   : std_logic_vector(9 downto 0);

  -- override de lectura para el barrido de verificacion final
  signal vaddr : std_logic_vector(15 downto 0) := (others => '0');
  signal use_vaddr : std_logic := '0';
  signal raddr_mux : std_logic_vector(15 downto 0);

  function hexv(ch : character) return integer is
  begin
    case ch is
      when '0' => return 0;  when '1' => return 1;  when '2' => return 2;
      when '3' => return 3;  when '4' => return 4;  when '5' => return 5;
      when '6' => return 6;  when '7' => return 7;  when '8' => return 8;
      when '9' => return 9;  when 'A'|'a' => return 10; when 'B'|'b' => return 11;
      when 'C'|'c' => return 12; when 'D'|'d' => return 13; when 'E'|'e' => return 14;
      when 'F'|'f' => return 15; when others => return -1;
    end case;
  end function;

  function is_digit(c : character) return boolean is
  begin
    return c >= '0' and c <= '9';
  end function;

  -- flags: bit9=was_ce, bit8=was_ded  ->  entero ce | (ded<<1)  (formato oraculo)
  function flags_of(syn10 : std_logic_vector(9 downto 0)) return integer is
    variable v : integer := 0;
  begin
    if syn10(9) = '1' then v := v + 1; end if;
    if syn10(8) = '1' then v := v + 2; end if;
    return v;
  end function;

  -- parse_key: busca la subcadena key en s y devuelve el entero decimal que le sigue
  function parse_key(s : string; key : string) return integer is
    variable i, j : integer;
    variable val  : integer := 0;
    variable found : boolean := false;
  begin
    for i in s'low to s'high - key'length + 1 loop
      if s(i to i+key'length-1) = key then
        j := i + key'length;
        while j <= s'high and is_digit(s(j)) loop
          val := val*10 + (character'pos(s(j)) - character'pos('0'));
          j := j + 1;
          found := true;
        end loop;
        exit;
      end if;
    end loop;
    if not found then return -1; end if;
    return val;
  end function;

  -- parse_nth: devuelve el n-esimo entero decimal en la cadena (1-indexado),
  -- ignorando cualquier caracter no-digito como separador
  function parse_nth(s : string; n : integer) return integer is
    variable count : integer := 0;
    variable i     : integer := s'low;
    variable val   : integer;
    variable innum : boolean;
  begin
    while i <= s'high loop
      if is_digit(s(i)) then
        count := count + 1;
        val := 0;
        while i <= s'high and is_digit(s(i)) loop
          val := val*10 + (character'pos(s(i)) - character'pos('0'));
          i := i + 1;
        end loop;
        if count = n then
          return val;
        end if;
      else
        i := i + 1;
      end if;
    end loop;
    return -1;
  end function;
begin
  clk <= not clk after 5 ns;
  raddr_mux <= vaddr when use_vaddr = '1' else raddr;

  bram : entity work.scrub_bram
    generic map (DEPTH => DEPTH, INITFILE => "layer2_init.txt")
    port map (clk => clk, we => we, waddr => waddr, wdata => wdata,
              raddr => raddr_mux, rdata => rdata);

  fsm : entity work.scrub_fsm
    generic map (DEPTH => DEPTH)
    port map (clk => clk, rst => rst, start => start,
              we => we, waddr => waddr, wdata => wdata,
              raddr => raddr, rdata => rdata,
              busy => busy, done => done,
              ce_count => ce_count, ded_count => ded_count,
              first_addr => first_addr, first_syn => first_syn,
              last_addr => last_addr, last_syn => last_syn);

  stim : process
    file     ef    : text;
    variable L     : line;
    variable st    : file_open_status;
    variable c     : character;
    variable ok    : boolean;
    -- valores esperados del header
    variable exp_ce, exp_ded : natural := 0;
    variable exp_fa, exp_fs, exp_ff : natural := 0;
    variable exp_la, exp_ls, exp_lf : natural := 0;
    variable errors : natural := 0;
    variable acc    : unsigned(38 downto 0);
    variable nib    : integer;
    variable exp_word : ecc_t;
    variable widx   : natural := 0;
  begin
    -- reset
    rst <= '1'; start <= '0'; use_vaddr <= '0';
    wait for 23 ns;
    rst <= '0';
    wait for 10 ns;

    -- arrancar barrido
    start <= '1';
    wait for 10 ns;
    start <= '0';

    -- esperar done
    for i in 0 to 10000 loop
      wait until rising_edge(clk);
      exit when done = '1';
    end loop;
    assert done = '1' report "el barrido no termino a tiempo" severity failure;

    -- leer expectativas del header de layer2_exp.txt
    file_open(st, ef, "layer2_exp.txt", read_mode);
    assert st = open_ok report "no se pudo abrir layer2_exp.txt" severity failure;

    -- linea 1: # N=.. CE=.. DED=.. SIG=..
    readline(ef, L);
    exp_ce  := parse_key(L.all, "CE=");
    exp_ded := parse_key(L.all, "DED=");
    -- linea 2: # FIRST addr syn flags
    readline(ef, L);
    exp_fa := parse_nth(L.all, 1);
    exp_fs := parse_nth(L.all, 2);
    exp_ff := parse_nth(L.all, 3);
    -- linea 3: # LAST addr syn flags
    readline(ef, L);
    exp_la := parse_nth(L.all, 1);
    exp_ls := parse_nth(L.all, 2);
    exp_lf := parse_nth(L.all, 3);

    -- comparar contadores
    if to_integer(unsigned(ce_count)) /= exp_ce then
      errors := errors + 1;
      report "CE_COUNT " & integer'image(to_integer(unsigned(ce_count))) &
             " != esperado " & integer'image(exp_ce) severity warning;
    end if;
    if to_integer(unsigned(ded_count)) /= exp_ded then
      errors := errors + 1;
      report "DED_COUNT " & integer'image(to_integer(unsigned(ded_count))) &
             " != esperado " & integer'image(exp_ded) severity warning;
    end if;
    -- sticky first
    if to_integer(unsigned(first_addr)) /= exp_fa or
       to_integer(unsigned(first_syn(6 downto 0))) /= exp_fs or
       flags_of(first_syn) /= exp_ff then
      errors := errors + 1;
      report "FIRST no coincide" severity warning;
    end if;
    -- sticky last
    if to_integer(unsigned(last_addr)) /= exp_la or
       to_integer(unsigned(last_syn(6 downto 0))) /= exp_ls or
       flags_of(last_syn) /= exp_lf then
      errors := errors + 1;
      report "LAST no coincide" severity warning;
    end if;

    -- verificar memoria final: leer cada palabra por el puerto de lectura
    use_vaddr <= '1';
    widx := 0;
    while not endfile(ef) loop
      readline(ef, L);
      next when L'length = 0;
      next when L(L'left) = '#';
      -- parsear palabra esperada
      acc := (others => '0');
      for k in L'range loop
        nib := hexv(L(k));
        exit when nib < 0;
        acc := acc(34 downto 0) & to_unsigned(nib, 4);
      end loop;
      exp_word := std_logic_vector(acc);
      -- leer BRAM en widx (latencia 1 ciclo)
      vaddr <= std_logic_vector(to_unsigned(widx, 16));
      wait until rising_edge(clk);
      wait until rising_edge(clk);  -- dwell por latencia
      if rdata /= exp_word then
        errors := errors + 1;
        if errors <= 8 then
          report "MEM[" & integer'image(widx) & "] no coincide" severity warning;
        end if;
      end if;
      widx := widx + 1;
    end loop;
    file_close(ef);

    report "palabras verificadas: " & integer'image(widx);
    report "discrepancias        : " & integer'image(errors);
    if errors = 0 then
      report "LAYER2 SCRUB PASS - memoria, contadores y sticky OK";
    else
      report "LAYER2 SCRUB FAIL" severity failure;
    end if;
    wait;
  end process;

end architecture;
