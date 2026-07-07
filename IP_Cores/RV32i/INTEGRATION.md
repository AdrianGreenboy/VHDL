# Integracion en el TE0950: del RTL a una app Linux que usa el core

Flujo completo para correr el core RISC-V en el PL del Versal y manejarlo desde
una app Linux en el A72.

## 1. Vivado (bitstream + XSA)

```sh
vivado -mode batch -source vivado/vivado_soc.tcl
```

Eso crea el proyecto y agrega las fuentes. Completa CIPS+NoC por GUI (ver los
pasos que imprime el script). Al final: Generate Bitstream y exporta el XSA
(File -> Export -> Export Hardware, con bitstream).

Anota la **direccion base** que el Address Editor le asigno al esclavo AXI de
`u_soc` (p. ej. `0xA000_0000`). Va en `SOC_BASE` de `sw/riscv_accel.c`.

## 2. PetaLinux

```sh
petalinux-create -t project --template versal -n rv32i_linux
cd rv32i_linux
petalinux-config --get-hw-description=<ruta_al_xsa>     # apunta al XSA exportado
petalinux-build
```

### Acceso al esclavo AXI: dos opciones

**A) /dev/mem (mas simple para demo).** La app mapea la base fisica directo.
Requiere que el kernel tenga `CONFIG_DEVMEM=y` y `CONFIG_STRICT_DEVMEM`
deshabilitado:

```sh
petalinux-config -c kernel
#   Device Drivers -> /dev/mem virtual device support = y
#   deshabilita CONFIG_STRICT_DEVMEM (Kernel hacking o via .config)
```

**B) UIO (mas limpio, sin root ni acceso a toda la memoria fisica).** Agrega un
nodo al device tree y usa `/dev/uioX`. En `project-spec/meta-user/.../system-user.dtsi`:

```dts
/ {
    rv32i_soc@a0000000 {
        compatible = "generic-uio";
        reg = <0x0 0xa0000000 0x0 0x10000>;
    };
};
```

Y en el kernel: `CONFIG_UIO=y`, `CONFIG_UIO_PDRV_GENIRQ=y` (no como modulo).
La app se adapta cambiando `open("/dev/mem")` + `SOC_BASE` por
`open("/dev/uio0")` + `mmap(..., 0)`.

## 3. Compilar y empaquetar la app

Como app de PetaLinux:

```sh
petalinux-create -t apps --template c --name riscv-accel --enable
cp <repo>/sw/riscv_accel.c project-spec/meta-user/recipes-apps/riscv-accel/files/
# ajusta el .bb para compilar ese fuente
petalinux-build
```

O compilando a mano con el cross-compiler del SDK:

```sh
source <sdk>/environment-setup-cortexa72-cortexa53-xilinx-linux
$CC sw/riscv_accel.c -o riscv_accel
```

## 4. Empaquetar el boot y arrancar

```sh
petalinux-package --boot --u-boot --force
# copia BOOT.BIN, image.ub (o los binarios) a la SD
```

Recuerda del bring-up previo del TE0950: el rootfs suele ser ramdisk (los
binarios se pierden al reiniciar; re-copiar desde SD), la SD monta en
`/run/media/mmcblk1p1`, y conviene redirigir la salida del benchmark a archivo
para evitar el cuelgue del buffer serial.

## 5. Correr en la placa

```sh
# como root (para /dev/mem)
./riscv_accel 1 2 3 4 5
# -> resultado del core (sum de cuadrados) = 55
#    esperado (calculado en el A72)        = 55
#    OK: el acelerador coincide
```

`riscv_accel` carga el programa acelerador en la IMEM, escribe las entradas en
la DMEM, arranca el core, espera la bandera de "listo", y lee el resultado — el
A72 usando tu RISC-V del PL como coprocesador.

## Que sigue

- Cambiar el programa acelerador (`sim/accel_*.s` -> ensamblar -> pegar el array
  en la app) para otros calculos: producto punto, GEMV, etc.
- Pasar a la version pipeline para mas Fmax.
- Exponer interrupciones al PS (linea del core -> PL-PS IRQ del CIPS) para no
  hacer polling.

## Iteracion v2: pipeline + GEMV + interrupcion

Junta las tres mejoras en un solo flujo. RTL nuevo: `soc_top_pipe.vhd` (core
pipeline + doorbell en la palabra 127 de la DMEM que genera `irq_out`),
`soc_top_pipe_wrap.v` (wrapper), y el registro IRQ (0x0C, write-1-to-clear) en
`axil_soc.vhd`. App: `sw/riscv_accel_v2.c` (sumsq | gemv, UIO con fallback a
polling). Validar en sim: `./run_xsim.sh accel_pipe`.

### Vivado (cambios respecto al bring-up base)

1. Agrega `soc_top_pipe.vhd` y `soc_top_pipe_wrap.v` al proyecto; instancia
   `soc_top_pipe_wrap` en el BD en vez de `soc_top_wrap`.
2. Conecta `u_soc/irq_out` a una **PL-PS IRQ** del CIPS: doble clic al CIPS ->
   PS-PL Interfaces -> habilita `IRQ0` (o `pl_ps_irq`), y cablea `irq_out` a esa
   linea (`connect_bd_net`).
3. Address y relojes igual que antes; re-genera device image y XSA.

### PetaLinux (UIO con interrupcion)

En `system-user.dtsi`, agrega la propiedad de interrupcion al nodo (el numero
depende de la IRQ del CIPS que conectaste; el editor de direcciones/IRQ de
Vivado lo reporta):

```dts
/ {
    rv32i_soc: rv32i_soc@2010000000 {
        compatible = "generic-uio";
        reg = <0x20 0x10000000 0x0 0x10000>;
        interrupt-parent = <&gic>;
        interrupts = <0 90 4>;   /* <SPI  numero  nivel-alto> -- ajustar numero */
        status = "okay";
    };
};
```

Kernel: `CONFIG_UIO=y` y `CONFIG_UIO_PDRV_GENIRQ=y` (no como modulo). Al
arrancar aparece `/dev/uio0`, y `riscv_accel_v2` lo detecta y usa la
interrupcion automaticamente (si no existe, cae a polling con `/dev/mem`).

Correr: `./riscv_accel_v2 gemv 2 0 1`  o  `./riscv_accel_v2 sumsq 1 2 3 4 5`.
