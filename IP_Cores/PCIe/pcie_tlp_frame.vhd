-- ============================================================================
-- pcie_tlp_frame.vhd -- PCIE IP (rewritten in audit 2026-11)
-- TX framer of the node: STORE-AND-FORWARD for TLPs, plus a DLLP port.
--
--   TLP  : the DLL TX stream ([seq][tlp][lcrc]) is written into a packet
--          buffer; STP is emitted only once the WHOLE packet is buffered, so
--          a bubble in the DLL stream (e.g. replay-buffer read latency) can no
--          longer put a logical-idle symbol inside an open TLP. A packet
--          closed with dabort='1' is discarded (never reaches the wire).
--          Emitted as STP <bytes> END, followed by one idle symbol (gap).
--   DLLP : 6 bytes (Ack/Nak with CRC-16) latched from dl_data, emitted as
--          SDP <6 bytes> END. DLLPs have priority over TLPs.
--   SKP  : a SKP ordered set (COM + 3 SKP) is due every SKP_INTERVAL symbols;
--          it is held pending and inserted at the next packet boundary (never
--          inside a packet, never skipped). Hook for a PHY that needs SKP for
--          clock compensation (see pcie_elastic_buf.vhd on the RX side).
-- Between packets: logical idle (D00, scrambled downstream).
-- No packet is started while link_up = '0'.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;

entity pcie_tlp_frame is
  generic (
    SKP_INTERVAL : integer := 600;
    BUF_BYTES    : integer := 256     -- >= MAX_TLP + 6 (seq + LCRC)
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    en        : in  std_logic;
    link_up   : in  std_logic := '1';

    -- TLP stream from the DLL TX
    start     : in  std_logic := '0';   -- informative (first byte); unused
    din       : in  byte_t;
    dvalid    : in  std_logic;
    dlast     : in  std_logic;
    dabort    : in  std_logic := '0';
    dready    : out std_logic;

    -- DLLP (6 bytes, b0 in 47:40)
    dl_valid  : in  std_logic := '0';
    dl_data   : in  std_logic_vector(47 downto 0) := (others => '0');
    dl_ready  : out std_logic;

    sym       : out byte_t;
    sym_k     : out std_logic;
    sym_com   : out std_logic;
    sym_skp   : out std_logic;
    sym_byp   : out std_logic;
    busy      : out std_logic
  );
end entity;

architecture rtl of pcie_tlp_frame is
  type st_t is (F_IDLE, F_TPAY, F_TEND, F_DPAY, F_DEND, F_GAP,
                F_SKP1, F_SKP2, F_SKP3);
  signal st : st_t := F_IDLE;

  type buf_t is array (0 to BUF_BYTES-1) of byte_t;
  signal tbuf : buf_t := (others => (others => '0'));
  signal wcnt : integer range 0 to BUF_BYTES := 0;     -- bytes buffered
  signal tlen : integer range 0 to BUF_BYTES := 0;     -- length of ready packet
  signal tlp_rdy : std_logic := '0';
  signal rptr : integer range 0 to BUF_BYTES := 0;
  signal ovf  : std_logic := '0';

  signal dl_full : std_logic := '0';
  signal dl_reg  : std_logic_vector(47 downto 0) := (others => '0');
  signal dl_emit : std_logic_vector(47 downto 0) := (others => '0');
  signal di      : integer range 0 to 5 := 0;

  signal skp_cnt  : integer range 0 to 65535 := 0;
  signal skp_pend : std_logic := '0';
  signal dready_i : std_logic;
  signal emitting : std_logic;
begin
  emitting <= '1' when st = F_TPAY or st = F_TEND else '0';
  dready_i <= '1' when tlp_rdy = '0' and emitting = '0' else '0';
  dready   <= dready_i;
  dl_ready <= dl_valid and not dl_full;
  busy     <= '0' when st = F_IDLE else '1';

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= F_IDLE; skp_cnt <= 0; skp_pend <= '0';
        wcnt <= 0; tlen <= 0; tlp_rdy <= '0'; rptr <= 0; ovf <= '0';
        dl_full <= '0'; di <= 0;
        sym <= x"00"; sym_k <= '0'; sym_com <= '0'; sym_skp <= '0'; sym_byp <= '0';
      else
        -- ---------- fill side (store) ----------
        if dvalid = '1' and dready_i = '1' then
          if wcnt < BUF_BYTES then
            tbuf(wcnt) <= din; wcnt <= wcnt + 1;
          else
            ovf <= '1';                       -- cannot happen with MAX_TLP+6 <= BUF
          end if;
          if dlast = '1' then
            if dabort = '1' or ovf = '1' or wcnt >= BUF_BYTES then
              wcnt <= 0; ovf <= '0';          -- discard the packet
            else
              tlp_rdy <= '1'; tlen <= wcnt + 1;
            end if;
          end if;
        end if;
        if dl_valid = '1' and dl_full = '0' then
          dl_full <= '1'; dl_reg <= dl_data;
        end if;

        -- ---------- emit side (forward) ----------
        if en = '1' then
          sym <= x"00"; sym_k <= '0'; sym_com <= '0'; sym_skp <= '0'; sym_byp <= '0';
          if skp_cnt = SKP_INTERVAL-1 then
            skp_cnt <= 0; skp_pend <= '1';
          else
            skp_cnt <= skp_cnt + 1;
          end if;

          case st is
            when F_IDLE =>
              if skp_pend = '1' then
                skp_pend <= '0';
                sym <= K_COM; sym_k <= '1'; sym_com <= '1'; st <= F_SKP1;
              elsif dl_full = '1' and link_up = '1' then
                -- move the DLLP to the emit register: the latch is free again
                dl_emit <= dl_reg; dl_full <= '0';
                sym <= K_SDP; sym_k <= '1'; di <= 0; st <= F_DPAY;
              elsif tlp_rdy = '1' and link_up = '1' then
                sym <= K_STP; sym_k <= '1'; rptr <= 0; st <= F_TPAY;
              end if;

            when F_TPAY =>
              sym <= tbuf(rptr); sym_k <= '0';          -- registered read
              if rptr = tlen - 1 then st <= F_TEND; else rptr <= rptr + 1; end if;

            when F_TEND =>
              sym <= K_END; sym_k <= '1';
              tlp_rdy <= '0'; wcnt <= 0;
              st <= F_GAP;

            when F_DPAY =>
              sym <= dl_emit(47 - 8*di downto 40 - 8*di); sym_k <= '0';
              if di = 5 then st <= F_DEND; else di <= di + 1; end if;

            when F_DEND =>
              sym <= K_END; sym_k <= '1';
              st <= F_GAP;

            when F_GAP =>
              -- one logical-idle symbol between packets (receiver closes the
              -- previous packet before the next STP/SDP)
              st <= F_IDLE;

            when F_SKP1 => sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; st <= F_SKP2;
            when F_SKP2 => sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; st <= F_SKP3;
            when F_SKP3 => sym <= K_SKP; sym_k <= '1'; sym_skp <= '1'; st <= F_IDLE;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
