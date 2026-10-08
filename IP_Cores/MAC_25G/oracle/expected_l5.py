#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Palabras esperadas que el firmware deja en DDR+0x40 (capa 5, sim y silicio).
#
#   python3 expected_l5.py [N] [fichero_salida]
#     N = 64      -> fw_rv32_sim (SIM_FAST), tb_soc_mac
#     N = 100000  -> fw_rv32 (silicio), ps/mac_selftest
# Formato de salida: una palabra hex por linea; la palabra 16 (BURST_CYCLES)
# no es determinista y se escribe como XXXXXXXX.
# =============================================================================
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mac25g_oracle as o   # noqa: E402

ORDER = ["tx_frames", "tx_bytes", "rx_ok", "rx_bytes", "rx_crc_err", "rx_runt",
         "rx_oversize", "rx_abort", "rx_filtered", "rx_proto", "chk_ok",
         "chk_bad", "chk_seq_err", "chk_rxerr"]
STATUS_DONE = 0x11D     # LINK_UP | GEN_DONE | RX_ACTIVE | TX_ACTIVE | SNAP_DONE
IRQ_INJ = 0x3           # GEN_DONE | RX_CRC_ERR
FLAGS_OK = 0x3F


def expected(n):
    cfg = o.GenCfg(len_min=20, len_max=1514, len_step=37, count=n)
    clean = o.expected_counters(cfg, n)
    inj = o.expected_counters(cfg, n, inject=True)
    w = [0x4D414320, STATUS_DONE] + [clean[k] for k in ORDER]
    w += [None]                                   # BURST_CYCLES
    w += [inj["rx_ok"], inj["rx_crc_err"], inj["chk_rxerr"],
          inj["chk_seq_err"] | (inj["chk_bad"] << 16), IRQ_INJ]
    sig = o.fnv1a32([x for i, x in enumerate(w) if i != 16])
    w += [sig, FLAGS_OK]
    return w, clean


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 64
    w, clean = expected(n)
    lines = ["XXXXXXXX" if x is None else "%08X" % x for x in w]
    if len(sys.argv) > 2:
        open(sys.argv[2], "w").write("\n".join(lines) + "\n")
    # Rendimiento. Dos cifras distintas, no confundirlas:
    #  * eficiencia del MAC: bytes L2+FCS por ranura de bloque (8 bytes). En
    #    25GBASE-R real (390.625 Mbloques/s) eso son eff * 25.0 Gb/s de
    #    L2+FCS. El ideal 802.3 (preambulo 8 + IPG 12) es F/(F+20).
    #  * banco de silicio: gearbox de fabric 66->64 a 390.625 MHz (Core 19):
    #    32 bloques cada 33 ciclos = 25.0 Gb/s serie equivalente (no 25.78).
    slots = clean["slots"]
    eff = clean["tx_bytes"] / (slots * 8.0)
    ideal = clean["tx_bytes"] / float(clean["tx_bytes"] + 20 * n)
    cyc = slots * 33 / 32
    bench = clean["tx_bytes"] * 8 / (cyc / 390.625e6) / 1e9
    line = clean["tx_bytes"] * 8 / (slots / 390.625e6) / 1e9
    print("N=%d firma=0x%08X tx_bytes=%d slots=%d" % (n, w[22], clean["tx_bytes"], slots))
    print("  MAC: %.2f%% de las ranuras con L2+FCS -> %.2f Gb/s en 25GBASE-R "
          "(ideal 802.3 %.2f Gb/s, el MAC logra el %.1f%% del ideal)" %
          (100 * eff, 25.0 * eff, 25.0 * ideal, 100 * eff / ideal))
    print("  build por defecto (GEARBOX=false, 66 b/ciclo como un GT): ciclos ~%d "
          "-> %.2f Gb/s" % (slots, line))
    print("  GEARBOX=true (gearbox de fabric del Core 19): ciclos ~%.0f -> %.2f Gb/s" %
          (cyc, bench))


if __name__ == "__main__":
    main()
