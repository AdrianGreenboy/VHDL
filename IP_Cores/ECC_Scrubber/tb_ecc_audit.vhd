-- tb_ecc_audit.vhd - Audit 2026-11 regression for the scrubber register bank.
-- Self-checking (assert ... severity failure). Runs against ecc_regbank
-- (SI=false, map at 0x00) or ecc_regbank_si (SI=true, map at 0x40).
-- Every check below fails on the pre-audit RTL:
--   T1 re-arm      : a second CONTROL.start after DONE must run a new sweep.
--   T2 W1C         : STATUS.ce (bit3) clears on write-1, counters untouched.
--   T3 clr_cnt     : CONTROL bit2 clears CE/DED counters.
--   T4 arbitration : an immediate injection issued while a sweep is running
--                    must not be serviced mid-sweep (it is applied after it).
--   T5 torn read   : LO then HI of the same window word must be one snapshot
--                    even if the word is modified between the two accesses.
--   T6 region      : REGION_BASE/LEN sweep only the region, with wrap.
--   T7 periodic    : PERIOD re-triggers sweeps without a CPU start.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ecc_pkg.all;

entity tb_ecc_audit is
  generic (SI : boolean := false);
end entity;

architecture sim of tb_ecc_audit is
  constant DEPTH : natural := 32;
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal sel, wr : std_logic := '0';
  signal addr  : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal ready : std_logic;

  function B return natural is begin if SI then return 16#40#; else return 0; end if; end;
  constant R_STATUS   : natural := 16#04#;
  constant R_CONTROL  : natural := 16#08#;
  constant R_RBASE    : natural := 16#0C#;
  constant R_RLEN     : natural := 16#10#;
  constant R_PERIOD   : natural := 16#14#;
  constant R_CE       : natural := 16#18#;
  constant R_LASTADDR : natural := 16#28#;
  constant R_INJADDR  : natural := 16#30#;
  constant R_MASKLO   : natural := 16#34#;
  constant R_MASKHI   : natural := 16#38#;
  constant R_INJCTRL  : natural := 16#3C#;

  type mem_t is array (0 to DEPTH-1) of ecc_t;
begin
  clk <= not clk after 5 ns;

  g_plain : if not SI generate
    dut : entity work.ecc_regbank
      generic map (DEPTH => DEPTH, INITFILE => "layer3_init.txt")
      port map (clk => clk, rst => rst, sel => sel, wr => wr,
                addr => addr, wdata => wdata, rdata => rdata, ready => ready);
  end generate;
  g_si : if SI generate
    dut : entity work.ecc_regbank_si
      generic map (DEPTH => DEPTH, INITFILE => "layer3_init.txt")
      port map (clk => clk, rst => rst, sel => sel, wr => wr,
                addr => addr, wdata => wdata, rdata => rdata, ready => ready);
  end generate;

  stim : process
    variable v    : std_logic_vector(31 downto 0);
    variable snap : mem_t;
    variable w    : ecc_t;
    variable lo   : std_logic_vector(31 downto 0);
    variable ce0  : natural;

    procedure wreg(off : natural; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(B + off, 16)); wdata <= d;
      sel <= '1'; wr <= '1';
      wait until rising_edge(clk);
      sel <= '0'; wr <= '0';
      wait until rising_edge(clk);
    end procedure;

    procedure raddr16(a : natural; d : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 16));
      sel <= '1'; wr <= '0';
      loop
        wait until rising_edge(clk);
        exit when ready = '1';
      end loop;
      d := rdata;
      sel <= '0';
      wait until rising_edge(clk);
    end procedure;

    procedure rreg(off : natural; d : out std_logic_vector(31 downto 0)) is
    begin
      raddr16(B + off, d);
    end procedure;

    procedure rword(i : natural; d : out ecc_t) is
      variable l, h : std_logic_vector(31 downto 0);
    begin
      raddr16(16#1000# + i*8, l);
      raddr16(16#1000# + i*8 + 4, h);
      d := h(6 downto 0) & l;
    end procedure;

    procedure wait_done is
      variable s : std_logic_vector(31 downto 0);
    begin
      for k in 0 to 2000 loop
        rreg(R_STATUS, s);
        if s(1) = '1' and s(0) = '0' then return; end if;
      end loop;
      assert false report "timeout waiting for sweep DONE" severity failure;
    end procedure;

    procedure inject_now(i : natural; lo_m, hi_m : std_logic_vector(31 downto 0)) is
    begin
      wreg(R_INJADDR, std_logic_vector(to_unsigned(i, 32)));
      wreg(R_MASKLO, lo_m);
      wreg(R_MASKHI, hi_m);
      wreg(R_INJCTRL, x"00000003");   -- arm + immediate
    end procedure;

    procedure check_word(i : natural; exp : ecc_t; msg : string) is
      variable got : ecc_t;
    begin
      rword(i, got);
      assert got = exp
        report msg & ": word " & integer'image(i) & " mismatch" severity failure;
    end procedure;
  begin
    rst <= '1';
    for k in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0';
    wait until rising_edge(clk);

    -- baseline: one sweep cleans every correctable word
    wreg(R_CONTROL, x"00000003");          -- start, oneshot
    wait_done;
    for i in 0 to DEPTH-1 loop rword(i, snap(i)); end loop;

    -- ---------------- T1: re-arm after DONE ----------------------------
    inject_now(5, x"00000010", x"00000000");   -- 1-bit error in word 5
    check_word(5, snap(5) xor ("0000000" & x"00000010"), "T1 pre");
    wreg(R_CONTROL, x"00000003");
    rreg(R_STATUS, v);
    assert v(1) = '0' report "T1: STATUS.done still set right after a new start" severity failure;
    wait_done;
    rreg(R_CE, v);
    assert unsigned(v) = 1 report "T1: second sweep did not run (CE /= 1)" severity failure;
    check_word(5, snap(5), "T1 corrected");
    report "T1 PASS re-arm from DONE";

    -- ---------------- T2: W1C sticky ----------------------------------
    rreg(R_STATUS, v);
    assert v(3) = '1' report "T2: STATUS.ce not set" severity failure;
    wreg(R_STATUS, x"00000008");
    rreg(R_STATUS, v);
    assert v(3) = '0' report "T2: STATUS.ce not cleared by W1C" severity failure;
    rreg(R_CE, v);
    assert unsigned(v) = 1 report "T2: W1C must not touch CE_COUNT" severity failure;
    report "T2 PASS W1C sticky";

    -- ---------------- T3: clr_cnt -------------------------------------
    wreg(R_CONTROL, x"00000004");
    rreg(R_CE, v);
    assert unsigned(v) = 0 report "T3: CONTROL.clr_cnt did not clear CE_COUNT" severity failure;
    report "T3 PASS clr_cnt";

    -- ---------------- T4: injection during a running sweep ------------
    -- start a sweep and immediately issue an immediate injection into the
    -- LAST word (which the sweep has not reached yet). The injection must be
    -- deferred until the sweep is over, so the word stays corrupted and the
    -- sweep must not have counted it.
    addr <= std_logic_vector(to_unsigned(B + R_INJADDR, 16)); wdata <= std_logic_vector(to_unsigned(DEPTH-1, 32));
    sel <= '1'; wr <= '1'; wait until rising_edge(clk);
    addr <= std_logic_vector(to_unsigned(B + R_MASKLO, 16)); wdata <= x"00000100";
    wait until rising_edge(clk);
    addr <= std_logic_vector(to_unsigned(B + R_MASKHI, 16)); wdata <= x"00000000";
    wait until rising_edge(clk);
    addr <= std_logic_vector(to_unsigned(B + R_CONTROL, 16)); wdata <= x"00000003";
    wait until rising_edge(clk);
    addr <= std_logic_vector(to_unsigned(B + R_INJCTRL, 16)); wdata <= x"00000003";
    wait until rising_edge(clk);
    sel <= '0'; wr <= '0';
    wait until rising_edge(clk);
    wait_done;
    for k in 0 to 10 loop wait until rising_edge(clk); end loop;
    rreg(R_CE, v);
    assert unsigned(v) = 0 report "T4: injection was serviced in the middle of the sweep (CE /= 0)" severity failure;
    for i in 0 to DEPTH-2 loop check_word(i, snap(i), "T4 untouched"); end loop;
    check_word(DEPTH-1, snap(DEPTH-1) xor ("0000000" & x"00000100"), "T4 injected");
    -- clean it again for the next tests
    wreg(R_CONTROL, x"00000003"); wait_done;
    check_word(DEPTH-1, snap(DEPTH-1), "T4 cleanup");
    report "T4 PASS injector / sweep arbitration";

    -- ---------------- T5: torn LO/HI read -----------------------------
    raddr16(16#1000# + 7*8, lo);                       -- LO of word 7
    inject_now(7, x"00000001", x"00000001");           -- flips bit0 and bit32
    raddr16(16#1000# + 7*8 + 4, v);                    -- HI of word 7
    w := v(6 downto 0) & lo;
    assert w = snap(7)
      report "T5: torn window read (LO and HI from different word versions)" severity failure;
    -- a fresh LO/HI pair now returns the new (injected) word
    check_word(7, snap(7) xor ("0000001" & x"00000001"), "T5 fresh");
    -- restore word 7 (2-bit error is uncorrectable -> undo with the same mask)
    inject_now(7, x"00000001", x"00000001");
    check_word(7, snap(7), "T5 restore");
    report "T5 PASS atomic window snapshot";

    -- ---------------- T6: region sweep with wrap ----------------------
    inject_now(1, x"00000004", x"00000000");   -- inside the region
    inject_now(5, x"00000004", x"00000000");   -- outside the region
    inject_now(30, x"00000004", x"00000000");  -- inside (before the wrap)
    wreg(R_RBASE, std_logic_vector(to_unsigned(30, 32)));
    wreg(R_RLEN,  std_logic_vector(to_unsigned(4, 32)));   -- 30,31,0,1
    wreg(R_CONTROL, x"00000003"); wait_done;
    rreg(R_CE, v);
    assert unsigned(v) = 2 report "T6: region sweep CE /= 2" severity failure;
    rreg(R_LASTADDR, v);
    assert unsigned(v) = 1 report "T6: LAST_ADDR should be 1 (wrapped)" severity failure;
    check_word(1, snap(1), "T6 inside");
    check_word(30, snap(30), "T6 inside");
    check_word(5, snap(5) xor ("0000000" & x"00000004"), "T6 outside");
    wreg(R_RLEN, std_logic_vector(to_unsigned(0, 32)));       -- empty region
    wreg(R_CONTROL, x"00000003"); wait_done;
    rreg(R_CE, v);
    assert unsigned(v) = 0 report "T6: empty region must not count" severity failure;
    wreg(R_RBASE, x"00000000");
    wreg(R_RLEN,  std_logic_vector(to_unsigned(DEPTH, 32)));
    report "T6 PASS region base/len with wrap";

    -- ---------------- T7: periodic scrubbing --------------------------
    wreg(R_PERIOD, std_logic_vector(to_unsigned(40, 32)));
    wreg(R_CONTROL, x"00000001");          -- start, periodic (oneshot = 0)
    wait_done;                             -- this sweep corrects word 5
    rreg(R_STATUS, v);
    assert v(4) = '1' report "T7: periodic trigger not armed" severity failure;
    rreg(R_CE, v); ce0 := to_integer(unsigned(v));
    inject_now(9, x"00010000", x"00000000");
    -- no CPU start: wait for at least one periodic sweep
    for k in 0 to 600 loop wait until rising_edge(clk); end loop;
    wait_done;
    check_word(9, snap(9), "T7 periodic correction");
    rreg(R_CE, v);
    assert to_integer(unsigned(v)) = ce0 + 1
      report "T7: periodic sweep did not accumulate CE" severity failure;
    wreg(R_PERIOD, x"00000000");           -- disarm
    rreg(R_STATUS, v);
    assert v(4) = '0' report "T7: PERIOD=0 did not disarm" severity failure;
    report "T7 PASS periodic scrubbing";

    report "TB_ECC_AUDIT PASS (SI=" & boolean'image(SI) & ")";
    std.env.finish;
  end process;
end architecture;
