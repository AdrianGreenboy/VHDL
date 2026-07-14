-- ============================================================================
-- pcie_scrambler.vhd -- PCIE IP v1
-- Scrambler/descrambler PCIe Gen1 (identico en ambos sentidos: XOR involutivo).
-- Regla implementada exactamente:
--   * COM (K28.5): reinicializa el LFSR a 0xFFFF, no se scrambla, no avanza
--     "como los demas" (queda en el estado inicial para el siguiente simbolo).
--   * SKP: no se scrambla y NO avanza el LFSR.
--   * Resto de simbolos D y K: el LFSR avanza 8 posiciones.
--   * Solo los D se XORean con el byte de scrambling. Los K avanzan el LFSR
--     pero salen sin modificar.
--   * bypass='1' (p.ej. datos dentro de TS1/TS2 o scrambling deshabilitado):
--     el LFSR AVANZA igual (es un simbolo D normal para el contador) pero el
--     dato NO se XORea. Esto respeta "TS no se scramblan" sin desincronizar.
--
-- Interfaz de flujo simple, 1 simbolo/ciclo con clock-enable 'en'. Latencia 1.
-- La decision (es_com/es_skp/es_k/bypass) la provee el framer aguas arriba.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_phy_pkg.all;

entity pcie_scrambler is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;                 -- sincrono
    en      : in  std_logic;                 -- clock-enable de simbolo
    din     : in  byte_t;
    is_k    : in  std_logic;                 -- el simbolo es un codigo K
    is_com  : in  std_logic;                 -- COM: reinit LFSR
    is_skp  : in  std_logic;                 -- SKP: no avanzar
    bypass  : in  std_logic;                 -- no XOR aunque sea D (TS/disable)
    dout    : out byte_t;
    dout_k  : out std_logic;                 -- pasa is_k con la misma latencia
    lfsr_mon: out lfsr_t
  );
end entity;

architecture rtl of pcie_scrambler is
  signal st : lfsr_t := LFSR_SEED;
begin
  process(clk)
    variable r : lfsr8_res_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st     <= LFSR_SEED;
        dout   <= (others => '0');
        dout_k <= '0';
      elsif en = '1' then
        dout_k <= is_k;
        if is_com = '1' then
          st   <= LFSR_SEED;         -- reinicializa; COM sale intacto
          dout <= din;
        elsif is_skp = '1' then
          dout <= din;               -- no avanza, no scrambla
        else
          r := f_lfsr8(st);
          st <= r.nxt;               -- avanza 8 en todo D o K (no SKP)
          if is_k = '1' or bypass = '1' then
            dout <= din;             -- K y TS/disable: sin XOR
          else
            dout <= din xor r.sbyte; -- dato scrambleado
          end if;
        end if;
      end if;
    end if;
  end process;
  lfsr_mon <= st;
end architecture;
