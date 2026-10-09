-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Capa 1A: generador UDP. Vuelca cada trama (hex, una por linea) a OUTF; el
-- oraculo compara byte a byte. Backpressure pseudoaleatoria opcional, gap,
-- modo continuo con STOP.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.tb_eth21_pkg.all;

entity tb_eth21_gen is
  generic (
    LMIN   : natural := 18;
    LMAX   : natural := 200;
    LSTEP  : natural := 37;
    COUNT  : natural := 40;
    GAP    : natural := 0;
    BP     : natural := 1;      -- 1: tready pseudoaleatorio
    CONT   : natural := 0;      -- 1: modo continuo, STOP tras STOPAT tramas
    STOPAT : natural := 10;
    OWNIP  : std_logic_vector(31 downto 0) := x"C0A81502";
    PEERIP : std_logic_vector(31 downto 0) := x"C0A81501";
    OUTF   : string  := "gen_out.txt"
  );
end entity tb_eth21_gen;

architecture sim of tb_eth21_gen is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start, stop : std_logic := '0';
  signal tdata : std_logic_vector(63 downto 0);
  signal tkeep : std_logic_vector(7 downto 0);
  signal tlast, tvalid, busy, done : std_logic;
  signal tready : std_logic := '1';
  signal lf : std_logic_vector(15 downto 0) := x"ACE1";
  signal nframes : natural := 0;
  signal fin : boolean := false;
  signal cont_s : std_logic;
  signal mingap : natural := 1000000;
  signal gapc   : natural := 0;
  signal ingap  : boolean := false;
begin
  clk <= not clk after 2 ns when not fin;
  cont_s <= '1' when CONT = 1 else '0';

  dut: entity work.eth21_udp_gen
    port map (clk=>clk, rst=>rst, start=>start, stop=>stop, cont=>cont_s,
              dst=>T_PEER_MAC, src=>T_OWN_MAC, sip=>OWNIP, dip=>PEERIP,
              sport=>T_SPORT, dport=>T_DPORT,
              len_min=>to_unsigned(LMIN, 11), len_max=>to_unsigned(LMAX, 11),
              len_step=>to_unsigned(LSTEP, 11), count=>to_unsigned(COUNT, 32),
              gap=>to_unsigned(GAP, 16),
              m_tdata=>tdata, m_tkeep=>tkeep, m_tlast=>tlast, m_tvalid=>tvalid,
              m_tready=>tready, busy=>busy, done=>done);

  process(clk)
  begin
    if rising_edge(clk) then
      lf <= lfsr16(lf);
      if BP = 1 then tready <= lf(3) or lf(7); else tready <= '1'; end if;
    end if;
  end process;

  -- recoge tramas
  process(clk)
    file f : text open write_mode is OUTF;
    variable l : line;
  begin
    if rising_edge(clk) then
      -- hueco minimo entre el ultimo y el primer word de tramas seguidas
      if ingap then
        if tvalid = '1' then
          if gapc < mingap then mingap <= gapc; end if;
          ingap <= false;
        else
          gapc <= gapc + 1;
        end if;
      end if;
      if tvalid = '1' and tready = '1' and tlast = '1' then
        ingap <= true; gapc <= 0;
      end if;
      if tvalid = '1' and tready = '1' then
        for b in 0 to 7 loop
          if tkeep(b) = '1' then write(l, hex2(tdata(8*b+7 downto 8*b))); end if;
        end loop;
        if tlast = '1' then
          writeline(f, l);
          nframes <= nframes + 1;
        end if;
      end if;
    end if;
  end process;

  process
    variable cyc : natural := 0;
  begin
    wait for 40 ns; wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    start <= '1'; wait until rising_edge(clk); start <= '0';
    loop
      wait until rising_edge(clk);
      cyc := cyc + 1;
      if CONT = 1 and nframes = STOPAT and stop = '0' then
        stop <= '1';
      else
        stop <= '0';
      end if;
      exit when done = '1' or cyc > 400000;
    end loop;
    for i in 0 to 20 loop wait until rising_edge(clk); end loop;
    if done = '1' and busy = '0' then
      report "LAYER1A GEN frames=" & integer'image(nframes) & " PASS mingap=" & integer'image(mingap);
    else
      report "LAYER1A GEN FAIL (timeout) frames=" & integer'image(nframes) severity error;
    end if;
    fin <= true;
    wait;
  end process;
end architecture sim;
