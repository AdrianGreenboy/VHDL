# ============================================================================
#  BRINGUP_1553.md  -  Guion de bring-up de silicio del IP MIL-STD-1553B
#  (TE0950, Versal xcve2302). Capa 5. Licencia: MIT
#
#  Los comandos van UNO POR UNO leyendo cada salida. Este documento NO se
#  ejecuta como script. Prompts:
#    workstation: adrian@adrian:~$
#    target:      root@plnxte0950m1553:~#
# ============================================================================

## 0) Precondiciones (ya hechas y verificadas en simulacion)
#   - Capas 1a/1b/1c/2/4 PASS con firmas bit-identicas.
#   - Firmware fw_m1553.mem verificado contra el ISS con interprete RV32IM.
#   - Vivado: BD trasplantado (bd_m1553_steps.tcl), synth+impl cerrados,
#     m1553_soc.xsa exportada (run_impl_m1553.tcl).
#   Confirmar WNS positivo antes de seguir:
#     grep -i "WNS =" en la salida de run_impl_m1553.tcl  ->  debe ser > 0 ns

## 1) PetaLinux: proyecto clonado del SPW
# NO cp -a de un build ya construido: arrastra rutas absolutas en build/tmp
# (leccion). Clonar limpio y re-apuntar el XSA.
adrian@adrian:~$ cp -r ~/Petalinux/plnx_spw ~/Petalinux/plnx_m1553
adrian@adrian:~$ cd ~/Petalinux/plnx_m1553
adrian@adrian:~$ rm -rf build/tmp build/cache        # rutas absolutas del clon
adrian@adrian:~$ source ~/Petalinux/settings.sh
adrian@adrian:~$ petalinux-config --get-hw-description=~/m1553_ip/m1553_soc.xsa --silentconfig

## 2) reserved-memory para el buffer del DMA
# El verificador del PS lee la firma en 0x5000_0000. Esa zona debe estar
# RESERVADA en el device tree para que Linux no la use, y el DMA del PL pueda
# escribirla. Editar el device tree de usuario:
adrian@adrian:~$ nano project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
# ---- contenido (anadir dentro de / { ... }):
#   reserved-memory {
#       #address-cells = <2>;
#       #size-cells = <2>;
#       ranges;
#       m1553_dma_buf: buffer@50000000 {
#           no-map;
#           reg = <0x0 0x50000000 0x0 0x00100000>;   // 1 MB en 0x5000_0000
#       };
#   };
# OJO con el split de direcciones de 40 bits: el par <hi lo> es
# <0x0 0x50000000>, NO <0x5 0x0000000> (leccion del device tree 1553/SPW).

## 3) habilitar /dev/mem y el gcc estatico en el rootfs
adrian@adrian:~$ petalinux-config -c rootfs
#   habilitar: CONFIG_imagefeature-debug-tweaks (ya en el SPW)
#   asegurar que /dev/mem esta accesible (kernel: CONFIG_DEVMEM=y, default)

## 4) construir y empaquetar BOOT.BIN
# NUNCA hot-load del PDI de implementacion sobre un PL ya configurado: el PLM
# lo rechaza con "Image Header Table Validation failed" (0x03024001).
# SIEMPRE repackage BOOT.BIN via PetaLinux (leccion).
adrian@adrian:~$ petalinux-build
adrian@adrian:~$ petalinux-package --boot --plm --psmfw \
                   --u-boot --dtb --force
# resultado: images/linux/BOOT.BIN, image.ub, boot.scr

## 5) SD limpia (reformatear + verificar FAT)
# Artefactos viejos hacen que u-boot caiga en fallback silencioso; se ha visto
# corrupcion del tamano de la particion FAT. Reformatear y verificar (leccion).
adrian@adrian:~$ lsblk                       # identificar la SD (p.ej. /dev/sdX)
# (con cuidado con el nombre del dispositivo!)
adrian@adrian:~$ sudo mkfs.vfat -F 32 -n BOOT /dev/sdX1
adrian@adrian:~$ sudo fsck.vfat -v /dev/sdX1   # verificar integridad de la FAT
adrian@adrian:~$ sudo mount /dev/sdX1 /mnt
adrian@adrian:~$ sudo cp images/linux/BOOT.BIN images/linux/image.ub \
                   images/linux/boot.scr /mnt/
# copiar tambien el firmware y el verificador (ver paso 6)
adrian@adrian:~$ sync && sudo umount /mnt

## 6) cross-compilar el verificador del PS y ponerlo en la SD
adrian@adrian:~$ aarch64-linux-gnu-gcc -O2 -static \
                   ~/m1553_ip/m1553_bringup.c -o ~/m1553_ip/m1553_bringup
adrian@adrian:~$ sudo mount /dev/sdX1 /mnt
adrian@adrian:~$ sudo cp ~/m1553_ip/m1553_bringup ~/m1553_ip/fw_m1553.mem /mnt/
adrian@adrian:~$ sync && sudo umount /mnt

## 7) arrancar la placa y conectar por serie
# Insertar la SD, modo de arranque SD, alimentar. Consola serie:
adrian@adrian:~$ picocom -b 115200 /dev/ttyUSB0     # 8N1
# esperar el login de PetaLinux; usuario root
#   plnxte0950m1553 login: root

## 8) ejecutar el bring-up en el target
root@plnxte0950m1553:~# mount /dev/mmcblk1p1 /run/media/mmcblk1p1 2>/dev/null || true
root@plnxte0950m1553:~# cd /run/media/mmcblk1p1     # la SD monta aqui
root@plnxte0950m1553:~# ./m1553_bringup fw_m1553.mem
# salida esperada:
#   [bringup] firmware: 176 instrucciones
#   [bringup] IMEM cargada y verificada
#   [bringup] DBG_PC final = 0x000002A0
#   [bringup] firma en DDR vs ISS:
#      sig[0] = 0x00002800  esperado 0x00002800  OK
#      sig[1] = 0x0000C406  esperado 0x0000C406  OK
#      sig[2] = 0x00002800  esperado 0x00002800  OK
#      sig[3] = 0x0000E203  esperado 0x0000E203  OK
#      sig[4] = 0x28004800  esperado 0x28004800  OK
#      sig[5] = 0x0000F300  esperado 0x0000F300  OK
#      sig[6] = 0x00000003  esperado 0x00000003  OK
#      sig[7] = 0x0000DEAD  esperado 0x0000DEAD  OK
#
#   M1553 SILICON PASS

## 9) si algo falla: arbol de diagnostico
#   - "carga de IMEM" -> el esclavo AXI-Lite no responde: revisar que el BD
#     mapeo s_axi en 0x8000_0000 (assign_bd_address del bd_m1553_steps.tcl)
#     y que el core esta en halt (CONTROL=1) durante la carga.
#   - "timeout / sin firma", DBG_PC quieto -> el core no arranca: revisar el
#     reset (rst_versal_cips_0_240M/peripheral_aresetn) y el pl0_ref_clk.
#   - "timeout / sin firma", DBG_PC avanzando -> el core corre pero el DMA no
#     vuelca: revisar DDR_BASE_{LO,HI} y la reserved-memory del device tree
#     (el split de 40 bits <0x0 0x50000000>).
#   - firma parcial correcta -> como la firma del firmware ya coincide con el
#     ISS en simulacion, un mismatch aqui apunta a hardware: decode de region
#     0xC000_0000 en mem_subsys_m1553, o el NoC/aclk6 del maestro DMA.
#   - IRQ: opcional; el bring-up usa polling de la palabra centinela, no
#     depende de la IRQ PL->PS para declarar PASS.
```
