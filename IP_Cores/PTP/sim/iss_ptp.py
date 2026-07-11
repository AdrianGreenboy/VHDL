#!/usr/bin/env python3
# iss_ptp.py — ISS ORACULO del IP PTP visto por el firmware (nivel MMIO).
# ---------------------------------------------------------------------------
# Modela el IP como una maquina observable por registros MMIO. NO reimplementa
# el datapath bit-a-bit (eso lo hacen los ISS de bloque y los TB de capa 1);
# modela el CONTRATO que el firmware ve: que valores devuelven las lecturas y
# como evolucionan los stickies / la IRQ tras una secuencia de accesos.
#
# Se valida RTL-vs-ISS: el mismo "programa" de accesos MMIO se aplica al RTL
# (tb_ptp_soc.vhd) y a este modelo; las lecturas deben coincidir. Este oraculo
# es el que el firmware usa como referencia en la capa 4 del SoC real.
#
# Mapa de registros (offset de palabra):
#   0x00 CONTROL  0x04 SERVO_K  0x08 LAT   0x0C CMD
#   0x10 CLKID_HI 0x14 CLKID_LO 0x18 PORT  0x1C SMAC_HI 0x20 SMAC_LO
#   0x24 STATUS   0x28 NOW_SEC  0x2C NOW_NS 0x30 MPD_LO 0x34 MPD_HI
#   0x38 OFFSET   0x3C RATE_ADJ 0x40 IRQEN
# ---------------------------------------------------------------------------

# offsets de palabra
CTRL,SERVO,LAT,CMD = 0,1,2,3
CLKIDH,CLKIDL,PORT,SMACH,SMACL = 4,5,6,7,8
STATUS,NOWSEC,NOWNS,MPDLO,MPDHI,OFFSET,RATE,IRQEN = 9,10,11,12,13,14,15,16

# bits de STATUS
ST_RXSYNC = 0
ST_RXRESP = 1
ST_MPDVAL = 2
ST_OFFVAL = 3

# parametros del modelo de loopback (deterministas, casan con el RTL):
#  - cada Sync emitido en loopback vuelve y arma rx_sync.
#  - un peer-delay (start_pdelay) produce mpd = MPD_LOOPBACK y arma mpd_valid.
#  - en modo esclavo, un Sync procesa un offset = OFFSET_LOOPBACK.
#  - el reloj avanza 10 ns por ciclo de MMIO transcurrido (modelo simplificado
#    que casa con el generador de now del arnes; el valor exacto lo fija el TB).
MPD_LOOPBACK    = 40
OFFSET_LOOPBACK = 40
NS_PER_TICK     = 10

class PtpIss:
    def __init__(self):
        self.ctrl = 0
        self.servo = 0
        self.lat = 0
        self.clkid_hi = 0
        self.clkid_lo = 0
        self.port = 0
        self.smac_hi = 0
        self.smac_lo = 0
        self.irqen = 0
        self.status = 0
        # estado de reloj y medidas
        self.now_ns = 0
        self.now_sec = 0
        self.mpd = 0
        self.offset = 0
        self.rate = 0
        # snapshots atomicos
        self.ns_snap = 0
        self.mpdhi_snap = 0
        # cola de eventos pendientes (llegan tras "advance")
        self._pending_sync = False
        self._pending_mpd = False
        self._pending_off = False

    # --- helpers de rol ---
    def role_slave(self): return (self.ctrl >> 0) & 1
    def loopback(self):   return (self.ctrl >> 1) & 1
    def enable(self):     return (self.ctrl >> 2) & 1

    def irq(self):
        return 1 if (self.status & self.irqen & 0xF) != 0 else 0

    # --- escritura MMIO ---
    def write(self, a, d):
        d &= 0xFFFFFFFF
        if   a == CTRL:   self.ctrl = d
        elif a == SERVO:  self.servo = d
        elif a == LAT:    self.lat = d
        elif a == CMD:
            # disparos: send_sync (bit0), start_pdelay (bit1)
            if d & 1:  # send_sync
                if self.loopback():
                    self._pending_sync = True
                    if self.role_slave():
                        self._pending_off = True
            if d & 2:  # start_pdelay
                if self.loopback():
                    self._pending_mpd = True
        elif a == CLKIDH: self.clkid_hi = d
        elif a == CLKIDL: self.clkid_lo = d
        elif a == PORT:   self.port = d
        elif a == SMACH:  self.smac_hi = d
        elif a == SMACL:  self.smac_lo = d
        elif a == STATUS: self.status &= ~(d & 0xF) & 0xF   # W1C
        elif a == IRQEN:  self.irqen = d

    # --- lectura MMIO (con snapshot atomico) ---
    def read(self, a):
        if   a == CTRL:   return self.ctrl
        elif a == SERVO:  return self.servo
        elif a == LAT:    return self.lat
        elif a == CLKIDH: return self.clkid_hi
        elif a == CLKIDL: return self.clkid_lo
        elif a == PORT:   return self.port
        elif a == SMACH:  return self.smac_hi
        elif a == SMACL:  return self.smac_lo
        elif a == STATUS: return self.status & 0xF
        elif a == NOWSEC:
            self.ns_snap = self.now_ns            # congela ns
            return self.now_sec & 0xFFFFFFFF
        elif a == NOWNS:  return self.ns_snap & 0xFFFFFFFF
        elif a == MPDLO:
            self.mpdhi_snap = (self.mpd >> 32) & 0xFFFFFFFF  # congela hi
            return self.mpd & 0xFFFFFFFF
        elif a == MPDHI:  return self.mpdhi_snap
        elif a == OFFSET: return self.offset & 0xFFFFFFFF
        elif a == RATE:   return self.rate & 0xFFFFFFFF
        elif a == IRQEN:  return self.irqen
        return 0

    # --- avance de tiempo: procesa eventos pendientes tras N ciclos ---
    def advance(self, ticks):
        self.now_ns += ticks * NS_PER_TICK
        # tras dejar correr el datapath, los eventos disparados se materializan
        if self._pending_sync:
            self.status |= (1 << ST_RXSYNC)
            self._pending_sync = False
        if self._pending_mpd:
            self.mpd = MPD_LOOPBACK
            self.status |= (1 << ST_MPDVAL)
            self.status |= (1 << ST_RXRESP)   # el Resp tambien se recibe
            self._pending_mpd = False
        if self._pending_off:
            # offset = latencia - meanPathDelay. Si el mpd ya se midio (peer-delay
            # previo), se cancela con la latencia de loopback -> offset ~0.
            self.offset = OFFSET_LOOPBACK - (self.mpd if self.mpd != 0 else 0)
            self.status |= (1 << ST_OFFVAL)
            self._pending_off = False


if __name__ == "__main__":
    # programa de referencia: configurar, disparar Sync, avanzar, leer STATUS.
    iss = PtpIss()
    prog = []
    def W(a,d): prog.append(("W",a,d))
    def R(a):   prog.append(("R",a,None))
    def A(n):   prog.append(("A",n,None))

    W(CTRL, 0x6)          # loopback+enable, maestro
    W(SERVO, 0x00400010)
    W(CLKIDH, 0x00112233); W(CLKIDL, 0x44556677)
    W(IRQEN, 0x1)
    W(STATUS, 0xF)        # limpiar
    W(CMD, 0x1)           # send_sync
    A(4000)               # dejar correr el lazo
    R(STATUS)
    R(NOWSEC); R(NOWNS)

    # ---- peer-delay por MMIO ----
    W(STATUS, 0xF)        # limpiar stickies
    W(CMD, 0x2)           # start_pdelay
    A(6000)               # dejar correr el ping-pong
    R(STATUS)             # mpd_valid + rx_resp
    R(MPDLO); R(MPDHI)    # meanPathDelay

    # ---- modo esclavo: offset ----
    # El offset = t_slave_rx - t_master_origin - meanPathDelay. Tras el
    # peer-delay previo, mpd=40 ya esta medido, y en loopback la latencia
    # t_slave-t_master es ~40, asi que el offset residual es ~0 (el esclavo ya
    # esta sincronizado; el mpd descontado cancela la latencia).
    W(CTRL, 0x7)          # loopback+enable+role_slave
    W(STATUS, 0xF)
    W(CMD, 0x1)           # send_sync (como esclavo, procesa offset)
    A(4000)
    R(STATUS)             # offset_valid + rx_sync
    R(OFFSET)             # ~0 (latencia - mpd)

    log = []
    for op in prog:
        k,a,d = op
        if k == "W": iss.write(a,d)
        elif k == "R":
            v = iss.read(a); log.append((a,v))
        elif k == "A": iss.advance(a)

    for a,v in log:
        print(f"read reg[{a}] = 0x{v:08x}  irq={iss.irq()}")

    # volcar la secuencia y los resultados esperados para el arnes RTL
    with open("ptp_soc_oracle.txt","w") as f:
        for a,v in log:
            f.write(f"{a} {v}\n")
    print("oraculo escrito en ptp_soc_oracle.txt")
