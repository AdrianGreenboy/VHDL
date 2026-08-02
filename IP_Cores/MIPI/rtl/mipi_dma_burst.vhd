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
  signal beats     : unsigned(7 downto 0) := (others=>'0');
  signal beat_cnt  : unsigned(7 downto 0) := (others=>'0');

  signal word_buf  : std_logic_vector(31 downto 0) := (others=>'0');

  signal done_i  : std_logic := '0';
  signal fb_re_i : std_logic := '0';

  function beats_to_boundary(addr : unsigned(31 downto 0); rem_b : unsigned(31 downto 0))
    return unsigned is
    variable page_off  : unsigned(11 downto 0);
    variable to_bound  : integer;
    variable rem_beats : integer;
    variable n         : integer;
  begin
    page_off := addr(11 downto 0);
    to_bound := (4096 - to_integer(page_off)) / 4;
    rem_beats := (to_integer(rem_b) + 3) / 4;
    n := to_bound;
    if rem_beats < n then n := rem_beats; end if;
    if n > 256 then n := 256; end if;
    if n < 1 then n := 1; end if;
    return to_unsigned(n, 8);
  end function;
begin

  m_awsize  <= "010";
  m_awburst <= "01";
  m_wstrb   <= "1111";
  fb_sel    <= src_sel;
  fb_re     <= fb_re_i;
  fb_addr   <= std_logic_vector(fb_ptr);
  done      <= done_i;
  m_wdata   <= word_buf;

  process(clk)
    variable nb : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      done_i    <= '0';
      m_awvalid <= '0';
      m_wvalid  <= '0';
      m_wlast   <= '0';
      m_bready  <= '0';
      fb_re_i   <= '0';

      if rst='1' then
        st <= S_IDLE;
        fb_ptr <= (others=>'0');
      else
        case st is
          when S_IDLE =>
            if start='1' then
              cur_dst   <= unsigned(dst_addr);
              rem_bytes <= unsigned(length);
              fb_ptr    <= (others=>'0');
              st <= S_ADDR;
            end if;

          -- issue write address for this burst (bounded by 4 KB page)
          when S_ADDR =>
            nb := beats_to_boundary(cur_dst, rem_bytes);
            beats    <= nb;
            beat_cnt <= (others=>'0');
            m_awaddr  <= std_logic_vector(cur_dst);
            m_awlen   <= std_logic_vector(nb - 1);
            m_awvalid <= '1';
            if m_awready='1' then
              -- prime FB read for first byte of first word
              fb_re_i <= '1';
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

          -- push the assembled word on the AXI W channel
          when S_PUSH =>
            m_wvalid <= '1';
            if beat_cnt = beats - 1 then
              m_wlast <= '1';
            end if;
            if m_wready='1' then
              cur_dst   <= cur_dst + 4;
              rem_bytes <= rem_bytes - 4;
              if beat_cnt = beats - 1 then
                st <= S_RESP;
              else
                beat_cnt <= beat_cnt + 1;
                fb_re_i  <= '1';       -- prime next word
                st <= S_FILL0;
              end if;
            end if;

          when S_RESP =>
            m_bready <= '1';
            if m_bvalid='1' then
              if rem_bytes = 0 or rem_bytes(31)='1' then
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
