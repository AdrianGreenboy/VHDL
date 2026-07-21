#!/bin/bash
# HERCOSSNUX NPU - commit y push del core #17 a los dos remotos.
(
set -e
DIR="$HOME/vhdl_repo"
IP="$DIR/IP_Cores/NPU"

if [ ! -d "$DIR/.git" ]; then
  echo "FALLO: $DIR no es un repositorio git"; exit 1
fi
if [ ! -f "$IP/README.md" ]; then
  echo "FALLO: falta $IP/README.md"; exit 1
fi

cd "$DIR"
echo "Rama actual: $(git rev-parse --abbrev-ref HEAD)"
echo ""
echo "Cambios a incluir:"
git status --short IP_Cores/NPU | head -40
echo ""
n=$(git status --porcelain IP_Cores/NPU | wc -l)
echo "  ($n rutas bajo IP_Cores/NPU)"
echo ""
read -p "Continuar con el commit? [s/N] " r
if [ "$r" != "s" ] && [ "$r" != "S" ]; then
  echo "Cancelado."; exit 0
fi

git add IP_Cores/NPU
if [ -f "$DIR/README.md" ]; then
  git add README.md
fi

git commit -m "NPU: INT8 CNN inference accelerator, silicon validated

Core #17 of the HERCOSSNUX family. 8x8 weight-stationary systolic array
running a LeNet-style network (conv1 -> pool -> conv2 -> pool -> FC ->
argmax) on 16x16 INT8 images, with weights and images fetched from DDR
over AXI4.

Verification: five layers, each closed with a bit-identical signature and
mutation tests that must all fail. The same signature 0x6084FD2A holds
from the Python oracle through every RTL layer, the AXI integration and
the silicon.

Silicon results on Trenz TE0950 (xcve2302):
  50884 LUTs (33.9%), 51 DSP58, 1 BRAM
  WNS +0.515 ns at 87.1 MHz, WHS +0.017 ns, TNS 0
  0.333 ms per inference, ~3000 inferences/s

Documented in the README: the seven-attempt DMA debugging and what broke
the loop, the multiple-driver bug resolving to 'X', the BRAM inference
restructuring, and the Versal platform issues (VHDL-2008 rejected as
module reference top, CIPS automation asking for undocumented keys, and
CH0_DDR4_0_BOARD_INTERFACE as the missing DDR pin binding).

Known limitation: 87.1 MHz instead of 100. Out-of-context synthesis
reported +1.640 ns of slack; after place and route with the NoC and CIPS
the same target closed with +0.0055 ns. Approaches to recover 100 MHz are
listed under Future work."

echo ""
echo "Commit creado:"
git log --oneline -1
echo ""
read -p "Hacer push a origin (GitLab + GitHub)? [s/N] " r2
if [ "$r2" != "s" ] && [ "$r2" != "S" ]; then
  echo "Commit local hecho, sin push."; exit 0
fi
git push origin
echo ""
echo "NPU COMMIT Y PUSH COMPLETADOS"
)
