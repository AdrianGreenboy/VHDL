#!/usr/bin/env bash
# Layer 3A poly_mem mutation harness: each mutation must FAIL the testbench.
set -u
PASS_LINE="PQC L3A POLYMEM PASS"

run_mut () {
  name="$1"; from="$2"; to="$3"
  d=$(mktemp -d)
  cp ../rtl/poly_mem.vhd tb_poly_mem.vhd "$d"/
  python3 - "$d/poly_mem.vhd" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 poly_mem.vhd tb_poly_mem.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_poly_mem >/dev/null 2>&1 \
      && timeout 300 ghdl -r --std=08 tb_poly_mem --stop-time=50ms 2>&1 | tail -3 > out.txt
    if grep -q "$PASS_LINE" out.txt 2>/dev/null; then
      echo "MUTATION NOT CAUGHT: $name"; exit 1
    fi )
  rc=$?
  rm -rf "$d"
  if [ $rc -ne 0 ]; then echo "FAIL $name"; return 1; fi
  echo "  killed: $name"
  return 0
}

fails=0
echo "Layer 3A poly_mem mutations (each must be killed):"

# M1: slot offset dropped from the FSM read path (all slots alias slot 0)
run_mut "M1 read slot offset" \
  "        ra   <= slot_rd * 256 + to_integer(unsigned(fsm_raddr));
        rb   <= slot_rd * 256 + to_integer(unsigned(fsm_raddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(fsm_waddr));
        wd   <= to_integer(signed(fsm_wdata));" \
  "        ra   <= to_integer(unsigned(fsm_raddr));
        rb   <= to_integer(unsigned(fsm_raddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(fsm_waddr));
        wd   <= to_integer(signed(fsm_wdata));" || fails=1

# M2: basemul second read port aliased to the first slot
run_mut "M2 basemul rd2 slot" \
  "rb   <= slot_rd2 * 256 + to_integer(unsigned(bm_baddr));" \
  "rb   <= slot_rd * 256 + to_integer(unsigned(bm_baddr));" || fails=1

# M3: NTT write routed to the read slot
run_mut "M3 ntt write slot" \
  "        wa   <= slot_wr * 256 + to_integer(unsigned(ntt_waddr));
        wd   <= to_integer(signed(ntt_wdata));" \
  "        wa   <= slot_rd * 256 + to_integer(unsigned(ntt_waddr));
        wd   <= to_integer(signed(ntt_wdata));" || fails=1

# M4: sampler write enable ignored
run_mut "M4 sampler write enable" \
  "        we_i <= sm_we;" "        we_i <= '0';" || fails=1

# M5: destination readback takes the read address instead of the write address
run_mut "M5 destination readback address" \
  "bm_drdata <= std_logic_vector(to_signed(mem(wa), 16));" \
  "bm_drdata <= std_logic_vector(to_signed(mem(ra), 16));" || fails=1

# M6: slot stride wrong, so adjacent slots overlap
run_mut "M6 slot stride" \
  "        ra   <= slot_rd * 256 + to_integer(unsigned(bm_aaddr));" \
  "        ra   <= slot_rd * 128 + to_integer(unsigned(bm_aaddr));" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
