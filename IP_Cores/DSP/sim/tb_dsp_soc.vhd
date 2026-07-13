-------------------------------------------------------------------------------
-- tb_dsp_soc.vhd  --  Capa 4: RTL-vs-ISS del IP DSP por MMIO (estilo familia).
-- Interpreta dsp_soc_prog.txt (WR/POLL/RD) generado por iss_dsp.py.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_dsp_soc is
end entity;

architecture sim of tb_dsp_soc is
  constant TCK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  signal req : std_logic := '0';
  signal addr: std_logic_vector(15 downto 0) := (others=>'0');
  signal wdata: std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb: std_logic_vector(3 downto 0) := (others=>'0');
  signal rdata: std_logic_vector(31 downto 0);
  signal ready: std_logic;
  signal errors : integer := 0;
  constant STATUS:integer:=16#008#;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.dsp_mmio
    port map (clk=>clk, rst=>rst, req=>req, addr=>addr,
              wdata=>wdata, wstrb=>wstrb, rdata=>rdata, ready=>ready);

  stim : process
    variable ln : line;
    variable c1 : character;
    variable good : boolean;
    variable voff : std_logic_vector(15 downto 0);
    variable vval : std_logic_vector(31 downto 0);
    variable rv : std_logic_vector(31 downto 0);
    variable a : integer;
    variable nread : integer := 0;
    file fh : text;
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure do_wr(aa:integer; d:std_logic_vector(31 downto 0)) is
    begin
      addr<=std_logic_vector(to_unsigned(aa,16)); wdata<=d; wstrb<="1111"; req<='1';
      step; req<='0'; wstrb<="0000"; step; wait for 1 ns;  -- +1 asentamiento BRAM
    end procedure;
    procedure do_poll is
    begin
      for w in 0 to 400000 loop
        addr<=std_logic_vector(to_unsigned(STATUS,16)); req<='1'; wstrb<="0000";
        wait for 1 ns; rv := rdata; step; req<='0';
        exit when rv(1)='1';
      end loop;
      assert rv(1)='1' report "TIMEOUT esperando DONE" severity failure;
    end procedure;
  begin
    rst<='1'; wait for 4*TCK; rst<='0'; wait for 2*TCK;
    file_open(fh, "dsp_soc_prog.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      -- primer caracter distingue el comando: W=WR, P=POLL, R=RD
      read(ln, c1, good);
      next when not good;
      if c1 = 'W' then
        read(ln, c1);              -- 'R'
        hread(ln, voff); hread(ln, vval);
        do_wr(to_integer(unsigned(voff)), vval);
      elsif c1 = 'P' then
        do_poll;
      elsif c1 = 'R' then
        read(ln, c1);              -- 'D'
        hread(ln, voff); hread(ln, vval);
        a := to_integer(unsigned(voff));
        addr<=std_logic_vector(to_unsigned(a,16)); req<='1'; wstrb<="0000";
        -- respetar ready (control inmediato; ventana DATA con wait-state BRAM)
        loop
          wait until rising_edge(clk);
          exit when ready='1';
        end loop;
        wait for 1 ns; rv := rdata; req<='0';
        if rv /= vval then
          errors <= errors + 1;
          if errors <= 8 then
            report "FALLO capa4 off="&to_hstring(voff)&": rtl="&to_hstring(rv)&
                   " oraculo="&to_hstring(vval) severity warning;
          end if;
        end if;
        nread := nread + 1;
      end if;
    end loop;
    file_close(fh);
    wait until rising_edge(clk);
    report "capa4 DSP: comparadas "&integer'image(nread)&" lecturas, errores="&integer'image(errors);
    assert errors=0 report "MUTANTE VIVO capa4: "&integer'image(errors)&" fallos" severity failure;
    report "CAPA4 DSP OK - RTL-vs-ISS bit-identico";
    done<=true; wait;
  end process;
end architecture;
