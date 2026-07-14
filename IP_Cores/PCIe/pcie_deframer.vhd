-- ============================================================================
-- pcie_deframer.vhd -- PCIE IP v1
-- Deframer RX del PHY logico. Entrada: stream de simbolos ya descrambleados
-- (byte + is_k) con su clock-enable. Salida: tokens clasificados (rx_kind_t)
-- + byte de payload cuando aplica, y los campos de training extraidos de los
-- ordered sets TS1/TS2 (link, lane, n_fts, rate, train_ctl) con un strobe
-- ts_valid al completar un TS.
--
-- Reconocimiento de Ordered Sets a partir de COM:
--   COM seguido de patron -> se buffean 16 simbolos y se clasifica:
--     * sym6 == 0x4A en todos 6..15 con is_k=0 -> TS1
--     * sym6 == 0x45 -> TS2
--     * COM + IDL(K28.3) x3 -> EIOS (electrical idle)
--     * COM + SKP(K28.0) -> SKP OS (longitud 1..n de SKP; se consume hasta el
--       primer no-SKP)
-- TLP/DLLP:
--   STP(K27.7) -> RK_TLP_START, luego RK_TLP_DATA por byte hasta END/EDB.
--   SDP(K28.2) -> RK_DLLP_START, idem.
--   END(K29.7) -> RK_*_END ; EDB(K30.7) -> RK_TLP_ABORT.
--
-- Nota: el deframer NO descrambla; asume que el scrambler RX ya lo hizo y que
-- ademas le indica cuando el simbolo es COM/SKP para reinit (esos flags se
-- derivan aqui del propio byte+is_k, de modo que el deframer es autonomo).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;
use work.pcie_8b10b_pkg.all;

entity pcie_deframer is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    en        : in  std_logic;                 -- clock-enable de simbolo
    sym       : in  work.pcie_ltssm_pkg.byte_t;                     -- simbolo descrambleado
    sym_k     : in  std_logic;

    tok       : out rx_kind_t;
    tok_data  : out work.pcie_ltssm_pkg.byte_t;                     -- valido con RK_*_DATA
    tok_valid : out std_logic;                  -- pulso de token

    -- Campos de training extraidos (validos con ts_valid)
    ts_valid  : out std_logic;                  -- pulso al completar un TS
    ts_is_ts2 : out std_logic;
    ts_link   : out work.pcie_ltssm_pkg.byte_t;
    ts_lane   : out work.pcie_ltssm_pkg.byte_t;
    ts_nfts   : out work.pcie_ltssm_pkg.byte_t;
    ts_rate   : out work.pcie_ltssm_pkg.byte_t;
    ts_ctl    : out work.pcie_ltssm_pkg.byte_t;

    -- flags derivados para el scrambler RX (reinit en COM, no-avance en SKP)
    is_com_o  : out std_logic;
    is_skp_o  : out std_logic
  );
end entity;

architecture rtl of pcie_deframer is
  type dstate_t is (D_IDLE, D_OS, D_TLP, D_DLLP);
  signal state : dstate_t := D_IDLE;

  -- buffer de ordered set
  type osbuf_t is array (0 to TS_LEN-1) of work.pcie_ltssm_pkg.byte_t;
  signal osb     : osbuf_t := (others => (others => '0'));
  signal oscnt   : integer range 0 to TS_LEN := 0;
begin

  -- flags combinacionales para el scrambler RX
  is_com_o <= '1' when (en = '1' and sym_k = '1' and sym = K_COM) else '0';
  is_skp_o <= '1' when (en = '1' and sym_k = '1' and sym = K_SKP) else '0';

  process(clk)
    variable is_ts1, is_ts2 : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= D_IDLE;
        oscnt     <= 0;
        tok       <= RK_NONE;
        tok_valid <= '0';
        tok_data  <= (others => '0');
        ts_valid  <= '0';
        ts_is_ts2 <= '0';
        ts_link   <= (others => '0');
        ts_lane   <= (others => '0');
        ts_nfts   <= (others => '0');
        ts_rate   <= (others => '0');
        ts_ctl    <= (others => '0');
      else
        -- defaults por ciclo (strobes de un ciclo)
        tok_valid <= '0';
        ts_valid  <= '0';
        tok       <= RK_NONE;

        if en = '1' then
          case state is
            when D_IDLE =>
              if sym_k = '1' then
                if sym = K_COM then
                  -- comienzo de un ordered set: bufferear
                  osb(0) <= sym; oscnt <= 1; state <= D_OS;
                elsif sym = K_STP then
                  tok <= RK_TLP_START; tok_valid <= '1'; state <= D_TLP;
                elsif sym = K_SDP then
                  tok <= RK_DLLP_START; tok_valid <= '1'; state <= D_DLLP;
                elsif sym = K_SKP then
                  tok <= RK_SKP; tok_valid <= '1';   -- SKP suelto
                else
                  null;  -- otros K en idle: ignorar
                end if;
              else
                tok <= RK_IDLE;  -- dato en idle logico
              end if;

            when D_OS =>
              -- segundo simbolo decide rama rapida SKP/EIOS
              if oscnt = 1 then
                if sym_k = '1' and sym = K_SKP then
                  tok <= RK_SKP; tok_valid <= '1';
                  state <= D_IDLE; oscnt <= 0;       -- SKP OS: consumido
                elsif sym_k = '1' and sym = K_IDL then
                  tok <= RK_EIOS; tok_valid <= '1';
                  state <= D_IDLE; oscnt <= 0;       -- EIOS
                else
                  osb(1) <= sym; oscnt <= 2;
                end if;
              elsif oscnt < TS_LEN then
                osb(oscnt) <= sym;
                if oscnt = TS_LEN - 1 then
                  -- TS completo: clasificar por el identificador sym6..15
                  is_ts1 := (osb(6) = TS1_ID);
                  is_ts2 := (osb(6) = TS2_ID) or (sym = TS2_ID and osb(6) = TS2_ID);
                  -- usar sym (sym15) y osb(6) como testigos del identificador
                  if osb(6) = TS1_ID then
                    tok <= RK_TS1; ts_is_ts2 <= '0';
                  elsif osb(6) = TS2_ID then
                    tok <= RK_TS2; ts_is_ts2 <= '1';
                  else
                    tok <= RK_ERR;
                  end if;
                  tok_valid <= '1';
                  ts_link <= osb(1); ts_lane <= osb(2); ts_nfts <= osb(3);
                  ts_rate <= osb(4); ts_ctl <= osb(5);
                  ts_valid <= '1';
                  state <= D_IDLE; oscnt <= 0;
                else
                  oscnt <= oscnt + 1;
                end if;
              end if;

            when D_TLP =>
              if sym_k = '1' and sym = K_END then
                tok <= RK_TLP_END; tok_valid <= '1'; state <= D_IDLE;
              elsif sym_k = '1' and sym = K_EDB then
                tok <= RK_TLP_ABORT; tok_valid <= '1'; state <= D_IDLE;
              elsif sym_k = '0' then
                tok <= RK_TLP_DATA; tok_data <= sym; tok_valid <= '1';
              else
                tok <= RK_ERR; tok_valid <= '1'; state <= D_IDLE;
              end if;

            when D_DLLP =>
              if sym_k = '1' and sym = K_END then
                tok <= RK_DLLP_END; tok_valid <= '1'; state <= D_IDLE;
              elsif sym_k = '0' then
                tok <= RK_DLLP_DATA; tok_data <= sym; tok_valid <= '1';
              else
                tok <= RK_ERR; tok_valid <= '1'; state <= D_IDLE;
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;
