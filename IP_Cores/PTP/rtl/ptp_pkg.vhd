-- ptp_pkg.vhd — familia TSN Ethernet, IP PTP / IEEE 802.1AS v1
-- ---------------------------------------------------------------------------
-- Constantes y tipos compartidos del IP PTP. Toda la aritmetica del reloj
-- ajustable y del servo PI vive documentada aqui de forma que el ISS de
-- Python (iss_ptp.py) la replique BIT A BIT. Cualquier cambio de ancho,
-- shift o orden de operacion DEBE reflejarse simultaneamente en ambos.
--
-- Formato de tiempo (nativo PTPv2 originTimestamp):
--   sec   : unsigned 48 bits  (segundos)
--   ns    : unsigned 32 bits  (0 .. 999_999_999, wrap explicito a 1e9)
--   subns : unsigned 32 bits  (fraccion de ns, peso 2^-32)
--
-- Acumulador de fase (avanza a 100 MHz, un paso por tick de core-clock):
--   {ns,subns} += INC_PER_TICK + RATE_ADJ
--   INC_PER_TICK codifica 10 ns exactos => parte entera de ns = 10, subns = 0.
--   RATE_ADJ es signed 32b en peso de subns (2^-32 ns/tick).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ptp_pkg is

  -- ---- anchos del reloj -------------------------------------------------
  constant SEC_W   : integer := 48;
  constant NS_W    : integer := 32;
  constant SUBNS_W : integer := 32;

  constant NS_PER_SEC : unsigned(NS_W-1 downto 0) := to_unsigned(1_000_000_000, NS_W);

  -- Incremento nominal por tick de 100 MHz: 10 ns, 0 subns.
  -- El reloj avanza a core-clock pleno (100 MHz), NO a mii_ce.
  constant INC_NS_NOM : integer := 10;

  -- ---- servo PI ---------------------------------------------------------
  -- KP, KI unsigned 16b escribibles por registro (SERVO_K).
  -- SHIFT_P, SHIFT_I fijos por generic del top; se listan aqui los defaults.
  constant SHIFT_P_DEF : integer := 8;
  constant SHIFT_I_DEF : integer := 12;

  constant ERR_W  : integer := 32;   -- error de offset, signed ns (saturado)
  constant ACC_W  : integer := 48;   -- acumulador integral, signed (saturado)
  constant RATE_W : integer := 32;   -- RATE_ADJ, signed peso 2^-32 ns/tick

  -- ---- saturacion signed a N bits --------------------------------------
  -- Satura un entero signed 'v' al rango de un signed de 'n' bits.
  -- Definida como funcion pura, replicada identica en el ISS.
  function sat_signed(v : signed; n : integer) return signed;

  -- Suma {ns,subns} + inc (inc signed en peso subns) con acarreo a sec.
  -- Devuelve el nuevo estado empaquetado. Pura y determinista.
  -- Layout del vector empaquetado: (sec & ns & subns), MSB->LSB.
  function clk_tick(sec   : unsigned;
                    ns    : unsigned;
                    subns : unsigned;
                    inc_subns : signed)   -- INC_PER_TICK + RATE_ADJ, signed
    return std_logic_vector;

end package ptp_pkg;

package body ptp_pkg is

  function sat_signed(v : signed; n : integer) return signed is
    -- limites de un signed de n bits, construidos por patron de bits para
    -- evitar el overflow de integer que produce 2**(n-1) con n grande (n=48).
    -- max_n =  0 1 1...1  (n bits)  ->  2^(n-1)-1
    -- min_n =  1 0 0...0  (n bits)  -> -2^(n-1)
    variable max_n : signed(n-1 downto 0);
    variable min_n : signed(n-1 downto 0);
    variable max_v : signed(v'length-1 downto 0);
    variable min_v : signed(v'length-1 downto 0);
  begin
    if v'length <= n then
      return resize(v, n);
    end if;
    -- max_n = 0111...1 : todos '1' y luego forzar el bit de signo a '0'
    max_n := (others => '1');
    max_n(n-1) := '0';
    -- min_n = 1000...0 : todos '0' y forzar el bit de signo a '1'
    min_n := (others => '0');
    min_n(n-1) := '1';
    max_v := resize(max_n, v'length);
    min_v := resize(min_n, v'length);
    if v > max_v then
      return max_n;
    elsif v < min_v then
      return min_n;
    else
      return resize(v, n);
    end if;
  end function;

  function clk_tick(sec   : unsigned;
                    ns    : unsigned;
                    subns : unsigned;
                    inc_subns : signed)
    return std_logic_vector is
    -- Trabajamos en un campo comun de fase = ns*2^32 + subns, con signo para
    -- poder restar cuando RATE_ADJ es negativo y empuja por debajo de 0.
    variable phase   : signed(NS_W + SUBNS_W + 1 downto 0);  -- holgura de signo/acarreo
    variable inc_ext : signed(NS_W + SUBNS_W + 1 downto 0);
    variable ns_v    : unsigned(NS_W-1 downto 0);
    variable subns_v : unsigned(SUBNS_W-1 downto 0);
    variable sec_v   : unsigned(SEC_W-1 downto 0);
    variable phu     : unsigned(NS_W + SUBNS_W - 1 downto 0);
  begin
    sec_v := sec;
    -- fase actual (siempre >= 0) en campo signed ancho
    phase := signed(resize(ns & subns, phase'length));
    -- inc_subns viene en peso subns (2^-32). INC nominal de 10 ns ya viene
    -- sumado por el llamante; aqui solo extendemos con signo.
    inc_ext := resize(inc_subns, inc_ext'length);
    phase := phase + inc_ext;

    -- Normalizar: la fase deberia mantenerse >= 0 en operacion normal (el
    -- INC nominal domina cualquier RATE_ADJ razonable). Si por saturacion
    -- extrema quedara negativa, la clampeamos a 0 (documentado; el ISS igual).
    if phase < 0 then
      phase := (others => '0');
    end if;

    phu := unsigned(std_logic_vector(phase(NS_W + SUBNS_W - 1 downto 0)));
    ns_v    := phu(NS_W + SUBNS_W - 1 downto SUBNS_W);
    subns_v := phu(SUBNS_W - 1 downto 0);

    -- wrap de ns a sec en 1e9 (puede requerir un solo decremento por tick,
    -- porque INC por tick << 1e9)
    if ns_v >= NS_PER_SEC then
      ns_v  := ns_v - NS_PER_SEC;
      sec_v := sec_v + 1;
    end if;

    return std_logic_vector(sec_v) & std_logic_vector(ns_v) & std_logic_vector(subns_v);
  end function;

end package body ptp_pkg;
