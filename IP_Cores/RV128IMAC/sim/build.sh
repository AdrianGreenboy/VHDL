#!/bin/bash
# Compila RTL + testbenches del RV128IMAC con GHDL (backend LLVM o GCC).
set -e
cd $(dirname $0)
pick() {
  for g in ${GHDL:-} ghdl-llvm ghdl-gcc; do
    command -v $g > /dev/null || continue
    d=$(mktemp -d); echo "entity t is end;" > $d/t.vhd
    if (cd $d && $g -a --std=08 t.vhd) > /dev/null 2>&1; then echo $g; return; fi
    echo "aviso: $g no funciona, pruebo el siguiente" >&2
  done
}
G=$(pick)
[ -n "$G" ] || { echo "no hay GHDL con backend llvm o gcc (sudo apt install ghdl-gcc)" >&2; exit 1; }
echo "GHDL: $G" >&2
R=../rtl
$G -a --std=08 $R/rv128_pkg.vhd $R/rv128_mmu_pkg.vhd $R/rv128_tlb.vhd $R/rv128_ptw.vhd $R/rv128_muldiv.vhd $R/rv128_csr.vhd $R/rv128_core.vhd ../fpga/rv128_proto_top.vhd
$G -a --std=08 ../tb/tb_rvc.vhd ../tb/tb_muldiv.vhd ../tb/tb_core.vhd ../tb/tb_proto.vhd
for t in tb_rvc tb_muldiv tb_core tb_proto; do $G -e --std=08 $t; done
