-- tb_eth_rx_l1b.vhd — capa 1b: motor RX MII contra un transmisor bit-bang
-- de nibbles independiente, con corrupciones inyectadas. El transmisor NO
-- reutiliza el motor TX del DUT: emite nibbles a mano y calcula el FCS con
-- una implementacion CRC byte a byte propia (anti modo comun).
--
-- Escenario base (G_MUT=0):
--   t0 unicast propia payload 46     -> aceptar (ev_ok) + vuelco identico
--   t1 broadcast payload 100         -> aceptar
--   t2 unicast propia payload 300    -> aceptar
--   t3 unicast AJENA payload 46      -> descartar (ev_drop) salvo promisc
--   t4 unicast propia payload 1500   -> aceptar (MTU)
--   t5 unicast propia payload 46     -> aceptar
--   d0 FCS corrupto (propia p46)     -> descartar (ev_crc)
--   d1 runt REAL 40 bytes sin padding-> descartar (ev_runt)
--
-- G_MUT (mutaciones sobre lo que ESPERA el oraculo, DEBEN hacer fallar):
--   0 = sin mutacion (PASS)
--   1 = el oraculo espera un byte de datos distinto en t2 -> vuelco no coincide
--   2 = el oraculo espera aceptar la trama de FCS malo    -> ev_ok no llega
--   3 = el oraculo espera aceptar el runt                 -> ev_ok no llega
--   4 = con promisc=1 el oraculo espera descartar t3      -> el RX la acepta
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.eth_pkg.all;

entity tb_eth_rx_l1b is
  generic (G_MUT : integer := 0);
end entity tb_eth_rx_l1b;

architecture sim of tb_eth_rx_l1b is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ce  : std_logic := '0';

  signal macaddr : std_logic_vector(47 downto 0) := x"EEDDCCBBAA02";
  signal promisc : std_logic := '0';

  signal rxd   : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_dv : std_logic := '0';

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last : std_logic;
  signal ev_ok, ev_crc, ev_runt, ev_drop : std_logic;

  type cap_t is array (0 to 8191) of std_logic_vector(7 downto 0);
  signal cap   : cap_t;
  signal cap_n : integer range 0 to 8191 := 0;

  signal got_ok, got_crc, got_runt, got_drop : integer := 0;

  type nat_arr is array (natural range <>) of natural;

  function tbyte(dst_kind : integer; f : natural; i : natural) return std_logic_vector is
    constant MINE  : nat_arr(0 to 5) := (16#02#, 16#AA#, 16#BB#, 16#CC#, 16#DD#, 16#EE#);
    constant OTHER : nat_arr(0 to 5) := (16#02#, 16#99#, 16#88#, 16#77#, 16#66#, 16#55#);
    constant SRC_B : nat_arr(0 to 5) := (16#0A#, 16#0B#, 16#0C#, 16#0D#, 16#0E#, 16#0F#);
    variable b : natural;
  begin
    if i < 6 then
      case dst_kind is
        when 1 => b := 255;
        when 2 => b := OTHER(i);
        when others => b := MINE(i);
      end case;
    elsif i < 12 then
      b := SRC_B(i - 6);
    elsif i = 12 then b := 16#08#;
    elsif i = 13 then b := 16#00#;
    else
      b := (f * 5 + (i - 14) * 3 + 17) mod 256;
    end if;
    return std_logic_vector(to_unsigned(b, 8));
  end function;

  function crc32_byte(crc : std_logic_vector(31 downto 0);
                      b   : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(31 downto 0) := crc;
  begin
    for i in 0 to 7 loop
      if (c(0) xor b(i)) = '1' then
        c := ('0' & c(31 downto 1)) xor x"EDB88320";
      else
        c := '0' & c(31 downto 1);
      end if;
    end loop;
    return c;
  end function;

begin

  clk <= not clk after TCLK / 2;

  process(clk)
    variable c : integer := 0;
  begin
    if rising_edge(clk) then
      if c = 3 then ce <= '1'; c := 0; else ce <= '0'; c := c + 1; end if;
    end if;
  end process;

  dut : entity work.eth_rx_mii
    generic map (G_MAXLEN => 1518)
    port map (
      clk => clk, rst => rst, mii_ce => ce,
      macaddr => macaddr, promisc => promisc,
      rxd => rxd, rx_dv => rx_dv,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      ev_ok => ev_ok, ev_crc => ev_crc, ev_runt => ev_runt, ev_drop => ev_drop);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        if ev_ok   = '1' then got_ok   <= got_ok   + 1; end if;
        if ev_crc  = '1' then got_crc  <= got_crc  + 1; end if;
        if ev_runt = '1' then got_runt <= got_runt + 1; end if;
        if ev_drop = '1' then got_drop <= got_drop + 1; end if;
        if rx_valid = '1' then
          cap(cap_n) <= rx_data;
          cap_n <= cap_n + 1;
        end if;
      end if;
    end if;
  end process;

  process
    variable c   : std_logic_vector(31 downto 0);
    variable fcs : std_logic_vector(31 downto 0);
    variable bd  : std_logic_vector(7 downto 0);

    procedure put_nib(n : std_logic_vector(3 downto 0)) is
    begin
      wait until rising_edge(clk) and ce = '1';
      rxd   <= n;
      rx_dv <= '1';
    end procedure;

    -- pad=true: rellena a 60 bytes de datos. corrupt=1: FCS malo.
    -- expect_ok=true: comparar el vuelco byte a byte.
    procedure send_frame(dst_kind : integer; f : natural; plen : natural;
                         pad : boolean; corrupt : integer; expect_ok : boolean;
                         mut_data : boolean) is
      variable dlen : natural := 14 + plen;
      variable exp_before : integer;
      variable bytes : cap_t;
    begin
      exp_before := got_ok;
      if pad and dlen < 60 then dlen := 60; end if;
      c := CRC32_INIT;
      for i in 0 to dlen - 1 loop
        if i < 14 + plen then bd := tbyte(dst_kind, f, i); else bd := x"00"; end if;
        bytes(i) := bd;
        c := crc32_byte(c, bd);
      end loop;
      fcs := not c;
      if corrupt = 1 then fcs := fcs xor x"00000100"; end if;
      for k in 0 to 6 loop
        put_nib(x"5"); put_nib(x"5");
      end loop;
      put_nib(x"5"); put_nib(x"D");
      for i in 0 to dlen - 1 loop
        put_nib(bytes(i)(3 downto 0));
        put_nib(bytes(i)(7 downto 4));
      end loop;
      for k in 0 to 3 loop
        bd := fcs(k*8+7 downto k*8);
        put_nib(bd(3 downto 0));
        put_nib(bd(7 downto 4));
      end loop;
      wait until rising_edge(clk) and ce = '1';
      rx_dv <= '0';
      rxd   <= x"0";
      for k in 0 to 30 loop
        wait until rising_edge(clk) and ce = '1';
      end loop;
      if expect_ok then
        for w in 0 to 4000 loop
          exit when got_ok /= exp_before;
          wait until rising_edge(clk);
        end loop;
        assert got_ok /= exp_before
          report "L1B: se esperaba aceptar la trama f=" & integer'image(f) &
                 " pero no llego ev_ok" severity failure;
        wait until rising_edge(clk);
        for i in 0 to 14 + plen - 1 loop
          bd := tbyte(dst_kind, f, i);
          if mut_data and i = 20 then bd := bd xor x"01"; end if;
          assert cap(cap_n - (14 + plen) + i) = bd
            report "L1B: byte " & integer'image(i) & " del vuelco de f=" &
                   integer'image(f) & " no coincide"
            severity failure;
        end loop;
      end if;
    end procedure;

  begin
    rst <= '1';
    if G_MUT = 4 then promisc <= '1'; else promisc <= '0'; end if;
    wait for 20 * TCLK;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 4 * TCLK;

    send_frame(0, 0, 46,   true,  0, true,           false);
    send_frame(1, 1, 100,  true,  0, true,           false);
    send_frame(0, 2, 300,  true,  0, true,           (G_MUT = 1));
    send_frame(2, 3, 46,   true,  0, (promisc = '1'), false);
    send_frame(0, 4, 1500, true,  0, true,           false);
    send_frame(0, 5, 46,   true,  0, true,           false);
    send_frame(0, 6, 46,   true,  1, (G_MUT = 2),    false);  -- FCS malo
    send_frame(0, 7, 26,   false, 0, (G_MUT = 3),    false);  -- runt real: 40 bytes con FCS

    wait for 300 * TCLK;

    report "L1B: got_ok=" & integer'image(got_ok) &
           " got_crc=" & integer'image(got_crc) &
           " got_runt=" & integer'image(got_runt) &
           " got_drop=" & integer'image(got_drop);

    if G_MUT = 0 then
      assert got_ok = 5
        report "L1B: got_ok=" & integer'image(got_ok) & " (esperado 5)" severity failure;
      assert got_crc = 1
        report "L1B: got_crc=" & integer'image(got_crc) & " (esperado 1)" severity failure;
      assert got_runt = 1
        report "L1B: got_runt=" & integer'image(got_runt) & " (esperado 1)" severity failure;
      assert got_drop = 1
        report "L1B: got_drop=" & integer'image(got_drop) & " (esperado 1)" severity failure;
      report "L1B RX PASS: 5 aceptadas, 1 FCS, 1 runt, 1 filtrada";
    end if;
    if G_MUT = 4 then
      -- promisc: t3 debe aceptarse -> 7 ok, 0 drop; el oraculo esperaba drop
      assert got_drop = 1
        report "L1B: con promisc el RX no filtro t3 (got_drop=" &
               integer'image(got_drop) & ")" severity failure;
    end if;
    finish;
  end process;

  process
  begin
    wait for 3 ms;
    assert false report "L1B: timeout de simulacion" severity failure;
    wait;
  end process;

end architecture sim;
