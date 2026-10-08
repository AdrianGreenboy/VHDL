-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 2C: checker de tramas contra el oraculo con tramas fabricadas:
-- buenas (con y sin padding), payload alterado, truncada, alargada con ceros,
-- padding de mas, destino alterado, byte de padding no nulo, tuser=1 y salto
-- de secuencia; con huecos de valid aleatorios.
-- Criterio: LAYER2C_PASS FNV32=<firma del oraculo sobre los 4 contadores>.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_mac_chk is
end entity;

architecture sim of tb_mac_chk is
  constant T : time := 2.56 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal tdata : std_logic_vector(63 downto 0) := (others => '0');
  signal tkeep : std_logic_vector(7 downto 0) := (others => '0');
  signal tlast, tuser, tvalid : std_logic := '0';
  signal e_ok, e_bad, e_seq, e_rxe : std_logic;
  signal done_sim : boolean := false;
  type cnt_arr is array (0 to 3) of natural;
  signal cnts : cnt_arr := (others => 0);
  constant OWN : std_logic_vector(47 downto 0) := x"2032" & x"43414D02";
  constant SRC : std_logic_vector(47 downto 0) := x"204E" & x"45474E02";
begin
  clk <= not clk after T/2 when not done_sim;

  dut: entity work.mac25g_chk
    port map (clk=>clk, rst=>rst, restart=>'0', dst=>OWN, src=>SRC,
              s_tdata=>tdata, s_tkeep=>tkeep, s_tlast=>tlast, s_tuser=>tuser,
              s_tvalid=>tvalid, ev_ok=>e_ok, ev_bad=>e_bad, ev_seq=>e_seq,
              ev_rxerr=>e_rxe);

  process(clk)
    variable c : cnt_arr;
  begin
    if rising_edge(clk) then
      c := cnts;
      if e_ok = '1' then c(0) := c(0) + 1; end if;
      if e_bad = '1' then c(1) := c(1) + 1; end if;
      if e_seq = '1' then c(2) := c(2) + 1; end if;
      if e_rxe = '1' then c(3) := c(3) + 1; end if;
      cnts <= c;
    end if;
  end process;

  process
    file f : text;
    variable l : line;
    variable n, lst, usr, gap, v, errs : integer := 0;
    variable d : std_logic_vector(63 downto 0);
    variable k : std_logic_vector(7 downto 0);
    variable h : unsigned(31 downto 0) := x"811C9DC5";
    procedure fnv32(x : natural) is
      variable w : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(x, 32));
    begin
      for i in 0 to 3 loop
        h := h xor resize(unsigned(w(8*i+7 downto 8*i)), 32);
        h := resize(h * to_unsigned(16777619, 32), 32);
      end loop;
    end procedure;
  begin
    rst <= '1'; wait for 10*T; wait until rising_edge(clk); rst <= '0';
    file_open(f, "chk_in.txt", read_mode);
    readline(f, l); read(l, n);
    for i in 1 to n loop
      readline(f, l); hread(l, d); hread(l, k); read(l, lst); read(l, usr); read(l, gap);
      if gap = 1 then tvalid <= '0'; wait until rising_edge(clk); end if;
      tvalid <= '1'; tdata <= d; tkeep <= k;
      if lst = 1 then tlast <= '1'; else tlast <= '0'; end if;
      if usr = 1 then tuser <= '1'; else tuser <= '0'; end if;
      wait until rising_edge(clk);
    end loop;
    tvalid <= '0';
    file_close(f);
    for i in 0 to 20 loop wait until rising_edge(clk); end loop;
    file_open(f, "chk_cnt.txt", read_mode);
    for i in 0 to 3 loop
      readline(f, l); read(l, v);
      fnv32(cnts(i));
      if cnts(i) /= v then
        errs := errs + 1;
        report "FAIL contador checker " & integer'image(i) & " = " &
          integer'image(cnts(i)) & " esperado " & integer'image(v) severity error;
      end if;
    end loop;
    file_close(f);
    if errs = 0 then
      report "LAYER2C_PASS FNV32=0x" & to_hstring(std_logic_vector(h)) &
        " ok=" & integer'image(cnts(0)) & " bad=" & integer'image(cnts(1)) &
        " seq=" & integer'image(cnts(2)) & " rxerr=" & integer'image(cnts(3));
    else
      report "LAYER2C_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
