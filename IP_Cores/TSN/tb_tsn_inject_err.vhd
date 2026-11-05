-- tb_tsn_inject_err.vhd - tsn_inject request handling (audit 2026-11, BAJA)
-- ---------------------------------------------------------------------------
-- Self-checking. tsn_inject feeds an eth_rx_mii (promisc) that counts frames.
--   E1 go with len = 0 is refused (err pulse) and emits NOTHING
--      (v1: len-1 wrapped to 4095 -> a 4096-byte garbage frame);
--   E2 go with len > buffer (2049) is refused;
--   E3 go while busy is queued and executed after the current frame:
--      2 go's back-to-back -> 2 good frames (v1: the second go was lost);
--   E4 a third go while one is already pending is refused (err);
--   E5 a push while busy is dropped and reported (err).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_tsn_inject_err is
end entity;

architecture sim of tb_tsn_inject_err is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ce : std_logic := '0';
  signal push, clr, go : std_logic := '0';
  signal word : std_logic_vector(31 downto 0) := (others => '0');
  signal len : unsigned(11 downto 0) := (others => '0');
  signal busy, err : std_logic;
  signal rxd : std_logic_vector(3 downto 0);
  signal dv : std_logic;
  signal ev_ok, ev_crc, ev_runt, ev_ovs : std_logic;
  signal n_ok, n_bad, n_err, n_dv : integer := 0;
  signal dv_d : std_logic := '0';
begin
  clk <= not clk after 5 ns;
  p_ce : process(clk)
    variable d : integer := 0;
  begin
    if rising_edge(clk) then
      if d = 3 then ce <= '1'; d := 0; else ce <= '0'; d := d + 1; end if;
    end if;
  end process;

  inj : entity work.tsn_inject
    generic map (LOG2_DEPTH => 11)
    port map (clk => clk, rst => rst, mii_ce => ce,
      wr_push => push, wr_word => word, clr_buf => clr,
      len_bytes => len, go => go, port_sel => "00", busy => busy, err => err,
      inj_port => open, inj_rxd => rxd, inj_rx_dv => dv);

  rx : entity work.eth_rx_mii
    generic map (G_MAXLEN => 1522)
    port map (clk => clk, rst => rst, mii_ce => ce,
      macaddr => x"000000000000", promisc => '1', rxd => rxd, rx_dv => dv,
      rx_data => open, rx_valid => open, rx_last => open,
      ev_ok => ev_ok, ev_crc => ev_crc, ev_runt => ev_runt, ev_drop => open,
      ev_oversize => ev_ovs, rx_sfd_pulse => open, dbg_dst => open, dbg_nb => open);

  p_cnt : process(clk)
  begin
    if rising_edge(clk) then
      dv_d <= dv;
      if ev_ok = '1' then n_ok <= n_ok + 1; end if;
      if ev_crc = '1' or ev_runt = '1' or ev_ovs = '1' then n_bad <= n_bad + 1; end if;
      if err = '1' then n_err <= n_err + 1; end if;
      if dv = '1' and dv_d = '0' then n_dv <= n_dv + 1; end if;
    end if;
  end process;

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure waitc(n : integer) is begin for i in 1 to n loop step; end loop; end procedure;
    procedure pgo is begin go <= '1'; step; go <= '0'; end procedure;
    variable e0 : integer;
  begin
    rst <= '1'; waitc(3); rst <= '0'; waitc(2);
    -- load a 64-byte frame (16 words)
    clr <= '1'; step; clr <= '0';
    for w in 0 to 15 loop
      word <= std_logic_vector(to_unsigned(w * 16#01010101# + 16#00020406#, 32));
      push <= '1'; step; push <= '0';
    end loop;

    -- E1
    len <= to_unsigned(0, 12); pgo; waitc(2000);
    assert n_err = 1 report "E1: len=0 not refused" severity failure;
    assert n_dv = 0 report "E1: len=0 emitted a frame" severity failure;
    -- E2
    len <= to_unsigned(2049, 12); pgo; waitc(50);
    assert n_err = 2 and busy = '0' report "E2: len>buffer not refused" severity failure;
    -- E3 + E4: three go's in a row
    len <= to_unsigned(64, 12);
    pgo; waitc(20);
    assert busy = '1' report "E3: not busy" severity failure;
    pgo;                                      -- queued
    waitc(5);
    e0 := n_err;
    pgo;                                      -- refused: one already pending
    waitc(2);
    assert n_err = e0 + 1 report "E4: third go not refused" severity failure;
    -- E5: push while busy
    e0 := n_err;
    push <= '1'; step; push <= '0'; waitc(2);
    assert n_err = e0 + 1 report "E5: push while busy not reported" severity failure;
    loop step; exit when busy = '0'; end loop;
    waitc(500);
    assert n_ok = 2 and n_bad = 0
      report "E3: " & integer'image(n_ok) & " good frames (2 expected), " &
             integer'image(n_bad) & " bad" severity failure;
    report "TB_TSN_INJECT_ERR PASS (len checks, go queued, errors reported)";
    finish;
  end process;
end architecture;
