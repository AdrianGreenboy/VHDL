-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- csi2_lane_rx (AUDIT 2026-11): CSI-2 lane-management layer, D-PHY byte clock
-- domain. Replaces the former passthrough "deskew" of dphy_model.
--
-- Input: one PPI-like byte interface per lane (all lanes on one byte clock,
-- as provided by a D-PHY RX with a shared RxByteClkHS / the FPGA ISERDES
-- byte clock):  RxByteHS[7:0], RxValidHS, RxActiveHS, RxSyncHS.
--
-- Per lane:
--  * cfg_hw_sync='0' (raw deserializer, e.g. ISERDES): bytes are NOT aligned.
--    From RxActiveHS rising, every byte is appended to a 16-bit window
--    {byte_t, byte_t-1} (bit 0 = first bit on the wire, D-PHY sends LSB first)
--    and the SoT sync byte 0xB8 is searched at bit offsets 0..7 (the HS-zero
--    leader before it is all zeros, so the first match is unique). The offset
--    is locked for the rest of the burst and every later byte is re-aligned:
--    data = window(k+7 downto k).
--  * cfg_hw_sync='1' (PHY already aligned, sync byte removed): every byte with
--    RxValidHS='1' while RxActiveHS='1' is a data byte (RxSyncHS is ignored).
--  * aligned data bytes enter an 8-deep deskew FIFO.
-- Merge (lane distribution, CSI-2: byte n of a packet stream is on lane
-- n mod NLANES, lane 0 = LSB / first):
--  * the burst starts when every active lane has data (absorbs per-lane skew
--    up to the FIFO depth); a lane that does not deliver within
--    DESKEW_TIMEOUT byte clocks raises err_deskew and the burst is flushed;
--  * a beat takes one byte from each active lane (lane order); when lanes end
--    with different byte counts (EoT), only lanes still holding data
--    contribute, so the last beat carries 1..NLANES bytes;
--  * when every active lane has ended (RxActiveHS low) and is drained, a
--    zero-byte beat with out_eot='1' closes the burst.
-- Output beats (byte clock): out_data(8*i+7..8*i) = i-th byte of the beat,
-- out_cnt = number of valid bytes (0..4), out_sot on the first beat.
-- Raw-PHY note: D-PHY trailer bytes are delivered as data until RxActiveHS
-- falls; the packet layer ignores them (cfg_multi_pkt='0', length from WC).
-- cfg_* are quasi-static: change them only while no burst is in progress.
-- Requirement: LP gap between bursts >= a few byte clocks (always true for
-- D-PHY: T_LPX + T_HS-PREPARE + T_HS-ZERO).
-- Synchronous active-high reset.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_lane_rx is
  generic (
    NL             : integer := 4;     -- physical lanes (max)
    DESKEW_TIMEOUT : integer := 32     -- byte clocks
  );
  port (
    clk        : in  std_logic;        -- RxByteClkHS
    rst        : in  std_logic;
    cfg_nlanes : in  std_logic_vector(2 downto 0);   -- 1..NL active lanes
    cfg_hw_sync: in  std_logic;
    -- PPI per lane
    rx_byte    : in  std_logic_vector(8*NL-1 downto 0);
    rx_valid   : in  std_logic_vector(NL-1 downto 0);
    rx_active  : in  std_logic_vector(NL-1 downto 0);
    rx_sync    : in  std_logic_vector(NL-1 downto 0);
    -- merged beats
    out_valid  : out std_logic;
    out_data   : out std_logic_vector(8*NL-1 downto 0);
    out_cnt    : out std_logic_vector(2 downto 0);
    out_sot    : out std_logic;
    out_eot    : out std_logic;
    -- error pulses
    err_deskew : out std_logic;
    err_lane   : out std_logic         -- lane deskew FIFO overflow
  );
end entity;

architecture rtl of csi2_lane_rx is
  constant FD : integer := 8;
  type fifo_t   is array (0 to FD-1) of std_logic_vector(7 downto 0);
  type fifos_t  is array (0 to NL-1) of fifo_t;
  type ptr_t    is array (0 to NL-1) of integer range 0 to FD-1;
  type cnt_t    is array (0 to NL-1) of integer range 0 to FD;
  type off_t    is array (0 to NL-1) of integer range 0 to 7;
  type byte_a_t is array (0 to NL-1) of std_logic_vector(7 downto 0);

  constant SYNC_BYTE : std_logic_vector(7 downto 0) := x"B8";

  signal fifo   : fifos_t := (others => (others => (others => '0')));
  signal wp, rp : ptr_t := (others => 0);
  signal cnt    : cnt_t := (others => 0);
  signal prev   : byte_a_t := (others => (others => '0'));
  signal locked : std_logic_vector(NL-1 downto 0) := (others => '0');
  signal ended  : std_logic_vector(NL-1 downto 0) := (others => '0');
  signal seen   : std_logic_vector(NL-1 downto 0) := (others => '0');  -- active seen
  signal offs   : off_t := (others => 0);

  type mst_t is (M_IDLE, M_RUN, M_DRAIN);
  signal mst : mst_t := M_IDLE;
  signal tmo : integer range 0 to DESKEW_TIMEOUT := 0;

  signal ov, os, oe, ed, el : std_logic := '0';
  signal od : std_logic_vector(8*NL-1 downto 0) := (others => '0');
  signal oc : unsigned(2 downto 0) := (others => '0');
begin

  process(clk)
    variable nl_v     : integer range 0 to 7;
    variable act      : std_logic_vector(NL-1 downto 0);
    variable w        : std_logic_vector(15 downto 0);
    variable b        : std_logic_vector(7 downto 0);
    variable push     : std_logic_vector(NL-1 downto 0);
    variable pdata    : byte_a_t;
    variable pop      : std_logic_vector(NL-1 downto 0);
    variable all_av, any_av, all_fin, all_av_or_end, any_start : boolean;
    variable k        : integer range 0 to NL;
    variable found    : boolean;
    variable cnt_v    : cnt_t;
    variable clear    : boolean;
  begin
    if rising_edge(clk) then
      ov <= '0'; os <= '0'; oe <= '0'; ed <= '0'; el <= '0';
      if rst = '1' then
        wp <= (others => 0); rp <= (others => 0); cnt <= (others => 0);
        prev <= (others => (others => '0'));
        locked <= (others => '0'); ended <= (others => '0'); seen <= (others => '0');
        mst <= M_IDLE; tmo <= 0;
      else
        nl_v := to_integer(unsigned(cfg_nlanes));
        if nl_v < 1 then nl_v := 1; elsif nl_v > NL then nl_v := NL; end if;
        for i in 0 to NL-1 loop
          if i < nl_v then act(i) := '1'; else act(i) := '0'; end if;
        end loop;

        ------------------------------------------------ per-lane alignment
        push := (others => '0');
        for i in 0 to NL-1 loop
          b := rx_byte(8*i+7 downto 8*i);
          pdata(i) := (others => '0');
          if act(i) = '1' and rx_active(i) = '1' then
            seen(i) <= '1';
            if rx_valid(i) = '1' then
              if cfg_hw_sync = '1' then
                locked(i) <= '1';
                pdata(i) := b; push(i) := '1';
              else
                w := b & prev(i);
                prev(i) <= b;
                if locked(i) = '1' then
                  pdata(i) := w(offs(i)+7 downto offs(i)); push(i) := '1';
                else
                  found := false;
                  for o in 0 to 7 loop
                    if not found and w(o+7 downto o) = SYNC_BYTE then
                      found := true; offs(i) <= o; locked(i) <= '1';
                    end if;
                  end loop;
                end if;
              end if;
            end if;
          elsif act(i) = '1' and seen(i) = '1' then
            ended(i) <= '1';                 -- RxActiveHS fell: lane EoT
            prev(i) <= (others => '0');
          else
            prev(i) <= (others => '0');
          end if;
        end loop;

        ------------------------------------------------ merge
        cnt_v := cnt;
        pop := (others => '0');
        all_av := true; any_av := false; all_fin := true; all_av_or_end := true;
        any_start := false;
        for i in 0 to NL-1 loop
          if act(i) = '1' then
            if cnt_v(i) = 0 then all_av := false; else any_av := true; end if;
            if not (ended(i) = '1' and cnt_v(i) = 0) then all_fin := false; end if;
            if not (cnt_v(i) > 0 or ended(i) = '1') then all_av_or_end := false; end if;
            if seen(i) = '1' then any_start := true; end if;
          end if;
        end loop;
        clear := false;

        case mst is
          when M_IDLE =>
            if all_av then
              pop := act;
              os <= '1';
              mst <= M_RUN; tmo <= 0;
            elsif any_start and all_fin then
              clear := true; tmo <= 0;        -- empty burst (nothing aligned)
            elsif any_av then
              -- some lanes already deliver data, others not yet: deskew window
              -- (counted from the first data byte, not from RxActiveHS, so a
              -- long HS-zero leader cannot trigger a false timeout)
              if tmo = DESKEW_TIMEOUT then
                ed <= '1'; mst <= M_DRAIN; tmo <= 0;
              else
                tmo <= tmo + 1;
              end if;
            else
              tmo <= 0;
            end if;
          when M_RUN =>
            if any_av and all_av_or_end then
              for i in 0 to NL-1 loop
                if act(i) = '1' and cnt_v(i) > 0 then pop(i) := '1'; end if;
              end loop;
            elsif all_fin then
              oe <= '1'; ov <= '1'; oc <= (others => '0');
              clear := true; mst <= M_IDLE;
            end if;
          when M_DRAIN =>
            for i in 0 to NL-1 loop
              if cnt_v(i) > 0 then pop(i) := '1'; end if;
            end loop;
            if all_fin then clear := true; mst <= M_IDLE; end if;
        end case;

        -- beat assembly (lane order, contiguous)
        if pop /= (pop'range => '0') and mst /= M_DRAIN then
          k := 0;
          od <= (others => '0');
          for i in 0 to NL-1 loop
            if pop(i) = '1' then
              od(8*k+7 downto 8*k) <= fifo(i)(rp(i));
              k := k + 1;
            end if;
          end loop;
          oc <= to_unsigned(k, 3);
          ov <= '1';
        end if;

        -- FIFO pointer / count update
        for i in 0 to NL-1 loop
          if push(i) = '1' then
            if cnt_v(i) = FD and pop(i) = '0' then
              el <= '1';                     -- deskew FIFO overflow: byte lost
              push(i) := '0';
            else
              fifo(i)(wp(i)) <= pdata(i);
              wp(i) <= (wp(i) + 1) mod FD;
            end if;
          end if;
          if pop(i) = '1' then rp(i) <= (rp(i) + 1) mod FD; end if;
          if push(i) = '1' and pop(i) = '0' then cnt_v(i) := cnt_v(i) + 1;
          elsif push(i) = '0' and pop(i) = '1' then cnt_v(i) := cnt_v(i) - 1; end if;
        end loop;
        cnt <= cnt_v;

        if clear then
          for i in 0 to NL-1 loop
            if rx_active(i) = '0' then
              ended(i) <= '0'; seen(i) <= '0'; locked(i) <= '0';
            end if;
          end loop;
        end if;
      end if;
    end if;
  end process;

  out_valid  <= ov;
  out_data   <= od;
  out_cnt    <= std_logic_vector(oc);
  out_sot    <= os;
  out_eot    <= oe;
  err_deskew <= ed;
  err_lane   <= el;
end architecture;
