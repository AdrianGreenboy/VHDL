-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 1B: mac25g_pcs_tx frente a pcs_tx_datapath (Core 19).
--
-- Ambos reciben la MISMA secuencia de bloques (cada uno a su ritmo, avanzando
-- su indice al aceptar). Propiedades:
--   1. el flujo de palabras de salida es bit a bit identico (equivalencia de
--      contenido: mismo scrambler, mismo gearbox, mismo orden)
--   2. mac25g_pcs_tx acepta 32 bloques cada 33 ciclos y emite 1 palabra por
--      ciclo en regimen (lo que exige un PMA serie real)
--   3. se informa la tasa del Core 19 para documentar el hallazgo
-- Tambien con in_valid intermitente (huecos aleatorios de la fuente).
--
-- Criterio: LAYER1B_PASS.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity tb_mac_pcs_tx is
end entity;

architecture sim of tb_mac_pcs_tx is
  constant T : time := 2.56 ns;
  constant NW : natural := 4000;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done_sim : boolean := false;
  signal gaps : boolean := false;
  signal lfsr : std_logic_vector(15 downto 0) := x"1D0F";

  signal ia, ib : natural := 0;            -- indice de bloque de cada DUT
  signal va, vb, ra, rb, oa, ob : std_logic;
  signal pa, pb, wa, wb : std_logic_vector(63 downto 0);
  signal da, db : std_logic;

  function blk(i : natural) return std_logic_vector is
    variable x : std_logic_vector(63 downto 0) :=
      std_logic_vector(to_unsigned(i, 32)) & std_logic_vector(to_unsigned(i * 7 + 3, 32));
  begin
    return xorshift64(xorshift64(x xor x"5A5A5A5A5A5A5A5A"));
  end function;
  function isd(i : natural) return std_logic is
  begin
    if i mod 7 = 0 then return '0'; else return '1'; end if;
  end function;

  type warr is array (0 to NW-1) of std_logic_vector(63 downto 0);
begin
  clk <= not clk after T/2 when not done_sim;

  -- fuente: con 'gaps' la entrada valida cae ~1/4 de los ciclos (igual para ambos)
  process(clk)
  begin
    if rising_edge(clk) then
      lfsr <= lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
    end if;
  end process;
  va <= '0' when rst = '1' or (gaps and lfsr(1 downto 0) = "00") else '1';
  vb <= va;
  pa <= blk(ia); da <= isd(ia);
  pb <= blk(ib); db <= isd(ib);

  u_a: entity work.pcs_tx_datapath
    port map (clk=>clk, rst=>rst, in_valid=>va, in_payload=>pa, in_is_data=>da,
              in_ready=>ra, out_valid=>oa, out_word=>wa);
  u_b: entity work.mac25g_pcs_tx
    port map (clk=>clk, rst=>rst, in_valid=>vb, in_payload=>pb, in_is_data=>db,
              in_ready=>rb, out_valid=>ob, out_word=>wb);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ia <= 0; ib <= 0;
      else
        if va = '1' and ra = '1' then ia <= ia + 1; end if;
        if vb = '1' and rb = '1' then ib <= ib + 1; end if;
      end if;
    end if;
  end process;

  process
    variable a, b : warr;
    variable na, nb, errs, cyc, acc_b, out_b, acc_a, out_a : natural := 0;
    variable run : natural;
  begin
    for pass in 0 to 1 loop
      gaps <= (pass = 1);
      rst <= '1'; na := 0; nb := 0; cyc := 0;
      wait for 10*T; wait until rising_edge(clk); rst <= '0';
      acc_a := 0; acc_b := 0; out_a := 0; out_b := 0;
      while na < NW or nb < NW loop
        wait until rising_edge(clk);
        cyc := cyc + 1;
        assert cyc < 20*NW report "TIMEOUT" severity failure;
        if oa = '1' and na < NW then a(na) := wa; na := na + 1; end if;
        if ob = '1' and nb < NW then b(nb) := wb; nb := nb + 1; end if;
        -- tasa en regimen (ventana de 3300 ciclos tras el arranque)
        if cyc > 100 and cyc <= 3400 then
          if va = '1' and ra = '1' then acc_a := acc_a + 1; end if;
          if vb = '1' and rb = '1' then acc_b := acc_b + 1; end if;
          if oa = '1' then out_a := out_a + 1; end if;
          if ob = '1' then out_b := out_b + 1; end if;
        end if;
      end loop;
      for i in 0 to NW - 1 loop
        if a(i) /= b(i) then
          errs := errs + 1;
          if errs < 5 then
            report "MISMATCH palabra " & integer'image(i) & " core19=" & to_hstring(a(i)) &
              " core20=" & to_hstring(b(i)) severity error;
          end if;
        end if;
      end loop;
      report "pasada " & integer'image(pass) & " (huecos=" & boolean'image(pass = 1) &
        ") en 3300 ciclos: Core19 bloques=" & integer'image(acc_a) & " palabras=" &
        integer'image(out_a) & " | Core20 bloques=" & integer'image(acc_b) &
        " palabras=" & integer'image(out_b);
      if pass = 0 and (acc_b /= 3200 or out_b /= 3300) then
        report "FAIL: Core20 no sostiene tasa de linea (esperado 3200 bloques / 3300 palabras)"
          severity error;
        errs := errs + 1;
      end if;
    end loop;
    if errs = 0 then
      report "LAYER1B_PASS flujo identico al Core 19 (" & integer'image(NW) &
        " palabras x2 pasadas), tasa de linea 32/33 con 1 palabra/ciclo";
    else
      report "LAYER1B_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
