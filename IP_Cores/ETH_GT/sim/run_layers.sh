#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 21 - ETH GT
# Regresion completa en GHDL (sin Vivado). Cada resultado del VHDL se cruza
# con el oraculo independiente (oracle/eth21_oracle.py, escrito desde IEEE
# 802.3 cl.49 y RFC 791/768):
#   1A generador UDP (5 configuraciones + continuo/STOP) == oraculo byte a byte
#   1B checker UDP con tramas buenas/mutadas/tuser/salto de secuencia
#   1C umbrales del block lock (64 / 15 de 64 / 16 de 64 / slip)
#   1D secuencia de reset del GT (pistas TX/RX independientes)
#   2  TX -> modelo de GT -> RX: 4 ordenes de bits del GT x flags, CRC
#      inyectado, perdida y recuperacion de lock, tramas minimas/maximas;
#      el cable de TX se decodifica con el decodificador IEEE del oraculo
#   3  RX desde un flujo IEEE del oraculo: con los flags correctos decodifica
#      todo; con flags incorrectos NO (prueba negativa: lock sin tramas)
#   4  core completo por AXI4-Lite: reset del GT, lock, rafaga, instantanea,
#      20 contadores, medidor de reloj, monitor AXI
#
#   bash sim/run_layers.sh [workdir]        sale con 1 si algo falla
# =============================================================================
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAC=$(cd "$HERE/../MAC_25G/rtl" && pwd)
PCS=$(cd "$HERE/../PCS_25G/rtl" && pwd)
W=${1:-/tmp/eth21_sim}
rm -rf "$W" && mkdir -p "$W/work" "$W/run"
GF="--std=08 --workdir=$W/work"
O="$HERE/oracle/check_tb.py"

python3 -I "$HERE/oracle/eth21_oracle.py" || exit 1

RTL="$PCS/pcs_scrambler.vhd $MAC/mac25g_crc_pkg.vhd $MAC/mac25g_pkg.vhd \
     $MAC/mac25g_tx.vhd $MAC/mac25g_rx.vhd $MAC/mac25g_pcs66.vhd $MAC/mac25g_sync.vhd \
     $HERE/rtl/eth21_pkg.vhd $HERE/rtl/eth21_udp_gen.vhd $HERE/rtl/eth21_udp_chk.vhd \
     $HERE/rtl/eth21_blocklock.vhd $HERE/rtl/eth21_gtmap.vhd $HERE/rtl/eth21_txpath.vhd \
     $HERE/rtl/eth21_rxpath.vhd $HERE/rtl/eth21_gt_rst.vhd $HERE/rtl/eth21_clkmeter.vhd \
     $HERE/rtl/eth21_top.vhd"
TBS="$HERE/tb/tb_eth21_pkg.vhd $HERE/tb/eth21_gt_model.vhd $HERE/tb/tb_eth21_gen.vhd \
     $HERE/tb/tb_eth21_chk.vhd $HERE/tb/tb_eth21_bl.vhd $HERE/tb/tb_eth21_path.vhd \
     $HERE/tb/tb_eth21_top.vhd $HERE/tb/tb_eth21_gtrst.vhd"
cd "$W/run"        # ghdl -e (mcode) ya abre los archivos de salida de los TB
ghdl -a $GF $RTL $TBS || exit 1
for t in tb_eth21_gen tb_eth21_chk tb_eth21_bl tb_eth21_path tb_eth21_top tb_eth21_gtrst; do
  ghdl -e $GF $t || exit 1
done
cd "$W/run"
PASS=0; FAILS=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1  :: $2"; FAILS=$((FAILS+1)); }

echo "== Capa 1A: generador UDP vs oraculo"
for c in "18 200 37 40 0 1" "18 1472 113 30 0 0" "100 100 0 25 3 1" "5 2000 500 20 0 1" "1472 1472 0 8 0 1" "1472 1472 576 6 0 1" "18 1472 2047 9 0 1" "1 1 1 1 0 0"; do
  set -- $c
  r=$(ghdl -r $GF tb_eth21_gen -gLMIN=$1 -gLMAX=$2 -gLSTEP=$3 -gCOUNT=$4 -gGAP=$5 -gBP=$6 2>&1 | grep -c "LAYER1A GEN frames=$4 PASS")
  o=$(python3 "$O" gen gen_out.txt $1 $2 $3 $4)
  if [ "$r" = 1 ] && echo "$o" | grep -q "GEN OK"; then ok "gen $c  ($o)"; else bad "gen $c" "$o"; fi
done
# IPs que fuerzan acarreos en los dos plegados del checksum IPv4
r=$(ghdl -r $GF tb_eth21_gen -gLMIN=18 -gLMAX=1472 -gLSTEP=331 -gCOUNT=40 -gOWNIP=11111111111111111111111111111111 -gPEERIP=11111111111111110011101011000011 2>&1 | grep -c "frames=40 PASS")
o=$(python3 "$O" gen gen_out.txt 18 1472 331 40 0xFFFFFFFF 0xFFFF3AC3)
if [ "$r" = 1 ] && echo "$o" | grep -q "GEN OK"; then ok "gen IPs 255.255.255.255 -> 255.255.58.195 (acarreo en el 2o plegado del checksum) ($o)"; else bad "gen IPs" "$o"; fi
mg=$(ghdl -r $GF tb_eth21_gen -gLMIN=18 -gLMAX=18 -gLSTEP=0 -gCOUNT=10 -gGAP=9 -gBP=0 2>&1 | grep -oE "mingap=[0-9]+" | cut -d= -f2)
if [ -n "$mg" ] && [ "$mg" -ge 9 ] && [ "$mg" -le 10 ]; then ok "gap 9 -> hueco minimo $mg ciclos"; else bad "gap" "mingap=$mg"; fi
r=$(ghdl -r $GF tb_eth21_gen -gCONT=1 -gSTOPAT=12 -gLSTEP=29 -gGAP=2 2>&1 | grep -c PASS)
n=$(wc -l < gen_out.txt)
o=$(python3 "$O" gen gen_out.txt 18 200 29 $n)
if [ "$r" = 1 ] && [ "$n" -ge 12 ] && [ "$n" -le 13 ] && echo "$o" | grep -q "GEN OK"; then ok "gen continuo+STOP ($n tramas)"; else bad "gen continuo" "$o"; fi

echo "== Capa 1B: checker UDP"
exp=$(python3 "$O" mkchk chk_in.txt | sed 's/CHK_EXPECT //')
for g in 0 1; do
  got=$(ghdl -r $GF tb_eth21_chk -gGAPS=$g 2>&1 | grep -oE "ok=.*")
  if [ "$got" = "$exp" ]; then ok "chk huecos=$g ($got)"; else bad "chk huecos=$g" "$got vs $exp"; fi
done

echo "== Capa 1C: block lock"
if ghdl -r $GF tb_eth21_bl 2>&1 | grep -q "LAYER1C BLOCKLOCK PASS"; then ok "umbrales cl.49"; else bad "block lock" "ver tb_eth21_bl"; fi

echo "== Capa 1D: secuencia de reset del GT"
for sc in 0 1 2 3; do
  d=("arranque normal" "RX sin terminar: TX y PLL intactos" "perdida del PLL: reinicio completo" "sin reloj de usuario TX: RX intacto")
  if ghdl -r $GF tb_eth21_gtrst -gSCN=$sc 2>&1 | grep -q "SCN$sc PASS"; then ok "${d[$sc]}"; else bad "gtrst $sc" "${d[$sc]}"; fi
done

echo "== Capa 2: TX -> GT -> RX (loopback) + decodificador IEEE del cable"
pr() { ghdl -r $GF tb_eth21_path "$@" 2>&1 | grep -oE "txf=.*|LAYER2 FAIL.*"; }
X=$(python3 "$O" pathexp 18 400 53 24 0 0)
for gr in false true; do for gs in false true; do
  cr=0; cs=0; [ $gr = true ] && cr=1; [ $gs = true ] && cs=1
  off=$(( (cr*2+cs)*17 + 5 ))
  got=$(pr -gGT_REV=$gr -gGT_SWAP=$gs -gC_REV=$cr -gC_SWAP=$cs -gOFF0=$off -gDUMPF=wire.txt)
  w=$(python3 "$O" wire wire.txt 18 400 53 24 2>&1 | tail -1)
  # el cable solo es IEEE con el orden por defecto (GT LSB primero, flags 0)
  if [ "$gr$gs" = "falsefalse" ]; then wexp="WIRE OK"; else wexp=""; fi
  if [ "$got" = "$X" ] && { [ -z "$wexp" ] || echo "$w" | grep -q "$wexp"; }; then
    ok "loopback gt=$gr/$gs off=$off ${wexp:+($w)}"
  else bad "loopback gt=$gr/$gs" "$got | $w"; fi
done; done
got=$(pr -gGT_REV=true -gC_REV=0 -gOFF0=3)
[ "$got" = "$X" ] && ok "loopback con flags distintos del GT (consistentes)" || bad "loopback flags" "$got"
X2=$(python3 "$O" pathexp 18 1472 211 30 1 0)
got=$(pr -gLMAX=1472 -gLSTEP=211 -gN=30 -gINJ=1)
[ "$got" = "$X2" ] && ok "CRC inyectado (1 trama mala, resto bien)" || bad "inyeccion" "$got"
got=$(pr -gBURSTERR=1 -gOFF0=60)
[ "$got" = "$X" ] && ok "perdida de lock por 20 cabeceras malas + relock + rafaga" || bad "burst err" "$got"
X4=$(python3 "$O" pathexp 18 18 0 60 0 0)
got=$(pr -gLMAX=18 -gLSTEP=0 -gN=60 -gDUMPF=wire.txt)
w=$(python3 "$O" wire wire.txt 18 18 0 60 | tail -1)
[ "$got" = "$X4" ] && echo "$w" | grep -q "WIRE OK" && ok "60 tramas minimas (60 B) a tasa de linea ($w)" || bad "minimas" "$got | $w"
X5=$(python3 "$O" pathexp 1472 1472 0 10 0 0)
got=$(pr -gLMIN=1472 -gLMAX=1472 -gLSTEP=0 -gN=10 -gGAP=7)
[ "$got" = "$X5" ] && ok "10 tramas maximas (1514 B) con gap" || bad "maximas" "$got"

echo "== Capa 3: RX desde un flujo IEEE del oraculo"
python3 "$O" mkwire rx_in.txt 18 1472 97 40 7 > mk.txt
X=$(python3 "$O" pathexp 18 1472 97 40 0 1)
for c in "false false 0 0" "false true 0 1" "true false 1 0" "true true 1 1"; do set -- $c
  got=$(pr -gINF=rx_in.txt -gGT_REV=$1 -gGT_SWAP=$2 -gC_REV=$3 -gC_SWAP=$4)
  [ "$got" = "$X" ] && ok "gt=$1/$2 flags=$3/$4: 40/40 tramas" || bad "rx gt=$1/$2" "$got"
done
for c in "true false 0 0" "false true 0 0" "true true 0 1"; do set -- $c
  got=$(pr -gINF=rx_in.txt -gGT_REV=$1 -gGT_SWAP=$2 -gC_REV=$3 -gC_SWAP=$4)
  if echo "$got" | grep -q "rxok=0 .*lock='1'" && ! echo "$got" | grep -q "proto=0 "; then
    ok "negativa gt=$1/$2 flags=$3/$4: lock pero 0 tramas y RX_PROTO>0 (firma de autodeteccion)"
  else bad "negativa gt=$1/$2" "$got"; fi
done

python3 "$O" mkfault fault_in.txt 8000 3000 2000
os=$(ghdl -r $GF tb_eth21_path -gINF=fault_in.txt 2>&1 | grep -oE "idle=.*")
idle=$(echo "$os" | sed -E 's/idle=([0-9]+).*/\1/')
if echo "$os" | grep -q "lf=3000 rf=2000" && [ "$idle" -gt 5000 ]; then
  ok "ordered sets Local/Remote Fault (0x4B/0x2D/0x55) contados (diagnostico del enlace con el PC): $os"
else bad "fault" "$os"; fi

python3 -c "
import random; r=random.Random(5)
with open('nolock_in.txt','w') as f:
    for i in range(30000):
        b=[r.getrandbits(1) for _ in range(64)]
        f.write('00'+''.join(map(str,b))+'\\n')"
nl=$(ghdl -r $GF tb_eth21_path -gINF=nolock_in.txt 2>&1 | grep -oE "NOLOCK.*")
if echo "$nl" | grep -q "blocks=0 proto=0 rxok=0" && ! echo "$nl" | grep -q "slips=0$"; then
  ok "sin cabeceras validas: nunca lock, el MAC no ve ningun bloque ($nl)"
else bad "nolock" "$nl"; fi

echo "== Capa 4: core completo por AXI4-Lite"
X=$(python3 "$O" pathexp 18 1472 131 20 0 0)
out=$(ghdl -r $GF tb_eth21_top 2>&1)
got=$(echo "$out" | grep -oE "txf=.*")
if [ "$got" = "$X" ] && echo "$out" | grep -q "LAYER4 checks PASS"; then ok "rafaga por registros, flags 1/0"; else bad "top" "$got"; fi
X=$(python3 "$O" pathexp 18 1472 97 15 1 0)
out=$(ghdl -r $GF tb_eth21_top -gINJ=1 -gCREV=0 -gCSWAP=1 -gN=15 -gLSTEP=97 2>&1)
got=$(echo "$out" | grep -oE "txf=.*")
if [ "$got" = "$X" ] && echo "$out" | grep -q "LAYER4 checks PASS"; then ok "rafaga con CRC inyectado, flags 0/1"; else bad "top inj" "$got"; fi

echo
echo "RESULTADO: $PASS PASS, $FAILS FAIL"
[ $FAILS -eq 0 ]
