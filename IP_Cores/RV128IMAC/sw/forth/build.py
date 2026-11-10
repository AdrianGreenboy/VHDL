#!/usr/bin/env python3
"""build.py - build RV128 Forth images and run them on the ISS.

  build.py [--uart-div N] [--max STEPS] [--no-run] [--out DIR] script.fs ...
Each script is linked after the libraries (lib/core, bignum, fixed, conc) into its own
image DIR/<name>.bin/.sym/.S. With no --no-run, every image runs on iss128 and must end in
PASS; when <script>.expect exists, every line in it must appear on the console.
An empty script list builds the interactive image (libraries only, then the UART).
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LIBS = [os.path.join(HERE, "lib", f) for f in ("core.fs", "bignum.fs", "fixed.fs", "conc.fs")]


def build(script, out, div):
    name = os.path.splitext(os.path.basename(script))[0] if script else "forth"
    pre = os.path.join(out, name)
    scripts = LIBS + ([script] if script else [])
    subprocess.run([sys.executable, os.path.join(HERE, "gen_forth.py"), pre + ".S",
                    "--uart-div", str(div), "--script", *scripts], check=True)
    subprocess.run([sys.executable, os.path.join(ROOT, "rv128asm.py"), pre + ".S", "-o", pre + ".bin",
                    "--sym", pre + ".sym"], check=True)
    return pre


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scripts", nargs="*")
    ap.add_argument("--uart-div", type=int, default=1)
    ap.add_argument("--max", type=int, default=50_000_000)
    ap.add_argument("--no-run", action="store_true")
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    sys.path.insert(0, ROOT)
    import iss128
    fails = 0
    for s in a.scripts or [None]:
        pre = build(s, a.out, a.uart_div)
        if a.no_run or s is None:
            print(f"built   {pre}.bin  ({os.path.getsize(pre + '.bin')} bytes)")
            continue
        code, hart = iss128.run_flat(pre + ".bin", pre + ".sym", a.max)
        con = bytes(hart.bus.uart_out + hart.bus.console).decode(errors="replace")
        ok = code == 0
        exp = os.path.splitext(s)[0] + ".expect"
        missing = []
        if os.path.exists(exp):
            missing = [l for l in open(exp).read().splitlines() if l and l not in con]
            ok = ok and not missing
        open(pre + ".log", "w").write(con)
        verdict = "PASS" if ok else ("TIMEOUT" if code is None else f"FAIL(code {code})")
        print(f"{verdict:16} {os.path.basename(pre):12} retired={hart.minstret}")
        if not ok:
            fails += 1
            print("---- console tail ----\n" + con[-1500:])
            for m in missing:
                print("missing expected text:", m[:80])
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
