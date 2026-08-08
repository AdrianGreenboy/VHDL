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
--      ev_rx_err, ev_prbs_err. Toggle-sync: el pulso conmuta un toggle en el
--      dominio dp; el dominio AXI detecta el cambio de toggle (edge) y regenera
--      el pulso. Garantiza que ningun evento se pierde aunque los pulsos sean
--      mas rapidos que el reloj AXI (se serializan por el toggle).
--
--   3. MULTIBIT (contadores 32b): captura-en-snapshot. El pulso stats_snap
--      (AXI) cruza al dominio dp por toggle-sync; en dp congela un registro
--      shadow de forma atomica; el shadow (estable, no cambia hasta el proximo
--      snapshot) se lee desde AXI sin sincronizador de bus (es estatico entre
--      snapshots). Esto evita el gray-code y es el patron correcto para valores
--      que solo se leen tras un evento de congelacion.
--
-- Riesgo de metaestabilidad: acotado a los dobles-FF. El shadow multibit NO
-- cruza como bus vivo: se lee solo cuando esta estatico, tras confirmar por
-- handshake que el snapshot en dp termino (snap_done cruza de vuelta a AXI).
--
-- MIT License.
-------------------------------------------------------------------------------
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

  -- toggle-sync eventos: toggle en dp, doble FF + edge en axi.
  -- COOLDOWN (critico): dos eventos en ciclos dp consecutivos harian dos
  -- toggles seguidos que el dominio axi (mucho mas lento) NO llega a muestrear
  -- -> el flanco se cancela y el evento se pierde. Cada toggle se gatea con un
  -- contador que garantiza un nivel estable de COOLDOWN_N ciclos dp, superior
  -- a 2 ciclos axi con margen. Como los destinos son stickies, basta con que
  -- llegue el primero de una rafaga.
  constant COOLDOWN_N : natural := 24;   -- 24 x 2.56ns = 61ns > 2 ciclos axi
  signal tg_lg, tg_ll, tg_hb, tg_re, tg_pe : std_logic := '0';  -- dominio dp
  signal cd_lg, cd_ll, cd_hb, cd_re, cd_pe : natural range 0 to COOLDOWN_N := 0;
  signal a1_lg, a2_lg, a3_lg : std_logic := '0';
  signal a1_ll, a2_ll, a3_ll : std_logic := '0';
  signal a1_hb, a2_hb, a3_hb : std_logic := '0';
  signal a1_re, a2_re, a3_re : std_logic := '0';
  signal a1_pe, a2_pe, a3_pe : std_logic := '0';
  attribute ASYNC_REG of a1_lg, a2_lg : signal is "TRUE";
  attribute ASYNC_REG of a1_ll, a2_ll : signal is "TRUE";
  attribute ASYNC_REG of a1_hb, a2_hb : signal is "TRUE";
  attribute ASYNC_REG of a1_re, a2_re : signal is "TRUE";
  attribute ASYNC_REG of a1_pe, a2_pe : signal is "TRUE";

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
  -- 2. EVENTOS: toggle en dp
  ----------------------------------------------------------------------------
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        tg_lg<='0'; tg_ll<='0'; tg_hb<='0'; tg_re<='0'; tg_pe<='0';
        cd_lg<=0; cd_ll<=0; cd_hb<=0; cd_re<=0; cd_pe<=0;
      else
        if cd_lg > 0 then cd_lg <= cd_lg - 1;
        elsif dp_ev_lock_gained='1' then tg_lg <= not tg_lg; cd_lg <= COOLDOWN_N; end if;
        if cd_ll > 0 then cd_ll <= cd_ll - 1;
        elsif dp_ev_lock_lost='1' then tg_ll <= not tg_ll; cd_ll <= COOLDOWN_N; end if;
        if cd_hb > 0 then cd_hb <= cd_hb - 1;
        elsif dp_ev_hi_ber='1' then tg_hb <= not tg_hb; cd_hb <= COOLDOWN_N; end if;
        if cd_re > 0 then cd_re <= cd_re - 1;
        elsif dp_ev_rx_err='1' then tg_re <= not tg_re; cd_re <= COOLDOWN_N; end if;
        if cd_pe > 0 then cd_pe <= cd_pe - 1;
        elsif dp_ev_prbs_err='1' then tg_pe <= not tg_pe; cd_pe <= COOLDOWN_N; end if;
      end if;
    end if;
  end process;

  -- doble FF + tercer FF para detectar edge en axi
  process(clk_axi)
  begin
    if rising_edge(clk_axi) then
      if rst_axi = '1' then
        a1_lg<='0';a2_lg<='0';a3_lg<='0'; a1_ll<='0';a2_ll<='0';a3_ll<='0';
        a1_hb<='0';a2_hb<='0';a3_hb<='0'; a1_re<='0';a2_re<='0';a3_re<='0';
        a1_pe<='0';a2_pe<='0';a3_pe<='0';
      else
        a1_lg<=tg_lg; a2_lg<=a1_lg; a3_lg<=a2_lg;
        a1_ll<=tg_ll; a2_ll<=a1_ll; a3_ll<=a2_ll;
        a1_hb<=tg_hb; a2_hb<=a1_hb; a3_hb<=a2_hb;
        a1_re<=tg_re; a2_re<=a1_re; a3_re<=a2_re;
        a1_pe<=tg_pe; a2_pe<=a1_pe; a3_pe<=a2_pe;
      end if;
    end if;
  end process;

  -- pulso axi = XOR de los dos ultimos FF (edge del toggle)
  axi_ev_lock_gained <= a2_lg xor a3_lg;
  axi_ev_lock_lost   <= a2_ll xor a3_ll;
  axi_ev_hi_ber      <= a2_hb xor a3_hb;
  axi_ev_rx_err      <= a2_re xor a3_re;
  axi_ev_prbs_err    <= a2_pe xor a3_pe;

  ----------------------------------------------------------------------------
  -- 3. SNAPSHOT: axi_snap_req -> toggle axi -> sync dp -> congela shadow ->
  --    toggle done dp -> sync axi -> pulso snap_done
  ----------------------------------------------------------------------------
  -- toggle de request en axi
  process(clk_axi)
  begin
    if rising_edge(clk_axi) then
      if rst_axi = '1' then snap_tg_axi <= '0';
      elsif axi_snap_req = '1' then snap_tg_axi <= not snap_tg_axi;
      end if;
    end if;
  end process;

  -- sync del toggle en dp + deteccion de edge -> congelar shadow
  process(clk_dp)
    variable snap_edge : std_logic;
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        s1_dp<='0'; s2_dp<='0'; s3_dp<='0'; done_tg_dp<='0';
        shadow_tx<=(others=>'0'); shadow_rx<=(others=>'0');
        shadow_re<=(others=>'0'); shadow_be<=(others=>'0');
        shadow_lt<=(others=>'0');
      else
        s1_dp<=snap_tg_axi; s2_dp<=s1_dp; s3_dp<=s2_dp;
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
      if rst_axi = '1' then d1_axi<='0'; d2_axi<='0'; d3_axi<='0';
      else
        d1_axi<=done_tg_dp; d2_axi<=d1_axi; d3_axi<=d2_axi;
      end if;
    end if;
  end process;

  axi_snap_done <= d2_axi xor d3_axi;

end architecture rtl;
