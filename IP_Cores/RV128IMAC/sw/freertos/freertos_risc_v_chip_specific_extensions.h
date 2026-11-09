/* RV128IMAC SoC in RV64 mode: SiFive-style CLINT with mtime, no extra registers
 * (no FPU, no vector). Same content as FreeRTOS RISCV_MTIME_CLINT_no_extensions. */
#ifndef __FREERTOS_RISC_V_EXTENSIONS_H__
#define __FREERTOS_RISC_V_EXTENSIONS_H__

#define portasmHAS_SIFIVE_CLINT           1
#define portasmHAS_MTIME                  1
#define portasmADDITIONAL_CONTEXT_SIZE    0

.macro portasmSAVE_ADDITIONAL_REGISTERS
    .endm

.macro portasmRESTORE_ADDITIONAL_REGISTERS
    .endm

#endif /* __FREERTOS_RISC_V_EXTENSIONS_H__ */
