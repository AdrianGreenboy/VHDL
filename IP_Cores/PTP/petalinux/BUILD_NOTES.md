# PetaLinux build & silicon bring-up — PTP IP (TE0950 / Versal)

PetaLinux 2025.2.1. These notes assume the Vivado PDI is built (see
`../vivado/ptp_soc.tcl`) and the SoC firmware is assembled. Run each command and
read its output before the next; do not paste blocks.

## 0. Environment

```
source ~/Petalinux/settings.sh
```

## 1. Clone the existing project (do not build from scratch)

Clone the working Ethernet-MAC PetaLinux project and retarget it. A `cp -a`
clone carries absolute paths inside `build/tmp`, so wipe them:

```
cp -a ~/petalinux/eth_te0950 ~/petalinux/ptp_te0950
cd ~/petalinux/ptp_te0950
rm -rf build/tmp build/cache
```

## 2. Import the new hardware (PDI + XSA)

```
petalinux-config --get-hw-description=<path-to-ptp_soc.xsa>
```

Leave the reserved-memory node in `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`:

```
/ {
    reserved-memory {
        #address-cells = <2>;
        #size-cells = <2>;
        ranges;
        ptp_buf: buffer@70000000 {
            no-map;
            reg = <0x0 0x70000000 0x0 0x1000000>;   /* 16 MB */
        };
    };
};
```

## 3. Build

```
petalinux-build
```

Then package a **full** BOOT.BIN (the Versal PLM rejects a hot-loaded PDI with
`Image Header Table Validation failed` / `0x03024001`):

```
petalinux-package --boot --force \
  --plm --psmfw \
  --u-boot \
  --dtb images/linux/system.dtb
```

## 4. Flash a clean SD card

Stale SD artifacts make u-boot silently fall back, so clean first:

```
sudo umount /media/adrian/BOOT-* 2>/dev/null
sudo fsck.vfat -a /dev/mmcblk<X>p1
```

Copy `BOOT.BIN`, `image.ub` (and `boot.scr` if used) to the FAT32 partition,
then `sync` before removing.

## 5. Serial console

```
picocom -b 115200 /dev/ttyUSB0
```

Target prompt: `root@plnxte0950usart:~#`. The SD mounts at
`/run/media/mmcblk1p1` on the target.

## 6. Run the bring-up firmware

Load the RV32IM firmware into the core's local RAM with the core halted
(`CONTROL.bit0` gives AXI ownership of the memory; the PS only sees the local
RAM when the core is stopped), release the core, and let it run the
Sync → Pdelay → slave sequence. It writes the signature to `0x7000_0000`.

## 7. Compare the silicon signature (layer 5)

Read back the DDR window and compare bit-identically against the oracle:

```
# on target: dump the reserved buffer
busybox devmem 0x70000000 32          # signature word [0] = STATUS after Sync
busybox devmem 0x70000008 32          # MPD_LO  (expect 0x28 = 40 ns)
busybox devmem 0x70000014 32          # OFFSET  (expect 0x0, synchronized)
busybox devmem 0x7000001C 32          # doorbell DONE marker
```

Cross-check against `sim/iss_ptp.py` (`ptp_soc_oracle.txt`): the STATUS/MPD/
OFFSET words must match the layer-4 values (STATUS=1 then 6 then 9, MPD=40,
OFFSET=0). A bit-identical match closes layer 5.
