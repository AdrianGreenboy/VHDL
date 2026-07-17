# RV32IMA Linux SoC - Especificacion congelada v1

Fecha de congelacion: 2026-07-17
Base: fork de ~/rv32i (RV32IM validado en silicio, referencia intocable)
Working dir: ~/rv32ima/    Repo al publicar: IP_Cores/RV32IMA/

## 1. Objetivo
Boot de Linux 6.x nommu hasta shell busybox por consola, en silicio
(TE0950 / xcve2302), sobre core RV32IMA_Zicsr propio, M-mode only.

## 2. ISA del core
- Base: RV32I + M (heredados, ya validados)
- Extension A: lr.w / sc.w con un unico reservation bit (mono-hart);
  amoswap.w amoadd.w amoand.w amoor.w amoxor.w amomin.w amomax.w
  amominu.w amomaxu.w
- Zicsr: csrrw csrrs csrrc csrrwi csrrsi csrrci
- SIN extension C (compressed). Kernel y userspace compilados
  -march=rv32ima -mabi=ilp32. Gotcha clasico: buildroot por defecto
  mete C; se deshabilita explicitamente.
- wfi implementado como nop legal.

## 3. CSRs (M-mode only)
mstatus (MIE/MPIE/MPP), misa (RO), mie, mip, mtvec (solo modo direct),
mscratch, mepc, mcause, mtval, mvendorid/marchid/mimpid (RO cero),
mhartid (RO cero), mcycle/mcycleh (RO contadores).

## 4. Traps e interrupciones
- Excepciones: ecall (M), ebreak, instruccion ilegal, load/store
  desalineado (mcause 4/6; software compilado strict-align)
- Interrupciones: MTI (timer CLINT) y MSI (msip). SIN MEI ni PLIC en
  v1: consola por polling.

## 5. Mapa de memoria visto por el core (compatible mini-rv32ima)
- 0x10000000: UART (THR/LSR estilo 8250 minimo, polling)
- 0x11004000/0x11004004: mtimecmp lo/hi
- 0x1100BFF8/0x1100BFFC: mtime lo/hi
- 0x11100000: syscon (poweroff/reboot)
- 0x80000000: RAM, 64 MB
Traduccion fija en el adaptador AXI: core 0x80000000 -> DDR fisico
0x70000000. La reserva rv32i_reserved se amplia de 16 MB a 64 MB en
system-user.dtsi.

## 6. Arquitectura de memoria del SoC (cambio estructural)
- El core pasa a ser master AXI4-Lite single-beat para fetch y
  load/store, via NoC a DDR, concurrente con el PS.
- NUEVO CONTRATO: se elimina el contrato de rdata combinacional de
  dmem local. La interfaz de memoria del core usa handshake con
  ready real y wait states arbitrarios; el pipeline stallea.
- SIN cache en v1. Rendimiento estimado 2-5 MIPS; boot lento pero
  funcional. Cache I/D es v2.
- Banco de control AXI-Lite slave para el PS en 0x80000000/64K:
  reset/start/halt del core, DBG_STATE, y FIFO de consola.
- Consola v1: la UART del core (0x10000000 lado core) desemboca en
  FIFOs TX/RX expuestos al PS por el banco AXI-Lite; herramienta
  rvcon en C sobre PetaLinux la vuelca a la consola serial.

## 7. Software
- Buildroot: toolchain riscv32 (rv32ima/ilp32), kernel 6.x
  CONFIG_MMU=n, initramfs busybox.
- DTB derivado del de mini-rv32ima (64 MB RAM, UART, CLINT, syscon).
- Arranque: a0=hartid, a1=puntero a DTB, PC=0x80000000.

## 8. Verificacion (5 capas adaptadas a core)
- Oraculo de referencia: mini-rv32ima (cnlohr, ~400 lineas C),
  probado contra Linux real. Se usa como ISS lockstep.
- Capa 1: unidades nuevas (CSR file, traps, A) vs modelo
  independiente por instruccion; tests dirigidos + torture.
- Capa 2: master AXI del core vs BFM de memoria con wait states
  aleatorios; verificar stall correcto del pipeline.
- Capa 3: SoC RTL completo, firmware bare-metal (setup de traps,
  timer, UART) con fin determinista.
- Capa 4: lockstep RTL vs mini-rv32ima de los primeros 2M de
  instrucciones del boot real del kernel; comparacion de traza de
  retiro (PC, rd, valor). Timestamp final bit-identico como firma.
- Capa 5: silicio. BOOT.BIN via PetaLinux (nunca PDI en caliente),
  rvcon, boot completo hasta shell busybox.
- Mutaciones: 4-5 por capa, todas deben fallar.

## 9. Diferido a v2
Cache I/D, S-mode + Sv32 + MMU, PLIC + MEI, extension C, SMP,
AXI4 con bursts.

## 10. Pasos
- Paso 0: fork + freeze (este documento)
- Paso 1: Zicsr + CSR file + traps
- Paso 2: extension A
- Paso 3: CLINT + MTI/MSI
- Paso 4: master AXI + traduccion de direcciones + BFM wait states
- Paso 5: UART/syscon MMIO + bare-metal lockstep vs mini-rv32ima
- Paso 6: buildroot; lockstep boot 2M instrucciones (Capa 4)
- Paso 7: Vivado BD + NoC (Tcl script, nunca Connection Automation)
- Paso 8: PetaLinux + rvcon + boot a shell (Capa 5)

## 11. Paleta SVG del proyecto
Verde bosque: fondo #eaf5ec, trazo #2e7d4f. Canvas 760x560.
