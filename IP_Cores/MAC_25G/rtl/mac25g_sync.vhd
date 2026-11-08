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
-- NO se resetean con los resets FUNCIONALES de dominio: siguen siempre a su
-- origen y solo importan los CAMBIOS. Un reset de UN solo dominio (p. ej.
-- rst_dp al caer 'locked' del clocking wizard) no puede asi fabricar un
-- flanco falso: con reset en tg/s* el lado reseteado ve un toggle
-- inexistente y re-ejecuta el ultimo comando o crea un evento IRQ falso.
-- Mientras el destino esta en reset la salida se anula.
--
-- Power-on (audit 2026-11, fix M6, ASIC): the toggle / handshake state
-- flops (tg, req, busy, pend) get an ASYNCHRONOUS power-on reset 'por_src'
-- of the SOURCE domain; initial values (':= ...') do not exist in silicon.
-- The synchroniser chains (s*, r*, a*) stay without reset by design.
-- Required release order (provided by mac25g_porsync in the tops):
--   1. por_src asserts asynchronously at power-up -> tg/req defined at once
--   2. the destination domain stays in reset (rst_dst = 1) for >= 4
--      clk_dst edges after por_src is released AND clk_dst runs, which
--      flushes the 3-flop chain to the defined toggle value
--   3. only then rst_dst is released: no spurious pulse can be seen.
-- por_src = '0' (default) keeps the FPGA behaviour (init values).
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
    clk_dst : in std_logic; rst_dst : in std_logic; pulse_out : out std_logic;
    por_src : in std_logic := '0'      -- async power-on reset, source domain
  );
end entity mac25g_psync;

architecture rtl of mac25g_psync is
  signal tg : std_logic := '0';
  signal s1, s2, s3 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1, s2 : signal is "TRUE";
begin
  process(clk_src, por_src)
  begin
    if por_src = '1' then
      tg <= '0';
    elsif rising_edge(clk_src) then
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
    clk_dst : in std_logic; rst_dst : in std_logic; ev_out : out std_logic;
    por_src : in std_logic := '0'      -- async power-on reset, source domain
  );
end entity mac25g_evsync;

architecture rtl of mac25g_evsync is
  signal pend, busy, req : std_logic := '0';
  signal a1, a2 : std_logic := '0';          -- ack sincronizado en origen
  signal r1, r2, r3 : std_logic := '0';      -- req sincronizado en destino
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of a1, a2, r1, r2 : signal is "TRUE";
begin
  -- ack chain: plain synchroniser, no reset
  process(clk_src)
  begin
    if rising_edge(clk_src) then
      a1 <= r2; a2 <= a1;
    end if;
  end process;

  process(clk_src, por_src)
  begin
    if por_src = '1' then
      req <= '0'; pend <= '0'; busy <= '0';
    elsif rising_edge(clk_src) then
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


-------------------------------------------------------------------------------
-- mac25g_porsync: power-on reset synchroniser for one clock domain
-- (audit 2026-11, fix M6). Asynchronous assertion, synchronous release
-- after STAGES clk edges. Feed por_n from the chip power-on-reset cell; use
-- 'por' as the async reset of the CDC toggle flops of this domain and OR it
-- into the functional reset of this domain, which guarantees the release
-- order documented above (the chains flush during the STAGES edges).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity mac25g_porsync is
  generic (STAGES : positive := 4);
  port (clk : in std_logic; por_n : in std_logic; por : out std_logic);
end entity mac25g_porsync;

architecture rtl of mac25g_porsync is
  signal sr : std_logic_vector(STAGES-1 downto 0) := (others => '0');
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of sr : signal is "TRUE";
begin
  process(clk, por_n)
  begin
    if por_n = '0' then
      sr <= (others => '1');
    elsif rising_edge(clk) then
      sr <= sr(STAGES-2 downto 0) & '0';
    end if;
  end process;
  por <= sr(STAGES-1);
end architecture rtl;
