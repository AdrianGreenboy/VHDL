#!/usr/bin/env bash
# Cross-compila el bring-up de silicio del IP CAN para el TE0950 (aarch64).
# Copiar el binario resultante a la SD del target y correr:
#   sudo ./can_bringup            (cuadruple escalon 125k/250k/500k/1M)
#   sudo ./can_bringup <brp>      (un solo escalon; brp 39/19/9/4)
set -u
(
  cd "$(dirname "$0")" || exit 1
  aarch64-linux-gnu-gcc -O2 -static -Wall -o can_bringup can_bringup.c || exit 1
  echo "OK: can_bringup ($(du -h can_bringup | cut -f1))"
)
