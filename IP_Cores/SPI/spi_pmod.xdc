# ============================================================================
#  spi_pmod.xdc  -  Pines fisicos del bus SPI en el TE0950
#  Licencia: MIT
#
#  Conector: CRUVI Low Speed 1 (banco 302, HDIO, VCCO 3.3 V).
#  Sitios tomados del XDC de referencia del TE0950 Test Board de Trenz:
#    C_LS1_SEL = A10   C_LS1_SCK = D11   C_LS1_D0 = D10   C_LS1_D1 = C10
#  Mapeo SPI segun la convencion CRUVI/QSPI: SEL=CS_n, SCK=SCLK,
#  D0=MOSI (host->modulo), D1=MISO (modulo->host).
#
#  El timing lo absorbe el margen de medio periodo del motor (+ sample_late);
#  los false_path evitan quejas del analizador sobre los pads asincronos.
# ============================================================================

set_property PACKAGE_PIN D11 [get_ports spi_sclk]  ;# C_LS1_SCK
set_property PACKAGE_PIN D10 [get_ports spi_mosi]  ;# C_LS1_D0
set_property PACKAGE_PIN C10 [get_ports spi_miso]  ;# C_LS1_D1
set_property PACKAGE_PIN A10 [get_ports spi_cs_n]  ;# C_LS1_SEL

set_property IOSTANDARD LVCMOS33 [get_ports {spi_sclk spi_mosi spi_miso spi_cs_n}]

# drive/slew moderados para 50 MHz en el conector
set_property DRIVE 8    [get_ports {spi_sclk spi_mosi spi_cs_n}]
set_property SLEW  SLOW [get_ports {spi_sclk spi_mosi spi_cs_n}]

set_false_path -to   [get_ports {spi_sclk spi_mosi spi_cs_n}]
set_false_path -from [get_ports spi_miso]
