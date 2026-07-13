-- ============================================================================
-- adcs_pkg.vhd — Constantes y mapa de registros del IP ADCS (familia VHDL).
-- Port fiel de adcs_accel_pkg.sv. Scope v1: MODE_MPC_PGD + MODE_LOAD_H.
-- SRUKF_QR (modo 1) y los registros 0x30-0x40 quedan RESERVADOS (fase 2);
-- el decode debe aceptarlos como RAZ/WI para compatibilidad futura.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package adcs_pkg is

  -- -------- Dimensiones del problema (modelo ADCS validado en tesis) -------
  constant NX  : natural := 23;    -- estado completo
  constant NU  : natural := 7;     -- control
  constant NP  : natural := 10;    -- horizonte de prediccion
  constant D   : natural := 70;    -- NP*NU -> variable de decision U
  constant DP  : natural := 72;    -- padded a multiplo de 8

  -- -------- Anchos ----------------------------------------------------------
  constant FP_W   : natural := 32;
  constant ADDR_W : natural := 32;
  constant IDX_W  : natural := 8;

  -- -------- Contrato numerico del dot (parte de la firma) ------------------
  -- NACC acumuladores rotativos: acc[j mod NACC] = fma(h[j], u[j], acc),
  -- reduccion final acc[0] = fma(acc[k], 1.0, acc[0]) para k=1..NACC-1.
  -- NACC=16 validado en silicio (holgura sobre la latencia efectiva del FPO).
  constant NACC : natural := 16;

  -- -------- Modos de operacion (registro MODE) ------------------------------
  constant MODE_MPC_PGD  : std_logic_vector(1 downto 0) := "00";
  constant MODE_SRUKF_QR : std_logic_vector(1 downto 0) := "01"; -- reservado v1
  constant MODE_LOAD_H   : std_logic_vector(1 downto 0) := "10";

  -- -------- Bits de CTRL / STATUS -------------------------------------------
  constant CTRL_START_BIT  : natural := 0;
  constant CTRL_SRESET_BIT : natural := 1;
  constant CTRL_IRQEN_BIT  : natural := 2;
  constant ST_DONE_BIT     : natural := 0;  -- sticky: limpia solo START/SRESET
  constant ST_BUSY_BIT     : natural := 1;
  constant ST_ERR_BIT      : natural := 2;

  -- -------- Mapa de registros (byte offsets, AXI-Lite / dmem) ---------------
  constant REG_CTRL    : std_logic_vector(7 downto 0) := x"00";
  constant REG_STATUS  : std_logic_vector(7 downto 0) := x"04";
  constant REG_MODE    : std_logic_vector(7 downto 0) := x"08";
  constant REG_NDIM    : std_logic_vector(7 downto 0) := x"0C";
  constant REG_MAXITER : std_logic_vector(7 downto 0) := x"10";
  constant REG_STEP    : std_logic_vector(7 downto 0) := x"14"; -- float32
  constant REG_UMAX    : std_logic_vector(7 downto 0) := x"18"; -- float32
  constant REG_HBASE   : std_logic_vector(7 downto 0) := x"1C";
  constant REG_GBASE   : std_logic_vector(7 downto 0) := x"20";
  constant REG_UBASE   : std_logic_vector(7 downto 0) := x"24";
  constant REG_ITERCNT : std_logic_vector(7 downto 0) := x"28"; -- RO
  constant REG_VERSION : std_logic_vector(7 downto 0) := x"2C"; -- RO
  -- 0x30..0x40: RESERVADOS (QR fase 2): QROP, QRM, QRSTAT, XDATA, XIDX
  constant REG_DEBUG   : std_logic_vector(7 downto 0) := x"44"; -- RO
  constant REG_DBGTAG  : std_logic_vector(7 downto 0) := x"48"; -- RO, nuevo v1

  -- -------- Identidad -------------------------------------------------------
  -- VERSION distinta de la rama A72 (1.0) para distinguir en placa el port
  -- de familia gobernado por el RV32IM.
  constant IP_VERSION : std_logic_vector(31 downto 0) := x"0200_0001";
  -- Tag de presencia de instrumentacion (leccion PTP 0xA5D): el silicio
  -- declara que registros de debug trae. [31:16]=ADC5, [15:8]=rev debug,
  -- [7:0]=capacidades (bit0: REG_DEBUG presente).
  constant DBG_TAG    : std_logic_vector(31 downto 0) := x"ADC5_0101";

end package adcs_pkg;
