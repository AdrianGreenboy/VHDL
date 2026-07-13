-- ============================================================================
-- fp32_fma_xil.vhd — Arquitectura de SINTESIS de fp32_fma (IP ADCS).
--
-- MISMA entidad que fp32_fma.vhd (arch behav): swap directo por librería. En
-- simulacion de capas 1-4 se usa 'behav' (fma_fp32 entero bit-exacto en GHDL);
-- en Vivado se compila esta arquitectura 'xil', que instancia el core
-- Floating-Point Operator (fp_fma) generado por package_fpo.tcl.
--
-- FIRMA BIT-EXACTA EN SILICIO (verificado contra PG060, FPO v7.x):
--   * El FMA fusionado del FPO cumple IEEE-754 a MEDIA ULP => resultado
--     correctamente redondeado => redondeo UNICO verdadero. Identico bit a bit
--     al modelo behav (suma exacta 480b + un redondeo). No hay doble redondeo
--     porque es fusionado.
--   * Modo de redondeo: unicamente Round to Nearest Even (RNE), como behav.
--   * FTZ: denormales en entrada y salida se llevan a +/-0, como behav.
--   * Especiales: Inf*0 y (+Inf)+(-Inf) => qNaN, como behav.
--   => la firma de simulacion (0x873BA7B4 en capa 1a, etc.) se extiende a placa.
--
-- CONFIG del core (package_fpo.tcl, = latencia de la tesis):
--   Operation_Type=FMA, Single/Single, C_Mult_Usage=Full_Usage,
--   Flow_Control=NonBlocking, C_Latency=8, C_Rate=1 (throughput 1/ciclo).
--
-- LECCION DE SILICIO nro.1 (documentada en la tesis y en la memoria del port):
--   el canal s_axis_operation DEBE conectarse SIEMPRE (tdata=0x00 => a*b+c,
--   tvalid=in_valid). Sin el, el join interno de operandos del FPO nunca
--   dispara y no sale resultado => deadlock en placa. Aqui se conecta siempre.
--
-- Add/sub del datapath: NO se usa un core Add_Subtract separado. El add se
-- hace como fma(a, 1.0, b) con ESTE mismo core FMA (producto por 1.0 exacto).
-- Mezclar un Add unfused con el FMA fusionado podria diferir en LSBs; un solo
-- primitivo FMA garantiza la firma bit-exacta en todo el datapath del MPC.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entidad AUTOCONTENIDA (identica a la de fp32_fma.vhd). Se declara aqui para
-- que el fileset de SINTESIS pueda excluir fp32_fma.vhd (que trae el modelo
-- behav con acumulador de 480 bits, no sintetizable) e incluir SOLO este
-- archivo. En simulacion se usa fp32_fma.vhd (entidad + arch behav); nunca se
-- compilan juntos, asi que no hay doble declaracion de la entidad.
entity fp32_fma is
  generic (
    LAT_FMA : natural := 8;
    MUT     : natural := 0            -- ignorado en sintesis (solo verif.)
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    in_valid  : in  std_logic;
    a         : in  std_logic_vector(31 downto 0);
    b         : in  std_logic_vector(31 downto 0);
    c         : in  std_logic_vector(31 downto 0);
    out_valid : out std_logic;
    result    : out std_logic_vector(31 downto 0)
  );
end entity fp32_fma;

architecture xil of fp32_fma is

  -- Floating-Point Operator (fp_fma) como caja negra. La netlist real la
  -- provee el core generado por Vivado; aqui solo declaramos el componente.
  component fp_fma
    port (
      aclk                    : in  std_logic;
      s_axis_a_tvalid         : in  std_logic;
      s_axis_a_tdata          : in  std_logic_vector(31 downto 0);
      s_axis_b_tvalid         : in  std_logic;
      s_axis_b_tdata          : in  std_logic_vector(31 downto 0);
      s_axis_c_tvalid         : in  std_logic;
      s_axis_c_tdata          : in  std_logic_vector(31 downto 0);
      s_axis_operation_tvalid : in  std_logic;
      s_axis_operation_tdata  : in  std_logic_vector(7 downto 0);
      m_axis_result_tvalid    : out std_logic;
      m_axis_result_tdata     : out std_logic_vector(31 downto 0)
    );
  end component;

begin

  -- MUT no aplica en sintesis (es solo verificacion en behav); si MUT/=0 en un
  -- build de sintesis, es un error de configuracion. Se ignora aqui.

  u_fp_fma : fp_fma
    port map (
      aclk                    => clk,
      s_axis_a_tvalid         => in_valid,
      s_axis_a_tdata          => a,
      s_axis_b_tvalid         => in_valid,
      s_axis_b_tdata          => b,
      s_axis_c_tvalid         => in_valid,
      s_axis_c_tdata          => c,
      -- canal operation SIEMPRE conectado (leccion de silicio nro.1):
      --   0x00 => multiply-add (a*b + c). tvalid = in_valid.
      s_axis_operation_tvalid => in_valid,
      s_axis_operation_tdata  => x"00",
      m_axis_result_tvalid    => out_valid,
      m_axis_result_tdata     => result
    );

end architecture xil;
