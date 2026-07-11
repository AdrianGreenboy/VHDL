#!/usr/bin/env python3
# iss_ptp_pdelay.py — modelo de referencia de meanPathDelay.
# Replica ptp_pdelay.vhd: TS -> ns totales signed (sec*1e9+ns), corr>>16,
# ((t4-t1)-corr_ns)//2 con floor. Todo signed 64b.

def to_s64(v):
    v &= (1 << 64) - 1
    if v & (1 << 63): v -= (1 << 64)
    return v

def ts_to_ns(sec, ns):
    return sec * 1_000_000_000 + ns

def mean_path_delay(t1_sec, t1_ns, t4_sec, t4_ns, corr_field):
    t1 = ts_to_ns(t1_sec, t1_ns)
    t4 = ts_to_ns(t4_sec, t4_ns)
    d41 = t4 - t1
    corr_s = to_s64(corr_field)          # correctionField interpretado signed 64b
    corr_ns = corr_s >> 16               # 2^-16 ns -> ns, floor (shift aritmetico)
    diff = d41 - corr_ns
    return diff >> 1                      # /2 floor

if __name__ == "__main__":
    rows = []
    def case(tag, t1s, t1n, t4s, t4n, corr):
        d = mean_path_delay(t1s, t1n, t4s, t4n, corr)
        rows.append((tag, d))
        return d

    # caso loopback realista: round trip pequeno, residence pequeno.
    # t1=1000ns, t4=1400ns (round trip 400ns), corr=100ns residence
    # corr en 2^-16 ns: 100 * 65536 = 6553600
    case("LOOP", 0, 1000, 0, 1400, 100*65536)      # (400-100)/2 = 150
    # cruce de segundo: t1 en sec=0 ns=999_999_900, t4 en sec=1 ns=300
    # t4-t1 = (1e9+300)-(999999900) = 400 ; corr=0 -> 200
    case("XSEC", 0, 999_999_900, 1, 300, 0)        # 200
    # residence mayor que round trip -> delay negativo (caso patologico)
    case("NEG", 0, 1000, 0, 1200, 400*65536)       # (200-400)/2 = -100
    # corr con parte fraccionaria (no multiplo de 65536): 150.5 ns
    # 150.5 * 65536 = 9863168 ; >>16 = 150 (floor)
    case("FRAC", 0, 2000, 0, 2600, 9863168)        # (600-150)/2 = 225
    # delay cero exacto
    case("ZERO", 0, 5000, 0, 5200, 200*65536)      # (200-200)/2 = 0

    with open("ref_pdelay.csv", "w") as f:
        for tag, d in rows:
            f.write(f"{tag},{d}\n")
    for r in rows:
        print(r)
