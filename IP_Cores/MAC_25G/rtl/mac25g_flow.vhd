-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Frame buffering and IEEE 802.3x flow control (audit 2026-11):
--
--   mac25g_axis_fifo : AXIS 64b frame FIFO (one clock). TX use: store-and-
--                      forward in front of mac25g_tx, so tvalid bubbles of
--                      an AXIS-legal master can no longer cause underruns
--                      (fix M3). RX use: frames are committed at tlast, MAC
--                      control frames are dropped (consumed by the MAC), a
--                      frame that does not fit is dropped whole (overflow),
--                      m_tready back-pressure and a fill level for the PAUSE
--                      watermark.
--   mac25g_pause_rx  : snoops the RX AXIS stream of mac25g_rx and decodes
--                      MAC Control PAUSE frames (EtherType 0x8808, opcode
--                      0x0001, Annex 31B), reports pause_time on good frames
--   mac25g_pause_tx  : sits between the TX FIFO and mac25g_tx: honours a
--                      received pause (no new data frame starts while the
--                      pause timer runs; the frame in flight completes) and
--                      inserts PAUSE frames (XOFF / XON from the RX FIFO
--                      watermark, periodic XOFF refresh, or a register
--                      request)
--   mac25g_hsync     : W-bit value crossing with req/ack (stable data);
--                      used by MAC_10G where RX and TX clocks differ
--
-- PFC (802.1Qbb, per-priority pause, opcode 0x0101) is NOT implemented:
-- opcode 0x0101 frames are consumed as MAC control frames and ignored.
--
-- Pause quanta: 1 quantum = 512 bit times = 8 blocks of 64 bits. The timer
-- counts block slots (ce), i.e. 8 slots per quantum, which is exact for a
-- 25GBASE-R / 10GBASE-R MAC that emits one 64-bit block per slot.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac25g_axis_fifo is
  generic (
    AW       : positive := 9;          -- depth = 2**AW words of 8 bytes
    STORE_FW : boolean  := true;       -- output only complete frames
    NO_BP    : boolean  := false       -- true: s_tready ignored (RX), a beat
                                       -- that does not fit drops the frame
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    s_tdata  : in  std_logic_vector(63 downto 0);
    s_tkeep  : in  std_logic_vector(7 downto 0);
    s_tlast  : in  std_logic;
    s_tuser  : in  std_logic := '0';   -- stored, delivered with tlast
    s_tdrop  : in  std_logic := '0';   -- with tlast: discard this frame
    s_tvalid : in  std_logic;
    s_tready : out std_logic;
    m_tdata  : out std_logic_vector(63 downto 0);
    m_tkeep  : out std_logic_vector(7 downto 0);
    m_tlast  : out std_logic;
    m_tuser  : out std_logic;
    m_tvalid : out std_logic;
    m_tready : in  std_logic;
    level    : out unsigned(AW downto 0);   -- words held (incl. partial frame)
    ev_ovf   : out std_logic;               -- RX: frame dropped (no room)
    ev_drop  : out std_logic                -- frame discarded by s_tdrop
  );
end entity mac25g_axis_fifo;

architecture rtl of mac25g_axis_fifo is
  constant DEPTH : natural := 2**AW;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(73 downto 0);
  signal mem : mem_t;
  signal wp, cp, rp : unsigned(AW downto 0) := (others => '0');  -- write, commit, read
  signal frames : unsigned(AW downto 0) := (others => '0');      -- committed, unread
  signal ct     : std_logic := '0';     -- cut-through of a frame larger than DEPTH
  signal ovf_f  : std_logic := '0';     -- RX: current frame overflowed
  signal o_v    : std_logic := '0';
  signal o_w    : std_logic_vector(73 downto 0) := (others => '0');
  signal full   : std_logic;
  signal rdy    : std_logic;
  signal e_ovf, e_drop : std_logic := '0';
begin
  full <= '1' when (wp - rp) = DEPTH else '0';
  rdy  <= '1' when NO_BP else not full;
  s_tready <= rdy and not rst;

  process(clk)
    variable v_wp, v_cp, v_rp : unsigned(AW downto 0);
    variable v_fr : unsigned(AW downto 0);
    variable pop, load, wr : boolean;
    variable lim  : unsigned(AW downto 0);
  begin
    if rising_edge(clk) then
      e_ovf <= '0'; e_drop <= '0';
      if rst = '1' then
        wp <= (others => '0'); cp <= (others => '0'); rp <= (others => '0');
        frames <= (others => '0'); ct <= '0'; ovf_f <= '0'; o_v <= '0';
      else
        v_wp := wp; v_cp := cp; v_rp := rp; v_fr := frames;

        -- ---------------- write side ----------------
        if s_tvalid = '1' and rdy = '1' then
          wr := (full = '0') and ovf_f = '0';
          if NO_BP and full = '1' then
            ovf_f <= '1';                          -- this frame is lost
          end if;
          if wr then
            mem(to_integer(wp(AW-1 downto 0))) <= s_tuser & s_tlast & s_tkeep & s_tdata;
            v_wp := wp + 1;
          end if;
          if s_tlast = '1' then
            if s_tdrop = '1' or ovf_f = '1' or (NO_BP and full = '1') then
              if ct = '0' then v_wp := cp; end if; -- roll the frame back
              if s_tdrop = '1' then e_drop <= '1'; else e_ovf <= '1'; end if;
              ovf_f <= '0';
            else
              v_cp := v_wp; v_fr := v_fr + 1;      -- commit
            end if;
          end if;
        end if;

        -- ---------------- read side (registered output, FWFT) ----------------
        pop := o_v = '1' and m_tready = '1';
        if pop and o_w(72) = '1' then              -- a tlast leaves the FIFO
          v_fr := v_fr - 1;
          ct <= '0';
        end if;
        -- readable limit: committed data, or everything while cutting through
        if not STORE_FW or ct = '1' then lim := wp; else lim := cp; end if;
        if STORE_FW and not NO_BP and ct = '0' and frames = 0 and full = '1' then
          ct <= '1';                               -- TX frame larger than the FIFO
        end if;
        load := (o_v = '0' or pop) and rp /= lim;
        if load then
          o_w <= mem(to_integer(rp(AW-1 downto 0)));
          o_v <= '1';
          v_rp := rp + 1;
        elsif pop then
          o_v <= '0';
        end if;

        wp <= v_wp; cp <= v_cp; rp <= v_rp; frames <= v_fr;
      end if;
    end if;
  end process;

  m_tdata  <= o_w(63 downto 0);
  m_tkeep  <= o_w(71 downto 64);
  m_tlast  <= o_w(72);
  m_tuser  <= o_w(73);
  m_tvalid <= o_v;
  level    <= wp - rp;
  ev_ovf   <= e_ovf;
  ev_drop  <= e_drop;
end architecture rtl;


-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac25g_pause_rx is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    own_mac  : in  std_logic_vector(47 downto 0);
    -- AXIS from mac25g_rx (no back-pressure)
    s_tdata  : in  std_logic_vector(63 downto 0);
    s_tlast  : in  std_logic;
    s_tuser  : in  std_logic;
    s_tvalid : in  std_logic;
    -- combinational, valid on the tlast beat: this frame is a MAC Control
    -- frame (EtherType 0x8808) -> the RX FIFO drops it
    is_ctrl  : out std_logic;
    -- registered: a good PAUSE frame ended (1-cycle pulse) + its pause_time
    pause_stb   : out std_logic;
    pause_quanta: out std_logic_vector(15 downto 0)
  );
end entity mac25g_pause_rx;

architecture rtl of mac25g_pause_rx is
  -- byte i of a MAC address is bits 8i+7..8i (same as the generator)
  constant PAUSE_DA : std_logic_vector(47 downto 0) := x"010000C28001";  -- 01-80-C2-00-00-01
  signal wi      : unsigned(1 downto 0) := (others => '0');  -- word index, saturates at 3
  signal da_ok   : std_logic := '0';
  signal ctrl_r  : std_logic := '0';
  signal pause_r : std_logic := '0';
  signal q_r     : std_logic_vector(15 downto 0) := (others => '0');
  signal stb     : std_logic := '0';
  signal qo      : std_logic_vector(15 downto 0) := (others => '0');
  signal w1_ctrl : std_logic;
begin
  -- word 1: bytes 12,13 = EtherType (0x88, 0x08) in bits 39..32 / 47..40
  w1_ctrl <= '1' when wi = 1 and s_tdata(39 downto 32) = x"88" and s_tdata(47 downto 40) = x"08"
             else '0';
  is_ctrl <= ctrl_r or w1_ctrl;

  process(clk)
  begin
    if rising_edge(clk) then
      stb <= '0';
      if rst = '1' then
        wi <= (others => '0'); da_ok <= '0'; ctrl_r <= '0'; pause_r <= '0';
      elsif s_tvalid = '1' then
        if s_tlast = '1' then
          -- a good PAUSE frame: right DA, 0x8808, opcode 0x0001, >= 3 words
          if pause_r = '1' and wi = 3 and s_tuser = '0' then
            stb <= '1'; qo <= q_r;
          end if;
          wi <= (others => '0'); da_ok <= '0'; ctrl_r <= '0'; pause_r <= '0';
        else
          if wi /= 3 then wi <= wi + 1; end if;
          case to_integer(wi) is
            when 0 =>
              if s_tdata(47 downto 0) = PAUSE_DA or s_tdata(47 downto 0) = own_mac then
                da_ok <= '1';
              end if;
            when 1 =>
              if w1_ctrl = '1' then ctrl_r <= '1'; end if;
              -- opcode bytes 14,15 = 0x00, 0x01
              if w1_ctrl = '1' and da_ok = '1' and s_tdata(55 downto 48) = x"00" and
                 s_tdata(63 downto 56) = x"01" then
                pause_r <= '1';
              end if;
            when 2 =>
              q_r <= s_tdata(7 downto 0) & s_tdata(15 downto 8);   -- big endian
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  pause_stb    <= stb;
  pause_quanta <= qo;
end architecture rtl;


-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac25g_pause_tx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    ce         : in  std_logic;           -- block slot of mac25g_tx
    own_mac    : in  std_logic_vector(47 downto 0);
    -- configuration
    honor_en   : in  std_logic;           -- obey received PAUSE frames
    auto_en    : in  std_logic;           -- XOFF/XON from the RX watermark
    quanta     : in  std_logic_vector(15 downto 0);  -- XOFF pause_time
    -- received PAUSE (already in this clock domain)
    rx_stb     : in  std_logic;
    rx_quanta  : in  std_logic_vector(15 downto 0);
    -- RX FIFO above the high watermark (level with hysteresis, this domain)
    xoff       : in  std_logic;
    -- software request: send one PAUSE with sw_quanta (pulse)
    sw_req     : in  std_logic;
    sw_quanta  : in  std_logic_vector(15 downto 0);
    -- AXIS from the TX FIFO
    s_tdata    : in  std_logic_vector(63 downto 0);
    s_tkeep    : in  std_logic_vector(7 downto 0);
    s_tlast    : in  std_logic;
    s_tvalid   : in  std_logic;
    s_tready   : out std_logic;
    -- AXIS to mac25g_tx
    m_tdata    : out std_logic_vector(63 downto 0);
    m_tkeep    : out std_logic_vector(7 downto 0);
    m_tlast    : out std_logic;
    m_tvalid   : out std_logic;
    m_tready   : in  std_logic;
    -- status / events
    paused     : out std_logic;           -- pause timer running
    ev_tx_pause: out std_logic;           -- a PAUSE frame was sent
    ev_rx_pause: out std_logic            -- a received PAUSE was honoured
  );
end entity mac25g_pause_tx;

architecture rtl of mac25g_pause_tx is
  constant PAUSE_DA : std_logic_vector(47 downto 0) := x"010000C28001";
  type st_t is (S_IDLE, S_DATA, S_P0, S_P1, S_P2);
  signal st      : st_t := S_IDLE;
  signal timer   : unsigned(18 downto 0) := (others => '0');  -- 65535 * 8 slots
  signal pend    : std_logic := '0';
  signal pq      : std_logic_vector(15 downto 0) := (others => '0');
  signal fq      : std_logic_vector(15 downto 0) := (others => '0');  -- frame in flight
  signal xoff_d  : std_logic := '0';
  signal refresh : unsigned(18 downto 0) := (others => '0');
  signal e_tx, e_rx : std_logic := '0';
  signal pw      : std_logic_vector(63 downto 0);
  signal pk      : std_logic_vector(7 downto 0);
  signal pl      : std_logic;
begin
  -- PAUSE frame beats (mac25g_tx pads to 60 bytes and appends the FCS)
  with st select pw <=
    own_mac(15 downto 0) & PAUSE_DA                                when S_P0,
    x"0100" & x"0888" & own_mac(47 downto 16)                      when S_P1,
    x"000000000000" & fq(7 downto 0) & fq(15 downto 8)             when others;
  pk <= x"03" when st = S_P2 else x"FF";
  pl <= '1' when st = S_P2 else '0';

  m_tdata  <= pw when st = S_P0 or st = S_P1 or st = S_P2 else s_tdata;
  m_tkeep  <= pk when st = S_P0 or st = S_P1 or st = S_P2 else s_tkeep;
  m_tlast  <= pl when st = S_P0 or st = S_P1 or st = S_P2 else s_tlast;
  m_tvalid <= '1' when st = S_P0 or st = S_P1 or st = S_P2 else
              s_tvalid when st = S_DATA else
              s_tvalid when st = S_IDLE and pend = '0' and timer = 0 else '0';
  s_tready <= m_tready when st = S_DATA or (st = S_IDLE and pend = '0' and timer = 0)
              else '0';

  process(clk)
    variable start_data : boolean;
  begin
    if rising_edge(clk) then
      e_tx <= '0'; e_rx <= '0';
      if rst = '1' then
        st <= S_IDLE; timer <= (others => '0'); pend <= '0'; xoff_d <= '0';
        refresh <= (others => '0');
      else
        -- ---- received pause: (re)load the timer, quanta 0 = resume ----
        if rx_stb = '1' and honor_en = '1' then
          timer <= shift_left(resize(unsigned(rx_quanta), 19), 3);
          e_rx <= '1';
        elsif timer /= 0 and ce = '1' then
          timer <= timer - 1;
        end if;

        -- ---- PAUSE requests: XOFF on rise, XON on fall, refresh, software ----
        xoff_d <= xoff and auto_en;
        if refresh /= 0 and ce = '1' then refresh <= refresh - 1; end if;
        if sw_req = '1' then
          pend <= '1'; pq <= sw_quanta;
        elsif auto_en = '1' and xoff = '1' and
              (xoff_d = '0' or (refresh = 0 and quanta /= x"0000")) then
          pend <= '1'; pq <= quanta;
          -- re-send before the partner's timer runs out (half of the quanta)
          refresh <= shift_left(resize(unsigned(quanta), 19), 2);
        elsif xoff_d = '1' and (xoff = '0' or auto_en = '0') then
          pend <= '1'; pq <= x"0000";               -- XON
          refresh <= (others => '0');
        end if;

        -- ---- frame boundary arbiter ----
        case st is
          when S_IDLE =>
            if pend = '1' then
              st <= S_P0; fq <= pq;
              if not (sw_req = '1' or (auto_en = '1' and xoff = '1' and
                      (xoff_d = '0' or (refresh = 0 and quanta /= x"0000"))) or
                      (xoff_d = '1' and (xoff = '0' or auto_en = '0'))) then
                pend <= '0';
              end if;
            elsif timer = 0 and s_tvalid = '1' then
              -- the beat is OFFERED to mac25g_tx now: commit to this frame
              -- (tvalid must not drop before the handshake, and mac25g_tx has
              -- already started the frame when it sees tvalid)
              if not (m_tready = '1' and s_tlast = '1') then st <= S_DATA; end if;
            end if;
          when S_DATA =>
            if s_tvalid = '1' and m_tready = '1' and s_tlast = '1' then
              st <= S_IDLE;
            end if;
          when S_P0 =>
            if m_tready = '1' then st <= S_P1; end if;
          when S_P1 =>
            if m_tready = '1' then st <= S_P2; end if;
          when S_P2 =>
            if m_tready = '1' then st <= S_IDLE; e_tx <= '1'; end if;
        end case;
      end if;
    end if;
  end process;

  paused      <= '1' when timer /= 0 else '0';
  ev_tx_pause <= e_tx;
  ev_rx_pause <= e_rx;
end architecture rtl;


-------------------------------------------------------------------------------
-- mac25g_hsync: W-bit value + strobe across clock domains (req/ack). The
-- source holds the value in a register while the request is in flight; a
-- newer value arriving meanwhile replaces the pending one (latest wins) and
-- is sent after the acknowledge. Same reset rules as mac25g_evsync.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity mac25g_hsync is
  generic (W : positive := 16);
  port (
    clk_src : in  std_logic; rst_src : in std_logic; por_src : in std_logic := '0';
    stb_in  : in  std_logic;
    d_in    : in  std_logic_vector(W-1 downto 0);
    clk_dst : in  std_logic; rst_dst : in std_logic;
    stb_out : out std_logic;
    d_out   : out std_logic_vector(W-1 downto 0)
  );
end entity mac25g_hsync;

architecture rtl of mac25g_hsync is
  signal pend, busy, req : std_logic := '0';
  signal hold, nxt : std_logic_vector(W-1 downto 0) := (others => '0');
  signal a1, a2, r1, r2, r3 : std_logic := '0';
  signal q : std_logic_vector(W-1 downto 0) := (others => '0');
  signal s : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of a1, a2, r1, r2 : signal is "TRUE";
begin
  process(clk_src)
  begin
    if rising_edge(clk_src) then
      a1 <= r2; a2 <= a1;
    end if;
  end process;

  process(clk_src, por_src)
  begin
    if por_src = '1' then
      req <= '0'; pend <= '0'; busy <= '0';
    elsif rising_edge(clk_src) then
      if rst_src = '1' then
        pend <= '0'; busy <= '0';
      elsif busy = '0' and (pend = '1' or stb_in = '1') then
        if stb_in = '1' then hold <= d_in; else hold <= nxt; end if;
        req <= not req; busy <= '1'; pend <= '0';
      else
        if stb_in = '1' then pend <= '1'; nxt <= d_in; end if;
        if busy = '1' and a2 = req then busy <= '0'; end if;
      end if;
    end if;
  end process;

  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      r1 <= req; r2 <= r1; r3 <= r2;
      s <= '0';
      if (r2 xor r3) = '1' and rst_dst = '0' then
        q <= hold;                    -- stable: held until the acknowledge
        s <= '1';
      end if;
    end if;
  end process;
  stb_out <= s;
  d_out   <= q;
end architecture rtl;
