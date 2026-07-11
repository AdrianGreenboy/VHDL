#!/usr/bin/env python3
# iss_ptp_clock.py — modelo de referencia BIT-IDENTICO del reloj + servo PI.
# Replica ptp_clock.vhd / ptp_pkg.vhd exactamente: mismos anchos, mismos
# truncamientos aritmeticos (>>> = shift aritmetico con floor), mismo orden.
# Base extensible de iss_ptp.py (oraculo de capa 4).
#
# Convenios:
#   - sec: 48b unsigned ; ns: 32b unsigned [0,1e9) ; subns: 32b unsigned
#   - campo de fase = ns<<32 | subns ; INC nominal = 10<<32
#   - RATE_ADJ signed 32b ; acc signed 48b ; err signed 32b ns
#   - shift_right aritmetico de Python (>>) sobre int con signo YA es floor,
#     que es exactamente lo que hace shift_right(signed,...) en VHDL. Usamos
#     enteros ilimitados y saturamos EXPLICITAMENTE a los anchos declarados.

NS_PER_SEC = 1_000_000_000
SUBNS_W = 32
INC_NOM_PHASE = 10 << SUBNS_W          # 10 ns en campo de fase
PHASE_MASK = (1 << (32 + SUBNS_W)) - 1  # ns(32)+subns(32)

SEC_MASK = (1 << 48) - 1
NS_MASK  = (1 << 32) - 1

def sat_signed(v, n):
    lo = -(1 << (n-1))
    hi = (1 << (n-1)) - 1
    if v > hi: return hi
    if v < lo: return lo
    return v

class PtpClock:
    def __init__(self, shift_p=8, shift_i=12):
        self.SHIFT_P = shift_p
        self.SHIFT_I = shift_i
        self.reset()

    def reset(self):
        self.sec = 0
        self.ns = 0
        self.subns = 0
        self.rate_adj = 0      # signed 32b
        self.acc = 0           # signed 48b
        self.offset_applied = 0
        self._ov_d = 0    # registro para deteccion de flanco de offset_valid

    def _clk_tick(self, inc_subns_signed):
        # phase actual (>=0) + inc (signed). Clamp a 0 si negativa.
        phase = (self.ns << SUBNS_W) | self.subns
        phase = phase + inc_subns_signed
        if phase < 0:
            phase = 0
        phase &= PHASE_MASK  # el RTL toma NS_W+SUBNS_W bits del campo
        ns_v = (phase >> SUBNS_W) & NS_MASK
        subns_v = phase & ((1 << SUBNS_W) - 1)
        sec_v = self.sec
        if ns_v >= NS_PER_SEC:
            ns_v -= NS_PER_SEC
            sec_v = (sec_v + 1) & SEC_MASK
        return sec_v, ns_v, subns_v

    def tick(self, kp=0, ki=0, offset_err=0, offset_valid=0,
             role_slave=0, clr_servo=0, rst=0):
        """Un ciclo de core-clock. Orden IDENTICO al proceso VHDL."""
        if rst:
            self.reset()
            return
        # 1) avance del reloj
        inc_v = INC_NOM_PHASE + self.rate_adj
        sec_p, ns_p, subns_p = self._clk_tick(inc_v)
        self.sec, self.ns, self.subns = sec_p, ns_p, subns_p

        # limpieza por clr_servo
        if clr_servo:
            self.offset_applied = 0
            self.acc = 0
            self.rate_adj = 0

        # deteccion de flanco de offset_valid (evento, no nivel)
        rising = offset_valid and not self._ov_d
        self._ov_d = offset_valid

        # 2) error de offset (solo en el flanco de subida)
        if rising and role_slave:
            err = _to_signed(offset_err, 32)
            if self.offset_applied == 0 and clr_servo == 0:
                # salto unico sobre el valor recien avanzado (sec_p, ns_p)
                new_sec = sec_p
                new_ns = ns_p + err
                if new_ns >= NS_PER_SEC:
                    new_ns -= NS_PER_SEC
                    new_sec = (new_sec + 1) & SEC_MASK
                elif new_ns < 0:
                    new_ns += NS_PER_SEC
                    new_sec = (new_sec - 1) & SEC_MASK
                self.sec = new_sec & SEC_MASK
                self.ns = new_ns & NS_MASK
                self.offset_applied = 1
            elif self.offset_applied == 1:
                # PI de libro: integral acumula en alta resolucion (sin truncar
                # antes), se trunca solo al leer. Identico al RTL.
                p_term = (err * (kp & 0xFFFF)) >> self.SHIFT_P
                i_step = err * (ki & 0xFFFF)               # sin shift
                self.acc = sat_signed(self.acc + i_step, 48)
                rate_v = p_term + (self.acc >> self.SHIFT_I)
                self.rate_adj = sat_signed(rate_v, 32)

def _to_signed(v, n):
    v &= (1 << n) - 1
    if v & (1 << (n-1)):
        v -= (1 << n)
    return v


if __name__ == "__main__":
    # Genera el vector de referencia consumido por el testbench VHDL.
    # IMPORTANTE: el TB es dirigido por senal, asi que un pulso de control
    # (offset_valid) tiene UN ciclo de latencia delta antes de que el DUT lo
    # procese. El modelo lo refleja: para "aplicar" un pulso en el tick N, el
    # TB lo asigna en N-1. Aqui contamos los mismos AVANCES efectivos que el TB.
    #
    # Escenario determinista de bring-up (avances efectivos):
    #   fase A: 100 ticks libres -> ns=1000
    #   1 tick de latencia (offset_valid asignado, aun no aplicado) -> ns=1010
    #   fase B: 1 tick que aplica el SALTO (err=+1234) -> ns=2254, applied=1
    #   fase C: PI con error decreciente, cada 10 ticks un offset_valid
    # Este escenario es un ESPEJO LITERAL del proceso stim de tb_ptp_clock.vhd.
    # Mismo orden de estimulos, mismo conteo de ticks, misma deteccion de
    # flanco. Cada snapshot se toma en el MISMO punto que el check() del TB.
    clk = PtpClock(shift_p=8, shift_i=12)
    KP, KI = 0x0040, 0x0010     # 64, 16
    rows = []

    def snap(tag):
        # rate_adj y acc ya son signed en el modelo (sat_signed devuelve con
        # signo). Se escriben directos; el parser del TB maneja el '-'.
        rows.append((tag, clk.sec, clk.ns, clk.subns,
                     clk.rate_adj, clk.acc, clk.offset_applied))

    # El TB hace 101 steps en fase A (el primer step cae con rst aun alto por
    # delta => 100 avances efectivos). El ISS cuenta avances efectivos: 100.
    for _ in range(100):
        clk.tick(kp=KP, ki=KI)
    snap("A_end")                       # ns=1000, applied=0

    # fase B: el TB asigna offset_valid=1 y hace 2 steps. Primer step: flanco
    # de subida => procesa el salto. Segundo step: offset_valid sigue en 1 pero
    # ov_d ya es 1 => NO reprocesa (deteccion de flanco). Replicamos igual:
    clk.tick(offset_err=1234, offset_valid=1, role_slave=1, kp=KP, ki=KI)  # salto (flanco)
    clk.tick(offset_err=1234, offset_valid=1, role_slave=1, kp=KP, ki=KI)  # sin flanco: no-op de offset
    snap("B_jump")                      # ns=2254, applied=1

    # fase C: bucle identico al del TB. offset_valid=1 solo cuando i%10==0,
    # y como el ciclo siguiente vuelve a 0, cada uno es un flanco limpio.
    err = 200
    for i in range(300):
        ov = 1 if (i % 10 == 0) else 0
        e = err if ov else 0
        clk.tick(offset_err=e, offset_valid=ov, role_slave=1, kp=KP, ki=KI)
        if ov:
            err = err - err // 8
        if i in (49, 99, 149, 199, 249, 299):
            snap(f"C_{i}")

    # fase D: error NEGATIVO sostenido (esclavo adelantado -> frenar). Ejercita
    # el SIGNO del servo en ambos sentidos; sin esto una mutacion abs(err) pasa.
    # OJO: el decaimiento usa truncacion-a-cero (int(x/8)) para coincidir con la
    # division '/' de VHDL sobre negativos (Python // es floor y divergiria).
    errn = -180
    for i in range(200):
        ov = 1 if (i % 10 == 0) else 0
        e = errn if ov else 0
        clk.tick(offset_err=e & 0xFFFFFFFF, offset_valid=ov, role_slave=1,
                 kp=KP, ki=KI)
        if ov:
            errn = errn - int(errn / 8)   # trunc-a-cero, como VHDL '/'
        if i in (49, 149, 199):
            snap(f"D_{i}")

    with open("ref_clock.csv", "w") as f:
        for r in rows:
            f.write(",".join(str(x) for x in r) + "\n")
    for r in rows:
        print(r)
