#!/bin/sh
# run_all.sh - en la TE0950 (PetaLinux, root): corre todo lo de list.txt con rv128_soc_load.
#   sh run_all.sh [filtro]      resultados en ./out/<name>.console y ./out/<name>.result
cd "$(dirname "$0")"
[ -x ./rv128_soc_load ] || gcc -O2 -o rv128_soc_load rv128_soc_load.c || exit 1
mkdir -p out
: > out/summary.txt
grep -- "${1:-.}" list.txt | while read name mode div th; do
  ./rv128_soc_load -m $mode -d $div -t $th -T 120 $name.bin@0 > out/$name.console 2> out/$name.result
  rc=$?
  printf '%-36s %-5s rc=%d  %s\n' "$name" "$mode" $rc "$(tail -1 out/$name.result)" | tee -a out/summary.txt
done
echo "PASS: $(grep -c 'rc=0' out/summary.txt) / $(wc -l < out/summary.txt)"
