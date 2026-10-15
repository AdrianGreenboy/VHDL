#!/usr/bin/env python3
"""mutate.py - mutaciones del RTL: cada una DEBE hacer fallar la regresion.
Una mutacion que sobrevive significa que la capa no prueba lo que dice."""
import os, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
T = lambda n: os.path.join(HERE, 'sw/tests', n)
STORM = os.path.join(HERE, 'sw/irq_storm')
IRQM = os.path.join(HERE, 'sw/irq_m')
RACE = os.path.join(HERE, 'sw/irq_race')
SWEEP = os.path.join(HERE, 'sw/csr_sweep')
MMU = os.path.join(HERE, 'sw/mmu_test')
VM = [T('rv64ui-v-sd'), T('rv64ua-v-amoor_d'), T('rv64si-p-dirty')]

# (nombre, fichero, original, mutado, tests, args de compare)
MUTS = [
  ('forward W antes que M', 'rv64_core.vhd',
   """      if exmem.v = '1' and exmem.exc = '0' and exmem.rd_we = '1' and exmem.rd = idex.d.rs1 then fa := exmem.res; end if;""",
   """      if exmem.v = '1' and exmem.exc = '0' and exmem.rd_we = '1' and exmem.rd = idex.d.rs1 and wb_rf_we = '0' then fa := exmem.res; end if;""",
   [T('rv64ui-p-add')], []),
  ('sin espera de resultado tardio en M', 'rv64_core.vhd',
   """        late_dep := true;""", """        late_dep := false;""",
   [T('rv64ui-p-lb'), T('rv64ui-p-ld')], ['--maxlat', '6']),
  ('SC ignora la reserva', 'rv64_core.vhd',
   """    sc_ok := resv_v = '1' and resv_line = pa(63 downto 6);""",
   """    sc_ok := true;""", [T('rv64ua-p-lrsc')], []),
  ('MRET no restaura MIE', 'rv64_csr.vhd',
   """          prv <= mpp; mie_b <= mpie; mpie <= '1'; mpp <= PRV_U;""",
   """          prv <= mpp; mpie <= '1'; mpp <= PRV_U;""", [IRQM], []),
  ('irq no re-validada en W', 'rv64_core.vhd',
   """        if irq_pending = '1' then
          trap := true; irq := true; code := irq_code; tval := XZERO;""",
   """        if true then
          trap := true; irq := true; code := memwb.code; tval := XZERO;""", [RACE], []),
  ('c.j: bit 10 del offset cruzado', 'rv64_pkg.vhd',
   """(20 downto 11 => c(12)) & c(8) & c(10 downto 9)""", """(20 downto 11 => c(12)) & c(9) & c(10) & c(8)""",
   ['unit:tb_rvc', T('rv64uc-p-rvc')], []),
  ('signo del resto en division', 'rv64_muldiv.vhd',
   """                neg_r <= sa;""", """                neg_r <= sa xor sb;""", [T('rv64um-p-rem')], []),
  ('medeleg delega ecall-M', 'rv64_csr.vhd',
   """  constant MEDELEG_M: std_logic_vector(15 downto 0) := x"B3FE";""",
   """  constant MEDELEG_M: std_logic_vector(15 downto 0) := x"BBFE";""", [SWEEP], []),
  # ---- Paso 5: MMU
  ('SUM ignorado', 'rv64_mmu_pkg.vhd',
   """(acc = ACC_FETCH or sum = '0')""", """(acc = ACC_FETCH)""", [MMU], []),
  ('MXR ignorado', 'rv64_mmu_pkg.vhd',
   """ok := e.r = '1' or (mxr = '1' and e.x = '1');""", """ok := e.r = '1';""", [MMU], []),
  ('Svade: store con D=0 permitido', 'rv64_mmu_pkg.vhd',
   """ok := e.w = '1' and e.d = '1';""", """ok := e.w = '1';""", [T('rv64si-p-dirty'), MMU], []),
  ('TLB ignora el ASID', 'rv64_mmu_pkg.vhd',
   """    if e.g = '0' and e.asid /= asid then return false; end if;""", """""", [MMU], []),
  ('megapagina: bits de PA de la VA', 'rv64_mmu_pkg.vhd',
   """    if e.lvl /= "00" then pa(20 downto 12) := va(20 downto 12); end if;""",
   """    if e.lvl = "10" then pa(20 downto 12) := va(20 downto 12); end if;""", [MMU], []),
  ('sfence.vma no vacia las TLB', 'rv64_core.vhd',
   """  tlb_flush <= sfence_int;""", """  tlb_flush <= '0';""", [MMU] + VM, []),
  ('MPRV ignorado', 'rv64_core.vhd',
   """    if st_mprv = '1' and priv = PRV_M then effp := st_mpp; end if;""", """""", [MMU], []),
  ('PTW: megapagina desalineada aceptada', 'rv64_ptw.vhd',
   """                   (lvl = "01" and ppn(8 downto 0) /= (8 downto 0 => '0')) or a = '0' then""",
   """                   a = '0' then""", [MMU], []),
]

# Mutaciones de los Pasos 6-7 (caches, AXI, Zicbom, SoC). Se anaden a MUTS en mutate.py.
STRESS = os.path.join(HERE, 'sw/cache_stress')
SOCU = os.path.join(HERE, 'sw/soc_usart')
SOCD = os.path.join(HERE, 'sw/soc_dma')
SOCT = os.path.join(HERE, 'sw/soc_timer')
SOCP = os.path.join(HERE, 'sw/soc_plic')
AMOL = os.path.join(HERE, 'sw/amo_lanes')
CPU = ['--tb', 'cpu', '--timeout', '20000000']
SOC = ['--tb', 'soc', '--timeout', '2000000']
MUTS += [
  ('D$: store no marca la linea sucia', 'rv64_dcache.vhd',
   """              if r_kind /= "00" then dirty(hway)(i) <= '1'; end if;""", """""", [STRESS], CPU),
  ('D$: writeback a la direccion equivocada', 'rv64_dcache.vhd',
   """                wb_addr <= x"00000000" & '1' & t_q(v) & idx_of(r_addr) & "000000";""",
   """                wb_addr <= x"00000000" & '1' & tag_of(r_addr) & idx_of(r_addr) & "000000";""", [STRESS], CPU),
  ('D$: fence.i no limpia', 'rv64_dcache.vhd',
   """        if flush = '1' then flush_p <= '1'; end if;""", """""", [T('rv64ui-p-fence_i'), STRESS], CPU),
  ('I$: fence.i no invalida', 'rv64_icache.vhd',
   """        if inval = '1' or inval_p = '1' then""", """        if false then""", [T('rv64ui-p-fence_i'), STRESS], CPU),
  ('D$: AMO en el carril 0', 'rv64_dcache.vhd',
   """amo_calc(r_amo, r_size, d_q(hway), r_wdata, to_integer(unsigned(r_addr(2 downto 0))))""",
   """amo_calc(r_amo, r_size, d_q(hway), r_wdata, 0)""", [T('rv64ua-p-amoadd_w'), AMOL], CPU),
  ('AXI: rafaga de escritura de 7 beats', 'rv64_axi_master.vhd',
   """  m_awlen   <= x"07" when line_k else x"00";""", """  m_awlen   <= x"06" when line_k else x"00";""", [STRESS], CPU),
  ('Zicbom: cbo no escribe la linea sucia', 'rv64_dcache.vhd',
   """              if hit = '1' and dirty(hway)(i) = '1' then
                vic <= hway;""", """              if false then
                vic <= hway;""", [SOCD], SOC),
  ('PLIC: claim no limpia pendiente', 'rv64_plic.vhd',
   """              pending(best(0)) <= '0'; active(best(0)) <= '1';""", """              active(best(0)) <= '1';""", [SOCU], SOC),
  ('puente: mitad alta de 64 bit en la baja', 'rv64_periph.vhd',
   """              if hi then rd(63 downto 32) <= mm_word; else rd(31 downto 0) <= mm_word; end if;""",
   """              rd(31 downto 0) <= mm_word;""", [SOCU], SOC),
  ('puente: AW y W de AXI-Lite en el mismo ciclo', 'rv64_periph.vhd',
   """            if aw_done and w_done then aw_ok <= '0'; w_ok <= '0'; st <= L_B; end if;""",
   """            if l_awready = '1' and l_wready = '1' then aw_ok <= '0'; w_ok <= '0'; st <= L_B; end if;""",
   [SOCU], SOC),
  ('CLINT: mtimecmp decodificado en 0x8000', 'rv64_clint.vhd',
   """            when "0100000000000" =>               -- 0x4000""",
   """            when "1000000000000" =>               -- 0x4000""", [SOCT], SOC),
  ('CLINT: MTIP con > en vez de >=', 'rv64_clint.vhd',
   """  mtip <= '1' when mtime >= mtimecmp else '0';""",
   """  mtip <= '1' when mtime > mtimecmp else '0';""", [SOCT], SOC + ['--time-div', '100']),
  ('PLIC: claim de ctx1 devuelve el de ctx0', 'rv64_plic.vhd',
   """      if best(1) /= 0 and pending(best(1)) = '1' then v := std_logic_vector(to_unsigned(best(1), 32)); end if;""",
   """      if best(0) /= 0 and pending(best(0)) = '1' then v := std_logic_vector(to_unsigned(best(0), 32)); end if;""", [SOCP], SOC),
  ('PLIC: umbral con >= en vez de >', 'rv64_plic.vhd',
   """          if c(0)(7 downto 5) > thresh(ctx) then""",
   """          if c(0)(7 downto 5) >= thresh(ctx) then""", [SOCP], SOC),
]


def main():
    work = os.environ.get('MUT_WORK', os.path.join(HERE, 'sim_mut'))
    survived = 0
    sel = [m for m in MUTS if not sys.argv[1:] or any(k in m[0] for k in sys.argv[1:])]
    for name, f, a, b, tests, args in sel:
        shutil.rmtree(work, ignore_errors=True)
        os.makedirs(work)
        rtl = os.path.join(work, 'rtl'); shutil.copytree(os.path.join(HERE, 'rtl'), rtl)
        p = os.path.join(rtl, f); s = open(p).read()
        assert a in s, f'mutacion no aplicable: {name}'
        open(p, 'w').write(s.replace(a, b))
        shutil.copytree(os.path.join(HERE, 'tb'), os.path.join(work, 'tb'))
        sim = os.path.join(work, 'sim'); os.makedirs(sim)
        shutil.copy(os.path.join(HERE, 'sim', 'build.sh'), sim)
        env = dict(os.environ)
        env.setdefault('IP_CORES', os.path.dirname(HERE))      # el IP_Cores que contiene RV64IMAC
        b = subprocess.run([os.path.join(sim, 'build.sh')], cwd=sim, capture_output=True, env=env)
        if b.returncode != 0 or not os.path.exists(os.path.join(sim, 'tb_soc')):
            print((b.stdout + b.stderr).decode(errors='replace')[-1500:])
            sys.exit(f'build del mutante fallo ({name}): no se puede juzgar la mutacion')
        killed, first = False, []
        for u in [t for t in tests if t.startswith('unit:')]:
            vec = {'tb_rvc': 'rvc_vectors.txt', 'tb_muldiv': 'muldiv_vectors.txt'}[u[5:]]
            ru = subprocess.run([os.path.join(sim, u[5:]), f'-gVECTORS={os.path.join(HERE, "sim", vec)}'],
                                cwd=sim, capture_output=True, text=True)
            if ru.returncode != 0 or 'PASS' not in ru.stdout + ru.stderr:
                killed, first = True, ['FAIL', u]
        elfs = [t for t in tests if not t.startswith('unit:')]
        if not killed and elfs:
            r = subprocess.run([sys.executable, os.path.join(HERE, 'compare.py')] + args + elfs,
                               env=dict(os.environ, RV64_SIM=sim, RV64_HOME=HERE), capture_output=True, text=True)
            killed = r.returncode != 0
            first = next((l for l in r.stdout.splitlines() if not l.startswith('PASS')), '').split()
        survived += not killed
        print(f'{"MUERTA " if killed else "VIVA!! "} {name:38} -> {" ".join(first[:2])}')
    shutil.rmtree(work, ignore_errors=True)
    print(f'mutaciones={len(sel)} sobreviven={survived}')
    sys.exit(1 if survived else 0)

if __name__ == '__main__':
    main()
