# MIPI CSI-2 RX — Silicon bring-up runbook (L5)

End-to-end sequence to take the validated RTL to silicon on the TE0950. Run on
`adrian@adrian`. Each stage has a checkpoint; do not proceed past a failed check.

## 0. Layout
```
~/vhdl_repo/IP_Cores/MIPI/
  rtl/    all .vhd + soc_top_mipi_wrap.v
  fw/     fw_rv32.c, fw_ps.c, build_fw_rv32.sh
  verif/  oracle + testbenches (L1..L5)
  petalinux/
  doc/
```

## 1. Build the RV32 firmware binary
```
cd ~/vhdl_repo/IP_Cores/MIPI/fw
bash build_fw_rv32.sh
```
CHECK: `fw_rv32.bin` produced, ≤ 4 KB.

## 2. Create the Vivado project
```
vivado -mode batch -source ~/vhdl_repo/IP_Cores/MIPI/rtl/create_project.tcl
```
CHECK: elaboration 0 errors, 0 critical warnings.

## 3. Build the Block Design — INTERACTIVE, one STEP at a time
Open the project GUI (or Tcl console) and follow `BD_GUIDE.md`, running each STEP
of `build_bd.tcl` individually and reading the console.
CHECK per step as documented; final `validate_bd_design` = 0 errors.

Key checks:
- AXI-Lite slave at 0xA4000000 (not 0x80000000).
- Both PL masters bound to the shared DDR MC via dedicated NoC NSI (S01/S02),
  NOT via Connection Automation.
- DDR aperture the masters see == firmware DDR_PHYS_LO (0x70000000). Reconcile
  in STEP 12 if they differ.

## 4. Synthesis + implementation + XSA
```
vivado -mode batch -source ~/vhdl_repo/IP_Cores/MIPI/rtl/synth_impl.tcl
```
CHECK: framebuffers mapped to RAMB18E5_INT (not FFs).
CHECK: WNS ≥ 0 at 100 MHz. If negative, drop PL clock to 50 MHz in CIPS, re-run.
CHECK: `mipi_soc.xsa` exported.

## 5. PetaLinux
```
cd ~/vhdl_repo/IP_Cores/MIPI/petalinux
bash build_petalinux.sh
```
CHECK: `images/linux/BOOT.BIN` and `image.ub` produced.
Reminder: DDR buffer reserved no-map at 0x70000000; app uses volatile /dev/mem.

## 6. SD card + boot
- Copy `BOOT.BIN` + `image.ub` to the SD boot (FAT) partition.
- ext4 partition auto-mounts at `/run/media/mmcblk1p2`.
- Insert SD, power on, connect serial: `picocom -b 115200 /dev/ttyUSB0` (8N1).

## 7. Run the self-test on silicon
At the Linux console:
```
mipiverify /lib/firmware/fw_rv32.bin
```
Expected output:
```
loaded N firmware words
doorbell  : fired (...)
signature : 0xE6898DC5 (golden 0xE6898DC5)
hdr_2bit  : 0
L5 SILICON PASS
```

## PASS criterion (Layer 5)
`signature == 0xE6898DC5` on real silicon == the same bit-identical FNV that L1–L4
and the Python oracle produced. That closes the five-layer methodology.

## If it fails
- `signature = 0x811C9DC5` (FNV init): nothing folded — check the MIPI decode at
  0xD0000000 reached the core (dmem routing), and that the self-test ran (poll
  STATUS.selftest_done).
- doorbell never fires: check DONE_WORD write reaches done_pulse (ADDR_W/DONE_WORD
  generics match), and irq wiring (STEP 11).
- signature wrong but non-init: DMA/DDR path — confirm DDR_BASE (PS-programmed)
  matches the NoC DDR aperture, and the core DMA (local→DDR) wrote the result at
  DDR_RESULT_OFF.
- Never hot-load the impl PDI over a configured PL (PLM 0x03024001): always the
  repackaged BOOT.BIN.
```
