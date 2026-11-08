-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Cruce de dominios de reloj (Layer 2b): data plane (390.625 MHz) <-> AXI.
--
-- Tres tipos de sincronizador segun la naturaleza de la senal:
--
--   1. ESTADO (1 bit, nivel): block_lock, scr_sync, prbs_lock, hi_ber,
--      tx_active, rx_active. Doble flip-flop en el dominio destino (AXI).
--      Seguro por construccion; puede tener 1-2 ciclos de latencia.
--
--   2. EVENTOS (pulso 1 ciclo dp): ev_lock_gained, ev_lock_lost, ev_hi_ber,
--      ev_rx_err, ev_prbs_err. req/ack handshake (pcs_evsync, the pattern of
--      MAC_25G mac25g_evsync; audit 2026-11 fix M7): the source toggles req
--      only when the previous toggle has been acknowledged back; events
--      arriving meanwhile are COALESCED into one pending event (the AXI side
--      only sets stickies), never dropped. This replaces the old toggle with
--      a hard-coded COOLDOWN_N = 24 dp cycles, which assumed clk_dp/clk_axi
--      > ~12 and silently discarded every event inside the cooldown (an
--      event right after another one was lost, not coalesced).
--
--   3. MULTIBIT (contadores 32b): captura-en-snapshot. El pulso stats_snap
--      (AXI) cruza al dominio dp por toggle-sync; en dp congela un registro
--      shadow de forma atomica; el shadow (estable, no cambia hasta el proximo
--      snapshot) se lee desde AXI sin sincronizador de bus (es estatico entre
--      snapshots). Esto evita el gray-code y es el patron correcto para valores
--      que solo se leen tras un evento de congelacion.
--
-- Power-on (fix M6, ASIC): every toggle flop (event req, snapshot request,
-- snapshot done) has an ASYNCHRONOUS power-on reset of its own domain
-- (por_dp / por_axi, from pcs_porsync); the synchroniser chains are never
-- reset and the edge detectors are gated by the functional reset of the
-- destination domain. The functional domain resets must be released at
-- least 4 destination clock edges after the power-on reset (pcs_porsync
-- does this when its output is OR-ed into the domain reset). A reset of only
-- ONE domain no longer resets a toggle, so it cannot fabricate an edge.
--
-- Riesgo de metaestabilidad: acotado a los dobles-FF. El shadow multibit NO
-- cruza como bus vivo: se lee solo cuando esta estatico, tras confirmar por
-- handshake que el snapshot en dp termino (snap_done cruza de vuelta a AXI).
--
-- MIT License.
-------------------------------------------------------------------------------
-- ==== helper: event synchroniser with req/ack handshake ====
library ieee;
use ieee.std_logic_1164.all;

entity pcs_evsync is
  port (
    clk_src : in std_logic; rst_src : in std_logic; por_src : in std_logic;
    ev_in   : in std_logic;
    clk_dst : in std_logic; rst_dst : in std_logic;
    ev_out  : out std_logic
  );
end entity pcs_evsync;

architecture rtl of pcs_evsync is
  signal pend, busy, req : std_logic := '0';
  signal a1, a2 : std_logic := '0';          -- ack (= req seen in dst) in src
  signal r1, r2, r3 : std_logic := '0';      -- req in dst
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of a1, a2, r1, r2 : signal is "TRUE";
begin
  process(clk_src)
  begin
    if rising_edge(clk_src) then
      a1 <= r2; a2 <= a1;                    -- chain: no reset
    end if;
  end process;

  process(clk_src, por_src)
  begin
    if por_src = '1' then
      req <= '0'; pend <= '0'; busy <= '0';
    elsif rising_edge(clk_src) then
      if rst_src = '1' then
        pend <= '0'; busy <= '0';            -- req is NOT reset (no fake edge)
      elsif busy = '0' and (pend = '1' or ev_in = '1') then
        req <= not req; busy <= '1'; pend <= '0';
      else
        if ev_in = '1' then pend <= '1'; end if;
        if busy = '1' and a2 = req then busy <= '0'; end if;
      end if;
    end if;
  end process;

  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      r1 <= req; r2 <= r1; r3 <= r2;          -- chain: no reset
    end if;
  end process;
  ev_out <= (r2 xor r3) and not rst_dst;
end architecture rtl;


-- ==== helper: power-on reset synchroniser (async assert, sync release) ====
library ieee;
use ieee.std_logic_1164.all;

entity pcs_porsync is
  generic (STAGES : positive := 4);
  port (clk : in std_logic; por_n : in std_logic; por : out std_logic);
end entity pcs_porsync;

architecture rtl of pcs_porsync is
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_cdc is
  port (
    -- dominio data plane
    clk_dp  : in std_logic;
    rst_dp  : in std_logic;
    -- dominio AXI
    clk_axi : in std_logic;
    rst_axi : in std_logic;
    -- asynchronous power-on resets of each domain (pcs_porsync); '0' = FPGA
    por_dp  : in std_logic := '0';
    por_axi : in std_logic := '0';

    -- ==== ESTADO: dp -> axi (nivel, doble FF) ====
    dp_block_lock : in  std_logic;
    dp_scr_sync   : in  std_logic;
    dp_prbs_lock  : in  std_logic;
    dp_hi_ber     : in  std_logic;
    dp_tx_active  : in  std_logic;
    dp_rx_active  : in  std_logic;
    axi_block_lock: out std_logic;
    axi_scr_sync  : out std_logic;
    axi_prbs_lock : out std_logic;
    axi_hi_ber    : out std_logic;
    axi_tx_active : out std_logic;
    axi_rx_active : out std_logic;

    -- ==== EVENTOS: dp -> axi (pulso, toggle-sync) ====
    dp_ev_lock_gained : in  std_logic;
    dp_ev_lock_lost   : in  std_logic;
    dp_ev_hi_ber      : in  std_logic;
    dp_ev_rx_err      : in  std_logic;
    dp_ev_prbs_err    : in  std_logic;
    axi_ev_lock_gained: out std_logic;  -- pulso 1 ciclo axi
    axi_ev_lock_lost  : out std_logic;
    axi_ev_hi_ber     : out std_logic;
    axi_ev_rx_err     : out std_logic;
    axi_ev_prbs_err   : out std_logic;

    -- ==== SNAPSHOT: axi -> dp (pulso) + shadow dp -> axi (estatico) ====
    axi_snap_req  : in  std_logic;  -- pulso 1 ciclo axi (STATS_SNAP)
    -- contadores live desde dp
    dp_cnt_tx : in std_logic_vector(31 downto 0);
    dp_cnt_rx : in std_logic_vector(31 downto 0);
    dp_cnt_re : in std_logic_vector(31 downto 0);
    dp_cnt_be : in std_logic_vector(31 downto 0);
    dp_lock_t : in std_logic_vector(31 downto 0);
    -- shadow estable hacia axi
    axi_sh_tx : out std_logic_vector(31 downto 0);
    axi_sh_rx : out std_logic_vector(31 downto 0);
    axi_sh_re : out std_logic_vector(31 downto 0);
    axi_sh_be : out std_logic_vector(31 downto 0);
    axi_sh_lt : out std_logic_vector(31 downto 0);
    axi_snap_done : out std_logic   -- pulso 1 ciclo axi al completar snapshot
  );
end entity pcs_cdc;

architecture rtl of pcs_cdc is

  -- doble FF generico para nivel
  signal m_block_lock, s_block_lock : std_logic := '0';
  signal m_scr_sync,   s_scr_sync   : std_logic := '0';
  signal m_prbs_lock,  s_prbs_lock  : std_logic := '0';
  signal m_hi_ber,     s_hi_ber     : std_logic := '0';
  signal m_tx_active,  s_tx_active  : std_logic := '0';
  signal m_rx_active,  s_rx_active  : std_logic := '0';

  -- ASYNC_REG: marca los FFs de sincronizacion para Vivado (empaquetado
  -- adyacente + exclusion de optimizaciones). Sim-neutral en GHDL.
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of m_block_lock, s_block_lock : signal is "TRUE";
  attribute ASYNC_REG of m_scr_sync,   s_scr_sync   : signal is "TRUE";
  attribute ASYNC_REG of m_prbs_lock,  s_prbs_lock  : signal is "TRUE";
  attribute ASYNC_REG of m_hi_ber,     s_hi_ber     : signal is "TRUE";
  attribute ASYNC_REG of m_tx_active,  s_tx_active  : signal is "TRUE";
  attribute ASYNC_REG of m_rx_active,  s_rx_active  : signal is "TRUE";

  -- snapshot handshake
  signal snap_tg_axi : std_logic := '0';        -- toggle en axi
  signal s1_dp, s2_dp, s3_dp : std_logic := '0'; -- sync en dp
  attribute ASYNC_REG of s1_dp, s2_dp : signal is "TRUE";
  signal shadow_tx, shadow_rx, shadow_re, shadow_be, shadow_lt
         : std_logic_vector(31 downto 0) := (others => '0');
  signal done_tg_dp : std_logic := '0';          -- toggle done en dp
  signal d1_axi, d2_axi, d3_axi : std_logic := '0';
  attribute ASYNC_REG of d1_axi, d2_axi : signal is "TRUE";

begin

  ----------------------------------------------------------------------------
  -- 1. ESTADO: doble FF en el dominio AXI
  ----------------------------------------------------------------------------
  process(clk_axi)
  begin
    if rising_edge(clk_axi) then
      if rst_axi = '1' then
        m_block_lock<='0'; s_block_lock<='0';
        m_scr_sync<='0';   s_scr_sync<='0';
        m_prbs_lock<='0';  s_prbs_lock<='0';
        m_hi_ber<='0';     s_hi_ber<='0';
        m_tx_active<='0';  s_tx_active<='0';
        m_rx_active<='0';  s_rx_active<='0';
      else
        m_block_lock<=dp_block_lock; s_block_lock<=m_block_lock;
        m_scr_sync  <=dp_scr_sync;   s_scr_sync  <=m_scr_sync;
        m_prbs_lock <=dp_prbs_lock;  s_prbs_lock <=m_prbs_lock;
        m_hi_ber    <=dp_hi_ber;     s_hi_ber    <=m_hi_ber;
        m_tx_active <=dp_tx_active;  s_tx_active <=m_tx_active;
        m_rx_active <=dp_rx_active;  s_rx_active <=m_rx_active;
      end if;
    end if;
  end process;

  axi_block_lock<=s_block_lock; axi_scr_sync<=s_scr_sync;
  axi_prbs_lock <=s_prbs_lock;  axi_hi_ber  <=s_hi_ber;
  axi_tx_active <=s_tx_active;  axi_rx_active<=s_rx_active;

  ----------------------------------------------------------------------------
  -- 2. EVENTOS: req/ack handshake per event (no loss, coalescing)
  ----------------------------------------------------------------------------
  u_ev_lg: entity work.pcs_evsync port map (clk_src=>clk_dp, rst_src=>rst_dp, por_src=>por_dp,
    ev_in=>dp_ev_lock_gained, clk_dst=>clk_axi, rst_dst=>rst_axi, ev_out=>axi_ev_lock_gained);
  u_ev_ll: entity work.pcs_evsync port map (clk_src=>clk_dp, rst_src=>rst_dp, por_src=>por_dp,
    ev_in=>dp_ev_lock_lost, clk_dst=>clk_axi, rst_dst=>rst_axi, ev_out=>axi_ev_lock_lost);
  u_ev_hb: entity work.pcs_evsync port map (clk_src=>clk_dp, rst_src=>rst_dp, por_src=>por_dp,
    ev_in=>dp_ev_hi_ber, clk_dst=>clk_axi, rst_dst=>rst_axi, ev_out=>axi_ev_hi_ber);
  u_ev_re: entity work.pcs_evsync port map (clk_src=>clk_dp, rst_src=>rst_dp, por_src=>por_dp,
    ev_in=>dp_ev_rx_err, clk_dst=>clk_axi, rst_dst=>rst_axi, ev_out=>axi_ev_rx_err);
  u_ev_pe: entity work.pcs_evsync port map (clk_src=>clk_dp, rst_src=>rst_dp, por_src=>por_dp,
    ev_in=>dp_ev_prbs_err, clk_dst=>clk_axi, rst_dst=>rst_axi, ev_out=>axi_ev_prbs_err);

  ----------------------------------------------------------------------------
  -- 3. SNAPSHOT: axi_snap_req -> toggle axi -> sync dp -> congela shadow ->
  --    toggle done dp -> sync axi -> pulso snap_done
  ----------------------------------------------------------------------------
  -- toggle de request en axi
  process(clk_axi, por_axi)
  begin
    if por_axi = '1' then
      snap_tg_axi <= '0';
    elsif rising_edge(clk_axi) then
      if rst_axi = '0' and axi_snap_req = '1' then snap_tg_axi <= not snap_tg_axi;
      end if;
    end if;
  end process;

  -- sync del toggle en dp + deteccion de edge -> congelar shadow
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      s1_dp<=snap_tg_axi; s2_dp<=s1_dp; s3_dp<=s2_dp;   -- chain: no reset
    end if;
  end process;

  process(clk_dp, por_dp)
    variable snap_edge : std_logic;
  begin
    if por_dp = '1' then
      done_tg_dp <= '0';
    elsif rising_edge(clk_dp) then
      if rst_dp = '1' then
        shadow_tx<=(others=>'0'); shadow_rx<=(others=>'0');
        shadow_re<=(others=>'0'); shadow_be<=(others=>'0');
        shadow_lt<=(others=>'0');
      else
        snap_edge := s2_dp xor s3_dp;
        if snap_edge = '1' then
          -- captura atomica de los 5 contadores en el mismo ciclo dp
          shadow_tx<=dp_cnt_tx; shadow_rx<=dp_cnt_rx;
          shadow_re<=dp_cnt_re; shadow_be<=dp_cnt_be;
          shadow_lt<=dp_lock_t;
          done_tg_dp <= not done_tg_dp;  -- avisar que termino
        end if;
      end if;
    end if;
  end process;

  -- el shadow es estatico entre snapshots -> se lee directo en axi sin sync
  axi_sh_tx<=shadow_tx; axi_sh_rx<=shadow_rx; axi_sh_re<=shadow_re;
  axi_sh_be<=shadow_be; axi_sh_lt<=shadow_lt;

  -- sync del done en axi -> pulso snap_done
  process(clk_axi)
  begin
    if rising_edge(clk_axi) then
      d1_axi<=done_tg_dp; d2_axi<=d1_axi; d3_axi<=d2_axi;  -- chain: no reset
    end if;
  end process;

  axi_snap_done <= (d2_axi xor d3_axi) and not rst_axi;

end architecture rtl;
