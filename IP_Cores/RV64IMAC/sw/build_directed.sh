#!/bin/bash
# Compila los tests dirigidos (entorno p de riscv-tests para el link.ld).
set -e
cd "$(dirname "$0")"
RT=$(realpath "${1:?uso: build_directed.sh <ruta a riscv-tests>}")
CC="clang --target=riscv64-unknown-elf -march=rv64imac_zicsr_zifencei -mabi=lp64 -mcmodel=medany -mno-relax -nostdlib -static -fuse-ld=lld -T$RT/env/p/link.ld"
python3 gen_csr_sweep.py csr_sweep.S
python3 gen_csr_sweep.py csr_sweep_spike.S --spike
python3 gen_mmu_test.py mmu_test.S
python3 gen_cache_stress.py cache_stress.S
for t in csr_sweep csr_sweep_spike irq_storm irq_m irq_race mmu_test cache_stress soc_usart soc_timer soc_plic amo_lanes; do $CC $t.S -o $t; done
for t in cbo_test soc_dma; do ${CC/rv64imac_zicsr_zifencei/rv64imac_zicsr_zifencei_zicbom} $t.S -o $t; done
