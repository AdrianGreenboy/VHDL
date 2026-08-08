# Core 19 — PCS 64B/66B @ 25G — Mapa de Registros AXI-Lite (CONGELADO)

**Estado:** Entregable 1 / Scope freeze. Congelado antes de RTL.
**Interfaz:** AXI4-Lite slave, 32-bit data, 32-bit address.
**Base:** `0x8000_0000` (ventana 64 KiB del SoC v3).
**Offset del bloque PCS dentro de la ventana:** `0x0000` (el core ocupa `0x8000_0000`–`0x8000_00FF`, 256 B = 64 registros).
**Reloj del banco:** dominio AXI del SoC (~100–150 MHz). Todos los campos que reflejan estado del data plane (390.625 MHz) cruzan por CDC.
**Endianness:** little-endian, alineado a palabra (los 2 LSB de la dirección se ignoran).
**Acceso no mapeado:** escrituras a offsets reservados → OKAY sin efecto; lecturas → 0x00000000.

---

## 1. Convenciones

- **RW** = lectura/escritura software (RV32i).
- **RO** = solo lectura; lo escribe el data plane, lo lee software.
- **RW1C** = lectura normal; escribir 1 en un bit lo limpia (sticky de eventos/errores).
- **WO/SC** = write-only self-clearing: el bit se auto-limpia tras la acción (pulsos de comando).
- Todo campo RO que proviene del data plane está **sincronizado a AXI** (toggle/gray + doble flip-flop). Nunca leer un contador crudo sin el snapshot atómico (ver `STATS_SNAP`).

---

## 2. Tabla de registros

| Offset | Nombre          | Acceso | Reset       | Descripción breve                                   |
|--------|-----------------|--------|-------------|-----------------------------------------------------|
| 0x00   | `ID`            | RO     | 0x50435319  | Magic "PCS" + versión de core (0x19 = Core 19).     |
| 0x04   | `SCRATCH`       | RW     | 0x00000000  | Registro de prueba read/write (Layer 1).            |
| 0x08   | `CTRL`          | RW     | 0x00000000  | Control global del PCS (ver 3.1).                    |
| 0x0C   | `CMD`           | WO/SC  | 0x00000000  | Comandos de pulso (ver 3.2).                         |
| 0x10   | `STATUS`        | RO     | 0x00000000  | Estado del PCS: lock, sync, alineación (ver 3.3).   |
| 0x14   | `IRQ_STATUS`    | RW1C   | 0x00000000  | Eventos sticky (ver 3.4).                            |
| 0x18   | `IRQ_ENABLE`    | RW     | 0x00000000  | Máscara de interrupción por evento (bit-align 3.4). |
| 0x1C   | `PRBS_CTRL`     | RW     | 0x00000000  | Control del generador/checker PRBS31 (ver 3.5).     |
| 0x20   | `STATS_SNAP`    | WO/SC  | 0x00000000  | Escribir 1 congela todos los contadores (atómico).  |
| 0x24   | `CNT_TX_BLK`    | RO     | 0x00000000  | Bloques 66b transmitidos (snapshot).                |
| 0x28   | `CNT_RX_BLK`    | RO     | 0x00000000  | Bloques 66b recibidos (snapshot).                   |
| 0x2C   | `CNT_RX_ERR`    | RO     | 0x00000000  | Bloques con header inválido / sync header err.      |
| 0x30   | `CNT_BER`       | RO     | 0x00000000  | Bit errors acumulados del checker PRBS31.           |
| 0x34   | `LOCK_TIME`     | RO     | 0x00000000  | Ciclos data-plane hasta block-lock (last bring-up). |
| 0x38   | `DMA_ADDR`      | RW     | 0x70000000  | Dirección DDR destino del volcado de stats.         |
| 0x3C   | `DMA_DOORBELL`  | RW     | 0x00000000  | Palabra sentinel DONE_WORD escrita tras DMA.        |
| 0x40–0x7C |  reservado   | —      | —           | Lectura 0, escritura sin efecto.                    |

> Mutaciones de verificación se inyectan **fuera del banco** (vía testbench / fuerza de señal interna), no por registro. El mapa AXI es idéntico en simulación y en silicio.

---

## 3. Detalle de campos

### 3.1 `CTRL` (0x08, RW)

| Bit  | Nombre        | Reset | Descripción                                                        |
|------|---------------|-------|--------------------------------------------------------------------|
| 0    | `PCS_EN`      | 0     | Habilita el data plane PCS. 0 = quiescente/reset interno.          |
| 1    | `TX_EN`       | 0     | Habilita el gearbox/scrambler de TX.                              |
| 2    | `RX_EN`       | 0     | Habilita el block-sync/descrambler de RX.                         |
| 3    | `LOOPBACK`    | 0     | 1 = parallel loopback interno 66b (Layer 5). 0 = camino externo.  |
| 4    | `SCR_BYPASS`  | 0     | 1 = bypass del scrambler (debug/Layer 3). 0 = scrambler activo.   |
| 5    | `FEC_EN`      | 0     | Reservado para RS-FEC futuro. Debe ser 0 en Core 19.              |
| 6    | `AUTO_RESYNC` | 0     | 1 = re-sincroniza automáticamente al perder lock.                 |
| 31:7 | reservado     | 0     | Escribir 0.                                                        |

> **CDC:** los bits de `CTRL` cruzan al dominio 390 MHz por handshake (pulse-sync + ack). Software no debe asumir efecto inmediato; poll `STATUS.CTRL_ACK`.

### 3.2 `CMD` (0x0C, WO/SC) — pulsos, se auto-limpian

| Bit  | Nombre        | Descripción                                                        |
|------|---------------|--------------------------------------------------------------------|
| 0    | `SOFT_RESET`  | Pulso: reset del data plane sin tocar el banco AXI.               |
| 1    | `RESYNC`      | Pulso: fuerza re-arranque del block-sync (slip a 0).             |
| 2    | `CNT_CLEAR`   | Pulso: pone a cero todos los contadores.                          |
| 3    | `PRBS_RESET`  | Pulso: reinicia el estado LFSR del gen/checker PRBS.             |
| 31:4 | reservado     | Escribir 0.                                                        |

> Nunca atar `SOFT_RESET` al reset del banco AXI: la FSM AXI no debe resetearse a mitad de transacción (regla dura del proyecto). `SOFT_RESET` solo pulsa el dominio data-plane vía CDC.

### 3.3 `STATUS` (0x10, RO) — todo sincronizado a AXI

| Bit  | Nombre         | Descripción                                                       |
|------|----------------|-------------------------------------------------------------------|
| 0    | `BLOCK_LOCK`   | 1 = block-sync alcanzó lock (64 headers válidos consecutivos).   |
| 1    | `HI_BER`       | 1 = tasa de sync-header err supera umbral (hi_ber state).        |
| 2    | `SCR_SYNC`     | 1 = descrambler sincronizado (estado LFSR reconstruido).        |
| 3    | `PRBS_LOCK`    | 1 = checker PRBS enganchó la secuencia.                          |
| 4    | `CTRL_ACK`     | 1 = último cambio de `CTRL` aplicado en el dominio data-plane.   |
| 5    | `TX_ACTIVE`    | 1 = TX emitiendo bloques.                                        |
| 6    | `RX_ACTIVE`    | 1 = RX recibiendo bloques válidos.                              |
| 7    | `DMA_BUSY`     | 1 = volcado de stats a DDR en curso.                            |
| 31:8 | reservado      | Lee 0.                                                            |

### 3.4 `IRQ_STATUS` (0x14, RW1C) / `IRQ_ENABLE` (0x18, RW)

Mismo bit-align en ambos registros. `irq_out` del core = OR de (`IRQ_STATUS` AND `IRQ_ENABLE`).

| Bit  | Nombre            | Descripción                                             |
|------|-------------------|---------------------------------------------------------|
| 0    | `EV_LOCK_GAINED`  | Sticky: transición 0→1 de `BLOCK_LOCK`.                |
| 1    | `EV_LOCK_LOST`    | Sticky: transición 1→0 de `BLOCK_LOCK`.                |
| 2    | `EV_HI_BER`       | Sticky: entrada en estado hi_ber.                      |
| 3    | `EV_RX_ERR`       | Sticky: nuevo bloque con sync-header inválido.         |
| 4    | `EV_PRBS_ERR`     | Sticky: el checker PRBS detectó bit error(s).          |
| 5    | `EV_DMA_DONE`     | Sticky: volcado de stats a DDR completado (DONE_WORD). |
| 31:6 | reservado         | Escribir 0.                                             |

> **Regla sticky-race del proyecto:** leer estos bits solo tras el wait guardado que confirma el evento. El data plane setea el sticky vía CDC toggle; el clear RW1C gana sobre un set simultáneo solo si el toggle no cambió (documentar el orden en el oráculo Layer 2).

### 3.5 `PRBS_CTRL` (0x1C, RW)

| Bit  | Nombre        | Reset | Descripción                                          |
|------|---------------|-------|------------------------------------------------------|
| 0    | `GEN_EN`      | 0     | Habilita el generador PRBS31 en TX (en vez de datos).|
| 1    | `CHK_EN`      | 0     | Habilita el checker PRBS31 en RX.                    |
| 2    | `INJ_ERR`     | 0     | Pulso lógico: inyecta un bit error (auto-clear).    |
| 31:3 | reservado     | 0     | Escribir 0.                                          |

---

## 4. Secuencia de bring-up (firmware RV32i, referencia)

1. Leer `ID`, verificar `0x50435319`.
2. `DMA_ADDR` ← `0x70000000`.
3. `CTRL` ← `PCS_EN | TX_EN | RX_EN | LOOPBACK | AUTO_RESYNC`.
4. Poll `STATUS.CTRL_ACK` = 1.
5. `PRBS_CTRL` ← `GEN_EN | CHK_EN`.
6. `CMD` ← `RESYNC`.
7. Poll `STATUS.BLOCK_LOCK` = 1 y `STATUS.PRBS_LOCK` = 1 (con timeout).
8. Esperar N ciclos, luego `STATS_SNAP` ← 1 (congela contadores atómicamente).
9. Leer `CNT_TX_BLK`, `CNT_RX_BLK`, `CNT_RX_ERR`, `CNT_BER`, `LOCK_TIME`.
10. Acumular en RAM local, programar DMA local→DDR, escribir `DMA_DOORBELL` = `DONE_WORD`.
11. PASS de silicio = `BLOCK_LOCK`=1, `PRBS_LOCK`=1, `CNT_BER`=0, `CNT_RX_ERR`=0.

---

## 5. Notas de CDC (frontera 390.625 MHz ↔ AXI)

- **Config (AXI→DP):** cada bit de `CTRL`/`PRBS_CTRL` que afecta al data plane se transfiere con pulse-synchronizer + ack; `STATUS.CTRL_ACK` refleja el ack.
- **Estado (DP→AXI):** bits de un solo evento por toggle-sync; contadores multibit por captura-en-snapshot (`STATS_SNAP` congela un registro shadow en el dominio DP, que luego se lee estable en AXI — nunca lectura gray de un contador en vuelo).
- **Snapshot atómico:** `STATS_SNAP` es la única forma correcta de leer los contadores. Leerlos sin snapshot previo devuelve valores potencialmente inconsistentes entre sí.

---

## 6. Alcance de la firma FNV (Layer 4 oráculo)

El oráculo Python modela: el banco completo (RW, RW1C, WO/SC), el mapeo IRQ = STATUS_masked, y el modelo de contadores bajo una traza de eventos determinista. La firma FNV-1a 32-bit se calcula sobre la secuencia concatenada de:
`(offset, tipo_acceso, dato_resultante)` de cada transacción AXI de la traza de test, más el estado final de los 6 contadores tras snapshot. Bit-idéntica RTL vs Python = único criterio PASS de Layer 1/2.
