#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo del top-level integrado (Layer 4): cadena completa del silicon pass.

Compone la cadena de loopback que valida TODO el PCS en el silicon pass:

  PRBS31 gen -> TX datapath (scrambler + gearbox) -> [loopback paralelo]
             -> RX datapath (gearbox + descrambler) -> PRBS31 checker

Como scrambler/descrambler forman round-trip perfecto y gearbox TX/RX tambien,
la cadena es transparente al patron PRBS: el checker recupera el PRBS original y
debe reportar BER = 0 tras la sincronizacion en cascada de todos los bloques.

Este oraculo verifica la PROPIEDAD end-to-end: BER = 0 en la cadena limpia, y
BER > 0 si se inyecta un error en el loopback. No es una firma bit-identica de
temporizado (la cascada tiene latencias de settling), sino la verificacion de
que la cadena completa es transparente y el checker detecta corrupcion.

Reutiliza los modelos de scrambler, gearbox y prbs ya validados.
Python 3.
"""

import sys, os, importlib.util

_HERE = os.path.dirname(os.path.abspath(__file__))
def _load(n):
    spec = importlib.util.spec_from_file_location(n, os.path.join(_HERE, n + ".py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

prbs_mod = _load("pcs_prbs_oracle")
dp_mod   = _load("pcs_datapath_oracle")

MASK64 = (1 << 64) - 1


def run_chain(inject_at=None, nwords=200):
    """
    Ejecuta la cadena completa:
      PRBS gen -> TX datapath -> loopback -> RX datapath -> PRBS checker
    inject_at: indice de palabra de loopback donde inyectar 1 bit error (o None).
    Devuelve (ber_total, palabras_checked).
    """
    gen = prbs_mod.Prbs31Gen()
    tx  = dp_mod.PcsTxDatapath()
    rx  = dp_mod.PcsRxDatapath()
    chk = prbs_mod.Prbs31Chk()

    ber = 0
    checked = 0
    loop_idx = 0

    for i in range(nwords):
        # 1. PRBS31 genera un payload de 64 bits
        payload = gen.gen64()
        # 2. TX datapath: el PRBS entra como payload (is_data=True)
        words = tx.push(payload, is_data=True)
        # 3. loopback: cada palabra del TX va al RX (con posible inyeccion)
        for wd in words:
            if inject_at is not None and loop_idx == inject_at:
                wd = wd ^ (1 << 0)   # inyectar 1 bit
            loop_idx += 1
            # 4. RX datapath: recupera (payload, is_data)
            for (rec_payload, is_data) in rx.push(wd):
                # 5. PRBS checker: verifica el payload recuperado
                err = chk.check64(rec_payload)
                ber += err
                checked += 1

    return ber, checked


def run(dump=False):
    # cadena limpia: BER debe ser 0 (tras sincronizacion en cascada)
    ber_clean, checked_clean = run_chain(inject_at=None)

    # cadena con inyeccion: BER debe ser > 0
    ber_inj, checked_inj = run_chain(inject_at=50)

    ok_clean = (ber_clean == 0)
    ok_inj   = (ber_inj > 0)

    if dump:
        print("cadena limpia : BER=%d sobre %d palabras (esperado 0)" % (ber_clean, checked_clean))
        print("cadena inyect.: BER=%d sobre %d palabras (esperado >0)" % (ber_inj, checked_inj))
        print("transparencia end-to-end:", ok_clean)
        print("deteccion de corrupcion :", ok_inj)

    return ok_clean, ok_inj, ber_clean, ber_inj, checked_clean


def main():
    dump = "--dump" in sys.argv
    ok_c, ok_i, bc, bi, nc = run(dump=dump)
    if not ok_c:
        print("ADVERTENCIA: BER no cero en cadena limpia (%d)" % bc, file=sys.stderr)
    if not ok_i:
        print("ADVERTENCIA: la inyeccion no fue detectada", file=sys.stderr)
    print("TOPLEVEL_CHAIN clean_ber=%d inj_ber=%d checked=%d %s" %
          (bc, bi, nc, "OK" if (ok_c and ok_i) else "FAIL"))


if __name__ == "__main__":
    main()
