-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Sincronizadores de cruce de reloj.
--
--   mac25g_lsync : nivel, doble FF con ASYNC_REG
--   mac25g_psync : pulso por toggle (origen lento -> destino rapido, o
--                  pulsos separados > 3 ciclos de destino)
--   mac25g_evsync: evento con handshake req/ack. Eventos que llegan mientras
--                  hay uno en vuelo se COALESCEN en uno solo, pero nunca se
--                  pierden todos (con un toggle simple, dos pulsos seguidos
--                  se anulan y el destino no ve nada).
--
-- Resets: los biestables de toggle (tg, req) y las cadenas de sincronizacion
-- NO se resetean: siguen siempre a su origen y solo importan los CAMBIOS. Un
-- reset de UN solo dominio (p. ej. rst_dp al caer 'locked' del clocking
-- wizard) no puede asi fabricar un flanco falso: con reset en tg/s* el lado
-- reseteado ve un toggle inexistente y re-ejecuta el ultimo comando o crea
-- un evento IRQ falso. Mientras el destino esta en reset la salida se anula.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity mac25g_lsync is
  port (clk_dst : in std_logic; d : in std_logic; q : out std_logic);
end entity mac25g_lsync;

architecture rtl of mac25g_lsync is
  signal f1, f2 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of f1, f2 : signal is "TRUE";
begin
  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      f1 <= d; f2 <= f1;
    end if;
  end process;
  q <= f2;
end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;

entity mac25g_psync is
  port (
    clk_src : in std_logic; rst_src : in std_logic; pulse_in : in std_logic;
    clk_dst : in std_logic; rst_dst : in std_logic; pulse_out : out std_logic
  );
end entity mac25g_psync;

architecture rtl of mac25g_psync is
  signal tg : std_logic := '0';
  signal s1, s2, s3 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1, s2 : signal is "TRUE";
begin
  process(clk_src)
  begin
    if rising_edge(clk_src) then
      if rst_src = '0' and pulse_in = '1' then tg <= not tg; end if;
    end if;
  end process;
  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      s1 <= tg; s2 <= s1; s3 <= s2;
    end if;
  end process;
  pulse_out <= (s2 xor s3) and not rst_dst;
end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;

entity mac25g_evsync is
  port (
    clk_src : in std_logic; rst_src : in std_logic; ev_in : in std_logic;
    clk_dst : in std_logic; rst_dst : in std_logic; ev_out : out std_logic
  );
end entity mac25g_evsync;

architecture rtl of mac25g_evsync is
  signal pend, busy, req : std_logic := '0';
  signal a1, a2 : std_logic := '0';          -- ack sincronizado en origen
  signal r1, r2, r3 : std_logic := '0';      -- req sincronizado en destino
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of a1, a2, r1, r2 : signal is "TRUE";
begin
  process(clk_src)
  begin
    if rising_edge(clk_src) then
      a1 <= r2; a2 <= a1;
      if rst_src = '1' then
        pend <= '0'; busy <= '0';            -- req NO: ver cabecera
      else
        if busy = '0' and (pend = '1' or ev_in = '1') then
          req <= not req; busy <= '1'; pend <= '0';
        else
          if ev_in = '1' then pend <= '1'; end if;
          if busy = '1' and a2 = req then busy <= '0'; end if;
        end if;
      end if;
    end if;
  end process;

  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      r1 <= req; r2 <= r1; r3 <= r2;
    end if;
  end process;
  ev_out <= (r2 xor r3) and not rst_dst;
end architecture rtl;
