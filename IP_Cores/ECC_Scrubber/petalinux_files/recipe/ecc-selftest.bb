SUMMARY = "ECC scrubber SECDED(39,32) silicon selftest (Core 20) para el TE0950"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
SRC_URI = "file://ecc_selftest.c \
           file://ecc_fw_on.mem \
           file://ecc_fw_off.mem"
S = "${WORKDIR}"
do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ecc_selftest.c -o ecc-selftest
}
do_install() {
    install -d ${D}${bindir}
    install -m 0755 ecc-selftest ${D}${bindir}/ecc-selftest
    install -m 0644 ecc_fw_on.mem  ${D}${bindir}/ecc_fw_on.mem
    install -m 0644 ecc_fw_off.mem ${D}${bindir}/ecc_fw_off.mem
}
FILES:${PN} += "${bindir}/ecc_fw_on.mem ${bindir}/ecc_fw_off.mem"
