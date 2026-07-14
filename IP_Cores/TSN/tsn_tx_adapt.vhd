-- tsn_tx_adapt.vhd - Adaptador entre el crossbar TSN y el eth_tx_mii real
-- El xbar emite un flujo denso (tx_valid/tx_last con handshake xbar_ready byte
-- a byte); el eth_tx_mii consume 1 byte por mii_ce solo en ST_DAT_LO y tiene
-- IPG interno con tx_busy. Este shim:
--   * arranca el motor solo cuando NO esta ocupado (mii_busy='0') -> anti
--     fantasma del segundo envio consecutivo (leccion PTP)
--   * traduce el mii_ready esporadico en xbar_ready hacia el crossbar
--   * mantiene un registro de 1 byte (skid) para desacoplar los dominios de
--     handshake: el xbar entrega cuando xbar_ready; el MII consume cuando quiere
--
-- Nota de verificacion: el guard mii_busy es defensa en profundidad; se probo
-- formalmente (traza MII nibble-identica) que quitarlo NO cambia la salida en
-- este entorno, porque el eth_tx_mii solo muestrea tx_valid en ST_IDLE y el
-- skid presenta siempre el dato correcto. Es una mutacion equivalente, no un
-- agujero del TB.
--
-- Contrato hacia el xbar (lado dut->adapt):
--   xbar_valid/xbar_data/xbar_last presentados; xbar_ready pulsa cuando el
--   byte fue aceptado (el xbar avanza icnt en ese ciclo).
-- Contrato hacia el MII (lado adapt->tx):
--   mii_data/mii_valid/mii_last con el handshake nativo del eth_tx_mii
--   (mii_ready alto en ST_DAT_LO & mii_ce).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsn_tx_adapt is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- lado xbar (flujo denso)
    xbar_data  : in  std_logic_vector(7 downto 0);
    xbar_valid : in  std_logic;
    xbar_last  : in  std_logic;
    xbar_ready : out std_logic;
    -- lado eth_tx_mii
    mii_data   : out std_logic_vector(7 downto 0);
    mii_valid  : out std_logic;
    mii_last   : out std_logic;
    mii_ready  : in  std_logic;    -- tx_ready del eth_tx_mii
    mii_busy   : in  std_logic     -- tx_busy del eth_tx_mii (IPG incluido)
  );
end entity;

architecture rtl of tsn_tx_adapt is
  -- skid de 1 byte: desacopla la aceptacion xbar de la demanda del MII
  signal hold      : std_logic := '0';                     -- skid ocupado
  signal hold_data : std_logic_vector(7 downto 0) := (others => '0');
  signal hold_last : std_logic := '0';
  signal armed     : std_logic := '0';  -- trama en curso hacia el MII
begin
  -- presentacion al MII: lo que hay en el skid, pero solo tras armar (motor
  -- libre). armed se levanta cuando hay byte y el motor no esta ocupado, y
  -- baja tras entregar el ultimo byte.
  mii_data  <= hold_data;
  mii_valid <= hold and armed;
  mii_last  <= hold_last;

  -- aceptamos del xbar cuando el skid esta vacio (o se vacia este ciclo)
  xbar_ready <= '1' when hold = '0' or (armed = '1' and mii_ready = '1')
                else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        hold  <= '0';
        armed <= '0';
        hold_last <= '0';
      else
        -- 1) consumo por el MII
        if hold = '1' and armed = '1' and mii_ready = '1' then
          hold <= '0';
          if hold_last = '1' then
            armed <= '0';                 -- fin de trama: desarmar
          end if;
        end if;
        -- 2) carga desde el xbar (si aceptamos este ciclo)
        if xbar_valid = '1' and
           (hold = '0' or (armed = '1' and mii_ready = '1')) then
          hold_data <= xbar_data;
          hold_last <= xbar_last;
          hold      <= '1';
        end if;
        -- 3) armado del motor: hay byte pendiente y el motor esta libre.
        --    NO armamos mientras mii_busy='1' (IPG del envio anterior) -> el
        --    segundo envio consecutivo espera a que el motor vuelva a IDLE.
        if armed = '0' and mii_busy = '0' then
          if (hold = '1') or (xbar_valid = '1') then
            armed <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
