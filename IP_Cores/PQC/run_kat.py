#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC - Phase 0 KAT runner
# Validates the Python oracles (mlkem768.py, mldsa65.py) against the embedded
# subset of NIST ACVP vectors (FIPS 203 / FIPS 204, internalProjection).
# PASS criterion: every case matches AND the end-of-run signature is
# bit-identical. The signature is a SHA-256 over computed outputs only
# (data-dependent, never cycle-count-dependent): rejection loops make cycle
# counts non-portable, so signatures hash data, not time. This rule is frozen
# for all five verification layers of the PQC IP.
# =============================================================================
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "oracle"))
import mlkem768 as kem
import mldsa65 as dsa

acc = hashlib.sha256()
total = 0


def check(cond, name, tcid):
    if not cond:
        print("PQC PHASE0 ORACLE FAIL %s tcId=%d" % (name, tcid))
        sys.exit(1)


def main():
    global total
    vec = json.load(open(os.path.join(HERE, "verif", "vectors",
                                      "acvp_subset.json")))

    for t in vec["kem_keygen"]:
        ek, dk = kem.mlkem_keygen_internal(bytes.fromhex(t["d"]),
                                           bytes.fromhex(t["z"]))
        check(ek.hex() == t["ek"].lower() and dk.hex() == t["dk"].lower(),
              "kem_keygen", t["tcId"])
        acc.update(ek + dk)
        total += 1

    for t in vec["kem_encaps"]:
        k, c = kem.mlkem_encaps_internal(bytes.fromhex(t["ek"]),
                                         bytes.fromhex(t["m"]))
        check(k.hex() == t["k"].lower() and c.hex() == t["c"].lower(),
              "kem_encaps", t["tcId"])
        acc.update(k + c)
        total += 1

    for t in vec["kem_decaps"]:
        k = kem.mlkem_decaps_internal(bytes.fromhex(t["dk"]),
                                      bytes.fromhex(t["c"]))
        check(k.hex() == t["k"].lower(), "kem_decaps", t["tcId"])
        acc.update(k)
        total += 1

    for t in vec["dsa_keygen"]:
        pk, sk = dsa.keygen_internal(bytes.fromhex(t["seed"]))
        check(pk.hex() == t["pk"].lower() and sk.hex() == t["sk"].lower(),
              "dsa_keygen", t["tcId"])
        acc.update(pk + sk)
        total += 1

    for t in vec["dsa_siggen_det_pure"]:
        sk = bytes.fromhex(t["sk"])
        msg = bytes.fromhex(t["message"])
        if t["iface"] == "external":
            sig = dsa.sign(sk, msg, bytes.fromhex(t["context"]))
        else:
            sig = dsa.sign_internal(sk, msg, bytes(32))
        check(sig.hex() == t["signature"].lower(), "dsa_siggen", t["tcId"])
        acc.update(sig)
        total += 1

    for t in vec["dsa_sigver_pure"]:
        pk = bytes.fromhex(t["pk"])
        msg = bytes.fromhex(t["message"])
        sig = bytes.fromhex(t["signature"])
        if t["iface"] == "external":
            res = dsa.verify(pk, msg, sig, bytes.fromhex(t["context"]))
        else:
            res = dsa.verify_internal(pk, msg, sig)
        check(res == t["testPassed"], "dsa_sigver", t["tcId"])
        acc.update(bytes([1 if res else 0]))
        total += 1

    print("PQC PHASE0 ORACLE PASS cases=%d sig=%s"
          % (total, acc.hexdigest()[:16]))


if __name__ == "__main__":
    main()
