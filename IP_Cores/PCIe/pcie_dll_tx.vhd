-- ============================================================================
-- pcie_dll_tx.vhd -- PCIE IP (rewritten in audit 2026-11)
-- Data Link Layer TX: sequence numbers, LCRC-32, replay buffer, Ack/Nak
-- processing (from the PEER's Ack/Nak DLLPs), REPLAY_TIMER and REPLAY_NUM.
--
-- Stream to the framer (pcie_tlp_frame, store-and-forward):
--   [seq_hi][seq_lo][header+payload...][lcrc0][lcrc1][lcrc2][lcrc3]
-- fr_start flags the first byte, fr_last the last one. fr_abort (with
-- fr_last) tells the framer to discard the packet (oversize TLP from the TL).
-- Handshake: a byte transfers on a rising edge with fr_valid='1' and
-- fr_ready='1'; the DLL holds the byte otherwise.
--
-- Replay buffer: circular byte memory of 2**RB_LOG2 bytes (1W/1R, registered
-- read) + per-slot (base,len) metadata, slot = seq mod REPLAY_SLOTS.
--   * a new TLP is accepted only if a slot is free AND at least MAX_TLP bytes
--     are free (otherwise tl_ready stays low = backpressure to the TL);
--   * pointers wrap modulo the buffer size;
--   * a TLP longer than MAX_TLP is dropped (framer abort, no seq consumed,
--     oversize counter++).
-- Ack/Nak (spec semantics, 12-bit modular arithmetic):
--   ACKD_SEQ starts at 4095, NEXT_TRANSMIT_SEQ at 0.
--   Ack(n)/Nak(n) with (n - ACKD_SEQ) mod 4096 <= inflight purges up to n,
--   resets REPLAY_NUM and REPLAY_TIMER; a Nak then replays every TLP still
--   unacknowledged, in order. Out-of-window Ack/Nak are ignored (counted).
--   REPLAY_TIMER expiry (REPLAY_TMO cycles without forward progress while
--   TLPs are outstanding) also replays. REPLAY_NUM is 2 bits: the 4th
--   consecutive replay without progress rolls it over and pulses
--   retrain_req (Data Link -> LTSSM: go to Recovery); the replay still runs.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_dll_pkg.all;

entity pcie_dll_tx is
  generic (
    MAX_TLP      : integer := 128;   -- max header+payload bytes per TLP
    REPLAY_SLOTS : integer := 8;     -- power of 2, <= 2048
    RB_LOG2      : integer := 10;    -- replay buffer = 2**RB_LOG2 bytes
    REPLAY_TMO   : integer := 4000   -- REPLAY_TIMER limit (cycles)
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    link_up   : in  std_logic := '1';   -- '0': hold timers, start nothing new

    tl_valid  : in  std_logic;
    tl_data   : in  byte_t;
    tl_last   : in  std_logic;
    tl_ready  : out std_logic;

    fr_valid  : out std_logic;
    fr_data   : out byte_t;
    fr_last   : out std_logic;
    fr_start  : out std_logic;   -- with the first byte of a packet
    fr_abort  : out std_logic;   -- with fr_last: discard this packet
    fr_ready  : in  std_logic;

    -- Ack/Nak received from the link partner (decoded DLLP)
    ak_valid  : in  std_logic;
    ak_is_nak : in  std_logic;
    ak_seq    : in  std_logic_vector(11 downto 0);

    retrain_req : out std_logic;     -- pulse: REPLAY_NUM rollover

    nseq_o    : out std_logic_vector(11 downto 0);
    acked_o   : out std_logic_vector(11 downto 0);
    inflight_o: out std_logic_vector(7 downto 0);
    replays_o : out std_logic_vector(15 downto 0);
    tmo_o     : out std_logic_vector(15 downto 0);   -- replay timer expiries
    ovsz_o    : out std_logic_vector(15 downto 0);   -- dropped oversize TLPs
    akerr_o   : out std_logic_vector(15 downto 0)    -- out-of-window Ack/Nak
  );
end entity;

architecture rtl of pcie_dll_tx is
  constant RB      : integer := 2**RB_LOG2;
  subtype ptr_t is unsigned(RB_LOG2 downto 0);    -- one extra bit (used count)

  type ram_t is array (0 to RB-1) of byte_t;
  signal ram : ram_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";
  signal ram_q : byte_t := (others => '0');

  type base_t is array (0 to REPLAY_SLOTS-1) of ptr_t;
  type len_t  is array (0 to REPLAY_SLOTS-1) of integer range 0 to MAX_TLP;
  signal slot_base : base_t := (others => (others => '0'));
  signal slot_len  : len_t  := (others => 0);

  type tstate_t is (T_IDLE, T_NEW_SEQ, T_NEW_PAY, T_NEW_CRC, T_NEW_DRAIN,
                    T_RPL_NEXT, T_RPL_SEQ, T_RPL_PAY, T_RPL_CRC);
  signal st : tstate_t := T_IDLE;

  signal nseq    : seq_t := (others => '0');            -- NEXT_TRANSMIT_SEQ
  signal acked   : seq_t := (others => '1');            -- ACKD_SEQ = 4095
  signal inflight: natural range 0 to 4095;
  signal wr_ptr, free_ptr : ptr_t := (others => '0');
  signal used    : ptr_t;

  signal cur_len : integer range 0 to MAX_TLP := 0;
  signal crc     : crc32_t := LCRC_SEED;
  signal crc_fin : crc32_t := (others => '0');
  signal ci      : integer range 0 to 3 := 0;
  signal sbyte   : std_logic := '0';
  signal fv      : std_logic := '0';

  signal rpl_req  : std_logic := '0';
  signal rpl_seq  : seq_t := (others => '0');
  signal rpl_i    : integer range 0 to MAX_TLP := 0;
  signal rpl_len  : integer range 0 to MAX_TLP := 0;
  signal rpl_base : ptr_t := (others => '0');
  signal q_v      : std_logic := '0';
  signal replay_num : unsigned(1 downto 0) := (others => '0');
  signal rtimer   : integer range 0 to REPLAY_TMO := 0;
  signal rt_run   : std_logic := '0';

  signal replays, tmos, ovsz, akerr : unsigned(15 downto 0) := (others => '0');
  signal adv     : std_logic;
  signal can_new : std_logic;

  function seq_hi(s : seq_t) return byte_t is
  begin return "0000" & std_logic_vector(s(11 downto 8)); end function;
  function seq_lo(s : seq_t) return byte_t is
  begin return std_logic_vector(s(7 downto 0)); end function;
  function slot_of(s : seq_t) return integer is
  begin return to_integer(s) mod REPLAY_SLOTS; end function;
  function ra(p : ptr_t) return integer is
  begin return to_integer(p(RB_LOG2-1 downto 0)); end function;
begin
  assert 2**(RB_LOG2) >= 2*MAX_TLP report "replay buffer too small" severity failure;

  inflight <= f_sdist(nseq, acked) - 1 when nseq /= acked + 1 else 0;
  used     <= wr_ptr - free_ptr;
  adv      <= '1' when fv = '0' or fr_ready = '1' else '0';
  can_new  <= '1' when link_up = '1' and rpl_req = '0' and inflight < REPLAY_SLOTS
                       and (to_unsigned(RB, RB_LOG2+1) - used) >= MAX_TLP else '0';

  fr_valid   <= fv;
  nseq_o     <= std_logic_vector(nseq);
  acked_o    <= std_logic_vector(acked);
  inflight_o <= std_logic_vector(to_unsigned(inflight mod 256, 8));
  replays_o  <= std_logic_vector(replays);
  tmo_o      <= std_logic_vector(tmos);
  ovsz_o     <= std_logic_vector(ovsz);
  akerr_o    <= std_logic_vector(akerr);
  tl_ready   <= '1' when (st = T_NEW_PAY and adv = '1') or st = T_NEW_DRAIN else '0';

  process(clk)
    variable a      : seq_t;
    variable d      : natural;
    variable progress : boolean;
    variable infl_v : natural;
    variable pos    : natural;
    variable rs     : seq_t;
  begin
    if rising_edge(clk) then
      retrain_req <= '0';
      if rst = '1' then
        st <= T_IDLE; nseq <= (others=>'0'); acked <= (others=>'1');
        wr_ptr <= (others=>'0'); free_ptr <= (others=>'0');
        cur_len <= 0; crc <= LCRC_SEED; ci <= 0; sbyte <= '0';
        fv <= '0'; fr_last <= '0'; fr_start <= '0'; fr_abort <= '0';
        fr_data <= (others=>'0');
        rpl_req <= '0'; rpl_i <= 0; q_v <= '0'; replay_num <= (others=>'0');
        rtimer <= 0; rt_run <= '0';
        replays <= (others=>'0'); tmos <= (others=>'0');
        ovsz <= (others=>'0'); akerr <= (others=>'0');
      else
        progress := false;
        -- a transferred byte leaves the output register
        if fv = '1' and fr_ready = '1' then
          fv <= '0'; fr_last <= '0'; fr_start <= '0'; fr_abort <= '0';
        end if;

        -- ---------------- Ack / Nak from the peer ----------------
        if ak_valid = '1' then
          a := unsigned(ak_seq);
          d := f_sdist(a, acked);
          if d <= inflight then
            if d > 0 then
              progress := true;
              acked <= a;
              if a + 1 = nseq then
                free_ptr <= wr_ptr;
              else
                free_ptr <= slot_base(slot_of(a + 1));
              end if;
              replay_num <= (others => '0');
            end if;
            if ak_is_nak = '1' and d < inflight then
              rpl_req <= '1';            -- something is still outstanding
            end if;
          else
            akerr <= akerr + 1;          -- not in the window: ignore
          end if;
        end if;

        -- ---------------- REPLAY_TIMER ----------------
        if progress then
          rtimer <= 0;
          if d >= inflight then rt_run <= '0'; end if;   -- everything acknowledged
        elsif rt_run = '1' and link_up = '1' and rpl_req = '0'
              and st /= T_RPL_NEXT and st /= T_RPL_SEQ and st /= T_RPL_PAY
              and st /= T_RPL_CRC then
          if rtimer >= REPLAY_TMO - 1 then
            rtimer <= 0; rpl_req <= '1'; tmos <= tmos + 1;
          else
            rtimer <= rtimer + 1;
          end if;
        end if;

        -- ---------------- FSM ----------------
        case st is
          when T_IDLE =>
            if rpl_req = '1' and link_up = '1' and fv = '0' then
              rpl_req <= '0';
              if inflight > 0 then
                replays <= replays + 1;
                if replay_num = 3 then retrain_req <= '1'; end if;
                replay_num <= replay_num + 1;      -- 2-bit, rolls over
                rpl_seq <= acked + 1;
                st <= T_RPL_NEXT;
              end if;
            elsif can_new = '1' and tl_valid = '1' and adv = '1' then
              crc <= f_crc32_byte(f_crc32_byte(LCRC_SEED, seq_hi(nseq)), seq_lo(nseq));
              cur_len <= 0;
              fv <= '1'; fr_start <= '1'; fr_last <= '0'; fr_abort <= '0';
              fr_data <= seq_hi(nseq); sbyte <= '1';
              st <= T_NEW_SEQ;
            end if;

          when T_NEW_SEQ =>
            if adv = '1' then
              fv <= '1'; fr_data <= seq_lo(nseq); st <= T_NEW_PAY;
            end if;

          when T_NEW_PAY =>
            if adv = '1' and tl_valid = '1' then
              if cur_len = MAX_TLP then
                -- oversize: abort the packet in the framer, drain the TL
                fv <= '1'; fr_last <= '1'; fr_abort <= '1';
                ovsz <= ovsz + 1;
                if tl_last = '1' then st <= T_IDLE; else st <= T_NEW_DRAIN; end if;
              else
                fv <= '1'; fr_data <= tl_data;
                ram(ra(wr_ptr + to_unsigned(cur_len, RB_LOG2+1))) <= tl_data;
                cur_len <= cur_len + 1;
                crc <= f_crc32_byte(crc, tl_data);
                if tl_last = '1' then
                  crc_fin <= f_lcrc_final(f_crc32_byte(crc, tl_data));
                  ci <= 0; st <= T_NEW_CRC;
                end if;
              end if;
            end if;

          when T_NEW_DRAIN =>
            if tl_valid = '1' and tl_last = '1' then st <= T_IDLE; end if;

          when T_NEW_CRC =>
            if adv = '1' then
              fv <= '1';
              case ci is
                when 0 => fr_data <= crc_fin(7 downto 0);
                when 1 => fr_data <= crc_fin(15 downto 8);
                when 2 => fr_data <= crc_fin(23 downto 16);
                when others => fr_data <= crc_fin(31 downto 24);
              end case;
              if ci = 3 then
                fr_last <= '1';
                slot_base(slot_of(nseq)) <= wr_ptr;
                slot_len(slot_of(nseq))  <= cur_len;
                wr_ptr <= wr_ptr + to_unsigned(cur_len, RB_LOG2+1);
                nseq <= nseq + 1;
                -- (re)start REPLAY_TIMER: overrides a same-cycle "all acked" stop
                rt_run <= '1';
                if rt_run = '0' or progress then rtimer <= 0; end if;
                st <= T_IDLE;
              else
                ci <= ci + 1;
              end if;
            end if;

          -- ------------- replay of every unacknowledged TLP -------------
          when T_RPL_NEXT =>
            -- (acked may have advanced during the replay: skip purged TLPs)
            infl_v := inflight;
            rs := rpl_seq;
            pos := f_sdist(rs, acked + 1);
            if rs = nseq or infl_v = 0 then
              rtimer <= 0; rt_run <= '1' when infl_v > 0 else '0';
              st <= T_IDLE;
            else
              if pos >= infl_v then rs := acked + 1; end if;   -- purged meanwhile
              rpl_seq  <= rs;
              rpl_len  <= slot_len(slot_of(rs));
              rpl_base <= slot_base(slot_of(rs));
              rpl_i <= 0; q_v <= '0';
              crc <= f_crc32_byte(f_crc32_byte(LCRC_SEED, seq_hi(rs)), seq_lo(rs));
              sbyte <= '0';
              st <= T_RPL_SEQ;
            end if;

          when T_RPL_SEQ =>
            -- prefetch payload byte 0 from the replay memory meanwhile
            if q_v = '0' then
              ram_q <= ram(ra(rpl_base)); q_v <= '1';
            end if;
            if adv = '1' then
              fv <= '1';
              if sbyte = '0' then
                fr_start <= '1'; fr_data <= seq_hi(rpl_seq); sbyte <= '1';
              else
                fr_data <= seq_lo(rpl_seq); st <= T_RPL_PAY;
              end if;
            end if;

          when T_RPL_PAY =>
            if q_v = '0' then
              ram_q <= ram(ra(rpl_base + to_unsigned(rpl_i, RB_LOG2+1))); q_v <= '1';
            elsif adv = '1' then
              fv <= '1'; fr_data <= ram_q;
              crc <= f_crc32_byte(crc, ram_q);
              if rpl_i + 1 < rpl_len then
                ram_q <= ram(ra(rpl_base + to_unsigned(rpl_i + 1, RB_LOG2+1)));
                rpl_i <= rpl_i + 1;
              else
                crc_fin <= f_lcrc_final(f_crc32_byte(crc, ram_q));
                q_v <= '0'; ci <= 0; st <= T_RPL_CRC;
              end if;
            end if;

          when T_RPL_CRC =>
            if adv = '1' then
              fv <= '1';
              case ci is
                when 0 => fr_data <= crc_fin(7 downto 0);
                when 1 => fr_data <= crc_fin(15 downto 8);
                when 2 => fr_data <= crc_fin(23 downto 16);
                when others => fr_data <= crc_fin(31 downto 24);
              end case;
              if ci = 3 then
                fr_last <= '1';
                rpl_seq <= rpl_seq + 1;
                st <= T_RPL_NEXT;
              else
                ci <= ci + 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture;
