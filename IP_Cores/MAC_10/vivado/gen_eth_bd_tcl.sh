#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 21 - ETH GT
# Genera vivado/eth_soc_bd.tcl a partir del BD del Core 20
# (MAC_25G/vivado/mac_soc_bd.tcl, silicon pass en la TE0950). CIPS/NoC/DDR se
# conservan TAL CUAL (configuracion hecha por GUI): no se regenera CIPS.
#
# Cirugia (todas las sustituciones se verifican; si algo no aparece, aborta):
#   * mac_soc_bd -> eth_soc_bd, soc_top_mac_wrap -> eth21_bd_wrap,
#     soc_mac_0 -> eth21_0
#   * el Core 21 no tiene maestro AXI ni IRQ: fuera la conexion m_axi -> NoC
#     S06_AXI, sus direcciones y la red de irq_out
#   * NoC: 7 -> 6 entradas AXI y 7 -> 6 relojes (fuera S06_AXI y aclk6)
#   * sin validate_bd_design al final (el GT se anade despues en el build)
# =============================================================================
set -eu
cd "$(dirname "$0")"
SRC=../../MAC_25G/vivado/mac_soc_bd.tcl

python3 - "$SRC" << 'PYEOF'
import re, sys
src = open(sys.argv[1]).read()
n0 = len(src)

def sub(a, b, count=None):
    global src
    c = src.count(a)
    assert c > 0, "no aparece: %r" % a[:80]
    if count is not None:
        assert c == count, "%r aparece %d veces (esperado %d)" % (a[:60], c, count)
    src = src.replace(a, b)

def drop_lines(pattern, expect):
    global src
    lines = src.split("\n")
    keep = [l for l in lines if not re.search(pattern, l)]
    assert len(lines) - len(keep) == expect, "%s: %d lineas (esperado %d)" % (
        pattern, len(lines) - len(keep), expect)
    src = "\n".join(keep)

sub("mac_soc_bd", "eth_soc_bd")
sub("soc_top_mac_wrap", "eth21_bd_wrap")
sub("soc_mac_0", "eth21_0")

# maestro AXI y sus direcciones
drop_lines(r"connect_bd_intf_net -intf_net eth21_0_m_axi ", 1)
drop_lines(r"get_bd_addr_spaces eth21_0/m_axi", 2)
# red de IRQ (sentencia de dos lineas)
sub("  connect_bd_net -net eth21_0_irq_out  [get_bd_pins eth21_0/irq_out] \\\n"
    "  [get_bd_pins versal_cips_0/pl_ps_irq0]\n", "", 1)
# NoC: S06_AXI y aclk6
sub("    CONFIG.NUM_CLKS {7} \\\n", "    CONFIG.NUM_CLKS {6} \\\n", 1)
sub("    CONFIG.NUM_SI {7} \\\n", "    CONFIG.NUM_SI {6} \\\n", 1)
m = re.search(r"\n  set_property -dict \[ list \\\n(?:   [^\n]*\n)*? \] \[get_bd_intf_pins \$axi_noc_0/S06_AXI\]\n", src)
assert m, "bloque S06_AXI no encontrado"
src = src[:m.start()] + "\n" + src[m.end():]
m = re.search(r"\n  set_property -dict \[ list \\\n   CONFIG.ASSOCIATED_BUSIF \{S06_AXI\} \\\n \] \[get_bd_pins \$axi_noc_0/aclk6\]\n", src)
assert m, "bloque aclk6 no encontrado"
src = src[:m.start()] + "\n" + src[m.end():]
sub("  [get_bd_pins smartconnect_0/aclk] \\\n  [get_bd_pins axi_noc_0/aclk6]\n",
    "  [get_bd_pins smartconnect_0/aclk]\n", 1)
# sin validacion dentro del script del BD
sub("  validate_bd_design\n  save_bd_design\n}\n# End of create_root_design()",
    "  save_bd_design\n}\n# End of create_root_design()", 1)

for bad in ("S06_AXI", "aclk6", "eth21_0/m_axi", "eth21_0_m_axi", "irq_out", "soc_mac", "mac_soc"):
    assert bad not in src, "queda %s" % bad
open("eth_soc_bd.tcl", "w").write(src)
print("eth_soc_bd.tcl generado (%d -> %d bytes)" % (n0, len(src)))
PYEOF

echo "--- comprobaciones ---"
echo "  eth21_0 en 0xA4000000: $(grep -c '0xA4000000.*eth21_0/s_axi' eth_soc_bd.tcl)"
echo "  NUM_SI {6}: $(grep -c 'NUM_SI {6}' eth_soc_bd.tcl)  NUM_CLKS {6}: $(grep -c 'NUM_CLKS {6}' eth_soc_bd.tcl)"
echo "  restos S06/aclk6/m_axi del core/irq: $(grep -cE 'S06_AXI|aclk6|eth21_0/m_axi|irq_out' eth_soc_bd.tcl || true)"
