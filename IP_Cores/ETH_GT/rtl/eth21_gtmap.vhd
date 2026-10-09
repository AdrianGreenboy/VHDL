-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Correspondencia bloque de 66 bits <-> puertos del GT (64B66B_ASYNC, 64 b).
--
-- Bloque de los PCS66 del Core 20 (mac25g_pcs66_tx/rx):
--   blk(65:2) = payload aleatorizado (bit i del payload = blk(2+i), el bit
--               0 es el primero en el cable segun 802.3)
--   blk(1:0)  = cabecera con la convencion del Core 19/20: datos = "01"
--               (blk(1)='0', blk(0)='1'), control = "10".
-- Orden en el cable segun IEEE 802.3 (fig. 49-7), wire(0) primero:
--   wire(0..1) = cabecera (datos: 0,1 ; control: 1,0)  -> wire0 = blk(1),
--                                                         wire1 = blk(0)
--   wire(2+i)  = payload bit i
--
-- Hipotesis por defecto sobre el GT (flags a 0): transmite txheader(0),
-- txheader(1) y luego txdata(0..63) (LSB primero). El orden real del GTYP
-- en 64B66B_ASYNC no se puede garantizar desde la documentacion y el
-- loopback interno no lo distingue, asi que se corrige en ejecucion:
--   hdr_swap = 1 : txheader(0) <- wire1, txheader(1) <- wire0
--   bit_rev  = 1 : txdata(i) <- wire(2+63-i)
-- El receptor aplica la inversa con sus propios flags.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity eth21_gtmap_tx is
  port (
    blk      : in  std_logic_vector(65 downto 0);
    bit_rev  : in  std_logic;
    hdr_swap : in  std_logic;
    txdata   : out std_logic_vector(63 downto 0);
    txheader : out std_logic_vector(1 downto 0)
  );
end entity eth21_gtmap_tx;

architecture rtl of eth21_gtmap_tx is
  signal pl : std_logic_vector(63 downto 0);
begin
  pl <= blk(65 downto 2);
  g: for i in 0 to 63 generate
    txdata(i) <= pl(63 - i) when bit_rev = '1' else pl(i);
  end generate;
  txheader(0) <= blk(0) when hdr_swap = '1' else blk(1);
  txheader(1) <= blk(1) when hdr_swap = '1' else blk(0);
end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;

entity eth21_gtmap_rx is
  port (
    rxdata   : in  std_logic_vector(63 downto 0);
    rxheader : in  std_logic_vector(1 downto 0);
    bit_rev  : in  std_logic;
    hdr_swap : in  std_logic;
    blk      : out std_logic_vector(65 downto 0)
  );
end entity eth21_gtmap_rx;

architecture rtl of eth21_gtmap_rx is
begin
  g: for i in 0 to 63 generate
    blk(2 + i) <= rxdata(63 - i) when bit_rev = '1' else rxdata(i);
  end generate;
  -- wire0 -> blk(1), wire1 -> blk(0)
  blk(1) <= rxheader(1) when hdr_swap = '1' else rxheader(0);
  blk(0) <= rxheader(0) when hdr_swap = '1' else rxheader(1);
end architecture rtl;
