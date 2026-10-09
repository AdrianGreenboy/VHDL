-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Capa 1B: checker UDP con tramas del oraculo (buenas, mutadas, tuser, salto
-- de secuencia). Huecos de tvalid pseudoaleatorios o ninguno (GAPS).
-- Imprime los contadores; el script los compara con lo esperado.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.tb_eth21_pkg.all;

entity tb_eth21_chk is
  generic (
    INF  : string := "chk_in.txt";
    GAPS : natural := 1
  );
end entity tb_eth21_chk;

architecture sim of tb_eth21_chk is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal tdata : std_logic_vector(63 downto 0) := (others => '0');
  signal tkeep : std_logic_vector(7 downto 0) := (others => '0');
  signal tlast, tuser, tvalid : std_logic := '0';
  signal e_ok, e_bad, e_seq, e_rxe : std_logic;
  signal n_ok, n_bad, n_seq, n_rxe : natural := 0;
  signal fin : boolean := false;

  function hexval(c : character) return natural is
  begin
    case c is
      when '0' to '9' => return character'pos(c) - character'pos('0');
      when 'a' to 'f' => return character'pos(c) - character'pos('a') + 10;
      when 'A' to 'F' => return character'pos(c) - character'pos('A') + 10;
      when others => return 0;
    end case;
  end function;
begin
  clk <= not clk after 2 ns when not fin;

  dut: entity work.eth21_udp_chk
    port map (clk=>clk, rst=>rst, restart=>'0',
              dst=>T_PEER_MAC, src=>T_OWN_MAC, sip=>T_OWN_IP, dip=>T_PEER_IP,
              sport=>T_SPORT, dport=>T_DPORT,
              s_tdata=>tdata, s_tkeep=>tkeep, s_tlast=>tlast, s_tuser=>tuser,
              s_tvalid=>tvalid,
              ev_ok=>e_ok, ev_bad=>e_bad, ev_seq=>e_seq, ev_rxerr=>e_rxe);

  process(clk)
  begin
    if rising_edge(clk) then
      if e_ok = '1' then n_ok <= n_ok + 1; end if;
      if e_bad = '1' then n_bad <= n_bad + 1; end if;
      if e_seq = '1' then n_seq <= n_seq + 1; end if;
      if e_rxe = '1' then n_rxe <= n_rxe + 1; end if;
    end if;
  end process;

  process
    file f : text;
    variable l : line;
    variable tu : character;
    variable sp : character;
    variable s : string(1 to 4000);
    variable n, nb, b : natural;
    variable lf : std_logic_vector(15 downto 0) := x"BEEF";
  begin
    file_open(f, INF, read_mode);
    wait for 20 ns; wait until rising_edge(clk);
    rst <= '0';
    while not endfile(f) loop
      readline(f, l);
      read(l, tu); read(l, sp);
      n := l'length;
      s(1 to n) := l.all;
      nb := n / 2;
      b := 0;
      while b < nb loop
        -- hueco pseudoaleatorio
        lf := lfsr16(lf);
        if GAPS = 1 and lf(2) = '1' and lf(5) = '1' then
          tvalid <= '0';
          wait until rising_edge(clk);
        end if;
        tdata <= (others => '0'); tkeep <= (others => '0');
        for k in 0 to 7 loop
          if b + k < nb then
            tdata(8*k+7 downto 8*k) <= std_logic_vector(to_unsigned(
              16 * hexval(s(2*(b+k)+1)) + hexval(s(2*(b+k)+2)), 8));
            tkeep(k) <= '1';
          end if;
        end loop;
        if b + 8 >= nb then tlast <= '1'; else tlast <= '0'; end if;
        if tu = '1' then tuser <= '1'; else tuser <= '0'; end if;
        tvalid <= '1';
        wait until rising_edge(clk);
        b := b + 8;
      end loop;
      tvalid <= '0'; tlast <= '0';
      wait until rising_edge(clk);
    end loop;
    for i in 0 to 20 loop wait until rising_edge(clk); end loop;
    report "LAYER1B CHK ok=" & integer'image(n_ok) & " bad=" & integer'image(n_bad) &
           " seq=" & integer'image(n_seq) & " rxerr=" & integer'image(n_rxe);
    fin <= true;
    wait;
  end process;
end architecture sim;
