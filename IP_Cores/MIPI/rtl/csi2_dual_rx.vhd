-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L4: dual-VC frame receiver with real demux to TWO framebuffers.
-- One csi2_packet_rx parses the interleaved stream; the decoded VC selects
-- which framebuffer receives the validated payload. Each VC has independent
-- speculative/committed write pointers and per-line CRC commit.
--
--   VC0 -> FB0  (gradient frame in the self-test)
--   VC1 -> FB1  (vertical-bars frame in the self-test)
--
-- Signature (TB): FNV(FB0 bytes ++ FB1 bytes) must equal the oracle golden.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_dual_rx is
  generic (
    FB_DEPTH : integer := 18432;
    FB_AWID  : integer := 15
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    byte_in    : in  std_logic_vector(7 downto 0);
    byte_valid : in  std_logic;
    frame_done : out std_logic;
    -- framebuffer read ports
    fb0_re     : in  std_logic;
    fb0_raddr  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb0_rdata  : out std_logic_vector(7 downto 0);
    fb0_count  : out std_logic_vector(FB_AWID-1 downto 0);
    fb1_re     : in  std_logic;
    fb1_raddr  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb1_rdata  : out std_logic_vector(7 downto 0);
    fb1_count  : out std_logic_vector(FB_AWID-1 downto 0);
    hdr_2bit   : out std_logic
  );
end entity;

architecture rtl of csi2_dual_rx is
  signal pl_byte   : std_logic_vector(7 downto 0);
  signal pl_valid  : std_logic;
  signal pl_commit : std_logic;
  signal pl_drop   : std_logic;
  signal sop       : std_logic;
  signal is_long   : std_logic;
  signal vc_out    : std_logic_vector(1 downto 0);
  signal dt_out    : std_logic_vector(5 downto 0);
  signal hdr2      : std_logic;

  -- per-VC pointers
  signal base0, spec0 : unsigned(FB_AWID-1 downto 0) := (others=>'0');
  signal base1, spec1 : unsigned(FB_AWID-1 downto 0) := (others=>'0');

  -- write muxing
  signal we0, we1 : std_logic;
  signal waddr0, waddr1 : std_logic_vector(FB_AWID-1 downto 0);

  signal frame_done_i : std_logic := '0';

  -- current packet VC latched at sop (vc_out already persists, but latch for clarity)
  signal cur_vc : std_logic_vector(1 downto 0) := "00";
begin

  pkt : entity work.csi2_packet_rx
    port map (clk=>clk, rst=>rst, byte_in=>byte_in, byte_valid=>byte_valid,
              pl_byte=>pl_byte, pl_valid=>pl_valid, pl_commit=>pl_commit,
              pl_drop=>pl_drop, sop=>sop, is_long=>is_long,
              vc_out=>vc_out, dt_out=>dt_out, hdr_2bit=>hdr2);

  fb0 : entity work.framebuffer
    generic map (DEPTH=>FB_DEPTH, AWID=>FB_AWID)
    port map (clk=>clk, we=>we0, waddr=>waddr0, wdata=>pl_byte,
              re=>fb0_re, raddr=>fb0_raddr, rdata=>fb0_rdata);

  fb1 : entity work.framebuffer
    generic map (DEPTH=>FB_DEPTH, AWID=>FB_AWID)
    port map (clk=>clk, we=>we1, waddr=>waddr1, wdata=>pl_byte,
              re=>fb1_re, raddr=>fb1_raddr, rdata=>fb1_rdata);

  -- demux: write enable to the framebuffer selected by the current VC
  we0    <= '1' when (pl_valid='1' and cur_vc="00") else '0';
  we1    <= '1' when (pl_valid='1' and cur_vc="01") else '0';
  waddr0 <= std_logic_vector(spec0);
  waddr1 <= std_logic_vector(spec1);

  process(clk)
  begin
    if rising_edge(clk) then
      frame_done_i <= '0';
      if rst='1' then
        base0<=(others=>'0'); spec0<=(others=>'0');
        base1<=(others=>'0'); spec1<=(others=>'0');
        cur_vc<="00";
      else
        -- latch VC at start of packet
        if sop='1' then
          cur_vc <= vc_out;
        end if;

        -- advance speculative pointer of the active VC on each payload byte
        if pl_valid='1' then
          if cur_vc="00" then spec0 <= spec0 + 1;
          elsif cur_vc="01" then spec1 <= spec1 + 1;
          end if;
        end if;

        -- commit / drop per VC
        if pl_commit='1' then
          if cur_vc="00" then base0 <= spec0;
          elsif cur_vc="01" then base1 <= spec1;
          end if;
        end if;
        if pl_drop='1' then
          if cur_vc="00" then spec0 <= base0;
          elsif cur_vc="01" then spec1 <= base1;
          end if;
        end if;

        -- frame end (any VC)
        if sop='1' and is_long='0' and dt_out="000001" then
          frame_done_i <= '1';
        end if;
      end if;
    end if;
  end process;

  frame_done <= frame_done_i;
  fb0_count  <= std_logic_vector(base0);
  fb1_count  <= std_logic_vector(base1);
  hdr_2bit   <= hdr2;

end architecture;
