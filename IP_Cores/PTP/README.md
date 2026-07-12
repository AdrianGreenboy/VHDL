# IP Core PTP / IEEE 802.1AS — VHDL-2008 para AMD Versal

Sincronización de tiempo de precisión (gPTP / IEEE 802.1AS-2020, perfil de PTPv2)
implementada desde cero en VHDL-2008, con MAC Ethernet MII propio, reloj PTP con
servo PI, medición de *peer-delay* y control por MMIO/AXI4-Lite. Validado
**bit-idéntico contra un oráculo ISS en Python** en 17 capas de regresión GHDL y
**en silicio** sobre el Trenz TE0950 (Versal VE2302), gobernado por un SoC
RISC-V RV32IM también propio.

![Arquitectura completa del IP](architecture.svg)

---

## ¿Para qué sirve?

Este IP implementa el plano de tiempo de una red TSN (Time-Sensitive Networking):

- **Reloj PTP de 80 bits** (48b segundos + 32b nanosegundos) con acumulador de
  fase sub-ns, incremento nominal de 10 ns @ 100 MHz, ajuste fino de tasa
  (`rate_adj`) y salto atómico único para corrección inicial de offset.
- **Timestamping por hardware en el SFD** (t1–t4) para exactitud de nanosegundos,
  independiente del software.
- **Peer-delay (Pdelay_Req/Resp)**: medición de `meanPathDelay = ((t4−t1)−(t3−t2))/2`
  con orquestador iniciador/respondedor en hardware.
- **Lazo maestro/esclavo Sync**: en modo esclavo, el servo PI corrige offset y
  deriva contra el maestro.
- **MAC Ethernet MII 4-bit** propio (preámbulo/SFD, padding a 60, FCS por
  hardware, filtro de DA multicast gPTP, override 1-step de `originTimestamp` /
  `correctionField` en vuelo) con **loopback interno** (`LOOP_INT`) para
  autovalidación sin PHY.
- **Interfaz de control dual**: MMIO simple (sel/we/addr) o wrapper **AXI4-Lite**
  (`ptp_axil`), más un **maestro AXI-Lite embebido** (`ptp_axil_master`) para
  gobernarlo desde un core RISC-V dentro del PL.

Casos de uso: base de tiempo para *time-aware shaping* (802.1Qbv), sellado de
telemetría en payloads satelitales, sincronización de nodos en buses
deterministas, y bancos de prueba de TSN sin depender de IPs cerrados.

---

## Prerrequisitos

| Herramienta | Versión probada | Uso |
|---|---|---|
| AMD Vivado | 2025.2.1 | Síntesis/implementación (block design con module reference) |
| AMD PetaLinux | 2025.2.1 | Imagen Linux + BOOT.BIN para Versal |
| GHDL | 4.1.0 (mcode) | Regresión completa de simulación |
| Python | 3.10+ | Oráculo ISS, verificadores bit-idénticos, ensamblador `asm.py` |
| gcc-aarch64-linux-gnu | cualquiera reciente | Cross-compilar las herramientas de bring-up (`-static`) |
| Hardware | Trenz TE0950 (XCVE2302) | Plataforma validada; portable a otros Versal |

En Ubuntu 24.04:

```bash
sudo apt install ghdl gcc-aarch64-linux-gnu python3 zip
```

El flujo asume además el SoC RV32IM (repo `rv32i`: core, `mem_subsys_dma.vhd`,
`dp_ram`, `dma_burst`, `asm.py`) instanciado junto al IP en el mismo block design.

---

## Estructura del repositorio

```
PTP/
├── rtl/                  RTL VHDL-2008 (17 fuentes)
│   ├── ptp_pkg.vhd           constantes globales (SEC_W, NS_W, INC nominal)
│   ├── ptp_msg_pkg.vhd       layouts de trama gPTP + offsets + plantillas
│   ├── eth_pkg.vhd           utilidades Ethernet/CRC32
│   ├── ptp_clock.vhd         reloj PTP + servo PI
│   ├── ptp_tstamp.vhd        captura de timestamps en SFD
│   ├── ptp_tx.vhd            motor de trama TX (shift register 544b)
│   ├── ptp_rx.vhd            parser gPTP del lado RX
│   ├── ptp_pdelay.vhd        aritmética de meanPathDelay
│   ├── ptp_pdelay_fsm.vhd    orquestador iniciador/respondedor
│   ├── eth_tx_mii.vhd        serializador MII (pad, FCS, override)
│   ├── eth_rx_mii.vhd        deserializador MII (CRC, filtro DA)
│   ├── eth_mac.vhd           MAC + mux de loopback + divisor mii_ce
│   ├── spw_fifo.vhd          FIFO 2048×9 FWFT (bit 8 = tlast)
│   ├── ptp_mac.vhd           integración TX/RX/orquestador + gate S&F + sondas
│   ├── ptp_regs.vhd          banco de registros MMIO
│   ├── ptp_top.vhd           top MMIO
│   ├── ptp_axil.vhd          wrapper esclavo AXI4-Lite
│   └── ptp_axil_master.vhd   maestro AXI4-Lite embebido (lado core RISC-V)
├── sim/                  regresión: 17 testbenches + ISS Python + run_regression.sh
├── fw/                   firmware RV32IM de bring-up y diagnóstico (.s → .mem)
├── bringup/              herramientas Linux (ptp_verify, ptp_dump_*, firma esperada)
├── vivado/ vivado_ptp/   proyecto Vivado y TCL de reconstrucción
├── petalinux/            notas de build de la imagen
└── architecture.svg      este diagrama
```

---

## Mapa de registros

Base AXI4-Lite (vista del core RV32IM en el diseño de referencia): `0x6000_0000`.
Offsets de byte; registros de 32 bits.

| Offset | Nombre | Acceso | Descripción |
|---|---|---|---|
| 0x00 | CONTROL | RW | `[0]` role_slave, `[1]` loopback (LOOP_INT), `[2]` enable |
| 0x04 | SERVO_K | RW | ganancias del servo PI (empaquetadas kp/ki) |
| 0x08 | LAT | RW | compensación de latencia fija |
| 0x0C | CMD | W (disparo) | `[0]` send_sync, `[1]` start_pdelay — **en cola**: un comando emitido con trama en vuelo se difiere, jamás se descarta |
| 0x10 / 0x14 | CLKID_HI/LO | RW | clockIdentity (64b) |
| 0x18 | PORTNUM | RW | portNumber |
| 0x1C / 0x20 | SMAC_HI/LO | RW | MAC de origen para las tramas |
| 0x24 | STATUS | R / W1C | `[0]` rx_sync, `[1]` rx_resp, `[2]` mpd_valid, `[3]` offset_valid (escribir 1 limpia) |
| 0x28 | NOW_SEC | R | segundos; **leerlo congela NOW_NS** (lectura atómica de 80b) |
| 0x2C | NOW_NS | R | nanosegundos del snapshot |
| 0x30 | MPD_LO | R | meanPathDelay bajo; **leerlo congela MPD_HI** |
| 0x34 | MPD_HI | R | meanPathDelay alto |
| 0x38 | OFFSET | R | último offset medido (esclavo) |
| 0x3C | RATE_ADJ | R | salida del servo |
| 0x40 | IRQEN | RW | máscara de interrupción (espeja STATUS) |
| 0x44 | DBG_STATE | R | FSMs TX/orquestador + *stickies* RX (ev_ok/crc/runt/drop, último mtype, contador de mensajes) |
| 0x48 / 0x4C | DBG_DST | R | DA de la última trama **descartada por el filtro** (0x4C[31:20]=tag `0xA5D` = sonda presente) |
| 0x50 | DBG_FIFO | R | `[27:16]` nivel vivo de la FIFO, `[11:0]` longitud de la trama descartada |
| 0x54 | DBG_PTR | R | `[26:16]` wptr, `[10:0]` rptr de la FIFO de trama |
| 0x58 | DBG_BYTES | R | `[31:24]`=tag `0xB1`, bytes 14/35/0 escritos a la FIFO (autoverificación del camino TX) |

> Los registros 0x44–0x58 son la instrumentación de bring-up. Cuestan casi nada
> y **cazaron tres bugs de silicio invisibles en simulación** — se recomienda
> conservarlos (ver *Problemática*).

---

## Cómo usar el IP

### Integración hardware

1. Instanciar `ptp_axil` (AXI4-Lite) o `ptp_top` (MMIO crudo) en tu diseño.
2. Para gobernarlo desde un core en el PL: `mem_subsys_dma` decodifica
   `addr[31:28]=0110` → `ptp_axil_master` → `ptp_axil`. **El maestro entrega
   `ready` únicamente cuando `rdata` ya contiene el dato de ESA transacción**
   (capturado en `rvalid`) — ver *Problemática §1*.
3. `mii_txd/mii_tx_en/mii_rxd/mii_rx_dv` van a los pads del PHY. Con
   `CONTROL.loopback=1` el RX se alimenta del TX dentro del PL y los pines
   externos se ignoran (modo de autovalidación).

### Secuencia de software (maestro, loopback)

```text
CONTROL  <= 0x6            # enable + loopback, rol maestro
SERVO_K  <= 0x00400010
CLKID_HI <= 0x00112233 ; CLKID_LO <= 0x44556677
PORTNUM  <= 1
STATUS   <= 0xF            # limpiar stickies (W1C)
CMD      <= 0x1            # Sync      → esperar STATUS[0]
CMD      <= 0x2            # peer-delay → esperar STATUS[2]; leer MPD_LO/HI
CONTROL  <= 0x7            # rol esclavo
CMD      <= 0x1            # Sync      → esperar STATUS[0]; leer OFFSET
```

En LOOP_INT el resultado canónico es `MPD = 40 ns` (latencia del lazo interno)
y `OFFSET = 0`. El firmware de referencia está en `fw/ptp_bringup.s`.

---

## Reconstrucción completa desde cero

### 1. Regresión de simulación (GHDL)

```bash
cd PTP/sim
rm -f work-obj08.cf ../rtl/work-obj08.cf
./run_regression.sh
# Esperado: === TODAS LAS VERIFICACIONES PASAN === (17 capas)
```

Las capas: bloques con mutaciones (1a), bit-identidad TX vs ISS Python, parser
RX (1b), integración LOOP_INT (1c: Sync, Pdelay, lazo esclavo, carrera
Sync→Pdelay), MMIO (2), SoC RTL-vs-ISS de los 3 flujos (4), wrapper AXI-Lite y
cadena completa lado-core con aserciones anti-corrimiento (A1–A8).

### 2. Bitstream (Vivado, batch)

```bash
cd PTP/vivado_ptp
cat > rebuild_full.tcl <<'EOF'
open_project ptp_soc.xpr
update_module_reference [get_ips]
reset_run synth_1 -prev_step
reset_run impl_1 -prev_step
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1
open_run impl_1
report_timing_summary -delay_type max -max_paths 3 -file timing_check.rpt
write_hw_platform -fixed -force ../ptp_soc.xsa
EOF
vivado -mode batch -notrace -source rebuild_full.tcl
grep -A6 "Design Timing Summary" timing_check.rpt | tail -2      # WNS > 0
# CANDADO obligatorio (ver Problemática §4): la síntesis debe ser
# POSTERIOR a tu último cambio de RTL
ls -la ../rtl/ptp_tx.vhd ptp_soc.runs/bd_soc_usart_u_soc_ptp_0_synth_1/runme.log
```

### 3. Imagen PetaLinux + BOOT.BIN

```bash
source ~/Petalinux/settings.sh
cd ~/plnx_te0950_ptp
petalinux-config --get-hw-description=/ruta/a/PTP/ptp_soc.xsa --silentconfig
ls -la project-spec/hw-description/ptp_soc.pdi     # fecha de AHORA, si no, no importó
petalinux-build
petalinux-package --boot --force --plm --psmfw --u-boot --dtb images/linux/system.dtb
```

> Versal exige empaquetar con `--plm --psmfw`; sin ellos el PLM rechaza el PDI.

### 4. Firmware y herramientas

```bash
cd ~/rv32i
python3 asm.py ../PTP/fw/ptp_bringup.s ptp_bringup.mem
aarch64-linux-gnu-gcc -static -o ptp_verify ../PTP/bringup/ptp_verify.c
```

### 5. SD y placa

```bash
udisksctl mount -b /dev/sda1
cp images/linux/BOOT.BIN ptp_bringup.mem ptp_verify \
   ../PTP/bringup/ptp_signature.txt /media/$USER/BOOT/
sync && umount /dev/sda1
```

En la consola serial del TE0950 (la SD se auto-monta en
`/run/media/BOOT-mmcblk1p1`):

```bash
cd /run/media/BOOT-mmcblk1p1
./ptp_verify ptp_bringup.mem ptp_signature.txt
# Esperado:
#   sig[0] STATUS=0x1  sig[1] MPD=0x28 (40ns)  sig[3] OFFSET=0
#   sig[4] DOORBELL=0xD0ED  →  PTP SILICON PASS
```

---

## Problemática encontrada (léela: te va a ahorrar días)

Esta sección documenta el bring-up real. Cada punto costó horas de cacería y
tiene una moraleja concreta.

### 1. Corrimiento de una transacción en el maestro AXI-Lite

**Síntoma:** en silicio, cada lectura MMIO devolvía el dato de la lectura
*anterior*. `NOW_NS` regresaba el valor de `NOW_SEC` (delatado porque el valor
crecía con el *uptime* de la placa y no era múltiplo del incremento de 10 ns),
y el readback de CONTROL daba basura — mientras toda la simulación pasaba.

**Causa:** el maestro afirmaba `dmem_ready` al aceptarse la **dirección**
(`arready`) en vez de al llegar el **dato** (`rvalid`); el core capturaba el
`rdata` viejo.

**Moraleja:** en un maestro AXI, `ready` hacia el CPU se afirma en el mismo
ciclo en que el dato de *esta* transacción ya está registrado. El testbench
`tb_ptp_axil_master` incluye aserciones anti-corrimiento (readback inmediato,
`NOW_NS` múltiplo del incremento y avanzando, lecturas back-to-back de 3
registros) que detectan cualquier regresión de este tipo.

### 2. Vivado 2025.2.1 sintetiza mal lookups de plantilla indexados — CUATRO veces

**Síntoma:** las tramas Pdelay salían del TX con el encabezado en **ceros**
(DA `00:00:00:00:00:00`, FCS válido, filtro RX las descartaba), con Sync
funcionando perfecto y GHDL pasando todo. Las sondas de hardware demostraron
que los ceros ya entraban a la FIFO y que los parches dinámicos (clockIdentity)
del mismo cono salían **bien**.

**Formulaciones que Vivado mangló, en orden:**
1. Constantes inicializadas desde funciones **anidadas** que devuelven arreglos
   no restringidos → plantilla completa en ceros.
2. Funciones aplanadas de un nivel → igual.
3. Constantes con **literales** + `case` plano dentro de la función → el índice
   llegó al decode con el **bit 5 pegado a 1** (`ROM(i|32)` medido en silicio:
   byte[14] devolvía el byte 46).
4. Proceso combinacional separado con el mismo `case` → misma firma `i|32`.

**Solución definitiva:** eliminar el índice. `ptp_tx` carga la trama completa
en un **shift register de 544 bits** al aceptar el comando (plantilla = literal
hexadecimal, parches = asignaciones de slice con índices **estáticos**) y
`S_PUSH` solo desplaza 8 bits por ciclo. Sin lookup no hay nada que
mal-sintetizar. La bit-identidad contra el oráculo ISS se re-verificó tras el
cambio.

**Moraleja:** en Vivado 2025.2.1, desconfía de cualquier función VHDL que
indexe plantillas/tablas con una señal, por inocente que parezca y aunque GHDL
(que implementa la semántica correcta) la simule perfecta. Prefiere shift
registers o ROMs síncronas inferidas del patrón canónico, y **verifica en
silicio con sondas**, no solo en simulación.

### 3. Archivo fantasma: el proyecto sintetizaba OTRO `spw_fifo.vhd`

**Síntoma:** error `formal port <dbg_wptr> is not declared in <spw_fifo>` tras
agregar puertos de debug, con el archivo del repo correcto.

**Causa:** el `.xpr` referenciaba `~/spw_ip/spw_fifo.vhd` (una copia de otro
proyecto) en vez de `rtl/spw_fifo.vhd`. Ambos eran funcionalmente idénticos —
hasta que dejaron de serlo.

**Moraleja:** un IP autocontenido no debe referenciar fuentes fuera de su árbol.
Audita la lista real de archivos del run de síntesis
(`ptp_soc.runs/<modref>_synth_1/*.tcl` contiene los `read_vhdl` con rutas
absolutas) y busca duplicados por nombre en tu disco: `find ~ -name archivo.vhd`.

### 4. Bitstreams rancios: el fix que "no funcionó" nunca se sintetizó

Dos veces se probó en silicio un bitstream construido **antes** de copiar el
RTL corregido (una vez por carpeta equivocada, otra por una carrera de minutos
entre el `cp` y el arranque de Vivado). El resultado: horas descartando un fix
correcto.

**Moraleja — el candado de timestamps**, obligatorio antes de cada prueba:

```bash
ls -la rtl/archivo_modificado.vhd \
       vivado_ptp/ptp_soc.runs/<modref>_synth_1/runme.log
# el log de síntesis DEBE ser posterior al RTL; y el PDI importado por
# PetaLinux DEBE tener fecha del build actual.
```

Complemento: sondas con **tags de presencia** (`0xA5D`, `0xB1`) legibles en los
registros de debug — el propio silicio declara qué versión de instrumentación
trae, eliminando la ambigüedad "¿registro en cero o registro inexistente?".

### 5. Otros hallazgos menores

- **`dbg_state` de 31 bits en un vector de 32**: el aggregate de relleno estaba
  mal contado; GHDL lo reporta como *bound check failure* en elaboración.
  Cuenta tus concatenaciones.
- **Comandos descartados en silencio**: un `CMD.send_sync` emitido mientras la
  trama anterior seguía purgándose se perdía (pulso de 1 ciclo contra un gate).
  Ahora se **encola** (`sync_pend`) y se lanza al liberarse el motor.
- **`rx_sync` se adelanta al fin de trama**: en loopback el parser arma el
  evento antes de que el MAC termine de emitir; leer `dbg_state` justo después
  muestra un transitorio de purga (`tx_inflight=1`) que **no** es un atasco.
- **El IP no se resetea entre corridas de firmware**: los *stickies* de debug
  acumulan historia. Para diagnósticos, siempre *power cycle* y el diagnóstico
  como **primera** operación del boot.

---

## Recomendaciones

1. **Corre la regresión antes de cada síntesis** — 17 capas en menos de un
   minuto; la bit-identidad contra el ISS es tu red de seguridad.
2. **No borres la instrumentación 0x44–0x58** hasta tener el IP desplegado y
   estable en tu sistema final; su costo en LUTs es despreciable.
3. **Disciplina de experimentos en silicio**: power cycle real entre corridas,
   una variable a la vez, y candado de timestamps en cada build.
4. **Todo bajo git, en ambos repos** (este y el del SoC RISC-V): el maestro
   AXI-Lite original se perdió precisamente por un árbol sin versionar.
5. Si portas a otra versión de Vivado, re-valida el camino TX con las sondas
   (`0x58` debe leer `0xB1021101` tras un pdelay) antes de confiar.

## Pasos siguientes (roadmap)

- **v1.1 — PHY externo**: `loopback=0` ya enruta a los pads MII; falta
  validación con PHY real (constraints de IO, CDC de `mii_rx_clk` si el PHY
  provee reloj propio) y medición de mpd real entre dos placas.
- **BMCA** (Best Master Clock Algorithm) y mensajes Announce para elección
  automática de gran maestro.
- **Sync periódico por hardware** (intervalo programable, hoy lo dispara el
  software) y *follow-up* de dos pasos como alternativa al 1-step.
- **802.1Qbv time-aware shaper** usando `NOW` como base de tiempo de las
  compuertas — el objetivo TSN final de este IP.
- **Interrupciones**: `IRQEN` ya existe; cablear `irq` al GIC del PS y escribir
  el driver UIO correspondiente.
- **Puerto a MRMAC/GTY** para 10/25G en VCK190, reutilizando el plano de tiempo
  (reloj + timestamping) con un MAC serdes en lugar del MII.

---

## Licencia

MIT License

Copyright (c) 2026 Adrián Hernández

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
