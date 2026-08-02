#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# PetaLinux 2025.2.1 build flow for the TE0950.
# Run on the workstation (adrian@adrian). Assumes the XSA was exported by
# synth_impl.tcl to $HOME/vhdl_repo/IP_Cores/MIPI/petalinux/mipi_soc.xsa
#
# Produces a repackaged BOOT.BIN (never hot-load a full-impl PDI: the Versal PLM
# rejects it with 0x03024001). Boots image.ub initramfs; the PS verification
# binary runs from the SD ext4 partition auto-mounted at /run/media/mmcblk1p2.
#
# Disk hygiene (lesson): PetaLinux build/ is ~22 GB; delete build/tmp and
# build/cache from any cloned project before rebuilding.
# =============================================================================
set -e

MIPI=$HOME/vhdl_repo/IP_Cores/MIPI
PL=$MIPI/petalinux
XSA=$PL/mipi_soc.xsa
PROJ=$PL/mipi_plnx

# ---- source the PetaLinux environment ---------------------------------------
source /opt/petalinux/2025.2.1/settings.sh

# ---- create the project from the XSA ----------------------------------------
cd $PL
if [ ! -d "$PROJ" ]; then
  petalinux-create project --template versal --name mipi_plnx
fi
cd $PROJ
petalinux-config --get-hw-description=$XSA --silentconfig

# =============================================================================
# Device tree: reserve the 16 MB DDR buffer at 0x70000000 as no-map, and expose
# the AXI-Lite SoC control aperture. The core/MIPI DMA write into this buffer;
# the PS reads it via /dev/mem with volatile word accesses (glibc bulk ops fault
# SIGBUS on no-map).
# =============================================================================
cat > project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi <<'DTS'
/ {
    reserved-memory {
        #address-cells = <2>;
        #size-cells = <2>;
        ranges;

        mipi_ddr_buf: buffer@70000000 {
            no-map;
            reg = <0x0 0x70000000 0x0 0x01000000>;   /* 16 MB */
        };
    };

    /* AXI-Lite SoC control node - reachable via /dev/mem at 0xA4000000.
       (Kept as a plain reg node; the PS app mmaps /dev/mem directly.) */
    mipi_soc_ctrl@a4000000 {
        compatible = "hercossnux,mipi-soc-ctrl";
        reg = <0x0 0xa4000000 0x0 0x00010000>;
        status = "okay";
    };
};
DTS

# =============================================================================
# Root filesystem: add the PS verification app (fw_ps) and the RV32 firmware
# binary (fw_rv32.bin) so both land in the image. The RV32 .bin is loaded into
# the soft core's IMEM by fw_ps at runtime via the AXI-Lite window.
# =============================================================================
petalinux-create -t apps --name mipiverify --enable

APPDIR=project-spec/meta-user/recipes-apps/mipiverify/files
mkdir -p $APPDIR
cp $MIPI/fw/fw_ps.c        $APPDIR/
cp $MIPI/fw/fw_rv32.bin    $APPDIR/     # produced by the RV32 toolchain (below)

cat > project-spec/meta-user/recipes-apps/mipiverify/mipiverify.bb <<'BB'
SUMMARY = "MIPI CSI-2 RX silicon self-test verifier"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://fw_ps.c file://fw_rv32.bin"
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -O2 -static ${S}/fw_ps.c -o mipiverify
}
do_install() {
    install -d ${D}${bindir}
    install -m 0755 mipiverify ${D}${bindir}/mipiverify
    install -d ${D}${base_libdir}/firmware
    install -m 0644 ${S}/fw_rv32.bin ${D}${base_libdir}/firmware/fw_rv32.bin
}
FILES:${PN} += "${base_libdir}/firmware/fw_rv32.bin"
BB

# enable the app in the rootfs
echo 'CONFIG_mipiverify' >> project-spec/meta-user/conf/user-rootfsconfig
petalinux-config -c rootfs --silentconfig || true

# =============================================================================
# Build
# =============================================================================
petalinux-build

# =============================================================================
# Package BOOT.BIN (repackage - never hot-load the impl PDI).
# Versal boot image: BOOT.BIN (PLM + PDI + PS firmware) + image.ub.
# =============================================================================
petalinux-package boot \
  --boot \
  --plm \
  --psmfw \
  --u-boot \
  --dtb \
  --force

echo "== BOOT.BIN and image.ub in $PROJ/images/linux/ =="
echo "== copy BOOT.BIN + image.ub to the SD boot partition; the ext4 partition"
echo "   auto-mounts at /run/media/mmcblk1p2; run 'mipiverify' from the console =="
