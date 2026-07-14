#!/usr/bin/env python3
# tsn_scn1.py - Escenario dirigido fase 1 del TB del xbar.
# Grupos de tramas de longitud IGUAL (64 con FCS = 60 en RTL), simultaneas
# dentro del grupo y grupos muy separados: el orden RR del oraculo es
# robusto frente a las diferencias de temporizacion oraculo/RTL.
from tsn_model import Model, mk, NPORTS

m = Model()
m.table = {0x020000000001+p: p for p in range(NPORTS)}
MAC = lambda p: 0x020000000001+p
G = 2000  # separacion entre grupos >> duracion de servicio del grupo
arr = [
    # G0: dos unicast disjuntos en paralelo
    (0*G, 0, mk(MAC(1), MAC(0))),
    (0*G, 2, mk(MAC(3), MAC(2))),
    # G1: contencion triple sobre la salida 2 (orden = RR puro)
    (1*G, 0, mk(MAC(2), MAC(0))),
    (1*G, 1, mk(MAC(2), MAC(1))),
    (1*G, 3, mk(MAC(2), MAC(3))),
    # G2: broadcast desde 1 + unicast simultaneo 3->0 (broadcast secuencial)
    (2*G, 1, mk(0xffffffffffff, MAC(1))),
    (2*G, 3, mk(MAC(0), MAC(3))),
    # G3: MAC desconocida desde 2 -> flooding
    (3*G, 2, mk(0x0A0B0C0D0E0F, MAC(2))),
    # G4: dst==ingreso -> filtrada (rx cuenta, nada sale)
    (4*G, 3, mk(MAC(3), MAC(3))),
    # G5: contencion cuadruple: cada entrada p -> MAC((p+1)%4), todas a la vez
    (5*G, 0, mk(MAC(1), MAC(0))),
    (5*G, 1, mk(MAC(2), MAC(1))),
    (5*G, 2, mk(MAC(3), MAC(2))),
    (5*G, 3, mk(MAC(0), MAC(3))),
    # G6: discriminador RR vs prioridad fija: rr(1)=1 tras G5, contencion
    # {in0, in2} sobre la salida 1 => RR sirve in2 ANTES que in0
    (6*G, 0, mk(MAC(1), MAC(0))),
    (6*G, 2, mk(MAC(1), MAC(2))),
]
m.run(arr)
print(m.report())
