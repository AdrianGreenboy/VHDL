#!/usr/bin/env python3
"""HERCOSSNUX Core 21 - ETH GT: pruebas de mutacion.

Cada mutacion introduce un fallo plausible en el RTL nuevo; la regresion
completa (sim/run_layers.sh) debe FALLAR con cada una. Se ejecutan en copias
del repo, varias en paralelo.

    python3 sim/run_mutations.py [-j 4] [-m M01,M07,...]
"""
import concurrent.futures as cf
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CORE = os.path.dirname(HERE)
IPC = os.path.dirname(CORE)

M = [
    ("M01 gen: id IPv4 sin byte swap", "rtl/eth21_udp_gen.vhd",
     "be16(cur_seq(15 downto 0)) & be16(cur_tl)", "cur_seq(15 downto 0) & be16(cur_tl)"),
    ("M02 gen: checksum sin segundo plegado", "rtl/eth21_udp_gen.vhd",
     "f2 := resize(c2_f(15 downto 0), 17) + resize(c2_f(16 downto 16), 17);",
     "f2 := resize(c2_f(15 downto 0), 17);"),
    ("M03 gen: udp_len = tot_len", "rtl/eth21_udp_gen.vhd",
     "c1_ul <= resize(n_len, 16) + 8;", "c1_ul <= resize(n_len, 16) + 28;"),
    ("M04 gen: vuelta del barrido en 11 bits", "rtl/eth21_udp_gen.vhd",
     "nxt := resize(n_len, 12) + resize(lstep_c, 12);",
     "nxt := resize(n_len + lstep_c, 12);"),
    ("M05 gen: P1 sin semilla", "rtl/eth21_udp_gen.vhd",
     "p <= seed_of(cur_seq);", "p <= xorshift64(p);"),
    ("M06 gen: tkeep de la ultima palabra +1", "rtl/eth21_udp_gen.vhd",
     "c2_lastn <= resize(fb(2 downto 0), 4) + 1;", "c2_lastn <= resize(fb(2 downto 0), 4) + 2;"),
    ("M07 gen: gap ignorado", "rtl/eth21_udp_gen.vhd",
     "elsif c_gap /= 0 then", "elsif false then"),
    ("M08 chk: checksum no comprobado", "rtl/eth21_udp_chk.vhd",
     "if wf(7) = '1' and ck_rx /= ck_e then hdr := '1'; end if;", "null;"),
    ("M09 chk: id no comprobado", "rtl/eth21_udp_chk.vhd",
     "if id_r /= seq_now(15 downto 0) then hdr := '1'; end if;", "null;"),
    ("M10 chk: longitud no comprobada", "rtl/eth21_udp_chk.vhd",
     "if x_tot /= tl14 then bad := '1'; end if;", "null;"),
    ("M11 bl: lock con 63", "rtl/eth21_blocklock.vhd",
     "elsif sh_cnt = 63 then\n            lock_r <= '1';", "elsif sh_cnt = 62 then\n            lock_r <= '1';"),
    ("M12 bl: pierde lock con 15", "rtl/eth21_blocklock.vhd",
     "if not shv and inv_cnt = 15 then", "if not shv and inv_cnt = 14 then"),
    ("M13 gtmap: cabecera TX sin cruzar", "rtl/eth21_gtmap.vhd",
     "txheader(0) <= blk(0) when hdr_swap = '1' else blk(1);",
     "txheader(0) <= blk(1) when hdr_swap = '1' else blk(0);"),
    ("M14 gtmap: bit_rev RX ignorado", "rtl/eth21_gtmap.vhd",
     "blk(2 + i) <= rxdata(63 - i) when bit_rev = '1' else rxdata(i);",
     "blk(2 + i) <= rxdata(i);"),
    ("M15 rx: bloques sin lock al MAC", "rtl/eth21_rxpath.vhd",
     "b_v   <= i_v and lock and not rst;", "b_v   <= i_v and not rst;"),
    ("M16 rx: LF solo en 0x4B", "rtl/eth21_rxpath.vhd",
     "((pr_pl(7 downto 0) = x\"2D\" or pr_pl(7 downto 0) = x\"55\") and\n            pr_pl(63 downto 36) = x\"0100000\")",
     "false"),
    ("M17 gtrst: timeout RX reinicia todo", "rtl/eth21_gt_rst.vhd",
     "              rx <= step(rx, rx_alive, rd2);",
     "              rx <= step(rx, rx_alive, rd2);\n              if rx.st = P_DONE and rx.cnt = 0 then cs <= C_PG; end if;"),
    ("M18 gtrst: userrdy sin esperar reloj", "rtl/eth21_gt_rst.vhd",
     "        if alive = '1' then\n          n.st := P_USR;", "        if true then\n          n.st := P_USR;"),
    ("M19 top: contador 19 mal mapeado", "rtl/eth21_top.vhd",
     "when 16 to 22 => return x(32*(i-4)+31 downto 32*(i-4));",
     "when 16 to 22 => return x(32*(i-3)+31 downto 32*(i-3));"),
    ("M20 top: CMD no espera al RX", "rtl/eth21_top.vhd",
     "and (ack_rx = '1' or a_cmd_ack_rx = '1') then", "then"),
    ("M21 clkmeter: la cuenta no se reinicia por ventana", "rtl/eth21_clkmeter.vhd",
     "        edges <= (others => '0');\n", ""),
]


def run(m):
    name, f, a, b = m
    tmp = tempfile.mkdtemp(prefix="eth21mut_")
    try:
        for d in ("ETH_GT", "MAC_25G", "PCS_25G"):
            shutil.copytree(os.path.join(IPC, d), os.path.join(tmp, d),
                            ignore=shutil.ignore_patterns("eth_soc_*", "*.pdi", "petalinux*"))
        p = os.path.join(tmp, "ETH_GT", f)
        src = open(p).read()
        if src.count(a) != 1:
            return name, "MUTACION NO APLICABLE (%d apariciones)" % src.count(a)
        open(p, "w").write(src.replace(a, b))
        r = subprocess.run(["bash", os.path.join(tmp, "ETH_GT/sim/run_layers.sh"),
                            os.path.join(tmp, "w")], capture_output=True, text=True, timeout=1800)
        fails = [l for l in r.stdout.splitlines() if "FAIL " in l]
        if r.returncode != 0:
            return name, "DETECTADA (%s)" % (fails[0].strip()[:90] if fails else "compilacion")
        return name, "NO DETECTADA"
    except subprocess.TimeoutExpired:
        return name, "DETECTADA (timeout)"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    j = int(sys.argv[sys.argv.index("-j") + 1]) if "-j" in sys.argv else 4
    only = sys.argv[sys.argv.index("-m") + 1].split(",") if "-m" in sys.argv else None
    sel = [m for m in M if only is None or m[0].split()[0] in only]
    res = []
    with cf.ThreadPoolExecutor(j) as ex:
        for name, r in ex.map(run, sel):
            print("%-45s %s" % (name, r), flush=True)
            res.append(r)
    det = sum(r.startswith("DETECTADA") for r in res)
    print("\nMUTACIONES: %d/%d detectadas" % (det, len(sel)))
    sys.exit(0 if det == len(sel) else 1)


if __name__ == "__main__":
    main()
