-- tb_tsn_ext.vhd - TSN switch over REAL MII (rx_src="00"), async PHY clocks
-- ---------------------------------------------------------------------------
-- Audit 2026-11 (ALTA: external-PHY mode had no CDC) + TSN timestamp hooks.
-- Self-checking. Every port has its own RX_CLK and TX_CLK (25 MHz +/-40..100
-- ppm, all different, unrelated to the 100 MHz core). The TB drives raw MII
-- nibbles on RX (like a PHY) and decodes TXD/TX_EN of every port on its
-- TX_CLK, independently of the datapath.
--   * port 0 -> MAC(1): 6 frames of 60..1514 B, port 2 -> MAC(3): 5 frames,
--     port 0 broadcast (flooded to 1,2,3), port 0 1600-byte frame (> 1522:
--     must be dropped, DROP_FCS(0)++, ERR_STICKY[0] set);
--   * every output frame: valid FCS, exact content, per-source order, and the
--     exact expected set per output port (no loss, no duplicate);
--   * PTP hooks: rx_sfd(i) / tx_sfd(i) pulse once per frame received /
--     transmitted on each port.
-- On the v1 tsn_top this TB does not elaborate (no PHY clock ports, no SFD
-- hooks); v1 sampled the PHY pins with the internal 25 MHz enable.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.tsn_pkg.all;

entity tb_tsn_ext is
end entity;

architecture sim of tb_tsn_ext is
  type int4 is array (0 to 3) of integer;
  constant TXP : int4 := (40004, 39997, 40002, 39996);   -- ps
  constant RXP : int4 := (39996, 40003, 39998, 40001);
  constant N0 : integer := 6;
  constant N2 : integer := 5;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(8 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;
  signal mii_txd, mii_rxd : byte_arr4 := (others => (others => '0'));
  signal mii_tx_en, mii_rx_dv : std_logic_vector(3 downto 0) := (others => '0');
  signal txc, rxc : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_sfd, tx_sfd : std_logic_vector(3 downto 0);
  signal n_rxsfd, n_txsfd, n_out : int4 := (others => 0);
  signal tbl_ready : boolean := false;
  signal drv_done : std_logic_vector(3 downto 0) := "1010";   -- ports 1,3 idle

  function mac_of(p : integer) return std_logic_vector is
  begin return std_logic_vector(unsigned'(x"020000000001") + p); end;
  -- frame plan: (src, seq) -> destination MAC and data length
  function f_len(src, seq : integer) return integer is
  begin
    if src = 0 and seq = N0 then return 80; end if;      -- broadcast
    if src = 0 and seq = N0 + 1 then return 1600; end if; -- oversize
    case (seq + src) mod 4 is
      when 0 => return 60;
      when 1 => return 1514;
      when 2 => return 61 + seq * 37;
      when others => return 300;
    end case;
  end function;
  function f_dst(src, seq : integer) return std_logic_vector is
  begin
    if src = 0 and seq = N0 then return x"FFFFFFFFFFFF"; end if;
    if src = 0 then return mac_of(1); else return mac_of(3); end if;
  end function;
  function f_byte(src, seq, i : integer) return std_logic_vector is
    variable d : std_logic_vector(47 downto 0);
  begin
    d := f_dst(src, seq);
    if i < 6 then return d(47 - 8*i downto 40 - 8*i); end if;   -- wire byte0 = [47:40]
    if i < 12 then return std_logic_vector(to_unsigned(16#10# + src, 8)); end if;
    if i = 12 then return x"08"; end if;
    if i = 13 then return x"00"; end if;
    if i = 14 then return std_logic_vector(to_unsigned(src, 8)); end if;
    if i = 15 then return std_logic_vector(to_unsigned(seq, 8)); end if;
    return std_logic_vector(to_unsigned((src * 31 + seq * 17 + i * 5) mod 256, 8));
  end function;
  function crc_upd(c : std_logic_vector(31 downto 0); b : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := c;
  begin
    for k in 0 to 7 loop
      if (v(0) xor b(k)) = '1' then v := ('0' & v(31 downto 1)) xor x"EDB88320";
      else v := '0' & v(31 downto 1); end if;
    end loop;
    return v;
  end function;
begin
  clk <= not clk after 5 ns;
  g_clk : for i in 0 to 3 generate
    txc(i) <= not txc(i) after (TXP(i) * 1 ps) / 2;
    rxc(i) <= not rxc(i) after (RXP(i) * 1 ps) / 2;
  end generate;

  p_ce : process(clk)
    variable d : integer := 0;
  begin
    if rising_edge(clk) then
      if d = 3 then mii_ce <= '1'; d := 0; else mii_ce <= '0'; d := d + 1; end if;
    end if;
  end process;

  dut : entity work.tsn_top
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq, rx_src => "00",
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv,
      mii_rx_clk => rxc, mii_tx_clk => txc,
      rx_sfd => rx_sfd, tx_sfd => tx_sfd);

  p_hooks : process(clk)
  begin
    if rising_edge(clk) then
      for i in 0 to 3 loop
        if rx_sfd(i) = '1' then n_rxsfd(i) <= n_rxsfd(i) + 1; end if;
        if tx_sfd(i) = '1' then n_txsfd(i) <= n_txsfd(i) + 1; end if;
      end loop;
    end if;
  end process;

  -- RX drivers (PHY model, change on RX_CLK falling edge)
  g_drv : for p in 0 to 3 generate
    p_drv : process
      variable crc, fcs : std_logic_vector(31 downto 0);
      variable b : std_logic_vector(7 downto 0);
      variable nfr : integer;
      procedure nib(n : std_logic_vector(3 downto 0); v : std_logic) is
      begin
        wait until falling_edge(rxc(p));
        mii_rxd(p) <= "0000" & n; mii_rx_dv(p) <= v;
      end procedure;
    begin
      if p = 1 or p = 3 then wait; end if;
      if p = 0 then nfr := N0 + 2; else nfr := N2; end if;
      wait until tbl_ready;
      for seq in 0 to nfr - 1 loop
        for i in 1 to 15 loop nib(x"5", '1'); end loop;
        nib(x"D", '1');
        crc := x"FFFFFFFF";
        for i in 0 to f_len(p, seq) - 1 loop
          b := f_byte(p, seq, i); crc := crc_upd(crc, b);
          nib(b(3 downto 0), '1'); nib(b(7 downto 4), '1');
        end loop;
        fcs := not crc;
        for i in 0 to 7 loop nib(fcs(i*4+3 downto i*4), '1'); end loop;
        for i in 1 to 24 loop nib(x"0", '0'); end loop;
      end loop;
      drv_done(p) <= '1';
      wait;
    end process;
  end generate;

  -- TX monitors (PHY view, sample on TX_CLK rising edge)
  g_mon : for o in 0 to 3 generate
    p_mon : process
      type buf_t is array (0 to 2047) of std_logic_vector(7 downto 0);
      variable buf : buf_t;
      variable pre, inf : boolean := false;
      variable npre, nib, nb, src, seq, L : integer := 0;
      variable lo : std_logic_vector(3 downto 0);
      variable crc : std_logic_vector(31 downto 0);
      variable last_seq : int4 := (others => -1);
    begin
      wait until rising_edge(txc(o));
      if mii_tx_en(o) = '1' then
        if not pre and not inf then
          assert mii_txd(o)(3 downto 0) = x"5" report "MON: no preamble" severity failure;
          pre := true; npre := 1;
        elsif pre then
          if mii_txd(o)(3 downto 0) = x"5" then npre := npre + 1;
          else
            assert mii_txd(o)(3 downto 0) = x"D" and npre = 15
              report "MON: bad preamble/SFD on port " & integer'image(o) severity failure;
            pre := false; inf := true; nib := 0; nb := 0;
          end if;
        else
          if nib = 0 then lo := mii_txd(o)(3 downto 0); nib := 1;
          else buf(nb) := mii_txd(o)(3 downto 0) & lo; nb := nb + 1; nib := 0; end if;
        end if;
      else
        assert not pre report "MON: TX_EN dropped in preamble" severity failure;
        if inf then
          assert nib = 0 report "MON: odd nibbles" severity failure;
          crc := x"FFFFFFFF";
          for i in 0 to nb - 1 loop crc := crc_upd(crc, buf(i)); end loop;
          assert crc = x"DEBB20E3"
            report "MON: bad FCS on output port " & integer'image(o) severity failure;
          src := to_integer(unsigned(buf(14)));
          seq := to_integer(unsigned(buf(15)));
          assert src = 0 or src = 2 report "MON: unknown source" severity failure;
          L := f_len(src, seq);
          assert nb = L + 4
            report "MON: port " & integer'image(o) & " frame " & integer'image(src) & "/" &
                   integer'image(seq) & " length " & integer'image(nb) severity failure;
          for i in 0 to L - 1 loop
            assert buf(i) = f_byte(src, seq, i)
              report "MON: port " & integer'image(o) & " frame " & integer'image(src) & "/" &
                     integer'image(seq) & " byte " & integer'image(i) & " corrupted"
              severity failure;
          end loop;
          assert seq > last_seq(src) report "MON: duplicate / reordered frame" severity failure;
          last_seq(src) := seq;
          n_out(o) <= n_out(o) + 1;
        end if;
        inf := false;
      end if;
    end process;
  end generate;

  p_main : process
    variable v : std_logic_vector(31 downto 0);
    procedure wr32(a : std_logic_vector(8 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk); sel <= '0'; we <= '0';
    end procedure;
    procedure rd32(a : std_logic_vector(8 downto 0); o : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns; o := rdata;
      wait until rising_edge(clk); sel <= '0';
    end procedure;
  begin
    wait for 100 ns; wait until rising_edge(clk); rst <= '0';
    wait for 1 us;
    wr32(9x"000", x"00000001");
    for p in 0 to 3 loop
      wr32(9x"008", mac_of(p)(31 downto 0));
      wr32(9x"00C", '1' & "0000000000000" & std_logic_vector(to_unsigned(p, 2)) &
                    mac_of(p)(47 downto 32));
      wr32(9x"010", std_logic_vector(to_unsigned(p, 32)));
    end loop;
    tbl_ready <= true;
    wait until drv_done = "1111";
    wait for 300 us;                                  -- let the egress drain
    -- exact delivery set: p1 = 6 unicast + bcast, p3 = 5 + bcast, p2 = bcast
    assert n_out(0) = 0 and n_out(1) = N0 + 1 and n_out(2) = 1 and n_out(3) = N2 + 1
      report "DELIVERY: out frames p0..p3 = " & integer'image(n_out(0)) & "," &
             integer'image(n_out(1)) & "," & integer'image(n_out(2)) & "," &
             integer'image(n_out(3)) severity failure;
    -- PTP hooks
    assert n_rxsfd(0) = N0 + 2 and n_rxsfd(2) = N2 and n_rxsfd(1) = 0 and n_rxsfd(3) = 0
      report "HOOK: rx_sfd pulse counts wrong" severity failure;
    for o in 0 to 3 loop
      assert n_txsfd(o) = n_out(o)
        report "HOOK: tx_sfd(" & integer'image(o) & ") = " & integer'image(n_txsfd(o)) &
               " for " & integer'image(n_out(o)) & " frames" severity failure;
    end loop;
    -- counters / stickies
    rd32(9x"040", v);
    assert to_integer(unsigned(v)) = N0 + 1 report "RX_CNT p0 wrong" severity failure;
    rd32(9x"048", v);
    assert to_integer(unsigned(v)) = N2 report "RX_CNT p2 wrong" severity failure;
    rd32(9x"070", v);
    assert to_integer(unsigned(v)) = 1 report "DROP_FCS p0 (oversize) wrong" severity failure;
    rd32(9x"0C4", v);
    assert v(0) = '1' and v(2) = '0' and v(7 downto 4) = "0000"
      report "ERR_STICKY = " & to_hstring(v) severity failure;
    wr32(9x"0C4", x"00000001");
    rd32(9x"0C4", v);
    assert v(0) = '0' report "ERR_STICKY not W1C" severity failure;
    report "TB_TSN_EXT PASS (4 async PHY clock pairs, no loss/dup, SFD hooks, oversize drop)";
    finish;
  end process;

  p_wd : process
  begin
    wait for 8 ms;
    assert false report "TB_TSN_EXT: timeout" severity failure;
    wait;
  end process;
end architecture;
