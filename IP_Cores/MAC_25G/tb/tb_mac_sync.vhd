-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 1C: mac25g_evsync (dp 390.625 MHz -> aclk 40 MHz).
-- Pares de eventos separados d = 1..24 ciclos de clk_dp (lo que pasa con dos
-- tramas minimas erroneas seguidas). Por cada par, el dominio AXI debe ver al
-- menos un evento (coalescido) y el mecanismo debe quedar libre para el
-- siguiente par. Un toggle simple pierde los pares con d pequeno (dos toggles
-- se anulan antes de que aclk los muestree).
-- Fase 2: reset de UN solo dominio (rst_dp al caer 'locked') tras un numero
-- impar de comandos/eventos: ni mac25g_psync ni mac25g_evsync deben generar
-- un pulso falso al salir del reset (re-ejecucion del ultimo CMD / IRQ falsa).
-- Criterio: LAYER1C_PASS.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity tb_mac_sync is
end entity;

architecture sim of tb_mac_sync is
  signal clk_dp, aclk : std_logic := '0';
  signal rst_dp, rst_a : std_logic := '1';
  signal ev_in, ev_out : std_logic := '0';
  signal done_sim : boolean := false;
  signal seen : natural := 0;
  -- fase 2: psync aclk -> dp (camino de CMD) y evsync dp -> aclk
  signal p_in, p_out : std_logic := '0';
  signal p_seen : natural := 0;
  signal rst_dp_only : std_logic := '0';
  signal rst_dp2 : std_logic;
begin
  clk_dp <= not clk_dp after 1.28 ns when not done_sim;
  aclk   <= not aclk after 12.5 ns when not done_sim;

  dut: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>ev_in,
              clk_dst=>aclk, rst_dst=>rst_a, ev_out=>ev_out);

  process(aclk)
  begin
    if rising_edge(aclk) then
      if ev_out = '1' then seen <= seen + 1; end if;
    end if;
  end process;

  rst_dp2 <= rst_dp or rst_dp_only;
  u_ps: entity work.mac25g_psync
    port map (clk_src=>aclk, rst_src=>rst_a, pulse_in=>p_in,
              clk_dst=>clk_dp, rst_dst=>rst_dp2, pulse_out=>p_out);
  u_ev2: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp2, ev_in=>ev_in,
              clk_dst=>aclk, rst_dst=>rst_a, ev_out=>open);
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if p_out = '1' then p_seen <= p_seen + 1; end if;
    end if;
  end process;

  process
    alias req_mon is << signal .tb_mac_sync.dut.req : std_logic >>;
    variable before, errs : natural := 0;
  begin
    wait for 100 ns;
    wait until rising_edge(clk_dp); rst_dp <= '0';
    wait until rising_edge(aclk); rst_a <= '0';
    wait for 100 ns;
    for d in 1 to 24 loop
      before := seen;
      wait until rising_edge(clk_dp);
      ev_in <= '1'; wait until rising_edge(clk_dp); ev_in <= '0';
      for k in 2 to d loop wait until rising_edge(clk_dp); end loop;
      ev_in <= '1'; wait until rising_edge(clk_dp); ev_in <= '0';
      wait for 600 ns;                     -- ida y vuelta completa del handshake
      if seen = before then
        errs := errs + 1;
        report "FAIL: par de eventos separado " & integer'image(d) &
          " ciclos dp no llego al dominio AXI" severity error;
      end if;
    end loop;
    -- fase 2a: un CMD (toggle a 1), luego reset solo del dominio dp
    wait until rising_edge(aclk); p_in <= '1'; wait until rising_edge(aclk); p_in <= '0';
    wait for 200 ns;
    if p_seen /= 1 then
      errs := errs + 1; report "FAIL: el CMD no cruzo" severity error;
    end if;
    wait until rising_edge(clk_dp); rst_dp_only <= '1';
    wait for 100 ns;
    wait until rising_edge(clk_dp); rst_dp_only <= '0';
    wait for 300 ns;
    if p_seen /= 1 then
      errs := errs + 1;
      report "FAIL: reset solo de dp re-ejecuto el ultimo CMD (pulsos=" &
        integer'image(p_seen) & ")" severity error;
    end if;
    -- fase 2b: llevar 'req' del evsync a '1' (estado en el que un reset de req
    -- a '0' fabricaria un flanco) y resetear SOLO el dominio origen
    while req_mon /= '1' loop
      wait until rising_edge(clk_dp); ev_in <= '1'; wait until rising_edge(clk_dp); ev_in <= '0';
      wait for 600 ns;
    end loop;
    before := seen;
    wait until rising_edge(clk_dp); rst_dp <= '1';
    wait for 100 ns;
    wait until rising_edge(clk_dp); rst_dp <= '0';
    wait for 600 ns;
    if seen /= before then
      errs := errs + 1;
      report "FAIL: reset solo del origen genero un evento falso" severity error;
    end if;

    if errs = 0 then
      report "LAYER1C_PASS 24 pares de eventos, ninguno perdido (" &
        integer'image(seen) & " eventos AXI)";
    else
      report "LAYER1C_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
