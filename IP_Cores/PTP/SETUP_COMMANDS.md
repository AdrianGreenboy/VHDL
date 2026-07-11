# Comandos de instalación — IP PTP en la workstation

Secuencia para llevar el paquete descargado (`ptp_ip_deliver.tar.gz` en
`~/Downloads`) a la carpeta canónica `~/vhdl_repo/IP_Cores/PTP` y publicarlo.
Se usa `mv` (no `cp`) al traer desde `~/Downloads` para liberar espacio, según
tu convención. Ejecutar un comando a la vez, leyendo cada salida.

## 1. Preparar la carpeta canónica y mover el paquete

```
mkdir -p ~/vhdl_repo/IP_Cores/PTP
mv ~/Downloads/ptp_ip_deliver.tar.gz ~/vhdl_repo/IP_Cores/PTP/
cd ~/vhdl_repo/IP_Cores/PTP
tar xzf ptp_ip_deliver.tar.gz
mv ptp_ip_deliver/* .
rmdir ptp_ip_deliver
rm ptp_ip_deliver.tar.gz
```

Estructura resultante:

```
~/vhdl_repo/IP_Cores/PTP/
  rtl/  sim/  fw/  vivado/  petalinux/  docs/  README.md  LICENSE  SETUP_COMMANDS.md
```

## 2. Verificar la simulación (GHDL 4.1.0)

```
cd ~/vhdl_repo/IP_Cores/PTP/sim
./run_regression.sh
```

Esperado: 15 líneas `PASS` y `=== TODAS LAS VERIFICACIONES PASAN ===`.

## 3. Ensamblar el firmware de bring-up (asm.py)

```
cd ~/vhdl_repo/IP_Cores/PTP/fw
python3 ~/rv32i/asm.py ptp_bringup.s -o ptp_bringup.bin
```

(Revisa el binario con tu intérprete `iss_rv32.py` antes de llevarlo a placa,
como en los IP previos.)

## 4. Vivado (2025.2.1)

```
source ~/Xilinx/2025.2.1/Vivado/settings64.sh
vivado -mode tcl
```

Dentro de Vivado, seguir `vivado/ptp_soc.tcl` **comando a comando** (no pegar
bloques: los compuestos con `puts`/`;` se truncan). El script clona `eth_soc`,
añade el RTL como VHDL-2008, instancia `ptp_axil`, cablea el NoC PL→S_AXI por
Tcl, asigna `0x8000_0000/64K` y genera el PDI.

## 5. PetaLinux (2025.2.1)

```
source ~/Petalinux/settings.sh
```

Seguir `petalinux/BUILD_NOTES.md`: clonar el proyecto, `rm -rf build/tmp
build/cache`, importar el XSA, mantener el reserved-memory en `0x7000_0000`,
`petalinux-build`, y repackear un BOOT.BIN completo (nunca hot-load de PDI).

## 6. Publicar en Git (GitLab primario + GitHub mirror)

`git push origin` empuja a ambos remotos a la vez (ya configurado en tu repo).

```
cd ~/vhdl_repo
git add IP_Cores/PTP
git commit -m "Add PTP/IEEE 802.1AS Ordinary Clock IP core

- 1-step HW timestamping, autonomous PI servo, real peer path delay
- MMIO + AXI4-Lite, LOOP_INT, slave+master switchable
- Verified across 5 sim layers vs Python ISS oracle (15/15 PASS)"
git push origin
```

## 7. Limpiar el tar de descarga (si quedó en Downloads)

```
# ya se movió con mv en el paso 1; nada que limpiar en Downloads.
```
