#
# HERCOSSNUX Core 21 - ETH GT
# Receta PetaLinux: instala la herramienta 'eth21' (status, selftest,
# autodetect, send, stop, counters).
#   project-spec/meta-user/recipes-apps/eth21/
#     eth21.bb        (este fichero)
#     files/eth21.c
# Activar: echo 'CONFIG_eth21' >> project-spec/meta-user/conf/user-rootfsconfig
#          y CONFIG_eth21=y en project-spec/configs/rootfs_config
#
SUMMARY = "Core 21 ETH GT: herramienta de control y selftest (PS)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://eth21.c"
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -O2 eth21.c -o eth21
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 eth21 ${D}${bindir}/eth21
}
