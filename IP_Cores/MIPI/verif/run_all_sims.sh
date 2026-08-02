#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# Run all 5 verification layers with GHDL 4.1.0 (--std=08, mcode).
# Run from the verif/ directory:  bash run_all_sims.sh
#
# Each layer's sole PASS criterion is a bit-identical FNV signature. The RTL is
# read from ../rtl; vectors are regenerated from the oracle first.
# =============================================================================
set -e

RTL=../rtl
STD="--std=08"

echo "=================================================="
echo " Step 0: regenerate test vectors from the oracle"
echo "=================================================="
python3 gen_vectors.py
# tb_framegen reads gold_stream.hex (== the L4 dual-VC stream)
cp l4_stream.hex gold_stream.hex
echo ""

run_layer () {
  local name="$1"; shift
  local top="$1"; shift
  local files="$@"
  echo "=================================================="
  echo " $name"
  echo "=================================================="
  rm -rf work && mkdir work
  ghdl -a $STD --workdir=work $files
  ghdl -r $STD --workdir=work $top --stop-time=100ms 2>&1 | \
    grep -E "PASS|FAIL|FNV|signature|sig" | grep -iE "pass|fail" | tail -3
  echo ""
}

# ---- L1: RAW12 unpack ----
run_layer "L1 - RAW12 unpack (expect 0xEC935F45)" tb_l1 \
  $RTL/raw12_unpack.vhd tb_l1.vhd

# ---- L2a: ECC decoder ----
run_layer "L2a - ECC Hamming decoder (expect ECC ALL PASS)" tb_ecc \
  $RTL/csi2_ecc.vhd tb_ecc.vhd

# ---- L2b: packet layer ----
run_layer "L2b - packet layer + ECC + CRC (expect 0xADBF2613)" tb_l2 \
  $RTL/csi2_ecc.vhd $RTL/csi2_crc16.vhd $RTL/csi2_packet_rx.vhd tb_l2.vhd

# ---- L3: single-VC frame ----
run_layer "L3 - single-VC frame + framebuffer (expect 0x0C4F29C5)" tb_l3 \
  $RTL/raw12_unpack.vhd $RTL/csi2_ecc.vhd $RTL/csi2_crc16.vhd $RTL/csi2_packet_rx.vhd \
  $RTL/framebuffer.vhd csi2_frame_rx.vhd tb_l3.vhd

# ---- L4: dual-VC demux ----
run_layer "L4 - dual-VC demux (expect 0xE6898DC5)" tb_l4 \
  $RTL/raw12_unpack.vhd $RTL/csi2_ecc.vhd $RTL/csi2_crc16.vhd $RTL/csi2_packet_rx.vhd \
  $RTL/framebuffer.vhd $RTL/csi2_dual_rx.vhd tb_l4.vhd

# ---- L5a: frame generator (byte-identical to oracle) ----
run_layer "L5a - frame_gen byte-identical (expect FRAMEGEN PASS)" tb_framegen \
  $RTL/csi2_pkg.vhd $RTL/frame_gen.vhd tb_framegen.vhd

# ---- L5b: full self-test loopback ----
run_layer "L5b - self-test loopback (expect 0xE6898DC5)" tb_l5 \
  $RTL/csi2_pkg.vhd $RTL/csi2_ecc.vhd $RTL/csi2_crc16.vhd $RTL/csi2_packet_rx.vhd \
  $RTL/raw12_unpack.vhd $RTL/framebuffer.vhd $RTL/csi2_dual_rx.vhd \
  $RTL/frame_gen.vhd $RTL/dphy_model.vhd $RTL/byte_fifo.vhd $RTL/csi2_selftest.vhd tb_l5.vhd

echo "=================================================="
echo " All layers complete. Every line above must say PASS."
echo "=================================================="
