# RV128IMAC SoC en la TE0950 (M5)

El SoC completo (core dual, I$/D$, AXI4 de 128 bit, CLINT, PLIC, UART, boot ROM) con la
DDR por el NoC. Mismo flujo que `RV64IMAC/fpga` (validado en la placa el 2026-10-15:
`board_smoke` y Linux hasta `/init`). Diferencias: entrada del NoC de 128 bit, modo
RV64/RV128 elegido desde el PS (`CTRL.M64`) y veredicto `tohost` leido de la traza de
retiro (con la D$ write-back el `tohost` no llega a la DDR).

```
A72 (PetaLinux) --M_AXI_FPD--> SmartConnect --> rv128/s_axi_ctrl  (0xA400_0000, 64 KiB)
                                                 CTRL/STATUS/RETIRED/PC/TOHOST + UART host
rv128/m_axi_dram (128 bit) --> NoC (S0x_AXI) --> MC0 DDR_LOW0
                    el core ve 0x8000_0000 + off; fisico 0x7000_0000 + off (128 MiB no-map)
```

## Pasos (shell limpia, sin venv: lopper falla dentro de un venv)

1. Boot ROM de la placa (DTS a 50 MHz, 128 MiB, ttyS0 115200):
   ```bash
   cd ~/vhdl_repo/IP_Cores/RV128IMAC
   python3 sw/bootrom/build_bootrom.py --dts sw/bootrom/rv128_soc_fpga.dts --out fpga/soc/gen/rv128_bootrom_pkg.vhd
   ```
2. Proyecto: `vivado -mode batch -source fpga/soc/create_project.tcl -tclargs te0950`
3. GUI (como en el RV64IMAC): Block Design `design_1` con CIPS (LPDDR4 por el NoC,
   **M_AXI_FPD**, **pl0_ref_clk a 50 MHz** y `pl0_resetn`) y `axi_noc_0` con el MC.
4. Insercion e implementacion hasta PDI:
   ```bash
   vivado -mode batch -source fpga/soc/bd_insert.tcl \
       -tclargs fpga/soc/rv128_soc_te0950/rv128_soc_te0950.xpr design_1 2>&1 | tee fpga/soc/bd_insert.log
   ```
   Comprobar `NoC S0x_AXI DATA_WIDTH = 128` en el log y el WNS en `timing_summary.rpt`.
5. PetaLinux con la XSA nueva y la reserva de la DDR en `system-user.dtsi` (igual que el RV64):
   ```dts
   reserved-memory {
       #address-cells = <2>; #size-cells = <2>; ranges;
       rv128_reserved: rv128@70000000 { no-map; reg = <0x0 0x70000000 0x0 0x08000000>; };
   };
   ```
6. En el PC: `fpga/soc/board_pack.sh /tmp/rv128_board` y copiar la carpeta a la SD.
7. En la placa: `sh run_all.sh` (todo) o `sh run_all.sh freertos` (filtro).
   Linux: `./rv128_soc_load -m rv64 fw_jump.bin@0 Image@0x200000` (divisor 27 por defecto).

## Banco de control (0xA400_0000)

| Off | Registro |
|---|---|
| 0x00 | CTRL: bit0 RUN, bit1 RST, bit2 M64 (se aplica en el reset del SoC) |
| 0x04 | STATUS: bit0 en marcha, bit1 tohost escrito, bit2 modo RV64 |
| 0x08/0x0C | retiros |
| 0x10 | PC del ultimo retiro |
| 0x14 | DRAM_PHYS |
| 0x18 | TOHOST_ADDR (direccion del core, 0 = sin vigilar) |
| 0x1C | ID 0x52534F43 ("RSOC") |
| 0x20/0x24 | valor de tohost (primera escritura con bit0 = 1) |
| 0x28/0x2C | ciclos hasta tohost |
| 0x30/0x34 | retiros hasta tohost |
| 0x40 + 4n | UART del lado host, registro n |

## Riesgos

- 50 MHz es el reloj del RV64IMAC (WNS +2,28 ns). El datapath de 128 bit (sumador,
  desplazador, bypass, D$ de 128) alarga las rutas: si el WNS sale negativo, bajar
  `pl0_ref_clk` a 40 MHz y `TICK_DIV` a 40 en `bd_insert.tcl` y en el DTS de la placa.
- En modo RV128 la boot ROM salta a 0x8000_0000 igual; las pruebas usan la UART con el
  divisor de reset (1), de ahi `-d 1`.
- Sin Debug Module: si se cuelga, la visibilidad es RETIRED, PC y la consola.
