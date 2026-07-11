-- eth_tx_mii.vhd — motor TX MII 100 Mbit/s (familia TSN Ethernet, MAC v1)
--
-- Serializador de nibbles a 25 MHz (via mii_ce, 1 pulso cada 4 ciclos de los
-- 100 MHz del core — sin CDC, todo en un dominio, patron LOOP_INT v1):
--   preambulo (7 x 0x55) + SFD (0xD5) + bytes de trama + padding a 60 bytes
--   + FCS/CRC-32 por hardware + IPG de 96 bit-times (24 nibbles).
--
-- Entrada: flujo de bytes (dst+src+type+payload) con tx_last marcando el
-- ultimo byte. tx_ready solo se afirma cuando el motor consume (estado
-- DAT_LO con mii_ce): un byte cada 2 nibbles. La trama debe estar completa
-- en la FIFO antes de disparar (store-and-forward); si tx_valid cae en mitad
-- de trama el motor aborta (underrun, pulso de 1 ciclo) y respeta el IPG.
--
-- Nibble bajo primero (orden MII). FCS transmitido byte bajo primero,
-- nibble bajo primero, SIN pasar por el propio CRC.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_pkg.all;

entity eth_tx_mii is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                     -- sincrono activo-alto
    mii_ce   : in  std_logic;                     -- pulso a tasa de nibble (25 MHz)
    -- flujo de bytes de la trama
    tx_data  : in  std_logic_vector(7 downto 0);
    tx_valid : in  std_logic;
    tx_last  : in  std_logic;
    tx_ready : out std_logic;
    tx_busy  : out std_logic;
    underrun : out std_logic;                     -- pulso: valid cayo en mitad de trama
    -- MII TX
    txd      : out std_logic_vector(3 downto 0);
    tx_en    : out std_logic;
    -- pulso de 1 ciclo de core-clock en el instante del SFD (para PTP TS).
    -- Se afirma en el mii_ce que emite el nibble 0xD del SFD. Convenio de
    -- captura identico al de eth_rx_mii (nibble 0xD).
    tx_sfd_pulse : out std_logic;
    -- override 1-step: cuando ovr_en='1' y byte_cnt cae en [ovr_off, ovr_off+
    -- ovr_len), el byte emitido (y alimentado al CRC) se toma de ovr_data en
    -- vez de la FIFO. Permite parchear originTimestamp/correctionField in-fly
    -- con el timestamp del SFD de ESTA trama, manteniendo el FCS correcto.
    -- ovr_data se indexa por (byte_cnt - ovr_off). Ancho maximo 10 bytes.
    ovr_en   : in  std_logic := '0';
    ovr_off  : in  std_logic_vector(10 downto 0) := (others => '0');
    ovr_len  : in  std_logic_vector(3 downto 0)  := (others => '0');
    ovr_data : in  std_logic_vector(79 downto 0) := (others => '0')  -- 10 bytes, byte0 en [7:0]
  );
end entity eth_tx_mii;

architecture rtl of eth_tx_mii is

  type st_t is (ST_IDLE, ST_PRE, ST_SFD, ST_DAT_LO, ST_DAT_HI,
                ST_PAD_LO, ST_PAD_HI, ST_FCS, ST_IPG);

  signal st       : st_t := ST_IDLE;
  signal crc      : std_logic_vector(31 downto 0) := (others => '1');
  signal fcs_sh   : std_logic_vector(31 downto 0) := (others => '0');
  signal pre_cnt  : unsigned(3 downto 0)  := (others => '0');
  signal byte_cnt : unsigned(10 downto 0) := (others => '0');
  signal fcs_nib  : unsigned(2 downto 0)  := (others => '0');
  signal ipg_cnt  : unsigned(4 downto 0)  := (others => '0');
  signal cur_hi   : std_logic_vector(3 downto 0) := (others => '0');
  signal last_l   : std_logic := '0';
  signal txd_r    : std_logic_vector(3 downto 0) := (others => '0');
  signal txen_r   : std_logic := '0';
  signal sfd_p    : std_logic := '0';   -- pulso SFD (1 ciclo de core-clock)

begin

  txd      <= txd_r;
  tx_en    <= txen_r;
  tx_sfd_pulse <= sfd_p;
  tx_busy  <= '0' when st = ST_IDLE else '1';
  -- Consumo combinacional en el mismo ce del nibble bajo (contrato FIFO FWFT).
  tx_ready <= '1' when (st = ST_DAT_LO and mii_ce = '1' and rst = '0') else '0';

  process(clk)
    variable v_crc : std_logic_vector(31 downto 0);
    variable v_cnt : unsigned(10 downto 0);
    variable v_byte : std_logic_vector(7 downto 0);
    variable v_idx  : integer range 0 to 9;
  begin
    if rising_edge(clk) then
      underrun <= '0';
      sfd_p    <= '0';
      if rst = '1' then
        st     <= ST_IDLE;
        txen_r <= '0';
        txd_r  <= (others => '0');
      elsif mii_ce = '1' then
        case st is

          when ST_IDLE =>
            txen_r <= '0';
            txd_r  <= (others => '0');
            if tx_valid = '1' then
              txd_r   <= x"5";                    -- 1er nibble de preambulo
              txen_r  <= '1';
              pre_cnt <= to_unsigned(1, pre_cnt'length);
              st      <= ST_PRE;
            end if;

          when ST_PRE =>
            txd_r   <= x"5";
            pre_cnt <= pre_cnt + 1;
            if pre_cnt = 14 then                  -- este ce emite el 15o 0x5
              st <= ST_SFD;
            end if;

          when ST_SFD =>
            txd_r    <= x"D";                     -- SFD 0xD5: 0x5 ya emitido, ahora 0xD
            sfd_p    <= '1';                       -- pulso SFD: instante de TS TX
            crc      <= CRC32_INIT;
            byte_cnt <= (others => '0');
            st       <= ST_DAT_LO;

          when ST_DAT_LO =>
            if tx_valid = '1' then
              -- seleccion del byte efectivo: override 1-step si byte_cnt cae en
              -- la ventana [ovr_off, ovr_off+ovr_len). El byte parcheado va
              -- TANTO a la salida MII como al CRC (asi el FCS queda correcto).
              if ovr_en = '1'
                 and byte_cnt >= unsigned(ovr_off)
                 and byte_cnt < (unsigned(ovr_off) + unsigned(ovr_len)) then
                v_idx  := to_integer(byte_cnt - unsigned(ovr_off));
                v_byte := ovr_data(v_idx*8+7 downto v_idx*8);
              else
                v_byte := tx_data;
              end if;
              txd_r  <= v_byte(3 downto 0);
              cur_hi <= v_byte(7 downto 4);
              last_l <= tx_last;
              crc    <= crc32_nibble(crc, v_byte(3 downto 0));
              st     <= ST_DAT_HI;
            else
              txen_r   <= '0';                    -- underrun: abortar trama
              txd_r    <= (others => '0');
              underrun <= '1';
              ipg_cnt  <= (others => '0');
              st       <= ST_IPG;
            end if;

          when ST_DAT_HI =>
            txd_r    <= cur_hi;
            v_crc    := crc32_nibble(crc, cur_hi);
            crc      <= v_crc;
            v_cnt    := byte_cnt + 1;
            byte_cnt <= v_cnt;
            if last_l = '1' then
              if v_cnt < 60 then
                st <= ST_PAD_LO;                  -- padding a 60 bytes de datos
              else
                fcs_sh  <= not v_crc;
                fcs_nib <= (others => '0');
                st      <= ST_FCS;
              end if;
            else
              st <= ST_DAT_LO;
            end if;

          when ST_PAD_LO =>
            txd_r <= x"0";
            crc   <= crc32_nibble(crc, x"0");
            st    <= ST_PAD_HI;

          when ST_PAD_HI =>
            txd_r    <= x"0";
            v_crc    := crc32_nibble(crc, x"0");
            crc      <= v_crc;
            v_cnt    := byte_cnt + 1;
            byte_cnt <= v_cnt;
            if v_cnt = 60 then
              fcs_sh  <= not v_crc;
              fcs_nib <= (others => '0');
              st      <= ST_FCS;
            else
              st <= ST_PAD_LO;
            end if;

          when ST_FCS =>
            txd_r   <= fcs_sh(3 downto 0);        -- byte bajo primero, nibble bajo primero
            fcs_sh  <= x"0" & fcs_sh(31 downto 4);
            fcs_nib <= fcs_nib + 1;
            if fcs_nib = 7 then
              ipg_cnt <= (others => '0');
              st      <= ST_IPG;
            end if;

          when ST_IPG =>
            txen_r  <= '0';
            txd_r   <= (others => '0');
            ipg_cnt <= ipg_cnt + 1;
            if ipg_cnt = 23 then                  -- 24 nibbles = 96 bit-times
              st <= ST_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
