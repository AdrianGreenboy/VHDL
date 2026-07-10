#!/usr/bin/env bash
# Cross-compila el bring-up de silicio del IP SpaceWire para el TE0950 (aarch64).
# Copiar el binario resultante a la SD del target y correr:
#   sudo ./spw_bringup            (cuadruple escalon 10/20/25/50 Mbit/s)
#   sudo ./spw_bringup <div>      (un solo escalon; div 10/5/4/2)
set -u
(
  cd "$(dirname "$0")" || exit 1
  aarch64-linux-gnu-gcc -O2 -static -Wall -o spw_bringup spw_bringup.c || exit 1
  echo "OK: spw_bringup ($(du -h spw_bringup | cut -f1))"
)
