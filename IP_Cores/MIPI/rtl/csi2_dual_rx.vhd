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
--
-- AUDIT 2026-11:
--  * Framebuffer overflow: a payload byte is written only while the VC's
--    speculative pointer is < FB_DEPTH. A byte arriving with the pointer at
--    FB_DEPTH is not written, the packet is marked overflowed and, at its CRC
--    check, it is DROPPED (pointer rolled back) even if the CRC is good;
--    fb_ovf pulses. The pointer can never wrap or index past the RAM.
--  * Frame Start (FS) on VC0/VC1 rewinds that VC's pointers to 0, so every
--    frame lands at offset 0 (previously a second frame appended and wrapped).
--  * byte_sot / byte_eot / cfg_multi_pkt are passed to csi2_packet_rx
--    (ECC abort + resync, truncation); pkt_err pulses on any packet abort.
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
    byte_sot   : in  std_logic := '0';
    byte_eot   : in  std_logic := '0';
    cfg_multi_pkt : in std_logic := '1';
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
    hdr_2bit   : out std_logic;
    pkt_err    : out std_logic;         -- pulse: packet aborted (ECC/SoT/EoT)
    fb_ovf     : out std_logic          -- pulse: packet dropped, FB full
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
  signal perr      : std_logic;
  signal pkt_ovf   : std_logic := '0';     -- current packet hit FB_DEPTH
  signal fb_ovf_i  : std_logic := '0';
  signal full0, full1 : std_logic;

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

  assert FB_DEPTH < 2**FB_AWID
    report "csi2_dual_rx: FB_AWID must hold the value FB_DEPTH (overflow clamp)"
    severity failure;

  pkt : entity work.csi2_packet_rx
    port map (clk=>clk, rst=>rst, byte_in=>byte_in, byte_valid=>byte_valid,
              byte_sot=>byte_sot, byte_eot=>byte_eot, cfg_multi_pkt=>cfg_multi_pkt,
              pl_byte=>pl_byte, pl_valid=>pl_valid, pl_commit=>pl_commit,
              pl_drop=>pl_drop, sop=>sop, is_long=>is_long,
              vc_out=>vc_out, dt_out=>dt_out, hdr_2bit=>hdr2, pkt_err=>perr);

  fb0 : entity work.framebuffer
    generic map (DEPTH=>FB_DEPTH, AWID=>FB_AWID)
    port map (clk=>clk, we=>we0, waddr=>waddr0, wdata=>pl_byte,
              re=>fb0_re, raddr=>fb0_raddr, rdata=>fb0_rdata);

  fb1 : entity work.framebuffer
    generic map (DEPTH=>FB_DEPTH, AWID=>FB_AWID)
    port map (clk=>clk, we=>we1, waddr=>waddr1, wdata=>pl_byte,
              re=>fb1_re, raddr=>fb1_raddr, rdata=>fb1_rdata);

  -- demux: write enable to the framebuffer selected by the current VC
  full0  <= '1' when to_integer(spec0) >= FB_DEPTH else '0';
  full1  <= '1' when to_integer(spec1) >= FB_DEPTH else '0';
  we0    <= '1' when (pl_valid='1' and cur_vc="00" and full0='0') else '0';
  we1    <= '1' when (pl_valid='1' and cur_vc="01" and full1='0') else '0';
  waddr0 <= std_logic_vector(spec0);
  waddr1 <= std_logic_vector(spec1);

  process(clk)
  begin
    if rising_edge(clk) then
      frame_done_i <= '0';
      fb_ovf_i <= '0';
      if rst='1' then
        base0<=(others=>'0'); spec0<=(others=>'0');
        base1<=(others=>'0'); spec1<=(others=>'0');
        cur_vc<="00"; pkt_ovf <= '0';
      else
        -- latch VC at start of packet
        if sop='1' then
          cur_vc <= vc_out;
          pkt_ovf <= '0';
        end if;

        -- advance speculative pointer of the active VC on each payload byte,
        -- clamped at FB_DEPTH (the byte is then not written: see we0/we1)
        if pl_valid='1' then
          if cur_vc="00" then
            if full0='0' then spec0 <= spec0 + 1; else pkt_ovf <= '1'; end if;
          elsif cur_vc="01" then
            if full1='0' then spec1 <= spec1 + 1; else pkt_ovf <= '1'; end if;
          end if;
        end if;

        -- commit / drop per VC (an overflowed packet is dropped)
        if pl_commit='1' and pkt_ovf='0' then
          if cur_vc="00" then base0 <= spec0;
          elsif cur_vc="01" then base1 <= spec1;
          end if;
        end if;
        if pl_drop='1' or (pl_commit='1' and pkt_ovf='1') then
          if cur_vc="00" then spec0 <= base0;
          elsif cur_vc="01" then spec1 <= base1;
          end if;
          if pkt_ovf='1' and (cur_vc="00" or cur_vc="01") then fb_ovf_i <= '1'; end if;
          pkt_ovf <= '0';
        end if;

        -- Frame Start rewinds the VC's framebuffer to offset 0
        if sop='1' and is_long='0' and dt_out="000000" then
          if vc_out="00" then base0 <= (others=>'0'); spec0 <= (others=>'0');
          elsif vc_out="01" then base1 <= (others=>'0'); spec1 <= (others=>'0');
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
  pkt_err    <= perr;
  fb_ovf     <= fb_ovf_i;

end architecture;
