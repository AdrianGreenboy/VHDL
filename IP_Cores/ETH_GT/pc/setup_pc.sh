#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 21 - ETH GT : preparacion del PC (Ubuntu) para recibir de la
# TE0950 por la ConnectX-3 Pro (QSFP+, cable DAC directo).
#
#   sudo bash setup_pc.sh <interfaz> [ip/prefijo]      (por defecto 192.168.21.1/24)
#
# La ConnectX-3 Pro es 40GBASE-R4 (4 lanes de 10G): se fuerza a 10G, que usa
# solo la lane 0 del QSFP, la unica que lleva la TE0950.
# =============================================================================
set -u
IF=${1:?uso: sudo bash setup_pc.sh <interfaz> [ip/prefijo]}
ADDR=${2:-192.168.21.1/24}
PORT=21009

echo "== $IF: driver y modos"
ethtool -i "$IF" | head -3
ethtool "$IF" | grep -A12 "Supported link modes" | head -14

echo "== forzar 10G sin autonegociacion (lane 0 del QSFP)"
ip link set "$IF" up
ethtool -s "$IF" speed 10000 autoneg off duplex full || \
  echo "AVISO: ethtool -s fallo; prueba 'ethtool -s $IF speed 10000 autoneg off' a mano"
sleep 2

echo "== direccion IP y buffers"
ip addr flush dev "$IF"
ip addr add "$ADDR" dev "$IF"
sysctl -q -w net.core.rmem_max=268435456 net.core.rmem_default=67108864
sysctl -q -w net.core.netdev_max_backlog=250000
ethtool -G "$IF" rx 8192 2>/dev/null || ethtool -G "$IF" rx 4096 2>/dev/null || true

echo "== cortafuegos (UFW): UDP $PORT solo por $IF"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow in on "$IF" to any port $PORT proto udp
fi

echo "== resumen"
ip -br addr show "$IF"
echo "MAC de $IF (pasala a 'eth21 send --peer-mac ...'): $(cat /sys/class/net/$IF/address)"
ethtool "$IF" | grep -E "Speed|Duplex|Auto-negotiation|Link detected"
