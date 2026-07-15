-- ============================================================================
-- pcie_dll_rx.vhd -- PCIE IP v1
-- Data Link Layer RX. Consume el stream de un TLP ya deframado
--   [seq_hi][seq_lo][payload...][lcrc0..3]
-- (marcado con start en el primer byte y last en el ultimo del LCRC), verifica
-- el LCRC-32 y el numero de secuencia esperado (next_rx). Genera peticiones de
-- ACK (seq correcto y CRC ok) o NAK (CRC malo o seq fuera de orden).
--
-- Entrega el payload validado a la capa de transaccion (rx_* hacia TL) SOLO si
-- el TLP es bueno y en orden.
--
-- Reglas:
--   * TLP bueno y seq == next_rx: aceptar, next_rx++, pedir ACK(seq).
--   * CRC malo: descartar, pedir NAK(next_rx - 1) (pide reenvio desde el
--     ultimo bueno). Se marca nak_armed para no spamear NAKs.
--   * seq != next_rx (duplicado o adelantado): descartar; si es duplicado
--     (seq < next_rx) reconfirmar ACK(next_rx-1); si adelantado, NAK.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_dll_pkg.all;

entity pcie_dll_rx is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    -- stream deframado de entrada (un TLP)
    in_valid  : in  std_logic;
    in_data   : in  byte_t;
    in_start  : in  std_logic;      -- primer byte del TLP (seq_hi)
    in_last   : in  std_logic;      -- ultimo byte (lcrc3)

    -- payload validado hacia TL
    tl_valid  : out std_logic;
    tl_data   : out byte_t;
    tl_last   : out std_logic;

    -- peticion de ACK/NAK hacia el generador de DLLP
    ak_req    : out std_logic;
    ak_is_nak : out std_logic;
    ak_seq    : out std_logic_vector(11 downto 0);

    -- monitor
    good_o    : out std_logic_vector(15 downto 0);
    bad_o     : out std_logic_vector(15 downto 0);
    nextrx_o  : out std_logic_vector(11 downto 0)
  );
end entity;

architecture rtl of pcie_dll_rx is
  type rstate_t is (R_IDLE, R_SEQLO, R_PAY, R_CRC, R_CHECK);
  signal st : rstate_t := R_IDLE;

  signal next_rx : seq_t := (others => '0');
  signal cur_seq : seq_t := (others => '0');
  signal crc     : crc32_t := LCRC_SEED;
  signal rx_lcrc : crc32_t := (others => '0');
  signal ci      : integer range 0 to 4 := 0;
  signal good    : unsigned(15 downto 0) := (others => '0');
  signal bad     : unsigned(15 downto 0) := (others => '0');

  -- Pipeline de retardo de 4 bytes: conforme llegan bytes en R_PAY, el byte
  -- "de hace 4" es payload confirmado y se acumula al CRC incrementalmente
  -- (UN f_crc32_byte por ciclo). Los 4 bytes que quedan en el pipeline al
  -- llegar in_last son el LCRC recibido. Esto reemplaza al buffer de 64 bytes
  -- + bucle de 64 CRCs encadenados combinacionalmente en R_CHECK, que
  -- generaba ~600 niveles de logica XOR y saturaba la sintesis.
  type dly_t is array (0 to 3) of byte_t;
  signal dly    : dly_t := (others => (others=>'0'));
  signal dcount : integer range 0 to 4 := 0;

  signal seqhi : byte_t := (others=>'0');
begin

  good_o   <= std_logic_vector(good);
  bad_o    <= std_logic_vector(bad);
  nextrx_o <= std_logic_vector(next_rx);

  process(clk)
    variable good_tlp : boolean;
    variable seq_i : integer;
    variable c   : crc32_t;
    variable rxc : crc32_t;
    variable n   : integer;
    variable v12 : std_logic_vector(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= R_IDLE; next_rx <= (others=>'0'); crc <= LCRC_SEED;
        ci <= 0; good <= (others=>'0'); bad <= (others=>'0');
        dcount <= 0;
        tl_valid <= '0'; tl_last <= '0';
        ak_req <= '0'; ak_is_nak <= '0'; ak_seq <= (others=>'0');
      else
        tl_valid <= '0'; tl_last <= '0';
        ak_req   <= '0';

        case st is
          when R_IDLE =>
            if in_valid = '1' and in_start = '1' then
              seqhi <= in_data;
              crc <= f_crc32_byte(LCRC_SEED, in_data);
              dcount <= 0;
              st <= R_SEQLO;
            end if;

          when R_SEQLO =>
            if in_valid = '1' then
              v12 := seqhi(3 downto 0) & in_data;
              cur_seq <= unsigned(v12);
              crc <= f_crc32_byte(crc, in_data);
              st <= R_PAY;
            end if;

          when R_PAY =>
            if in_valid = '1' then
              -- Pipeline de retardo de 4 bytes: los primeros 4 bytes solo
              -- llenan el pipeline; a partir del 5o, el byte mas viejo
              -- (dly(0)) es payload confirmado y se acumula al CRC (un solo
              -- f_crc32_byte por ciclo). Al llegar in_last, los 4 bytes que
              -- quedan en el pipeline son el LCRC recibido.
              if dcount < 4 then
                dly(dcount) <= in_data;
                dcount <= dcount + 1;
              else
                crc <= f_crc32_byte(crc, dly(0));
                dly(0) <= dly(1); dly(1) <= dly(2); dly(2) <= dly(3);
                dly(3) <= in_data;
              end if;
              if in_last = '1' then
                st <= R_CHECK;
              end if;
            end if;

          when others =>
            null;
        end case;

        -- ------- R_CHECK: el CRC ya acumulo el payload (via pipeline) -------
        if st = R_CHECK then
          good_tlp := false;
          -- crc ya incluye seq_hi/seq_lo + payload (bytes retardados). Los 4
          -- bytes del pipeline son el LCRC recibido en orden de transmision:
          -- dly(0)=lcrc0 ... dly(3)=lcrc3.
          c := f_lcrc_final(crc);
          rxc := dly(3) & dly(2) & dly(1) & dly(0);
          if c = rxc then good_tlp := true; end if;

          seq_i := to_integer(cur_seq);
          if good_tlp and cur_seq = next_rx then
            good <= good + 1;
            next_rx <= next_rx + 1;
            ak_req <= '1'; ak_is_nak <= '0';
            ak_seq <= std_logic_vector(cur_seq);
          elsif not good_tlp then
            bad <= bad + 1;
            ak_req <= '1'; ak_is_nak <= '1';
            ak_seq <= std_logic_vector(next_rx - 1);
          else
            -- CRC ok pero fuera de orden -> reconfirmar ultimo bueno
            bad <= bad + 1;
            ak_req <= '1'; ak_is_nak <= '0';
            ak_seq <= std_logic_vector(next_rx - 1);
          end if;
          st <= R_IDLE;
        end if;

      end if;
    end if;
  end process;

end architecture;
