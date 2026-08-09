#!/bin/bash
# ============================================================================
# Core 20 - genera vivado/ecc_soc_bd.tcl desde el BD del Core 19 (PCS).
# Cirugia: renombrado pcs->ecc. NO se tocan NOC, relojes ni maestros: los
# puertos de ecc_soc_si casan 1:1 con lo que el BD ya cablea para soc_pcs_0
# (s_axi, m_axi->S06_AXI->DDR, irq_out, aclk, aresetn). El wrapper de ECC no
# tiene clk_dp/dp_locked, y el BD del PCS tampoco los cablea (verificado: 0).
# Se auto-verifica: no deben quedar restos de 'pcs'.
# ============================================================================
set -u
cd "$(dirname "$0")"

SRC="${1:-$HOME/vhdl_repo/IP_Cores/PCS_25G/vivado/pcs_soc_bd.tcl}"
OUT="ecc_soc_bd.tcl"

python3 - "$SRC" "$OUT" << 'PYEOF'
import sys
src_path, out_path = sys.argv[1], sys.argv[2]
src = open(src_path).read()
orig_len = len(src)

# --- renombrado global pcs -> ecc (nombres de modulo, instancia y design) ---
src = src.replace("soc_top_pcs_wrap", "soc_top_ecc_wrap")
src = src.replace("soc_pcs_0", "soc_ecc_0")
src = src.replace("pcs_soc_bd", "ecc_soc_bd")

open(out_path, "w").write(src)
print("ecc_soc_bd.tcl generado (%d -> %d bytes)" % (orig_len, len(src)))
PYEOF

echo "--- verificacion de restos de 'pcs' (esperado 0) ---"
n=$(grep -ci "pcs" "$OUT" || true)
echo "  'pcs': $n coincidencias (esperado 0)"

echo "--- referencias nuevas ---"
echo "  soc_ecc_0:          $(grep -c soc_ecc_0 "$OUT")"
echo "  soc_top_ecc_wrap:   $(grep -c soc_top_ecc_wrap "$OUT")"
echo "  design ecc_soc_bd:  $(grep -c 'set design_name ecc_soc_bd' "$OUT")"

echo "--- cableado NoC->DDR preservado (esperado: m_axi a S06_AXI y DDR_LOW) ---"
echo "  soc_ecc_0/m_axi -> S06_AXI: $(grep -c 'soc_ecc_0/m_axi.*S06_AXI\|S06_AXI.*soc_ecc_0/m_axi' "$OUT")"
echo "  S06_AXI/C3_DDR_LOW0:        $(grep -c 'S06_AXI/C3_DDR_LOW0' "$OUT")"
echo "  s_axi @ 0xA4000000:         $(grep -c '0xA4000000' "$OUT")"
