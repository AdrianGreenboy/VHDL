# MIPI CSI-2 RX — Block Design build guide (step by step)

Run `build_bd.tcl` **one STEP at a time** in the Vivado Tcl console. After each,
read the console before continuing. This mirrors the hard-won lesson that Versal
BD commands fail silently when pasted in bulk.

## Prerequisites
- Project created via `create_project.tcl` (RTL loaded, VHDL-2008, Verilog wrapper as top).
- Elaboration passed (0 errors, 0 critical warnings).

## STEP 1 — create BD
```
create_bd_design mipi_soc_bd
```
Expected: returns the BD path. If "already exists", `open_bd_design` instead.

## STEP 2 — CIPS
```
create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0
```
Then the `set_property PS_PMC_CONFIG {...}`. Expected: cell appears; the config
sets PL clock 100 MHz, one fabric reset, M_AXI_FPD, one PL→PS IRQ.
Sanity: `get_bd_cells versal_cips_0` returns the cell.

## STEP 3 — NoC with 3 slave ports (CIPS + 2 PL masters) → shared DDR MC
```
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_0
```
Then `NUM_SI 3`, `NUM_CLKS 4`, and the per-interface `CONNECTIONS {MC_0 {...}}`.
Expected: `S00_AXI`, `S01_AXI`, `S02_AXI` slave interfaces exist, all associated
to `MC_0`. This is the critical anti–Connection-Automation step: we bind the PL
masters to the same DDR MC as the CIPS explicitly.
Sanity: `get_bd_intf_pins axi_noc_0/S02_AXI` exists.

## STEP 4 — SoC module reference
```
create_bd_cell -type module -reference soc_top_mipi_wrap soc_top_mipi_wrap_0
```
Expected: hierarchical module-ref cell. If it errors with "cannot find module",
the Verilog wrapper isn't compiled — check the wrapper is the current top and
`update_compile_order` ran.

## STEP 5 — SmartConnect (M_AXI_FPD full → AXI-Lite)
```
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_0
set_property -dict {CONFIG.NUM_SI 1 CONFIG.NUM_MI 1} [get_bd_cells smartconnect_0]
```

## STEP 6 — Processor System Reset + xlconstant '1'
```
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant xlconstant_1
set_property -dict {CONFIG.CONST_VAL 1 CONFIG.CONST_WIDTH 1} [get_bd_cells xlconstant_1]
```
Reason: `pl0_resetn` is asynchronous; the PSReset synchronizes it. `dcm_locked`
must be tied to '1' (no MMCM lock signal available here).

## STEP 7 — clocks
Connect `pl0_ref_clk` to: PSReset `slowest_sync_clk`, SoC `aclk`, SmartConnect
`aclk`, and NoC `aclk1/aclk2/aclk3` (the PL-domain NSI clocks). `aclk0` is the
CIPS/PS NoC clock and is wired by the CIPS DDR interface automation.
Expected: each `connect_bd_net` returns without error. If a NoC aclk pin doesn't
exist, re-check `NUM_CLKS` in STEP 3.

## STEP 8 — resets
```
connect pl0_resetn        -> proc_sys_reset_0/ext_reset_in
connect xlconstant_1/dout -> proc_sys_reset_0/dcm_locked
connect peripheral_aresetn -> soc_top_mipi_wrap_0/aresetn AND smartconnect_0/aresetn
```

## STEP 9 — control path (PS → core)
```
CIPS/M_AXI_FPD -> smartconnect_0/S00_AXI
smartconnect_0/M00_AXI -> soc_top_mipi_wrap_0/s_axi
```

## STEP 10 — data path (2 masters → NoC → DDR)
```
CIPS/FPD_CCI_NOC_0            -> axi_noc_0/S00_AXI   (PS DDR)
soc_top_mipi_wrap_0/m_axi    -> axi_noc_0/S01_AXI   (core DMA)
soc_top_mipi_wrap_0/mipi_axi -> axi_noc_0/S02_AXI   (MIPI DMA)
```
NOTE: the exact CIPS→NoC master interface name may differ by CIPS preset
(`FPD_CCI_NOC_0`, `FPD_AXI_NOC_0`, or via the CIPS "Add NoC" flow). Run
`get_bd_intf_pins versal_cips_0/*NOC*` to find the actual DDR master interface,
then connect it to S00_AXI.

## STEP 11 — interrupt
```
soc_top_mipi_wrap_0/irq_out -> versal_cips_0/pl_ps_irq0
```

## STEP 12 — addresses
```
assign_bd_address
report_bd_address
```
CHECK: the AXI-Lite slave (`soc_top_mipi_wrap_0/s_axi`) must be at 0xA400_0000.
0x8000_0000 is NOT a valid M_AXI_FPD aperture on Versal. If it landed elsewhere,
force the segment offset to 0xA4000000.
CHECK: the DDR aperture the two PL masters see. The firmware programs
axil_soc DDR_BASE (0x70000000) as the physical DDR base; this MUST equal the DDR
base the NoC exposes to S01/S02. If the NoC assigns DDR low at 0x0 or a different
aperture, either (a) change the firmware DDR_PHYS_LO to match, or (b) set the DDR
segment base so the masters see 0x70000000. Confirm with `report_bd_address`.

## STEP 13 — validate + wrapper
```
validate_bd_design      ;# expect 0 errors, 0 critical warnings
save_bd_design
make_wrapper ...        ;# generate the BD wrapper as top
```

## Common failure modes (from prior cores)
- Connection Automation routed a PL master to `S_AXI_LPD` (no DDR): never accept
  it; wire to a dedicated NoC NSI as in STEP 10.
- `save_project_as` clone leaves the BD as a remote reference: use
  `write_bd_tcl`, remove the remote `.bd`, rebuild in the new project.
- An out-of-context `synth_design` silently changes the project top: after any
  OOC synth, restore `set_property top mipi_soc_bd_wrapper [current_fileset]`.
- Versal BRAM primitive is `RAMB18E5_INT` (filter reports with `REF_NAME`).
