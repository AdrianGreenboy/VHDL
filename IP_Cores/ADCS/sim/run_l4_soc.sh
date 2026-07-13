#!/bin/bash
# ============================================================================
# run_l4_soc.sh — Capa 4 del IP ADCS: SoC RV32IM real ejecuta adcs_test.mem,
# gobierna el IP ADCS (region 0xA), vuelca firma+doorbell a la DDR.
# PASS: sentinela 0xD1A6 + firma == oraculo del solver (0x0C4CCCD2) en DDR,
# disparados por el doorbell del firmware.
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
SOC=../soc
FW=../fw
MODEL=../model
WORK=work_l4
mkdir -p $WORK

echo "== Ensamblando firmware con asm.py =="
python3 $FW/asm.py $FW/adcs_test.s $WORK/adcs_test.mem | tail -1

echo "== Generando DDR init (H,g) y firma esperada =="
python3 - <<'PYEOF'
import sys, random
sys.path.insert(0, '../model')
from mpc_oracle import solve_mpc, f2b
rng = random.Random(0x39C)
def rand_fp(rng, lo, hi):
    return (rng.getrandbits(1)<<31)|(rng.randrange(lo,hi)<<23)|rng.getrandbits(23)
for (n,mi) in [(4,1),(4,2)]:
    _=[[rand_fp(rng,118,130) for _ in range(n)] for _ in range(n)]
    _=[rand_fp(rng,118,130) for _ in range(n)]
n,mi=8,2
H=[[rand_fp(rng,118,130) for _ in range(n)] for _ in range(n)]
g=[rand_fp(rng,118,130) for _ in range(n)]
step=f2b(0.881230); umax=f2b(0.05)
U=solve_mpc(H,g,n,mi,step,umax)
sig=0
for i in range(5):
    sig=((sig<<1)|(sig>>31))&0xFFFFFFFF; sig^=U[i]
DEPTH=16384; DP=72
mem=[0]*DEPTH
for i in range(n):
    for j in range(n): mem[i*DP+j]=H[i][j]
GB=0x2000//4
for i in range(n): mem[GB+i]=g[i]
with open('work_l4/adcs_ddr_init.mem','w') as f:
    for w in mem: f.write(f"{w:08X}\n")
print(f"FIRMA_ESPERADA=0x{sig:08X}")
PYEOF
SIG=$(python3 - <<'PYEOF'
import sys, random
sys.path.insert(0, '../model')
from mpc_oracle import solve_mpc, f2b
rng = random.Random(0x39C)
def rf(rng,lo,hi): return (rng.getrandbits(1)<<31)|(rng.randrange(lo,hi)<<23)|rng.getrandbits(23)
for (n,mi) in [(4,1),(4,2)]:
    _=[[rf(rng,118,130) for _ in range(n)] for _ in range(n)]; _=[rf(rng,118,130) for _ in range(n)]
n,mi=8,2
H=[[rf(rng,118,130) for _ in range(n)] for _ in range(n)]; g=[rf(rng,118,130) for _ in range(n)]
U=solve_mpc(H,g,n,mi,f2b(0.881230),f2b(0.05))
sig=0
for i in range(5): sig=((sig<<1)|(sig>>31))&0xFFFFFFFF; sig^=U[i]
print(f"{sig:08X}")
PYEOF
)
echo "firma esperada: 0x$SIG"

echo "== Analisis GHDL (SoC completo) =="
ghdl -a --std=08 --workdir=$WORK \
    $RTL/riscv_pkg.vhd \
    $SOC/alu.vhd $SOC/control.vhd $SOC/immgen.vhd $SOC/regfile.vhd \
    $SOC/csr.vhd $SOC/muldiv.vhd $SOC/cpu_pipeline.vhd \
    $SOC/dp_ram.vhd $SOC/axi4_master.vhd $SOC/dma_burst.vhd $SOC/axil_soc.vhd \
    $RTL/fp32_pkg.vhd $RTL/fp32_fma.vhd $RTL/adcs_pkg.vhd \
    $RTL/mpc_dot_row.vhd $RTL/mpc_dot_x8.vhd $RTL/adcs_mem_banks.vhd \
    $RTL/mpc_engine.vhd $RTL/adcs_regfile.vhd $RTL/axi_dma_engine.vhd \
    $RTL/adcs_accel_top.vhd $RTL/mem_subsys_dma_adcs.vhd \
    ../rtl/soc_top_master_adcs.vhd ddr_sim_2p.vhd tb_adcs_soc.vhd 2>&1 | grep -v '^$' || true
ghdl -e --std=08 --workdir=$WORK tb_adcs_soc || exit 1

echo "== Simulacion (core ejecuta el firmware) =="
(cd $WORK && cp ../../fw/adcs_test.mem . 2>/dev/null; \
 ghdl -r --std=08 --workdir=. tb_adcs_soc \
   -gFW_FILE=adcs_test.mem -gDDR_INIT=adcs_ddr_init.mem \
   -gEXP_SIG=$SIG --stop-time=50ms) > $WORK/run.log 2>&1
grep -E 'cargadas|arrancado|doorbell|PASS|FAIL|CAPA 4|TIMEOUT|error' $WORK/run.log | head -20

echo "=================================================="
if grep -q 'CAPA 4 ADCS SOC: PASS' $WORK/run.log; then
    echo "CAPA 4: PASS"
    exit 0
else
    echo "CAPA 4: FALLO"
    exit 1
fi
