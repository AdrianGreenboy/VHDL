-- ============================================================================
-- pcie_dll_rx.vhd -- PCIE IP (rewritten in audit 2026-11)
-- Data Link Layer RX. Consumes the raw deframed TLP stream
--   [seq_hi][seq_lo][header+payload...][lcrc0..3]
-- (in_start on seq_hi, in_last on lcrc3, in_abort on a framing error/EDB),
-- checks LCRC-32 and the sequence number, and is the ONLY path from the link
-- to the Transaction Layer:
--   * header+payload bytes are written TENTATIVELY into pcie_rx_tlp_fifo while
--     they arrive (4-byte delay line strips the LCRC, 1 extra byte of delay
--     lets the last payload byte carry the 'last' flag);
--   * good LCRC and seq == NEXT_RCV_SEQ  -> commit (TL sees the TLP),
--     NEXT_RCV_SEQ++, an Ack is scheduled (coalesced, AckNak latency timer);
--   * duplicate (seq behind, distance 1..2048) -> rollback, Ack scheduled now;
--   * bad LCRC, seq ahead, framing abort, oversize, or RX buffer overflow
--     -> rollback, Nak(NEXT_RCV_SEQ-1) scheduled unless NAK_SCHEDULED is
--     already set (cleared by the next good in-order TLP).
-- The Ack/Nak request (an_*) is turned into a real DLLP by pcie_dllp_gen and
-- sent across the link to the PEER's DLL TX (correct sequence space).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_dll_pkg.all;

entity pcie_dll_rx is
  generic (
    MAX_TLP    : integer := 128;   -- max header+payload bytes accepted
    ACKNAK_LAT : integer := 64;    -- cycles an Ack may be delayed (coalescing)
    FIFO_LOG2  : integer := 9      -- log2 depth of the attached pcie_rx_tlp_fifo
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    -- raw deframed stream (one TLP)
    in_valid  : in  std_logic;
    in_data   : in  byte_t;
    in_start  : in  std_logic;      -- first byte (seq_hi)
    in_last   : in  std_logic;      -- last byte (lcrc3)
    in_abort  : in  std_logic := '0'; -- framing error / EDB: discard current TLP

    -- tentative write into the RX TLP buffer (pcie_rx_tlp_fifo)
    f_wr       : out std_logic;
    f_data     : out byte_t;
    f_last     : out std_logic;
    f_commit   : out std_logic;
    f_rollback : out std_logic;
    f_ovf      : in  std_logic;
    f_space    : in  unsigned(FIFO_LOG2 downto 0);

    -- Ack/Nak request towards the DLLP generator
    an_valid  : out std_logic;
    an_is_nak : out std_logic;
    an_seq    : out std_logic_vector(11 downto 0);
    an_ready  : in  std_logic;

    -- monitor
    good_o    : out std_logic_vector(15 downto 0);
    bad_o     : out std_logic_vector(15 downto 0);
    dup_o     : out std_logic_vector(15 downto 0);
    nak_o     : out std_logic_vector(15 downto 0);
    nextrx_o  : out std_logic_vector(11 downto 0)
  );
end entity;

architecture rtl of pcie_dll_rx is
  type rstate_t is (R_IDLE, R_SEQLO, R_PAY, R_CHECK);
  signal st : rstate_t := R_IDLE;

  signal next_rx : seq_t := (others => '0');
  signal cur_seq : seq_t := (others => '0');
  signal crc     : crc32_t := LCRC_SEED;
  signal good, bad, dups, naks : unsigned(15 downto 0) := (others => '0');

  type dly_t is array (0 to 3) of byte_t;
  signal dly    : dly_t := (others => (others=>'0'));
  signal dcount : integer range 0 to 4 := 0;
  signal pend_v : std_logic := '0';            -- one confirmed payload byte held back
  signal pend_d : byte_t := (others => '0');
  signal nbytes : integer range 0 to MAX_TLP+1 := 0;
  signal oversz : std_logic := '0';
  signal seqhi  : byte_t := (others=>'0');

  -- Ack/Nak scheduler
  signal nak_sched : std_logic := '0';   -- NAK_SCHEDULED (spec)
  signal nak_req   : std_logic := '0';   -- NAK waiting to be sent
  signal ack_due   : std_logic := '0';   -- Ack must be sent now
  signal ack_pend  : std_logic := '0';   -- accepted TLPs not yet acknowledged
  signal lat_cnt   : integer range 0 to ACKNAK_LAT := 0;
  signal an_v_i    : std_logic;
begin

  good_o   <= std_logic_vector(good);
  bad_o    <= std_logic_vector(bad);
  dup_o    <= std_logic_vector(dups);
  nak_o    <= std_logic_vector(naks);
  nextrx_o <= std_logic_vector(next_rx);

  an_v_i    <= nak_req or ack_due;
  an_valid  <= an_v_i;
  an_is_nak <= nak_req;
  an_seq    <= std_logic_vector(next_rx - 1);   -- AckNak_Seq_Num = NEXT_RCV_SEQ-1

  process(clk)
    variable good_crc : boolean;
    variable c        : crc32_t;
    variable d        : natural;
    variable drop, nak_it, ack_now, accept : boolean;
    procedure start_tlp(b : byte_t) is
    begin
      seqhi <= b;
      crc <= f_crc32_byte(LCRC_SEED, b);
      dcount <= 0; pend_v <= '0'; nbytes <= 0; oversz <= '0';
      st <= R_SEQLO;
    end procedure;
  begin
    if rising_edge(clk) then
      f_wr <= '0'; f_last <= '0'; f_commit <= '0'; f_rollback <= '0';
      if rst = '1' then
        st <= R_IDLE; next_rx <= (others=>'0'); crc <= LCRC_SEED;
        good <= (others=>'0'); bad <= (others=>'0');
        dups <= (others=>'0'); naks <= (others=>'0');
        dcount <= 0; pend_v <= '0'; nbytes <= 0; oversz <= '0';
        nak_sched <= '0'; nak_req <= '0'; ack_due <= '0'; ack_pend <= '0';
        lat_cnt <= 0;
        f_data <= (others => '0');
      else
        drop := false; nak_it := false; ack_now := false; accept := false;

        -- ------------- Ack/Nak scheduler -------------
        if an_v_i = '1' and an_ready = '1' then
          -- a Nak also acknowledges everything up to its sequence number
          nak_req <= '0'; ack_due <= '0'; ack_pend <= '0'; lat_cnt <= 0;
        elsif ack_pend = '1' then
          if lat_cnt >= ACKNAK_LAT - 1 then
            ack_due <= '1';
          else
            lat_cnt <= lat_cnt + 1;
          end if;
        end if;

        -- ------------- receive FSM -------------
        if in_valid = '1' and in_abort = '1' then
          if st /= R_IDLE then drop := true; nak_it := true; end if;
          st <= R_IDLE;
        else
          case st is
            when R_IDLE | R_CHECK =>
              if st = R_CHECK then
                -- crc holds seq + payload; dly(0..3) = received LCRC bytes
                c := f_lcrc_final(crc);
                good_crc := (c = dly(3) & dly(2) & dly(1) & dly(0)) and
                            dcount = 4 and pend_v = '1';
                d := f_sdist(next_rx, cur_seq);
                if not good_crc then
                  drop := true; nak_it := true;
                elsif cur_seq = next_rx then
                  if oversz = '1' or f_ovf = '1' or f_space = 0 then
                    drop := true; nak_it := true;     -- no room: Nak, replay later
                  else
                    accept := true;
                  end if;
                elsif d >= 1 and d <= 2048 then
                  drop := true; ack_now := true; dups <= dups + 1;   -- duplicate
                else
                  drop := true; nak_it := true;       -- lost TLP(s): seq ahead
                end if;
                st <= R_IDLE;
              end if;
              if in_valid = '1' and in_start = '1' then
                start_tlp(in_data);
              end if;

            when R_SEQLO =>
              if in_valid = '1' then
                if in_start = '1' then
                  drop := true; nak_it := true; start_tlp(in_data);
                elsif in_last = '1' then
                  drop := true; nak_it := true; st <= R_IDLE;   -- runt
                else
                  cur_seq <= unsigned(std_logic_vector'(seqhi(3 downto 0) & in_data));
                  crc <= f_crc32_byte(crc, in_data);
                  st <= R_PAY;
                end if;
              end if;

            when R_PAY =>
              if in_valid = '1' then
                if in_start = '1' then
                  drop := true; nak_it := true; start_tlp(in_data);
                else
                  if dcount < 4 then
                    dly(dcount) <= in_data;
                    dcount <= dcount + 1;
                  else
                    -- dly(0) is confirmed header/payload: CRC it and pass the
                    -- previously held byte to the buffer (not last)
                    crc <= f_crc32_byte(crc, dly(0));
                    if pend_v = '1' and oversz = '0' then
                      f_wr <= '1'; f_data <= pend_d; f_last <= '0';
                    end if;
                    pend_v <= '1'; pend_d <= dly(0);
                    if nbytes >= MAX_TLP then oversz <= '1';
                    else nbytes <= nbytes + 1; end if;
                    dly(0) <= dly(1); dly(1) <= dly(2); dly(2) <= dly(3);
                    dly(3) <= in_data;
                  end if;
                  if in_last = '1' then
                    st <= R_CHECK;
                  end if;
                end if;
              end if;
          end case;
        end if;

        if accept then
          f_wr <= '1'; f_data <= pend_d; f_last <= '1';
          f_commit <= '1';
          good <= good + 1;
          next_rx <= next_rx + 1;
          nak_sched <= '0';
          ack_pend <= '1';
        end if;
        if drop then
          f_rollback <= '1';
          if nak_it then bad <= bad + 1; end if;
        end if;
        if nak_it and nak_sched = '0' and not accept then
          nak_req <= '1'; nak_sched <= '1'; naks <= naks + 1;
        end if;
        if ack_now then
          ack_due <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture;
