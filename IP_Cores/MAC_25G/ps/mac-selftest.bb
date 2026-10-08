#
# HERCOSSNUX Core 20 - MAC 25G
# Receta PetaLinux: instala mac-selftest y el firmware del RV32.
#   project-spec/meta-user/recipes-apps/mac-selftest/
#     mac-selftest.bb   (este fichero)
#     files/mac_selftest.c
#     files/fw_rv32.bin (fw/build_fw_rv32.sh)
# Activar en project-spec/configs/rootfs_config:  CONFIG_mac-selftest=y
#
SUMMARY = "Core 20 MAC 25G: silicon selftest (PS) + firmware RV32"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://mac_selftest.c \
           file://fw_rv32.bin \
          "
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -O2 mac_selftest.c -o mac-selftest
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 mac-selftest ${D}${bindir}/mac-selftest
    install -d ${D}${nonarch_base_libdir}/firmware/mac25g
    install -m 0644 fw_rv32.bin ${D}${nonarch_base_libdir}/firmware/mac25g/fw_rv32.bin
}

FILES:${PN} += "${nonarch_base_libdir}/firmware/mac25g/fw_rv32.bin"
