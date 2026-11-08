#!/bin/bash
# ============================================================================
# run_adc_regress.sh (AUDIT 2026-11) -- ADC regression on the REPO sources.
# The historical adc_pasoN_*.sh scripts regenerate the RTL/models from
# heredocs (snapshot of the original v1). This runner executes the same five
# flows (oracles, testbenches, mutation batteries) but with every heredoc that
# writes a file present in this directory SKIPPED, so the files under test are
# the current repo versions. Then it runs the AUDIT 2026-11 testbenches
# (tb_adc_audit: pdm_clk capture, FIFO overflow sticky/IRQ, DMA/MMIO grant,
# pop once per transaction). Everything runs in a temp HOME; the repo is not
# modified. Usage: bash run_adc_regress.sh
# ============================================================================
set -u
ADC=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d /tmp/adc_regress.XXXXXX)
mkdir -p "$T/adc_ip" "$T/vhdl_repo/IP_Cores"
ln -s "$(cd "$ADC/../RV32i" && pwd)" "$T/vhdl_repo/IP_Cores/RV32i"
cp "$ADC"/*.vhd "$ADC"/*.py "$ADC"/*.s "$T/adc_ip/"
for n in 1_pdmgen 2_cic 3_core 4_mmio 5_soc; do
  python3 - "$ADC/adc_paso$n.sh" "$T/paso$n.sh" "$ADC" <<'PY'
import sys, os, re
src, dst, adc = sys.argv[1], sys.argv[2], sys.argv[3]
repo = set(os.listdir(adc))
out, skip = [], None
for line in open(src):
    if skip:
        if line.rstrip('\n') == skip:
            skip = None
        continue
    m = re.match(r"^cat > (\S+) << '(\w+)'\s*$", line)
    if m and m.group(1) in repo:
        skip = m.group(2)
        out.append("# (run_adc_regress) using repo %s\n" % m.group(1))
        continue
    out.append(line)
open(dst, 'w').writelines(out)
PY
  echo "##### paso$n (repo sources)"
  HOME="$T" bash "$T/paso$n.sh" 2>&1 | tail -1
done
echo "##### AUDIT 2026-11 testbench (tb_adc_audit)"
( cd "$T/adc_ip" && mkdir -p ba && cd ba &&
  ghdl -a --std=08 --workdir=. ../adc_sin_lut_pkg.vhd ../adc_pdmgen.vhd ../adc_cic.vhd \
     ../adc_core.vhd ../adc_fifo.vhd ../adc_regs.vhd ../adc_mmio.vhd "$ADC/tb_adc_audit.vhd" &&
  ghdl -e --std=08 --workdir=. tb_adc_audit &&
  timeout 900 ghdl -r --std=08 --workdir=. tb_adc_audit --stop-time=100ms 2>&1 | grep -E "ADC AUDIT|FALLO" | head -5 )
echo ">> temp dir $T"
