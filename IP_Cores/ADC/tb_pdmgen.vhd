-- ============================================================================
-- tb_pdmgen.vhd : Capa 1a del ADC delta-sigma soft IP v1
-- Compara bit a bit 65536 bits PDM del RTL contra el modelo Python
-- event-driven independiente (pdm_esperado.txt) y verifica el checksum
-- LFSR-32 (chk_esperado.txt). Criterio de PASS: firma bit-identica.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_pdmgen is
end entity tb_pdmgen;

architecture sim of tb_pdmgen is
  constant C_NBITS : integer := 65536;
  constant C_FINC  : std_logic_vector(31 downto 0) := x"00193000";

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal en      : std_logic := '0';
  signal pdm     : std_logic;
  signal pdm_v   : std_logic;
begin

  dut : entity work.adc_pdmgen
    port map (
      clk         => clk,
      aresetn     => aresetn,
      en_i        => en,
      finc_i      => C_FINC,
      pdm_o       => pdm,
      pdm_valid_o => pdm_v
    );

  proc_clk : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process proc_clk;

  proc_stim : process
    file f_bits      : text;
    file f_chk       : text;
    variable v_line  : line;
    variable v_exp   : integer;
    variable v_n     : integer := 0;
    variable v_chk   : unsigned(31 downto 0) := (others => '1');
    variable v_msb   : std_logic;
    variable v_bit   : unsigned(0 downto 0);
    variable v_chk_e : std_logic_vector(31 downto 0);
  begin
    file_open(f_bits, "pdm_esperado.txt", read_mode);
    file_open(f_chk,  "chk_esperado.txt", read_mode);

    aresetn <= '0';
    en      <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    en <= '1';

    while v_n < C_NBITS loop
      wait until rising_edge(clk);
      if pdm_v = '1' then
        readline(f_bits, v_line);
        read(v_line, v_exp);
        if pdm = '1' then
          v_bit := "1";
        else
          v_bit := "0";
        end if;
        assert to_integer(v_bit) = v_exp
          report "FALLO PDM: bit " & integer'image(v_n) &
                 " esperado " & integer'image(v_exp) &
                 " obtenido " & integer'image(to_integer(v_bit))
          severity failure;
        v_msb := v_chk(31);
        v_chk := v_chk(30 downto 0) & v_bit(0);
        if v_msb = '1' then
          v_chk := v_chk xor x"04C11DB7";
        end if;
        v_n := v_n + 1;
      end if;
    end loop;

    readline(f_chk, v_line);
    hread(v_line, v_chk_e);
    assert std_logic_vector(v_chk) = v_chk_e
      report "FALLO CHECKSUM: esperado 0x" & to_hstring(v_chk_e) &
             " obtenido 0x" & to_hstring(std_logic_vector(v_chk))
      severity failure;

    report "FIN SIMULACION PDMGEN: PASS CHK=0x" &
           to_hstring(std_logic_vector(v_chk)) & " @ " & time'image(now);
    finish;
  end process proc_stim;

end architecture sim;
