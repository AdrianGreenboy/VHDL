#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Regresion completa en GHDL (sin Vivado):
#   1A paquete (CRC, xorshift, constantes)       1B PCS TX a tasa de linea
#   1C sincronizador de eventos dp->AXI
#   2A MAC TX (3 vectores x 2 patrones de ce)    2B MAC RX (casos de error)
#   2C checker (tramas fabricadas)
#   3  datapath completo por el PCS (4 rafagas)
#   4  core por registros: AXI4-Lite directo y via pcs_mmio_bridge
#   5  SoC: firmware RV32 real (fw/fw_rv32_sim.mem) en el RV32 real del repo
# Cada firma impresa por GHDL se cruza con la del oraculo Python.
#
#   bash sim/run_layers.sh [workdir]
# Requiere: ghdl (>= 4, --std=08), python3. Si hay riscv64-unknown-elf-gcc
# se recompila el firmware; si no, se usa el fw/fw_rv32_sim.mem del repo.
# Sale con 1 si algo falla.
# =============================================================================
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
PCS=$(cd "$HERE/../PCS_25G/rtl" && pwd)
RV=$(cd "$HERE/../RV32i" && pwd)
W=${1:-/tmp/mac25g_sim}
rm -rf "$W" && mkdir -p "$W/work" "$W/vec"
G="ghdl"
GF="--std=08 --workdir=$W/work"

python3 -I "$HERE/oracle/mac25g_oracle.py" || exit 1
python3 -I "$HERE/oracle/gen_vectors.py" "$W/vec" > "$W/oracle_sigs.txt" || exit 1
python3 -I "$HERE/oracle/expected_l5.py" 64 "$W/vec/l5_expected.txt" > /dev/null || exit 1
if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
  bash "$HERE/fw/build_fw_rv32.sh" > /dev/null || exit 1
fi
cp "$HERE/fw/fw_rv32_sim.mem" "$W/vec/" || exit 1

RVS="$RV/riscv_pkg.vhd $RV/alu.vhd $RV/immgen.vhd $RV/regfile.vhd $RV/control.vhd \
     $RV/muldiv.vhd $RV/csr.vhd $RV/clint.vhd $RV/cpu_pipeline.vhd $RV/dp_ram.vhd \
     $RV/axi4_master.vhd $RV/dma_burst.vhd $RV/mem_subsys_dma.vhd $RV/axil_soc.vhd \
     $RV/axi_ddr_sim.vhd"
RTL="$PCS/pcs_scrambler.vhd $PCS/pcs_gearbox_tx.vhd $PCS/pcs_gearbox_rx.vhd \
     $PCS/pcs_tx_datapath.vhd $PCS/pcs_rx_datapath.vhd $PCS/pcs_mmio_bridge.vhd \
     $HERE/rtl/mac25g_crc_pkg.vhd $HERE/rtl/mac25g_pkg.vhd $HERE/rtl/mac25g_pcs_tx.vhd $HERE/rtl/mac25g_gen.vhd \
     $HERE/rtl/mac25g_tx.vhd $HERE/rtl/mac25g_rx.vhd $HERE/rtl/mac25g_chk.vhd $HERE/rtl/mac25g_pcs66.vhd \
     $HERE/rtl/mac25g_datapath.vhd $HERE/rtl/mac25g_sync.vhd \
     $HERE/rtl/mac25g_top.vhd $HERE/rtl/soc_top_mac.vhd"
TBS="$HERE/tb/tb_mac_pkg.vhd $HERE/tb/tb_mac_pcs_tx.vhd $HERE/tb/tb_mac_tx.vhd \
     $HERE/tb/tb_mac_rx.vhd $HERE/tb/tb_mac_chk.vhd $HERE/tb/tb_mac_datapath.vhd \
     $HERE/tb/tb_mac_top.vhd $HERE/tb/tb_soc_mac.vhd $HERE/tb/tb_mac_sync.vhd"
$G -a $GF $RVS $RTL $TBS || exit 1
for t in tb_mac_pkg tb_mac_pcs_tx tb_mac_tx tb_mac_rx tb_mac_chk tb_mac_datapath \
         tb_mac_top tb_soc_mac tb_mac_sync; do
  $G -e $GF $t || exit 1
done

FAILS=0
sig() { grep -oE "FNV32_$1=0x[0-9A-F]{8}" "$W/oracle_sigs.txt" | cut -d= -f2; }
run() {   # run <etiqueta> <patron PASS> <firma esperada o -> <tb> [generics...]
  local tag=$1 pat=$2 exp=$3; shift 3
  local out
  out=$(cd "$W/vec" && $G -r $GF "$@" 2>&1 | grep -E "LAYER|MISMATCH|FAIL|failure" | head -5)
  local got
  got=$(echo "$out" | grep -oE "$pat FNV32=0x[0-9A-F]{8}" | grep -oE "0x[0-9A-F]{8}")
  if echo "$out" | grep -q "$pat" && { [ "$exp" = "-" ] || [ "$got" = "$exp" ]; }; then
    printf "  PASS  %-34s %s\n" "$tag" "${got:-}"
  else
    printf "  FAIL  %-34s (esperado %s)\n%s\n" "$tag" "$exp" "$out"
    FAILS=$((FAILS+1))
  fi
}

echo "== Core 20 MAC 25G: capas 1-5 =="
run "L1A paquete"            LAYER1A_PASS "$(sig L1)"  tb_mac_pkg
run "L1B PCS TX tasa linea"  LAYER1B_PASS -            tb_mac_pcs_tx
run "L1C evsync dp->AXI"     LAYER1C_PASS -            tb_mac_sync
for m in 0 1; do
  run "L2A TX txa ce=$m"     LAYER2A_PASS "$(sig TXA)" tb_mac_tx -gCE_MODE=$m
  run "L2A TX txb ce=$m"     LAYER2A_PASS "$(sig TXB)" tb_mac_tx -gCE_MODE=$m \
      -gVEC=tx_txb.txt -gLEN_MIN=20 -gLEN_MAX=90 -gSTEP=1 -gNFR=71
  run "L2A TX txc(inj) ce=$m" LAYER2A_PASS "$(sig TXC)" tb_mac_tx -gCE_MODE=$m \
      -gVEC=tx_txc.txt -gNFR=16 -gINJ=true
done
run "L2B RX errores"         LAYER2B_PASS "$(sig RX)"  tb_mac_rx
run "L2C checker"            LAYER2C_PASS "$(sig CHK)" tb_mac_chk
run "L3 rafaga limpia"       LAYER3_PASS  "$(sig L3A)" tb_mac_datapath
run "L3 inyeccion 1 bit"     LAYER3_PASS  "$(sig L3B)" tb_mac_datapath -gVEC=l3_l3b.txt -gINJ=true
run "L3 barrido fino/pad"    LAYER3_PASS  "$(sig L3C)" tb_mac_datapath -gVEC=l3_l3c.txt \
    -gLEN_MIN=20 -gLEN_MAX=90 -gSTEP=1 -gNFR=71
run "L3 oversize"            LAYER3_PASS  "$(sig L3D)" tb_mac_datapath -gVEC=l3_l3d.txt \
    -gLEN_MIN=1400 -gLEN_MAX=1700 -gSTEP=23 -gNFR=24
run "L3 GEN_STOP + rafaga"    LAYER3_PASS  "$(sig L3A)" tb_mac_datapath -gSTOP_TEST=true
run "L3 gearbox Core19 limpia" LAYER3_PASS "$(sig L3A)" tb_mac_datapath -gGEARBOX=true
run "L3 gearbox Core19 inyec."  LAYER3_PASS "$(sig L3B)" tb_mac_datapath -gGEARBOX=true \
    -gVEC=l3_l3b.txt -gINJ=true
run "L4 registros AXI4-Lite"  LAYER4_PASS -              tb_mac_top
run "L4 registros via MMIO"   LAYER4MMIO_PASS -          tb_mac_top -gBRIDGE=true
run "L5 SoC + firmware RV32"  LAYER5SIM_PASS -           tb_soc_mac

if [ $FAILS -eq 0 ]; then echo "== TODAS LAS CAPAS 1-5 PASAN =="; exit 0
else echo "== $FAILS FALLOS =="; exit 1; fi
