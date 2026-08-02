library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_ecc is
end entity;

architecture sim of tb_ecc is
  signal data_in  : std_logic_vector(23 downto 0);
  signal ecc_in   : std_logic_vector(5 downto 0);
  signal data_out : std_logic_vector(23 downto 0);
  signal err_1bit : std_logic;
  signal err_2bit : std_logic;
begin
  dut : entity work.csi2_ecc
    port map (data_in=>data_in, ecc_in=>ecc_in,
              data_out=>data_out, err_1bit=>err_1bit, err_2bit=>err_2bit);

  process
    file fh : text;
    variable ln : line;
    variable in_d, exp_d : std_logic_vector(23 downto 0);
    variable in_e : std_logic_vector(7 downto 0);
    variable exp2 : integer;
    variable fails : integer := 0;
    variable total : integer := 0;
    variable ok : file_open_status;
  begin
    file_open(ok, fh, "ecc_vec.txt", read_mode);
    assert ok = open_ok report "no ecc_vec.txt" severity failure;
    while not endfile(fh) loop
      readline(fh, ln);
      hread(ln, in_d);
      hread(ln, in_e);
      hread(ln, exp_d);
      read(ln, exp2);
      data_in <= in_d;
      ecc_in  <= in_e(5 downto 0);
      wait for 1 ns;
      total := total + 1;
      if exp2 = 1 then
        if err_2bit /= '1' then
          report "FAIL 2bit not flagged, in=0x"&to_hstring(in_d) severity warning;
          fails := fails + 1;
        end if;
      else
        if data_out /= exp_d then
          report "FAIL correct: in=0x"&to_hstring(in_d)&
                 " got=0x"&to_hstring(data_out)&" exp=0x"&to_hstring(exp_d)
                 severity warning;
          fails := fails + 1;
        end if;
        if err_2bit = '1' then
          report "FAIL false 2bit on in=0x"&to_hstring(in_d) severity warning;
          fails := fails + 1;
        end if;
      end if;
    end loop;
    file_close(fh);
    report "ECC vectors: "&integer'image(total)&" fails: "&integer'image(fails);
    if fails = 0 then
      report "ECC ALL PASS" severity note;
    else
      report "ECC FAIL" severity failure;
    end if;
    wait;
  end process;
end architecture;
