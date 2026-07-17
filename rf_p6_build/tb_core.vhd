-- tb_core.vhd - Verifica rv32im_core en aislamiento: imem cargado de test_core.hex,
-- dmem simple de 64KB con lectura COMBINACIONAL, corre hasta halt y vuelca 4
-- palabras de dmem para comparar con el ISS.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_core is
end entity tb_core;

architecture sim of tb_core is
  constant C_TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal imem_addr, imem_data : std_logic_vector(31 downto 0);
  signal dmem_addr, dmem_wdata, dmem_rdata : std_logic_vector(31 downto 0);
  signal dmem_we, dmem_re, halt : std_logic;
  signal dmem_be : std_logic_vector(3 downto 0);
  signal fin : boolean := false;

  type t_imem is array (0 to 255) of std_logic_vector(31 downto 0);
  impure function load_imem return t_imem is
    file f : text open read_mode is "test_core.hex";
    variable lin : line; variable w : std_logic_vector(31 downto 0);
    variable m : t_imem := (others => x"00000000");
    variable i : integer := 0;
  begin
    while not endfile(f) and i < 256 loop
      readline(f, lin); hread(lin, w); m(i) := w; i := i + 1;
    end loop;
    return m;
  end function;
  signal imem_r : t_imem := load_imem;

  type t_dmem is array (0 to 16383) of std_logic_vector(31 downto 0);
  signal dmem_r : t_dmem := (others => x"00000000");
begin
  clk <= '0' when fin else not clk after C_TCLK/2;

  imem_data <= imem_r(to_integer(unsigned(imem_addr(31 downto 2)))) when unsigned(imem_addr(31 downto 2)) < 256
               else x"00000000";

  -- dmem lectura COMBINACIONAL
  dmem_rdata <= dmem_r(to_integer(unsigned(dmem_addr(15 downto 2)))) when unsigned(dmem_addr) < 16#10000#
                else x"00000000";

  dut : entity work.rv32im_core
    generic map (IMEM_WORDS => 256)
    port map (clk_i=>clk, aresetn_i=>aresetn,
              imem_addr_o=>imem_addr, imem_data_i=>imem_data,
              dmem_addr_o=>dmem_addr, dmem_wdata_o=>dmem_wdata, dmem_we_o=>dmem_we,
              dmem_re_o=>dmem_re, dmem_be_o=>dmem_be, dmem_rdata_i=>dmem_rdata,
              halt_o=>halt);

  -- escritura sincrona de dmem
  proc_wr : process (clk)
  begin
    if rising_edge(clk) then
      if dmem_we = '1' and unsigned(dmem_addr) < 16#10000# then
        dmem_r(to_integer(unsigned(dmem_addr(15 downto 2)))) <= dmem_wdata;
      end if;
    end if;
  end process;

  proc : process
    variable ok : boolean := true;
    procedure chk(addr : integer; exp : integer) is
      variable got : integer;
    begin
      got := to_integer(signed(dmem_r(addr/4)));
      if got /= exp then
        report "FALLA dmem[0x"&to_hstring(to_unsigned(addr,16))&"] esp="&integer'image(exp)&
               " got="&integer'image(got) severity error;
        ok := false;
      end if;
    end procedure;
  begin
    aresetn <= '0';
    wait for 3*C_TCLK;
    aresetn <= '1';
    -- correr hasta halt
    for k in 1 to 2000 loop
      wait until rising_edge(clk);
      exit when halt = '1';
    end loop;
    wait until rising_edge(clk);
    chk(16#100#, 30); chk(16#104#, 40); chk(16#108#, 15); chk(16#10C#, 200);
    if ok then
      report "FIN SIMULACION CORE: PASS @ "&time'image(now) severity note;
    else
      report "FIN SIMULACION CORE: FAIL @ "&time'image(now) severity error;
    end if;
    fin <= true;
    wait;
  end process;
end architecture sim;
