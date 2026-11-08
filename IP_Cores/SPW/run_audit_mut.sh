#!/usr/bin/env bash
# Audit 2026-11: proof that every new SPW test has teeth. Each mutation
# reverts ONE fix in a private copy (mktemp dir; the tree is not touched)
# and the named testbench must FAIL. Also runs the oversampling receiver
# (pre-audit architecture) against the 400 Mbit/s DS testbench.
# Nothing is deleted; the work directory is printed at the end.
set -u
cd "$(dirname "$0")" || exit 1
SRC=$(pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/spw_mut.XXXXXX")
FAILS=0
ALL="spw_fifo.vhd spw_tx.vhd spw_tx_cdc.vhd spw_rx.vhd spw_rx_dsr.vhd spw_link.vhd spw_codec.vhd spw_mmio.vhd"

mutate() {   # $1 id, $2 file, $3 tb, $4 description, $5 old, $6 new [, $7 old2, $8 new2]
  local d="$W/$1"; mkdir -p "$d"
  ( cd "$SRC" && cp $ALL "$3.vhd" "$d/" )
  python3 - "$d/$2" "$5" "$6" "${7:-}" "${8:-}" <<'PYEND' || { echo "$1: patch site not found"; exit 2; }
import sys
p = sys.argv[1]
s = open(p).read()
for old, new in ((sys.argv[2], sys.argv[3]), (sys.argv[4], sys.argv[5])):
    if old:
        assert s.count(old) == 1, "site count %d" % s.count(old)
        s = s.replace(old, new)
open(p, 'w').write(s)
PYEND
  if ( cd "$d" && ghdl -a --std=08 $ALL "$3.vhd" >/dev/null 2>&1 && \
       ghdl -e --std=08 "$3" >/dev/null 2>&1 && \
       timeout 900 ghdl -r --std=08 "$3" > run.log 2>&1 ); then
    echo "$1 ($4): *** DID NOT FAIL - test has no teeth ***"; FAILS=$((FAILS+1))
  elif grep -q FALLO "$d/run.log"; then
    echo "$1 ($4): fails as expected -> $(grep -m1 -oE 'FALLO[^"]*' "$d/run.log" | head -c 110)"
  else
    echo "$1 ($4): *** failed without FALLO (compile/other) ***"; FAILS=$((FAILS+1))
  fi
}

mutate S1 spw_mmio.vhd tb_spw_2 "STAT clear-on-any-write" \
  "stk <= stk and not wdata(24 downto 16);  -- W1C per bit..." "stk <= (others => '0');"
mutate S2 spw_mmio.vhd tb_spw_2 "time-code tick without +1 check" \
  "if unsigned(time_out_i(5 downto 0)) = unsigned(time_last(5 downto 0)) + 1 then" "if true then"
mutate S3 spw_codec.vhd tb_spw_2 "stale tick_in emitted on entering Run" \
  "if en = '0' or allow_nchar_i = '0' then" "if en = '0' then"
mutate S4 spw_rx.vhd tb_spw_1b "no simultaneous D/S detection" \
  "if fnull = '1' and st /= HALT and d2 /= dp and s2 /= sp" "if false"
mutate S5 spw_rx_dsr.vhd tb_spw_3 "recovered-clock pair order swapped" \
  "      v_w   := acc6 & rbit & din;                -- even bit, odd bit" "      v_w   := acc6 & din & rbit;"
mutate S6 spw_tx_cdc.vhd tb_spw_4 "FCT handshake without cooldown" \
  "          fct_ack <= '1';
          fq_cool <= '1';" "          fct_ack <= '1';
          fq_busy <= '0';"
mutate S7 spw_rx_dsr.vhd tb_spw_1c "rclk reset release synchronized (swallows first bits)" \
  "  rs2 <= rx_rst;" "  rs_p : process (rclk, rx_rst) begin if rx_rst = '1' then rs1 <= '1'; rs2 <= '1'; elsif falling_edge(rclk) then rs1 <= '0'; rs2 <= rs1; end if; end process;" \
  "  signal rs2       : std_logic := '1';" "  signal rs1, rs2  : std_logic := '1';"

# oversampling receiver (pre-audit architecture) at 400 Mbit/s
d="$W/OLD_RX"; mkdir -p "$d"
cp "$SRC/spw_rx.vhd" "$SRC/tb_spw_3.vhd" "$d/"
sed -i 's/  dut : entity work.spw_rx_dsr/  dut : entity work.spw_rx/' "$d/tb_spw_3.vhd"
if ( cd "$d" && ghdl -a --std=08 spw_rx.vhd tb_spw_3.vhd >/dev/null 2>&1 && \
     ghdl -e --std=08 tb_spw_3 >/dev/null 2>&1 && \
     timeout 900 ghdl -r --std=08 tb_spw_3 > run.log 2>&1 ); then
  echo "OLD_RX: *** oversampling RX passes the 400 Mbit/s test ***"; FAILS=$((FAILS+1))
else
  echo "OLD_RX: oversampling RX fails at 400 Mbit/s as expected -> $(grep -m1 -oE 'FALLO[^"]*' "$d/run.log" | head -c 110)"
fi

echo "work dir: $W"
[ $FAILS -eq 0 ] && echo "AUDIT MUTATIONS OK" || { echo "AUDIT MUTATIONS: $FAILS PROBLEM(S)"; exit 1; }
