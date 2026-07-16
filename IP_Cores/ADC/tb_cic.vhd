-- ============================================================================
-- tb_cic.vhd : Capa 1b del ADC delta-sigma soft IP v1
-- Reproduce el estimulo con corrupciones del modelo bit-bang
-- (estimulo_cic.txt: "bit valid osr" por ciclo) y compara cada muestra
-- decimada contra muestras_esperadas.txt. Verifica cuenta total y
-- checksum LFSR-32 (resumen_cic.txt).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_cic is
end entity tb_cic;

architecture sim of tb_cic is
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal pdm     : std_logic := '0';
  signal pdm_v   : std_logic := '0';
  signal osr     : std_logic_vector(1 downto 0) := "11";
  signal smp     : std_logic_vector(23 downto 0);
  signal smp_v   : std_logic;

  signal n_smp   : integer := 0;
  signal chk     : unsigned(31 downto 0) := (others => '1');
begin

  dut : entity work.adc_cic
    port map (
      clk            => clk,
      aresetn        => aresetn,
      pdm_i          => pdm,
      pdm_valid_i    => pdm_v,
      osr_sel_i      => osr,
      sample_o       => smp,
      sample_valid_o => smp_v
    );

  proc_clk : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process proc_clk;

  -- monitor de muestras: compara cada strobe contra el archivo esperado
  proc_mon : process
    file f_smp     : text;
    variable v_l   : line;
    variable v_exp : integer;
    variable v_got : integer;
    variable v_c   : unsigned(31 downto 0) := (others => '1');
    variable v_msb : std_logic;
    variable v_w   : std_logic_vector(23 downto 0);
  begin
    file_open(f_smp, "muestras_esperadas.txt", read_mode);
    loop
      wait until rising_edge(clk);
      if smp_v = '1' then
        readline(f_smp, v_l);
        read(v_l, v_exp);
        v_got := to_integer(signed(smp));
        assert v_got = v_exp
          report "FALLO CIC: muestra " & integer'image(n_smp) &
                 " esperada " & integer'image(v_exp) &
                 " obtenida " & integer'image(v_got)
          severity failure;
        v_w := smp;
        for k in 23 downto 0 loop
          v_msb := v_c(31);
          v_c   := v_c(30 downto 0) & v_w(k);
          if v_msb = '1' then
            v_c := v_c xor x"04C11DB7";
          end if;
        end loop;
        chk   <= v_c;
        n_smp <= n_smp + 1;
      end if;
    end loop;
  end process proc_mon;

  proc_stim : process
    file f_stim    : text;
    file f_res     : text;
    variable v_l   : line;
    variable v_b   : integer;
    variable v_v   : integer;
    variable v_o   : integer;
    variable v_cnt : integer;
    variable v_chk : std_logic_vector(31 downto 0);
  begin
    file_open(f_stim, "estimulo_cic.txt", read_mode);
    file_open(f_res,  "resumen_cic.txt",  read_mode);

    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);

    while not endfile(f_stim) loop
      readline(f_stim, v_l);
      read(v_l, v_b);
      read(v_l, v_v);
      read(v_l, v_o);
      if v_b = 1 then
        pdm <= '1';
      else
        pdm <= '0';
      end if;
      if v_v = 1 then
        pdm_v <= '1';
      else
        pdm_v <= '0';
      end if;
      osr <= std_logic_vector(to_unsigned(v_o, 2));
      wait until rising_edge(clk);
    end loop;

    pdm_v <= '0';
    for k in 0 to 7 loop
      wait until rising_edge(clk);
    end loop;

    readline(f_res, v_l);
    read(v_l, v_cnt);
    readline(f_res, v_l);
    hread(v_l, v_chk);

    assert n_smp = v_cnt
      report "FALLO CIC: cuenta de muestras esperada " & integer'image(v_cnt) &
             " obtenida " & integer'image(n_smp)
      severity failure;
    assert std_logic_vector(chk) = v_chk
      report "FALLO CIC CHECKSUM: esperado 0x" & to_hstring(v_chk) &
             " obtenido 0x" & to_hstring(std_logic_vector(chk))
      severity failure;

    report "FIN SIMULACION CIC: PASS N=" & integer'image(n_smp) &
           " CHK=0x" & to_hstring(std_logic_vector(chk)) &
           " @ " & time'image(now);
    finish;
  end process proc_stim;

end architecture sim;
