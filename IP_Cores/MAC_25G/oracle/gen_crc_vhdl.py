#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Genera rtl/mac25g_crc_pkg.vhd: CRC-32 Ethernet sobre 8..64 bits de datos
# como ECUACIONES XOR EXPLICITAS, una por bit de salida, cada una escrita
# como arbol balanceado entre parentesis.
#
# Motivo (timing a 390.625 MHz): la forma recursiva bit a bit comparte nodos
# intermedios entre bits y Vivado la implemento con 10-11 niveles de LUT. Las
# ecuaciones independientes y balanceadas dan ~3 niveles (XOR de <= 96
# entradas). No hay tablas ni constantes indexadas (leccion de Vivado
# 2025.2.1 de esta familia): solo XOR de senales.
#
# Las ecuaciones se derivan simbolicamente de la misma recurrencia que el
# oraculo (crc_bits), que esta anclado a zlib; tb_mac_pkg lo comprueba.
#
#   python3 oracle/gen_crc_vhdl.py > rtl/mac25g_crc_pkg.vhd
# =============================================================================
POLY = 0xEDB88320


def symbolic(nbits):
    """Cada bit de estado = conjunto de variables (c0..c31, d0..d63) que lo
    componen por XOR, tras procesar nbits bits de datos (bit 0 primero)."""
    s = [frozenset(["c%d" % j]) for j in range(32)]
    for i in range(nbits):
        fb = s[0] ^ frozenset(["d%d" % i])
        s = s[1:] + [frozenset()]
        for j in range(32):
            if (POLY >> j) & 1:
                s[j] = s[j] ^ fb
    return s


def key(v):
    return (v[0], int(v[1:]))


def balanced(terms):
    if len(terms) == 1:
        return terms[0]
    h = len(terms) // 2
    return "(" + balanced(terms[:h]) + " xor " + balanced(terms[h:]) + ")"


def vname(v):
    return "c(%s)" % v[1:] if v[0] == "c" else "d(%s)" % v[1:]


def main():
    out = []
    out.append("""-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- AUTO-GENERADO por oracle/gen_crc_vhdl.py. NO EDITAR A MANO.
-- CRC-32 Ethernet (reflejado, 0xEDB88320), estado c sin complementar, datos
-- d bit 0 primero, sobre 8*k bits (k = 1..8). Una ecuacion XOR balanceada e
-- independiente por bit de salida: ~3 niveles de LUT6 por bit.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package mac25g_crc_pkg is""")
    for k in range(1, 9):
        out.append("  function crc_d%d(c : std_logic_vector(31 downto 0);\n"
                   "                  d : std_logic_vector(63 downto 0)) return std_logic_vector;"
                   % (8 * k))
    out.append("end package mac25g_crc_pkg;\n\npackage body mac25g_crc_pkg is")
    for k in range(1, 9):
        nb = 8 * k
        s = symbolic(nb)
        out.append("\n  function crc_d%d(c : std_logic_vector(31 downto 0);\n"
                   "                  d : std_logic_vector(63 downto 0)) return std_logic_vector is\n"
                   "    variable r : std_logic_vector(31 downto 0);\n  begin" % nb)
        for j in range(32):
            terms = [vname(v) for v in sorted(s[j], key=key)]
            expr = balanced(terms) if terms else "'0'"
            out.append("    r(%d) := %s;" % (j, expr))
        out.append("    return r;\n  end function;")
    out.append("\nend package body mac25g_crc_pkg;")
    print("\n".join(out))


if __name__ == "__main__":
    main()
