-- rv64_plic.vhd - PLIC compatible "riscv,plic0": 31 fuentes (1..31), prioridad de
-- 3 bits (0 = deshabilitada), 2 contextos: 0 = M hart0 (meip), 1 = S hart0 (seip).
-- Pasarelas por nivel: una fuente activa queda pendiente hasta que se reclama; no
-- vuelve a quedar pendiente hasta el complete. Solo accesos de 4 bytes.
--   0x000004+4i prioridad[i]   0x001000 pendientes   0x002000/0x002080 enable ctx0/1
--   0x200000/0x201000 umbral   0x200004/0x201004 claim/complete
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_plic is
  port (
    clk, rst : in  std_logic;
    req      : in  std_logic;
    we       : in  std_logic;
    addr     : in  std_logic_vector(25 downto 0);
    size     : in  std_logic_vector(1 downto 0);
    wdata    : in  xword;                              -- por carriles
    rdata    : out xword;                              -- por carriles
    err      : out std_logic;
    src      : in  std_logic_vector(31 downto 1);
    meip, seip : out std_logic
  );
end entity;

architecture rtl of rv64_plic is
  type prio_t is array (1 to 31) of unsigned(2 downto 0);
  signal prio     : prio_t;
  signal pending  : std_logic_vector(31 downto 1);
  signal active   : std_logic_vector(31 downto 1);
  type en_t is array (0 to 1) of std_logic_vector(31 downto 1);
  signal enable   : en_t;
  type th_t is array (0 to 1) of unsigned(2 downto 0);
  signal thresh   : th_t;
  type id_t is array (0 to 1) of natural range 0 to 31;
  signal best     : id_t;                            -- mejor candidato por contexto
  signal w32      : std_logic_vector(31 downto 0);
  signal off      : unsigned(25 downto 0);
begin
  off <= unsigned(addr(25 downto 2)) & "00";
  w32 <= wdata(63 downto 32) when addr(2) = '1' else wdata(31 downto 0);

  -- arbitraje: mayor prioridad, empate al menor id, y por encima del umbral
  process (all)
    variable b  : natural range 0 to 31;
    variable bp : unsigned(2 downto 0);
  begin
    for c in 0 to 1 loop
      b := 0; bp := (others => '0');
      for i in 1 to 31 loop
        if pending(i) = '1' and enable(c)(i) = '1' and prio(i) > bp then
          b := i; bp := prio(i);
        end if;
      end loop;
      if bp > thresh(c) then best(c) <= b; else best(c) <= 0; end if;
    end loop;
  end process;
  meip <= '1' when best(0) /= 0 else '0';
  seip <= '1' when best(1) /= 0 else '0';

  process (all)
    variable v : std_logic_vector(31 downto 0);
    variable i : natural range 0 to 1023;
  begin
    v := (others => '0');
    if off < x"001000" then
      i := to_integer(off(11 downto 2));
      if i >= 1 and i <= 31 then v(2 downto 0) := std_logic_vector(prio(i)); end if;
    elsif off = x"001000" then v := pending & '0';
    elsif off = x"002000" then v := enable(0) & '0';
    elsif off = x"002080" then v := enable(1) & '0';
    elsif off = x"200000" then v(2 downto 0) := std_logic_vector(thresh(0));
    elsif off = x"200004" then v := std_logic_vector(to_unsigned(best(0), 32));
    elsif off = x"201000" then v(2 downto 0) := std_logic_vector(thresh(1));
    elsif off = x"201004" then v := std_logic_vector(to_unsigned(best(1), 32));
    end if;
    if addr(2) = '1' then rdata <= v & x"00000000"; else rdata <= x"00000000" & v; end if;
    err <= '1' when req = '1' and size /= "10" else '0';
  end process;

  process (clk)
    variable i : natural range 0 to 1023;
    variable id : natural range 0 to 31;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        prio <= (others => (others => '0')); pending <= (others => '0'); active <= (others => '0');
        enable <= (others => (others => '0')); thresh <= (others => (others => '0'));
      else
        -- pasarelas por nivel
        for k in 1 to 31 loop
          if src(k) = '1' and active(k) = '0' then pending(k) <= '1'; end if;
        end loop;
        if req = '1' and size = "10" then
          if we = '1' then
            if off < x"001000" then
              i := to_integer(off(11 downto 2));
              if i >= 1 and i <= 31 then prio(i) <= unsigned(w32(2 downto 0)); end if;
            elsif off = x"002000" then enable(0) <= w32(31 downto 1);
            elsif off = x"002080" then enable(1) <= w32(31 downto 1);
            elsif off = x"200000" then thresh(0) <= unsigned(w32(2 downto 0));
            elsif off = x"201000" then thresh(1) <= unsigned(w32(2 downto 0));
            elsif off = x"200004" or off = x"201004" then
              id := to_integer(unsigned(w32(4 downto 0)));      -- complete
              if id /= 0 then active(id) <= '0'; end if;
            end if;
          else
            -- claim: lectura con efecto (el bridge garantiza una sola lectura)
            if off = x"200004" and best(0) /= 0 then
              pending(best(0)) <= '0'; active(best(0)) <= '1';
            elsif off = x"201004" and best(1) /= 0 then
              pending(best(1)) <= '0'; active(best(1)) <= '1';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
