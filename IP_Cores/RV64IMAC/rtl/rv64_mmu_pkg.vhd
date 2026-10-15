-- rv64_mmu_pkg.vhd - tipos y comprobacion de permisos Sv39 (Svade).
-- Semantica identica a Hart.translate de iss64.py.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

package rv64_mmu_pkg is
  -- tipo de acceso
  constant ACC_FETCH : std_logic_vector(1 downto 0) := "00";
  constant ACC_LOAD  : std_logic_vector(1 downto 0) := "01";
  constant ACC_STORE : std_logic_vector(1 downto 0) := "10";   -- store y AMO/SC

  type tlbe_t is record
    v     : std_logic;
    vpn   : std_logic_vector(26 downto 0);
    asid  : std_logic_vector(15 downto 0);
    g     : std_logic;
    lvl   : std_logic_vector(1 downto 0);          -- 0: 4 KiB, 1: 2 MiB, 2: 1 GiB
    ppn   : std_logic_vector(43 downto 0);
    r, w, x, u, d : std_logic;                      -- A=1 siempre (Svade: A=0 no se cachea)
  end record;
  constant TLBE_NONE : tlbe_t := ('0', (others => '0'), (others => '0'), '0', "00",
                                  (others => '0'), '0', '0', '0', '0', '0');

  -- coincidencia de VPN segun el nivel de la entrada
  function tlb_match(e : tlbe_t; vpn : std_logic_vector(26 downto 0);
                     asid : std_logic_vector(15 downto 0)) return boolean;
  -- direccion fisica a partir de la entrada y la VA
  function tlb_pa(e : tlbe_t; va : xword) return xword;
  -- permisos: true si el acceso esta permitido
  function tlb_perm_ok(e : tlbe_t; acc : std_logic_vector(1 downto 0);
                       eff_priv : std_logic_vector(1 downto 0); sum, mxr : std_logic) return boolean;
  -- VA canonica para Sv39 (bits 63..39 = bit 38)
  function va_canonical(va : xword) return boolean;
end package;

package body rv64_mmu_pkg is

  function tlb_match(e : tlbe_t; vpn : std_logic_vector(26 downto 0);
                     asid : std_logic_vector(15 downto 0)) return boolean is
    variable m : boolean;
  begin
    if e.v = '0' then return false; end if;
    if e.g = '0' and e.asid /= asid then return false; end if;
    m := e.vpn(26 downto 18) = vpn(26 downto 18);
    if e.lvl /= "10" then m := m and e.vpn(17 downto 9) = vpn(17 downto 9); end if;
    if e.lvl = "00" then m := m and e.vpn(8 downto 0) = vpn(8 downto 0); end if;
    return m;
  end function;

  function tlb_pa(e : tlbe_t; va : xword) return xword is
    variable pa : std_logic_vector(55 downto 0);
  begin
    pa := e.ppn & va(11 downto 0);
    if e.lvl /= "00" then pa(20 downto 12) := va(20 downto 12); end if;
    if e.lvl = "10" then pa(29 downto 21) := va(29 downto 21); end if;
    return x"00" & pa;
  end function;

  function tlb_perm_ok(e : tlbe_t; acc : std_logic_vector(1 downto 0);
                       eff_priv : std_logic_vector(1 downto 0); sum, mxr : std_logic) return boolean is
    variable ok : boolean;
  begin
    if acc = ACC_FETCH then
      ok := e.x = '1';
    elsif acc = ACC_LOAD then
      ok := e.r = '1' or (mxr = '1' and e.x = '1');
    else
      ok := e.w = '1' and e.d = '1';                -- Svade: D=0 en store -> fallo
    end if;
    if eff_priv = PRV_U and e.u = '0' then ok := false; end if;
    if eff_priv = PRV_S and e.u = '1' and (acc = ACC_FETCH or sum = '0') then ok := false; end if;
    return ok;
  end function;

  function va_canonical(va : xword) return boolean is
  begin
    return va(63 downto 38) = (63 downto 38 => '0') or va(63 downto 38) = (63 downto 38 => '1');
  end function;

end package body;
