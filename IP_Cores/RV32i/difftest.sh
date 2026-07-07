#!/usr/bin/env bash
# =============================================================================
#  difftest.sh  -  Differential testing: modelo de oro (Python) vs core (xsim)
#  Licencia: MIT
#
#  Uso (desde la carpeta con todos los .vhd y .py):
#     source ~/Xilinx/2025.2.1/Vivado/settings64.sh
#     ./difftest.sh [n_iteraciones] [n_instrucciones]
#
#  Genera N programas aleatorios, los corre en el core con pipeline y compara
#  el estado final de registros contra el modelo de referencia. Para en el
#  primer fallo dejando program.mem / expected.txt / actual.txt para depurar.
# =============================================================================
set -e
ITERS=${1:-30}
INSTRS=${2:-48}

echo "Compilando RTL..."
xvhdl -2008 riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
            csr.vhd imem.vhd dmem.vhd cpu_pipeline.vhd tb_difftest.vhd > /dev/null

pass=0
for seed in $(seq 1 "$ITERS"); do
  python3 difftest_gen.py "$seed" "$INSTRS" program_dt.mem expected.txt > /dev/null
  # re-elabora para que imem lea el nuevo program_dt.mem
  xelab -debug typical tb_difftest -s dt_sim > /dev/null 2>&1
  xsim dt_sim -runall > /dev/null 2>&1
  if python3 difftest_cmp.py expected.txt actual.txt "$seed"; then
    pass=$((pass+1))
    printf "  seed %-4s PASS\n" "$seed"
  else
    echo "  seed $seed FAIL  (revisa program.mem / expected.txt / actual.txt)"
    exit 1
  fi
done

echo "============================================================"
echo "  $pass / $ITERS PROGRAMAS ALEATORIOS PASARON"
echo "============================================================"
