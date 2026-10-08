#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Genera vivado/mac_soc_bd.tcl a partir del BD capturado del Core 19
# (PCS_25G/vivado/pcs_soc_bd.tcl), que ya dio silicon pass en la TE0950.
#
# El SoC del Core 20 tiene EXACTAMENTE la misma interfaz que el del Core 19
# (s_axi, m_axi, clk_dp, dp_locked, irq_out), asi que la cirugia es solo un
# renombrado. La configuracion de CIPS/NoC se conserva tal cual (hecha por GUI
# y capturada con write_bd_tcl): no se regenera CIPS por TCL.
# Se auto-verifica: no deben quedar restos del Core 19.
# =============================================================================
set -eu
cd "$(dirname "$0")"
SRC=../../PCS_25G/vivado/pcs_soc_bd.tcl

python3 - "$SRC" << 'PYEOF'
import sys
src = open(sys.argv[1]).read()
n0 = len(src)
for a, b, exp in [("soc_top_pcs_wrap", "soc_top_mac_wrap", None),
                  ("soc_pcs_0", "soc_mac_0", None),
                  ("pcs_soc_bd", "mac_soc_bd", None)]:
    c = src.count(a)
    assert c > 0, "no aparece %s" % a
    src = src.replace(a, b)
open("mac_soc_bd.tcl", "w").write(src)
print("mac_soc_bd.tcl generado (%d -> %d bytes)" % (n0, len(src)))
PYEOF

echo "--- verificacion de restos (esperado 0) ---"
for pat in soc_pcs_0 soc_top_pcs_wrap pcs_soc_bd; do
  echo "  '$pat': $(grep -c "$pat" mac_soc_bd.tcl || true)"
done
echo "--- referencias nuevas ---"
echo "  soc_mac_0: $(grep -c soc_mac_0 mac_soc_bd.tcl)"
echo "  soc_top_mac_wrap: $(grep -c soc_top_mac_wrap mac_soc_bd.tcl)"
echo "  axil_soc del RV32 en 0xA4000000: $(grep -c '0xA4000000.*soc_mac_0/s_axi' mac_soc_bd.tcl)"
