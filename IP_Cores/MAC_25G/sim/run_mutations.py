#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Pruebas de mutacion: cada mutacion introduce un defecto realista en la RTL
# y DEBE hacer fallar el testbench indicado. Si alguna sobrevive, el
# testbench no cubre esa clase de defecto.
#
#   python3 sim/run_mutations.py [workdir]
# Requiere haber pasado sim/run_layers.sh (reutiliza sus vectores).
# =============================================================================
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PCS = os.path.normpath(os.path.join(HERE, "..", "PCS_25G", "rtl"))
W = sys.argv[1] if len(sys.argv) > 1 else "/tmp/mac25g_mut"
VEC = "/tmp/mac25g_sim/vec"

PCS_FILES = ["pcs_scrambler.vhd", "pcs_gearbox_tx.vhd", "pcs_gearbox_rx.vhd",
             "pcs_tx_datapath.vhd", "pcs_rx_datapath.vhd", "pcs_mmio_bridge.vhd"]
MAC_FILES = ["mac25g_pkg.vhd", "mac25g_pcs_tx.vhd", "mac25g_gen.vhd",
             "mac25g_tx.vhd", "mac25g_rx.vhd", "mac25g_chk.vhd",
             "mac25g_datapath.vhd", "mac25g_sync.vhd", "mac25g_top.vhd"]
TB_FILES = ["tb_mac_pkg.vhd", "tb_mac_pcs_tx.vhd", "tb_mac_tx.vhd",
            "tb_mac_rx.vhd", "tb_mac_chk.vhd", "tb_mac_datapath.vhd",
            "tb_mac_top.vhd", "tb_mac_sync.vhd"]

L3B = ["-gVEC=l3_l3b.txt", "-gINJ=true"]
TXB = ["-gVEC=tx_txb.txt", "-gLEN_MIN=20", "-gLEN_MAX=90", "-gSTEP=1", "-gNFR=71"]

# (id, descripcion, fichero, texto original, texto mutado, tb, generics, PASS)
MUTS = [
    ("M01", "polinomio CRC alterado", "mac25g_pkg.vhd",
     'x"EDB88320"', 'x"EDB88321"', "tb_mac_pkg", [], "LAYER1A_PASS"),
    ("M02", "tipo T3 erroneo (0xB4->0xB5)", "mac25g_pkg.vhd",
     'when 3 => t := x"B4";', 'when 3 => t := x"B5";', "tb_mac_tx", [], "LAYER2A_PASS"),
    ("M03", "un solo hueco tras la trama (IPG corto)", "mac25g_tx.vhd",
     "when SA_GAP1 =>\n            a_st <= SA_GAP2;",
     "when SA_GAP1 =>\n            a_st <= SA_IDLE;", "tb_mac_tx", [], "LAYER2A_PASS"),
    ("M04", "padding: umbral de la 8a palabra", "mac25g_tx.vhd",
     "(wcnt = 7 and n >= 4)", "(wcnt = 7 and n >= 3)", "tb_mac_tx", TXB, "LAYER2A_PASS"),
    ("M05", "FCS sin complementar", "mac25g_tx.vhd",
     "c_fcs  <= not crc_nbytes(b_crc, b_data, b_n);",
     "c_fcs  <= crc_nbytes(b_crc, b_data, b_n);", "tb_mac_tx", [], "LAYER2A_PASS"),
    ("M06", "inyeccion en el bloque de datos 0", "mac25g_tx.vhd",
     "if dblk = 1 and inj_arm = '1' then", "if dblk = 0 and inj_arm = '1' then",
     "tb_mac_tx", ["-gVEC=tx_txc.txt", "-gNFR=16", "-gINJ=true"], "LAYER2A_PASS"),
    ("M07", "residuo CRC RX erroneo", "mac25g_pkg.vhd",
     'x"DEBB20E3"', 'x"DEBB20E2"', "tb_mac_rx", [], "LAYER2B_PASS"),
    ("M08", "strip de FCS desplazado", "mac25g_rx.vhd",
     "elsif r5_ab = '1' or r5_n > 4 then", "elsif r5_ab = '1' or r5_n > 5 then",
     "tb_mac_rx", [], "LAYER2B_PASS"),
    ("M09", "filtro ignora broadcast", "mac25g_rx.vhd",
     'r2_d(47 downto 0) = x"FFFFFFFFFFFF"', 'r2_d(47 downto 0) = x"FFFFFFFFFFFE"',
     "tb_mac_rx", [], "LAYER2B_PASS"),
    ("M10", "aborto no marcado", "mac25g_rx.vhd",
     "r2_last <= '1'; r2_ab <= '1'; h_v <= '0';", "r2_last <= '1'; h_v <= '0';",
     "tb_mac_rx", [], "LAYER2B_PASS"),
    ("M11", "limite oversize 1522->1534", "mac25g_pkg.vhd",
     "MAX_FRAME     : natural := 1522;", "MAX_FRAME     : natural := 1534;",
     "tb_mac_rx", [], "LAYER2B_PASS"),
    ("M12", "checker no avanza el patron", "mac25g_chk.vhd",
     "p <= xorshift64(p);\n            rem_r", "p <= p;\n            rem_r",
     "tb_mac_datapath", [], "LAYER3_PASS"),
    ("M13", "checker sin comprobar longitud", "mac25g_chk.vhd",
     "if x_tot /= lexp then bad := '1'; end if;", "null;",
     "tb_mac_chk", [], "LAYER2C_PASS"),
    ("M17", "checker no exige padding a cero", "mac25g_chk.vhd",
     "e(8*b+7 downto 8*b) := x\"00\";", "null;",
     "tb_mac_chk", [], "LAYER2C_PASS"),
    ("M14", "prediccion de ready del PCS TX", "mac25g_pcs_tx.vhd",
     "if f2 <= 64 then rdy_r", "if f2 <= 66 then rdy_r",
     "tb_mac_pcs_tx", [], "LAYER1B_PASS"),
    ("M15", "inyeccion no llega al cable", "mac25g_tx.vhd",
     "pl(0) := not pl(0);", "pl(0) := pl(0);",
     "tb_mac_datapath", L3B, "LAYER3_PASS"),
    ("M16", "secuencia del generador salta", "mac25g_gen.vhd",
     "seq   <= seq + 1;", "seq   <= seq + 2;",
     "tb_mac_datapath", [], "LAYER3_PASS"),
    ("M18", "CMD sin retener mientras hay otro en vuelo", "mac25g_top.vhd",
     "not (s_axi_awaddr(7 downto 2) = \"000011\" and cmd_busy = '1')", "true",
     "tb_mac_top", [], "LAYER4_PASS"),
    ("M19", "evento IRQ con toggle simple (sin handshake)", "mac25g_sync.vhd",
     "if busy = '1' and a2 = req then busy <= '0'; end if;", "busy <= '0';",
     "tb_mac_sync", [], "LAYER1C_PASS"),
]


def run(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def main():
    if not os.path.isdir(VEC):
        sys.exit("faltan vectores: ejecuta antes sim/run_layers.sh")
    survivors = 0
    for mid, desc, fname, old, new, tb, gens, pas in MUTS:
        d = os.path.join(W, mid)
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(os.path.join(d, "work"))
        srcs = []
        for f in PCS_FILES:
            srcs.append(os.path.join(PCS, f))
        for f in MAC_FILES:
            src = os.path.join(HERE, "rtl", f)
            if f == fname:
                txt = open(src).read()
                cnt = txt.count(old)
                if cnt != 1:
                    sys.exit("%s: el patron aparece %d veces en %s" % (mid, cnt, f))
                dst = os.path.join(d, f)
                open(dst, "w").write(txt.replace(old, new))
                srcs.append(dst)
            else:
                srcs.append(src)
        srcs += [os.path.join(HERE, "tb", f) for f in TB_FILES]
        gf = ["--std=08", "--workdir=" + os.path.join(d, "work")]
        rc, out = run(["ghdl", "-a"] + gf + srcs, d)
        if rc == 0:
            rc, out = run(["ghdl", "-e"] + gf + [tb], d)
        if rc == 0:
            rc, out = run(["ghdl", "-r"] + gf + [tb] + gens, VEC)
        killed = (pas not in out)
        verdict = "MUERTA" if killed else "SOBREVIVE"
        if not killed:
            survivors += 1
        why = ""
        m = re.search(r"(LAYER\w*FAIL[^\n]*|FAIL[^\n]{0,60}|MISMATCH[^\n]{0,50}|"
                      r"failure[^\n]{0,60}|TIMEOUT[^\n]{0,40})", out)
        if m:
            why = m.group(1)
        print("  %s %-10s %-42s -> %s" % (mid, verdict, desc, why[:70]))
    print("== %d/%d mutaciones detectadas ==" % (len(MUTS) - survivors, len(MUTS)))
    sys.exit(1 if survivors else 0)


if __name__ == "__main__":
    main()
