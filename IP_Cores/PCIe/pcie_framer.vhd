-- ============================================================================
-- pcie_framer.vhd -- PCIE IP v1
-- Framer TX del PHY logico. Toma peticiones de "enviar payload" (un stream de
-- bytes con longitud) y produce el stream de simbolos (byte + flags) hacia el
-- scrambler:
--   * TLP  : STP , <payload...> , END           (o EDB si abort)
--   * DLLP : SDP , <6 bytes>    , END
--   * Cuando no hay payload: IDLE (D00.0 scrambleado, is_k=0) o SKP OS.
--   * Inserta un SKP Ordered Set (COM + 3x SKP) cada SKP_INTERVAL simbolos.
--   * Emite un COM peridico de sincronizacion al inicio (gestionado por LTSSM
--     en pasos posteriores; aqui exponemos la orden send_com).
--
-- Este bloque NO decide protocolo de enlace; es puramente el "empaquetador de
-- simbolos". El LTSSM (paso 3) lo pilota. La interfaz de payload es un handshake
-- valid/ready por byte con marca de ultimo (last) y de abort.
--
-- Flags de salida (hacia scrambler): is_k, is_com, is_skp, bypass.
-- 'bypass' se usara en pasos posteriores para TS1/TS2; aqui siempre '0' salvo
-- que el pilotante lo pida por tx_bypass.
--
-- Audit 2026-11: STORE-AND-FORWARD. The payload is first written into an
-- internal packet buffer (pay_ready='1' combinationally while filling; a byte
-- transfers on a clock edge with pay_valid='1' and pay_ready='1'). STP/SDP is
-- emitted only when the whole packet is buffered, so a payload underrun can no
-- longer insert logical-idle symbols inside an open TLP. A SKP OS that falls
-- due during a packet is held pending and inserted right after it.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_phy_pkg.all;
use work.pcie_8b10b_pkg.all;

entity pcie_framer is
  generic (
    SKP_INTERVAL : integer := 1180;  -- simbolos entre SKP OS (spec: <=1538)
    MAX_PKT      : integer := 256    -- packet buffer (bytes)
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    en         : in  std_logic;                  -- clock-enable de simbolo

    -- Peticion de paquete (nivel): '1' mientras haya payload que enviar
    pkt_start  : in  std_logic;                  -- pulso: arranca un paquete
    pkt_is_dllp: in  std_logic;                  -- '1' DLLP (SDP), '0' TLP (STP)
    pay_data   : in  work.pcie_phy_pkg.byte_t;                      -- byte de payload actual
    pay_valid  : in  std_logic;                  -- hay byte valido
    pay_last   : in  std_logic;                  -- ultimo byte del payload
    pay_abort  : in  std_logic;                  -- cerrar con EDB en vez de END
    pay_ready  : out std_logic;                  -- el framer consume el byte

    tx_bypass  : in  std_logic;                  -- fuerza bypass de scramble

    -- Salida de simbolos hacia el scrambler
    sym        : out work.pcie_phy_pkg.byte_t;
    sym_k      : out std_logic;
    sym_com    : out std_logic;
    sym_skp    : out std_logic;
    sym_bypass : out std_logic;

    busy       : out std_logic                   -- '1' si esta enmarcando pkt
  );
end entity;

architecture rtl of pcie_framer is
  type st_t is (S_IDLE, S_PAY, S_END, S_SKP1, S_SKP2, S_SKP3);
  signal state   : st_t := S_IDLE;
  signal skp_cnt : integer range 0 to 65535 := 0;
  signal skp_pend: std_logic := '0';

  type buf_t is array (0 to MAX_PKT-1) of work.pcie_phy_pkg.byte_t;
  signal pbuf    : buf_t := (others => (others => '0'));
  signal filling : std_logic := '0';   -- a packet is being written
  signal ready_p : std_logic := '0';   -- a complete packet is buffered
  signal wcnt    : integer range 0 to MAX_PKT := 0;
  signal plen    : integer range 0 to MAX_PKT := 0;
  signal rptr    : integer range 0 to MAX_PKT := 0;
  signal p_dllp  : std_logic := '0';
  signal p_abort : std_logic := '0';
  signal prdy    : std_logic;
begin
  prdy      <= '1' when filling = '1' and wcnt < MAX_PKT else '0';
  pay_ready <= prdy;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE; skp_cnt <= 0; skp_pend <= '0';
        filling <= '0'; ready_p <= '0'; wcnt <= 0; plen <= 0; rptr <= 0;
        p_dllp <= '0'; p_abort <= '0';
        sym <= (others => '0'); sym_k <= '0'; sym_com <= '0'; sym_skp <= '0';
        sym_bypass <= '0'; busy <= '0';
      else
        -- ---------------- store ----------------
        if pkt_start = '1' and filling = '0' and ready_p = '0' and state /= S_PAY
           and state /= S_END then
          filling <= '1'; wcnt <= 0; p_dllp <= pkt_is_dllp;
        end if;
        if pay_valid = '1' and prdy = '1' then
          pbuf(wcnt) <= pay_data; wcnt <= wcnt + 1;
          if pay_last = '1' then
            filling <= '0'; ready_p <= '1'; plen <= wcnt + 1; p_abort <= pay_abort;
          end if;
        end if;

        -- ---------------- forward ----------------
        if en = '1' then
          sym <= x"00"; sym_k <= '0'; sym_com <= '0'; sym_skp <= '0';
          sym_bypass <= tx_bypass;
          if skp_cnt = SKP_INTERVAL - 1 then
            skp_cnt <= 0; skp_pend <= '1';
          else
            skp_cnt <= skp_cnt + 1;
          end if;

          case state is
            when S_IDLE =>
              busy <= '0';
              if skp_pend = '1' or skp_cnt = SKP_INTERVAL - 1 then
                skp_pend <= '0';
                sym <= K_COM; sym_k <= '1'; sym_com <= '1';
                state <= S_SKP1; busy <= '1';
              elsif ready_p = '1' then
                busy <= '1'; rptr <= 0;
                if p_dllp = '1' then sym <= K_SDP; else sym <= K_STP; end if;
                sym_k <= '1';
                state <= S_PAY;
              else
                sym <= x"00"; sym_k <= '0';     -- logical idle (between packets only)
              end if;

            when S_PAY =>
              busy <= '1';
              sym <= pbuf(rptr); sym_k <= '0';
              if rptr = plen - 1 then state <= S_END; else rptr <= rptr + 1; end if;

            when S_END =>
              busy <= '1';
              if p_abort = '1' then sym <= K_EDB; else sym <= K_END; end if;
              sym_k <= '1';
              ready_p <= '0';
              state <= S_IDLE;

            -- SKP OS: COM already emitted; 3 SKP follow
            when S_SKP1 =>
              sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; state <= S_SKP2;
            when S_SKP2 =>
              sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; state <= S_SKP3;
            when S_SKP3 =>
              sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; state <= S_IDLE;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;
