-- tb_soc.vhd - Capa 4: SoC RF completo con firmware real. Carga fw_poll.hex en
-- imem, provee scratch dmem (comb) y un BFM DDR (arreglo escrito por el puerto
-- DMA). Corre hasta halt, luego compara DDR[0x70000000..] contra ddr_esperado.txt
-- y el checksum contra ddr_chk.txt.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_soc is
end entity tb_soc;

architecture sim of tb_soc is
  constant C_TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal imem_addr, imem_data : std_logic_vector(31 downto 0);
  signal dm_addr, dm_wdata, dm_rdata : std_logic_vector(31 downto 0);
  signal dm_we : std_logic;
  signal ddr_wr_en : std_logic;
  signal ddr_wr_addr, ddr_wr_data : std_logic_vector(31 downto 0);
  signal halt : std_logic;
  signal fin : boolean := false;

  type t_imem is array (0 to 255) of std_logic_vector(31 downto 0);
  impure function load_imem return t_imem is
    file f : text open read_mode is "fw_poll.hex";
    variable lin : line; variable w : std_logic_vector(31 downto 0);
    variable m : t_imem := (others => x"00000000"); variable i : integer := 0;
  begin
    while not endfile(f) and i < 256 loop
      readline(f, lin); hread(lin, w); m(i):=w; i:=i+1;
    end loop;
    return m;
  end function;
  signal imem_r : t_imem := load_imem;

  type t_dmem is array (0 to 16383) of std_logic_vector(31 downto 0);
  signal dmem_r : t_dmem := (others => x"00000000");

  -- DDR BFM: 64 palabras desde 0x70000000
  type t_ddr is array (0 to 1023) of std_logic_vector(31 downto 0);
  signal ddr_r : t_ddr := (others => x"00000000");
begin
  clk <= '0' when fin else not clk after C_TCLK/2;

  imem_data <= imem_r(to_integer(unsigned(imem_addr(31 downto 2)))) when unsigned(imem_addr(31 downto 2)) < 256
               else x"00000000";
  dm_rdata <= dmem_r(to_integer(unsigned(dm_addr(15 downto 2)))) when unsigned(dm_addr) < 16#10000#
              else x"00000000";

  dut : entity work.rf_soc_top
    port map (clk_i=>clk, aresetn_i=>aresetn,
              imem_addr_o=>imem_addr, imem_data_i=>imem_data,
              dm_addr_o=>dm_addr, dm_wdata_o=>dm_wdata, dm_we_o=>dm_we, dm_rdata_i=>dm_rdata,
              ddr_wr_en_o=>ddr_wr_en, ddr_wr_addr_o=>ddr_wr_addr, ddr_wr_data_o=>ddr_wr_data,
              halt_o=>halt);

  proc_dm : process (clk)
  begin
    if rising_edge(clk) then
      if dm_we = '1' and unsigned(dm_addr) < 16#10000# then
        dmem_r(to_integer(unsigned(dm_addr(15 downto 2)))) <= dm_wdata;
      end if;
    end if;
  end process;

  -- DDR BFM: escribe cuando el DMA lo pide
  proc_ddr : process (clk)
    variable idx : integer;
  begin
    if rising_edge(clk) then
      if ddr_wr_en = '1' then
        idx := to_integer(unsigned(ddr_wr_addr) - 16#70000000#) / 4;
        if idx >= 0 and idx < 1024 then
          ddr_r(idx) <= ddr_wr_data;
        end if;
      end if;
    end if;
  end process;

  proc : process
    file f_exp : text open read_mode is "ddr_esperado.txt";
    file f_chk : text open read_mode is "ddr_chk.txt";
    variable lin : line;
    variable exp_v, chk_e : std_logic_vector(31 downto 0);
    variable chk_v : std_logic_vector(31 downto 0) := (others=>'0');
    variable ok : boolean := true;
    variable n : integer := 0;
  begin
    aresetn <= '0';
    wait for 3*C_TCLK;
    aresetn <= '1';
    for k in 1 to 200000 loop
      wait until rising_edge(clk);
      exit when halt = '1';
    end loop;
    -- esperar a que el DMA termine de vaciar (holgura)
    for k in 1 to 4000 loop wait until rising_edge(clk); end loop;

    readline(f_chk, lin); hread(lin, chk_e);
    n := 0;
    while not endfile(f_exp) loop
      readline(f_exp, lin); hread(lin, exp_v);
      if ddr_r(n) /= exp_v then
        if ok then
          report "FALLA DDR["&integer'image(n)&"] esp="&to_hstring(exp_v)&
                 " got="&to_hstring(ddr_r(n)) severity error;
        end if;
        ok := false;
      end if;
      chk_v := (chk_v(30 downto 0) & chk_v(31)) xor ddr_r(n);
      n := n + 1;
    end loop;
    if chk_v /= chk_e then
      report "FALLA checksum esp="&to_hstring(chk_e)&" got="&to_hstring(chk_v) severity error;
      ok := false;
    end if;
    if ok then
      report "FIN SIMULACION SOC: PASS N="&integer'image(n)&" CHK=0x"&to_hstring(chk_v)&
             " @ "&time'image(now) severity note;
    else
      report "FIN SIMULACION SOC: FAIL @ "&time'image(now) severity error;
    end if;
    fin <= true;
    wait;
  end process;
end architecture sim;
