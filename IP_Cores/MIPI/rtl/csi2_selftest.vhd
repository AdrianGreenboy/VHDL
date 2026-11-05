-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- csi2_selftest: CSI-2 receive top (historical name kept for compatibility).
--
-- AUDIT 2026-11: two selectable byte sources feed ONE dual-VC receiver:
--
--  cfg_src_ext='0' (self-test, default): frame_gen (aclk) -> mipi_byte_fifo
--      -> csi2_dual_rx. frame_gen marks the first byte of every packet
--      (byte_sot) exactly like a D-PHY SoT, so the parser runs in its robust
--      one-packet-per-SoT mode.
--  cfg_src_ext='1' (external D-PHY): PPI ports (ppi_clk = RxByteClkHS domain)
--      -> csi2_lane_rx (sync-byte alignment, deskew, lane merge, EoT)
--      -> mipi_async_fifo (Gray pointers, ppi_clk -> aclk)
--      -> beat-to-byte serializer (aclk, 1 byte/cycle) -> csi2_dual_rx.
--
-- Throughput (honest limit): the packet layer and framebuffer path are
-- byte-wide, 1 byte per aclk. A burst at full PHY rate is sustained only if
-- f_aclk >= cfg_nlanes * f_byteclk; otherwise the async FIFO (2**RXF_AW beats
-- of up to 4 bytes) absorbs the burst and anything beyond it is DROPPED with
-- the rx_ovf event (sticky STATUS bit + IRQ in csi2_mmio), never silently.
--
-- Resets: 'rst' is the aclk-domain synchronous reset. The ppi_clk domain gets
-- its own reset through a 2-flop synchronizer of 'rst' (ppi_clk must run
-- while rst is asserted for the lane layer to be reset).
-- cfg_* are quasi-static (change only while idle); they cross into ppi_clk
-- through 2-flop synchronizers. Error events cross back as toggles.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_selftest is
  generic (
    W : integer := 128;
    H : integer := 96;
    FB_DEPTH : integer := 18432;
    FB_AWID  : integer := 15;
    NL       : integer := 4;
    RXF_AW   : integer := 9
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    start      : in  std_logic;
    done       : out std_logic;       -- both frames received (self-test)
    -- framebuffer read ports (to firmware / DMA)
    fb0_re     : in  std_logic;
    fb0_raddr  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb0_rdata  : out std_logic_vector(7 downto 0);
    fb0_count  : out std_logic_vector(FB_AWID-1 downto 0);
    fb1_re     : in  std_logic;
    fb1_raddr  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb1_rdata  : out std_logic_vector(7 downto 0);
    fb1_count  : out std_logic_vector(FB_AWID-1 downto 0);
    hdr_2bit   : out std_logic;
    -- AUDIT 2026-11: configuration (aclk domain, quasi-static)
    cfg_src_ext   : in  std_logic := '0';
    cfg_nlanes    : in  std_logic_vector(2 downto 0) := "100";
    cfg_hw_sync   : in  std_logic := '0';
    cfg_multi_pkt : in  std_logic := '0';
    -- AUDIT 2026-11: external D-PHY PPI (ppi_clk domain)
    ppi_clk    : in  std_logic := '0';
    ppi_byte   : in  std_logic_vector(8*NL-1 downto 0) := (others => '0');
    ppi_valid  : in  std_logic_vector(NL-1 downto 0) := (others => '0');
    ppi_active : in  std_logic_vector(NL-1 downto 0) := (others => '0');
    ppi_sync   : in  std_logic_vector(NL-1 downto 0) := (others => '0');
    -- AUDIT 2026-11: error / status events (aclk, single-cycle pulses)
    ev_frame   : out std_logic;       -- FE received (any VC)
    ev_rx_ovf  : out std_logic;       -- bytes lost before the packet layer
    ev_pkt_err : out std_logic;       -- packet aborted (ECC / truncation)
    ev_fb_ovf  : out std_logic;       -- packet dropped: framebuffer full
    ev_lane_err: out std_logic        -- deskew timeout / lane FIFO overflow
  );
end entity;

architecture rtl of csi2_selftest is
  -- self-test source
  signal gen_byte  : std_logic_vector(7 downto 0);
  signal gen_valid, gen_sot : std_logic;
  signal gen_busy, gen_done : std_logic;
  signal fifo_byte : std_logic_vector(7 downto 0);
  signal fifo_valid, fifo_sot : std_logic;
  signal fifo_full, fifo_empty, fifo_ovf : std_logic;
  signal fifo_ovf_q : std_logic := '0';

  -- external source, ppi_clk domain
  signal prst_m, prst : std_logic := '1';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of prst_m, prst : signal is "TRUE";
  signal pcfg_nl_m, pcfg_nl : std_logic_vector(2 downto 0) := "100";
  signal pcfg_hw_m, pcfg_hw : std_logic := '0';
  attribute ASYNC_REG of pcfg_nl_m, pcfg_nl, pcfg_hw_m, pcfg_hw : signal is "TRUE";
  signal ln_valid, ln_sot, ln_eot, ln_ed, ln_el : std_logic;
  signal ln_data : std_logic_vector(8*NL-1 downto 0);
  signal ln_cnt  : std_logic_vector(2 downto 0);
  signal af_wdata, af_rdata : std_logic_vector(8*NL+4 downto 0);
  signal af_full, af_empty, af_rvalid, af_ovf, af_rd : std_logic;
  signal lerr_tgl : std_logic := '0';
  signal le1, le2, le3 : std_logic := '0';
  attribute ASYNC_REG of le1, le2 : signal is "TRUE";

  -- external source, aclk serializer
  signal hold_data : std_logic_vector(8*NL-1 downto 0) := (others => '0');
  signal hold_cnt  : integer range 0 to NL := 0;
  signal hold_idx  : integer range 0 to NL := 0;
  signal rd_pend   : std_logic := '0';
  signal ext_byte  : std_logic_vector(7 downto 0) := (others => '0');
  signal ext_valid, ext_sot, ext_eot : std_logic := '0';

  -- receiver input mux
  signal rx_byte : std_logic_vector(7 downto 0);
  signal rx_valid, rx_sot, rx_eot, rx_multi : std_logic;

  signal frame_done : std_logic;
  signal fe_count : unsigned(1 downto 0) := (others=>'0');
  signal gen_started : std_logic := '0';
  signal done_i : std_logic := '0';
begin
  ---------------------------------------------------------------- self-test
  gen : entity work.frame_gen
    generic map (W=>W, H=>H, BAR_W=>16)
    port map (clk=>clk, rst=>rst, start=>start, stall=>fifo_full,
              byte_out=>gen_byte, byte_valid=>gen_valid, byte_sot=>gen_sot,
              busy=>gen_busy, done=>gen_done);

  fifo : entity work.mipi_byte_fifo
    generic map (DEPTH=>512, AWID=>9)
    port map (clk=>clk, rst=>rst,
              wr_byte=>gen_byte, wr_valid=>gen_valid, wr_sot=>gen_sot, full=>fifo_full,
              rd_byte=>fifo_byte, rd_valid=>fifo_valid, rd_sot=>fifo_sot,
              empty=>fifo_empty, ovf=>fifo_ovf, ovf_clr=>'0');

  ---------------------------------------------------------------- PPI domain
  process(ppi_clk)
  begin
    if rising_edge(ppi_clk) then
      prst_m <= rst;  prst <= prst_m;            -- reset synchronizer
      pcfg_nl_m <= cfg_nlanes; pcfg_nl <= pcfg_nl_m;
      pcfg_hw_m <= cfg_hw_sync; pcfg_hw <= pcfg_hw_m;
      if ln_ed = '1' or ln_el = '1' then lerr_tgl <= not lerr_tgl; end if;
    end if;
  end process;

  lanes : entity work.csi2_lane_rx
    generic map (NL => NL)
    port map (clk => ppi_clk, rst => prst, cfg_nlanes => pcfg_nl, cfg_hw_sync => pcfg_hw,
              rx_byte => ppi_byte, rx_valid => ppi_valid, rx_active => ppi_active,
              rx_sync => ppi_sync,
              out_valid => ln_valid, out_data => ln_data, out_cnt => ln_cnt,
              out_sot => ln_sot, out_eot => ln_eot,
              err_deskew => ln_ed, err_lane => ln_el);

  af_wdata <= ln_eot & ln_sot & ln_cnt & ln_data;

  afifo : entity work.mipi_async_fifo
    generic map (DW => 8*NL+5, AW => RXF_AW)
    port map (wclk => ppi_clk, wrst => prst, wr_en => ln_valid, wr_data => af_wdata,
              wr_full => af_full,
              rclk => clk, rrst => rst, rd_en => af_rd, rd_data => af_rdata,
              rd_valid => af_rvalid, rd_empty => af_empty, ovf_pulse => af_ovf);

  ---------------------------------------------------------------- serializer
  -- The FIFO read is registered (beat valid 1 cycle after af_rd). Byte 0 of a
  -- beat is emitted straight from af_rdata in its valid cycle, bytes 1..cnt-1
  -- from the holding register, and the next read is issued while the last
  -- byte of the current beat is emitted -> 1 byte per aclk sustained.
  af_rd <= '1' when af_empty = '0' and rd_pend = '0' and
                    (hold_idx >= hold_cnt or hold_idx = hold_cnt - 1) else '0';

  process(clk)
    variable cntv : integer range 0 to 7;
  begin
    if rising_edge(clk) then
      ext_valid <= '0'; ext_sot <= '0'; ext_eot <= '0';
      if rst = '1' then
        hold_cnt <= 0; hold_idx <= 0; rd_pend <= '0';
      else
        if af_rd = '1' then rd_pend <= '1'; end if;
        if af_rvalid = '1' then
          rd_pend <= '0';
          cntv := to_integer(unsigned(af_rdata(8*NL+2 downto 8*NL)));
          if cntv > NL then cntv := NL; end if;
          hold_data <= af_rdata(8*NL-1 downto 0);
          hold_cnt  <= cntv;
          if cntv > 0 then
            ext_byte  <= af_rdata(7 downto 0);
            ext_valid <= '1';
            ext_sot   <= af_rdata(8*NL+3);
            hold_idx  <= 1;
          else
            hold_idx  <= 0;
          end if;
          if af_rdata(8*NL+4) = '1' then ext_eot <= '1'; end if;   -- EoT marker
        elsif hold_idx < hold_cnt then
          ext_byte  <= hold_data(8*hold_idx+7 downto 8*hold_idx);
          ext_valid <= '1';
          hold_idx  <= hold_idx + 1;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------- receiver
  rx_byte  <= ext_byte  when cfg_src_ext = '1' else fifo_byte;
  rx_valid <= ext_valid when cfg_src_ext = '1' else fifo_valid;
  rx_sot   <= ext_sot   when cfg_src_ext = '1' else fifo_sot;
  rx_eot   <= ext_eot   when cfg_src_ext = '1' else '0';
  rx_multi <= cfg_multi_pkt when cfg_src_ext = '1' else '0';

  rx : entity work.csi2_dual_rx
    generic map (FB_DEPTH=>FB_DEPTH, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst,
              byte_in=>rx_byte, byte_valid=>rx_valid,
              byte_sot=>rx_sot, byte_eot=>rx_eot, cfg_multi_pkt=>rx_multi,
              frame_done=>frame_done,
              fb0_re=>fb0_re, fb0_raddr=>fb0_raddr, fb0_rdata=>fb0_rdata, fb0_count=>fb0_count,
              fb1_re=>fb1_re, fb1_raddr=>fb1_raddr, fb1_rdata=>fb1_rdata, fb1_count=>fb1_count,
              hdr_2bit=>hdr_2bit, pkt_err=>ev_pkt_err, fb_ovf=>ev_fb_ovf);

  ---------------------------------------------------------------- events
  process(clk)
  begin
    if rising_edge(clk) then
      le1 <= lerr_tgl; le2 <= le1; le3 <= le2;
      fifo_ovf_q <= fifo_ovf;
    end if;
  end process;
  ev_lane_err <= le2 xor le3;
  ev_rx_ovf   <= af_ovf or (fifo_ovf and not fifo_ovf_q);
  ev_frame    <= frame_done;

  -- done when both frame-end packets have been received (2 VCs).
  -- Gated by gen_started so a spurious frame_done during reset/startup (before
  -- any real data) cannot latch done early.
  process(clk)
  begin
    if rising_edge(clk) then
      done_i <= '0';
      if rst='1' then
        fe_count <= (others=>'0');
        gen_started <= '0';
      else
        if gen_busy='1' then
          gen_started <= '1';
        end if;
        if frame_done='1' and gen_started='1' then
          if fe_count = 1 then
            done_i <= '1';
            fe_count <= (others=>'0');
          else
            fe_count <= fe_count + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
  done <= done_i;
end architecture;
