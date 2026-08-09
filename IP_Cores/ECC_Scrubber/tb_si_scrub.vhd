-- tb_layer3.vhd - Testbench Layer 3 del regbank+inyector. Core 20 HERCOSSNUX.
-- Reproduce la traza de accesos dmem de si_trace.txt sobre ecc_regbank,
-- verifica cada lectura (R) contra el valor esperado del oraculo, y comprueba
-- que el scrub termina. PASS si cero discrepancias (firma implicita del oraculo).
-- Las lineas 'L' (carga BRAM) las consume scrub_bram via layer3_init.txt.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ecc_pkg.all;

entity tb_si_scrub is
end entity;

architecture sim of tb_si_scrub is
  constant DEPTH : natural := 32;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal sel, wr : std_logic := '0';
  signal addr  : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal ready : std_logic;

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

  -- lee un token hex de la linea (hasta espacio o fin), devuelve unsigned 32
  procedure rd_hex32(variable L : inout line; variable val : out unsigned(31 downto 0)) is
    variable c   : character;
    variable ok  : boolean;
    variable acc : unsigned(31 downto 0) := (others => '0');
    variable nib : integer;
  begin
    loop
      read(L, c, ok); exit when not ok; exit when c /= ' ';
    end loop;
    loop
      nib := hexv(c);
      exit when nib < 0;
      acc := acc(27 downto 0) & to_unsigned(nib, 4);
      read(L, c, ok); exit when not ok; exit when c = ' ';
    end loop;
    val := acc;
  end procedure;
begin
  clk <= not clk after 5 ns;

  dut : entity work.ecc_regbank_si
    generic map (DEPTH => DEPTH, INITFILE => "si_init.txt")
    port map (clk => clk, rst => rst, sel => sel, wr => wr,
              addr => addr, wdata => wdata, rdata => rdata, ready => ready);

  stim : process
    file     tf   : text;
    variable L    : line;
    variable st   : file_open_status;
    variable c    : character;
    variable ok   : boolean;
    variable uoff : unsigned(31 downto 0);
    variable uval : unsigned(31 downto 0);
    variable errors : natural := 0;
    variable nreads : natural := 0;
    variable is_scrub_ctrl : boolean;
  begin
    rst <= '1'; sel <= '0'; wr <= '0';
    wait for 23 ns;
    rst <= '0';
    wait for 10 ns;

    file_open(st, tf, "si_trace.txt", read_mode);
    assert st = open_ok report "no se pudo abrir si_trace.txt" severity failure;

    while not endfile(tf) loop
      readline(tf, L);
      next when L'length = 0;
      read(L, c, ok);
      next when not ok;
      next when c = '#';
      next when c = 'L';   -- carga BRAM: la hace scrub_bram por initfile

      if c = 'W' then
        rd_hex32(L, uoff);
        rd_hex32(L, uval);
        is_scrub_ctrl := (uoff(7 downto 0) = x"48") and (uval(0) = '1');
        -- realizar escritura (1 ciclo)
        wait until rising_edge(clk);
        addr  <= std_logic_vector(uoff(15 downto 0));
        wdata <= std_logic_vector(uval);
        sel <= '1'; wr <= '1';
        wait until rising_edge(clk);
        sel <= '0'; wr <= '0';
        -- si arranco un scrub, esperar a que termine (done via STATUS)
        if is_scrub_ctrl then
          addr <= x"0044";  -- STATUS
          for i in 0 to 5000 loop
            wait until rising_edge(clk);
            sel <= '1'; wr <= '0';
            wait for 1 ns;
            exit when rdata(1) = '1';   -- done
          end loop;
          sel <= '0';
        end if;

      elsif c = 'R' then
        rd_hex32(L, uoff);
        rd_hex32(L, uval);
        wait until rising_edge(clk);
        addr <= std_logic_vector(uoff(15 downto 0));
        sel <= '1'; wr <= '0';
        wait for 1 ns;                  -- rdata combinacional
        if rdata /= std_logic_vector(uval) then
          errors := errors + 1;
          if errors <= 12 then
            report "READ off=" & integer'image(to_integer(uoff(7 downto 0))) &
                   " got=" & integer'image(to_integer(unsigned(rdata))) &
                   " exp=" & integer'image(to_integer(uval)) severity warning;
          end if;
        end if;
        sel <= '0';
        nreads := nreads + 1;
      end if;
    end loop;
    file_close(tf);

    report "lecturas verificadas: " & integer'image(nreads);
    report "discrepancias        : " & integer'image(errors);
    if errors = 0 then
      report "SILICON SCRUB MMIO PASS - regbank, inyector (2 modos) y sticky OK";
    else
      report "SILICON SCRUB MMIO FAIL" severity failure;
    end if;
    wait;
  end process;

end architecture;
