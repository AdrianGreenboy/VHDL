#!/usr/bin/env bash
# run_regression.sh — regresion completa del IP PTP / IEEE 802.1AS (GHDL 4.1.0).
# Analiza el RTL en orden de dependencia y corre los 15 testbenches.
# Uso:  cd sim && ./run_regression.sh
# Requiere: GHDL 4.1.0 (--std=08), Python 3. Los ficheros RTL en ../rtl.
set -u
RTL=../rtl
STD="--std=08 -Wno-hide"
fail=0

echo "=== generando referencias ISS (Python) ==="
python3 iss_ptp_clock.py   >/dev/null 2>&1
python3 iss_ptp_tstamp.py  >/dev/null 2>&1
python3 iss_ptp_pdelay.py  >/dev/null 2>&1
python3 iss_ptp.py         >/dev/null 2>&1

echo "=== analizando RTL en orden de dependencia ==="
rm -f work-obj08.cf
ghdl -a $STD \
  $RTL/ptp_pkg.vhd $RTL/ptp_msg_pkg.vhd $RTL/eth_pkg.vhd $RTL/spw_fifo.vhd \
  $RTL/ptp_clock.vhd $RTL/ptp_tstamp.vhd $RTL/ptp_pdelay.vhd $RTL/ptp_pdelay_fsm.vhd \
  $RTL/ptp_tx.vhd $RTL/ptp_rx.vhd \
  $RTL/eth_tx_mii.vhd $RTL/eth_rx_mii.vhd $RTL/eth_mac.vhd \
  $RTL/ptp_mac.vhd $RTL/ptp_regs.vhd $RTL/ptp_top.vhd $RTL/ptp_axil.vhd $RTL/ptp_axil_master.vhd \
  tb_ptp_clock.vhd tb_ptp_tstamp.vhd tb_ptp_pdelay.vhd tb_ptp_pdelay_fsm.vhd \
  tb_ptp_tx.vhd tb_ptp_rx.vhd tb_ptp_tx_pdelay.vhd \
  tb_ptp_mac_sync.vhd tb_ptp_mac_pdelay.vhd tb_ptp_mac_slave.vhd tb_ptp_mac_seq.vhd \
  tb_ptp_regs.vhd tb_ptp_top.vhd tb_ptp_soc.vhd tb_ptp_axil.vhd tb_ptp_axil_master.vhd
if [ $? -ne 0 ]; then echo "FALLO en analisis RTL"; exit 1; fi

chk () {
  # $1 = etiqueta, $2 = comando ghdl -r, $3 = patron de exito
  local r
  r=$(eval "$2" 2>&1 | grep -oE "$3" | head -1)
  if [ -n "$r" ]; then echo "  PASS  $1"; else echo "  FALLO $1"; fail=1; fi
}

echo "=== capa 1a (bloques + mutaciones) ==="
chk "reloj/servo PI"      "ghdl -r $STD tb_ptp_clock --assert-level=error"      "LAYER 1a PASS"
chk "timestamping SFD"    "ghdl -r $STD tb_ptp_tstamp --assert-level=error"     "LAYER 1a PASS"
chk "meanPathDelay"       "ghdl -r $STD tb_ptp_pdelay --assert-level=error"     "LAYER 1a PASS"
chk "orquestador pdelay"  "ghdl -r $STD tb_ptp_pdelay_fsm --assert-level=error" "LAYER 1a PASS"
chk "TX Sync bit-ident"   "ghdl -r $STD tb_ptp_tx >/dev/null 2>&1 && python3 verify_ptp_tx.py" "BIT-IDENTICA.*PASS"
chk "TX Pdelay bit-ident" "ghdl -r $STD tb_ptp_tx_pdelay >/dev/null 2>&1 && python3 verify_ptp_tx_pdelay.py" "PASS"

echo "=== capa 1b (parser RX) ==="
chk "RX parser gPTP"      "ghdl -r $STD tb_ptp_rx --assert-level=error"         "LAYER 1b PASS"

echo "=== capa 1c (integracion en LOOP_INT) ==="
chk "Sync loopback"       "ghdl -r $STD tb_ptp_mac_sync --assert-level=error"   "1c .basico. PASS"
chk "Pdelay loopback"     "ghdl -r $STD tb_ptp_mac_pdelay --assert-level=error" "mpd=40ns PASS"
chk "lazo esclavo servo"  "ghdl -r $STD tb_ptp_mac_slave --assert-level=error"  "lazo esclavo Sync PASS"
chk "Sync->Pdelay (carrera)" "ghdl -r $STD tb_ptp_mac_seq --assert-level=error" "Sync->Pdelay mpd=40 PASS"

echo "=== capa 2 (MMIO) ==="
chk "banco de registros"  "ghdl -r $STD tb_ptp_regs --assert-level=error"       "LAYER 2 PASS"
chk "IP top end-to-end"   "ghdl -r $STD tb_ptp_top --assert-level=error"        "IP completo por MMIO. PASS"

echo "=== capa 4 (SoC RTL-vs-ISS) ==="
chk "SoC 3 flujos vs ISS" "ghdl -r $STD tb_ptp_soc --assert-level=error"        "LAYER 4 .RTL-vs-ISS.*PASS"

echo "=== wrapper AXI4-Lite ==="
chk "AXI-Lite wrapper"    "ghdl -r $STD tb_ptp_axil --assert-level=error"       "wrapper AXI4-Lite PASS"
chk "maestro AXIL (core)"  "ghdl -r $STD tb_ptp_axil_master --assert-level=error" "cadena lado-core PASS"

echo ""
if [ $fail -eq 0 ]; then
  echo "=== TODAS LAS VERIFICACIONES PASAN ==="
else
  echo "=== HAY FALLOS (ver arriba) ==="
  exit 1
fi
