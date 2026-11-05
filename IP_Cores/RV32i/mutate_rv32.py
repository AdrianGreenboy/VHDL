#!/usr/bin/env python3
"""mutate_rv32.py - audit-2026-11 mutation check for the RV32i regression.

Every mutation re-introduces one of the fixed defects (or breaks one of the
new mechanisms) in a scratch copy of this folder; the listed run_ghdl.sh
targets MUST then fail. A surviving mutation means the corresponding test
does not check what it claims.

Usage: python3 mutate_rv32.py [name-substring ...]
Env:   GHDL (default ghdl), MUT_WORK (default: a temp dir)
"""
import os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

# (name, file, original, mutated, targets, extra env)
MUTS = [
  ('EX exceptions not trapped', 'cpu_pipeline.vhd',
   "(id_ex.ctrl.is_ecall = '1' or id_ex.ctrl.is_ebreak = '1' or ex_exc = '1'))",
   "(id_ex.ctrl.is_ecall = '1' or id_ex.ctrl.is_ebreak = '1'))", ['exc'], {}),
  ('unknown SYSTEM imm executes as NOP', 'control.vhd',
   "            when others      => c.is_illegal := '1';",
   "            when others      => null;", ['exc'], {}),
  ('unknown opcode executes as NOP', 'control.vhd',
   "      when others =>                        -- unknown opcode (incl. 16-bit RVC)\n        c.is_illegal := '1';",
   "      when others =>\n        null;", ['exc'], {}),
  ('CSR write attempt keyed on value, not rs1 field', 'cpu_pipeline.vhd',
   "csr_rs1z <= '1' when id_ex.rs1_addr = \"00000\" else '0';",
   "csr_rs1z <= '0';", ['exc'], {}),
  ('unimplemented CSR accepted', 'csr.vhd',
   "    if (not known) or (csr_addr(11 downto 10) = \"11\" and wr) then",
   "    if (csr_addr(11 downto 10) = \"11\" and wr) then", ['exc'], {}),
  ('mtval not written on trap', 'csr.vhd',
   "          mtval        <= trap_tval;", "", ['exc'], {}),
  ('no misaligned check', 'riscv_pkg.vhd',
   "      when \"01\"   => return a(0) = '1';      -- half: 2-byte aligned\n      when others => return a /= \"00\";       -- word: 4-byte aligned",
   "      when others => return false;", ['exc'], {}),
  ('load-use stall wins over trap redirect', 'cpu_pipeline.vhd',
   "    elsif any_redirect = '1' then\n      -- before stall_lu",
   "    elsif stall_lu = '1' then\n      pc_d <= pc;\n    elsif any_redirect = '1' then\n      -- before stall_lu",
   ['exc'], {}),
  ('single-cycle: faulting instr still writes rd', 'cpu.vhd',
   "  reg_we_g <= '1' when (ctrl.reg_we = '1' and do_commit = '1') else '0';",
   "  reg_we_g <= '1' when (ctrl.reg_we = '1' and commit = '1') else '0';", ['exc'], {}),
  ('bus error ignored by the core', 'cpu_pipeline.vhd',
   "  mem_fault <= '1' when (mem_access = '1' and ld_first = '0' and dmem_ready = '1' and\n                         dmem_err = '1') else '0';",
   "  mem_fault <= '0';", ['bus_err'], {}),
  ('AXI RRESP/BRESP ignored', 'axi4_master.vhd',
   "              err_q   <= m_axi_rresp(1);        -- SLVERR (10) / DECERR (11)", "", ['bus_err'], {}),
  ('faulting load writes back', 'cpu_pipeline.vhd',
   "          -- and every younger instruction is squashed (precise trap)\n          mem_wb   <= MEMWB_NOP;",
   "          -- and every younger instruction is squashed (precise trap)\n          mem_wb   <= memwb_next;",
   ['bus_err'], {}),
  ('DMEM_SYNC: no address cycle', 'cpu_pipeline.vhd',
   "  ld_first  <= '1' when (DMEM_SYNC and ex_mem.mem_re = '1' and ld_wait = '0') else '0';",
   "  ld_first  <= '0';", ['difftest', 'lw_hazard_reg'], {'DT_MODES': 'true', 'DT_ITERS': '10', 'SYNC_MODES': 'true'}),
  ('IMEM_SYNC: current pc on the SRAM', 'cpu_pipeline.vhd',
   "  imem_addr <= pc_d when IMEM_SYNC else pc;", "  imem_addr <= pc;",
   ['pipeline'], {'SYNC_MODES': 'true'}),
  ('lw hazard fix removed (no WB history forwarding)', 'cpu_pipeline.vhd',
   "           wbh_data      when (wbh_we = '1' and wbh_addr /= \"00000\" and\n                               wbh_addr = id_ex.rs1_addr) else",
   "", ['lw_hazard_reg'], {}),
  ('DMA: no look-ahead with sync local RAM', 'dma_burst.vhd',
   "  loc_idx_rd <= loc_idx + 1 when (SYNC_LOC and state = W_DATA and m_axi_wready = '1')\n                else loc_idx;",
   "  loc_idx_rd <= loc_idx;", ['dma'], {}),
  ('DMA: BRESP/RRESP ignored', 'dma_burst.vhd',
   "              if m_axi_rresp(1) = '1' then err_q <= '1'; end if;", "", ['dma'], {}),
  ('axil_soc: no address cycle for sync RAM', 'axil_soc.vhd',
   "              if MEM_SYNC then rstate <= R_ADDR; else rstate <= R_DATA; end if;",
   "              rstate <= R_DATA;", ['boot_rom'], {'SYNC_MODES': 'true'}),
  ('axil_soc: read and write overlap again', 'axil_soc.vhd',
   "  s_axi_awready <= '1' when (wstate = W_IDLE and rstate = R_IDLE and\n"
   "                             s_axi_awvalid = '1' and s_axi_wvalid = '1') else '0';\n"
   "  s_axi_wready  <= s_axi_awready;\n"
   "  s_axi_arready <= '1' when (rstate = R_IDLE and wstate = W_IDLE and s_axi_arvalid = '1' and\n"
   "                             not (s_axi_awvalid = '1' and s_axi_wvalid = '1')) else '0';",
   "  s_axi_awready <= '1' when (wstate = W_IDLE and s_axi_awvalid = '1' and s_axi_wvalid = '1') else '0';\n"
   "  s_axi_wready  <= s_axi_awready;\n"
   "  s_axi_arready <= '1' when (rstate = R_IDLE and s_axi_arvalid = '1') else '0';", ['boot_rom'], {}),
  ('boot loader: no zero fill', 'boot_loader.vhd',
   "  wstrb <= \"1111\" when (busy_q = '1' and idx < DEPTH) else \"0000\";",
   "  wstrb <= \"1111\" when (busy_q = '1' and idx < BOOT_ROM'length) else \"0000\";", ['boot_rom'], {}),
  ('load-use stall on any field match', 'cpu_pipeline.vhd',
   "                         ((ctrl_id.use_rs1 = '1' and id_ex.rd_addr = rs1a) or\n                          (ctrl_id.use_rs2 = '1' and id_ex.rd_addr = rs2a))",
   "                         ((id_ex.rd_addr = rs1a) or (id_ex.rd_addr = rs2a))", ['lu_stall'], {}),
  ('stale accel_sumsq image (doorbell word 127)', 'accel_sumsq.s',
   "        sw   x11, 260(x0)     # DMEM[65] = 1 (listo)",
   "        sw   x11, 508(x0)     # DMEM[65] = 1 (listo)", ['accel'], {'REASM': '1'}),
]

def main():
    sel = [m for m in MUTS if not sys.argv[1:] or any(k in m[0] for k in sys.argv[1:])]
    base = os.environ.get('MUT_WORK') or tempfile.mkdtemp(prefix='rv32_mut_')
    survived = 0
    for name, f, a, b, targets, env_x in sel:
        src = os.path.join(base, 'src')
        shutil.rmtree(src, ignore_errors=True)
        shutil.copytree(HERE, src, ignore=shutil.ignore_patterns('vivado', 'docs', 'sw', '*.log'))
        p = os.path.join(src, f); s = open(p).read()
        assert s.count(a) == 1, f'mutation not applicable: {name}'
        open(p, 'w').write(s.replace(a, b))
        if env_x.get('REASM'):
            subprocess.run([sys.executable, os.path.join(src, 'asm.py'), p, p[:-2] + '.mem'],
                           capture_output=True, check=True)
        env = dict(os.environ, WORK=os.path.join(base, 'work'), **{k: v for k, v in env_x.items() if k != 'REASM'})
        shutil.rmtree(env['WORK'], ignore_errors=True)
        r = subprocess.run([os.path.join(src, 'run_ghdl.sh')] + targets, env=env,
                           capture_output=True, text=True)
        killed = r.returncode != 0
        first = next((l.strip() for l in r.stdout.splitlines() if '[FAIL]' in l), '')
        survived += not killed
        print(f'{"KILLED " if killed else "SURVIVED"} {name:50} {first[:70]}', flush=True)
    shutil.rmtree(base, ignore_errors=True)
    print(f'mutations={len(sel)} survived={survived}')
    sys.exit(1 if survived else 0)

if __name__ == '__main__':
    main()
