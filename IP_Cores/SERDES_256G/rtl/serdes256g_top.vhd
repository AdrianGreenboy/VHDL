-------------------------------------------------------------------------------
-- SERDES_256G - top level
-- Multi-lane 64B/66B link layer: G_LANES x 128-bit raw GT channels.
-- 8 lanes x 32 Gb/s = 256 Gb/s on the wire (248.2 Gb/s of 64B/66B payload).
--
--   TX (tx_clk = GT TX user clock, line_rate/128):
--     s_axis_tx -> tx_frame -> G_LANES x tx_lane -> gt_txdata
--   RX:
--     gt_rxdata -> G_LANES x rx_lane (each in its own gt_rxusrclk)
--               -> G_LANES x afifo -> rx_align -> rx_frame -> m_axis_rx (rx_clk)
--
-- The core is rate-agnostic: the line rate is set by the GT configuration
-- only. Lane order and lane skew on the RX side are arbitrary (the alignment
-- markers carry the lane id). RX polarity must be correct (GT RXPOLARITY).
--
-- Clocks and resets
--   tx_clk / tx_rst       synchronous reset, tx_clk
--   rx_clk / rx_rst       synchronous reset, rx_clk; also the (asynchronously
--                         asserted) source of the per-lane resets
--   gt_rxusrclk(L)        recovered user clock of lane L
--
-- Status (rx_clk unless noted)
--   rx_block_lock   per PHYSICAL lane, in its gt_rxusrclk domain (debug)
--   rx_am_lock      per physical lane, synchronised
--   rx_aligned      all lanes deskewed and lane map valid: link is up
--   rx_lane_map     logical lane id carried by each physical lane (4 bit each)
--   remote_aligned  the far end reports its own rx_aligned (AM_B status bit 0)
--   bip_err_cnt     16-bit saturating BIP-8 error counter per physical lane
--   am_err/hdr_err  1-clock pulses per physical lane
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.serdes256g_pkg.all;

entity serdes256g_top is
  generic (
    G_LANES     : positive range 1 to 16 := 8;
    G_AM_PERIOD : positive := 16384;     -- lane words between alignment markers
    G_FIFO_AW   : positive := 6          -- deskew FIFO depth = 2**G_FIFO_AW words
  );
  port (
    -- TX user side
    tx_clk          : in  std_logic;
    tx_rst          : in  std_logic;
    s_axis_tx_tdata : in  std_logic_vector(G_LANES*128-1 downto 0);
    s_axis_tx_tkeep : in  std_logic_vector(G_LANES*16-1 downto 0);
    s_axis_tx_tlast : in  std_logic;
    s_axis_tx_tvalid: in  std_logic;
    s_axis_tx_tready: out std_logic;
    -- GT TX (lane L at 128*L), all lanes in tx_clk
    gt_txdata       : out std_logic_vector(G_LANES*128-1 downto 0);
    -- GT RX (lane L at 128*L), lane L in gt_rxusrclk(L)
    gt_rxusrclk     : in  std_logic_vector(G_LANES-1 downto 0);
    gt_rxdata       : in  std_logic_vector(G_LANES*128-1 downto 0);
    -- RX user side
    rx_clk          : in  std_logic;
    rx_rst          : in  std_logic;
    m_axis_rx_tdata : out std_logic_vector(G_LANES*128-1 downto 0);
    m_axis_rx_tkeep : out std_logic_vector(G_LANES*16-1 downto 0);
    m_axis_rx_tlast : out std_logic;
    m_axis_rx_tuser : out std_logic;
    m_axis_rx_tvalid: out std_logic;
    -- status
    rx_block_lock   : out std_logic_vector(G_LANES-1 downto 0);
    rx_am_lock      : out std_logic_vector(G_LANES-1 downto 0);
    rx_aligned      : out std_logic;
    rx_lane_map     : out std_logic_vector(G_LANES*4-1 downto 0);
    remote_aligned  : out std_logic;
    cnt_clr         : in  std_logic := '0';
    bip_err_cnt     : out std_logic_vector(G_LANES*16-1 downto 0);
    am_err          : out std_logic_vector(G_LANES-1 downto 0);
    hdr_err         : out std_logic_vector(G_LANES-1 downto 0);
    map_err         : out std_logic
  );
end entity serdes256g_top;

architecture rtl of serdes256g_top is
  signal txf_word  : std_logic_vector(G_LANES*132-1 downto 0);
  signal txf_valid : std_logic;
  signal txf_am    : std_logic;
  signal tx_status : std_logic_vector(7 downto 0);

  signal lane_rst  : std_logic_vector(G_LANES-1 downto 0);
  signal lrst_m    : std_logic_vector(G_LANES-1 downto 0) := (others => '1');
  signal lrst_s    : std_logic_vector(G_LANES-1 downto 0) := (others => '1');

  signal f_wr      : std_logic_vector(G_LANES-1 downto 0);
  signal f_full    : std_logic_vector(G_LANES-1 downto 0);
  signal f_din     : std_logic_vector(G_LANES*133-1 downto 0);
  signal f_dout    : std_logic_vector(G_LANES*133-1 downto 0);
  signal f_empty   : std_logic_vector(G_LANES-1 downto 0);
  signal f_rd      : std_logic_vector(G_LANES-1 downto 0);

  signal amlk_l    : std_logic_vector(G_LANES-1 downto 0);   -- lane domains
  signal amlk_m    : std_logic_vector(G_LANES-1 downto 0) := (others => '0');
  signal amlk_s    : std_logic_vector(G_LANES-1 downto 0) := (others => '0');

  signal al_word   : std_logic_vector(G_LANES*132-1 downto 0);
  signal al_valid  : std_logic;
  signal aligned_i : std_logic;
  signal rem_stat  : std_logic_vector(7 downto 0);
  signal bip_p     : std_logic_vector(G_LANES-1 downto 0);

  signal al_tx_m, al_tx_s : std_logic := '0';                -- aligned in tx_clk

  type t_cnt is array (0 to G_LANES-1) of unsigned(15 downto 0);
  signal bip_cnt : t_cnt := (others => (others => '0'));

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of lrst_m, lrst_s   : signal is "TRUE";
  attribute ASYNC_REG of amlk_m, amlk_s   : signal is "TRUE";
  attribute ASYNC_REG of al_tx_m, al_tx_s : signal is "TRUE";
begin

  -----------------------------------------------------------------------------
  -- TX
  -----------------------------------------------------------------------------
  u_tx_frame : entity work.serdes256g_tx_frame
    generic map (G_LANES => G_LANES, G_AM_PERIOD => G_AM_PERIOD)
    port map (
      clk => tx_clk, rst => tx_rst,
      s_tdata => s_axis_tx_tdata, s_tkeep => s_axis_tx_tkeep,
      s_tlast => s_axis_tx_tlast, s_tvalid => s_axis_tx_tvalid,
      s_tready => s_axis_tx_tready,
      o_word => txf_word, o_valid => txf_valid, o_am => txf_am);

  -- local link status towards the far end (AM_B status bit 0)
  process(tx_clk)
  begin
    if rising_edge(tx_clk) then
      al_tx_m <= aligned_i;
      al_tx_s <= al_tx_m;
    end if;
  end process;
  tx_status <= "0000000" & al_tx_s;

  g_lane : for l in 0 to G_LANES-1 generate
  begin
    u_tx_lane : entity work.serdes256g_tx_lane
      generic map (G_LANE_ID => l)
      port map (
        clk => tx_clk, rst => tx_rst,
        in_word  => txf_word(132*l+131 downto 132*l),
        in_valid => txf_valid, in_am => txf_am,
        status   => tx_status,
        gt_txdata => gt_txdata(128*l+127 downto 128*l));

    -- lane reset: asynchronous assert, synchronous release
    process(gt_rxusrclk(l), rx_rst)
    begin
      if rx_rst = '1' then
        lrst_m(l) <= '1';
        lrst_s(l) <= '1';
      elsif rising_edge(gt_rxusrclk(l)) then
        lrst_m(l) <= '0';
        lrst_s(l) <= lrst_m(l);
      end if;
    end process;
    lane_rst(l) <= lrst_s(l);

    u_rx_lane : entity work.serdes256g_rx_lane
      generic map (G_AM_PERIOD => G_AM_PERIOD)
      port map (
        clk => gt_rxusrclk(l), rst => lane_rst(l),
        gt_rxdata => gt_rxdata(128*l+127 downto 128*l),
        fifo_full => f_full(l), fifo_wr => f_wr(l),
        fifo_din  => f_din(133*l+132 downto 133*l),
        block_lock => rx_block_lock(l), am_lock => amlk_l(l));

    u_fifo : entity work.serdes256g_afifo
      generic map (G_AW => G_FIFO_AW, G_DW => 133)
      port map (
        wclk => gt_rxusrclk(l), wrst => lane_rst(l),
        wr => f_wr(l), din => f_din(133*l+132 downto 133*l), full => f_full(l),
        rclk => rx_clk, rrst => rx_rst,
        rd => f_rd(l), dout => f_dout(133*l+132 downto 133*l),
        empty => f_empty(l));
  end generate g_lane;

  -----------------------------------------------------------------------------
  -- RX common part
  -----------------------------------------------------------------------------
  process(rx_clk)
  begin
    if rising_edge(rx_clk) then
      amlk_m <= amlk_l;
      amlk_s <= amlk_m;
    end if;
  end process;

  u_rx_align : entity work.serdes256g_rx_align
    generic map (G_LANES => G_LANES, G_FIFO_AW => G_FIFO_AW)
    port map (
      clk => rx_clk, rst => rx_rst, lane_up => amlk_s,
      f_dout => f_dout, f_empty => f_empty, f_rd => f_rd,
      o_word => al_word, o_valid => al_valid, aligned => aligned_i,
      lane_map => rx_lane_map, rem_status => rem_stat,
      bip_err => bip_p, am_err => am_err, hdr_err => hdr_err,
      map_err => map_err);

  u_rx_frame : entity work.serdes256g_rx_frame
    generic map (G_LANES => G_LANES)
    port map (
      clk => rx_clk, rst => rx_rst, link_up => aligned_i,
      in_word => al_word, in_valid => al_valid,
      m_tdata => m_axis_rx_tdata, m_tkeep => m_axis_rx_tkeep,
      m_tlast => m_axis_rx_tlast, m_tuser => m_axis_rx_tuser,
      m_tvalid => m_axis_rx_tvalid);

  rx_am_lock     <= amlk_s;
  rx_aligned     <= aligned_i;
  remote_aligned <= aligned_i and rem_stat(0);

  process(rx_clk)
  begin
    if rising_edge(rx_clk) then
      for l in 0 to G_LANES-1 loop
        if rx_rst = '1' or cnt_clr = '1' then
          bip_cnt(l) <= (others => '0');
        elsif bip_p(l) = '1' and bip_cnt(l) /= x"FFFF" then
          bip_cnt(l) <= bip_cnt(l) + 1;
        end if;
      end loop;
    end if;
  end process;

  process(all)
  begin
    for l in 0 to G_LANES-1 loop
      bip_err_cnt(16*l+15 downto 16*l) <= std_logic_vector(bip_cnt(l));
    end loop;
  end process;

end architecture rtl;
