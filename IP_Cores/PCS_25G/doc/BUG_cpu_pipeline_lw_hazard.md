# BUG ABIERTO — `cpu_pipeline`: se pierde el segundo `lw` consecutivo a memoria con espera

**Estado:** abierto (pendiente de corregir)
**Severidad:** alta — fallo silencioso, sin excepción ni señal de error
**Detectado:** Core 19 (PCS_25G), Layer 5 en simulación, agosto 2026
**Afecta:** todos los SoC de la familia HERCOSSNUX que hagan dos o más lecturas
MMIO encadenadas (`cpu_pipeline` es infraestructura compartida)

---

## Síntoma

Cuando el firmware ejecuta dos instrucciones `lw` consecutivas a una región cuyo
`dmem_ready` se difiere (periférico MMIO multi-ciclo, p. ej. a través de un
puente a AXI-Lite), **el segundo acceso nunca llega al bus `dmem`**. El registro
destino recibe dato residual del bus, que suele ser un valor plausible — por eso
no se detecta por inspección.

La tercera lectura de una ráfaga vuelve a funcionar: el patrón es que falla el
segundo de cada pareja.

## Evidencia (Core 19, `tb_soc_pcs_diag`)

Código generado por GCC (`fw_rv32_sim.elf`, sin el workaround):

```
 e8: lw a6,36(a5)   -> 0xD0000024 CNT_TX_BLK   presente en el bus
 ec: lw t3,40(a1)   -> 0xD0000028 CNT_RX_BLK   AUSENTE del bus
 f0: lw a1,48(a2)   -> 0xD0000030 CNT_BER      presente en el bus
...
178: lw a2,48(a5)   -> 0xD0000030 CNT_BER      presente en el bus
17c: lw t1,20(a4)   -> 0xD0000014 IRQ_STATUS   AUSENTE del bus
```

Traza de accesos observada en el bus `dmem` (ventana del periférico):

```
0x00 RD, 0x1C WR, 0x08 WR, 0x0C WR, 0x0C WR, 0x20 WR,
0x10 RD, 0x24 RD, [falta 0x28], 0x30 RD, 0x1C WR, 0x20 WR,
0x30 RD, [falta 0x14]
```

Contadores de ciclos con `sel` activo: `0x10`=5, `0x30`=10 (dos accesos),
`0x14`=**0**. El registro `IRQ_STATUS` contenía internamente `0x00000011`
(verificado por nombre externo) mientras el firmware leyó `0x00000000`.

Descartado previamente, en este orden: generación del evento en el data plane
(ocurre), cruce de dominio (llega), armado del sticky en el banco (correcto),
código del firmware (la instrucción existe en el binario).

## Reproducción mínima sugerida

Testbench directo sobre `cpu_pipeline` con una memoria de prueba que asserte
`dmem_ready` con N ciclos de retardo (N >= 2), ejecutando:

```asm
    lui  a0, 0xD0000
    lw   a1, 0(a0)     # primer load: estanca el pipeline
    lw   a2, 4(a0)     # segundo load: NO aparece en el bus
    lw   a3, 8(a0)     # tercer load: vuelve a aparecer
```

Comprobar en el bus `dmem` que las tres direcciones (0, 4, 8) se solicitan.
Con el bug presente, la dirección 4 no aparece y `a2` toma dato residual.

## Causa probable

Manejo del estancamiento en la etapa de memoria: la petición del segundo load
parece consumirse durante el ciclo en que el primero aún espera `dmem_ready`,
de modo que el `dmem_req` correspondiente nunca se emite. Revisar cómo se
mantiene/reafirma `dmem_req` y el avance de las etapas mientras `dmem_ready`
está a `'0'`.

## Mitigación temporal (aplicada en Core 19)

En `fw_rv32.c` del Core 19, todas las lecturas del periférico pasan por:

```c
static uint32_t PCS_RD(uint32_t off)
{
    uint32_t v = *(volatile uint32_t *)(PCS_BASE + off);
    __asm__ volatile ("" ::: "memory");
    delay_cycles(2);          /* rompe la cadena lw-lw */
    return v;
}
```

Con esta mitigación el Layer 5 pasa (`LAYER5SIM_PASS`): traza completa de 14
accesos, `IRQ_STATUS=0x11`, `FLAGS=0xF`.

**La mitigación no sustituye a la corrección**: cualquier firmware que encadene
lecturas MMIO sin conocer este bug leerá datos erróneos sin ningún aviso.
