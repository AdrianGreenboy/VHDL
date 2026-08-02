# Vivado / PetaLinux flow scripts

Run order and notes for reproducing the silicon build.

## 1. `create_project.tcl`
Creates the Vivado project, loads the RV32 core sources (from
`~/vhdl_repo/IP_Cores/RV32i`) and the MIPI RTL as VHDL-2008, and sets the Verilog
wrapper `soc_top_mipi_wrap` as top.

```bash
vivado -mode batch -source scripts/create_project.tcl
```

## 2. Block Design
The silicon build reuses the **PQC (Core 17)** Block Design, which already boots
Linux on the TE0950. The procedure:

1. Export the PQC BD to Tcl: `write_bd_tcl /tmp/pqc_bd_reference.tcl`.
2. Transform PQC → MIPI:
   - `soc_top_pqc_wrap` → `soc_top_mipi_wrap`, `soc_pqc_0` → `soc_mipi_0`
   - design name → `mipi_soc_bd`
   - remove the PQC's second IRQ (`pqc_irq_out` → `pl_ps_irq1`)
   - NoC `NUM_SI` 7 → 8 **and** `NUM_CLKS` 7 → 8
   - add S07 (config, aclk7 assoc, `mipi_axi` → S07, DDR addresses)
3. Run inside the project **after** setting the board part:
   ```tcl
   set_param board.repoPaths [list $HOME/te0950_work/board_files]
   set_property board_part_repo_paths [list $HOME/te0950_work/board_files] [current_project]
   set_property board_part trenz.biz:te0950_23_1lse:part0:1.2 [current_project]
   source scripts/build_bd_mipi.tcl
   assign_bd_address -offset 0xA4000000 -range 0x00010000 \
     -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] \
     [get_bd_addr_segs soc_mipi_0/s_axi/reg0] -force
   validate_bd_design
   save_bd_design
   ```

`build_bd.tcl` (from-scratch reference) is kept for education; the silicon flow
used the PQC-adapted `build_bd_mipi.tcl`. See `../BD_GUIDE.md`.

## 3. `synth_impl.tcl`
Generates the BD wrapper, synthesizes, implements, checks timing (WNS was
+16.76 ns at 100 MHz), writes the device image (PDI) and exports the XSA to
`petalinux/mipi_soc.xsa`.

## 4. `build_petalinux.sh`
Reference PetaLinux flow. The silicon build instead cloned the PQC PetaLinux
project (`project-spec/` + `.petalinux` only), imported the MIPI XSA, reserved the
DDR buffer (`no-map` @ `0x70000000`), enabled the `mipi-selftest` app, built, and
repackaged BOOT.BIN. See `../RUNBOOK.md`.
