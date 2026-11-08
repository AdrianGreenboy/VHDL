# RV128IMAC — OOC synthesis and bare-metal on the TE0950

**Status: not run yet.** Layer 4 (`tb_proto`, the prototype top driven the way the A72
loader drives it) is part of `run_regression.sh` and must be green before going to the board.

## 1. Out-of-context synthesis (VE2302)

Run the RV128 core, the RV64 core (same part, same flow) and the full prototype top:

```bash
cd IP_Cores/RV128IMAC
for t in core128 core64 proto; do vivado -mode batch -source fpga/ooc/ooc.tcl -tclargs $t 10 -log fpga/ooc/$t.log -journal fpga/ooc/$t.jou; done
```

Follow it live from another terminal:

```bash
tail -f IP_Cores/RV128IMAC/fpga/ooc/core128.log
```

Each run ends with a `RESULT top=... LUT=... FF=... WNS=... fmax=...` line; the reports
are in `fpga/ooc/<top>/` (`util.rpt` is authoritative for resources).
The 10 ns target is deliberately tight so WNS gives a real fmax estimate.

Caveat for the comparison: `rv64_core` contains the MMU (TLB + PTW) and S/U modes;
`rv128_core` does not. The difference therefore understates the cost of 128-bit width.

## 2. Prototype architecture

```
A72 (PetaLinux) --M_AXI_FPD--> SmartConnect --> rv128/s_axi_ctrl (0xA400_0000, 256 KiB)
                                                 control bank + BRAM window + console FIFO
rv128_core --I--> BRAM 128 KiB (port A)
           --D--> BRAM (port B) | CLINT | console byte port
```

No NoC, no DDR, no reserved memory: the program lives in BRAM. The core sees RAM at
0x8000_0000, the CLINT at 0x0200_0000 and the console at 0x1000_0000, the same map as
the simulation and the ISS, so the same binaries run unchanged.

## 3. Vivado project and PDI

```bash
vivado -mode batch -source fpga/create_project.tcl
```

GUI (your preference for the CIPS): open `fpga/rv128_proto_te0950/rv128_proto_te0950.xpr`,
create Block Design `design_1` with the CIPS as in your TE0950 projects (PS + LPDDR4 through
the NoC), enable **M_AXI_FPD** and **pl0_ref_clk = 50 MHz** with `pl0_resetn`. Save, close.

```bash
vivado -mode batch -source fpga/bd_insert_rv128.tcl -tclargs fpga/rv128_proto_te0950/rv128_proto_te0950.xpr design_1 -log fpga/bd_insert.log
tail -f IP_Cores/RV128IMAC/fpga/bd_insert.log
```

Outputs: `timing_summary.rpt`, `utilization.rpt`, the PDI and `rv128_proto_te0950.xsa`
next to the `.xpr`.

## 4. PetaLinux

BOOT.BIN through PetaLinux with the new XSA (never a hot PDI load), in your usual TE0950
project. Nothing else changes: no device-tree node or reserved memory is needed, the
loader uses `/dev/mem`.

## 5. Running the tests on the board

On the PC, stage the programs (binaries + tohost offsets + loader source + runner):

```bash
cd IP_Cores/RV128IMAC && python3 fpga/board_check.py pack fpga/board $(ls sw/tests/*.bin | sed 's/\.bin$//')
scp -r fpga/board root@<te0950>:/home/root/rv128
```

On the board (root):

```bash
cd /home/root/rv128 && sh board_run.sh
```

Back on the PC, compare against the ISS (verdict, console bytes, exact commit count):

```bash
scp -r root@<te0950>:/home/root/rv128/out fpga/board/out
python3 fpga/board_check.py compare fpga/board/out $(ls sw/tests/*.bin | sed 's/\.bin$//')
```

If `gcc` is not on the board image: `aarch64-linux-gnu-gcc -O2 -static -o fpga/board/rv128_load fpga/rv128_load.c`
on the PC before `scp`.

## Debugging on silicon

Without a debug module the visibility is `RETIRED` (0x08) and `PC` (0x10). On a TIMEOUT
the loader prints both; compare `pc` with `sw/tests/<name>.sym` and run
`python3 iss128.py --trace sw/tests/<name>` to see what the ISS does there.
