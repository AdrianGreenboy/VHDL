# CONTEXTO — arranque del siguiente IP (tras MIL-STD-1553B)

Documento puente para empezar el próximo IP en una sesión nueva. Resume el
estado del proyecto, las convenciones congeladas, y todas las lecciones
acumuladas hasta el cierre del **MIL-STD-1553B** (silicio PASS, WNS +3.110 ns).

---

## 0. Qué está hecho

Familia de IP cores en VHDL-2008 para un SoC RV32IM v3 propio (TU Berlin / OHB,
tesis de ADCS + acelerador GEMV/matrix), sobre la Trenz **TE0950**
(`xcve2302-sfva784-1LP-e-S`).

IPs completados y validados en silicio: **USART, SPI, IIC, I3C, CAN, SpaceWire,
MIL-STD-1553B**. Todos con el mismo flujo de 5 capas + bring-up.

El 1553 quedó cerrado end-to-end:
- Capas 1a/1b/1c/2/4 con firmas bit-idénticas (`400485` / `462205` / `1679825`
  / `615665` / `552845` ns).
- Firmware verificado con intérprete RV32IM (firma = ISS).
- Vivado: síntesis + impl, **WNS +3.110 ns**, XSA exportada.
- Silicio: **`M1553 SILICON PASS`** (8 palabras de firma idénticas al ISS).

Repos: GitLab `gitlab.com/AdrianHerCoss/vhdl.git` (primario) y GitHub
`github.com/AdrianGreenboy/VHDL.git`; `git push origin` empuja a ambos.

---

## 1. Próximo IP (a decidir)

> **Rellenar al arrancar la nueva sesión.** Opciones sobre la mesa:
>
> - **Otro bus/periférico** (p. ej. Ethernet MAC lite, UART-DMA, ADC/DAC SPI de
>   alta velocidad, un segundo canal 1553 A/B para cerrar la v1.1).
> - **Vuelta a los aceleradores de la tesis**: el GEMV / matrix accelerator, que
>   es el objetivo real del trabajo de ADCS. Aquí el patrón cambia (no es un bus
>   serie sino un datapath), pero el andamiaje de verificación por capas y el
>   bring-up se reutilizan casi calcados.
>
> Cuando se decida, congelar el **alcance v1** en una fase de clarificación
> interactiva antes de escribir RTL (como en el 1553): arquitectura, formatos,
> registros, temporización, criterio de PASS de silicio, y qué queda fuera.

---

## 2. Convenciones congeladas (aplicar tal cual)

**Estructura de directorios.** Un directorio plano por IP (`~/<ip>_ip/` con
`rtl/`, `tb/`, `sim/`, `docs/`). Copia canónica del repo en
`~/vhdl_repo/IP_Cores/<IP>/`. Fuentes compartidas referenciadas desde su origen,
nunca duplicadas (el `spw_fifo.vhd` es la FIFO FWFT parametrizable canónica;
`~/rv32i/` tiene las fuentes compartidas del core; `asm.py` en `~/rv32i/`).

**Interfaz MMIO (familia).** Puerto `sel`/`we`/`rdata` con `rst` síncrono
activo-alto (`arstn = not rst` internamente, no `req`/`arstn`). `rdata` es
**combinacional** en el mismo ciclo del `sel` (contrato del dmem — un `rdata`
registrado pasa capa 2 pero falla capa 4). Pop-on-read con `VALID` en b31.
`EN` como reset síncrono + flush de FIFOs. Stickies generosos, limpieza por
escritura al registro STAT con **sets del mismo ciclo ganando**. IRQ por nivel:
`irq = OR(STAT and IRQEN)`, máscara alineada bit a bit con STAT.

**Región de memoria.** Decode por `addr[31:28]`. Usadas hasta ahora:
`00`→RAM, `0100`→DMA, y por IP: SPW `1011` (0xB000_0000), 1553 `1100`
(0xC000_0000). El siguiente IP puede tomar `1101` (0xD000_0000) si el
`mem_subsys` clonado lo tiene libre — **verificar** en el clon.

**Assembler / firmware.** `asm.py` (RV32IM subset). `lui` ya desplaza 12 bits
(no construir máscaras con `lui 0x20000` cuando quieres `lui 0x20`). Aislar
campos parcheables (BRP, etc.) en `addi` propias. Split de dirección de 40 bits:
`<0x0 0x70000000>`, no `<0x7 0x0>`.

**Verificación.** Flujo estricto de 5 capas: 1a (motor TX vs modelo receptor
independiente por eventos), 1b (motor RX vs transmisor bit-bang con
corrupciones), 1c (RTL vs RTL full-duplex con fase 0 anti-modo-común + vigilante
de cable independiente), capa 2 (banco MMIO vs BFM del dmem), capa 4 (SoC con
RV32 corriendo el programa ensamblado, ISS Python primero como oráculo), capa 5
(silicio en la TE0950). Firma = end-timestamp bit-idéntico; cualquier
divergencia es bug. **Cada capa lleva mutaciones que DEBEN fallar** (un banco
sin dientes no vale). Asserts en español con `severity failure`, en ASCII puro
(GHDL rechaza no-ASCII en asserts).

**Entrega.** Cada IP se desarrolla end-to-end en una sesión: diseño → 5 capas de
simulación → Vivado → PetaLinux → SD → silicio PASS → README (inglés, ~12-14
secciones, con SVG de arquitectura EMBEBIDO, no referenciado) → commit → contexto
para el siguiente. Un bloque robusto por paso, con fallbacks dentro del mismo
bloque, cero placeholders (`<name>`), salida esperada indicada en una línea.
`mv` no `cp` al mover de `~/Downloads`. Guard blocks con subshell `( ... )`,
nunca `exit` a pelo (mata el terminal interactivo).

**Paletas de SVG (760×560).** SPW steel-blue (`#eef4f8`/`#3d7ea6`), I3C berry
(`#fdeef4`/`#b03a6e`), USART/SPI azul (`#eef3fb`/`#4a6fa5`), **1553 oliva militar
(`#eef4ee`/`#4a7a4a`)**. Elegir una nueva para el siguiente IP.

---

## 3. Lecciones de Vivado (todas, acumuladas)

- `save_project_as` clona runs sucios: `reset_run synth_1/impl_1` y borrar el
  `INCREMENTAL_CHECKPOINT` tras clonar. La propiedad
  `STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_CHECKPOINT` **no existe** en Versal
  2025.2; usar `INCREMENTAL_CHECKPOINT ""` del run.
- Barrer con `foreach f [get_files -all *]` referencias al proyecto padre tras
  clonar (`.bd` remoto, wrappers, DCPs, `nocattrs.dat`).
- **Residuo del module reference** (nuevo con el 1553): al borrar la celda del IP
  clonado queda `bd_soc_usart_u_soc_<ip>_0.xci` en `sources_1`; `remove_files` lo
  rechaza (*"must be removed via the sub-design parent"*). Se limpia con
  `generate_target all [get_files bd_soc_usart.bd]` tras borrar la celda.
- **Referencias remotas en `sim_1`/`utils_1`** (nuevo): el `nocattrs.dat` y el
  `.dcp` del clon necesitan `remove_files -fileset sim_1 …` / `-fileset utils_1 …`
  explícito.
- **Pin inventado** (nuevo): verificar SIEMPRE `PACKAGE_PIN` contra
  `get_package_pins -filter {BANK == N}` antes de sintetizar. El banco de los
  headers accesibles de la TE0950 usado hasta ahora es el **302 HDIO** (LVCMOS33;
  el CAN usó D10, C10 documentado; el 1553 usó C10/D10/A10).
- **Tcl uno por uno, sin `puts`/`;`** (nuevo, importante): los comandos
  compuestos se cortan o concatenan al pegarse en la consola (se perdió una `c`
  de `connect` y varias salidas de verificación). Comandos simples de una línea.
- Connection Automation en Versal rutea maestros del PL a `S_AXI_LPD` (sin DDR):
  **siempre** Tcl scripteado para el NoC. El maestro del PL va a un SI dedicado
  (`S06_AXI`) con su propio `aclk` (`aclk6` asociado SOLO a `S06_AXI`). Auditar
  con `bd_review.tcl` (`~/vhdl_repo/IP_Cores/USART/bd_review.tcl`).
- `validate_bd_design` dice OK aunque esté válidamente equivocado → auditar con
  `bd_review.tcl` (ojo: el script busca la celda `u_soc`; si la tuya se llama
  `u_soc_<ip>`, la sección reloj/reset del reporte sale vacía — verificar a mano
  con `get_bd_nets -of_objects [get_bd_pins /u_soc_<ip>/aclk]`).
- `connect_bd_net` puede fallar en silencio → verificar cada conexión con
  `get_bd_nets -of_objects [...]`.
- Top de implementación = wrapper del BD (`bd_soc_usart_wrapper`). PL CLK0 a
  100 MHz. `~` no se expande en Tcl → `$env(HOME)`.
- Fuentes VHDL como **VHDL 2008** explícitamente
  (`set_property file_type {VHDL 2008}`) — sin esto la síntesis peta.

---

## 4. Lecciones de PetaLinux / SD

- Los proyectos PetaLinux viven en `~/plnx_te0950_<ip>` (clonar del más cercano,
  p. ej. `plnx_te0950_spw`). Instalación en `~/Petalinux/` (`source settings.sh`).
- Clonar con `cp -r` y luego `rm -rf build/tmp build/cache` (el clon arrastra
  rutas absolutas). Re-apuntar con
  `petalinux-config --get-hw-description=<xsa> --silentconfig`.
- **reserved-memory**: el device tree del SPW reserva `0x7000_0000` (16 MB,
  nodo `rv32i_reserved`). Reutilizarla (apuntar el verificador ahí) evita editar
  el device tree. Split de 40 bits: `reg = <0x0 0x70000000 0x0 0x01000000>`.
- Nunca hot-load del PDI de implementación sobre un PL configurado (PLM lo
  rechaza, `0x03024001`); siempre repackage `BOOT.BIN` vía PetaLinux
  (`petalinux-package --boot --plm --psmfw --u-boot --dtb --force`).
- SD: reformatear (`mkfs.vfat -F 32 -n BOOT /dev/sdX1`) + `fsck.vfat -v` para
  evitar el fallback silencioso de u-boot y la corrupción de FAT. La SD del
  workstation fue `/dev/sda` (29.1G, `RM=1`), partición BOOT `/dev/sda1`.
  **Verificar SIEMPRE con `lsblk` cuál es la SD antes de formatear.**
- En el target la SD monta por etiqueta: `/run/media/BOOT-mmcblk1p1` (con la
  label `BOOT` que pone el `mkfs`). Prompt del target heredado del linaje:
  `root@plnxte0950usart:~#` (el hostname dice `usart` aunque el HW sea otro).
- Sin SSH entrante: transferencia por microSD exclusivamente.
- Verificador del PS: `aarch64-linux-gnu-gcc -O2 -static`. Mapea el esclavo
  AXI-Lite del core en `0x8000_0000` (offset del BD), carga el firmware por la
  ventana IMEM (`0x1000`), fija `DDR_BASE_{LO,HI}`, suelta el core
  (`CONTROL.bit0 = 0`), sondea la palabra centinela y compara la firma.

---

## 5. Bloques reutilizables (copiar y adaptar)

- **Interfaz dmem + banco MMIO**: `m1553_mmio.vhd` es el patrón más completo
  (FIFOs parametrizables, stickies set-wins, IRQ nivel, LOOP_INT, skid de
  colisión). Buen punto de partida para el siguiente IP.
- **mem_subsys**: `mem_subsys_m1553.vhd` es el clon con region propia; cambiar el
  decode `addr[31:28]` y el nombre del puerto del IP.
- **SoC top + wrapper**: `soc_top_m1553.vhd` + `soc_top_m1553_wrap.v` — clon del
  `soc_top_spw`; ajustar el IP colgado, la región, y los pads.
- **Testbench de capa 4 + ISS**: `tb_m1553_l4.vhd` + `iss_m1553.py` — el ISS
  Python como oráculo primero, luego el RTL contra su firma. El maestro de bus de
  comportamiento debe pulsar `req` UN ciclo (como el RV32 real), o el pop-on-read
  se dobla.
- **Intérprete RV32IM** (validación de firmware sin el core real): el pequeño
  intérprete usado para verificar `fw_m1553.mem` contra el ISS es reutilizable;
  separa "¿bug de SW o de HW?" antes del bring-up.
- **Guiones Vivado**: `bd_<ip>_steps.tcl`, `run_synth_<ip>.tcl`,
  `run_impl_<ip>.tcl` — clonar y ajustar rutas/nombres.
- **Bring-up**: `m1553_bringup.c` + `BRINGUP_1553.md` — plantilla del verificador
  del PS y del runbook de placa.

---

## 6. Recordatorios de estilo

- Congelar alcance tras una fase de clarificación interactiva; evaluación honesta
  de riesgos por delante, no estimaciones optimistas.
- Claude escribe ficheros completos y localmente verificados (GHDL 4.1.0
  `--std=08` disponible en su entorno) antes de entregar; Adrián ejecuta y pega
  la salida exacta incluyendo los end-timestamps; ambos confirman firmas
  bit-idénticas en cada capa.
- Un bloque robusto por paso, con fallbacks; cero placeholders; salida esperada
  en una línea (así solo se pega la salida cuando algo difiere).
- README en inglés, asserts en español, comentarios de código donde ayuden.
- Al terminar cada IP: `git push origin`, generar este documento de contexto para
  el siguiente.
