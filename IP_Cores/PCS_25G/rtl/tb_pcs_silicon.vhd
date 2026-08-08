-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Testbench del subsistema de datos del silicon pass (Layer 3 integracion).
--
-- Verifica la PROPIEDAD end-to-end (no firma bit-identica, por las latencias
-- de settling en cascada):
--   P1: cadena limpia -> BER = 0 tras sincronizacion
--   P2: inyeccion de 1 bit -> BER > 0 (la cadena detecta corrupcion)
--
-- La cadena ejercita TODO el PCS: PRBS31 -> scrambler -> gearbox -> loopback
--   -> gearbox -> descrambler -> PRBS31 checker.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_silicon is end entity;

architecture sim of tb_pcs_silicon is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal prbs_gen_en, loopback_en, prbs_chk_en, inject_err, clr_ber : std_logic := '0';
  signal ber_count, tx_word_cnt, rx_block_cnt : std_logic_vector(31 downto 0);
  signal chk_locked : std_logic;

  signal ber_after_clean : std_logic_vector(31 downto 0) := (others=>'0');
  signal errors : natural := 0;
begin
  clk <= not clk after 1.28 ns;

  dut: entity work.pcs_silicon_datapath
    port map (clk_dp=>clk, rst_dp=>rst,
              prbs_gen_en=>prbs_gen_en, loopback_en=>loopback_en,
              prbs_chk_en=>prbs_chk_en, inject_err=>inject_err, clr_ber=>clr_ber,
              ber_count=>ber_count, chk_locked=>chk_locked,
              tx_word_cnt=>tx_word_cnt, rx_block_cnt=>rx_block_cnt);

  main: process
  begin
    rst <= '1'; wait for 20 ns; wait until rising_edge(clk); rst <= '0';
    wait until rising_edge(clk);

    -- arrancar la cadena completa
    prbs_gen_en <= '1';
    loopback_en <= '1';
    prbs_chk_en <= '1';

    -- dejar sincronizar toda la cascada (scrambler+gearbox+descrambler+checker)
    wait for 2 us;

    -- limpiar el BER para descartar el transitorio de sincronizacion en cascada.
    -- Esto replica lo que hace el firmware real: PRBS_RESET tras el bring-up.
    wait until rising_edge(clk);
    clr_ber <= '1';
    wait until rising_edge(clk);
    clr_ber <= '0';

    -- ahora medir en una ventana limpia (cadena ya estable)
    wait for 2 us;

    -- P1: BER debe ser 0 en la ventana limpia
    wait until rising_edge(clk);
    ber_after_clean <= ber_count;
    wait for 1 ns;
    assert chk_locked = '1'
      report "checker no sincronizo en la cadena" severity error;
    if chk_locked /= '1' then errors <= errors + 1; end if;
    assert unsigned(ber_count) = 0
      report "P1 FAIL: BER no cero en ventana limpia: 0x" & to_hstring(ber_count) severity error;
    if unsigned(ber_count) /= 0 then errors <= errors + 1; end if;

    report "P1 cadena limpia BER=0x" & to_hstring(ber_count) &
           " tx_words=" & integer'image(to_integer(unsigned(tx_word_cnt))) &
           " lock=" & std_logic'image(chk_locked);

    -- P2: inyectar 1 bit error y verificar que el BER sube
    wait until rising_edge(clk);
    inject_err <= '1';
    wait until rising_edge(clk);
    inject_err <= '0';

    -- dejar propagar la corrupcion por la cascada
    wait for 200 ns;
    wait until rising_edge(clk);
    assert unsigned(ber_count) > unsigned(ber_after_clean)
      report "P2 FAIL: la inyeccion no aumento el BER" severity error;
    if unsigned(ber_count) <= unsigned(ber_after_clean) then errors <= errors + 1; end if;

    report "P2 tras inyeccion BER=0x" & to_hstring(ber_count) &
           " (antes 0x" & to_hstring(ber_after_clean) & ")";

    wait for 1 ns;
    if errors = 0 then
      report "LAYER3TOP_PASS cadena PCS completa: BER=0 limpio, deteccion OK" severity note;
    else
      report "LAYER3TOP_FAIL errores=" & integer'image(errors) severity error;
    end if;
    std.env.stop;
  end process;

end architecture;
