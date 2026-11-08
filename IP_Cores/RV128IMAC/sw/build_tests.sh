#!/bin/bash
# Genera y ensambla las pruebas del RV128IMAC en sw/tests/.
#   SEED  semilla de las dirigidas (1)    RND  numero de programas aleatorios (8)
#   RNDN  instrucciones por programa aleatorio (3000)
set -e
cd $(dirname $0)
OUT=tests
mkdir -p $OUT
python3 gen_isa_tests.py $OUT ${SEED:-1}
for s in $(seq 1 ${RND:-8}); do
  python3 gen_random.py $OUT/rnd_$s.S --seed $s --n ${RNDN:-3000}            # con AMO.Q (lockstep)
  python3 gen_random.py $OUT/rndq_$s.S --seed $((1000 + s)) --n ${RNDN:-3000} --qemu
done
n=0
for f in $OUT/*.S; do
  b=${f%.S}
  python3 ../rv128asm.py $f -o $b.bin --sym $b.sym
  n=$((n + 1))
done
echo "$n programas ensamblados en sw/$OUT"
