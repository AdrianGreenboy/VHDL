# Core 19 — Estrategia de verificación de la CDC (Layer 2b)

## Por qué la CDC no usa firma FNV bit-idéntica

Las capas 1 y 2a verifican con una firma FNV-1a 32-bit **bit-idéntica** entre RTL
y oráculo Python. La CDC dual-clock **no** puede verificarse así, y forzarlo
sería falsear el modelo: cuando dos relojes asíncronos cruzan datos, el número
exacto de ciclos que tarda un dato en cruzar depende de la fase relativa entre
relojes, que es no-determinista por naturaleza. Una firma temporal exigiría fijar
esa fase, lo que ocultaría precisamente el comportamiento que la CDC debe tolerar.

En su lugar, Layer 2b verifica **dos propiedades** de forma determinista, más una
tercera que corresponde a otra capa.

## P1 — Integridad de snapshot (simulable, verificada)

Tras cada `STATS_SNAP`, cuando llega `snap_done`, el registro shadow leído por AXI
coincide con el valor que el data plane tenía congelado, es coherente (los cinco
contadores del mismo instante) y estable hasta el siguiente snapshot. El handshake
`snap_done` es obligatorio: si no llega, la prueba falla.

Verificado en `tb_pcs_cdc.vhd`. El shadow multibit **no** cruza como bus vivo: se
lee sólo cuando es estático, tras confirmar por handshake que el snapshot en el
dominio dp terminó. Esto evita gray-code y es el patrón correcto para valores que
sólo se leen tras un evento de congelación.

## P2 — No-pérdida de eventos (simulable, verificada)

Cada pulso de evento generado en el dominio dp aparece exactamente una vez en el
dominio AXI. Contadores independientes en cada dominio; al final coinciden.
Verificado incluso con eventos generados **más rápido que el reloj AXI** (los
`rx_err` se emiten a ~2.6× el ritmo de AXI), que el toggle-sync serializa sin
perder ninguno.

## P3 — Seguridad de metaestabilidad (NO simulable, corresponde a Layer 5)

Dos clases de bug de CDC son **fundamentalmente invisibles** en simulación
funcional porque GHDL no modela la metaestabilidad de los flip-flops:

- Conectar una señal de estado directamente entre dominios sin doble-FF
  (funcionalmente da el mismo valor; el riesgo es metaestabilidad, no función).
- Reducir el número de etapas de sincronización (mismo conteo de eventos, menor
  margen de resolución de metaestabilidad).

Estas se verifican **estructuralmente** en Layer 5, no por testbench:

1. Constraints de CDC en Vivado: `set_clock_groups -asynchronous` entre el reloj
   dp (390.625 MHz) y el reloj AXI del SoC.
2. `report_cdc` de Vivado debe reportar cada cruce como *safe* (doble-FF para
   nivel, toggle/handshake para pulso y multibit), sin cruces *unsafe* ni
   *unknown*.
3. El análisis de timing con los relojes declarados asíncronos confirma que no
   se exige timing entre dominios (las rutas de cruce quedan como `false path`
   controladas por los sincronizadores).

## Resumen de cobertura por capa

| Propiedad                        | Capa   | Método                        |
|----------------------------------|--------|-------------------------------|
| Integridad de snapshot           | 2b     | testbench (P1), determinista  |
| No-pérdida de eventos            | 2b     | testbench (P2), determinista  |
| Doble-FF en señales de estado    | 5      | `report_cdc` = safe           |
| Etapas de sync suficientes       | 5      | `report_cdc` + timing         |
| Relojes declarados asíncronos    | 5      | constraints + `report_clocks` |

Esta separación es honesta: no se afirma que la simulación funcional prueba la
robustez ante metaestabilidad, porque no puede. La prueba de esa robustez es el
análisis estructural de Vivado sobre el silicio configurado.

## Addendum — cooldown en los toggles de eventos (hallazgo de Layer 5)

La verificación original de esta capa exigía **conteo exacto** de eventos entre
dominios. Esa propiedad es físicamente inalcanzable cuando la relación de
frecuencias es grande (dp 390.625 MHz frente a axi 40 MHz en silicio): dos
eventos en ciclos consecutivos del dominio rápido producen dos toggles que el
dominio lento nunca llega a muestrear, y el flanco se cancela. El fallo apareció
en Layer 5 como un `IRQ_STATUS` que leía cero pese a que el sticky interno del
banco valía `0x11`.

El CDC gatea ahora cada toggle con un contador de enfriamiento que garantiza un
nivel estable durante más de dos ciclos del dominio destino. La propiedad P2 se
corrigió en consecuencia:

- si hubo al menos un evento en dp, llega al menos uno a axi;
- no aparecen eventos espurios (axi ≤ dp).

Esto es suficiente porque los eventos alimentan **solo stickies de interrupción**.
Los contadores exactos (`CNT_RX_ERR`, `CNT_BER`) no viajan por eventos: cruzan por
el handshake de snapshot, que sí es exacto y está verificado en P1.
