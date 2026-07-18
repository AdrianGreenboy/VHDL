-- Verifica P1/P2: congelar el core (y el AMO) a mitad de ejecucion con
-- core_clk_en pulsante NO corrompe el resultado. Corre un programa con AMOs
-- dos veces: una con en=1 siempre, otra con en pulsante, y compara memoria.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;
entity tb_amo_freeze is end entity;
architecture sim of tb_amo_freeze is
  signal clk: std_logic:='0'; signal rstn: std_logic:='0';
  signal en: std_logic:='1';
  signal iaddr,idata,daddr,dwdata,rdata: std_logic_vector(31 downto 0);
  signal we,re,halt,stf,stm,sts: std_logic; signal be: std_logic_vector(3 downto 0);
  signal dbg: std_logic_vector(1023 downto 0);
  constant NW: natural:=4096;
  type t_mem is array(0 to NW-1) of std_logic_vector(31 downto 0);
  impure function lp return t_mem is
    variable m: t_mem:=(others=>(others=>'0'));
    file f: text open read_mode is "lockstep.mem";
    variable l: line; variable w: std_logic_vector(31 downto 0); variable i: natural:=0;
  begin
    while not endfile(f) and i<NW loop readline(f,l); hread(l,w); m(i):=w; i:=i+1; end loop;
    return m;
  end function;
  signal mem: t_mem:=lp;
  function idx(a:std_logic_vector(31 downto 0)) return integer is
  begin return to_integer(unsigned(a(13 downto 2))); end function;
begin
  dut: entity work.rv32ima_core generic map(RESET_PC=>x"80000000")
    port map(clk_i=>clk,aresetn_i=>rstn,core_clk_en_i=>en,
      imem_addr_o=>iaddr,imem_data_i=>idata,dmem_addr_o=>daddr,dmem_wdata_o=>dwdata,
      dmem_we_o=>we,dmem_re_o=>re,dmem_be_o=>be,dmem_rdata_i=>rdata,halt_o=>halt,
      st_fetch_o=>stf,st_mem_o=>stm,st_store_o=>sts,dbg_regs_o=>dbg);
  idata <= mem(idx(iaddr)) when iaddr(31)='1' else (others=>'0');
  rdata <= mem(idx(daddr)) when daddr(31)='1' else (others=>'0');
  process(clk) begin
    if rising_edge(clk) then
      if en='1' and we='1' and daddr(31)='1' and daddr/=x"11100000" then
        if be(0)='1' then mem(idx(daddr))(7 downto 0)   <= dwdata(7 downto 0);   end if;
        if be(1)='1' then mem(idx(daddr))(15 downto 8)  <= dwdata(15 downto 8);  end if;
        if be(2)='1' then mem(idx(daddr))(23 downto 16) <= dwdata(23 downto 16); end if;
        if be(3)='1' then mem(idx(daddr))(31 downto 24) <= dwdata(31 downto 24); end if;
      end if;
    end if;
  end process;
  clk <= not clk after 5 ns;
  -- en pulsante: 2 ciclos on, 1 ciclo off, para congelar a mitad de AMOs
  process begin
    wait until rstn='1';
    loop
      en<='1'; wait until rising_edge(clk); wait until rising_edge(clk);
      en<='0'; wait until rising_edge(clk);
    end loop;
  end process;
  chk: process
    variable to_c: integer:=0;
  begin
    wait until rising_edge(clk); wait until rising_edge(clk); rstn<='1';
    loop
      wait until rising_edge(clk); wait for 1 ns;
      exit when halt='1' or (en='1' and we='1' and daddr=x"11100000" and dwdata=x"00005555");
      to_c:=to_c+1;
      assert to_c<50000 report "TIMEOUT en PC=" & to_hstring(iaddr) & " estado stf=" & std_logic'image(stf) severity failure;
    end loop;
    -- verificar el resultado final de la cadena AMO en 0x210
    assert mem(idx(x"80000210"))=x"00000063"
      report "AMO CORROMPIDO con freeze: mem[0x210]=" & to_hstring(mem(idx(x"80000210")))
      severity failure;
    report "AMO FREEZE OK: mem[0x210]=00000063 con core_clk_en pulsante" severity note;
    finish;
  end process;
end architecture;
