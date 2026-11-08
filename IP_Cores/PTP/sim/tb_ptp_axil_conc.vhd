-- tb_ptp_axil_conc.vhd - ptp_axil under concurrent AXI4-Lite channels
-- ---------------------------------------------------------------------------
-- Audit 2026-11 (ALTA, ptp_axil.vhd:108-113 / 148 / wstrb). Self-checking.
-- An independent AXI4-Lite master model that behaves like a legal but
-- aggressive interconnect:
--   * AW+W and AR are raised in the same cycle or with a skew of 1..3 cycles
--     in either order (v1 corrupted the write when AR was accepted while the
--     write strobe was being issued, i.e. AR one cycle after AW/W);
--   * after each handshake the master immediately drives garbage on the
--     channel's payload (AXI allows it: payload is only valid with VALID);
--   * W may be presented before AW.
-- Checks:
--   C1 a write issued together with a read lands at the WRITE address with
--      the handshaked data (v1: write landed at the read address and/or
--      took the post-handshake garbage wdata);
--   C2 the concurrent read returns the register it addressed;
--   C3 64 random interleaved writes/reads to SERVO/LAT/CLKID_LO/PORTNUM
--      against a reference model;
--   C4 partial WSTRB -> SLVERR and register unchanged; WSTRB=0000 -> OKAY,
--      unchanged; WSTRB=1111 -> OKAY, written;
--   C5 BVALID is never lost: every write gets exactly one response.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

entity tb_ptp_axil_conc is
end entity;

architecture sim of tb_ptp_axil_conc is
  constant TCK : time := 10 ns;
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal awaddr, araddr : std_logic_vector(15 downto 0) := (others => '0');
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic := '0';
  signal arvalid, arready, rvalid, rready : std_logic := '0';
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := "1111";
  signal bresp, rresp : std_logic_vector(1 downto 0);
  signal irq : std_logic;
  signal n_b : integer := 0;

  constant A_SERVO : integer := 16#04#;
  constant A_LAT   : integer := 16#08#;
  constant A_CLKL  : integer := 16#14#;
  constant A_PORT  : integer := 16#18#;
  type addr_arr is array (0 to 3) of integer;
  constant ADDRS : addr_arr := (A_SERVO, A_LAT, A_CLKL, A_PORT);
begin
  clk <= not clk after TCK / 2;

  dut : entity work.ptp_axil
    port map (s_axi_aclk => clk, s_axi_aresetn => aresetn,
      s_axi_awaddr => awaddr, s_axi_awvalid => awvalid, s_axi_awready => awready,
      s_axi_wdata => wdata, s_axi_wstrb => wstrb, s_axi_wvalid => wvalid, s_axi_wready => wready,
      s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
      s_axi_araddr => araddr, s_axi_arvalid => arvalid, s_axi_arready => arready,
      s_axi_rdata => rdata, s_axi_rresp => rresp, s_axi_rvalid => rvalid, s_axi_rready => rready,
      irq => irq, mii_txd => open, mii_tx_en => open,
      mii_rxd => (others => '0'), mii_rx_dv => '0');

  p_bcount : process(clk)
  begin
    if rising_edge(clk) then
      if bvalid = '1' and bready = '1' then n_b <= n_b + 1; end if;
    end if;
  end process;

  stim : process
    type model_t is array (0 to 3) of std_logic_vector(31 downto 0);
    variable model : model_t := (others => (others => '0'));
    variable seed1, seed2 : positive := 7;
    variable r : real;
    variable v : std_logic_vector(31 downto 0);
    variable br : std_logic_vector(1 downto 0);
    variable nwr : integer := 0;
    variable ai, ri : integer;
    variable d : std_logic_vector(31 downto 0);

    procedure step is begin wait until rising_edge(clk); end procedure;

    -- concurrent write (AW+W) and read (AR), channels completing independently
    -- skew > 0: AR raised 'skew' cycles after AW/W; skew < 0: AW/W after AR
    procedure wr_rd(wa : integer; wd : std_logic_vector(31 downto 0);
                    ra : integer; rd_o : out std_logic_vector(31 downto 0);
                    bresp_o : out std_logic_vector(1 downto 0); skew : integer := 0) is
      variable aw_done, w_done, ar_done, b_done, r_done : boolean := false;
      variable cyc : integer := 0;
      variable w_up, r_up : boolean := false;
    begin
      bready <= '1'; rready <= '1';
      loop
        if not w_up and cyc >= -skew then
          awaddr <= std_logic_vector(to_unsigned(wa, 16)); awvalid <= '1';
          wdata  <= wd; wvalid <= '1'; w_up := true;
        end if;
        if not r_up and cyc >= skew then
          araddr <= std_logic_vector(to_unsigned(ra, 16)); arvalid <= '1'; r_up := true;
        end if;
        cyc := cyc + 1;
        step;
        if awvalid = '1' and awready = '1' then
          aw_done := true; awvalid <= '0'; awaddr <= x"FFFC";     -- garbage
        end if;
        if wvalid = '1' and wready = '1' then
          w_done := true; wvalid <= '0'; wdata <= x"DEADBEEF";    -- garbage
        end if;
        if arvalid = '1' and arready = '1' then
          ar_done := true; arvalid <= '0'; araddr <= x"FFFC";
        end if;
        if bvalid = '1' and bready = '1' then
          b_done := true; bresp_o := bresp; bready <= '0';
        end if;
        if rvalid = '1' and rready = '1' then
          r_done := true; rd_o := rdata; rready <= '0';
        end if;
        exit when aw_done and w_done and ar_done and b_done and r_done;
      end loop;
    end procedure;

    procedure wr(a : integer; dd : std_logic_vector(31 downto 0);
                 st : std_logic_vector(3 downto 0);
                 bresp_o : out std_logic_vector(1 downto 0)) is
      variable aw_done, w_done : boolean := false;
    begin
      -- W first, AW one cycle later (legal ordering)
      wdata <= dd; wstrb <= st; wvalid <= '1'; bready <= '1';
      step;
      awaddr <= std_logic_vector(to_unsigned(a, 16)); awvalid <= '1';
      loop
        step;
        if awvalid = '1' and awready = '1' then aw_done := true; awvalid <= '0'; awaddr <= x"0000"; end if;
        if wvalid = '1' and wready = '1' then w_done := true; wvalid <= '0'; wdata <= x"A5A5A5A5"; end if;
        if bvalid = '1' and bready = '1' then bresp_o := bresp; bready <= '0'; exit; end if;
      end loop;
      wstrb <= "1111";
    end procedure;

    procedure rd(a : integer; rd_o : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, 16)); arvalid <= '1'; rready <= '1';
      loop
        step;
        if arvalid = '1' and arready = '1' then arvalid <= '0'; araddr <= x"FFFC"; end if;
        if rvalid = '1' and rready = '1' then rd_o := rdata; rready <= '0'; exit; end if;
      end loop;
    end procedure;
  begin
    aresetn <= '0'; step; step; step; aresetn <= '1'; step;

    -- C1/C2: write SERVO while reading LAT, same cycle
    wr(A_LAT, x"11112222", "1111", br); nwr := nwr + 1;
    model(1) := x"11112222";
    wr_rd(A_SERVO, x"0BADF00D", A_LAT, v, br, 1); nwr := nwr + 1;
    model(0) := x"0BADF00D";
    assert v = x"11112222"
      report "C2: concurrent read of LAT returned " & to_hstring(v) severity failure;
    rd(A_SERVO, v);
    assert v = x"0BADF00D"
      report "C1: SERVO = " & to_hstring(v) & " after concurrent write (expected 0BADF00D)"
      severity failure;
    rd(A_LAT, v);
    assert v = x"11112222"
      report "C1: LAT corrupted by a concurrent write: " & to_hstring(v) severity failure;

    -- C3: random interleaving vs reference model
    for k in 0 to 63 loop
      uniform(seed1, seed2, r); ai := integer(trunc(r * 4.0)) mod 4;
      uniform(seed1, seed2, r); ri := integer(trunc(r * 4.0)) mod 4;
      uniform(seed1, seed2, r);
      d := std_logic_vector(to_unsigned(integer(trunc(r * 65535.0)), 16)) &
           std_logic_vector(to_unsigned(k * 977 mod 65536, 16));
      if ADDRS(ai) = A_PORT then d(31 downto 16) := x"0000"; end if;
      wr_rd(ADDRS(ai), d, ADDRS(ri), v, br, (k mod 7) - 3); nwr := nwr + 1;
      -- the read may be ordered before or after the write: both are legal
      assert v = model(ri) or (ri = ai and v = d)
        report "C3: read of reg " & integer'image(ri) & " returned " & to_hstring(v) &
               " (model " & to_hstring(model(ri)) & ")" severity failure;
      model(ai) := d;
      assert br = "00" report "C3: unexpected BRESP" severity failure;
    end loop;
    for i in 0 to 3 loop
      rd(ADDRS(i), v);
      assert v = model(i)
        report "C3: final reg " & integer'image(i) & " = " & to_hstring(v) &
               " model " & to_hstring(model(i)) severity failure;
    end loop;

    -- C4: WSTRB policy
    wr(A_SERVO, x"12345678", "0011", br); nwr := nwr + 1;
    assert br = "10" report "C4: partial WSTRB did not return SLVERR" severity failure;
    rd(A_SERVO, v);
    assert v = model(0) report "C4: partial write modified SERVO" severity failure;
    wr(A_SERVO, x"12345678", "0000", br); nwr := nwr + 1;
    assert br = "00" report "C4: WSTRB=0000 must be OKAY" severity failure;
    rd(A_SERVO, v);
    assert v = model(0) report "C4: WSTRB=0000 modified SERVO" severity failure;
    wr(A_SERVO, x"12345678", "1111", br); nwr := nwr + 1;
    rd(A_SERVO, v);
    assert v = x"12345678" and br = "00" report "C4: full write failed" severity failure;

    -- C5: two writes while BREADY is held low: each must get its own response
    bready <= '0';
    awaddr <= std_logic_vector(to_unsigned(A_LAT, 16)); awvalid <= '1';
    wdata <= x"0000C0DE"; wvalid <= '1';
    loop step; exit when awvalid = '1' and awready = '1'; end loop;
    awvalid <= '0'; wvalid <= '0';
    step;
    awaddr <= std_logic_vector(to_unsigned(A_PORT, 16)); awvalid <= '1';
    wdata <= x"0000BEEF"; wvalid <= '1';
    for i in 1 to 20 loop
      step;
      if awvalid = '1' and awready = '1' then awvalid <= '0'; wvalid <= '0'; end if;
    end loop;
    bready <= '1';
    loop
      step;
      if awvalid = '1' and awready = '1' then awvalid <= '0'; wvalid <= '0'; end if;
      exit when awvalid = '0' and bvalid = '0';
    end loop;
    for i in 1 to 10 loop step; end loop;
    bready <= '0';
    nwr := nwr + 2;
    rd(A_PORT, v);
    assert v = x"0000BEEF" report "C5: second write lost" severity failure;
    step; step;
    assert n_b = nwr
      report "C5: " & integer'image(n_b) & " B responses for " & integer'image(nwr) & " writes"
      severity failure;

    report "TB_PTP_AXIL_CONC PASS (serialized channels, handshake-edge capture, WSTRB/SLVERR)";
    finish;
  end process;

  wd : process
  begin
    wait for 2 ms;
    assert false report "TB_PTP_AXIL_CONC: timeout (deadlock?)" severity failure;
    wait;
  end process;
end architecture;
