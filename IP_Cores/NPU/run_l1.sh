#!/bin/bash
# HERCOSSNUX NPU - Layer 1: base PASS + todas las mutaciones FAIL
(
set -e
cd "$(dirname "$0")"
rm -rf build && mkdir -p build
ghdl -a --std=08 --workdir=build \
  rtl/npu_pkg.vhd rtl/npu_mac.vhd rtl/npu_requant.vhd rtl/npu_pool.vhd \
  tb/tb_npu_mac.vhd tb/tb_npu_requant.vhd tb/tb_npu_pool.vhd tb/tb_npu_latency.vhd

fail=0
check_pass () { # $1 entidad  $2 etiqueta
  out=$(ghdl -r --std=08 --workdir=build "$1" 2>&1)
  if echo "$out" | grep -q "$2 PASS"; then
    echo "$out" | grep -o "$2 PASS.*"
  else
    echo "FALLO base $1: $out"; fail=1
  fi
}
check_mut () { # $1 entidad  $2 etiqueta  $3 mut
  out=$(ghdl -r --std=08 --workdir=build "$1" -gG_MUT="$3" 2>&1)
  if echo "$out" | grep -q "$2 FAIL"; then
    return 0
  else
    echo "FALLO: mutacion $3 de $1 NO fallo"; fail=1
  fi
}

check_pass tb_npu_mac      TB_MAC
check_pass tb_npu_requant  TB_REQUANT
check_pass tb_npu_pool     TB_POOL
check_pass tb_npu_latency  TB_LATENCY

nm=0
for m in 1 2 3;     do check_mut tb_npu_mac     TB_MAC     $m && nm=$((nm+1)); done
for m in 3 4 5 6;   do check_mut tb_npu_requant TB_REQUANT $m && nm=$((nm+1)); done
for m in 1 2 3 4;   do check_mut tb_npu_pool    TB_POOL    $m && nm=$((nm+1)); done

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO2 OK L1 4/4 PASS MUTACIONES $nm/11 FAIL"
)
