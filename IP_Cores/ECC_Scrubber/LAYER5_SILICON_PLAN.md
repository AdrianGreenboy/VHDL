# Layer 5 — Plan de integración en silicio (TE0950) — Core 20 ECC Scrubber

Guía de integración física del ECC scrubber en la AMD Versal `xcve2302-sfva784-1LP-e-S`
(Trenz TE0950), reusando el patrón `soc_top_master` de la familia HERCOSSNUX.

Objetivo: `L5 SILICON PASS` con contraste protegido/no-protegido sobre una región
ECC que vive en DDR real, orquestado por el `ecc-selftest` PS-side.

---

## 1. Piezas RTL a integrar

Top del SoC de silicio: `ecc_soc_si.vhd` (ya verificado en simulación: arranque,
ruteo MMIO, doorbell). Instancia:

- `cpu_pipeline` (RV32IM v1.1, fix de forwarding-durante-stall)
- `dp_ram` (IMEM)
- `mem_subsys_dma` (RAM local + motor DMA `dma_burst`) — **usar la versión limpia**
  (dp_ram + dma_burst; NO la que instancia ptp/dsp/pcie de otros cores)
- `axil_soc` (control + ventana IMEM/DMEM)
- `ecc_regbank_si` (codec MMIO 0x00-0x1F + scrubber 0x40+ + ventana 0x1000+ +
  contadores de tile CE_BUMP/DED_BUMP)
- `ecc_codec_mmio`, `ecc_codec`, `ecc_pkg`, `scrub_bram`, `scrub_fsm`

Firmware: `ecc_fw_tiles.mem` (barrido por tiles, ensamblado con `asm.py`).

---

## 2. Mapa de direcciones (silicio)

| Región (dmem RV32) | Rango | Destino |
|---|---|---|
| RAM local | `addr(31:30)="00"` | RAM local del firmware (buffer de tile) |
| Registros DMA | `0x4000_0000` | SRC/DST/LEN/CTRL/STATUS del `dma_burst` |
| Scrubber MMIO | `0x8000_0000` | codec `0x00-0x1F`, scrubber `0x40+`, ventana `0x1000+` |

Del lado PS (físico):

| Símbolo | Dirección | Uso |
|---|---|---|
| `AXIL_BASE` | `0x8000_0000` | esclavo AXI-Lite del SoC (control + IMEM) |
| `DDR_BASE` | `0x7000_0000` | buffer DDR reservado, 16 MB, `no-map` |

DDR reservado en `system-user.dtsi`: base `0x70000000`, 16 MB, `no-map`.
Esclavo AXI-Lite del SoC en `0x80000000`, 64 KB.

---

## 3. Flujo del Block Design (Vivado)

Reusar el proyecto de referencia de un core previo con maestro DMA (p.ej. el del
NPU o PCS 25G). Pasos, **un comando Tcl a la vez** en la consola, leyendo cada
respuesta (nunca pegar bloques):

1. `write_bd_tcl` del proyecto de referencia para capturar el estado del BD.
2. Clonar solo `project-spec/` + `.petalinux` (NO `build/`, ~22 GB).
3. Script de cirugía: renombrar el módulo del core previo a `ecc_soc_si`, ajustar
   conteos de SI del NoC y clocks, remover/renombrar puertos que no apliquen.
4. `set_property BOARD_PART trenz.biz:te0950_23_1lse:part0:1.2 [current_project]`
   **antes** de sourcear el BD Tcl.
5. `set run_remote_bd_flow 0` en el script exportado.
6. El core entra al BD como **module reference**:
   `create_bd_cell -type module -reference ecc_soc_si u_ecc`.
7. Cablear el maestro AXI4 (`m_axi`) a un puerto **SI del NoC** con ruta explícita
   a DDR. **CRÍTICO**: NO usar Connection Automation, que lo rutea a `S_AXI_LPD`
   (cero acceso a DDR). Cablear a mano vía Tcl al SI del NoC con la ruta a la DDR
   controller.
8. El esclavo AXI-Lite (`s_axi`) se conecta a un maestro del CIPS (M_AXI_FPD o
   similar), mapeado en `0x8000_0000`.
9. CDC: sincronizar reset y lock por separado; nunca combinar combinacionalmente
   antes del sincronizador.
10. Restaurar el top del proyecto tras cualquier `synth_design` out-of-context.
11. Barrer todos los filesets por artefactos de referencia remota
    (`get_files -all *`); limpiar checkpoints incrementales explícitamente.

---

## 4. Timing (Versal)

Los XOR trees de la paridad Hamming son cadenas combinacionales profundas. En
simulación el codec cuelga de la lectura BRAM registrada, pero a frecuencia de
silicio puede no cerrar. Si WNS negativo:

1. Estrategia `Performance_Explore` en síntesis.
2. Directiva `Explore` en place.
3. `AggressiveExplore` en post-route phys-opt.
4. Si aún no cierra: pipelinear el decode (etapa de registro entre decode y
   writeback en `ecc_codec` / `ecc_codec_mmio`). El acelerador es combinacional
   puro, así que insertar un registro en la salida es funcionalmente transparente
   para el firmware (que ya hace `sw DEC_IN; lw DEC_STATUS` en ciclos separados).

Diagnóstico de síntesis colgada: bisecar módulos con timeout. Culpables típicos:
LUTs con tipo record (aplanar a `std_logic_vector`), `mod` sobre signed en lazos
(usar máscara), cadenas CRC/XOR combinacionales profundas (pipelinear).

---

## 5. PetaLinux + BOOT.BIN + SD

1. `system-user.dtsi`: reservar DDR `0x70000000` 16 MB `no-map`; declarar el
   esclavo AXI-Lite `0x80000000` 64 KB.
2. Compilar el `ecc-selftest` (aarch64):
   `aarch64-linux-gnu-gcc -O2 -static ecc_selftest.c -o ecc-selftest`.
3. Desplegar el binario en `/usr/bin/` del initramfs (corre desde RAM).
4. Empaquetar: **repackage BOOT.BIN** (nunca hot-load PDI; el PLM lo rechaza con
   `0x03024001`). Copiar BOOT.BIN + `image.ub` a la tarjeta SD.
5. Boot desde SD; consola serie picocom 115200 8N1.

Acceso PS a DDR `no-map`: SIEMPRE `volatile` palabra a palabra. `memset`/`memcpy`
fallan con SIGBUS en memoria `no-map` (por eso el selftest usa loops de word).

---

## 6. Ejecución del selftest

```
# en la consola serie de la TE0950
ecc-selftest ecc_fw_tiles.mem 1024
```

Secuencia interna (ver `ecc_selftest.c`):

1. `mmap` de `/dev/mem` para AXIL (`0x80000000`) y DDR (`0x70000000`).
2. RUN A: escribe región corrupta en DDR (word-by-word), carga firmware por la
   ventana IMEM, libera el core (`CONTROL=0`), espera el doorbell, firma la
   región corregida de DDR.
3. RUN B: misma región corrupta, firmware con `cfg=0` (no corrige), firma.
4. Veredicto: `sigA != sigB` -> protección demostrada -> `L5 SILICON PASS`.

Nota: la config del firmware (`cfg`, `n_words`, `ddr_off`) se pasa por la RAM
local. Si el `axil_soc` no expone ventana DMEM al PS, la variante de firmware con
`cfg` fija por build cubre el contraste (dos `.mem`: uno con scrub ON, otro OFF),
o se añade la ventana DMEM al `axil_soc` (patrón ya presente en `soc_top_pipe`).

---

## 7. Consistencia end-to-end (ya verificada en simulación)

- **Codec ECC** bit-idéntico en tres implementaciones: oráculo Python
  (`ecc_oracle.py`), RTL VHDL (`ecc_codec.vhd`), C PS-side (`ecc_selftest.c`).
  Verificado por diff de 9 vectores de encode y por los 1504 vectores de Layer 1.
- **FNV-1a-32 word-wise** idéntico en firmware RV32, oráculo Python y C PS-side.
- **Codec MMIO** verificado con los 1504 vectores por el bus (Layer 5 unit).
- **Bucle de corrección del firmware** ejecuta sobre el SoC real hasta el doorbell.
- **Contraste protegido/no-protegido** demostrado en el oráculo de tiles
  (CE=40, DED=12, firma A != firma B).

Pendiente de validar en tu estación (necesita modelo de DDR/AXI4 slave):
- Lockstep completo del firmware de tiles sobre el SoC master con DDR simulada.
- Cierre de timing real en Vivado.
- Ejecución del `ecc-selftest` en la TE0950.

---

## 8. Firmas de referencia (documentar en el README del core)

| Capa | Firma | Escenario |
|---|---|---|
| L1 codec | `0x165aeb0d` | 1504 vectores encode/decode |
| L2 scrub | `0xccfdb060` | barrido N=64 (CE=21, DED=8) |
| L3 MMIO | `0x36525268` | traza de lecturas MMIO |
| L4 run A | `0xdb5e11bb` | SoC+firmware, scrub ON |
| L4 run B | `0x0f37257a` | SoC+firmware, scrub OFF |
| L5 tiles A | `0x9986c2e9` | tiles N=300, scrub ON (CE=40, DED=12) |
| L5 tiles B | `0xa44f7975` | tiles N=300, scrub OFF |

Core ID: `0x5C520020`.
