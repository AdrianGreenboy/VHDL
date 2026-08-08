# BUG CORREGIDO — cpu_pipeline: fallo de forwarding a un lw detenido durante un stall

**Estado:** CORREGIDO (agosto 2026) — validado en simulacion y en silicio
**Severidad:** alta — era un fallo silencioso, sin excepcion ni senal de error
**Detectado:** Core 19 (PCS_25G), Layer 5 en simulacion, agosto 2026
**Corregido:** cpu_pipeline.vhd, buffer historico de write-back (3er nivel de forwarding)
**Afecta (afectaba):** todos los SoC de la familia HERCOSSNUX; cpu_pipeline es infraestructura compartida por los 19 cores.

---

## Resumen ejecutivo

El sintoma observado ("se pierde el segundo de dos lw consecutivos a un periferico lento") era real, pero la causa raiz NO estaba en el handshake de memoria como se sospecho al principio. El handshake lw-lw con dmem_ready diferido funciona correctamente. El bug era un fallo de forwarding durante el estancamiento:

- Cuando un lw estanca el pipeline (stall_mem = '1', el periferico aun no responde), la etapa de avance ejecuta mem_wb <= MEMWB_NOP para insertar una burbuja hacia WB.
- Eso aplasta el resultado de la instruccion que en ese momento se estaba retirando por WB, eliminando su ruta de forwarding.
- Si la instruccion inmediatamente anterior al lw que estanca producia un registro que un lw posterior (detenido en EX/ID por el mismo stall) necesitaba como base, ese forwarding moria. El segundo lw computaba su direccion con la base obsoleta leida del banco (habitualmente 0).
- Con base = 0, la direccion del segundo lw caia fuera de la ventana del periferico (en la RAM local del SoC). Por eso "nunca aparecia en el bus del periferico" y el registro destino tomaba dato residual plausible: fallo silencioso.

La condicion se da SOLO cuando la distancia productor-de-base -> primer lw es de cero instrucciones (GAP = 0). Con una o mas instrucciones de holgura el forwarding normal (via ex_mem o mem_wb) cubre el caso y no hay error.

---

## Sintoma (tal como se observo)

Cuando el firmware ejecutaba dos lw consecutivos a una region con dmem_ready diferido (periferico MMIO multi-ciclo, p. ej. tras un puente a AXI-Lite), el segundo acceso no llegaba al bus del periferico con su direccion correcta. El registro destino recibia dato residual, un valor plausible; por eso no se detectaba por inspeccion.

## Evidencia original (Core 19, tb_soc_pcs_diag)

Codigo generado por GCC (fw_rv32_sim.elf, sin el workaround):

    e8: lw a6,36(a5)   -> 0xD0000024 CNT_TX_BLK   presente en el bus
    ec: lw t3,40(a1)   -> 0xD0000028 CNT_RX_BLK   AUSENTE del bus
    f0: lw a1,48(a2)   -> 0xD0000030 CNT_BER      presente en el bus
    ...
    178: lw a2,48(a5)  -> 0xD0000030 CNT_BER      presente en el bus
    17c: lw t1,20(a4)  -> 0xD0000014 IRQ_STATUS   AUSENTE del bus

El registro IRQ_STATUS contenia internamente 0x00000011 (verificado por nombre externo) mientras el firmware leia 0x00000000.

## Diagnostico definitivo (barrido de GAP)

Testbench tb_lw_hazard parametrizado por GAP (numero de nop entre la instruccion que produce la base y el primer lw). Memoria de prueba con dmem_ready combinacional diferido N = 2 ciclos. Resultado:

    GAP=0  d0=true d4=false d8=true  BAD_ADDR=0x00000004   <- HAZARD
    GAP=1  d0=true d4=true  d8=true                        <- OK
    GAP=2  d0=true d4=true  d8=true                        <- OK
    GAP=3  d0=true d4=true  d8=true                        <- OK
    GAP=4  d0=true d4=true  d8=true                        <- OK

Con GAP=0 el segundo lw salia con direccion 0x00000004 (base perdida, = 0) en vez de 0xD0000004. Confirma: fallo de forwarding durante stall, ventana GAP=0, no un problema de handshake.

## Ubicacion en el RTL

Etapa de avance del pipeline, rama de stall_mem:

    if stall_mem = '1' then
      ...
      mem_wb <= MEMWB_NOP;   -- aplasta el WB en vuelo; mata su forwarding
      ...

El forwarding solo tenia dos fuentes (ex_mem y mem_wb). Durante un stall, el productor recien retirado cae por el borde de mem_wb sin que ninguna instruccion detenida pueda aun reenviarlo.

## Correccion aplicada

Buffer historico de write-back como TERCER nivel de forwarding, persistente ante stalls de cualquier duracion. Aditivo: no toca la logica de stall ni la de WB.

    -- registro que retiene el ultimo WB retirado
    signal wbh_we   : std_logic := '0';
    signal wbh_addr : reg_addr_t := (others => '0');
    signal wbh_data : word_t := (others => '0');

    -- se captura cada flanco con el mem_wb vigente (lo que el regfile escribe)
    if mem_wb.reg_we = '1' and mem_wb.rd_addr /= "00000" then
      wbh_we <= '1'; wbh_addr <= mem_wb.rd_addr; wbh_data <= wb_data;
    end if;

    -- tercer termino en fwd_a / fwd_b, tras ex_mem y mem_wb:
    --   wbh_data when (wbh_we='1' and wbh_addr/="00000" and wbh_addr=id_ex.rsN_addr)

Prioridad de forwarding: ex_mem (mas nuevo) -> mem_wb -> wbh (mas viejo) -> valor del banco. El tercer nivel solo actua cuando no hay productor mas reciente en vuelo, por lo que nunca entrega un valor obsoleto.

Se preserva el contrato del bus dmem (rdata combinacional, valido el mismo ciclo que ready): el fix no toca la interfaz de memoria.

## Verificacion

- Reproduccion / barrido tb_lw_hazard.vhd (generic GAP): GAP=0..4 todos PASS tras el fix (antes GAP=0 fallaba con base corrupta).
- Regresion permanente tb_lw_hazard_reg.vhd (fija en GAP=0, el caso que fallaba, con severity failure): PASS con el CPU corregido; contra el CPU pre-fix aborta con REG_HAZARD (regresion bidireccional valida).
- Sin regresion en los testbenches del CPU: tb_difftest bit-identico pre/post; tb_cpu_pipeline, tb_irq_pipeline, tb_trap_pipeline todos los checkpoints PASS.
- Layer 5 del Core 19 en simulacion (tb_soc_pcs): LAYER5SIM_PASS con la mitigacion y tambien SIN la mitigacion (firmware directo, 612 bytes), IRQ_STATUS=0x11 leido correctamente.
- Silicio (TE0950, Versal xcve2302): pcs-selftest -> L5 SILICON PASS con el firmware SIN mitigacion. IRQ_STATUS=0x00000011 leido con acceso directo (PREG), que era exactamente la lectura que antes salia 0x00000000. Timing cerrado a 390.625 MHz (WNS 0.000 / WHS 0.000); el CPU no entra en el path critico (dominio con +7.6 ns de holgura), el fix es transparente al timing.

## Mitigacion (retirada)

La mitigacion en firmware (PCS_RD con delay_cycles(2) para romper la cadena lw-lw) SE RETIRO tras la correccion. El firmware del Core 19 volvio de 896 a 612 bytes leyendo con PREG() directo. Se conserva aqui solo como registro historico:

    /* MITIGACION RETIRADA - ya no necesaria tras corregir el CPU */
    static uint32_t PCS_RD(uint32_t off)
    {
        uint32_t v = *(volatile uint32_t *)(PCS_BASE + off);
        __asm__ volatile ("" ::: "memory");
        delay_cycles(2);          /* rompia la cadena lw-lw */
        return v;
    }

## Leccion

El sintoma apuntaba al handshake de memoria, pero la causa estaba en la interaccion stall <-> forwarding. Dos modelos de memoria plausibles (ready registrado y ready combinacional) NO reprodujeron el fallo; lo que lo aislo fue barrer la distancia productor-base -> load y trazar la direccion completa en el bus (no solo el offset). Moraleja: cuando un fallo "de memoria" depende del codigo exacto que lo rodea, sospechar del forwarding antes que del bus.
