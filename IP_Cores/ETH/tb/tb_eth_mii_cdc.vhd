-- tb_eth_mii_cdc.vhd - eth_mac in external-PHY mode with asynchronous clocks
-- ---------------------------------------------------------------------------
-- Audit 2026-11 (ALTA, eth_mac external MII had no CDC). Self-checking.
--   core clock 100 MHz; PHY TX_CLK and RX_CLK independent, default
--   25 MHz -100 ppm / +100 ppm (generics), full duplex, many frames.
-- TX: a byte feeder drives the MAC; an independent monitor samples
--     TXD/TX_EN on TX_CLK rising edges (as a PHY would), rebuilds every
--     frame, and checks preamble (15x5 + D), byte content, padding, FCS
--     (bitwise CRC independent from the RTL) and IPG >= 24 nibbles.
--     -> proves no nibble lost / duplicated across the core->TX_CLK FIFO.
-- RX: a PHY model drives RXD/RX_DV from RX_CLK (changes on falling edge,
--     sampled by the MAC on rising edge): good frames, bad-FCS frames,
--     runts and oversize (> 1518) frames. The delivered byte stream must
--     equal the good frames exactly, in order; error events must match.
-- Timestamps: for every frame the latency between the wire SFD instant
--     (TX: launch edge of the 'D' nibble; RX: RX_CLK edge that samples it)
--     and the core-domain tx_sfd_pulse / rx_sfd_pulse is measured. The
--     spread (max-min) must be <= 1 core clock (10 ns) -> timestamps are
--     deterministic to one core clock; min/max are reported for TX_LAT/RX_LAT.
-- On the OLD eth_mac this TB does not elaborate (no PHY clock ports): the
-- old design sampled RXD with the internal 25 MHz enable, i.e. no CDC.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_eth_mii_cdc is
  generic (
    G_TXCLK_PS : integer := 40004;    -- 25 MHz - 100 ppm
    G_RXCLK_PS : integer := 39996;    -- 25 MHz + 100 ppm
    G_NTX      : integer := 40;
    G_NRX      : integer := 48
  );
end entity;

architecture sim of tb_eth_mii_cdc is
  constant TCLK : time := 10 ns;
  constant TTX  : time := G_TXCLK_PS * 1 ps;
  constant TRX  : time := G_RXCLK_PS * 1 ps;

  signal clk, txc, rxc : std_logic := '0';
  signal rst : std_logic := '1';

  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid, tx_last : std_logic := '0';
  signal tx_ready, tx_busy, tx_underrun : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last, ev_ok, ev_crc, ev_runt, ev_drop, ev_ovs : std_logic;
  signal ovf, unf : std_logic;
  signal mii_txd, mii_rxd : std_logic_vector(3 downto 0) := (others => '0');
  signal mii_tx_en, mii_rx_dv : std_logic := '0';
  signal tx_sfd, rx_sfd : std_logic;

  type time_arr is array (natural range <>) of time;
  signal tx_wire_t, tx_pulse_t : time_arr(0 to G_NTX-1) := (others => 0 ns);
  signal rx_wire_t, rx_pulse_t : time_arr(0 to G_NRX-1) := (others => 0 ns);
  signal tx_mon_done, rx_chk_done, rx_drv_done : boolean := false;
  signal n_txp, n_rxp : integer := 0;
  signal n_good_exp, n_crc_got, n_runt_got, n_ovs_got, n_ok_got : integer := 0;
  signal ovf_seen, unf_seen : boolean := false;

  -- frame descriptors (deterministic pseudo-random)
  function tx_len(f : natural) return natural is
  begin
    case f mod 8 is
      when 0 => return 60;
      when 1 => return 61 + (f * 37) mod 40;
      when 2 => return 1514;
      when 3 => return 45;                          -- padded to 60
      when 4 => return 200 + (f * 101) mod 300;
      when 5 => return 64;
      when 6 => return 120 + (f * 53) mod 90;
      when others => return 1 + (f * 7) mod 59;     -- short, padded
    end case;
  end function;
  -- RX kinds: 0 good, 1 bad FCS, 2 runt, 3 oversize
  function rx_kind(k : natural) return natural is
  begin
    case k mod 12 is
      when 3 => return 1;
      when 7 => return 2;
      when 10 => return 3;
      when others => return 0;
    end case;
  end function;
  function rx_len(k : natural) return natural is     -- data bytes (no FCS)
  begin
    case rx_kind(k) is
      when 2 => return 30;
      when 3 => return 1515 + (k mod 3) * 300;        -- 1519..2119 with FCS
      when others =>
        case k mod 5 is
          when 0 => return 60;
          when 1 => return 1514;
          when 2 => return 61 + (k * 29) mod 200;
          when 3 => return 100;
          when others => return 64 + (k * 11) mod 64;
        end case;
    end case;
  end function;
  function fbyte(seed, i : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned((seed * 29 + i * 13 + 7 + (i / 256)) mod 256, 8));
  end function;

  -- bitwise CRC-32 (independent from the RTL nibble implementation)
  function crc_upd(c : std_logic_vector(31 downto 0); b : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := c;
  begin
    for k in 0 to 7 loop
      if (v(0) xor b(k)) = '1' then
        v := ('0' & v(31 downto 1)) xor x"EDB88320";
      else
        v := '0' & v(31 downto 1);
      end if;
    end loop;
    return v;
  end function;
begin
  clk <= not clk after TCLK / 2;
  txc <= not txc after TTX / 2;
  rxc <= not rxc after TRX / 2;

  dut : entity work.eth_mac
    generic map (G_MAXLEN => 1518)
    port map (
      clk => clk, rst => rst, loopback => '0',
      macaddr => x"000000000000", promisc => '1',
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready, tx_busy => tx_busy, tx_underrun => tx_underrun,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      rx_ev_ok => ev_ok, rx_ev_crc => ev_crc, rx_ev_runt => ev_runt,
      rx_ev_drop => ev_drop, rx_ev_oversize => ev_ovs,
      rx_dbg_dst => open, rx_dbg_nb => open,
      phy_rx_ovf => ovf, phy_tx_unf => unf,
      mii_rx_clk => rxc, mii_tx_clk => txc,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv,
      tx_sfd_pulse => tx_sfd, rx_sfd_pulse => rx_sfd);

  p_rst : process
  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait;
  end process;

  -- ------------------------------------------------ TX feeder (core domain)
  p_feed : process
    variable i : integer;
  begin
    wait until rst = '0';
    wait for 1 us;                                   -- let the PHY domains start
    for f in 0 to G_NTX-1 loop
      -- FWFT source: byte i is valid until the engine consumes it (tx_ready)
      wait until rising_edge(clk);
      i := 0;
      tx_data <= fbyte(f, 0); tx_valid <= '1';
      if tx_len(f) = 1 then tx_last <= '1'; else tx_last <= '0'; end if;
      loop
        wait until rising_edge(clk);
        if tx_ready = '1' then
          i := i + 1;
          exit when i = tx_len(f);
          tx_data <= fbyte(f, i);
          if i = tx_len(f) - 1 then tx_last <= '1'; else tx_last <= '0'; end if;
        end if;
      end loop;
      tx_valid <= '0'; tx_last <= '0';
      -- next frame only once the engine is idle (store-and-forward source)
      loop
        wait until rising_edge(clk);
        exit when tx_busy = '0';
      end loop;
    end loop;
    wait;
  end process;

  -- ------------------------------------------------ TX monitor (TX_CLK, PHY view)
  p_txmon : process
    type st_t is (M_IDLE, M_PRE, M_DATA);
    variable st     : st_t := M_IDLE;
    variable npre   : integer := 0;
    variable nib    : integer := 0;
    variable lo     : std_logic_vector(3 downto 0);
    variable bytes  : integer := 0;
    variable crc    : std_logic_vector(31 downto 0);
    type buf_t is array (0 to 4095) of std_logic_vector(7 downto 0);
    variable buf    : buf_t;
    variable f      : integer := 0;
    variable idle_n : integer := 1000;
    variable explen, plen : integer;
    variable b      : std_logic_vector(7 downto 0);
  begin
    wait until rising_edge(txc);
    if mii_tx_en = '1' then
      case st is
        when M_IDLE =>
          assert idle_n >= 24
            report "TX: IPG of only " & integer'image(idle_n) & " nibbles before frame " &
                   integer'image(f) severity failure;
          assert mii_txd = x"5" report "TX: first nibble is not preamble" severity failure;
          npre := 1; st := M_PRE;
        when M_PRE =>
          if mii_txd = x"5" then
            npre := npre + 1;
          else
            assert mii_txd = x"D" report "TX: bad SFD nibble" severity failure;
            assert npre = 15
              report "TX: preamble has " & integer'image(npre) & " nibbles (15 expected), frame "
                     & integer'image(f) severity failure;
            -- SFD launched one TX_CLK before this sampling edge
            tx_wire_t(f) <= now - TTX;
            st := M_DATA; nib := 0; bytes := 0; crc := x"FFFFFFFF";
          end if;
        when M_DATA =>
          if nib = 0 then
            lo := mii_txd; nib := 1;
          else
            b := mii_txd & lo;
            buf(bytes) := b;
            bytes := bytes + 1; nib := 0;
          end if;
      end case;
      idle_n := 0;
    else
      if st = M_DATA then
        -- end of frame: check
        assert nib = 0 report "TX: odd nibble count in frame " & integer'image(f) severity failure;
        explen := tx_len(f);
        if explen < 60 then plen := 60; else plen := explen; end if;
        assert bytes = plen + 4
          report "TX: frame " & integer'image(f) & " has " & integer'image(bytes) &
                 " bytes, expected " & integer'image(plen + 4) severity failure;
        crc := x"FFFFFFFF";
        for i in 0 to bytes - 1 loop
          crc := crc_upd(crc, buf(i));
          if i < explen then
            assert buf(i) = fbyte(f, i)
              report "TX: frame " & integer'image(f) & " byte " & integer'image(i) & " corrupted"
              severity failure;
          elsif i < plen then
            assert buf(i) = x"00" report "TX: bad padding byte" severity failure;
          end if;
        end loop;
        assert crc = x"DEBB20E3"
          report "TX: bad FCS on frame " & integer'image(f) severity failure;
        f := f + 1;
        if f = G_NTX then
          tx_mon_done <= true;
        end if;
      end if;
      assert st /= M_PRE report "TX: TX_EN dropped inside preamble" severity failure;
      st := M_IDLE;
      if idle_n < 100000 then idle_n := idle_n + 1; end if;
    end if;
  end process;

  -- ------------------------------------------------ RX PHY model (RX_CLK)
  p_rxdrv : process
    variable crc : std_logic_vector(31 downto 0);
    variable b   : std_logic_vector(7 downto 0);
    variable fcs : std_logic_vector(31 downto 0);
    variable ln  : integer;
    variable ngood : integer := 0;
    procedure nib(n : std_logic_vector(3 downto 0); dv : std_logic) is
    begin
      wait until falling_edge(rxc);
      mii_rxd <= n; mii_rx_dv <= dv;
    end procedure;
  begin
    wait until rst = '0';
    wait for 1.5 us;
    for k in 0 to G_NRX-1 loop
      for i in 1 to 15 loop nib(x"5", '1'); end loop;
      nib(x"D", '1');
      -- the MAC samples this nibble on the next RX_CLK rising edge
      rx_wire_t(k) <= now + TRX / 2;
      ln := rx_len(k);
      crc := x"FFFFFFFF";
      for i in 0 to ln - 1 loop
        b := fbyte(k + 1000, i);
        crc := crc_upd(crc, b);
        nib(b(3 downto 0), '1');
        nib(b(7 downto 4), '1');
      end loop;
      fcs := not crc;
      if rx_kind(k) = 1 then fcs(5) := not fcs(5); end if;   -- corrupt FCS
      for i in 0 to 7 loop
        nib(fcs(i*4+3 downto i*4), '1');
      end loop;
      for i in 1 to 24 loop nib(x"0", '0'); end loop;          -- IPG
      if rx_kind(k) = 0 then ngood := ngood + 1; end if;
      n_good_exp <= ngood;
    end loop;
    rx_drv_done <= true;
    wait;
  end process;

  -- ------------------------------------------------ RX checker (core domain)
  p_rxchk : process
    variable k : integer := 0;     -- index of the next good frame expected
    variable i : integer := 0;
  begin
    wait until rising_edge(clk);
    if rx_valid = '1' then
      while k < G_NRX and rx_kind(k) /= 0 loop k := k + 1; end loop;
      assert k < G_NRX report "RX: more frames delivered than sent" severity failure;
      assert rx_data = fbyte(k + 1000, i)
        report "RX: frame " & integer'image(k) & " byte " & integer'image(i) &
               " mismatch got=" & to_hstring(rx_data) & " exp=" & to_hstring(fbyte(k + 1000, i))
        severity failure;
      if rx_last = '1' then
        assert i = rx_len(k) - 1
          report "RX: frame " & integer'image(k) & " delivered " & integer'image(i + 1) &
                 " bytes, expected " & integer'image(rx_len(k)) severity failure;
        i := 0; k := k + 1;
      else
        i := i + 1;
      end if;
    end if;
  end process;

  p_events : process
  begin
    wait until rising_edge(clk);
    if ev_ok = '1'  then n_ok_got   <= n_ok_got + 1;   end if;
    if ev_crc = '1' then n_crc_got  <= n_crc_got + 1;  end if;
    if ev_runt = '1' then n_runt_got <= n_runt_got + 1; end if;
    if ev_ovs = '1' then n_ovs_got  <= n_ovs_got + 1;  end if;
    if ovf = '1' then ovf_seen <= true; end if;
    if unf = '1' then unf_seen <= true; end if;
    if tx_underrun = '1' then
      assert false report "TX: engine underrun" severity failure;
    end if;
    if tx_sfd = '1' then
      if n_txp < G_NTX then tx_pulse_t(n_txp) <= now; end if;
      n_txp <= n_txp + 1;
    end if;
    if rx_sfd = '1' then
      if n_rxp < G_NRX then rx_pulse_t(n_rxp) <= now; end if;
      n_rxp <= n_rxp + 1;
    end if;
  end process;

  -- ------------------------------------------------ final checks
  p_final : process
    variable mn, mx, d : time;
    variable nbad, nrunt, novs : integer := 0;
  begin
    wait until tx_mon_done and rx_drv_done;
    wait for 20 us;
    for k in 0 to G_NRX-1 loop
      case rx_kind(k) is
        when 1 => nbad := nbad + 1;
        when 2 => nrunt := nrunt + 1;
        when 3 => novs := novs + 1;
        when others => null;
      end case;
    end loop;
    assert n_ok_got = n_good_exp
      report "RX: " & integer'image(n_ok_got) & " good frames, expected " &
             integer'image(n_good_exp) severity failure;
    assert n_crc_got = nbad report "RX: bad-FCS count mismatch" severity failure;
    assert n_runt_got = nrunt report "RX: runt count mismatch" severity failure;
    assert n_ovs_got = novs
      report "RX: oversize count " & integer'image(n_ovs_got) & " expected " &
             integer'image(novs) severity failure;
    assert not ovf_seen report "CDC: RX FIFO overflow" severity failure;
    assert not unf_seen report "CDC: TX FIFO underflow" severity failure;
    assert n_txp = G_NTX report "TS: TX SFD pulse count " & integer'image(n_txp) severity failure;
    assert n_rxp = G_NRX report "TS: RX SFD pulse count " & integer'image(n_rxp) severity failure;

    mn := 1 sec; mx := 0 ns;
    for f in 0 to G_NTX-1 loop
      d := tx_pulse_t(f) - tx_wire_t(f);
      if d < mn then mn := d; end if;
      if d > mx then mx := d; end if;
    end loop;
    report "TS TX: wire SFD -> tx_sfd_pulse latency min=" & time'image(mn) &
           " max=" & time'image(mx);
    assert mx - mn <= TCLK
      report "TS TX: latency spread exceeds one core clock" severity failure;
    assert mn > 0 ns report "TS TX: pulse before wire SFD" severity failure;

    mn := 1 sec; mx := 0 ns;
    for k in 0 to G_NRX-1 loop
      d := rx_pulse_t(k) - rx_wire_t(k);
      if d < mn then mn := d; end if;
      if d > mx then mx := d; end if;
    end loop;
    report "TS RX: wire SFD -> rx_sfd_pulse latency min=" & time'image(mn) &
           " max=" & time'image(mx);
    assert mx - mn <= TCLK
      report "TS RX: latency spread exceeds one core clock" severity failure;

    report "TB_ETH_MII_CDC PASS: " & integer'image(G_NTX) & " TX frames, " &
           integer'image(G_NRX) & " RX frames, async PHY clocks, timestamps within 1 core clock";
    finish;
  end process;

  p_wd : process
  begin
    wait for 20 ms;
    assert false report "TB_ETH_MII_CDC: timeout" severity failure;
    wait;
  end process;
end architecture;
