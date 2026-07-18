# Paso 7b — Vivado, device tree y firmware del PS

Este paso no lleva script de validación automática: **Vivado no corre en
el contenedor**, así que entregarte una firma de PASS sería mentira. Lo
que sí está verificado se marca abajo.

## Archivos

| Archivo | Destino |
|---|---|
| `hercossnux_bd.tcl` | `~/rv32ima/` — construye el block design |
| `system-user.dtsi` | `<petalinux>/project-spec/meta-user/recipes-bsp/device-tree/files/` |
| `hercossnux_run.c` | compilar y copiar a la placa |

## Verificado en esta sesión

- **El stub que genera el driver es bit-idéntico al validado en
  simulación** (`stub.mem`). Era el punto de fallo más probable del
  bring-up: si `a1` no apunta al DTB, el kernel arranca y muere.
- `hercossnux_run.c` compila con `-Wall -Wextra` sin avisos.
- El top pasa `tb_soc_top` con latencias de NoC 0/1/4/12 tras el cambio
  del FIFO a molde BRAM (ver abajo).

## No verificado (requiere tu máquina)

- Que el Tcl construya el BD sin errores.
- Que síntesis e implementación cierren timing.
- El boot real en silicio.

---

## 1. Block design

```tcl
# desde la consola Tcl de Vivado
source $env(HOME)/rv32ima/hercossnux_bd.tcl
```

**Por qué existe este script**: en Versal, la Connection Automation rutea
el master AXI de la PL a `S_AXI_LPD`, que **no tiene camino a la DDR**. El
diseño implementa sin errores y falla en silicio con lecturas a cero. Todo
el cableado del NoC va a mano aquí.

Si prefieres ir comando a comando (más seguro, los fallos silenciosos
viven en los bloques pegados), el script está escrito para poder
copiarse por tramos leyendo cada respuesta.

**Verificación obligatoria antes de implementar:**

```tcl
get_bd_addr_segs -of [get_bd_addr_spaces rv32ima_soc_0/M_AXI]
```

Debe listar `C0_DDR_LOW0` y **ningún** segmento LPD. Si aparece LPD, el
NoC quedó mal cableado y el boot fallará en placa.

## 2. Device tree

La reserva sube de **16 MB a 64 MB** respecto a los cores anteriores: el
core RV32IMA modela 64 MB para el kernel nommu.

`no-map` es imprescindible — el core de la PL debe ser el único dueño de
esa región.

## 3. Firmware del PS

```bash
aarch64-linux-gnu-gcc -O2 -static -o hercossnux_run hercossnux_run.c
# copiar a la placa junto con kernel.img y hercossnux.dtb
./hercossnux_run kernel.img hercossnux.dtb
```

**El cuidado con `no-map`** (ya te mordió en cores previos): glibc aarch64
usa `DC ZVA` y `stp` de 128 bits en `memset`/`memcpy`, que dan **SIGBUS**
sobre regiones `no-map`. Todas las escrituras a DDR en el driver son
bucles palabra a palabra sobre punteros `volatile` (`wr32`, `blk_copy`,
`blk_clear`). **No los sustituyas por `memcpy` aunque parezca
equivalente.**

El driver hace una verificación de ida y vuelta tras cargar: si la DDR no
devuelve lo escrito, aborta antes de arrancar el core. Eso distingue un
problema de NoC de un problema del core.

## 4. Cambio en el top desde el 7a

El FIFO de consola pasó a **lectura síncrona con `ram_style="block"`**.
Con lectura asíncrona, 4096×8 bits se convertían en ~32k flip-flops más
muxes gigantes en vez de un solo BRAM. El camino de lectura AXI captura
ahora el dato en la fase `rvalid` (el FIFO llega un ciclo después).

Reverificado: PASS con latencias 0/1/4/12.

## Orden sugerido de bring-up

1. Correr el Tcl y **verificar el mapa de direcciones** (paso 1 arriba).
2. Sintetizar. Revisar en el informe de utilización que el FIFO mapeó a
   BRAM (`RAMB18E5_INT`) y no a FFs.
3. Empaquetar `BOOT.BIN` **por PetaLinux** — nunca hot-load del PDI; el
   PLM de Versal lo rechaza con `0x03024001`.
4. En la placa: `./hercossnux_run` y observar. Si la verificación de ida
   y vuelta falla, el problema es el NoC, no el core.
5. Si arranca pero se cuelga pronto, leer `[retiros=... pc=...]` que el
   driver imprime cada ~5 s: el PC te dice dónde.
