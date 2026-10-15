# RV64IMAC Linux SoC - Especificacion congelada v1 (+ enmiendas v1.1)

Fecha de congelacion: 2026-10-14. Enmiendas v1.1: 2026-10-15 (seccion 12).
Base: nuevo core (no fork). Hereda metodologia y oraculos de IP_Cores/RV32IMA.
Repo al publicar: IP_Cores/RV64IMAC/
Destino de produccion: ASIC IHP SG13G2. Prototipo en silicio: TE0950 / VCK190.

## 1. Objetivo
Core RV64IMAC con privilegios M/S/U y MMU Sv39 que arranque OpenSBI
(fw_jump) + Linux 6.x con MMU hasta shell busybox. Integrable con el
resto de IP_Cores (perifericos AXI4-Lite 32b + irq) sin modificarlos.

## 2. ISA
- RV64I + M + A + C + Zicsr + Zifencei. Perfil de software:
  -march=rv64imac_zicsr_zifencei -mabi=lp64.
- SIN F/D (sin FPU). Kernel con CONFIG_FPU=n; buildroot lp64.
- M: mul/mulh/mulhsu/mulhu/mulw, div/divu/rem/remu y variantes W.
  Multiplicador iterativo (radix-4/radix-16, 16-32 ciclos) y divisor
  iterativo radix-2 (64 ciclos). Sin DSP: el RTL es portable a ASIC.
- A: lr.w/lr.d, sc.w/sc.d, 9 AMO x {w,d}. Reserva de una linea de cache;
  se pierde en trap, sc, o escritura de otro maestro a la linea (v1: mono-hart).
- C: decompresor en etapa IF; fetch alineado a 16 bit, instrucciones de
  32 bit pueden cruzar linea de cache y pagina (dos accesos, dos posibles
  page faults: stval apunta al byte de la pagina que falla).
- fence: nop en v1 (in-order, un solo puerto de datos).
- fence.i: write-back de D$ sucio + invalidacion completa de I$ + flush pipeline.
- wfi: para el pipeline hasta interrupcion pendiente (aunque este enmascarada).

## 3. Privilegios y CSRs
Modos M, S, U. Conforme a Privileged Spec 1.12.
- M: mstatus (SIE,MIE,SPIE,UBE=0,MPIE,SPP,MPP,MPRV,SUM,MXR,TVM,TW,TSR,
  UXL=SXL=2 RO), misa (RO: RV64 ACIMSU), medeleg, mideleg, mie, mip,
  mtvec (direct + vectored), mscratch, mepc, mcause, mtval,
  mcounteren, mcountinhibit, menvcfg (solo FIOM), mvendorid/marchid/
  mimpid (RO 0 hasta asignar), mhartid=0, mconfigptr=0.
- S: sstatus (vista), sie/sip (vista via mideleg), stvec, sscratch,
  sepc, scause, stval, scounteren, satp (MODE: Bare|Sv39), senvcfg.
- Contadores: mcycle, minstret; cycle/time/instret en U/S segun
  counteren. time = mtime del CLINT cableado al core. hpmcounter3..31 = 0.
- PMP: 0 entradas (pmpcfg/pmpaddr leen 0, escrituras ignoradas).
  OpenSBI lo detecta y sigue. RIESGO declarado para produccion: sin PMP
  no hay aislamiento de OpenSBI frente a S-mode. PMP de 8-16 entradas es v2.
- Desalineados: excepcion (mcause 4/6); OpenSBI los emula.
- medeleg: delegables 1-9, 12, 13, 15. Bit 0 solo lectura a cero (con C no
  hay fetch desalineado), 11 (ecall-M) nunca.
- mstatus.FS/VS/XS/SD solo lectura a cero (sin F; la spec permite FS
  escribible con S-mode, Spike lo hace; nosotros no).
- Accesos ilegales a CSR -> illegal instruction, mtval = instruccion.

## 4. MMU Sv39
- satp.MODE=8 Sv39, ASID de 16 bit implementado (TLB etiquetada con ASID
  y bit G).
- I-TLB y D-TLB fully-associative de 8 entradas cada una, reemplazo
  round-robin; soporte de megapaginas (2 MiB) y gigapaginas (1 GiB).
- PTW hardware, un acceso en vuelo, lee PTEs a traves de D$ (coherente).
- Bits A/D: modelo Svade (sin actualizacion hardware): A=0, o D=0 en
  store, genera page fault. Linux lo maneja. Evita AMOs en el PTW.
- MPRV, SUM, MXR implementados. sfence.vma: flush total de TLBs y del
  pipeline (v1 ignora rs1/rs2 de forma conservadora, es legal).
- Fallo de acceso fisico (AXI SLVERR/DECERR) -> access fault (1/5/7).

## 5. Microarquitectura
- Pipeline en orden, 5 etapas: IF / ID / EX / MEM / WB, single issue.
- Forwarding EX->EX y MEM->EX; un ciclo de load-use stall.
- Saltos: prediccion estatica "no tomado" + BTFN para ramas; redirect
  en EX (penalizacion 2 ciclos). Branch predictor dinamico: v2.
- Traps precisos: la excepcion se registra con la instruccion y se toma
  al llegar a WB (commit unico); flush de todas las etapas mas jovenes.
- CSRs escritos en WB; instrucciones CSR serializan el pipeline.
- I$: 16 KiB, 2-way, linea 64 B, PIPT (v1.1, ver sec. 12).
- D$: 16 KiB, 2-way, linea 64 B, PIPT, write-back + write-allocate,
  LR/SC/AMO ejecutados en D$. Region de perifericos y CLINT/PLIC: no cacheable.
- Memorias de cache tras un wrapper unico (sram_1rw) con modelo
  comportamental y mapeo a macros SRAM IHP SG13G2 en el flujo ASIC.

## 6. Buses e integracion
- Maestro AXI4 de 64 bit (memoria): bursts INCR de 8 beats para lineas,
  single beat para no cacheable. ID unico, 1 transaccion en vuelo por canal en v1.
- Puente AXI4 64b -> AXI4-Lite 32b para la ventana de perifericos:
  aqui se cuelgan los IP_Cores existentes SIN cambios.
  Accesos de 64 bit a la ventana se parten en dos de 32 bit (orden LE).
- PLIC: 31 fuentes (1..31), 7 niveles de prioridad, 2 contextos
  (0 = M hart0, 1 = S hart0), compatible "riscv,plic0" para Linux.
- CLINT: msip, mtimecmp, mtime (contador a frecuencia fija, divisor
  configurable por generic).
- UART 16550 minima propia para consola de arranque (reutiliza la
  logica de rv32_uart, ampliada a irq).

## 7. Mapa de memoria (fisico, visto por el core)
| Base         | Tamano  | Contenido                                  |
|--------------|---------|--------------------------------------------|
| 0x0000_1000  | 4 KiB   | Boot ROM (reset vector 0x0000_1000)        |
| 0x0200_0000  | 64 KiB  | CLINT                                      |
| 0x0C00_0000  | 64 MiB  | PLIC                                       |
| 0x1000_0000  | 4 KiB   | UART consola                               |
| 0x1001_0000  | 16x64KiB| IP_Cores: bus MMIO nativo (slot n = 0x1001_0000+n*64K), irq n+2 |
| 0x2000_0000  | 256 MiB | Ventana AXI4-Lite 32 bit (IPs genericas)   |
| 0x8000_0000  | hasta 2 GiB | DRAM (cacheable)                       |
En prototipo Versal el adaptador traslada 0x8000_0000 -> DDR fisica
reservada (igual que RV32IMA), porque 0x8000_0000 es DDR del CIPS.
Todo lo que no es DRAM es no cacheable y ordenado.

PMA (comprobadas en el core, sin tocar el bus):
- DRAM: R/W/X, idempotente, cacheable, atomicos (LR/SC/AMO).
- Boot ROM: R/X.
- CLINT/PLIC/UART/ventana IP_Cores: R/W, no idempotente, sin X, sin atomicos.
- Resto: access fault.
- LR/SC/AMO fuera de DRAM -> access fault (5 LR, 7 SC/AMO), comprobado
  antes que la reserva. Fetch fuera de DRAM/ROM -> instruction access fault.
- Solo los loads a memoria idempotente se emiten especulativamente; stores,
  AMO, SC y cualquier acceso no idempotente esperan a que todo lo mas
  antiguo no pueda ya excepcionar.
- SC espera a que MEM y WB esten vacias (la reserva se fija en WB).

## 8. Reglas de RTL (portabilidad ASIC)
- VHDL-2008, sintetizable por GHDL+Yosys (ghdl-yosys-plugin) y Vivado.
- Sin primitivas de fabricante, sin DSP inferido explicito, sin latches.
- Reset: asincrono en assert, sincronizado en deassert, SOLO en flops de
  control; datapath sin reset.
- Prohibido indexar funciones/constantes VHDL para tablas (bug de Vivado
  2025.2.1 confirmado en silicio): ROMs sincronas canonicas o logica.
- Un solo reloj en el core; CDC solo en el borde (uart, mtime).

## 9. Verificacion (capas, misma metodologia que RV32IMA)
- Oraculo: ISS Python propio (iss64.py) escrito ANTES del RTL, validado
  contra riscv-tests oficiales (rv64ui/um/ua/uc/mi/si, entornos p y v).
- Capa 1: unidades (decompresor, mul/div, CSR, TLB, PTW, cache, PLIC)
  contra modelos independientes, dirigidos + aleatorios.
- Capa 2: core con memoria ideal, lockstep RTL vs ISS en cada retiro
  (PC, instruccion, rd, valor, CSRs de trap). riscv-tests completos.
- Capa 3: core + caches + AXI4 contra BFM con wait states aleatorios y
  modelo estricto de SmartConnect.
- Capa 4: SoC completo; lockstep de OpenSBI + primeros 10M de
  instrucciones de Linux. riscv-arch-test (compliance oficial).
- Capa 5: silicio FPGA (TE0950/VCK190), boot a shell.
- Capa 6 (ASIC): GDS en IHP SG13G2 con LibreLane, STA sign-off,
  gate-level sim de los tests de capa 2.
- Mutaciones: 4-5 por capa, todas deben fallar.

## 10. Diferido a v2
F/D, PMP, Debug Module (JTAG, Debug Spec 0.13), Svadu (A/D hardware),
branch predictor, multi-hart/coherencia, AXI con multiples IDs, Sstc.
RIESGO declarado: sin Debug Module, un chip fabricado solo se depura
por la UART y la boot ROM. Para tapeout real el Debug Module deberia
entrar antes de la Capa 6.

## 11. Pasos
- Paso 0: freeze (este documento)
- Paso 1: ISS iss64.py + riscv-tests (p y v) en verde
- Paso 2: pipeline RV64IM + Zicsr + traps M, memoria ideal, lockstep
- Paso 3: extension C (decompresor + fetch de 16 bit)
- Paso 4: extension A
- Paso 5: S/U + Sv39 (TLBs + PTW)
- Paso 6: I$ / D$ + maestro AXI4 + BFM con wait states
- Paso 7: CLINT, PLIC, UART, puente AXI4-Lite 32b a IP_Cores
- Paso 8: OpenSBI + Linux, lockstep ISS
- Paso 9: silicio Versal (Tcl, nunca Connection Automation)
- Paso 10: flujo ASIC IHP SG13G2

## 12. Enmiendas v1.1 (con su motivo)
1. Caches PIPT, no VIPT: la TLB traduce en X antes de emitir la peticion, asi que
   el indice ya es fisico sin coste. Elimina el aliasing de 16 KiB/2 vias
   (8 KiB por via > pagina de 4 KiB).
2. Zicbom (cbo.clean/flush/inval) anadido al ISA. Motivo: los DMA de las IP_Cores
   son maestros AXI4 hacia la DRAM y la D$ es write-back: sin Zicbom Linux no
   puede gestionar DMA no coherente. Semantica igual a Spike: habilitacion por
   menvcfg/senvcfg (CBIE, CBCFE; CBIE=10 -> 00), traduccion como load con fallos
   de store/AMO (15/7), sin fallos de PMA, no-op fuera de DRAM. cbo.inval se
   ejecuta como flush (permitido, seguro para Linux). DTS: riscv,cbom-block-size
   = 64 y dma-noncoherent.
3. Bus de las IP_Cores: las IP_Cores de la familia usan el bus MMIO "dmem" de un
   ciclo (sel/req/addr/wdata/wstrb/rdata), no AXI4-Lite. La ventana 0x1001_0000
   ofrece 16 ranuras nativas con ese protocolo (los cores se conectan sin
   cambios) y se anade una ventana AXI4-Lite 32 bit en 0x2000_0000 (256 MiB) para
   IPs genericas/Xilinx. Ambas parten los accesos de 8 bytes en dos de 32 bit.
4. Los DMA de las IP_Cores se unen a la DRAM fuera del SoC (SmartConnect/NoC en
   FPGA, interconexion del ASIC): el SoC expone un unico puerto AXI4 de DRAM.
5. mtvec/stvec: MODE con bit 1 siempre a 0 (como Spike, sin depender del valor
   anterior). medeleg[0] solo lectura a cero (con C no hay fetch desalineado).
6. Reset sincrono en todo el diseno (requiere sincronizador de deassert externo
   al SoC). Varios registros de datos del pipeline tienen reset: coste de area,
   no de correccion; optimizacion pendiente para el ASIC.
7. Traza RVFI ampliada: escrituras a memoria del retiro (rvfi_mem_*) y mip del
   retiro (rvfi_mip). El lockstep compara cada store y valida legalidad y
   vivacidad de cada interrupcion contra las lineas que ve el RTL.
8. mstatus.FS/VS/XS/SD solo lectura a cero (la spec permite FS escribible con
   S-mode y sin F; Spike lo hace, nosotros no). PMP con 0 entradas: CSRs de solo
   lectura a cero (Spike con 0 regiones los hace ilegales; ambas son legales).

### Diferencias conocidas con Spike (todas legales)
- PMP con 0 entradas (ver 8); mstatus.FS (ver 8); misa de solo lectura (Spike
  permite borrar C); marchid/mimpid/mvendorid = 0 hasta asignar.
- CSR de Sdtrig scontext/mcontext/tinfo: Spike los expone sin triggers.
- Spike rompe reservas LR/SC cada 5000 instrucciones (fallo espurio de SC).
- mtimecmp en reset: Spike 0, nosotros todo unos (no especificado).
