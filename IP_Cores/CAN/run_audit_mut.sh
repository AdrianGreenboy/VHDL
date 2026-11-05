#!/usr/bin/env bash
# Audit 2026-11: proof that every new CAN test has teeth. Each mutation
# reverts ONE fix in a private copy (mktemp dir, the tree is not touched);
# the named testbench must then FAIL. Also runs the pre-audit engine
# (git HEAD, rstn adapted to rst) against the new engine/RX testbenches.
# Nothing is deleted; the work directory is printed at the end.
set -u
cd "$(dirname "$0")" || exit 1
SRC=$(pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/can_mut.XXXXXX")
FAILS=0

run_tb() {   # $1 dir, $2 tb name -> returns ghdl status
  ( cd "$1" && ghdl -a --std=08 can_byte_fifo.vhd can_engine.vhd can_mmio.vhd \
        "$2.vhd" >/dev/null 2>&1 && ghdl -e --std=08 "$2" >/dev/null 2>&1 && \
    timeout 900 ghdl -r --std=08 "$2" > run.log 2>&1 )
}

mutate() {   # $1 id, $2 file, $3 tb, $4 description, $5 old, $6 new
  local d="$W/$1"; mkdir -p "$d"
  cp "$SRC"/can_byte_fifo.vhd "$SRC"/can_engine.vhd "$SRC"/can_mmio.vhd "$SRC/$3.vhd" "$d/"
  python3 - "$d/$2" "$5" "$6" <<'EOF' || { echo "$1: patch site not found"; exit 2; }
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(old) == 1, "site count %d" % s.count(old)
open(p, 'w').write(s.replace(old, new))
EOF
  if run_tb "$d" "$3"; then
    echo "$1 ($4): *** DID NOT FAIL - test has no teeth ***"; FAILS=$((FAILS+1))
  elif grep -q FALLO "$d/run.log"; then
    echo "$1 ($4): fails as expected -> $(grep -m1 -oE 'FALLO[^"]*' "$d/run.log" | head -c 110)"
  else
    echo "$1 ($4): *** failed without FALLO (compile/other) ***"; FAILS=$((FAILS+1))
  fi
}

mutate A1 can_engine.vhd tb_can_engine "no stuff bit before CRC delimiter (TX)" \
  "    return stuffed(s) or s = S_CRCDEL;" "    return stuffed(s);"
mutate A2 can_engine.vhd tb_can_engine_rx "no stuff bit before CRC delimiter (RX)" \
  "    return stuffed(s) or s = S_CRCDEL;" "    return stuffed(s);"
mutate B1 can_engine.vhd tb_can_engine "no hard sync in intermission" \
  "or (st = S_INTER and cnt >= 2)) then" "or false) then"
mutate C1 can_engine.vhd tb_can_engine "no stuff-error-in-arbitration exception" \
  "p_err(true, false, lastarb and lastb = '0');" "p_err(true, false);"
mutate C2 can_engine.vhd tb_can_engine "bit error in active flag not counted" \
  "p_flagbiterr; -- bit error in own active flag: +8, new flag" "cnt := 0;"
mutate C3 can_engine.vhd tb_can_engine "passive ACK exception never voided" \
  "                ackexc := false;
                p_inc8;" "                ackexc := false;"
mutate C4 can_engine.vhd tb_can_engine_rx "no REC+8 for dominant after flag" \
  "p_inc8;     -- receiver: dominant 1st bit after its flag" "null;"
mutate C5 can_engine.vhd tb_can_engine_rx "no +8 for 14 consecutive dominant" \
  "        dcnt := 0;
        p_inc8;" "        dcnt := 0;"
mutate C6 can_engine.vhd tb_can_engine_rx "dominant in error delimiter not a form error" \
  "p_err(errtx, false); -- form error in the error delimiter" "st := S_EWAIT;"
mutate D1 can_engine.vhd tb_can_engine "bus-off keeps the pending request" \
  "      bseq := 0;
      pend := '0';" "      bseq := 0;"
mutate E1 can_mmio.vhd tb_can_mmio "STAT clear-on-any-write" \
  "if wdata(16) = '1' then s_tda  <= '0'; end if;" "s_tda <= '0'; s_rxvb <= '0';"
mutate E2 can_mmio.vhd tb_can_mmio "SELFACK without key" \
  "if wdata(31 downto 24) = x\"A5\" then -- SELFACK key" "if true then"
mutate E3 can_mmio.vhd tb_can_mmio "BTR writable while enabled" \
  "if ena_r = '0' and enb_r = '0' then" "if true then"

# pre-audit engine (git HEAD) against the new engine-level testbenches
if git -C "$SRC" show HEAD:./can_engine.vhd > "$W/old_engine.vhd" 2>/dev/null; then
  sed -i -e 's/    rstn        : in  std_logic;/    rst         : in  std_logic;/' \
         -e "s/      if rstn = '0' then/      if rst = '1' then/" "$W/old_engine.vhd"
  for tb in tb_can_engine tb_can_engine_rx; do
    d="$W/old_$tb"; mkdir -p "$d"
    cp "$SRC"/can_byte_fifo.vhd "$SRC"/can_mmio.vhd "$SRC/$tb.vhd" "$d/"
    cp "$W/old_engine.vhd" "$d/can_engine.vhd"
    if run_tb "$d" "$tb"; then
      echo "OLD/$tb: *** pre-audit engine PASSES the new testbench ***"; FAILS=$((FAILS+1))
    else
      echo "OLD/$tb: pre-audit engine fails as expected -> $(grep -m1 -oE 'FALLO[^"]*' "$d/run.log" | head -c 110)"
    fi
  done
else
  echo "OLD: git HEAD copy not available, skipped"
fi

echo "work dir: $W"
[ $FAILS -eq 0 ] && echo "AUDIT MUTATIONS OK" || { echo "AUDIT MUTATIONS: $FAILS PROBLEM(S)"; exit 1; }
