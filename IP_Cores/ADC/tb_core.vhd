-- ============================================================================
-- tb_core.vhd : Capa 1c del ADC delta-sigma soft IP v1
-- Reproduce el plan T1..T5 del modelo compuesto (estimulo_core.txt:
-- "en src osr extbit fbexp toexp" por ciclo). Verifica:
--   * cada muestra decimada contra muestras_core.txt (orden estricto)
--   * pdm_fb_o y ext_timeout_o ciclo a ciclo (contrato del hook B y
--     prueba Phase-0 anti-modo-comun)
--   * cuenta total y checksum LFSR-32 (resumen_core.txt)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_core is
end entity tb_core;

architecture sim of tb_core is
  constant C_FINC : std_logic_vector(31 downto 0) := x"00193000";

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal en      : std_logic := '0';
  signal src     : std_logic := '0';
  signal osr     : std_logic_vector(1 downto 0) := "11";
  signal ext     : std_logic := '0';
  signal fb      : std_logic;
  signal tout    : std_logic;
  signal smp     : std_logic_vector(23 downto 0);
  signal smp_v   : std_logic;

  signal n_smp   : integer := 0;
  signal chk     : unsigned(31 downto 0) := (others => '1');
begin

  dut : entity work.adc_core
    port map (
      clk            => clk,
      aresetn        => aresetn,
      en_i           => en,
      src_sel_i      => src,
      finc_i         => C_FINC,
      osr_sel_i      => osr,
      pdm_ext_i      => ext,
      pdm_fb_o       => fb,
      ext_timeout_o  => tout,
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

  proc_mon : process
    file f_smp     : text;
    variable v_l   : line;
    variable v_exp : integer;
    variable v_got : integer;
    variable v_c   : unsigned(31 downto 0) := (others => '1');
    variable v_msb : std_logic;
    variable v_w   : std_logic_vector(23 downto 0);
  begin
    file_open(f_smp, "muestras_core.txt", read_mode);
    loop
      wait until rising_edge(clk);
      if smp_v = '1' then
        readline(f_smp, v_l);
        read(v_l, v_exp);
        v_got := to_integer(signed(smp));
        assert v_got = v_exp
          report "FALLO CORE: muestra " & integer'image(n_smp) &
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
    file f_stim     : text;
    file f_res      : text;
    variable v_l    : line;
    variable v_en   : integer;
    variable v_src  : integer;
    variable v_osr  : integer;
    variable v_eb   : integer;
    variable v_fbe  : integer;
    variable v_toe  : integer;
    variable v_fbp  : integer := 0;
    variable v_top  : integer := 0;
    variable v_i    : integer := 0;
    variable v_fbg  : integer;
    variable v_tog  : integer;
    variable v_cnt  : integer;
    variable v_chk  : std_logic_vector(31 downto 0);
  begin
    file_open(f_stim, "estimulo_core.txt", read_mode);
    file_open(f_res,  "resumen_core.txt",  read_mode);

    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);

    while not endfile(f_stim) loop
      readline(f_stim, v_l);
      read(v_l, v_en);
      read(v_l, v_src);
      read(v_l, v_osr);
      read(v_l, v_eb);
      read(v_l, v_fbe);
      read(v_l, v_toe);
      if v_en = 1 then
        en <= '1';
      else
        en <= '0';
      end if;
      if v_src = 1 then
        src <= '1';
      else
        src <= '0';
      end if;
      osr <= std_logic_vector(to_unsigned(v_osr, 2));
      if v_eb = 1 then
        ext <= '1';
      else
        ext <= '0';
      end if;
      wait until rising_edge(clk);
      -- visible en este instante: estado tras el flanco anterior
      if fb = '1' then
        v_fbg := 1;
      else
        v_fbg := 0;
      end if;
      if tout = '1' then
        v_tog := 1;
      else
        v_tog := 0;
      end if;
      if v_i > 0 then
        assert v_fbg = v_fbp
          report "FALLO CORE FB: ciclo " & integer'image(v_i) &
                 " esperado " & integer'image(v_fbp) &
                 " obtenido " & integer'image(v_fbg)
          severity failure;
        assert v_tog = v_top
          report "FALLO CORE TIMEOUT: ciclo " & integer'image(v_i) &
                 " esperado " & integer'image(v_top) &
                 " obtenido " & integer'image(v_tog)
          severity failure;
      end if;
      v_fbp := v_fbe;
      v_top := v_toe;
      v_i   := v_i + 1;
    end loop;

    en <= '0';
    for k in 0 to 7 loop
      wait until rising_edge(clk);
    end loop;

    readline(f_res, v_l);
    read(v_l, v_cnt);
    readline(f_res, v_l);
    hread(v_l, v_chk);

    assert n_smp = v_cnt
      report "FALLO CORE: cuenta de muestras esperada " & integer'image(v_cnt) &
             " obtenida " & integer'image(n_smp)
      severity failure;
    assert std_logic_vector(chk) = v_chk
      report "FALLO CORE CHECKSUM: esperado 0x" & to_hstring(v_chk) &
             " obtenido 0x" & to_hstring(std_logic_vector(chk))
      severity failure;

    report "FIN SIMULACION CORE: PASS N=" & integer'image(n_smp) &
           " CHK=0x" & to_hstring(std_logic_vector(chk)) &
           " @ " & time'image(now);
    finish;
  end process proc_stim;

end architecture sim;
