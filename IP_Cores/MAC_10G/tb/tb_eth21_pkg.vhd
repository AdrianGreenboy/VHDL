-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT : constantes y utilidades de testbench
-- (la misma configuracion que oracle/gen_vectors.py)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_eth21_pkg is
  constant T_PEER_MAC : std_logic_vector(47 downto 0) := x"665544332211";
  constant T_OWN_MAC  : std_logic_vector(47 downto 0) := x"204E47454E02";
  constant T_OWN_IP   : std_logic_vector(31 downto 0) := x"C0A81502";
  constant T_PEER_IP  : std_logic_vector(31 downto 0) := x"C0A81501";
  constant T_SPORT    : std_logic_vector(15 downto 0) := x"5210";
  constant T_DPORT    : std_logic_vector(15 downto 0) := x"5211";

  function hex2(b : std_logic_vector(7 downto 0)) return string;
  function hexv(v : std_logic_vector) return string;

  -- LFSR de 16 bits para patrones pseudoaleatorios
  function lfsr16(x : std_logic_vector(15 downto 0)) return std_logic_vector;
end package tb_eth21_pkg;

package body tb_eth21_pkg is
  function hexc(n : natural) return character is
    constant H : string(1 to 16) := "0123456789ABCDEF";
  begin
    return H(n + 1);
  end function;

  function hex2(b : std_logic_vector(7 downto 0)) return string is
  begin
    return hexc(to_integer(unsigned(b(7 downto 4)))) & hexc(to_integer(unsigned(b(3 downto 0))));
  end function;

  function hexv(v : std_logic_vector) return string is
    constant N : natural := (v'length + 3) / 4;
    variable x : std_logic_vector(4 * N - 1 downto 0) := (others => '0');
    variable s : string(1 to N);
  begin
    x(v'length - 1 downto 0) := v;
    for i in 0 to N - 1 loop
      s(N - i) := hexc(to_integer(unsigned(x(4 * i + 3 downto 4 * i))));
    end loop;
    return s;
  end function;

  function lfsr16(x : std_logic_vector(15 downto 0)) return std_logic_vector is
    variable fb : std_logic;
  begin
    fb := x(15) xor x(13) xor x(12) xor x(10);
    return x(14 downto 0) & fb;
  end function;
end package body tb_eth21_pkg;
