# SERDES_256G — multi-lane 64B/66B link layer, 8 × 32 Gb/s

VHDL-2008 link layer that bonds `G_LANES` raw 128-bit transceiver channels into
one wide AXI4-Stream link. With 8 lanes at 32 Gb/s the line carries
**256 Gb/s raw / 248.2 Gb/s of 64B/66B payload** (minus 1/`G_AM_PERIOD` for the
alignment markers).

**Status: v0.2. Link testbench passes in GHDL (run by the author). OOC synthesis on xcve2302-1LP: 17.3k LUT, 19.3k FF, WNS +0.043 ns at 250 MHz before the s2b pipeline stage; not placed and routed, not on silicon.**


## What it is and what it is not

- It is the **digital** part of a SerDes: framing, 64B/66B, scrambling,
  gearbox, block lock, lane alignment, deskew and lane reordering.
- The serialiser, CDR, PLL and equaliser are the GT hard block (FPGA) or an
  analog PMA macro (ASIC). The core talks to them through a 128-bit parallel
  interface per lane and is rate-agnostic.
- No FEC, no frame CRC, no auto-negotiation / link training in v0.1.

## Architecture

```
s_axis_tx (1024 b) -> tx_frame -> 8 x tx_lane  -> gt_txdata (8 x 128 b)
                                  scrambler, AM + BIP-8, gearbox 132->128

gt_rxdata (8 x 128 b) -> 8 x rx_lane -> 8 x afifo -> rx_align -> rx_frame -> m_axis_rx
                         gearbox+slip,   CDC +      deskew,      deframer
                         block lock,     skew       lane reorder,
                         marker lock     buffer     BIP-8, descrambler
```

| Item | Value |
|---|---|
| Lane word | 2 × 66-bit blocks per clock (132 bit) |
| Fabric clock at 32 Gb/s | 250 MHz GT user clock, 242.4 MHz average word rate |
| User interface | AXI4-Stream, `G_LANES*128` bit (`tkeep`, `tlast`); RX has no `tready` |
| Scrambler | x^58 + x^39 + 1, self-synchronous, per lane |
| Block lock | clause 49 thresholds (64 valid headers / 16 invalid in 64) |
| Alignment | AM_A + AM_B on every lane every `G_AM_PERIOD` words, lane id, BIP-8 |
| Deskew range | about `2**(G_FIFO_AW-1)` lane words (32 words = 4224 bit by default) |
| Lane order / RX word alignment | arbitrary, resolved by the core |

Differences from Core 19/20: the sync-header convention, scrambler and block
lock rules are the same, but the datapath is two blocks wide and frame
delimiting is **not** clause 49 /S/ /T/. A frame always starts in block 0 of a
beat and ends with one EOF control block (type `0xE1`) carrying the byte count
of the last data block. This removes every barrel shifter from the 1024-bit
datapath.

## Files

```
rtl/serdes256g_pkg.vhd        constants, block formats, helpers
rtl/serdes256g_tx_frame.vhd   AXI4-Stream -> blocks, slot scheduler
rtl/serdes256g_tx_lane.vhd    scrambler, AM/BIP insertion, gearbox 132->128
rtl/serdes256g_rx_lane.vhd    gearbox 128->132 + slip, block lock, marker lock
rtl/serdes256g_afifo.vhd      asynchronous FIFO (per-lane CDC + deskew buffer)
rtl/serdes256g_rx_align.vhd   deskew FSM, BIP-8 check, descrambler, lane reorder
rtl/serdes256g_rx_frame.vhd   blocks -> AXI4-Stream
rtl/serdes256g_top.vhd        top level
tb/tb_serdes256g.vhd          self-checking link testbench (skew, lane swap, errors)
sim/run_tb.sh                 GHDL run script
vivado/serdes256g_cdc.xdc     CDC constraints
```

## Simulation

```
bash sim/run_tb.sh
tail -f sim/tb_serdes256g.log
```

Expected last line: `SERDES256G_TB_PASS`.

## Integration notes

- GT: raw mode, 128-bit TX and RX user data width, no 8B/10B / gearbox / comma
  logic, RX buffer in any mode. `gt_txdata(0)` of a lane is the first bit on
  the wire. All TX lanes must share `tx_clk`.
- `rx_clk` can be the local TX user clock: lane words arrive in 32 of every 33
  clocks, which absorbs any ppm offset between the two ends.
- RX polarity inversion is not detected; set RXPOLARITY in the GT.
- Hold `rx_rst` until the GT RX user clocks are stable.

## Open points

1. Line rate on the TE0950: the board carries `xcve2302-sfva784-1LP-e-S`.
   Check the GTYP maximum line rate for the -1LP grade in DS958 and how many
   GTYP channels the board routes out; 8 × 32 Gb/s may need a different
   device/board. The RTL does not change with the rate or the lane count.
2. Timing: the 128-bit scrambler loop and the RX shifters are the long paths;
   expect to add pipeline stages after the first out-of-context synthesis.
3. BER: 32 Gb/s NRZ without FEC only works on short, clean channels.
4. No AXI4 register bank yet (status is on ports).
