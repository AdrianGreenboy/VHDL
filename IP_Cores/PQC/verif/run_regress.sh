#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - in-tree regression runner.
#
# Runs every Layer 1..4 testbench in verif/ directly against the sources in
# rtl/ (the pqc_l*.sh installers embed historical copies and install to
# $HOME/vhdl_repo; this script never touches them).
#
# Usage: run_regress.sh [quick|full|<test-name>...]
#   quick : unit + checkpoint tests (minutes)
#   full  : everything, including the ACVP KAT suites (hours on 2 CPUs)
# Environment:
#   BUILD  work directory (default: verif/build, git-ignored)
#   JOBS   parallel simulations (default: 2)
#   GHDL_EXTRA  extra analysis options
# Output: one line per test "PASS|FAIL <name> <report line>" plus a log per
# test in $BUILD/logs/<name>.log.
# =============================================================================
set -u
HERE="${VERIF:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
RTL="${RTL:-$HERE/../rtl}"
BUILD="${BUILD:-$HERE/build}"
JOBS="${JOBS:-2}"
GHDL="${GHDL:-ghdl}"        # ghdl-llvm is several times faster on the KATs
mkdir -p "$BUILD/logs"

# Analysis order: production RTL first (same order as soc/rtl/
# SOC_ANALYSIS_ORDER.txt), then the verification-only wrappers.
RTL_FILES="keccak_pkg keccak_f1600 keccak_sponge ntt_tables_pkg pqc_codec_pkg
  pqc_round_pkg poly_mem ntt_d_tables_pkg pqc_round_d_pkg poly_mem_d
  sampler_ntt_k sampler_misc ntt_unit basemul_k byte_mem codec_ct byte_mem_d
  ntt_d_unit sampler_d codec_d kem_keygen kem_encaps kem_decaps kem_core_sx
  dsa_keygen dsa_sign dsa_verify dsa_core_sx pqc_core
  kem_keygen_top kem_encaps_top kem_decaps_top kem_core
  dsa_keygen_top dsa_sign_top dsa_verify_top dsa_core"
VERIF_PKGS=""
[ -f "$HERE/pqc_round_ref_pkg.vhd" ] && VERIF_PKGS="pqc_round_ref_pkg"

TBS=$(cd "$HERE" && ls tb_*.vhd | sed 's/\.vhd$//')

# soc/rtl must hold byte-identical copies of every rtl/ file
if [ -d "$RTL/../soc/rtl" ]; then
  for f in "$RTL"/*.vhd; do
    g="$RTL/../soc/rtl/$(basename "$f")"
    if [ -f "$g" ] && ! cmp -s "$f" "$g"; then
      echo "SOC COPY OUT OF SYNC: $(basename "$f") (cp rtl/*.vhd to soc/rtl)"; exit 1
    fi
  done
fi

analyze () {
  cd "$BUILD" || exit 1
  rm -f work-obj08.cf
  for f in $RTL_FILES; do
    $GHDL -a --std=08 ${GHDL_EXTRA:-} "$RTL/$f.vhd" || { echo "ANALYSIS FAIL $f"; exit 1; }
  done
  # Layer 1 ML-DSA sampler prototypes (verification only, used by tb_sampler)
  if [ -f "$RTL/../legacy/sampler_misc_l1_d.vhd" ]; then
    $GHDL -a --std=08 ${GHDL_EXTRA:-} "$RTL/../legacy/sampler_misc_l1_d.vhd" \
      || { echo "ANALYSIS FAIL legacy"; exit 1; }
  fi
  for f in $VERIF_PKGS $TBS; do
    $GHDL -a --std=08 ${GHDL_EXTRA:-} "$HERE/$f.vhd" || { echo "ANALYSIS FAIL $f"; exit 1; }
  done
  # vectors are opened by relative path
  for v in "$HERE"/*.txt; do ln -sf "$v" "$BUILD/"; done
  for t in $TBS; do $GHDL -e --std=08 "$t" >/dev/null 2>&1 || { echo "ELAB FAIL $t"; exit 1; }; done
}

# name | tb | generics | stop-time | pass-regex
TABLE_QUICK="
keccak|tb_keccak||50ms|PQC L1 KECCAK PASS
ntt|tb_ntt||500ms|PQC L1 NTT PASS
sampler|tb_sampler||300ms|PQC L1 SAMPLER PASS
codec|tb_codec||10ms|PQC L2 CODEC PASS
round|tb_round||10ms|PQC L2 ROUND PASS
basemul|tb_basemul||100ms|PQC L3 BASEMUL PASS
codec12|tb_codec12||200ms|PQC L3A CODEC12 PASS
poly_mem|tb_poly_mem||50ms|PQC L3A POLYMEM PASS
datapath|tb_datapath||300ms|PQC L3A DATAPATH PASS
codec_ct|tb_codec_ct||800ms|PQC L3A CODECCT PASS
kg_cp1|tb_checkpoint|-gG_STAGE=1|800ms|CHECKPOINT PASS
kg_cp2|tb_checkpoint|-gG_STAGE=2|800ms|CHECKPOINT PASS
kg_cp3|tb_checkpoint|-gG_STAGE=3|800ms|CHECKPOINT PASS
kg_cp4|tb_checkpoint|-gG_STAGE=4|800ms|CHECKPOINT PASS
kg_cp5|tb_checkpoint|-gG_STAGE=5|800ms|CHECKPOINT PASS
ep_cp2|tb_ep_checkpoint|-gG_STAGE=2|1500ms|ENCAPS CHECKPOINT PASS
ep_cp3|tb_ep_checkpoint|-gG_STAGE=3|1500ms|ENCAPS CHECKPOINT PASS
ep_cp4|tb_ep_checkpoint|-gG_STAGE=4|1500ms|ENCAPS CHECKPOINT PASS
ep_cp5|tb_ep_checkpoint|-gG_STAGE=5|1500ms|ENCAPS CHECKPOINT PASS
ntt_d|tb_ntt_d||300ms|PQC L3B NTTD PASS
sampler_d|tb_sampler_d||100ms|PQC L3B SAMPD PASS
round_d|tb_round_d||50ms|PQC L3B ROUNDD PASS
codec_d|tb_codec_d||300ms|PQC L3B CODECD PASS
dkg_cp1|tb_dsa_keygen|-gG_STAGE=1|40000ms|CHECKPOINT PASS
dkg_cp2|tb_dsa_keygen|-gG_STAGE=2|40000ms|CHECKPOINT PASS
dkg_cp3|tb_dsa_keygen|-gG_STAGE=3|40000ms|CHECKPOINT PASS
dkg_cp4|tb_dsa_keygen|-gG_STAGE=4|40000ms|CHECKPOINT PASS
dsg_cp1|tb_dsa_sign|-gG_STAGE=1|8000ms|CHECKPOINT PASS
dsg_cp2|tb_dsa_sign|-gG_STAGE=2|8000ms|CHECKPOINT PASS
dsg_cp3|tb_dsa_sign|-gG_STAGE=3|8000ms|CHECKPOINT PASS
dsg_cp4|tb_dsa_sign|-gG_STAGE=4|8000ms|CHECKPOINT PASS
dvf_cp1|tb_dsa_verify|-gG_STAGE=1|20000ms|CHECKPOINT PASS
dvf_cp2|tb_dsa_verify|-gG_STAGE=2|20000ms|CHECKPOINT PASS
dvf_cp3|tb_dsa_verify|-gG_STAGE=3|20000ms|CHECKPOINT PASS
dvf_cp4|tb_dsa_verify|-gG_STAGE=4|20000ms|CHECKPOINT PASS
"
TABLE_KAT="
keygen|tb_keygen||4000ms|PQC L3A KEYGEN PASS
encaps|tb_encaps||6000ms|PQC L3A ENCAPS PASS
decaps|tb_decaps||30000ms|PQC L3A DECAPS PASS
dsakg|tb_dsa_keygen|-gG_STAGE=0|400000ms|PQC L3B DSAKG PASS
dsaver|tb_dsa_verify|-gG_STAGE=0|400000ms|PQC L3B DSAVER PASS
kemcore|tb_kem_core||400000ms|PQC L4 KEMCORE PASS
dsacore|tb_dsa_core||400000ms|PQC L4 DSACORE PASS
fusion|tb_pqc_core||800000ms|PQC L4 FUSION PASS
dsasign|tb_dsa_sign|-gG_STAGE=0|400000ms|PQC L3B DSASIGN PASS
"
# extra self-checking tests added by the 2026-11 audit (only if present).
# They inspect memories through VHDL-2008 external names: run them with the
# mcode backend (GHDL=ghdl); GHDL 4.1's gcc backend fails them with
# "NULL access dereferenced" at elaboration.
TABLE_AUDIT="
mem_banks|tb_mem_banks||100ms|PQC MEMBANKS PASS
sponge_err|tb_sponge_err||10ms|PQC SPONGEERR PASS
host_guard|tb_host_guard||800000ms|PQC HOSTGUARD PASS
sign_bound2|tb_sign_bound|-gG_MAX_ITER=2|800000ms|PQC SIGNBOUND PASS
sign_bound3|tb_sign_bound|-gG_MAX_ITER=3|800000ms|PQC SIGNBOUND PASS
zeroize|tb_zeroize||800000ms|PQC ZEROIZE PASS
"

run_one () {
  IFS='|' read -r name tb gen st rx <<< "$1"
  [ -z "$name" ] && return 0
  [ -f "$HERE/$tb.vhd" ] || return 0
  cd "$BUILD" || exit 1
  t0=$(date +%s)
  $GHDL -r --std=08 "$tb" $gen --stop-time="$st" > "logs/$name.log" 2>&1
  t1=$(date +%s)
  line=$(grep -m1 "$rx" "logs/$name.log" | sed 's/.*(report note): //')
  if [ -n "$line" ] && ! grep -q "(assertion failure)\|(report failure)\|(assertion error)" "logs/$name.log"; then
    echo "PASS $name [$((t1-t0))s] $line"
  else
    echo "FAIL $name [$((t1-t0))s] $(grep -m2 'error\|failure' logs/$name.log | tr '\n' ' ')"
  fi
}
export -f run_one
export BUILD HERE GHDL

MODE="${1:-quick}"
case "$MODE" in
  quick) SEL="$TABLE_QUICK" ;;
  audit) SEL="$TABLE_AUDIT" ;;
  full)  SEL="$TABLE_QUICK$TABLE_KAT$TABLE_AUDIT" ;;
  kat)   SEL="$TABLE_KAT" ;;
  *)     SEL=""
         for n in "$@"; do
           SEL="$SEL
$(printf '%s\n' "$TABLE_QUICK$TABLE_KAT$TABLE_AUDIT" | grep "^$n|")"
         done ;;
esac

analyze
printf '%s\n' "$SEL" | grep -v '^$' | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
