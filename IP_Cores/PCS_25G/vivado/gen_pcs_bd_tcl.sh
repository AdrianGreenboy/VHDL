#!/bin/bash
# ============================================================================
# Core 19 - genera vivado/pcs_soc_bd.tcl desde vivado/mipi_soc_bd_base.tcl
# Cirugia: renombrado mipi->pcs, NOC de 8 a 7 SIs/relojes (fuera S07/aclk7),
# fuera el maestro mipi_axi (connect + direcciones).
# Se auto-verifica: no deben quedar restos de mipi/S07/aclk7.
# ============================================================================
set -u
cd "$(dirname "$0")"

python3 - << 'PYEOF'
src = open('mipi_soc_bd_base.tcl').read()
orig_len = len(src)

# --- 1. eliminar lineas del maestro mipi_axi (connect + 2 direcciones) ---
lines = src.split('\n')
lines = [l for l in lines if 'mipi_axi' not in l]
src = '\n'.join(lines)

# --- 2. bloque de propiedades de S07_AXI (identico a S06 salvo el pin) ---
blk_s07 = """  set_property -dict [ list \\
   CONFIG.CONNECTIONS {MC_3 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}} \\
   CONFIG.NOC_PARAMS {} \\
   CONFIG.CATEGORY {pl} \\
 ] [get_bd_intf_pins $axi_noc_0/S07_AXI]
"""
assert src.count(blk_s07) == 1, "bloque S07 no encontrado o multiple"
src = src.replace(blk_s07, "")

# --- 3. aclk6 asociado solo a S06 ---
assert src.count("CONFIG.ASSOCIATED_BUSIF {S06_AXI:S07_AXI}") == 1
src = src.replace("CONFIG.ASSOCIATED_BUSIF {S06_AXI:S07_AXI}",
                  "CONFIG.ASSOCIATED_BUSIF {S06_AXI}")

# --- 4. bloque de propiedades de aclk7 (ASSOCIATED_BUSIF vacio) ---
blk_a7 = """  set_property -dict [ list \\
   CONFIG.ASSOCIATED_BUSIF {} \\
 ] [get_bd_pins $axi_noc_0/aclk7]
"""
assert src.count(blk_a7) == 1, "bloque aclk7 no encontrado"
src = src.replace(blk_a7, "")

# --- 5. quitar aclk7 de la red de pl0_ref_clk (y el backslash de aclk6) ---
old_net = """  [get_bd_pins axi_noc_0/aclk6] \\
  [get_bd_pins axi_noc_0/aclk7]"""
assert src.count(old_net) == 1, "red aclk6/aclk7 no encontrada"
src = src.replace(old_net, "  [get_bd_pins axi_noc_0/aclk6]")

# --- 6. NOC: 7 SIs y 7 relojes ---
assert src.count("CONFIG.NUM_SI {8}") == 1
src = src.replace("CONFIG.NUM_SI {8}", "CONFIG.NUM_SI {7}")
assert src.count("CONFIG.NUM_CLKS {8}") == 1
src = src.replace("CONFIG.NUM_CLKS {8}", "CONFIG.NUM_CLKS {7}")

# --- 7. renombrado global ---
src = src.replace("soc_top_mipi_wrap", "soc_top_pcs_wrap")
src = src.replace("soc_mipi_0", "soc_pcs_0")
src = src.replace("mipi_soc_bd", "pcs_soc_bd")

open('pcs_soc_bd.tcl', 'w').write(src)
print("pcs_soc_bd.tcl generado (%d -> %d bytes)" % (orig_len, len(src)))
PYEOF

echo "--- verificacion de restos ---"
for pat in mipi S07 aclk7; do
  n=$(grep -ci "$pat" pcs_soc_bd.tcl || true)
  echo "  '$pat': $n coincidencias (esperado 0)"
done
echo "--- referencias nuevas ---"
echo "  soc_pcs_0: $(grep -c soc_pcs_0 pcs_soc_bd.tcl)"
echo "  soc_top_pcs_wrap: $(grep -c soc_top_pcs_wrap pcs_soc_bd.tcl)"
echo "  design pcs_soc_bd: $(grep -c 'set design_name pcs_soc_bd' pcs_soc_bd.tcl)"
