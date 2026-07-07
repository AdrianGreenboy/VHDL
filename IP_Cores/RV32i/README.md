# rv32i-vhdl

Un core RISC-V **RV32I** escrito desde cero en VHDL-2008, pensado para ser
claro, verificable y sintetizable en FPGA. Objetivo de plataforma:
**AMD Versal VE2302** (Trenz **TE0950**), con flujo Vivado.

> Estado: **en construcción**. Fase 1 (cimientos) en progreso.

## Arquitectura

- **ISA:** RV32IM. Base entera + extension M (mul/div); mul mapea a DSP58,
  div es iterativa (restauradora, ~34 ciclos) con handshake de stall.
- **Microarquitectura:** pipeline in-order de 5 etapas
  `IF -> ID -> EX -> MEM -> WB`, con:
  - forwarding EX/MEM y MEM/WB,
  - detección de hazards con stall en load-use,
  - resolución de saltos en EX (flush de 2 etapas).
- **Memorias:** BRAM (instrucciones + datos) para bring-up standalone;
  wrapper AXI4 posterior para colgarlo del NoC/CIPS del Versal.

## Estructura

```
rtl/
  riscv_pkg.vhd   Tipos, opcodes, funct3, enums de ALU y muldiv
  alu.vhd         ALU combinacional (RV32I)
  regfile.vhd     Banco de 32 registros (x0=0, bypass write-first)
  muldiv.vhd      Unidad mul/div de la extension M (handshake start/busy/done)
  immgen.vhd      Generador de inmediatos (I/S/B/U/J)
  control.vhd     Decoder / unidad de control (produce ctrl_t)
  csr.vhd         CSRs (Zicsr) + traps e interrupciones de modo maquina
  clint.vhd       CLINT: timer (mtime/mtimecmp) + software interrupt
  imem.vhd        Memoria de instrucciones (carga program.mem)
  dmem.vhd        Memoria de datos (byte enables para SB/SH/SW)
  cpu.vhd         Datapath single-cycle RV32IM (stall en mul/div)
  cpu_pipeline.vhd  Core RV32IM con pipeline de 5 etapas (forwarding+hazards)
sim/
  tb_alu.vhd      Testbench autoverificable de la ALU
  tb_muldiv.vhd   Testbench autoverificable de muldiv
  tb_decode.vhd   Testbench autoverificable del decode
  tb_cpu.vhd      Testbench de integracion (single-cycle)
  tb_cpu_pipeline.vhd  Testbench de integracion (pipeline)
  tb_trap.vhd     Testbench de CSRs + traps (ECALL/MRET)
  tb_irq.vhd      Testbench de interrupcion de timer (CLINT)
  tb_trap_pipeline.vhd / tb_irq_pipeline.vhd  Traps e interrupciones en pipeline
  asm.py          Mini-ensamblador RV32IM (+Zicsr, li) -> .mem
  program.mem     Programa de prueba ensamblado (ISA base)
  program_trap.s / program_trap.mem   Programa de prueba de traps
  program_irq.s  / program_irq.mem    Programa de prueba de interrupciones
  difftest_gen.py Generador de programas aleatorios + modelo de oro
  difftest_cmp.py Comparador de registros (modelo vs core)
  tb_difftest.vhd Banco que vuelca registros para differential testing
  difftest.sh     Orquesta el differential testing (genera/simula/compara)
  run_xsim.sh     Compila y corre los testbenches en xsim
LICENSE           MIT
```

## Simular (xsim de Vivado)

Primero carga el entorno de Vivado (ajusta la ruta a tu instalacion):

```sh
source /tools/Xilinx/Vivado/2025.2/settings64.sh
```

Todo de una vez con el script:

```sh
chmod +x sim/run_xsim.sh
./sim/run_xsim.sh          # tb_alu + tb_muldiv
./sim/run_xsim.sh muldiv   # solo muldiv
```

O a mano (por ejemplo la ALU):

```sh
xvhdl -2008 rtl/riscv_pkg.vhd rtl/alu.vhd sim/tb_alu.vhd
xelab -debug typical tb_alu -s tb_alu_sim
xsim tb_alu_sim -runall
```

> GHDL es opcional (solo si mas adelante quieres CI en GitHub Actions).

## Differential testing

Compara el core (pipeline) contra un modelo de referencia en Python sobre
cientos de programas aleatorios, sin toolchain de RISC-V:

```sh
./difftest.sh 50        # 50 programas aleatorios de 48 instrucciones
./difftest.sh 100 64    # 100 programas de 64 instrucciones
```

Para en el primer fallo dejando `program.mem` / `expected.txt` / `actual.txt`.

## SoC para el TE0950 (Versal VE2302)

SoC minimo para bring-up en el PL, controlado por el PS via AXI4-Lite:

```
rtl/
  dp_ram.vhd      RAM de doble acceso (CPU + PS), lectura asincrona
  axil_soc.vhd    Esclavo AXI4-Lite: control del core + ventanas IMEM/DMEM
  soc_top.vhd     Top: core single-cycle + IMEM/DMEM + esclavo AXI
sim/
  tb_soc.vhd      Emula al PS: carga programa, corre el core, lee resultados
  mem2coe.py      Convierte .mem -> .coe (para el Block Memory Generator)
```

Mapa AXI4-Lite: `0x0000` CONTROL (bit0=halt), `0x0004` STATUS, `0x0008` DBG_PC,
`0x1000` ventana IMEM, `0x2000` ventana DMEM.

Flujo del PS: CONTROL=1 (halt) -> cargar programa en IMEM -> CONTROL=0 (corre)
-> CONTROL=1 (halt) -> leer DMEM. Simular con `./run_xsim.sh soc`.

### Demo de acelerador (app Linux)

El A72 (Linux) usa el core como coprocesador: escribe datos en DMEM, el core
calcula, y el A72 lee el resultado.

```
sim/accel_sumsq.s   Programa acelerador (suma de cuadrados, usa mul)
sim/tb_accel.vhd    Valida el flujo completo en sim (= lo que hace la app)
sw/riscv_accel.c    App Linux (A72): mmap /dev/mem, carga, arranca, lee
vivado/vivado_soc.tcl  Crea el proyecto Vivado y agrega fuentes
INTEGRATION.md      Guia Vivado + PetaLinux + la app
```

Validar el flujo del acelerador en simulacion: `./run_xsim.sh accel`.

Integracion en Vivado (TE0950): instanciar `soc_top` como RTL, conectar
`s_axi_*` al AXI4-Lite del CIPS/NoC y `aclk`/`aresetn` del PS. En 2025.2.1 la
automatizacion CIPS+NoC se hace por GUI (el TCL truena con `mc_type`).

## Hoja de ruta

- [x] **Fase 1 — Cimientos:** package, ALU, register file, unidad muldiv (M), TBs.
- [x] **Fase 2 — Decode:** generador de inmediatos, decoder (I+M), unidad de control, TB.
- [x] **Fase 3 — Datapath single-cycle:** junta regfile+ALU+muldiv+decode y valida
      la ISA completa end-to-end con un programa (stall en mul/div).
- [x] **Fase 4 — Pipeline 5 etapas:** registros de pipeline, forwarding,
      load-use stall, flush de branches, stall de mul/div.
- [x] **Fase 5 — Zicsr + traps + interrupciones:** CSRs de modo maquina,
      ECALL/EBREAK/MRET y CLINT (timer + software irq), en el single-cycle Y en
      el pipeline (excepciones precisas + serializacion de CSR).
- [~] **Fase 6 — Verificacion:** differential testing (modelo Python vs xsim)
      operativo; falta riscv-arch-test / riscv-formal.
- [~] **Fase 6 — TE0950:** SoC (AXI4-Lite + IMEM/DMEM + control del core) listo y
      simulado; falta el block design en Vivado (CIPS/NoC) y la sintesis.
- [ ] **Fase 6 — Wrapper AXI4 + integración Versal:** CIPS/NoC en TE0950.
- [ ] **Fase 7 — Verificación:** riscv-tests / riscv-arch-test + CI con GHDL.

## Licencia

MIT — ver [LICENSE](LICENSE).
