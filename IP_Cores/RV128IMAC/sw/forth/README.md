# RV128 Forth: a native RV128 compute environment

No C compiler targets RV128, so the core brings its own language. `gen_forth.py` generates
a small Forth kernel in rv128asm source. It runs bare metal in RV128 mode, with 128-bit cells.

## Kernel

- **Threading.** Code is subroutine-threaded: every colon definition is real RV128 machine
  code. Control flow compiles `bnez`/`jal` directly.
- **Literals are inline, with no call:** `addi s1, x0, imm` for 12-bit values, otherwise
  `auipc` + `lq` + a jump over an aligned 16-byte cell. CREATE/VARIABLE/CONSTANT words have
  the same shape. Every compiled call is therefore a real `jal`/`ret` pair that the core's
  BTB and return-address stack predict.
- **Cache coherence.** `;` executes `fence.i`, so every definition exercises the D$→I$
  coherence path.
- **Registers and stacks.**
  - TOS is in `s1`.
  - The data stack sits at `s0` (top 0x8070_0000, grows down).
  - The return stack is `sp` (top 0x8080_0000) and also holds the DO/LOOP parameters.
- **Input.** An embedded script runs first, then the UART (16550, with echo and backspace).
  The input line buffer (TIB) holds 255 characters, and longer lines are cut.
- **Exit codes.** These go through `tohost`, so every script checks itself under the ISS,
  the lockstep and the board loader alike:
  - `BYE` ends with PASS.
  - `n FAIL` and `flag n ASSERT` end with code n.
  - A script error ends with code 3.
  - A trap ends with code 4.
- **Timer interrupt.** The trap handler serves the CLINT timer: it reloads mtimecmp to
  now + period, increments `TICKS`, and runs the word set with `ISR!`. It saves all
  registers, so a Forth word can be an interrupt handler.

## Words

- **Core:** stack, 128-bit arithmetic (`* / MOD U/ UM* M*`), comparisons, memory
  (`@ ! C@ C! D@ D! +! , C, ALLOT`), `: ; IF ELSE THEN BEGIN UNTIL AGAIN WHILE REPEAT DO LOOP
  +LOOP RECURSE CREATE CONSTANT VARIABLE ' EXECUTE ." S" .S WORDS CYCLES INSTRET BYE`.
- **Compute library, in assembly:**

| Area | Words | RV128 feature used |
|---|---|---|
| Bignum (limbs of 128 bits) | `BN0 BNCOPY BN0= BN+ BN- BN*1 BN/1 BN*` | 128x128→256 `mul`/`mulhu`, 128/128 `divu` |
| Fixed point Q64.64 | `F* F/` | `mul`+`mulh` give the exact 256-bit product; `F/` uses two 32-bit steps of the divider |
| SHA-512 | `SHA512 ( addr len out -- )` | the *D ops (`addd srlid sllid`) give 64-bit rotates/adds without masking |
| Poly1305 | `POLY1305 ( msg len key out -- )` | 130-bit accumulator in one 128-bit register + 2 bits |
| Lock-free stack | `LPUSH LPOP` | 128-bit head = pointer + version tag, a double-width CAS with `LR.Q/SC.Q` |
| Atomics / IRQ | `ATOM+ CAS ISR! TIMER TICKS` | `AMOADD.Q`, timer interrupt |
| Bit manipulation | `CLZ CTZ CPOP ROL ROR REV8 ANDN CLMUL CLMULH MIN MAX UMIN UMAX` | Zbb + Zbc (this core's RV128 extension) |
| AES-128-GCM | `AES-KEY AES-BLOCK GCM-ENC GCM-DEC GF*` | GHASH: one `clmul` + one `clmulh` for the full 128×128 product, reduced with shifts on the bit-reflected value; AES uses T-tables rotated with `roriw` |

SHA-512 uses `rorid` (64-bit rotate in one instruction), `rev8` + `srai 64` (big-endian
load) and `andn` (Ch). That cuts its instruction count by 33 % compared with v1.3.

- **Forth libraries** (`lib/`):
  - `core.fs`: `.N .0 .HEX`.
  - `bignum.fs`: `BN.` (decimal), `BNFACT`, `PI-COMPUTE`/`PI.` (Machin).
  - `fixed.fs`: `F. FSQRT FSIN FCOS`, and quaternions `Q* QCONJ Q.`.
  - `conc.fs`: `LCOUNT LTAG`.

## Tests and demos

`gen_tests.py` computes every expected value in Python (exact integers, hashlib, an RFC 8439
Poly1305 reference, high-precision Decimal sin/cos) and embeds it as ASSERTs.

| Script | Checks |
|---|---|
| tests/t_core | interpreter, compiler, control flow, CREATE/VARIABLE/CONSTANT |
| tests/t_bignum | 100!, BN* (2^256-1)^2 and a mixed product, BN-/BN+ carries, BN/1, 114 digits of pi |
| tests/t_fixed | F*, F/ (fast and slow path), exact FSQRT (= isqrt), sin/cos to 2^-56, quaternion rotation |
| tests/t_crypto | SHA-512 at lengths 0, 3, 111, 112, 128, 239, 1000; Poly1305 RFC 8439 vector + 7 lengths |
| tests/t_conc | 64 nodes moved between two lock-free stacks by the main loop and the timer ISR; conserves nodes, version tags = number of operations |
| tests/t_aes | FIPS-197 block, GF* vs the NIST bit-serial multiply, GCM test case 4 (encrypt + decrypt), 8 random key/IV/AAD/length combinations vs `cryptography` |
| tests/t_zb | CLZ/CTZ/CPOP/REV8/ROL/ROR on corner and random values, CLMUL/CLMULH, MIN/UMAX, ABS |
| demos/pi1000 | 1007 digits of pi (29 limbs) |
| demos/fact1000 | 1000! (2568 digits) |
| demos/bench | cycles of SHA512, POLY1305, BN*, F/, FSIN, ATOM+ |

## Usage

```
python3 sw/forth/gen_tests.py sw/forth/tests            # also writes sw/forth/demos
python3 sw/forth/build.py sw/forth/tests/t_*.fs          # build + ISS, must print PASS
python3 compare128.py --tb cpu sw/forth/out/t_conc       # lockstep (layer 7 of run_regression.sh)
python3 sw/forth/build.py --uart-div 27 --out sw/forth/out_board   # interactive image
```

To run on the board:

- The tests are staged by `fpga/soc/board_pack.sh` as `forth_*` (divisor 1), so `run_all.sh forth_` runs them.
- For the interactive console: `./rv128_soc_load -m rv128 -d 27 forth.bin@0` (115200 baud).
