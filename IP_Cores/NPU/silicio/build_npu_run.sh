#!/bin/bash
# HERCOSSNUX NPU - genera binarios y compila el bring-up para la placa.
(
set -e
cd "$(dirname "$0")/.."

echo "[1/2] generando binarios de pesos e imagenes..."
python3 silicio/gen_bin.py oracle/oracle_npu.py model/npu_weights.hex \
        model/npu_golden.txt silicio/pesos.bin silicio/imgs.bin 8

echo "[2/2] compilando npu_run para aarch64..."
if ! command -v aarch64-linux-gnu-gcc > /dev/null 2>&1; then
  echo "FALLO: falta aarch64-linux-gnu-gcc"
  echo "  sudo apt install gcc-aarch64-linux-gnu"
  exit 1
fi
aarch64-linux-gnu-gcc -O2 -static -Wall -o silicio/npu_run silicio/npu_run.c
file silicio/npu_run | head -1

echo ""
echo "NPU BRING-UP LISTO"
echo "Copiar a la placa:"
echo "  silicio/npu_run"
echo "  silicio/pesos.bin"
echo "  silicio/imgs.bin"
echo ""
echo "Ejecutar como root en la placa:"
echo "  ./npu_run pesos.bin imgs.bin 8"
echo ""
echo "Linea esperada:"
echo "  NPU SILICIO OK SIG_CLASE=0x6084FD2A"
)
