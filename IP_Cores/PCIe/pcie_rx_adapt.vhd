-- ============================================================================
-- pcie_rx_adapt.vhd -- PCIE IP v1
-- Adaptador RX: toma los tokens del deframer (RK_TLP_START/DATA/END/ABORT) y
-- reconstruye un stream de bytes con start/last bien definidos, apto para
-- alimentar tanto al TL_EP (que parsea el TLP crudo) como a la DLL RX.
--
-- Un TLP en el cable es: STP, [seq_hi seq_lo][header+payload][lcrc0..3], END.
-- El deframer entrega: RK_TLP_START (por el STP), luego RK_TLP_DATA por cada
-- byte (incluye seq y lcrc), y RK_TLP_END al final.
--
-- Salida "cruda" (out_*): el stream completo tal cual (seq + tlp + lcrc), con
-- out_start en el primer byte (seq_hi) y out_last en el ultimo (lcrc3).
--
-- Salida "TL" (tl_*): el TLP SIN los 2 bytes de seq iniciales ni los 4 de LCRC
-- finales -> exactamente el header+payload que el completer espera. Para
-- lograrlo con streaming se usa un retardo de 4 bytes (para recortar el LCRC) y
-- se saltan los 2 primeros (seq). tl_start en el primer byte del header,
-- tl_last en el ultimo byte de payload.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;   -- rx_kind_t

entity pcie_rx_adapt is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    tok       : in  rx_kind_t;
    tok_data  : in  byte_t;
    tok_valid : in  std_logic;

    -- stream crudo (seq+tlp+lcrc) -> DLL RX
    out_valid : out std_logic;
    out_data  : out byte_t;
    out_start : out std_logic;
    out_last  : out std_logic;

    -- stream TL (header+payload, sin seq ni lcrc) -> TL EP
    tl_valid  : out std_logic;
    tl_data   : out byte_t;
    tl_start  : out std_logic;
    tl_last   : out std_logic
  );
end entity;

architecture rtl of pcie_rx_adapt is
  type st_t is (A_IDLE, A_RUN);
  signal st : st_t := A_IDLE;
  signal bcnt : integer range 0 to 4095 := 0;   -- bytes desde el start

  -- retardo de 4 bytes para poder recortar el LCRC al ver END
  type d4_t is array (0 to 4) of byte_t;
  signal dl   : d4_t := (others => (others=>'0'));
  signal dv   : std_logic_vector(0 to 4) := (others=>'0');
  signal fill : integer range 0 to 5 := 0;
  signal tl_first : std_logic := '1';
begin

  process(clk)
    variable is_data, is_start, is_end : boolean;
  begin
    if rising_edge(clk) then
      if rst='1' then
        st <= A_IDLE; bcnt <= 0; fill <= 0; tl_first <= '1';
        out_valid<='0'; out_start<='0'; out_last<='0'; out_data<=(others=>'0');
        tl_valid<='0'; tl_start<='0'; tl_last<='0'; tl_data<=(others=>'0');
        dv <= (others=>'0');
      else
        out_valid<='0'; out_start<='0'; out_last<='0';
        tl_valid<='0'; tl_start<='0'; tl_last<='0';

        is_start := (tok_valid='1' and tok=RK_TLP_START);
        is_data  := (tok_valid='1' and tok=RK_TLP_DATA);
        is_end   := (tok_valid='1' and (tok=RK_TLP_END or tok=RK_TLP_ABORT));

        case st is
          when A_IDLE =>
            if is_start then
              st <= A_RUN; bcnt <= 0; fill <= 0; tl_first <= '1';
              dv <= (others=>'0');
            end if;

          when A_RUN =>
            if is_data then
              -- ----- stream crudo -----
              out_valid <= '1';
              out_data  <= tok_data;
              if bcnt = 0 then out_start <= '1'; end if;

              -- ----- stream TL: saltar 2 bytes de seq, retrasar 4 (LCRC) -----
              -- empujar al pipeline de 4
              dl(4)<=dl(3); dl(3)<=dl(2); dl(2)<=dl(1); dl(1)<=dl(0);
              dl(0)<=tok_data;
              dv(4)<=dv(3); dv(3)<=dv(2); dv(2)<=dv(1); dv(1)<=dv(0);
              -- el byte que entra es valido para TL solo si bcnt>=2 (tras seq)
              if bcnt >= 2 then dv(0)<='1'; else dv(0)<='0'; end if;

              -- emitir el byte que sale del retardo (4 posiciones atras) SOLO si
              -- aun no estamos en la zona de LCRC. Como no conocemos la longitud
              -- de antemano, emitimos con retardo 4 y confiamos en que END corta
              -- justo cuando los 4 en vuelo son el LCRC.
              if dv(4)='1' then
                tl_valid <= '1';
                tl_data  <= dl(4);
                if tl_first = '1' then tl_start <= '1'; tl_first <= '0'; end if;
              end if;

              bcnt <= bcnt + 1;

            elsif is_end then
              -- al END, los 4 bytes en vuelo (dl(0..3)) son el LCRC -> se
              -- descartan. El ultimo byte de payload ya salio; marcamos last en
              -- el byte que sale ahora (dl(4) si valido).
              out_valid <= '1'; out_data <= tok_data; out_last <= '1';
              if dv(4)='1' then
                tl_valid <= '1'; tl_data <= dl(4); tl_last <= '1';
              end if;
              st <= A_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture;
