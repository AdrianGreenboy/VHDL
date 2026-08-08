#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera el testbench VHDL de Layer 2a (data plane aislado, mono-reloj) desde la
traza canonica de pcs_stats_oracle.py.

El testbench:
  * instancia pcs_dataplane (generics LOCK_THRESHOLD=64, HIBER_THRESHOLD=16)
  * reproduce la traza: 'run' -> pulsos blk_evt; 'cmd' -> pulsos de comando;
    'snap' -> captura shadow en el testbench; 'rd_*' -> acumula firma
  * implementa el snapshot y la lectura de shadow en el propio TB (la logica
    de snapshot/CDC real se prueba en L2b), reproduciendo el contrato del oraculo
  * calcula la firma FNV-1a 32-bit y la compara con la golden

Fuente unica de verdad: la traza del oraculo.
Uso: python3 gen_tb_stats.py > ../rtl/tb_pcs_dataplane.vhd
"""
import importlib.util
import os

# Resolver la ruta del oraculo relativa a ESTE script, no al directorio de
# trabajo actual, para que funcione desde cualquier sitio.
_HERE = os.path.dirname(os.path.abspath(__file__))
_ORACLE_PATH = os.path.join(_HERE, "pcs_stats_oracle.py")
spec = importlib.util.spec_from_file_location("o2", _ORACLE_PATH)
o = importlib.util.module_from_spec(spec); spec.loader.exec_module(o)

GOLDEN = o.run(o.canonical_trace())

# Reejecutar la traza para capturar, en cada operacion, lo que el TB debe hacer.
def build():
    dp = o.DataPlane()
    stim = []
    pat_map = {'idle': None, 'tx': 'tx', 'rx_ok': 'rx_ok',
               'rx_bad': 'rx_bad', 'prbs_bad': 'prbs_bad'}
    evt_code = {None: 0, 'tx': 1, 'rx_ok': 2, 'rx_bad': 3, 'prbs_bad': 4}
    for op in o.canonical_trace():
        k = op[0]
        if k == 'run':
            _, pat, n = op
            blk = pat_map[pat]
            for _ in range(n):
                dp.tick(blk)
            enc = (o.fnv1a_32(pat.encode('ascii')) ^ (n & o.MASK32)) & o.MASK32
            stim.append({"op": "run", "code": evt_code[blk], "n": n, "enc": enc})
        elif k == 'cmd':
            name = op[1]
            getattr(dp, 'cmd_' + name)()
            stim.append({"op": "cmd", "name": name,
                         "enc": o.fnv1a_32(name.encode('ascii'))})
        elif k == 'snap':
            dp.snapshot()
            stim.append({"op": "snap"})
        elif k == 'rd_cnt':
            stim.append({"op": "rd_cnt",
                         "vals": [dp.sh_tx, dp.sh_rx, dp.sh_rxerr, dp.sh_ber, dp.sh_lockt]})
        elif k == 'rd_status':
            stim.append({"op": "rd_status", "val": dp.status_word()})
        elif k == 'rd_irq':
            stim.append({"op": "rd_irq", "val": dp.sticky & o.IRQ_MASK})
        elif k == 'clr_irq':
            dp.clear_sticky(op[1])
            stim.append({"op": "clr_irq", "mask": op[1] & o.IRQ_MASK})
    return stim, dp

STIM, FINAL = build()

def hx(v): return "x\"%08X\"" % (v & o.MASK32)

L = []
def w(s=""): L.append(s)

w("-- AUTO-GENERADO por gen_tb_stats.py desde pcs_stats_oracle.py")
w("-- NO EDITAR A MANO. Firma golden esperada: 0x%08X" % GOLDEN)
w("library ieee;")
w("use ieee.std_logic_1164.all;")
w("use ieee.numeric_std.all;")
w("")
w("entity tb_pcs_dataplane is end entity;")
w("")
w("architecture sim of tb_pcs_dataplane is")
w("  constant GOLDEN : unsigned(31 downto 0) := %s;" % hx(GOLDEN))
w("  constant FNV_OFFSET : unsigned(31 downto 0) := x\"811C9DC5\";")
w("  constant FNV_PRIME  : unsigned(31 downto 0) := x\"01000193\";")
w("")
w("  signal clk : std_logic := '0';")
w("  signal rst : std_logic := '1';")
w("  signal blk_evt : std_logic_vector(2 downto 0) := \"000\";")
w("  signal c_clear, c_sreset, c_resync, c_prbsr : std_logic := '0';")
w("  signal cnt_tx, cnt_rx, cnt_rxerr, cnt_ber, lockt : std_logic_vector(31 downto 0);")
w("  signal s_lock, s_scr, s_prbs, s_hiber, s_txa, s_rxa : std_logic;")
w("  signal e_lg, e_ll, e_hb, e_re, e_pe : std_logic;")
w("")
w("  -- shadow y sticky reproducidos en el TB (contrato del oraculo)")
w("  signal sh_tx, sh_rx, sh_rxerr, sh_ber, sh_lockt : std_logic_vector(31 downto 0) := (others=>'0');")
w("  signal sticky : std_logic_vector(5 downto 0) := (others=>'0');")
w("  signal clr_mask : std_logic_vector(5 downto 0) := (others=>'0');")
w("  signal clr_stb  : std_logic := '0';")
w("  signal dma_done_stb : std_logic := '0';")
w("")
w("  signal sig : unsigned(31 downto 0) := FNV_OFFSET;")
w("")
w("  procedure fnv_byte(signal h : inout unsigned(31 downto 0); b : integer) is")
w("    variable hv : unsigned(31 downto 0); variable pr : unsigned(63 downto 0);")
w("  begin")
w("    hv := h xor to_unsigned(b mod 256, 32); pr := hv * FNV_PRIME;")
w("    h <= pr(31 downto 0);")
w("  end procedure;")
w("")
w("begin")
w("  clk <= not clk after 1.28 ns;  -- ~390.625 MHz")
w("")
w("  dut: entity work.pcs_dataplane")
w("    generic map (LOCK_THRESHOLD => 64, HIBER_THRESHOLD => 16)")
w("    port map (")
w("      clk_dp=>clk, rst_dp=>rst, blk_evt=>blk_evt,")
w("      cmd_cnt_clear=>c_clear, cmd_soft_reset=>c_sreset,")
w("      cmd_resync=>c_resync, cmd_prbs_reset=>c_prbsr,")
w("      cnt_tx_blk=>cnt_tx, cnt_rx_blk=>cnt_rx, cnt_rx_err=>cnt_rxerr,")
w("      cnt_ber=>cnt_ber, lock_time=>lockt,")
w("      st_block_lock=>s_lock, st_scr_sync=>s_scr, st_prbs_lock=>s_prbs,")
w("      st_hi_ber=>s_hiber, st_tx_active=>s_txa, st_rx_active=>s_rxa,")
w("      ev_lock_gained=>e_lg, ev_lock_lost=>e_ll, ev_hi_ber=>e_hb,")
w("      ev_rx_err=>e_re, ev_prbs_err=>e_pe);")
w("")
w("  -- captura de stickies: UNICO driver de sticky (evita X por doble driver)")
w("  sticky_proc: process(clk)")
w("    variable nx : std_logic_vector(5 downto 0);")
w("  begin")
w("    if rising_edge(clk) then")
w("      if rst = '1' then sticky <= (others=>'0');")
w("      else")
w("        nx := sticky;")
w("        if clr_stb = '1' then nx := nx and not clr_mask; end if;")
w("        if e_lg = '1' then nx(0) := '1'; end if;")
w("        if e_ll = '1' then nx(1) := '1'; end if;")
w("        if e_hb = '1' then nx(2) := '1'; end if;")
w("        if e_re = '1' then nx(3) := '1'; end if;")
w("        if e_pe = '1' then nx(4) := '1'; end if;")
w("        if dma_done_stb = '1' then nx(5) := '1'; end if;")
w("        sticky <= nx;")
w("      end if;")
w("    end if;")
w("  end process;")
w("")
w("  stim: process")
w("    variable v_st : std_logic_vector(7 downto 0);")
w("")
w("    procedure acc_u32(v : std_logic_vector(31 downto 0)) is")
w("    begin")
w("      fnv_byte(sig, to_integer(unsigned(v(7 downto 0))));   wait for 0 ns;")
w("      fnv_byte(sig, to_integer(unsigned(v(15 downto 8))));  wait for 0 ns;")
w("      fnv_byte(sig, to_integer(unsigned(v(23 downto 16)))); wait for 0 ns;")
w("      fnv_byte(sig, to_integer(unsigned(v(31 downto 24)))); wait for 0 ns;")
w("    end procedure;")
w("    procedure acc_byte(b : integer) is")
w("    begin fnv_byte(sig, b); wait for 0 ns; end procedure;")
w("")
w("    procedure pulse_evt(code : integer; n : integer) is")
w("    begin")
w("      for i in 1 to n loop")
w("        wait until rising_edge(clk);")
w("        blk_evt <= std_logic_vector(to_unsigned(code, 3));")
w("      end loop;")
w("      wait until rising_edge(clk);")
w("      blk_evt <= \"000\";")
w("    end procedure;")
w("")
w("  begin")
w("    rst <= '1'; wait for 10 ns; wait until rising_edge(clk); rst <= '0';")
w("    wait until rising_edge(clk);")
w("")

for s in STIM:
    if s["op"] == "run":
        w("    -- run code=%d n=%d" % (s["code"], s["n"]))
        w("    pulse_evt(%d, %d);" % (s["code"], s["n"]))
        w("    acc_byte(0); acc_u32(%s);" % hx(s["enc"]))
    elif s["op"] == "cmd":
        cmap = {"cnt_clear":"c_clear", "soft_reset":"c_sreset",
                "resync":"c_resync", "prbs_reset":"c_prbsr", "dma_done":None}
        sig_name = cmap.get(s["name"], None)
        w("    -- cmd %s" % s["name"])
        if sig_name:
            w("    wait until rising_edge(clk); %s <= '1';" % sig_name)
            w("    wait until rising_edge(clk); %s <= '0';" % sig_name)
        else:
            # dma_done: strobe hacia el proceso unico de sticky
            w("    wait until rising_edge(clk); dma_done_stb <= '1';")
            w("    wait until rising_edge(clk); dma_done_stb <= '0';")
        w("    wait until rising_edge(clk);")
        w("    acc_byte(1); acc_u32(%s);" % hx(s["enc"]))
    elif s["op"] == "snap":
        w("    -- snap")
        w("    wait until rising_edge(clk);")
        w("    sh_tx <= cnt_tx; sh_rx <= cnt_rx; sh_rxerr <= cnt_rxerr;")
        w("    sh_ber <= cnt_ber; sh_lockt <= lockt;")
        w("    wait until rising_edge(clk);")
        w("    acc_byte(2); acc_u32(x\"00000000\");")
    elif s["op"] == "rd_cnt":
        vals = s["vals"]
        w("    -- rd_cnt esperado tx,rx,rxerr,ber = (%d,%d,%d,%d); lockt=%d no-firmado" % (vals[0],vals[1],vals[2],vals[3],vals[4]))
        w("    assert sh_tx = %s report \"CNT tx mismatch\" severity error;" % hx(vals[0]))
        w("    assert sh_rx = %s report \"CNT rx mismatch\" severity error;" % hx(vals[1]))
        w("    assert sh_rxerr = %s report \"CNT rxerr mismatch\" severity error;" % hx(vals[2]))
        w("    assert sh_ber = %s report \"CNT ber mismatch\" severity error;" % hx(vals[3]))
        # lock_time se observa pero no se firma (timestamp absoluto)
        w("    acc_byte(3); acc_u32(sh_tx);")
        w("    acc_byte(3); acc_u32(sh_rx);")
        w("    acc_byte(3); acc_u32(sh_rxerr);")
        w("    acc_byte(3); acc_u32(sh_ber);")
    elif s["op"] == "rd_status":
        w("    -- rd_status esperado 0x%02X" % s["val"])
        w("    wait until rising_edge(clk);")
        w("    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;")
        w("    assert unsigned(v_st) = to_unsigned(%d,8) report \"STATUS mismatch got 0x\" & to_hstring(v_st) & \" exp 0x%02X\" severity error;" % (s["val"], s["val"]))
        w("    acc_byte(4);")
        w("    acc_u32(x\"000000\" & v_st);")
    elif s["op"] == "rd_irq":
        w("    -- rd_irq esperado 0x%02X" % s["val"])
        w("    wait until rising_edge(clk);")
        w("    assert unsigned(sticky) = to_unsigned(%d,6) report \"IRQ mismatch got 0x\" & to_hstring(sticky) & \" exp 0x%02X\" severity error;" % (s["val"], s["val"]))
        w("    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));")
    elif s["op"] == "clr_irq":
        w("    -- clr_irq mask=0x%02X" % s["mask"])
        w("    wait until rising_edge(clk);")
        w("    clr_mask <= std_logic_vector(to_unsigned(%d, 6)); clr_stb <= '1';" % s["mask"])
        w("    wait until rising_edge(clk); clr_stb <= '0';")
        w("    wait until rising_edge(clk);")
        w("    acc_byte(6); acc_u32(std_logic_vector(to_unsigned(%d, 32)));" % s["mask"])

# cierre
w("")
w("    -- cierre: estado final (lock_time excluido de la firma)")
w("    acc_u32(sh_tx); acc_u32(sh_rx); acc_u32(sh_rxerr); acc_u32(sh_ber);")
w("    acc_byte(to_integer(unsigned'('0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock)));")
w("    acc_byte(to_integer(unsigned(sticky)));")
w("    wait for 1 ns;")
w("    if sig = GOLDEN then")
w("      report \"LAYER2A_PASS FNV32=0x\" & to_hstring(sig) severity note;")
w("    else")
w("      report \"LAYER2A_FAIL FNV32=0x\" & to_hstring(sig) & \" GOLDEN=0x\" & to_hstring(GOLDEN) severity error;")
w("    end if;")
w("    wait;")
w("  end process;")
w("end architecture;")

print("\n".join(L))
