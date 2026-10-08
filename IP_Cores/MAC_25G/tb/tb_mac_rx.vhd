-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 2B: MAC RX contra el oraculo.
--
-- Estimulo (rx_in.txt): tramas buenas de todas las longitudes finales,
-- broadcast, destino ajeno, CRC malo, runt, oversize, abortos por /E/ y por
-- /S/, preambulo malo, bloques no soportados, tramas de 0 y 1 palabra, y
-- huecos de valid aleatorios entre bloques.
-- Esperado: rx_out.txt (palabras AXIS con tkeep/tlast/tuser) y rx_cnt.txt.
--
-- Criterio: LAYER2B_PASS FNV32=<firma del oraculo>.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.mac25g_pkg.all;

entity tb_mac_rx is
  generic (DIR : string := ".");
end entity;

architecture sim of tb_mac_rx is
  constant T : time := 2.56 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal iv, isd : std_logic := '0';
  signal ipl : std_logic_vector(63 downto 0) := (others => '0');
  signal tdata : std_logic_vector(63 downto 0);
  signal tkeep : std_logic_vector(7 downto 0);
  signal tlast, tuser, tvalid : std_logic;
  signal e_ok, e_crc, e_runt, e_r0, e_over, e_ab, e_a0, e_filt, e_proto, lnk : std_logic;
  signal e_bytes : unsigned(15 downto 0);
  signal done_sim, feed_done : boolean := false;

  constant OWN : std_logic_vector(47 downto 0) := x"2032" & x"43414D02";
  type cnt_arr is array (0 to 7) of natural;
  signal cnts : cnt_arr := (others => 0);
begin
  clk <= not clk after T/2 when not done_sim;

  dut: entity work.mac25g_rx
    port map (clk=>clk, rst=>rst, in_valid=>iv, in_payload=>ipl, in_is_data=>isd,
              own_mac=>OWN, promisc=>'0',
              m_tdata=>tdata, m_tkeep=>tkeep, m_tlast=>tlast, m_tuser=>tuser,
              m_tvalid=>tvalid,
              ev_ok=>e_ok, ev_bytes=>e_bytes, ev_crc=>e_crc, ev_runt=>e_runt,
              ev_runt0=>e_r0, ev_over=>e_over, ev_abort=>e_ab, ev_abort0=>e_a0,
              ev_filt=>e_filt, ev_proto=>e_proto, link_up=>lnk);

  -- contadores (mismo orden que RX_COUNTERS del oraculo)
  process(clk)
    variable c : cnt_arr;
  begin
    if rising_edge(clk) then
      c := cnts;
      if e_ok = '1' then c(0) := c(0) + 1; c(1) := c(1) + to_integer(e_bytes); end if;
      if e_crc = '1' then c(2) := c(2) + 1; end if;
      if e_runt = '1' then c(3) := c(3) + 1; end if;
      if e_r0 = '1' then c(3) := c(3) + 1; end if;
      if e_over = '1' then c(4) := c(4) + 1; end if;
      if e_ab = '1' then c(5) := c(5) + 1; end if;
      if e_a0 = '1' then c(5) := c(5) + 1; end if;
      if e_filt = '1' then c(6) := c(6) + 1; end if;
      if e_proto = '1' then c(7) := c(7) + 1; end if;
      cnts <= c;
    end if;
  end process;

  feed: process
    file f : text;
    variable l : line;
    variable n, g, d : integer;
    variable p : std_logic_vector(63 downto 0);
  begin
    file_open(f, DIR & "/rx_in.txt", read_mode);
    readline(f, l); read(l, n);
    rst <= '1'; wait for 10*T; wait until rising_edge(clk); rst <= '0';
    for i in 1 to n loop
      readline(f, l); read(l, g); read(l, d); hread(l, p);
      if g = 1 then
        iv <= '0'; wait until rising_edge(clk);
      end if;
      iv <= '1'; ipl <= p;
      if d = 1 then isd <= '1'; else isd <= '0'; end if;
      wait until rising_edge(clk);
    end loop;
    iv <= '0';
    file_close(f);
    feed_done <= true;
    wait;
  end process;

  chk: process
    file f, fc : text;
    variable l : line;
    variable nw, k, errs, last_e, user_e, v : integer := 0;
    variable d_e : std_logic_vector(63 downto 0);
    variable kp_e : std_logic_vector(7 downto 0);
    variable h : unsigned(31 downto 0) := x"811C9DC5";
    type meta_arr is array (0 to 4095) of std_logic_vector(15 downto 0);
    variable meta : meta_arr;
    variable mw : std_logic_vector(15 downto 0);
    variable idle_cyc : natural := 0;
    procedure fnv(b : std_logic_vector(7 downto 0)) is
    begin
      h := h xor resize(unsigned(b), 32);
      h := resize(h * to_unsigned(16777619, 32), 32);
    end procedure;
  begin
    file_open(f, DIR & "/rx_out.txt", read_mode);
    readline(f, l); read(l, nw);
    k := 0;
    while k < nw loop
      wait until rising_edge(clk);
      if feed_done then idle_cyc := idle_cyc + 1; end if;
      assert idle_cyc < 200 report "TIMEOUT: faltan palabras RX (" &
        integer'image(k) & "/" & integer'image(nw) & ")" severity failure;
      if tvalid = '1' then
        readline(f, l); hread(l, d_e); hread(l, kp_e); read(l, last_e); read(l, user_e);
        if tdata /= d_e or tkeep /= kp_e or (tlast = '1') /= (last_e = 1) or
           (tuser = '1') /= (user_e = 1) then
          errs := errs + 1;
          if errs < 8 then
            report "MISMATCH palabra " & integer'image(k) & " got " & to_hstring(tdata) &
              " k=" & to_hstring(tkeep) & " l=" & std_logic'image(tlast) &
              " u=" & std_logic'image(tuser) & " exp " & to_hstring(d_e) &
              " k=" & to_hstring(kp_e) & " l=" & integer'image(last_e) &
              " u=" & integer'image(user_e) severity error;
          end if;
        end if;
        for i in 0 to 7 loop fnv(tdata(8*i+7 downto 8*i)); end loop;
        mw := (others => '0');
        mw(7 downto 0) := tkeep; mw(8) := tlast; mw(9) := tuser;
        meta(k) := mw;
        k := k + 1;
      end if;
    end loop;
    file_close(f);
    for i in 0 to nw - 1 loop
      fnv(meta(i)(7 downto 0)); fnv(meta(i)(15 downto 8));
    end loop;
    -- no debe salir nada mas
    for i in 0 to 100 loop
      wait until rising_edge(clk);
      if tvalid = '1' then
        errs := errs + 1; report "FAIL: palabra RX extra" severity error;
      end if;
    end loop;
    file_open(fc, DIR & "/rx_cnt.txt", read_mode);
    for i in 0 to 7 loop
      readline(fc, l); read(l, v);
      if cnts(i) /= v then
        errs := errs + 1;
        report "FAIL contador " & integer'image(i) & " = " & integer'image(cnts(i)) &
          " esperado " & integer'image(v) severity error;
      end if;
    end loop;
    file_close(fc);
    if lnk /= '1' then
      report "FAIL: link_up no se recupero tras los errores" severity error;
      errs := errs + 1;
    end if;
    if errs = 0 then
      report "LAYER2B_PASS FNV32=0x" & to_hstring(std_logic_vector(h)) &
        " palabras=" & integer'image(nw) & " ok=" & integer'image(cnts(0)) &
        " crc=" & integer'image(cnts(2)) & " runt=" & integer'image(cnts(3)) &
        " over=" & integer'image(cnts(4)) & " abort=" & integer'image(cnts(5)) &
        " filt=" & integer'image(cnts(6)) & " proto=" & integer'image(cnts(7));
    else
      report "LAYER2B_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
