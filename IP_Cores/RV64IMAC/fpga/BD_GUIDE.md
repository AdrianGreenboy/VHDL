# Prototipo RV64IMAC en Versal — guia (Paso 9)

**Estado: NO validado en silicio.** Todo lo de esta carpeta compila y sintetiza en
GHDL/Yosys, pero no ha pasado por Vivado ni por una placa. Es el punto de partida
para la Capa 5, no un resultado.

## Arquitectura del prototipo

```
A72 (PetaLinux) --M_AXI_FPD--> SmartConnect --> rv64/s_axi_ctrl   (0xA400_0000, 64 KiB)
                                                  CTRL/STATUS/RETIRED/PC + UART lado host
rv64/m_axi_dram --> NoC (S0x_AXI, nuevo) --> MC0 DDR_LOW0
                    el core ve 0x8000_0000 + off; fisico 0x7000_0000 + off (128 MiB no-map)
rv64/mm_* + irq_ip  --> IP_Cores (16 ranuras MMIO nativas) o constantes a cero
```

## Pasos

1. Boot ROM de la placa (DTS a 50 MHz, 128 MiB, consola ttyS0 115200):

   ```bash
   python3 sw/bootrom/build_bootrom.py --dts sw/bootrom/rv64_soc_fpga.dts \
           --out fpga/gen/rv64_bootrom_pkg.vhd
   ```

2. Proyecto y fuentes (TCL):

   ```bash
   vivado -mode batch -source fpga/create_project.tcl -tclargs te0950   # o vck190
   ```

3. **CIPS + NoC por GUI** (tu preferencia: la automatizacion TCL del CIPS no es fiable):
   - Create Block Design `design_1`.
   - CIPS (`versal_cips_0`): PS con LPDDR4 por el NoC como en tus proyectos TE0950;
     habilitar **M_AXI_FPD** y **pl0_ref_clk a 50 MHz** con `pl0_resetn`.
   - NoC (`axi_noc_0`) con el controlador de memoria y las entradas del PS. El
     script anade la entrada del RV64 (`NUM_SI + 1`) y su reloj.
   - Guardar el BD.

4. Insercion del SoC, conexiones, direcciones e implementacion hasta PDI (TCL):

   ```bash
   vivado -mode batch -source fpga/bd_insert_rv64.tcl -tclargs fpga/rv64_proto_te0950/rv64_proto_te0950.xpr design_1
   ```

   Revisar `timing_summary.rpt`. 50 MHz es una estimacion prudente: la ruta
   critica probable es X (sumador + TLB + PMA) hacia la direccion de la D$, y
   la de respuesta de la D$ hacia el control de paradas del pipeline.

5. PetaLinux: reservar la DDR del RV64 en `system-user.dtsi`:

   ```dts
   reserved-memory {
       #address-cells = <2>; #size-cells = <2>; ranges;
       rv64_reserved: rv64@70000000 { no-map; reg = <0x0 0x70000000 0x0 0x08000000>; };
   };
   ```

   BOOT.BIN por PetaLinux (nunca PDI en caliente, como en el RV32IMA).

6. En la placa:

   ```bash
   aarch64-linux-gnu-gcc -O2 -static -o rv64_load fpga/rv64_load.c
   ./rv64_load fw_jump.bin Image
   ```

   OpenSBI se compila igual que para simulacion; el kernel con
   `CONFIG_CMDLINE` vacio (usa los `bootargs` del DTS de la placa: ttyS0).

## Riesgos conocidos

- Los nombres de pines del NoC/CIPS cambian entre versiones de Vivado: el script
  comprueba que existen las celdas, pero los `CONFIG.*` del NoC pueden necesitar ajuste.
- El primer silicio deberia arrancar primero un test de riscv-tests desde la ROM
  (cambiar `FW_JUMP_ADDR` no hace falta: basta cargar el ELF `-p-` en 0x8000_0000)
  y comprobar `RETIRED`/`PC` en el banco de control antes de intentar Linux.
- Sin Debug Module: si se cuelga, la unica visibilidad es `RETIRED` y `PC`.
