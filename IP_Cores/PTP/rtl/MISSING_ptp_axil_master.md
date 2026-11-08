# MISSING SOURCE: `ptp_axil_master.vhd`

**Status: file not in the repository. Action required from the owner.**

Until audit 2026-11, `PTP/rtl/ptp_axil_master.vhd` was a *symbolic link* to
`/home/adrian/rv32i/ptp_axil_master.vhd`, a path outside the repository. On any
other machine (CI, reviewers, the ASIC flow) the link dangles, so:

- `sim/run_regression.sh` failed at analysis time and ran **no** test at all;
- `sim/tb_ptp_axil_master.vhd` (core dmem -> `ptp_axil_master` -> `ptp_axil`
  -> `ptp_top` chain, the test of the silicon "one-transaction shift" bug)
  cannot be elaborated.

The dangling link was removed in the audit. The behaviour of the master was
**not** re-created: it is a silicon-validated block and inventing a
replacement would silently change what `tb_ptp_axil_master` verifies.

## What is known (from `INTEGRACION_OPCION_B.md` and the TB, not verified)

```vhdl
u_ptp_axil_master : entity work.ptp_axil_master
  port map (clk, aresetn, start, we, addr(15:0), wdata, rdata, ready,
            m_awaddr, m_awvalid, m_awready, m_wdata, m_wstrb, m_wvalid,
            m_wready, m_bresp, m_bvalid, m_bready, m_araddr, m_arvalid,
            m_arready, m_rdata, m_rresp, m_rvalid, m_rready);
```

## To recover

1. Copy the original from `~/rv32i/ptp_axil_master.vhd` (Adrian's workstation)
   into `PTP/rtl/` as a **regular file** (no symlink).
2. Add `$RTL/ptp_axil_master.vhd` and `tb_ptp_axil_master.vhd` back to the
   analysis list in `sim/run_regression.sh` and re-enable the
   `maestro AXIL (core)` check (both are marked `MISSING-FILE` there).
3. Note the audit change in `ptp_axil.vhd`: partial `WSTRB` (not `1111` and
   not `0000`) now returns **SLVERR** without writing. The master must drive
   `m_wstrb = "1111"` for register writes (the integration note derives
   `we` from `dmem_wstrb /= "0000"`, so a byte store from the core would now
   be refused instead of writing a garbled word).
4. Also delete this note.
