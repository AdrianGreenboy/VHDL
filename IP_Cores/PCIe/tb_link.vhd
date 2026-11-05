-- ============================================================================
-- tb_link.vhd -- PCIE IP, link-level integrity bench (audit 2026-11)
--
-- Two complete pcie_node instances (A = RC, B = EP) connected PIPE-to-PIPE
-- through a channel model, one per direction, that works on the scrambled
-- symbol stream and can:
--   * corrupt one data byte of a chosen TLP          (LCRC error at the RX)
--   * drop a whole TLP / DLLP (its STP/SDP is replaced by an unused K symbol,
--     so the receiver never sees it; the symbol count is preserved so the
--     scramblers stay in lock)
--   * drop all TLPs or all DLLPs during a time window.
-- Self-checking (severity failure). Each test fails on the pre-audit node:
--   T1  corrupted MWr payload must NOT reach BAR0 (Nak + replay instead)
--   T2  dropped MWr followed by a second MWr to the same address: in-order
--       delivery after Nak/replay (final value = the second write)
--   T3  all Acks lost: REPLAY_TIMER replays, the EP discards the duplicate
--       (BAR0 write counter exact), the RC replay buffer empties
--   T4  MRd outside BAR0 -> Cpl with status UR (tag preserved)
--   T5  MRd of 20 DW -> two CplDs split at the 64-byte RCB boundary,
--       correct data / Byte Count / Lower Address
--   T6  completion lost long enough -> requester completion timeout
--   T7  persistent loss -> REPLAY_NUM rollover -> Recovery -> back to L0,
--       traffic resumes
--   T8  MSI triggered while a long MWr is being received: MSI correct and
--       the MWr data intact (no RX FSM clobber)
--   T9  both nodes send requests while completing the other's requests:
--       TX arbiter keeps TLPs whole (all completions correct)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;
use work.pcie_tl_pkg.all;

entity tb_link is
end entity;

architecture sim of tb_link is
  constant TCLK : time := 10 ns;
  constant RPL_TMO : integer := 3000;
  constant CPL_TMO : integer := 8000;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst : std_logic := '1';

  signal a_pt, b_pt, a_pr, b_pr : work.pcie_8b10b_pkg.byte_t;
  signal a_ptk, b_ptk, a_prk, b_prk : std_logic;

  -- node A (RC)
  signal a_rv, a_rl, a_rrdy : std_logic := '0';
  signal a_rd : work.pcie_8b10b_pkg.byte_t := (others => '0');
  signal a_up : std_logic; signal a_st : std_logic_vector(3 downto 0);
  signal a_rx_v, a_rx_s, a_rx_l : std_logic; signal a_rx_d : work.pcie_8b10b_pkg.byte_t;
  signal a_rpl, a_rtmo, a_ctmo_cnt, a_retr, a_good : std_logic_vector(15 downto 0);
  signal a_ctmo : std_logic;
  -- node B (EP)
  signal b_rv, b_rl, b_rrdy : std_logic := '0';
  signal b_rd : work.pcie_8b10b_pkg.byte_t := (others => '0');
  signal b_msi : std_logic := '0';
  signal b_up : std_logic; signal b_st : std_logic_vector(3 downto 0);
  signal b_bar : dw_t; signal b_mwr, b_mrd, b_good, b_bad, b_rpl, b_ur, b_retr : std_logic_vector(15 downto 0);
  signal b_rx_v, b_rx_s, b_rx_l : std_logic; signal b_rx_d : work.pcie_8b10b_pkg.byte_t;

  -- channel controls, index 0 = A->B, 1 = B->A
  type int2 is array (0 to 1) of integer;
  type sl2  is array (0 to 1) of std_logic;
  signal c_tlp_n, c_dllp_n : int2 := (0, 0);       -- packets seen so far
  signal c_cor_tlp, c_cor_pos, c_drop_tlp : int2 := (-1, -1);
  signal c_drop_all_tlp, c_drop_all_dllp : sl2 := ('0', '0');

  -- received-TLP capture (validated streams of A and B)
  constant QN : integer := 16;
  type tlp_t is array (0 to 127) of work.pcie_8b10b_pkg.byte_t;
  type q_t is array (0 to QN-1) of tlp_t;
  type len_q_t is array (0 to QN-1) of integer;
  signal qa, qb : q_t;
  signal qa_len, qb_len : len_q_t := (others => 0);
  signal qa_n, qb_n : integer := 0;
  signal tb_clr_q : std_logic := '0';

  -- B-side injector (for T9)
  signal b_go : std_logic := '0';
  signal b_done : std_logic := '0';
begin
  clk <= '0' when fin else not clk after TCLK/2;

  u_a : entity work.pcie_node
    generic map (is_rc => true, TIMEOUT_C => 5000, REPLAY_TMO => RPL_TMO,
                 ACKNAK_LAT => 32, CPL_TMO_C => CPL_TMO)
    port map (clk=>clk, rst=>rst, en=>'1', cmd_start=>'1', cmd_hotrst=>'0',
              pt_sym=>a_pt, pt_k=>a_ptk, pr_sym=>a_pr, pr_k=>a_prk,
              req_valid=>a_rv, req_data=>a_rd, req_last=>a_rl, req_ready=>a_rrdy,
              msi_trigger=>'0', link_up=>a_up, ltssm_state=>a_st,
              bar0_dbg=>open, mwr_cnt=>open, mrd_cnt=>open, good_rx=>a_good,
              replays=>a_rpl,
              tlresp_valid=>open, tlresp_data=>open, tlresp_start=>open, tlresp_last=>open,
              rxtlp_valid=>a_rx_v, rxtlp_data=>a_rx_d, rxtlp_start=>a_rx_s, rxtlp_last=>a_rx_l,
              cpl_tmo=>a_ctmo, cpl_tmo_cnt=>a_ctmo_cnt, bad_rx=>open, nak_tx=>open,
              rpl_tmo=>a_rtmo, ur_cnt=>open, retrain_cnt=>a_retr);

  u_b : entity work.pcie_node
    generic map (is_rc => false, TIMEOUT_C => 5000, REPLAY_TMO => RPL_TMO,
                 ACKNAK_LAT => 32, CPL_TMO_C => CPL_TMO)
    port map (clk=>clk, rst=>rst, en=>'1', cmd_start=>'1', cmd_hotrst=>'0',
              pt_sym=>b_pt, pt_k=>b_ptk, pr_sym=>b_pr, pr_k=>b_prk,
              req_valid=>b_rv, req_data=>b_rd, req_last=>b_rl, req_ready=>b_rrdy,
              msi_trigger=>b_msi, link_up=>b_up, ltssm_state=>b_st,
              bar0_dbg=>b_bar, mwr_cnt=>b_mwr, mrd_cnt=>b_mrd, good_rx=>b_good,
              replays=>b_rpl,
              tlresp_valid=>open, tlresp_data=>open, tlresp_start=>open, tlresp_last=>open,
              rxtlp_valid=>b_rx_v, rxtlp_data=>b_rx_d, rxtlp_start=>b_rx_s, rxtlp_last=>b_rx_l,
              cpl_tmo=>open, cpl_tmo_cnt=>open, bad_rx=>b_bad, nak_tx=>open,
              rpl_tmo=>open, ur_cnt=>b_ur, retrain_cnt=>b_retr);

  -- ---------------- channel model (registered, 1 cycle) ----------------
  g_ch : for d in 0 to 1 generate
    signal i_sym : work.pcie_8b10b_pkg.byte_t;
    signal i_k   : std_logic;
    signal o_sym : work.pcie_8b10b_pkg.byte_t := (others => '0');
    signal o_k   : std_logic := '0';
  begin
    i_sym <= a_pt  when d = 0 else b_pt;
    i_k   <= a_ptk when d = 0 else b_ptk;
    g0 : if d = 0 generate b_pr <= o_sym; b_prk <= o_k; end generate;
    g1 : if d = 1 generate a_pr <= o_sym; a_prk <= o_k; end generate;

    process(clk)
      variable in_tlp : boolean := false;
      variable pos    : integer := 0;
      variable s      : work.pcie_8b10b_pkg.byte_t;
    begin
      if rising_edge(clk) then
        s := i_sym;
        if i_k = '1' and i_sym = K_STP then
          in_tlp := true; pos := 0;
          if c_drop_all_tlp(d) = '1' or c_tlp_n(d) = c_drop_tlp(d) then
            s := K_FTS;                    -- receiver ignores: TLP lost
          end if;
          c_tlp_n(d) <= c_tlp_n(d) + 1;
        elsif i_k = '1' and i_sym = K_SDP then
          if c_drop_all_dllp(d) = '1' then s := K_FTS; end if;
          c_dllp_n(d) <= c_dllp_n(d) + 1;
        elsif i_k = '1' then
          in_tlp := false;
        elsif in_tlp then
          if c_tlp_n(d) - 1 = c_cor_tlp(d) and pos = c_cor_pos(d) then
            s := i_sym xor x"01";          -- single-bit error in a TLP byte
          end if;
          pos := pos + 1;
        end if;
        o_sym <= s; o_k <= i_k;
      end if;
    end process;
  end generate;

  -- ---------------- capture of validated received TLPs ----------------
  cap_a : process(clk)
    variable j : integer := 0;
  begin
    if rising_edge(clk) then
      if tb_clr_q = '1' then qa_n <= 0; j := 0;
      elsif a_rx_v = '1' then
        if a_rx_s = '1' then j := 0; end if;
        if qa_n < QN and j < 128 then qa(qa_n)(j) <= a_rx_d; end if;
        j := j + 1;
        if a_rx_l = '1' then
          if qa_n < QN then qa_len(qa_n) <= j; qa_n <= qa_n + 1; end if;
          j := 0;
        end if;
      end if;
    end if;
  end process;
  cap_b : process(clk)
    variable j : integer := 0;
  begin
    if rising_edge(clk) then
      if tb_clr_q = '1' then qb_n <= 0; j := 0;
      elsif b_rx_v = '1' then
        if b_rx_s = '1' then j := 0; end if;
        if qb_n < QN and j < 128 then qb(qb_n)(j) <= b_rx_d; end if;
        j := j + 1;
        if b_rx_l = '1' then
          if qb_n < QN then qb_len(qb_n) <= j; qb_n <= qb_n + 1; end if;
          j := 0;
        end if;
      end if;
    end if;
  end process;

  -- ---------------- B-side requester (T9): MRd x4 to A's BAR0 ----------------
  b_inj : process
    variable h : tlp_t;
  begin
    b_rv <= '0'; b_rl <= '0'; b_done <= '0';
    wait until b_go = '1';
    for r in 0 to 3 loop
      h := (others => (others => '0'));
      h(0) := B0_MRD3; h(3) := x"02"; h(4) := x"02"; h(6) := std_logic_vector(to_unsigned(16#40# + r, 8));
      h(11) := std_logic_vector(to_unsigned(8*r, 8));
      for i in 0 to 11 loop
        b_rd <= h(i); b_rv <= '1';
        if i = 11 then b_rl <= '1'; else b_rl <= '0'; end if;
        loop wait until rising_edge(clk); exit when b_rrdy = '1'; end loop;
      end loop;
      b_rv <= '0'; b_rl <= '0';
    end loop;
    b_done <= '1';
    wait;
  end process;

  -- ---------------- main ----------------
  main : process
    variable h : tlp_t;
    variable c, n0, m0 : integer;
    variable dw : dw_t;

    procedure inject(constant t : tlp_t; constant n : integer) is
    begin
      for i in 0 to n-1 loop
        a_rd <= t(i); a_rv <= '1';
        if i = n-1 then a_rl <= '1'; else a_rl <= '0'; end if;
        loop wait until rising_edge(clk); exit when a_rrdy = '1'; end loop;
      end loop;
      a_rv <= '0'; a_rl <= '0';
    end procedure;
    procedure hdr(b0 : work.pcie_tl_pkg.byte_t; len : integer; tag : integer; addr : integer) is
      variable a : unsigned(31 downto 0);
    begin
      h := (others => (others => '0'));
      a := to_unsigned(addr, 32);
      h(0) := b0; h(2) := "000000" & std_logic_vector(to_unsigned(len, 10)(9 downto 8));
      h(3) := std_logic_vector(to_unsigned(len, 10)(7 downto 0));
      h(6) := std_logic_vector(to_unsigned(tag, 8)); h(7) := x"FF";
      h(8) := std_logic_vector(a(31 downto 24)); h(9) := std_logic_vector(a(23 downto 16));
      h(10) := std_logic_vector(a(15 downto 8)); h(11) := std_logic_vector(a(7 downto 0));
    end procedure;
    procedure put_dw(i : integer; v : dw_t) is
    begin
      h(12+4*i) := v(31 downto 24); h(13+4*i) := v(23 downto 16);
      h(14+4*i) := v(15 downto 8);  h(15+4*i) := v(7 downto 0);
    end procedure;
    procedure clr_q is
    begin
      tb_clr_q <= '1'; wait until rising_edge(clk); tb_clr_q <= '0';
    end procedure;
    procedure wait_qa(n : integer; msg : string; lim : integer := 30000) is
      variable c : integer := 0;
    begin
      loop
        wait until rising_edge(clk); c := c + 1;
        exit when qa_n >= n;
        assert c < lim report msg & ": expected TLP not received by A" severity failure;
      end loop;
    end procedure;
    procedure idle(n : integer) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
    end procedure;
    procedure wait_mwr(n : integer; msg : string; lim : integer := 40000) is
      variable c : integer := 0;
    begin
      loop
        wait until rising_edge(clk); c := c + 1;
        exit when to_integer(unsigned(b_mwr)) >= n;
        assert c < lim report msg & ": EP BAR0 writes missing" severity failure;
      end loop;
    end procedure;
    function pat(i : integer) return dw_t is
    begin
      return std_logic_vector(unsigned'(x"C0DE0000") + to_unsigned(i, 32));
    end function;
    function qdw(constant q : tlp_t; i : integer) return dw_t is
    begin
      return q(i) & q(i+1) & q(i+2) & q(i+3);
    end function;
    procedure read1(addr : integer; tag : integer; v : out dw_t; msg : string) is
    begin
      clr_q;
      hdr(B0_MRD3, 1, tag, addr); inject(h, 12);
      wait_qa(1, msg);
      assert qa(0)(0) = B0_CPLD and qa(0)(10) = std_logic_vector(to_unsigned(tag, 8))
        report msg & ": no CplD for the MRd" severity failure;
      v := qdw(qa(0), 12);
    end procedure;
  begin
    rst <= '1'; idle(8); rst <= '0';
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when a_up = '1' and b_up = '1';
      assert c < 20000 report "link did not reach L0" severity failure;
    end loop;
    idle(100);
    report "L0 reached";

    -- ---------- T1: corrupted MWr payload ----------
    n0 := to_integer(unsigned(a_rpl));
    c_cor_tlp(0) <= c_tlp_n(0); c_cor_pos(0) <= 2 + 12 + 1;   -- seq(2) + hdr(12) + 1
    hdr(B0_MWR3, 1, 1, 16#20#); put_dw(0, x"A5A5A5A5");
    inject(h, 16);
    wait_mwr(1, "T1");
    c_cor_tlp(0) <= -1;
    assert b_bar = x"A5A5A5A5" report "T1: corrupted payload reached BAR0" severity failure;
    read1(16#20#, 2, dw, "T1");
    assert dw = x"A5A5A5A5" report "T1: BAR0 content wrong" severity failure;
    assert to_integer(unsigned(a_rpl)) > n0 report "T1: no replay after LCRC error" severity failure;
    assert to_integer(unsigned(b_mwr)) = 1 report "T1: duplicate BAR0 write" severity failure;
    report "T1: PASS corrupted TLP never reached the TL; Nak + replay delivered it";

    -- ---------- T2: lost TLP, in-order recovery ----------
    m0 := to_integer(unsigned(b_mwr));
    c_drop_tlp(0) <= c_tlp_n(0);                 -- drop the first of the two
    hdr(B0_MWR3, 1, 3, 16#24#); put_dw(0, x"11112222"); inject(h, 16);
    hdr(B0_MWR3, 1, 4, 16#24#); put_dw(0, x"33334444"); inject(h, 16);
    wait_mwr(m0 + 2, "T2");
    c_drop_tlp(0) <= -1;
    idle(200);
    assert to_integer(unsigned(b_mwr)) = m0 + 2 report "T2: duplicate delivery" severity failure;
    read1(16#24#, 5, dw, "T2");
    assert dw = x"33334444" report "T2: out-of-order delivery (second write lost to the first)" severity failure;
    report "T2: PASS dropped TLP -> seq gap -> Nak -> in-order replay";

    -- ---------- T3: all Acks lost -> REPLAY_TIMER ----------
    n0 := to_integer(unsigned(a_rtmo));
    m0 := to_integer(unsigned(b_mwr));
    c_drop_all_dllp(1) <= '1';                   -- B->A DLLPs (Acks) lost
    hdr(B0_MWR3, 1, 6, 16#28#); put_dw(0, x"0BADF00D"); inject(h, 16);
    wait_mwr(m0 + 1, "T3");
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when to_integer(unsigned(a_rtmo)) > n0;
      assert c < 4*RPL_TMO report "T3: replay timer never fired" severity failure;
    end loop;
    c_drop_all_dllp(1) <= '0';
    idle(3*RPL_TMO);
    assert to_integer(unsigned(b_mwr)) = m0 + 1
      report "T3: replayed duplicate written twice" severity failure;
    read1(16#28#, 7, dw, "T3");
    assert dw = x"0BADF00D" report "T3: data wrong" severity failure;
    report "T3: PASS lost Acks -> REPLAY_TIMER -> duplicate discarded";

    -- ---------- T4: UR for MRd outside BAR0 ----------
    clr_q;
    hdr(B0_MRD3, 1, 16#55#, 16#00001000#); inject(h, 12);
    wait_qa(1, "T4");
    assert qa(0)(0) = B0_CPL report "T4: no Cpl for MRd outside BAR0" severity failure;
    assert qa(0)(6)(7 downto 5) = "001" report "T4: completion status is not UR" severity failure;
    assert qa(0)(10) = x"55" report "T4: tag not preserved" severity failure;
    assert to_integer(unsigned(b_ur)) = 1 report "T4: UR counter" severity failure;
    report "T4: PASS MRd outside BAR0 -> Cpl UR";

    -- ---------- T5: multi-DW read, RCB split ----------
    m0 := to_integer(unsigned(b_mwr));
    hdr(B0_MWR3, 20, 8, 16#30#);                 -- DW index 12..31
    for i in 0 to 19 loop put_dw(i, pat(i + 0)); end loop;
    inject(h, 12 + 80);
    wait_mwr(m0 + 20, "T5");
    clr_q;
    hdr(B0_MRD3, 20, 9, 16#30#); inject(h, 12);
    wait_qa(2, "T5");
    -- first CplD: idx 12..15 (4 DW, up to the 64-byte boundary), BC = 80
    assert qa(0)(0) = B0_CPLD and qa(0)(3) = x"04" and qa_len(0) = 12 + 16
      report "T5: first CplD length wrong" severity failure;
    assert qa(0)(6)(3 downto 0) & qa(0)(7) = x"050" report "T5: first Byte Count /= 80" severity failure;
    assert qa(0)(11) = x"30" report "T5: first Lower Address /= 0x30" severity failure;
    assert qa(1)(3) = x"10" and qa_len(1) = 12 + 64
      report "T5: second CplD length wrong" severity failure;
    assert qa(1)(6)(3 downto 0) & qa(1)(7) = x"040" report "T5: second Byte Count /= 64" severity failure;
    assert qa(1)(11) = x"40" report "T5: second Lower Address /= 0x40" severity failure;
    for i in 0 to 3 loop
      assert qdw(qa(0), 12+4*i) = pat(i + 0)
        report "T5: data of first CplD wrong" severity failure;
    end loop;
    for i in 0 to 15 loop
      assert qdw(qa(1), 12+4*i) = pat(i + 4)
        report "T5: data of second CplD wrong" severity failure;
    end loop;
    report "T5: PASS MRd 20 DW -> 2 CplDs split at RCB, data/BC/LA correct";

    -- ---------- T6: completion timeout ----------
    n0 := to_integer(unsigned(a_ctmo_cnt));
    c_drop_all_tlp(1) <= '1';                    -- B->A TLPs lost for a while
    hdr(B0_MRD3, 1, 16#66#, 16#20#); inject(h, 12);
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when to_integer(unsigned(a_ctmo_cnt)) > n0;
      assert c < 2*CPL_TMO report "T6: no completion timeout" severity failure;
    end loop;
    c_drop_all_tlp(1) <= '0';
    idle(4*RPL_TMO);                             -- let the late CplD drain
    report "T6: PASS completion timeout reported (" &
           integer'image(to_integer(unsigned(a_ctmo_cnt))) & ")";

    -- ---------- T7: REPLAY_NUM rollover -> Recovery -> L0 ----------
    n0 := to_integer(unsigned(a_retr));
    m0 := to_integer(unsigned(b_mwr));
    c_drop_all_tlp(0) <= '1';                    -- A->B TLPs lost: A replays
    hdr(B0_MWR3, 1, 10, 16#2C#); put_dw(0, x"5EC0FE11"); inject(h, 16);
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when to_integer(unsigned(a_retr)) > n0;
      assert c < 8*RPL_TMO report "T7: no retrain after repeated replays" severity failure;
    end loop;
    c_drop_all_tlp(0) <= '0';
    c := 0;
    loop                                          -- link must leave and re-enter L0
      wait until rising_edge(clk); c := c + 1;
      exit when a_up = '0' or b_up = '0';
      assert c < 2000 report "T7: link did not enter Recovery" severity failure;
    end loop;
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when a_up = '1' and b_up = '1';
      assert c < 20000 report "T7: link did not return to L0" severity failure;
    end loop;
    wait_mwr(m0 + 1, "T7", 6*RPL_TMO);
    read1(16#2C#, 11, dw, "T7");
    assert dw = x"5EC0FE11" report "T7: data wrong after Recovery" severity failure;
    report "T7: PASS replay rollover -> Recovery -> L0, traffic resumed";

    -- ---------- T8: MSI during a long incoming MWr ----------
    -- program MSI address/data (CfgWr0 0x50 / 0x54) and wait for the Cpls
    clr_q;
    hdr(B0_CFGWR0, 1, 12, 16#50#); put_dw(0, x"FEED0000"); inject(h, 16);
    hdr(B0_CFGWR0, 1, 13, 16#54#); put_dw(0, x"0000CAFE"); inject(h, 16);
    wait_qa(2, "T8 cfg");
    assert qa(0)(0) = B0_CPL and qa(1)(0) = B0_CPL report "T8: CfgWr0 without Cpl" severity failure;
    clr_q;
    m0 := to_integer(unsigned(b_mwr));
    hdr(B0_MWR3, 16, 14, 16#80#);
    for i in 0 to 15 loop put_dw(i, std_logic_vector(to_unsigned(16#77000000# + i, 32))); end loop;
    inject(h, 12 + 64);
    -- trigger the MSI while the EP is parsing/receiving that MWr
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when b_rx_v = '1' and b_rx_s = '1';
      assert c < 5000 report "T8: MWr not seen at EP" severity failure;
    end loop;
    wait until rising_edge(clk); wait until rising_edge(clk);
    b_msi <= '1'; wait until rising_edge(clk); b_msi <= '0';
    wait_mwr(m0 + 16, "T8");
    wait_qa(1, "T8 msi");
    assert qa(0)(0) = B0_MWR3 and qdw(qa(0), 8) = x"FEED0000" and qdw(qa(0), 12) = x"0000CAFE"
      report "T8: MSI wrong" severity failure;
    for i in 0 to 15 loop
      read1(16#80# + 4*i, 16#20# + i, dw, "T8");
      assert dw = std_logic_vector(to_unsigned(16#77000000# + i, 32))
        report "T8: MWr data clobbered by MSI at DW " & integer'image(i) severity failure;
    end loop;
    report "T8: PASS MSI during incoming MWr: MSI correct, data intact";

    -- ---------- T9: requests in both directions (TX arbiter) ----------
    -- A's own BAR0: write 8 DW first (MWr from B is not needed: A's completer
    -- answers B's MRds from its BAR0, which is zero after reset)
    clr_q;
    b_go <= '1';
    for r in 0 to 3 loop
      hdr(B0_MRD3, 2, 16#30# + r, 16#30# + 8*r); inject(h, 12);
    end loop;
    wait_qa(4 + 4, "T9", 60000);    -- 4 CplDs for A + 4 MRds from B (seen by A)
    c := 0;
    loop
      wait until rising_edge(clk); c := c + 1;
      exit when qb_n >= 8 and b_done = '1';   -- 4 MRd from A + 4 CplD for B
      assert c < 60000 report "T9: B did not get its 4 CplDs" severity failure;
    end loop;
    idle(100);
    -- A received 4 MRd (from B) and 4 CplD of 2 DW (tags 0x30..0x33) in some order
    n0 := 0;
    for i in 0 to 7 loop
      if qa(i)(0) = B0_CPLD then
        n0 := n0 + 1;
        assert qa_len(i) = 12 + 8 and qa(i)(3) = x"02" report "T9: CplD to A malformed" severity failure;
        c := to_integer(unsigned(qa(i)(10))) - 16#30#;
        assert c >= 0 and c < 4 report "T9: unexpected tag" severity failure;
        assert qdw(qa(i), 12) = pat(2*c + 0) and
               qdw(qa(i), 16) = pat(2*c + 1)
          report "T9: CplD data to A wrong" severity failure;
      else
        assert qa(i)(0) = B0_MRD3 and qa_len(i) = 12 report "T9: request from B malformed" severity failure;
      end if;
    end loop;
    assert n0 = 4 report "T9: A did not get 4 CplDs" severity failure;
    m0 := 0;
    for i in 0 to 7 loop
      if qb(i)(0) = B0_CPLD then
        m0 := m0 + 1;
        assert qb_len(i) = 12 + 8 and qb(i)(3) = x"02" and qb(i)(10)(7 downto 4) = x"4"
          report "T9: CplD to B malformed" severity failure;
      else
        assert qb(i)(0) = B0_MRD3 and qb_len(i) = 12 report "T9: request from A malformed" severity failure;
      end if;
    end loop;
    assert m0 = 4 report "T9: B did not get 4 CplDs" severity failure;
    report "T9: PASS concurrent requests/completions, TLPs kept whole";

    report "link stats: A replays=" & integer'image(to_integer(unsigned(a_rpl))) &
           " A rpl_tmo=" & integer'image(to_integer(unsigned(a_rtmo))) &
           " B bad_rx=" & integer'image(to_integer(unsigned(b_bad))) &
           " A retrain=" & integer'image(to_integer(unsigned(a_retr))) &
           " A cpl_tmo=" & integer'image(to_integer(unsigned(a_ctmo_cnt)));
    report "FIN SIMULACION LINK: PASS @ " & time'image(now);
    fin <= true; wait;
  end process;
end architecture;
