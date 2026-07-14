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
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_phy_pkg.all;
use work.pcie_8b10b_pkg.all;

entity pcie_framer is
  generic (
    SKP_INTERVAL : integer := 1180   -- simbolos entre SKP OS (spec: <=1538)
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
  type st_t is (S_IDLE, S_STP, S_PAY, S_END, S_SKP0, S_SKP1, S_SKP2, S_SKP3);
  signal state   : st_t := S_IDLE;
  signal skp_cnt : integer range 0 to 65535 := 0;
  signal end_edb : std_logic := '0';
  signal pend    : std_logic := '0';   -- paquete pendiente latcheado
  signal pend_dllp : std_logic := '0';
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= S_IDLE;
        skp_cnt   <= 0;
        end_edb   <= '0';
        pend      <= '0';
        pend_dllp <= '0';
        sym       <= (others => '0');
        sym_k     <= '0';
        sym_com   <= '0';
        sym_skp   <= '0';
        sym_bypass<= '0';
        pay_ready <= '0';
        busy      <= '0';
      else
        -- latch de peticion aun estando ocupado (se sirve al terminar)
        if pkt_start = '1' then
          pend      <= '1';
          pend_dllp <= pkt_is_dllp;
        end if;

        if en = '1' then
          -- defaults por ciclo
          sym       <= x"00";
          sym_k     <= '0';
          sym_com   <= '0';
          sym_skp   <= '0';
          sym_bypass<= tx_bypass;
          pay_ready <= '0';

          -- contador de SKP (avanza siempre que se emite un simbolo)
          if skp_cnt = SKP_INTERVAL - 1 then
            skp_cnt <= 0;
          else
            skp_cnt <= skp_cnt + 1;
          end if;

          case state is
            when S_IDLE =>
              busy <= '0';
              if skp_cnt = SKP_INTERVAL - 1 then
                -- prioriza SKP OS en la frontera
                sym <= K_COM; sym_k <= '1'; sym_com <= '1';
                state <= S_SKP1;
                busy  <= '1';
              elsif pend = '1' then
                pend <= '0';
                busy <= '1';
                if pend_dllp = '1' then
                  sym <= K_SDP;
                else
                  sym <= K_STP;
                end if;
                sym_k <= '1';
                state <= S_PAY;
              else
                -- logical idle: D00.0 (se scramblea a algo no nulo)
                sym <= x"00"; sym_k <= '0';
              end if;

            when S_PAY =>
              busy <= '1';
              if pay_valid = '1' then
                sym       <= pay_data;
                sym_k     <= '0';
                pay_ready <= '1';
                if pay_last = '1' then
                  end_edb <= pay_abort;
                  state   <= S_END;
                end if;
              else
                -- underrun: mantener idle-data sin cerrar (store&forward evita
                -- esto en el uso normal; se deja robusto)
                sym <= x"00"; sym_k <= '0';
              end if;

            when S_END =>
              busy <= '1';
              if end_edb = '1' then
                sym <= K_EDB;
              else
                sym <= K_END;
              end if;
              sym_k <= '1';
              state <= S_IDLE;

            -- SKP OS: COM ya emitido en la transicion; faltan 3 SKP
            when S_SKP1 =>
              sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; state <= S_SKP2;
            when S_SKP2 =>
              sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; state <= S_SKP3;
            when S_SKP3 =>
              sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; state <= S_IDLE;

            when others =>
              state <= S_IDLE;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;
