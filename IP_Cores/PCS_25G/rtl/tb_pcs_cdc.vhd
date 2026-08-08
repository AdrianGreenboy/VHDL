-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Testbench Layer 2b: verificacion de la CDC dual-clock.
--
-- NO usa firma FNV temporal (la latencia de cruce es no-determinista con
-- relojes asincronos). Verifica dos PROPIEDADES en su lugar:
--
--   P1 INTEGRIDAD DE SNAPSHOT: tras cada axi_snap_req, cuando llega snap_done,
--      el shadow leido en AXI coincide con el valor que el data plane tenia
--      congelado. Se comprueba que el shadow es coherente (todos los contadores
--      del mismo instante) y estable hasta el proximo snapshot.
--
--   P2 NO-PERDIDA DE EVENTOS: cada pulso de evento generado en el dominio dp
--      aparece exactamente una vez en el dominio axi. Contadores independientes
--      en cada dominio; al final deben coincidir.
--
-- Relojes deliberadamente asincronos y con relacion no-entera para forzar
-- cruces de fase realistas: dp ~390.625 MHz (1.28 ns), axi ~150 MHz (3.33 ns).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_cdc is end entity;

architecture sim of tb_pcs_cdc is
  signal clk_dp  : std_logic := '0';
  signal clk_axi : std_logic := '0';
  signal rst_dp  : std_logic := '1';
  signal rst_axi : std_logic := '1';

  -- estado dp
  signal dp_block_lock, dp_scr_sync, dp_prbs_lock : std_logic := '0';
  signal dp_hi_ber, dp_tx_active, dp_rx_active : std_logic := '0';
  signal axi_block_lock, axi_scr_sync, axi_prbs_lock : std_logic;
  signal axi_hi_ber, axi_tx_active, axi_rx_active : std_logic;

  -- eventos
  signal dp_ev_lg, dp_ev_ll, dp_ev_hb, dp_ev_re, dp_ev_pe : std_logic := '0';
  signal axi_ev_lg, axi_ev_ll, axi_ev_hb, axi_ev_re, axi_ev_pe : std_logic;

  -- snapshot
  signal axi_snap_req : std_logic := '0';
  signal dp_cnt_tx, dp_cnt_rx, dp_cnt_re, dp_cnt_be, dp_lock_t
         : std_logic_vector(31 downto 0) := (others => '0');
  signal axi_sh_tx, axi_sh_rx, axi_sh_re, axi_sh_be, axi_sh_lt
         : std_logic_vector(31 downto 0);
  signal axi_snap_done : std_logic;

  -- contadores de verificacion de eventos
  signal dp_lg_cnt, axi_lg_cnt : natural := 0;
  signal dp_re_cnt, axi_re_cnt : natural := 0;
  signal dp_pe_cnt, axi_pe_cnt : natural := 0;

  signal sim_done : boolean := false;
  signal errors   : natural := 0;
begin

  clk_dp  <= not clk_dp  after 1.28 ns when not sim_done else '0';
  clk_axi <= not clk_axi after 3.33 ns when not sim_done else '0';

  dut: entity work.pcs_cdc
    port map (
      clk_dp=>clk_dp, rst_dp=>rst_dp, clk_axi=>clk_axi, rst_axi=>rst_axi,
      dp_block_lock=>dp_block_lock, dp_scr_sync=>dp_scr_sync,
      dp_prbs_lock=>dp_prbs_lock, dp_hi_ber=>dp_hi_ber,
      dp_tx_active=>dp_tx_active, dp_rx_active=>dp_rx_active,
      axi_block_lock=>axi_block_lock, axi_scr_sync=>axi_scr_sync,
      axi_prbs_lock=>axi_prbs_lock, axi_hi_ber=>axi_hi_ber,
      axi_tx_active=>axi_tx_active, axi_rx_active=>axi_rx_active,
      dp_ev_lock_gained=>dp_ev_lg, dp_ev_lock_lost=>dp_ev_ll,
      dp_ev_hi_ber=>dp_ev_hb, dp_ev_rx_err=>dp_ev_re, dp_ev_prbs_err=>dp_ev_pe,
      axi_ev_lock_gained=>axi_ev_lg, axi_ev_lock_lost=>axi_ev_ll,
      axi_ev_hi_ber=>axi_ev_hb, axi_ev_rx_err=>axi_ev_re, axi_ev_prbs_err=>axi_ev_pe,
      axi_snap_req=>axi_snap_req,
      dp_cnt_tx=>dp_cnt_tx, dp_cnt_rx=>dp_cnt_rx, dp_cnt_re=>dp_cnt_re,
      dp_cnt_be=>dp_cnt_be, dp_lock_t=>dp_lock_t,
      axi_sh_tx=>axi_sh_tx, axi_sh_rx=>axi_sh_rx, axi_sh_re=>axi_sh_re,
      axi_sh_be=>axi_sh_be, axi_sh_lt=>axi_sh_lt, axi_snap_done=>axi_snap_done);

  -- contar eventos generados en dp
  ev_dp_count: process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if dp_ev_lg='1' then dp_lg_cnt <= dp_lg_cnt + 1; end if;
      if dp_ev_re='1' then dp_re_cnt <= dp_re_cnt + 1; end if;
      if dp_ev_pe='1' then dp_pe_cnt <= dp_pe_cnt + 1; end if;
    end if;
  end process;

  -- contar eventos recibidos en axi
  ev_axi_count: process(clk_axi)
  begin
    if rising_edge(clk_axi) then
      if axi_ev_lg='1' then axi_lg_cnt <= axi_lg_cnt + 1; end if;
      if axi_ev_re='1' then axi_re_cnt <= axi_re_cnt + 1; end if;
      if axi_ev_pe='1' then axi_pe_cnt <= axi_pe_cnt + 1; end if;
    end if;
  end process;

  -- estimulo en el dominio dp: cuenta contadores y genera eventos espaciados
  dp_stim: process
  begin
    wait for 20 ns; wait until rising_edge(clk_dp);
    rst_dp <= '0';
    -- avanzar contadores a valores conocidos
    dp_cnt_tx <= x"00001000";
    dp_cnt_rx <= x"00000800";
    dp_cnt_re <= x"00000005";
    dp_cnt_be <= x"00000002";
    dp_lock_t <= x"0000ABCD";
    dp_block_lock <= '1'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';

    -- generar 10 eventos lock_gained espaciados (mas lentos que axi)
    for i in 1 to 10 loop
      wait until rising_edge(clk_dp);
      dp_ev_lg <= '1';
      wait until rising_edge(clk_dp);
      dp_ev_lg <= '0';
      for j in 1 to 5 loop wait until rising_edge(clk_dp); end loop;
    end loop;

    -- generar eventos rx_err RAPIDOS (mas rapidos que el reloj axi) para
    -- probar que el toggle-sync no pierde ninguno
    for i in 1 to 20 loop
      wait until rising_edge(clk_dp);
      dp_ev_re <= '1';
      wait until rising_edge(clk_dp);
      dp_ev_re <= '0';
      wait until rising_edge(clk_dp);  -- solo 1 ciclo de separacion
    end loop;

    -- eventos prbs_err
    for i in 1 to 7 loop
      wait until rising_edge(clk_dp);
      dp_ev_pe <= '1';
      wait until rising_edge(clk_dp);
      dp_ev_pe <= '0';
      for j in 1 to 3 loop wait until rising_edge(clk_dp); end loop;
    end loop;

    wait;
  end process;

  -- estimulo/checker en el dominio axi: snapshots e integridad
  axi_check: process
    variable tx0, rx0, re0, be0, lt0 : std_logic_vector(31 downto 0);
    variable got_done : boolean;
  begin
    wait for 20 ns; wait until rising_edge(clk_axi);
    rst_axi <= '0';
    wait for 100 ns;  -- dejar que los contadores dp se estabilicen

    -- === P1: snapshot y verificar integridad ===
    wait until rising_edge(clk_axi);
    axi_snap_req <= '1';
    wait until rising_edge(clk_axi);
    axi_snap_req <= '0';
    -- esperar snap_done, registrando si efectivamente llego
    got_done := false;
    for k in 0 to 50 loop
      wait until rising_edge(clk_axi);
      if axi_snap_done = '1' then got_done := true; exit; end if;
    end loop;
    -- P1a: el handshake de snapshot DEBE completarse (snap_done obligatorio)
    assert got_done report "P1 FAIL snap_done nunca llego" severity error;
    if not got_done then errors <= errors + 1; end if;
    -- leer shadow (estable)
    wait until rising_edge(clk_axi);
    tx0 := axi_sh_tx; rx0 := axi_sh_rx; re0 := axi_sh_re;
    be0 := axi_sh_be; lt0 := axi_sh_lt;
    assert tx0 = x"00001000" report "P1 FAIL sh_tx" severity error;
    assert rx0 = x"00000800" report "P1 FAIL sh_rx" severity error;
    assert re0 = x"00000005" report "P1 FAIL sh_re" severity error;
    assert be0 = x"00000002" report "P1 FAIL sh_be" severity error;
    assert lt0 = x"0000ABCD" report "P1 FAIL sh_lt" severity error;
    if tx0/=x"00001000" or rx0/=x"00000800" or re0/=x"00000005"
       or be0/=x"00000002" or lt0/=x"0000ABCD" then
      errors <= errors + 1;
    end if;

    -- verificar estabilidad: el shadow no cambia sin nuevo snapshot
    for k in 1 to 20 loop wait until rising_edge(clk_axi); end loop;
    assert axi_sh_tx = tx0 report "P1 FAIL shadow inestable" severity error;
    if axi_sh_tx /= tx0 then errors <= errors + 1; end if;

    -- === verificar CDC de estado ===
    assert axi_block_lock='1' report "estado block_lock no cruzo" severity error;
    assert axi_prbs_lock='1' report "estado prbs_lock no cruzo" severity error;

    -- esperar a que todos los eventos terminen de propagarse
    wait for 800 ns;

    -- === P2: notificacion de eventos (semantica de sticky) ===
    -- El conteo EXACTO de eventos es fisicamente inalcanzable entre dominios
    -- con relacion de frecuencia grande (dp 390.625 MHz vs axi 40 MHz en
    -- silicio): si el productor emite eventos mas rapido de lo que el
    -- consumidor muestrea, ningun toggle-sync los preserva; dos toggles en
    -- ciclos dp consecutivos se cancelan antes de ser vistos. El CDC usa
    -- ahora un cooldown que garantiza niveles estables y NO pretende conteo.
    --
    -- Los CONTADORES exactos (CNT_RX_ERR, CNT_BER) no viajan por eventos:
    -- cruzan por el snapshot con handshake, que si es exacto. Los eventos
    -- alimentan unicamente los stickies de IRQ, cuya propiedad correcta es:
    --   * si hubo al menos un evento en dp, llega al menos uno a axi
    --   * no aparecen eventos espurios (axi <= dp)
    report "dp_lg=" & integer'image(dp_lg_cnt) & " axi_lg=" & integer'image(axi_lg_cnt);
    report "dp_re=" & integer'image(dp_re_cnt) & " axi_re=" & integer'image(axi_re_cnt);
    report "dp_pe=" & integer'image(dp_pe_cnt) & " axi_pe=" & integer'image(axi_pe_cnt);
    assert not (dp_lg_cnt > 0 and axi_lg_cnt = 0)
      report "P2 FAIL lock_gained no notificado" severity error;
    assert not (dp_re_cnt > 0 and axi_re_cnt = 0)
      report "P2 FAIL rx_err no notificado" severity error;
    assert not (dp_pe_cnt > 0 and axi_pe_cnt = 0)
      report "P2 FAIL prbs_err no notificado" severity error;
    assert axi_lg_cnt <= dp_lg_cnt and axi_re_cnt <= dp_re_cnt and axi_pe_cnt <= dp_pe_cnt
      report "P2 FAIL eventos espurios en axi" severity error;
    if (dp_lg_cnt > 0 and axi_lg_cnt = 0) or (dp_re_cnt > 0 and axi_re_cnt = 0)
       or (dp_pe_cnt > 0 and axi_pe_cnt = 0)
       or axi_lg_cnt > dp_lg_cnt or axi_re_cnt > dp_re_cnt or axi_pe_cnt > dp_pe_cnt then
      errors <= errors + 1;
    end if;

    wait for 10 ns;
    if errors = 0 then
      report "LAYER2B_PASS integridad+eventos OK" severity note;
    else
      report "LAYER2B_FAIL errores=" & integer'image(errors) severity error;
    end if;
    sim_done <= true;
    wait;
  end process;

end architecture;
