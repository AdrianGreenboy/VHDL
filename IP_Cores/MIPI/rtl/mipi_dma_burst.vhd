-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5 (silicon): dma_burst - doorbell DMA engine.
-- Reads bytes from the core's local framebuffer (via the same streaming read
-- port the firmware uses) and writes them to DDR through an AXI4 master.
--
-- Doorbell contract (standard across the HERCOSSNUX family):
--   firmware writes dma_src (FB select), dma_dst (DDR addr), dma_len (bytes),
--   then pulses start; engine runs and asserts done.
--
-- Versal NoC lesson: an AXI burst must NOT cross a 4 KB address boundary
-- (PMC EAM ERR / NoC rejection). The engine splits transfers at 4 KB pages.
-- Data path is 32-bit (4 bytes/beat); AWSIZE=2, INCR bursts.
--
-- AUDIT 2026-11 (AXI protocol): AWVALID / WVALID / BREADY are now driven
-- combinationally FROM THE STATE (S_ADDR / S_PUSH / S_RESP), not from a
-- register re-armed every cycle. A valid therefore drops in the very cycle
-- after its handshake (no duplicate AW or W beat), READY is only sampled
-- while the matching VALID is asserted, and AWADDR/AWLEN/WDATA/WSTRB/WLAST are
-- stable for as long as VALID is high (they only depend on registers that do
-- not change in that state). Same pattern as ADCS/soc/axi4_master.vhd.
-- AUDIT 2026-11 (length): length = 0 completes without any bus traffic. A
-- length that is not a multiple of 4 gets a partial WSTRB on its last beat,
-- so no byte past 'length' is written in DDR.
-- Requirement: dst_addr must be 4-byte aligned (low 2 bits are ignored).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mipi_dma_burst is
  generic (
    FB_AWID : integer := 15
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- doorbell
    start     : in  std_logic;
    src_sel   : in  std_logic;                       -- 0=FB0, 1=FB1
    dst_addr  : in  std_logic_vector(31 downto 0);   -- DDR base
    length    : in  std_logic_vector(31 downto 0);   -- bytes
    done      : out std_logic;
    -- framebuffer streaming read (word = 1 byte, zero-extended)
    fb_sel    : out std_logic;
    fb_re     : out std_logic;
    fb_addr   : out std_logic_vector(FB_AWID-1 downto 0);
    fb_data   : in  std_logic_vector(7 downto 0);
    -- AXI4 master write channels
    m_awaddr  : out std_logic_vector(31 downto 0);
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_wdata   : out std_logic_vector(31 downto 0);
    m_wstrb   : out std_logic_vector(3 downto 0);
    m_wlast   : out std_logic;
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_bresp   : in  std_logic_vector(1 downto 0);
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic
  );
end entity;

architecture rtl of mipi_dma_burst is
  type st_t is (S_IDLE, S_ADDR, S_FILL0, S_FILL1, S_FILL2, S_FILL3, S_FILLW,
                S_PUSH, S_RESP, S_DONE);
  signal st : st_t := S_IDLE;

  signal cur_dst   : unsigned(31 downto 0) := (others=>'0');
  signal rem_bytes : unsigned(31 downto 0) := (others=>'0');
  signal fb_ptr    : unsigned(FB_AWID-1 downto 0) := (others=>'0');
  signal beats     : unsigned(8 downto 0) := (others=>'0');   -- 1..256
  signal beat_cnt  : unsigned(8 downto 0) := (others=>'0');
  signal nb_c      : unsigned(8 downto 0);                    -- beats of next burst

  signal word_buf  : std_logic_vector(31 downto 0) := (others=>'0');

  signal done_i  : std_logic := '0';
  signal fb_re_i : std_logic := '0';
  signal last_c  : std_logic;

  -- beats of the next burst: bounded by the 4 KB page, the remaining bytes
  -- (rounded up to whole words) and the AXI4 INCR limit of 256.
  function beats_to_boundary(addr : unsigned(31 downto 0); rem_b : unsigned(31 downto 0))
    return unsigned is
    variable to_bound  : unsigned(10 downto 0);   -- 1..1024 words to the page end
    variable rem_beats : unsigned(30 downto 0);
    variable n         : unsigned(10 downto 0);
  begin
    to_bound  := to_unsigned(1024, 11) - resize(addr(11 downto 2), 11);
    rem_beats := resize(shift_right(rem_b + 3, 2), 31);
    n := to_bound;
    if rem_beats < resize(n, 31) then n := resize(rem_beats, 11); end if;
    if n > 256 then n := to_unsigned(256, 11); end if;
    if n < 1 then n := to_unsigned(1, 11); end if;
    return resize(n, 9);
  end function;
begin

  m_awsize  <= "010";
  m_awburst <= "01";
  fb_sel    <= src_sel;
  fb_re     <= fb_re_i;
  fb_addr   <= std_logic_vector(fb_ptr);
  done      <= done_i;
  m_wdata   <= word_buf;

  -- AXI handshake signals are a pure function of the state (+ stable regs).
  nb_c      <= beats_to_boundary(cur_dst, rem_bytes);
  m_awvalid <= '1' when st = S_ADDR else '0';
  m_awaddr  <= std_logic_vector(cur_dst(31 downto 2)) & "00";
  m_awlen   <= std_logic_vector(resize(nb_c - 1, 8));
  last_c    <= '1' when beat_cnt = beats - 1 else '0';
  m_wvalid  <= '1' when st = S_PUSH else '0';
  m_wlast   <= last_c when st = S_PUSH else '0';
  m_wstrb   <= "0001" when rem_bytes = 1 else
               "0011" when rem_bytes = 2 else
               "0111" when rem_bytes = 3 else
               "1111";
  m_bready  <= '1' when st = S_RESP else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      done_i    <= '0';
      fb_re_i   <= '0';

      if rst='1' then
        st <= S_IDLE;
        fb_ptr <= (others=>'0');
        beats <= to_unsigned(1, 9); beat_cnt <= (others=>'0');
      else
        case st is
          when S_IDLE =>
            if start='1' then
              cur_dst   <= unsigned(dst_addr(31 downto 2)) & "00";
              rem_bytes <= unsigned(length);
              fb_ptr    <= (others=>'0');
              if unsigned(length) = 0 then
                st <= S_DONE;              -- nothing to move
              else
                st <= S_ADDR;
              end if;
            end if;

          -- AWVALID is high in this state; leave only on the handshake.
          when S_ADDR =>
            if m_awready='1' then
              beats    <= nb_c;
              beat_cnt <= (others=>'0');
              fb_re_i  <= '1';             -- prime FB read for byte 0 of word 0
              st <= S_FILL0;
            end if;

          -- assemble one 32-bit little-endian word from 4 FB bytes.
          -- BRAM latency: address presented in a state, data valid next state.
          when S_FILL0 =>
            fb_re_i <= '1';                 -- request byte at fb_ptr
            fb_ptr  <= fb_ptr + 1;
            st <= S_FILL1;
          when S_FILL1 =>
            word_buf(7 downto 0) <= fb_data;   -- byte0 now valid
            fb_re_i <= '1';
            fb_ptr  <= fb_ptr + 1;
            st <= S_FILL2;
          when S_FILL2 =>
            word_buf(15 downto 8) <= fb_data;  -- byte1
            fb_re_i <= '1';
            fb_ptr  <= fb_ptr + 1;
            st <= S_FILL3;
          when S_FILL3 =>
            word_buf(23 downto 16) <= fb_data; -- byte2
            fb_re_i <= '1';
            fb_ptr  <= fb_ptr + 1;
            st <= S_FILLW;
          when S_FILLW =>
            word_buf(31 downto 24) <= fb_data; -- byte3
            st <= S_PUSH;

          -- WVALID is high in this state; WDATA/WSTRB/WLAST are stable here.
          when S_PUSH =>
            if m_wready='1' then
              cur_dst <= cur_dst + 4;
              if rem_bytes > 4 then
                rem_bytes <= rem_bytes - 4;
              else
                rem_bytes <= (others=>'0');
              end if;
              if last_c = '1' then
                st <= S_RESP;
              else
                beat_cnt <= beat_cnt + 1;
                fb_re_i  <= '1';       -- prime next word
                st <= S_FILL0;
              end if;
            end if;

          -- BREADY is high in this state.
          when S_RESP =>
            if m_bvalid='1' then
              if rem_bytes = 0 then
                st <= S_DONE;
              else
                st <= S_ADDR;
              end if;
            end if;

          when S_DONE =>
            done_i <= '1';
            st <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture;
