-- rv64_tlb.vhd - TLB totalmente asociativa de N entradas, etiquetada con ASID y G.
-- Busqueda combinacional; relleno y vaciado en flanco. Reemplazo round-robin.
-- Soporta paginas de 4 KiB, megapaginas de 2 MiB y gigapaginas de 1 GiB.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_mmu_pkg.all;

entity rv64_tlb is
  generic (N : positive := 8);
  port (
    clk, rst : in  std_logic;
    flush    : in  std_logic;                       -- sfence.vma (v1: total)
    vpn      : in  std_logic_vector(26 downto 0);
    asid     : in  std_logic_vector(15 downto 0);
    hit      : out std_logic;
    e        : out tlbe_t;
    fill     : in  std_logic;
    fill_e   : in  tlbe_t
  );
end entity;

architecture rtl of rv64_tlb is
  type arr_t is array (0 to N - 1) of tlbe_t;
  signal ent : arr_t;
  signal rr  : natural range 0 to N - 1;
begin
  process (all)
    variable h : boolean;
    variable r : tlbe_t;
  begin
    h := false; r := TLBE_NONE;
    for k in 0 to N - 1 loop
      if not h and tlb_match(ent(k), vpn, asid) then
        h := true; r := ent(k);
      end if;
    end loop;
    hit <= '1' when h else '0';
    e <= r;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or flush = '1' then
        for k in 0 to N - 1 loop ent(k).v <= '0'; end loop;
        rr <= 0;
      elsif fill = '1' then
        ent(rr) <= fill_e;
        if rr = N - 1 then rr <= 0; else rr <= rr + 1; end if;
      end if;
    end if;
  end process;
end architecture;
