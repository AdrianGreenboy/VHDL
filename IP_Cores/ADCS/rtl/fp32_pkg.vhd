-- ============================================================================
-- fp32_pkg.vhd — Aritmetica fp32 bit-exacta del IP ADCS (familia VHDL-2008).
--
-- Contrato numerico (identico en lo observable al Floating-Point Operator):
--   * IEEE-754 binary32, redondeo RNE, FMA fusionada (redondeo unico).
--   * FTZ: entradas con exponente 0 => +/-0; resultados < 2^-126 => +/-0.
--   * NaN canonico 0x7FC00000. Inf*0 => qNaN. Inf-Inf => qNaN.
--   * Cancelacion exacta (terminos no nulos) => +0.
--   * add(a,b) := fma(b,+1.0,a); sub(a,b) := fma(b,-1.0,a) (producto por 1.0
--     exacto => identico al add/sub IEEE con un solo motor verificado).
--
-- Implementacion: acumulador entero de 480 bits, suma EXACTA de producto y
-- addendo, normalizacion y un unico redondeo. Solo para la arquitectura
-- behavioral (GHDL / capa 1-4); en sintesis la entidad fp32_fma instancia el
-- FPO de Xilinx (arquitectura xil, archivo aparte).
--
-- MUT (solo verificacion, 0 en uso normal):
--   1 = truncar en vez de RNE   2 = sticky perdido   3 = bias exp off-by-one
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fp32_pkg is
  constant FP32_QNAN : std_logic_vector(31 downto 0) := x"7FC00000";
  constant FP32_PONE : std_logic_vector(31 downto 0) := x"3F800000";
  constant FP32_MONE : std_logic_vector(31 downto 0) := x"BF800000";

  function fma_fp32(a, b, c : std_logic_vector(31 downto 0);
                    mut     : natural) return std_logic_vector;
end package fp32_pkg;

package body fp32_pkg is

  constant ACC_W : natural := 480;

  function fma_fp32(a, b, c : std_logic_vector(31 downto 0);
                    mut     : natural) return std_logic_vector is
    variable sa, sb, sc, sp, ssign : std_logic;
    variable ea, eb, ec            : integer;
    variable a_zero, b_zero, c_zero : boolean;
    variable a_inf, b_inf, c_inf    : boolean;
    variable a_nan, b_nan, c_nan    : boolean;
    variable ma, mb, mc  : unsigned(23 downto 0);
    variable mp          : unsigned(47 downto 0);
    variable ep, ecg, emin : integer;
    variable accp, accc, smag : unsigned(ACC_W-1 downto 0);
    variable msb    : integer;
    variable e_res  : integer;
    variable mant   : unsigned(24 downto 0);
    variable guard, sticky : std_logic;
    variable roundup : boolean;
    variable ebias   : integer;
  begin
    -- ---- clasificacion (FTZ en entrada) ------------------------------------
    sa := a(31); ea := to_integer(unsigned(a(30 downto 23)));
    sb := b(31); eb := to_integer(unsigned(b(30 downto 23)));
    sc := c(31); ec := to_integer(unsigned(c(30 downto 23)));
    a_zero := (ea = 0);  a_inf := (ea = 255) and (unsigned(a(22 downto 0)) = 0);
    b_zero := (eb = 0);  b_inf := (eb = 255) and (unsigned(b(22 downto 0)) = 0);
    c_zero := (ec = 0);  c_inf := (ec = 255) and (unsigned(c(22 downto 0)) = 0);
    a_nan := (ea = 255) and not a_inf;
    b_nan := (eb = 255) and not b_inf;
    c_nan := (ec = 255) and not c_inf;
    sp := sa xor sb;

    -- ---- especiales ---------------------------------------------------------
    if a_nan or b_nan or c_nan then
      return FP32_QNAN;
    end if;
    if a_inf or b_inf then
      if (a_inf and b_zero) or (b_inf and a_zero) then
        return FP32_QNAN;                              -- Inf * 0
      end if;
      if c_inf and (sc /= sp) then
        return FP32_QNAN;                              -- Inf - Inf
      end if;
      return sp & "1111111100000000000000000000000";   -- Inf(sp)
    end if;
    if c_inf then
      return sc & "1111111100000000000000000000000";   -- Inf(sc)
    end if;
    if a_zero or b_zero then                           -- producto exacto cero
      if c_zero then
        if sp = sc then
          return sp & "0000000000000000000000000000000";
        else
          return x"00000000";
        end if;
      end if;
      return c;                                        -- c normal, inalterada
    end if;

    -- ---- camino general: suma exacta en 480 bits ---------------------------
    ma := unsigned('1' & a(22 downto 0));
    mb := unsigned('1' & b(22 downto 0));
    mp := ma * mb;                                     -- 48 bits
    ep  := ea + eb - 300;                              -- P = mp * 2^ep
    if c_zero then
      mc  := (others => '0');
      ecg := ep;
    else
      mc  := unsigned('1' & c(22 downto 0));
      ecg := ec - 150;                                 -- C = mc * 2^ecg
    end if;
    if ep < ecg then emin := ep; else emin := ecg; end if;

    accp := shift_left(resize(mp, ACC_W), ep  - emin);
    accc := shift_left(resize(mc, ACC_W), ecg - emin);

    if (sp = sc) or c_zero then
      smag  := accp + accc;
      ssign := sp;
    elsif accp >= accc then
      smag  := accp - accc;
      ssign := sp;
    else
      smag  := accc - accp;
      ssign := sc;
    end if;

    if smag = 0 then
      return x"00000000";                              -- cancelacion exacta -> +0
    end if;

    -- ---- normalizacion ------------------------------------------------------
    msb := 0;
    for i in ACC_W-1 downto 0 loop
      if smag(i) = '1' then
        msb := i;
        exit;
      end if;
    end loop;
    e_res := msb + emin;                               -- exponente sin sesgo
    smag  := shift_left(smag, ACC_W-1 - msb);          -- lider en el bit alto

    mant   := resize(smag(ACC_W-1 downto ACC_W-24), 25);
    guard  := smag(ACC_W-25);
    sticky := or smag(ACC_W-26 downto 0);
    if mut = 2 then sticky := '0'; end if;             -- MUT2: sticky perdido

    -- ---- redondeo RNE (unico) ----------------------------------------------
    roundup := (guard = '1') and ((sticky = '1') or (mant(0) = '1'));
    if mut = 1 then roundup := false; end if;          -- MUT1: truncamiento
    if roundup then
      mant := mant + 1;
      if mant(24) = '1' then
        mant  := shift_right(mant, 1);
        e_res := e_res + 1;
      end if;
    end if;

    -- ---- empaquetado con FTZ de salida --------------------------------------
    ebias := e_res + 127;
    if mut = 3 then ebias := ebias + 1; end if;        -- MUT3: bias off-by-one
    if ebias >= 255 then
      return ssign & "1111111100000000000000000000000";
    elsif ebias < 1 then
      return ssign & "0000000000000000000000000000000"; -- FTZ salida
    else
      return ssign & std_logic_vector(to_unsigned(ebias, 8))
                   & std_logic_vector(mant(22 downto 0));
    end if;
  end function fma_fp32;

end package body fp32_pkg;
