-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- tb_dma_axi (AUDIT 2026-11): mipi_dma_burst against an AXI4 slave model with
-- pseudo-random wait states on AWREADY / WREADY / BVALID plus an independent
-- AXI protocol checker and a byte-exact DDR scoreboard.
--
-- Protocol checker (every clock):
--   * a VALID that was high without READY must stay high, with its payload
--     (AWADDR/AWLEN/AWSIZE/AWBURST, WDATA/WSTRB/WLAST) unchanged;
--   * number of W beats of each burst == AWLEN+1 and WLAST only on the last;
--   * no burst crosses a 4 KB boundary; AWSIZE=2, AWBURST=INCR;
--   * no W beat without an outstanding AW (this core issues AW first);
--   * BREADY handshake count == AW handshake count.
-- Scoreboard: DDR bytes [dst, dst+len) == FB bytes [0, len); every other byte
-- keeps its 0xEE fill (catches duplicate beats, over-length writes and
-- wrong WSTRB). Cases cover len = 0..9, 4 KB crossings, >256-beat splits.
-- Runs: random wait states (MODE=0, SEED), READY tied high (MODE=1) and a
-- registered "ready follows valid" slave (MODE=2) -- the latter is where the
-- old registered VALID produced duplicate AW / W beats.
-- Pass: "DMA AXI PASS". assert severity failure on any error.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_dma_axi is
  generic (SEED : integer := 12345; MODE : integer := 0);  -- 0 random, 1 ready=1, 2 ready<=valid
end entity;

architecture sim of tb_dma_axi is
  constant TCK : time := 10 ns;
  constant FB_AWID : integer := 15;
  constant FB_DEPTH : integer := 18432;
  constant DDR_BYTES : integer := 65536;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin : boolean := false;

  signal start, src_sel, done : std_logic := '0';
  signal dst_addr, length : std_logic_vector(31 downto 0) := (others=>'0');
  signal fb_sel, fb_re : std_logic;
  signal fb_addr : std_logic_vector(FB_AWID-1 downto 0);
  signal fb_data : std_logic_vector(7 downto 0);
  signal fb_we : std_logic := '0';
  signal fb_waddr : std_logic_vector(FB_AWID-1 downto 0) := (others=>'0');
  signal fb_wdata : std_logic_vector(7 downto 0) := (others=>'0');

  signal awaddr : std_logic_vector(31 downto 0);
  signal awlen  : std_logic_vector(7 downto 0);
  signal awsize : std_logic_vector(2 downto 0);
  signal awburst: std_logic_vector(1 downto 0);
  signal awvalid, awready : std_logic := '0';
  signal wdata  : std_logic_vector(31 downto 0);
  signal wstrb  : std_logic_vector(3 downto 0);
  signal wlast, wvalid, wready : std_logic := '0';
  signal bresp  : std_logic_vector(1 downto 0) := "00";
  signal bvalid, bready : std_logic := '0';

  type ddr_t is array (0 to DDR_BYTES-1) of std_logic_vector(7 downto 0);
  signal ddr : ddr_t := (others => x"EE");   -- driven only by the slave process
  signal ddr_clear : boolean := false;

  signal prot_err : integer := 0;
  signal aw_hs, b_hs, w_hs : integer := 0;

  function fbpat(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned((i * 37 + 11 + i / 256) mod 256, 8));
  end function;
begin
  clk <= '0' when fin else not clk after TCK/2;

  fb : entity work.framebuffer
    generic map (DEPTH => FB_DEPTH, AWID => FB_AWID)
    port map (clk => clk, we => fb_we, waddr => fb_waddr, wdata => fb_wdata,
              re => fb_re, raddr => fb_addr, rdata => fb_data);

  dut : entity work.mipi_dma_burst
    generic map (FB_AWID => FB_AWID)
    port map (clk => clk, rst => rst, start => start, src_sel => src_sel,
              dst_addr => dst_addr, length => length, done => done,
              fb_sel => fb_sel, fb_re => fb_re, fb_addr => fb_addr, fb_data => fb_data,
              m_awaddr => awaddr, m_awlen => awlen, m_awsize => awsize, m_awburst => awburst,
              m_awvalid => awvalid, m_awready => awready,
              m_wdata => wdata, m_wstrb => wstrb, m_wlast => wlast,
              m_wvalid => wvalid, m_wready => wready,
              m_bresp => bresp, m_bvalid => bvalid, m_bready => bready);

  ---------------------------------------------------------------------------
  -- AXI4 write slave: random ready / response delays, byte memory with WSTRB
  ---------------------------------------------------------------------------
  slave : process(clk)
    variable lfsr : unsigned(31 downto 0) := to_unsigned(SEED, 32);
    variable cur_addr : integer := 0;
    variable pend_b : integer := 0;      -- bursts whose WLAST was accepted
    variable a : integer;
    procedure step is
    begin
      lfsr := lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
    end procedure;
  begin
    if rising_edge(clk) then
      if ddr_clear then
        ddr <= (others => x"EE");
      end if;
      -- handshakes of this cycle
      if awvalid = '1' and awready = '1' then
        cur_addr := to_integer(unsigned(awaddr(15 downto 0)));
        aw_hs <= aw_hs + 1;
      end if;
      if wvalid = '1' and wready = '1' then
        for b in 0 to 3 loop
          if wstrb(b) = '1' then
            a := (cur_addr + b) mod DDR_BYTES;
            ddr(a) <= wdata(8*b+7 downto 8*b);
          end if;
        end loop;
        cur_addr := cur_addr + 4;
        w_hs <= w_hs + 1;
        if wlast = '1' then pend_b := pend_b + 1; end if;
      end if;
      if bvalid = '1' and bready = '1' then
        b_hs <= b_hs + 1;
        pend_b := pend_b - 1;
        bvalid <= '0';
      elsif bvalid = '0' and pend_b > 0 and (MODE = 1 or lfsr(13) = '1') then
        bvalid <= '1'; bresp <= "00";
      end if;
      -- next-cycle ready / response generation
      step;
      if MODE = 1 then
        awready <= '1'; wready <= '1';
      elsif MODE = 2 then
        -- "ready follows valid" slave (registered): READY rises the cycle after
        -- VALID and stays while VALID stays -> a VALID held one cycle too long
        -- after its handshake is accepted twice (duplicate AW / W beat).
        awready <= awvalid; wready <= wvalid;
      else
        awready <= lfsr(3) and lfsr(7);          -- ~25% ready
        wready  <= lfsr(5) or lfsr(11);          -- ~75% ready
      end if;
      if rst = '1' then
        awready <= '0'; wready <= '0'; bvalid <= '0'; pend_b := 0;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- independent AXI protocol checker
  ---------------------------------------------------------------------------
  checker : process(clk)
    variable aw_q, w_q : boolean := false;
    variable awaddr_q : std_logic_vector(31 downto 0);
    variable awlen_q  : std_logic_vector(7 downto 0);
    variable wdata_q  : std_logic_vector(31 downto 0);
    variable wstrb_q  : std_logic_vector(3 downto 0);
    variable wlast_q  : std_logic;
    variable outstanding : integer := 0;     -- AW accepted, W burst incomplete
    variable beats_left  : integer := 0;
    type q_t is array (0 to 63) of integer;
    variable lenq : q_t;
    variable qh, qt : integer := 0;
    variable a0 : unsigned(31 downto 0);
    procedure err(m : string) is
    begin
      report "AXI PROTOCOL: " & m severity error;
      prot_err <= prot_err + 1;
    end procedure;
  begin
    if rising_edge(clk) and rst = '0' then
      -- VALID stability rules
      if aw_q then
        if awvalid /= '1' then err("AWVALID dropped before AWREADY");
        elsif awaddr /= awaddr_q or awlen /= awlen_q then err("AW payload changed while waiting"); end if;
      end if;
      if w_q then
        if wvalid /= '1' then err("WVALID dropped before WREADY");
        elsif wdata /= wdata_q or wstrb /= wstrb_q or wlast /= wlast_q then
          err("W payload changed while waiting");
        end if;
      end if;
      aw_q := (awvalid = '1' and awready = '0');
      w_q  := (wvalid = '1' and wready = '0');
      awaddr_q := awaddr; awlen_q := awlen;
      wdata_q := wdata; wstrb_q := wstrb; wlast_q := wlast;
      -- AW checks
      if awvalid = '1' and awready = '1' then
        if awsize /= "010" or awburst /= "01" then err("AWSIZE/AWBURST"); end if;
        a0 := unsigned(awaddr);
        if (to_integer(a0(11 downto 0)) + 4 * (to_integer(unsigned(awlen)) + 1)) > 4096 then
          err("burst crosses 4KB at 0x" & to_hstring(awaddr));
        end if;
        lenq(qt) := to_integer(unsigned(awlen)) + 1; qt := (qt + 1) mod 64;
      end if;
      -- W checks (bursts are served in AW order)
      if wvalid = '1' and wready = '1' then
        if beats_left = 0 then
          if qh = qt then err("W beat without outstanding AW");
          else beats_left := lenq(qh); qh := (qh + 1) mod 64; end if;
        end if;
        beats_left := beats_left - 1;
        if (beats_left = 0) /= (wlast = '1') then
          err("WLAST mismatch (beats_left=" & integer'image(beats_left) & ")");
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- stimulus + scoreboard
  ---------------------------------------------------------------------------
  stim : process
    type case_t is record dst : integer; len : integer; end record;
    type cases_t is array (natural range <>) of case_t;
    constant CASES : cases_t := (
      (16#0100#, 0), (16#0200#, 1), (16#0300#, 2), (16#0400#, 3), (16#0500#, 4),
      (16#0600#, 5), (16#0700#, 6), (16#0800#, 7), (16#0900#, 9),
      (16#0FF0#, 1023),           -- crosses 4 KB after 4 beats
      (16#1FFC#, 4096 + 7),       -- 1 beat, then a full page, then a tail
      (16#3000#, 1100),           -- > 256 beats inside one page: split at 256
      (16#5004#, 18432 - 3));     -- almost the whole FB, odd length
    variable errs : integer := 0;
    variable aw0, b0 : integer;
    variable lo, hi : integer;
    variable expb : std_logic_vector(7 downto 0);
  begin
    -- prefill the framebuffer
    rst <= '1';
    for i in 0 to FB_DEPTH-1 loop
      fb_waddr <= std_logic_vector(to_unsigned(i, FB_AWID));
      fb_wdata <= fbpat(i); fb_we <= '1';
      wait until rising_edge(clk);
    end loop;
    fb_we <= '0';
    wait until rising_edge(clk); rst <= '0';
    wait until rising_edge(clk);

    for c in CASES'range loop
      ddr_clear <= true; wait until rising_edge(clk); ddr_clear <= false;
      wait until rising_edge(clk);
      aw0 := aw_hs; b0 := b_hs;
      dst_addr <= std_logic_vector(to_unsigned(CASES(c).dst, 32));
      length   <= std_logic_vector(to_unsigned(CASES(c).len, 32));
      src_sel  <= '0';
      start <= '1'; wait until rising_edge(clk); start <= '0';
      for t in 0 to 400000 loop
        wait until rising_edge(clk);
        exit when done = '1';
      end loop;
      assert done = '1' report "DMA timeout case " & integer'image(c) severity failure;
      for t in 1 to 20 loop wait until rising_edge(clk); end loop;   -- late beats?
      if CASES(c).len = 0 and aw_hs /= aw0 then
        errs := errs + 1; report "len=0 issued bus traffic" severity error;
      end if;
      if (b_hs - b0) /= (aw_hs - aw0) then
        errs := errs + 1; report "B count /= AW count" severity error;
      end if;
      lo := CASES(c).dst; hi := CASES(c).dst + CASES(c).len;
      for a in 0 to DDR_BYTES-1 loop
        if a >= lo and a < hi then expb := fbpat(a - lo); else expb := x"EE"; end if;
        if ddr(a) /= expb then
          errs := errs + 1;
          if errs < 8 then
            report "DDR mismatch case " & integer'image(c) & " addr=0x" &
                   to_hstring(to_unsigned(a, 16)) & " got=" & to_hstring(ddr(a)) &
                   " exp=" & to_hstring(expb) severity error;
          end if;
        end if;
      end loop;
    end loop;

    errs := errs + prot_err;
    report "DMA AXI errors=" & integer'image(errs) & " AW=" & integer'image(aw_hs) &
           " W=" & integer'image(w_hs) & " B=" & integer'image(b_hs);
    assert errs = 0 report "DMA AXI FAIL" severity failure;
    report "DMA AXI PASS (SEED=" & integer'image(SEED) & " MODE=" & integer'image(MODE) & ")";
    fin <= true;
    wait;
  end process;
end architecture;
