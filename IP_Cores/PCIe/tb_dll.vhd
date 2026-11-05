-- ============================================================================
-- tb_dll.vhd -- PCIE IP, Data Link Layer unit bench (rewritten audit 2026-11)
--
-- DLL_TX -> [channel: store-and-forward like the framer; can corrupt a byte,
-- drop a whole TLP, honours fr_abort] -> DLL_RX -> pcie_rx_tlp_fifo -> reader.
-- DLL_RX Ack/Nak requests (an_*) go back to DLL_TX ak_* through an "ack
-- channel" that can be blocked (backpressure) or lose Acks.
-- The reader checks every delivered TLP: exactly once, in order, bit-exact
-- (TLP k has length len_of(k) and byte j = (7k + j) mod 256).
-- Self-checking, severity failure. Scenarios:
--   A clean traffic                    B LCRC corrupted -> Nak -> replay
--   C payload corrupted -> Nak         D acks blocked: TX must stop at
--                                        REPLAY_SLOTS outstanding (no overwrite)
--   E 160 TLPs, random lengths, random corruption: replay buffer wraps
--   F last TLP lost and its Ack never comes: REPLAY_TIMER recovers
--   G same TLP lost 5 times: REPLAY_NUM rollover -> retrain_req
--   H TLP longer than MAX_TLP: dropped, no sequence number consumed
-- D, E, G and H fail on the pre-audit DLL (no free-slot check, no pointer
-- wrap, no replay timer / REPLAY_NUM, no MAX_TLP enforcement).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.pcie_dll_pkg.all;

entity tb_dll is
end entity;

architecture sim of tb_dll is
  constant TCLK    : time := 10 ns;
  constant MAX_TLP : integer := 128;
  constant SLOTS   : integer := 8;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst : std_logic := '1';

  signal tl_valid, tl_last, tl_ready : std_logic := '0';
  signal tl_data : byte_t := (others=>'0');
  signal fr_valid, fr_last, fr_start, fr_abort : std_logic;
  signal fr_ready : std_logic := '1';
  signal fr_data : byte_t;
  signal in_valid, in_start, in_last : std_logic := '0';
  signal in_data : byte_t := (others=>'0');

  signal f_wr, f_last, f_commit, f_rollback, f_ovf : std_logic;
  signal f_data : byte_t;
  signal f_space : unsigned(9 downto 0);
  signal rd_valid, rd_start, rd_last, rd_ready : std_logic;
  signal rd_data : byte_t;

  signal an_valid, an_is_nak, an_ready : std_logic;
  signal an_seq : std_logic_vector(11 downto 0);
  signal ak_valid, ak_is_nak : std_logic := '0';
  signal ak_seq : std_logic_vector(11 downto 0) := (others => '0');
  signal retrain : std_logic;

  signal nseq, acked, nextrx : std_logic_vector(11 downto 0);
  signal inflight : std_logic_vector(7 downto 0);
  signal replays, tmos, ovsz, akerr, good_rx, bad_rx, dup_rx, nak_rx : std_logic_vector(15 downto 0);

  -- channel controls
  signal corrupt_tlp, corrupt_pos : integer := -1;   -- channel packet index
  signal drop_tlp_from, drop_count : integer := -1;  -- drop packets [from, from+count)
  signal pkt_idx : integer := 0;                     -- packets seen by the channel
  signal ack_block : std_logic := '0';               -- hold Ack/Nak (an_ready=0)
  signal ack_lose  : std_logic := '0';               -- accept Ack/Nak but lose it
  signal rnd_corrupt : std_logic := '0';             -- random corruption (E)
  signal retrain_seen : integer := 0;
  signal sent_tlps : integer := 0;                   -- TLPs accepted by the TX
  signal rcv_tlps  : integer := 0;                   -- TLPs checked by the reader

  function len_of(k : integer) return integer is
  begin
    return 12 + ((k * 37) mod 100);                  -- 12..111 bytes
  end function;
  function byte_of(k, j : integer) return byte_t is
  begin
    return std_logic_vector(to_unsigned((7*k + j) mod 256, 8));
  end function;
begin
  clk <= '0' when fin else not clk after TCLK/2;

  u_tx : entity work.pcie_dll_tx
    generic map (MAX_TLP => MAX_TLP, REPLAY_SLOTS => SLOTS, RB_LOG2 => 10,
                 REPLAY_TMO => 1500)
    port map (clk=>clk, rst=>rst, link_up=>'1',
              tl_valid=>tl_valid, tl_data=>tl_data, tl_last=>tl_last,
              tl_ready=>tl_ready,
              fr_valid=>fr_valid, fr_data=>fr_data, fr_last=>fr_last,
              fr_start=>fr_start, fr_abort=>fr_abort, fr_ready=>fr_ready,
              ak_valid=>ak_valid, ak_is_nak=>ak_is_nak, ak_seq=>ak_seq,
              retrain_req=>retrain,
              nseq_o=>nseq, acked_o=>acked, inflight_o=>inflight,
              replays_o=>replays, tmo_o=>tmos, ovsz_o=>ovsz, akerr_o=>akerr);

  u_rx : entity work.pcie_dll_rx
    generic map (MAX_TLP => MAX_TLP, ACKNAK_LAT => 20)
    port map (clk=>clk, rst=>rst,
              in_valid=>in_valid, in_data=>in_data, in_start=>in_start,
              in_last=>in_last, in_abort=>'0',
              f_wr=>f_wr, f_data=>f_data, f_last=>f_last,
              f_commit=>f_commit, f_rollback=>f_rollback,
              f_ovf=>f_ovf, f_space=>f_space,
              an_valid=>an_valid, an_is_nak=>an_is_nak, an_seq=>an_seq,
              an_ready=>an_ready,
              good_o=>good_rx, bad_o=>bad_rx, dup_o=>dup_rx, nak_o=>nak_rx,
              nextrx_o=>nextrx);

  u_buf : entity work.pcie_rx_tlp_fifo
    generic map (LOG2_DEPTH => 9)
    port map (clk=>clk, rst=>rst, wr_en=>f_wr, wr_data=>f_data, wr_last=>f_last,
              commit=>f_commit, rollback=>f_rollback, wr_ovf=>f_ovf, wr_space=>f_space,
              rd_valid=>rd_valid, rd_data=>rd_data, rd_start=>rd_start,
              rd_last=>rd_last, rd_ready=>rd_ready);

  -- ---------------- ack channel ----------------
  an_ready <= not ack_block;
  process(clk)
  begin
    if rising_edge(clk) then
      ak_valid <= '0';
      if an_valid = '1' and an_ready = '1' and ack_lose = '0' then
        ak_valid <= '1'; ak_is_nak <= an_is_nak; ak_seq <= an_seq;
      end if;
      if retrain = '1' then retrain_seen <= retrain_seen + 1; end if;
    end if;
  end process;

  -- ---------------- framer-like channel (store-and-forward) ----------------
  chan : process
    type pkt_t is array (0 to 255) of byte_t;
    variable pk : pkt_t;
    variable n  : integer := 0;
    variable s1 : positive := 77; variable s2 : positive := 991;
    variable rr : real;
    variable drop, abort : boolean;
  begin
    wait until rising_edge(clk);
    -- random framer backpressure
    uniform(s1, s2, rr);
    if rr < 0.2 then fr_ready <= '0'; else fr_ready <= '1'; end if;
    if fr_valid = '1' and fr_ready = '1' then
      if fr_start = '1' then n := 0; end if;
      if n < 256 then pk(n) := fr_data; n := n + 1; end if;
      if fr_last = '1' then
        abort := fr_abort = '1';
        if not abort then
          drop := drop_tlp_from >= 0 and pkt_idx >= drop_tlp_from and
                  pkt_idx < drop_tlp_from + drop_count;
          if pkt_idx = corrupt_tlp and corrupt_pos >= 0 and corrupt_pos < n then
            pk(corrupt_pos) := pk(corrupt_pos) xor x"5A";
          end if;
          if rnd_corrupt = '1' then
            uniform(s1, s2, rr);
            if rr < 0.08 then
              uniform(s1, s2, rr);
              pk(integer(floor(rr * real(n-1)))) := pk(integer(floor(rr * real(n-1)))) xor x"01";
            end if;
          end if;
          pkt_idx <= pkt_idx + 1;
          if not drop then
            fr_ready <= '0';
            for i in 0 to n-1 loop
              in_valid <= '1'; in_data <= pk(i);
              if i = 0 then in_start <= '1'; else in_start <= '0'; end if;
              if i = n-1 then in_last <= '1'; else in_last <= '0'; end if;
              wait until rising_edge(clk);
            end loop;
            in_valid <= '0'; in_start <= '0'; in_last <= '0';
            -- inter-packet gap of the real framer (END + idle)
            wait until rising_edge(clk);
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ---------------- reader / scoreboard ----------------
  reader : process
    variable s1 : positive := 3; variable s2 : positive := 8;
    variable rr : real;
    variable j, k : integer := 0;
  begin
    rd_ready <= '0';
    wait until rising_edge(clk);
    loop
      uniform(s1, s2, rr);
      if rr < 0.85 then rd_ready <= '1'; else rd_ready <= '0'; end if;
      wait until rising_edge(clk);
      if rd_valid = '1' and rd_ready = '1' then
        if rd_start = '1' then
          assert j = 0 report "reader: start inside a TLP" severity failure;
        end if;
        assert rd_data = byte_of(k, j)
          report "reader: TLP " & integer'image(k) & " byte " & integer'image(j) &
                 " wrong (duplicate, loss or corruption delivered)" severity failure;
        if rd_last = '1' then
          assert j = len_of(k) - 1
            report "reader: TLP " & integer'image(k) & " has wrong length" severity failure;
          j := 0; k := k + 1; rcv_tlps <= k;
        else
          j := j + 1;
        end if;
      end if;
    end loop;
  end process;

  -- ---------------- stimulus ----------------
  main : process
    variable k : integer := 0;     -- next TLP index the reader expects us to send

    procedure send_raw(len : integer; idx : integer) is
    begin
      for j in 0 to len-1 loop
        tl_valid <= '1'; tl_data <= byte_of(idx, j);
        if j = len-1 then tl_last <= '1'; else tl_last <= '0'; end if;
        loop wait until rising_edge(clk); exit when tl_ready = '1'; end loop;
      end loop;
      tl_valid <= '0'; tl_last <= '0';
    end procedure;
    procedure send(n : integer) is
    begin
      for i in 1 to n loop
        send_raw(len_of(k), k);
        k := k + 1; sent_tlps <= k;
      end loop;
    end procedure;
    procedure drain(msg : string; lim : integer := 200000) is
      variable c : integer := 0;
    begin
      loop
        wait until rising_edge(clk); c := c + 1;
        exit when rcv_tlps = k and to_integer(unsigned(inflight)) = 0;
        assert c < lim
          report msg & ": not drained (rcv=" & integer'image(rcv_tlps) & "/" &
                 integer'image(k) & ", inflight=" &
                 integer'image(to_integer(unsigned(inflight))) & ")" severity failure;
      end loop;
    end procedure;
    variable r0, t0, g0 : integer;
    variable c : integer;
  begin
    rst <= '1'; for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);

    -- A: clean
    send(20); drain("A");
    assert to_integer(unsigned(replays)) = 0 report "A: unexpected replay" severity failure;
    report "A: PASS 20 clean TLPs, delivered in order, inflight=0";

    -- B: LCRC of the 4th packet corrupted
    r0 := to_integer(unsigned(replays));
    corrupt_tlp <= pkt_idx + 3; corrupt_pos <= len_of(k+3) + 4;   -- last LCRC byte
    send(10); drain("B");
    assert to_integer(unsigned(replays)) > r0 report "B: no replay after LCRC error" severity failure;
    report "B: PASS LCRC error -> Nak -> replay, 10 delivered once";

    -- C: payload byte corrupted
    r0 := to_integer(unsigned(replays));
    corrupt_tlp <= pkt_idx + 2; corrupt_pos <= 7;
    send(6); drain("C");
    assert to_integer(unsigned(replays)) > r0 report "C: payload error not caught" severity failure;
    corrupt_tlp <= -1;
    report "C: PASS payload corruption -> Nak -> replay";

    -- D: acks blocked -> at most SLOTS outstanding, then backpressure
    ack_block <= '1';
    t0 := k;
    for i in 1 to SLOTS + 4 loop
      -- offer one TLP; give up (without consuming the index) if TX stalls
      c := 0;
      tl_valid <= '1'; tl_data <= byte_of(k, 0); tl_last <= '0';
      loop
        wait until rising_edge(clk); c := c + 1;
        exit when tl_ready = '1' or c > 3000;
      end loop;
      if c > 3000 then tl_valid <= '0'; exit; end if;
      for j in 1 to len_of(k)-1 loop
        tl_data <= byte_of(k, j);
        if j = len_of(k)-1 then tl_last <= '1'; end if;
        loop wait until rising_edge(clk); exit when tl_ready = '1'; end loop;
      end loop;
      tl_valid <= '0'; tl_last <= '0';
      k := k + 1; sent_tlps <= k;
    end loop;
    assert k - t0 = SLOTS
      report "D: TX accepted " & integer'image(k - t0) & " TLPs with acks blocked (expected " &
             integer'image(SLOTS) & ")" severity failure;
    assert to_integer(unsigned(inflight)) = SLOTS report "D: inflight wrong" severity failure;
    ack_block <= '0';
    send(4); drain("D");
    report "D: PASS free-slot check: TX stalls at " & integer'image(SLOTS) &
           " outstanding TLPs, no replay-slot overwrite";

    -- E: long random run (replay buffer wraps many times)
    r0 := to_integer(unsigned(replays));
    rnd_corrupt <= '1';
    send(160); drain("E", 2000000);
    rnd_corrupt <= '0';
    report "E: PASS 160 TLPs with random corruption, replay buffer wrapped, " &
           "replays=" & integer'image(to_integer(unsigned(replays)) - r0);

    -- F: last packet lost, no later TLP to provoke a Nak -> REPLAY_TIMER
    t0 := to_integer(unsigned(tmos));
    drop_tlp_from <= pkt_idx + 2; drop_count <= 1;
    wait until rising_edge(clk);
    send(3);
    drain("F");
    assert to_integer(unsigned(tmos)) > t0 report "F: replay timer did not fire" severity failure;
    drop_tlp_from <= -1;
    report "F: PASS lost TLP recovered by REPLAY_TIMER";

    -- G: the same TLP lost 5 times -> REPLAY_NUM rollover -> retrain request
    g0 := retrain_seen;
    drop_tlp_from <= pkt_idx; drop_count <= 5;
    wait until rising_edge(clk);
    send(1);
    drain("G", 400000);
    assert retrain_seen > g0 report "G: no retrain request on REPLAY_NUM rollover" severity failure;
    drop_tlp_from <= -1;
    report "G: PASS REPLAY_NUM rollover -> retrain_req";

    -- H: oversize TLP dropped, the next one goes through with the next seq
    r0 := to_integer(unsigned(ovsz));
    send_raw(MAX_TLP + 10, 999);        -- not expected by the reader
    send(2); drain("H");
    assert to_integer(unsigned(ovsz)) = r0 + 1 report "H: oversize TLP not dropped" severity failure;
    report "H: PASS TLP > MAX_TLP dropped, sequence space unaffected";

    report "DLL stats: good=" & integer'image(to_integer(unsigned(good_rx))) &
           " bad=" & integer'image(to_integer(unsigned(bad_rx))) &
           " dup=" & integer'image(to_integer(unsigned(dup_rx))) &
           " nak=" & integer'image(to_integer(unsigned(nak_rx))) &
           " replays=" & integer'image(to_integer(unsigned(replays))) &
           " tmo=" & integer'image(to_integer(unsigned(tmos)));
    report "FIN SIMULACION DLL: PASS @ " & time'image(now);
    fin <= true; wait;
  end process;
end architecture;
