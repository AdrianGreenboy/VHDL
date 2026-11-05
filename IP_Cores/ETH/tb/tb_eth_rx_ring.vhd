-- tb_eth_rx_ring.vhd - eth_rx_mii max-length + back-to-back drain regression
-- ---------------------------------------------------------------------------
-- Audit 2026-11. Self-checking (assert severity failure), core-domain only,
-- nibbles bit-banged on the internal /4 enable.
--   T1 long (1514 B) frame immediately followed (min IPG) by a 60 B frame:
--      both must be delivered intact. v1 restarted the drain at index 0 when
--      the short frame completed and corrupted the long one.
--   T2 1519 B (data+FCS) frame -> ev_oversize, nothing delivered.
--   T3 5000 B frame (> 4095: v1 counter overflow) -> ev_oversize only.
--   T4 exactly 1518 B (1514 + FCS) -> accepted and delivered.
--   T5 a normal frame after the oversize ones is delivered intact
--      (oversize frames do not leave garbage in the buffer).
-- Old code: T1 fails (corrupted byte), T2/T3 fail (frame accepted/truncated
-- or range overflow). Run against the v1 logic in AUDIT_FIXES.md.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_eth_rx_ring is
end entity;

architecture sim of tb_eth_rx_ring is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ce  : std_logic := '0';
  signal cdiv : integer range 0 to 3 := 0;
  signal rxd : std_logic_vector(3 downto 0) := (others => '0');
  signal dv  : std_logic := '0';
  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last, ev_ok, ev_crc, ev_runt, ev_drop, ev_ovs : std_logic;

  -- expected delivery script: frame ids that must be delivered, in order
  type int_arr is array (natural range <>) of integer;
  constant DELIV_ID  : int_arr(0 to 3) := (1, 2, 5, 6);
  constant DELIV_LEN : int_arr(0 to 3) := (1514, 60, 1514, 70);
  signal n_ok, n_ovs, n_other : integer := 0;
  signal nfr_done : integer := 0;

  function fb(id, i : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned((id * 41 + i * 7 + i / 256 + 3) mod 256, 8));
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
  clk <= not clk after TCLK / 2;

  p_ce : process(clk)
  begin
    if rising_edge(clk) then
      if cdiv = 3 then cdiv <= 0; ce <= '1'; else cdiv <= cdiv + 1; ce <= '0'; end if;
    end if;
  end process;

  dut : entity work.eth_rx_mii
    generic map (G_MAXLEN => 1518)
    port map (clk => clk, rst => rst, mii_ce => ce,
              macaddr => x"000000000000", promisc => '1',
              rxd => rxd, rx_dv => dv,
              rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
              ev_ok => ev_ok, ev_crc => ev_crc, ev_runt => ev_runt, ev_drop => ev_drop,
              ev_oversize => ev_ovs, rx_sfd_pulse => open, dbg_dst => open, dbg_nb => open);

  p_drv : process
    variable crc : std_logic_vector(31 downto 0);
    variable b   : std_logic_vector(7 downto 0);
    variable fcs : std_logic_vector(31 downto 0);
    procedure nib(n : std_logic_vector(3 downto 0); v : std_logic) is
    begin
      loop
        wait until rising_edge(clk);
        exit when ce = '1';
      end loop;
      rxd <= n; dv <= v;
    end procedure;
    procedure frame(id, ln : natural) is      -- ln = data bytes (FCS added)
    begin
      for i in 1 to 15 loop nib(x"5", '1'); end loop;
      nib(x"D", '1');
      crc := x"FFFFFFFF";
      for i in 0 to ln - 1 loop
        b := fb(id, i); crc := crc_upd(crc, b);
        nib(b(3 downto 0), '1'); nib(b(7 downto 4), '1');
      end loop;
      fcs := not crc;
      for i in 0 to 7 loop nib(fcs(i*4+3 downto i*4), '1'); end loop;
      for i in 1 to 24 loop nib(x"0", '0'); end loop;        -- minimum IPG
    end procedure;
  begin
    rst <= '1'; wait for 100 ns; wait until rising_edge(clk); rst <= '0';
    wait for 200 ns;
    frame(1, 1514);        -- T1 long (1518 with FCS = exactly G_MAXLEN: T4 too)
    frame(2, 60);          -- T1 short right behind it
    frame(3, 1515);        -- T2 1519 with FCS -> oversize
    frame(4, 4996);        -- T3 5000 with FCS -> oversize, no counter wrap
    frame(5, 1514);        -- T4 again, after oversize frames
    frame(6, 70);          -- T5
    wait for 40 us;
    assert n_ok = 4
      report "RX ring: " & integer'image(n_ok) & " frames delivered, 4 expected" severity failure;
    assert n_ovs = 2
      report "RX ring: " & integer'image(n_ovs) & " oversize events, 2 expected" severity failure;
    assert n_other = 0 report "RX ring: unexpected crc/runt/drop event" severity failure;
    report "TB_ETH_RX_RING PASS (back-to-back drain, oversize doom, counter saturation)";
    finish;
  end process;

  p_chk : process
    variable k, i : integer := 0;
  begin
    wait until rising_edge(clk);
    if ev_ok = '1' then n_ok <= n_ok + 1; end if;
    if ev_ovs = '1' then n_ovs <= n_ovs + 1; end if;
    if ev_crc = '1' or ev_runt = '1' or ev_drop = '1' then n_other <= n_other + 1; end if;
    if rx_valid = '1' then
      assert k <= 3 report "RX ring: extra frame delivered" severity failure;
      assert rx_data = fb(DELIV_ID(k), i)
        report "RX ring: frame id " & integer'image(DELIV_ID(k)) & " byte " &
               integer'image(i) & " corrupted" severity failure;
      if rx_last = '1' then
        assert i = DELIV_LEN(k) - 1
          report "RX ring: frame id " & integer'image(DELIV_ID(k)) & " length " &
                 integer'image(i + 1) severity failure;
        k := k + 1; i := 0;
      else
        i := i + 1;
      end if;
    end if;
  end process;

  p_wd : process
  begin
    wait for 5 ms;
    assert false report "TB_ETH_RX_RING: timeout" severity failure;
    wait;
  end process;
end architecture;
