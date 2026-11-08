# RV128IMAC — ISA definition used by this core (experimental)

## 0. Dual-XLEN core (v0.3)

`misa.MXL` is fixed at reset by the `m64` input of `rv128_core` (stable while running):

| m64 | Mode | Contents | Oracle |
|---|---|---|---|
| 0 | RV128 | RV128IMAC (this document) + M/S/U, Zicsr, Zifencei; paging **Bare** only (no RV128 paging scheme exists); no Zicbom (MISC-MEM f3=010 is LQ) | `iss128.py` |
| 1 | RV64 | RV64IMAC + Zicbom + Sv39, binary-identical to `rv64_core` (Linux, OpenSBI, RTOSes, standard RV64 toolchains) | `iss64.py`, unmodified |

In RV64 mode every register, pc, address and CSR value is kept as the sign extension of its
low 64 bits (checked on every retirement by `compare64.py`). The structure keeps the MMU,
S/U modes and the RVC/decoder paths parametrised by mode so a future RV128 paging scheme
or RV128 operating system can be added without reworking the core.

Status: **experimental**. RV128I is a *draft* base ISA (v1.7) that the RISC-V
manual removed after release 20240411 ("removal of unratified content,
including the sketch of the RV128I base ISA"). This document pins every
encoding this core implements so the RTL, the Python ISS and the assembler
agree. Where the draft is silent we follow QEMU's `x-rv128` decoder
(target/riscv/insn32.decode / insn16.decode) so QEMU can serve as an
independent oracle.

Source of truth for the draft: riscv-isa-manual tag `20240411`,
`src/rv128.adoc`, `src/c-st-ext.adoc`.

## 1. Base: RV128I

* XLEN = 128, 32 x 128-bit integer registers, x0 hard-wired to 0.
* All RV64I computational instructions operate on 128 bits.
* `*W` instructions (ADDIW, SLLIW, SRLIW, SRAIW, ADDW, SUBW, SLLW, SRLW, SRAW)
  operate on the low 32 bits and sign-extend bit 31 to bit 127.
* New `*D` instructions operate on the low 64 bits and sign-extend bit 63 to bit 127.
* LUI / AUIPC: 32-bit immediate sign-extended to 128 bits.
* Branch/JAL/JALR offsets sign-extended to 128 bits; PC is 128 bits.

### 1.1 Shifts

| Instr | Encoding | Notes |
|---|---|---|
| SLLI | imm[11:7]=00000, shamt=imm[6:0], f3=001, OP-IMM | 7-bit shamt |
| SRLI | imm[11:7]=00000, f3=101, OP-IMM | |
| SRAI | imm[11:7]=01000, f3=101, OP-IMM | |
| SLL/SRL/SRA | rs2[6:0] is the shift amount | |
| SLLIW/SRLIW/SRAIW | imm[11:5]=0000000/0000000/0100000, 5-bit shamt | as RV64 |
| SLLW/SRLW/SRAW | rs2[4:0] | as RV64 |

### 1.2 New opcodes

| Major opcode | Value | Name |
|---|---|---|
| OP-IMM-64 | `1011011` (0x5B, ex custom-2/rv128) | ADDID, SLLID, SRLID, SRAID |
| OP-64     | `1111011` (0x7B, ex custom-3/rv128) | ADDD, SUBD, SLLD, SRLD, SRAD, MULD, DIVD, DIVUD, REMD, REMUD |

| Instr | f7 / imm[11:6] | f3 | Opcode |
|---|---|---|---|
| ADDID | imm | 000 | OP-IMM-64 |
| SLLID | 000000 + shamt[5:0] | 001 | OP-IMM-64 |
| SRLID | 000000 + shamt[5:0] | 101 | OP-IMM-64 |
| SRAID | 010000 + shamt[5:0] | 101 | OP-IMM-64 |
| ADDD  | 0000000 | 000 | OP-64 |
| SUBD  | 0100000 | 000 | OP-64 |
| SLLD  | 0000000 | 001 | OP-64 (rs2[5:0]) |
| SRLD  | 0000000 | 101 | OP-64 |
| SRAD  | 0100000 | 101 | OP-64 |

### 1.3 Loads / stores

| Instr | Opcode | f3 | Width | Ext |
|---|---|---|---|---|
| LB/LH/LW/LD | LOAD | 000/001/010/011 | 8/16/32/64 | sign → 128 |
| LBU/LHU/LWU | LOAD | 100/101/110 | 8/16/32 | zero → 128 |
| **LDU** | LOAD `0000011` | **111** | 64 | zero → 128 |
| **LQ**  | MISC-MEM `0001111` | **010** | 128 | — |
| SB/SH/SW/SD | STORE | 000..011 | | |
| **SQ** | STORE `0100011` | **100** | 128 | |

Misaligned accesses raise address-misaligned exceptions (no hardware split).
Every naturally aligned access fits in one 128-bit bus beat.

## 2. M extension

* MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU on 128 bits (MULH* = upper
  128 bits of the 256-bit product).
* MULW, DIVW, DIVUW, REMW, REMUW: as RV64, result sign-extended from bit 31.
* MULD, DIVD, DIVUD, REMD, REMUD: OP-64, f7=0000001, f3 = 000/100/101/110/111,
  64-bit operands, result sign-extended from bit 63.
* Division by zero and overflow follow the standard M rules at the operation width.

## 3. A extension

funct3 selects width: `010` = .W, `011` = .D, **`100` = .Q (this core's choice;
matches QEMU's AMOCAS.Q slot)**.
LR, SC, AMOSWAP, AMOADD, AMOXOR, AMOAND, AMOOR, AMOMIN, AMOMAX, AMOMINU, AMOMAXU.
.W/.D values returned to rd are sign-extended to 128 bits. Natural alignment is
required (misaligned → store/AMO address-misaligned exception).
Single-hart reservation: LR sets a reservation on the aligned granule; SC
succeeds iff the reservation is valid and the address matches; any SC, trap or
`mret` clears it. AMOs assert `bus_lock` for the read-modify-write.

## 4. C extension (RV128C)

As RV64C with these RV128C changes:

| Quadrant | f3 | RV128C instruction | Offset |
|---|---|---|---|
| 00 | 001 | **C.LQ**  → `lq rd', off(rs1')` | inst[12:11]=off[5:4], inst[10]=off[8], inst[6:5]=off[7:6] |
| 00 | 101 | **C.SQ**  → `sq rs2', off(rs1')` | same as C.LQ |
| 10 | 001 | **C.LQSP** → `lq rd, off(x2)` (rd≠0) | inst[12]=off[5], inst[6]=off[4], inst[5:2]=off[9:6] |
| 10 | 101 | **C.SQSP** → `sq rs2, off(x2)` | inst[12:11]=off[5:4], inst[10:7]=off[9:6] |
| 10 | 000 | C.SLLI: shamt field 0 encodes **64** | |
| 01 | 100 | C.SRLI/C.SRAI: 6-bit shamt is **sign-extended**; 0 encodes **64** → legal 1–31, 64, 96–127 | |

C.LD/C.SD/C.LDSP/C.SDSP/C.ADDIW/C.ADDW/C.SUBW are retained.
There is no compressed form of the `*D` instructions.

## 5. Privileged architecture

M, S and U with the same CSR set and semantics as RV64IMAC (Privileged 1.12): `medeleg`,
`mideleg`, MPRV/SUM/MXR, TVM/TW/TSR, `mcounteren`/`scounteren`, `menvcfg`/`senvcfg`,
PMP with 0 entries, triggers reading 0. Differences in RV128 mode:

| CSR | RV128 mode |
|---|---|
| misa | MXL=3 (bits 127:126), extensions A C I M S U |
| mstatus | SXL = UXL = 3 (bits 35:32 = 0xF) |
| satp | reads 0, writes ignored (paging Bare: no RV128 scheme exists) |
| mcause/scause | interrupt flag in bit 127 |
| counters | 64-bit, zero-extended |

Traps: instruction access fault (1), illegal instruction (2), breakpoint (3),
load misaligned (4), load access fault (5), store/AMO misaligned (6),
store/AMO access fault (7), ECALL from U/S/M (8/9/11), page faults (12/13/15, RV64 mode). mtval: illegal -> instruction bits,
ebreak -> pc, memory faults -> address, ecall/irq -> 0.
MRET; WFI waits in W until (mip & mie) /= 0 (the ISS executes it as a nop);
FENCE is a no-op; FENCE.I serializes and pulses `fencei_o`.
Interrupt priority: MEI > MSI > MTI.

## 6. Physical address space and PMAs

Registers and PC are 128 bits. The memory map is the RV64IMAC SoC map and
lives in the low 4 GiB; any address with a non-zero bit in 127:32 is outside
the map and raises an access fault without a bus transaction:

| Region | Range | Attributes |
|---|---|---|
| boot ROM | 0x0000_1000 - 0x0000_1FFF | R/X |
| CLINT | 0x0200_0000 + 64 KiB | R/W (4/8-byte) |
| PLIC | 0x0C00_0000 + 64 MiB | R/W |
| UART | 0x1000_0000 + 4 KiB | R/W (byte) |
| IP_Cores x16 | 0x1001_0000 + 1 MiB | R/W (native MMIO) |
| AXI4-Lite window | 0x2000_0000 + 256 MiB | R/W |
| DRAM | 0x8000_0000 - 0xFFFF_FFFF | R/W/X, atomics |

Atomics (LR/SC/AMO) are only legal in DRAM. The LR/SC reservation granule is 64 B.

## 7. Microarchitecture (v0)

Derived from the RV64IMAC 5-stage pipeline (F/D/X/M/W, forwarding, precise
traps in W), with the MMU, S/U modes and Zicbom removed.

| Item | Value |
|---|---|
| Pipeline | in-order, 5 stages, as RV64IMAC |
| Instruction port | 32-bit, 4-halfword fetch buffer (unchanged from RV64IMAC) |
| Data port | 128-bit, 16 byte lanes: LQ/SQ/AMO.Q are one transaction |
| ALU | 128-bit add/sub/logic/compare, 128-bit barrel shifter |
| M unit | iterative, no DSP: radix-4 multiply (64/32/16 cycles for Q/D/W), radix-2 divide (128/64/32) |
| Register file | 31 x 128 bit |
