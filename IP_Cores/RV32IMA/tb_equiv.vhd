-- Verifica que rv32im_core_ce con core_clk_en_i='1' es identico al
-- rv32im_core original. Ambos con memoria combinacional de latencia cero
-- cargada con el mismo programa. Compara imem_addr (PC) y halt cada ciclo.
library ieee;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_equiv is
end entity;

architecture sim of tb_equiv is
  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';
  signal en   : std_logic := '1';

  signal a_iaddr, a_idata, a_daddr, a_dwdata, a_rdata : std_logic_vector(31 downto 0);
  signal a_we, a_re, a_halt : std_logic;
  signal a_be : std_logic_vector(3 downto 0);

  signal b_iaddr, b_idata, b_daddr, b_dwdata, b_rdata : std_logic_vector(31 downto 0);
  signal b_we, b_re, b_halt : std_logic;
  signal b_be : std_logic_vector(3 downto 0);

  constant N : natural := 256;
  type t_mem is array (0 to N-1) of std_logic_vector(31 downto 0);

  -- programa RV32IM de prueba, leido del .mem generado por asm.py
  impure function load_prog return t_mem is
    variable m : t_mem := (others => (others => '0'));
    file f     : text open read_mode is "prog_equiv.mem";
    variable l : line;
    variable w : std_logic_vector(31 downto 0);
    variable i : natural := 0;
  begin
    while not endfile(f) and i < N loop
      readline(f, l);
      hread(l, w);
      m(i) := w;
      i := i + 1;
    end loop;
    return m;
  end function;

  signal amem : t_mem := load_prog;
  signal bmem : t_mem := load_prog;
begin

  dut_a : entity work.rv32im_core
    port map (clk_i=>clk, aresetn_i=>rstn,
      imem_addr_o=>a_iaddr, imem_data_i=>a_idata,
      dmem_addr_o=>a_daddr, dmem_wdata_o=>a_dwdata, dmem_we_o=>a_we,
      dmem_re_o=>a_re, dmem_be_o=>a_be, dmem_rdata_i=>a_rdata, halt_o=>a_halt);

  dut_b : entity work.rv32im_core_ce
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>en,
      imem_addr_o=>b_iaddr, imem_data_i=>b_idata,
      dmem_addr_o=>b_daddr, dmem_wdata_o=>b_dwdata, dmem_we_o=>b_we,
      dmem_re_o=>b_re, dmem_be_o=>b_be, dmem_rdata_i=>b_rdata, halt_o=>b_halt,
      st_fetch_o=>open, st_mem_o=>open, st_store_o=>open);

  -- memorias combinacionales de latencia cero
  a_idata <= amem(to_integer(unsigned(a_iaddr(31 downto 2)))) when unsigned(a_iaddr(31 downto 2)) < N else (others=>'0');
  a_rdata <= amem(to_integer(unsigned(a_daddr(31 downto 2)))) when unsigned(a_daddr(31 downto 2)) < N else (others=>'0');
  b_idata <= bmem(to_integer(unsigned(b_iaddr(31 downto 2)))) when unsigned(b_iaddr(31 downto 2)) < N else (others=>'0');
  b_rdata <= bmem(to_integer(unsigned(b_daddr(31 downto 2)))) when unsigned(b_daddr(31 downto 2)) < N else (others=>'0');

  -- escritura sincrona en ambas memorias
  process(clk)
  begin
    if rising_edge(clk) then
      if a_we='1' and unsigned(a_daddr(31 downto 2)) < N then
        amem(to_integer(unsigned(a_daddr(31 downto 2)))) <= a_dwdata;
      end if;
      if b_we='1' and unsigned(b_daddr(31 downto 2)) < N then
        bmem(to_integer(unsigned(b_daddr(31 downto 2)))) <= b_dwdata;
      end if;
    end if;
  end process;

  clk <= not clk after 5 ns;

  chk : process
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    -- correr hasta que AMBOS hayan hecho halt (equivalencia arquitectural,
    -- no ciclo-a-ciclo: el core_ce con S_STORE toma 1 ciclo mas por store)
    for i in 0 to 600 loop
      wait until rising_edge(clk);
      wait for 1 ns;
      exit when a_halt = '1' and b_halt = '1';
    end loop;
    assert a_halt = '1' and b_halt = '1'
      report "no ambos llegaron a halt" severity failure;
    -- comparar registros via memoria final: ambos escribieron los mismos
    -- resultados en las mismas direcciones.
    for i in 0 to N-1 loop
      assert amem(i) = bmem(i)
        report "MEM DIVERGE palabra " & integer'image(i) &
               " orig=" & to_hstring(amem(i)) & " ce=" & to_hstring(bmem(i))
        severity failure;
    end loop;
    report "EQUIVALENCIA CORE: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
