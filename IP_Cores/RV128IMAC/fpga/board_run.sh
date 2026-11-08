#!/bin/sh
# board_run.sh - runs every staged program on the TE0950 (PetaLinux, as root).
# Folder produced by 'board_check.py pack': <name>.bin, list.txt, rv128_load.c, this script.
#   sh board_run.sh            results in ./out/<name>.console and ./out/<name>.result
cd "$(dirname "$0")"
[ -x ./rv128_load ] || gcc -O2 -o rv128_load rv128_load.c || exit 1
mkdir -p out
pass=0; total=0
while read name tohost; do
  ./rv128_load "$name.bin" "$tohost" 20 > "out/$name.console" 2> "out/$name.result"
  rc=$?
  total=$((total + 1)); [ $rc -eq 0 ] && pass=$((pass + 1))
  printf '%-24s rc=%d  %s\n' "$name" $rc "$(cat out/$name.result)"
done < list.txt
echo "$pass/$total con codigo 0 (la comparacion completa se hace en el PC con board_check.py compare)"
