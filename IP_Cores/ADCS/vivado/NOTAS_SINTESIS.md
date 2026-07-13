# Flujo de síntesis del IP ADCS — selección de arquitectura fp32_fma

El `fp32_fma` tiene DOS arquitecturas sobre la misma entidad:

- **`behav`** (`rtl/fp32_fma.vhd`): FMA fp32 bit-exacto en enteros (GHDL).
  Es la que usan las capas de simulación 1–4. Los runners compilan
  `fp32_fma.vhd` y NO `fp32_fma_xil.vhd`, así que GHDL siempre toma `behav`.

- **`xil`** (`rtl/fp32_fma_xil.vhd`): instancia el core Floating-Point Operator
  `fp_fma` de Xilinx (caja negra). Es la de SÍNTESIS en Vivado.

## Regla de oro del transplante Vivado

En el proyecto Vivado del SoC ADCS:

1. Generar el core con `vivado/package_fpo.tcl` (crea `fp_fma`, latencia 8).
2. Añadir al fileset de síntesis **`fp32_fma_xil.vhd`** (arquitectura `xil`),
   y **NO** `fp32_fma.vhd` (la `behav` usa un acumulador de 480 bits que no es
   sintetizable y no debe entrar al build).
3. El resto del RTL del IP es idéntico entre simulación y síntesis.

Para forzar la arquitectura sin ambigüedad, se puede usar una configuración
VHDL en el top de síntesis, o simplemente excluir `fp32_fma.vhd` del fileset
`sources_1` (dejándolo solo en `sim_1`).

## Firma bit-exacta en silicio (verificado contra PG060)

El FMA fusionado del FPO cumple IEEE-754 a media ULP con RNE + FTZ, es decir
resultado correctamente redondeado con redondeo único. Por tanto produce el
MISMO bit-patrón que el modelo `behav` para cada operación. La firma de
simulación se extiende a placa: el criterio de silicio del ADCS es firma
bit-idéntica de extremo a extremo, no el nivel degradado (plano de control +
error máximo).

Condición: TODO el datapath del MPC usa el core FMA (el add es `fma(a,1.0,b)`).
No instanciar un core Add/Subtract separado — mezclar Add unfused con FMA
fusionado podría diferir en LSBs.

## Latencia (de la tesis, validada en silicio)

`C_Latency = 8`, `C_Rate = 1`, `Flow_Control = NonBlocking`. El interlock del
`mpc_dot_row` (NACC=16) tolera cualquier latencia efectiva ≤ 14; la capa 1b lo
verifica hasta LAT=20. Si el core reporta una latencia efectiva distinta de 8
en la plataforma Versal, el diseño sigue siendo correcto por el interlock; se
documenta el valor real en el tag de debug de silicio.
