#!/bin/bash
# run_regression.sh - GHDL regression of the ECC scrubber core (all sim layers
# + audit 2026-11 benches). Build products go to $ECC_SIM_DIR (default under
# /tmp), never into the source tree. Exit code 0 = all PASS.
set -u
E="$(cd "$(dirname "$0")" && pwd)"
W="${ECC_SIM_DIR:-${TMPDIR:-/tmp}/ecc_sim_$(id -un)}"
ASM="${ASM_PY:-$E/../ADCS/fw/asm.py}"
mkdir -p "$W"; cd "$W"
cp "$E"/*.txt .
FAIL=0
for s in ecc_fw smoke_si ecc_fw_selfcheck; do
  python3 "$ASM" "$E/$s.s" "$s.mem" >/dev/null || { echo "ASM FAIL $s"; FAIL=1; }
done
(cd "$E" && python3 -B test_mmio_oracle.py) || FAIL=1

SRC="ecc_pkg riscv_pkg ecc_codec scrub_bram scrub_fsm ecc_regbank ecc_codec_mmio
     ecc_regbank_si alu control csr immgen muldiv regfile cpu_pipeline dp_ram
     dma_burst mem_subsys_dma axil_soc ecc_soc_top ecc_soc_si
     tb_layer1 tb_layer2 tb_layer3 tb_layer4 tb_layer4_b tb_codec_mmio tb_si_scrub
     tb_smoke_si tb_selfcheck_si tb_ecc_audit tb_dma_audit"
for f in $SRC; do
  ghdl -a --std=08 "$E/$f.vhd" 2>&1 | grep -i error && FAIL=1
done

# name:stop-time:PASS-pattern[:generic]
TESTS="tb_layer1:3ms:LAYER1 CODEC PASS
tb_layer2:50us:LAYER2 SCRUB PASS
tb_layer3:100us:LAYER3 MMIO PASS
tb_layer4:2ms:LAYER4 RUN A PASS
tb_layer4_b:2ms:LAYER4 RUN B PASS
tb_codec_mmio:3ms:CODEC_MMIO PASS
tb_si_scrub:200us:SILICON SCRUB MMIO PASS
tb_smoke_si:2ms:smoke_si fin: irq='1'
tb_selfcheck_si:2ms:selfcheck fin: irq='1'
tb_ecc_audit:1ms:TB_ECC_AUDIT PASS (SI=false)
tb_ecc_audit:1ms:TB_ECC_AUDIT PASS (SI=true):-gSI=true
tb_dma_audit:1ms:TB_DMA_AUDIT PASS"
while IFS= read -r line; do
  n=${line%%:*}; rest=${line#*:}; st=${rest%%:*}; rest=${rest#*:}
  pat=${rest%%:-g*}; gen=""; [ "$pat" != "$rest" ] && gen="-g${rest#*:-g}"
  ghdl -e --std=08 "$n" >/dev/null 2>&1
  out=$(ghdl -r --std=08 "$n" $gen --stop-time="$st" 2>&1)
  if echo "$out" | grep -qF "$pat" && ! echo "$out" | grep -q "assertion failure"; then
    echo "PASS  $n $gen"
  else
    echo "FAIL  $n $gen"; echo "$out" | tail -5; FAIL=1
  fi
done <<< "$TESTS"
echo "=================================================="
[ $FAIL -eq 0 ] && echo "ECC REGRESSION: ALL PASS" || echo "ECC REGRESSION: FAILURES"
exit $FAIL
