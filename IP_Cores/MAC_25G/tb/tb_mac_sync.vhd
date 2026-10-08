-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 1C: mac25g_evsync (dp 390.625 MHz -> aclk 40 MHz).
-- Pares de eventos separados d = 1..24 ciclos de clk_dp (lo que pasa con dos
-- tramas minimas erroneas seguidas). Por cada par, el dominio AXI debe ver al
-- menos un evento (coalescido) y el mecanismo debe quedar libre para el
-- siguiente par. Un toggle simple pierde los pares con d pequeno (dos toggles
-- se anulan antes de que aclk los muestree).
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

  process
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
