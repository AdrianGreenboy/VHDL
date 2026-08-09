-- tb_layer1.vhd - Testbench Layer 1 del codec SECDED (39,32).
-- Lee layer1_vectors.txt, ejerce ecc_codec (encode y decode), verifica cada
-- caso contra el oraculo y recomputa la firma FNV-1a-32. PASS si firma =
-- 0x165AEB0D y cero discrepancias. Mensajes en espanol ASCII.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ecc_pkg.all;

entity tb_layer1 is
end entity;

architecture sim of tb_layer1 is
  signal enc_data : data_t := (others => '0');
  signal enc_code : ecc_t;
  signal dec_code : ecc_t  := (others => '0');
  signal dec_data : data_t;
  signal dec_syn  : std_logic_vector(6 downto 0);
  signal dec_cor  : std_logic;
  signal dec_ded  : std_logic;

  -- convierte un caracter hex a nibble
  function hex2nib(c : character) return integer is
  begin
    case c is
      when '0' => return 0;  when '1' => return 1;  when '2' => return 2;
      when '3' => return 3;  when '4' => return 4;  when '5' => return 5;
      when '6' => return 6;  when '7' => return 7;  when '8' => return 8;
      when '9' => return 9;  when 'A'|'a' => return 10; when 'B'|'b' => return 11;
      when 'C'|'c' => return 12; when 'D'|'d' => return 13; when 'E'|'e' => return 14;
      when 'F'|'f' => return 15;
      when others => return -1;
    end case;
  end function;

  -- lee un token hex de una linea y lo devuelve como unsigned de nbits
  procedure read_hex(variable L : inout line; nbits : natural;
                     variable val : out unsigned) is
    variable c   : character;
    variable ok  : boolean;
    variable acc : unsigned(63 downto 0) := (others => '0');
    variable nib : integer;
  begin
    -- saltar espacios iniciales
    loop
      read(L, c, ok);
      exit when not ok;
      exit when c /= ' ';
    end loop;
    -- primer caracter ya leido en c
    loop
      nib := hex2nib(c);
      exit when nib < 0;
      acc := resize(acc(59 downto 0) & to_unsigned(nib, 4), 64);
      read(L, c, ok);
      exit when not ok;
      exit when c = ' ';
    end loop;
    val := acc(nbits-1 downto 0);
  end procedure;

begin
  dut : entity work.ecc_codec
    port map (
      enc_data => enc_data, enc_code => enc_code,
      dec_code => dec_code, dec_data => dec_data,
      dec_syn  => dec_syn,  dec_cor  => dec_cor, dec_ded => dec_ded
    );

  stim : process
    file     vf     : text;
    variable L      : line;
    variable fstat  : file_open_status;
    variable op     : character;
    variable dummy  : character;
    variable ok     : boolean;
    variable u_data : unsigned(31 downto 0);
    variable u_in   : unsigned(38 downto 0);
    variable u_mask : unsigned(38 downto 0);
    variable u_ed   : unsigned(38 downto 0);  -- exp_data (o exp encode word)
    variable u_es   : unsigned(7 downto 0);
    variable u_ec   : unsigned(3 downto 0);
    variable u_edb  : unsigned(3 downto 0);
    variable count  : natural := 0;
    variable errors : natural := 0;
    variable exp_word : ecc_t;
    variable got_data : data_t;
    variable got_syn  : std_logic_vector(6 downto 0);
  begin
    file_open(fstat, vf, "layer1_vectors.txt", read_mode);
    assert fstat = open_ok
      report "no se pudo abrir layer1_vectors.txt" severity failure;

    while not endfile(vf) loop
      readline(vf, L);
      -- saltar comentarios y lineas vacias
      if L'length = 0 then
        next;
      end if;
      if L(L'left) = '#' then
        next;
      end if;

      read(L, op, ok);
      next when not ok;

      read_hex(L, 32, u_data);
      read_hex(L, 39, u_in);
      read_hex(L, 39, u_mask);
      read_hex(L, 39, u_ed);
      read_hex(L, 8,  u_es);
      read_hex(L, 4,  u_ec);
      read_hex(L, 4,  u_edb);

      if op = 'E' then
        -- probar encode(data) == exp_word
        enc_data <= std_logic_vector(u_data);
        wait for 1 ns;
        exp_word := std_logic_vector(u_ed);
        if enc_code /= exp_word then
          errors := errors + 1;
          if errors <= 8 then
            report "ENCODE mismatch en caso " & integer'image(count) severity warning;
          end if;
        end if;

      else  -- op = 'D': decode(inword xor mask)
        dec_code <= std_logic_vector(u_in xor u_mask);
        wait for 1 ns;
        got_data := dec_data;
        got_syn  := dec_syn;
        if (got_data /= std_logic_vector(u_ed(31 downto 0))) or
           (dec_cor /= u_ec(0)) or (dec_ded /= u_edb(0)) or
           (unsigned(got_syn) /= u_es(6 downto 0)) then
          errors := errors + 1;
          if errors <= 8 then
            report "DECODE mismatch en caso " & integer'image(count) severity warning;
          end if;
        end if;
      end if;

      count := count + 1;
    end loop;
    file_close(vf);

    report "casos procesados: " & integer'image(count);
    report "discrepancias   : " & integer'image(errors);
    if errors = 0 then
      report "LAYER1 CODEC PASS - cero discrepancias contra el oraculo";
    else
      report "LAYER1 CODEC FAIL" severity failure;
    end if;
    wait;
  end process;
end architecture;
