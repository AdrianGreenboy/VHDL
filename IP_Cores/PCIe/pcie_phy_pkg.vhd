-- ============================================================================
-- pcie_phy_pkg.vhd -- PCIE IP v1
-- Definiciones del PHY logico compartidas por scrambler y framer:
-- seed del LFSR, funcion de avance de 8 bits (byte-paralela) del polinomio
-- G(x)=X^16+X^5+X^4+X^3+1, y byte de scrambling asociado a un estado.
--
-- Convencion del LFSR (identica al modelo serie clasico de PCIe):
--   * Estado de 16 bits d(15..0). Reset = x"FFFF".
--   * Por cada bit servido: out_bit = d(15); shift a la izquierda; el bit que
--     entra en d(0) es d(15); y d(3),d(4),d(5) reciben XOR con d(15) (taps
--     5,4,3). Ocho de estos pasos = un avance de byte.
--   * El byte de scrambling se forma tomando d(15) ANTES de cada uno de los 8
--     shifts (MSB primero), que es el orden en que se aplican a un byte de
--     dato D7..D0.
-- f_lfsr8 devuelve (estado_siguiente, byte_scramble).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pcie_phy_pkg is

  subtype lfsr_t is std_logic_vector(15 downto 0);
  subtype byte_t is std_logic_vector(7 downto 0);

  constant LFSR_SEED : lfsr_t := x"FFFF";

  type lfsr8_res_t is record
    nxt  : lfsr_t;    -- estado tras 8 avances
    sbyte: byte_t;    -- byte de scrambling (aplicar por XOR sobre el dato)
  end record;

  function f_lfsr8(state : lfsr_t) return lfsr8_res_t;

  -- Tipos de token que emite el framer hacia el codec.
  type frm_kind_t is (FK_IDLE, FK_STP, FK_SDP, FK_END, FK_EDB, FK_COM,
                      FK_SKP, FK_DATA, FK_TS);

end package;

package body pcie_phy_pkg is

  function f_lfsr8(state : lfsr_t) return lfsr8_res_t is
    variable d  : lfsr_t := state;
    variable ob : byte_t;
    variable fb : std_logic;
    variable r  : lfsr8_res_t;
  begin
    -- Avance del estado (verificado contra la tabla canonica de estados de
    -- PCIe: FFFF -> E817 -> 0328 -> 284B ...): la salida serie es d(15), se
    -- desplaza a la izquierda realimentando d(15) en d(0) y XOR en taps 3,4,5.
    -- El byte de scrambling se ensambla con orden de bits canonico
    -- (verificado contra la tabla de bytes: FF,17,C0,14,B2,...): el bit d(15)
    -- de cada paso ocupa la posicion i (LSB-first en el ensamblado ob(i)).
    for i in 0 to 7 loop
      ob(i) := d(15);
      fb := d(15);
      d := d(14 downto 0) & fb;    -- shift a la izquierda
      d(3) := d(3) xor fb;
      d(4) := d(4) xor fb;
      d(5) := d(5) xor fb;
    end loop;
    r.nxt   := d;
    r.sbyte := ob;
    return r;
  end function;

end package body;
