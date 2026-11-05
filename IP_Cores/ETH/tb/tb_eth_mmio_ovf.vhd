-- tb_eth_mmio_ovf.vhd - eth_mmio audit-2026-11 regression (LOOP_INT, dmem BFM)
-- ---------------------------------------------------------------------------
-- Self-checking. Covers:
--   A RX FIFO overflow drops WHOLE frames: three 1000-byte frames loop back
--     without the firmware reading RXD (FIFO = 2048 B). Frames 1 and 2 must be
--     readable intact with their EOF; frame 3 must be absent entirely (v1 kept
--     its first 48 bytes without EOF, merging them into the next frame) and
--     STAT.RXF_OVF (b22) must be set.
--   B STAT stickies are W1C per bit: writing b22 clears RXF_OVF only, RX_OK
--     stays set (v1: any write cleared all).
--   C LEVEL register reports the full 12-bit rxf_level and STAT b14:8
--     saturates at 127 instead of truncating (v1: 2000 & 0x7F = 80).
--   D a 1600-byte frame (looped back) raises RX_OVERSIZE (b23) and is not
--     delivered.
--   E TX_FLUSH also clears the store-and-forward frame counter: after a flush
--     a partially written frame must NOT start transmitting (v1 kept a stale
--     frames_pending and transmitted the partial frame -> TX underrun).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_eth_mmio_ovf is
end entity;

architecture sim of tb_eth_mmio_ovf is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal sel, we : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0) := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;

  constant A_CTRL  : std_logic_vector(7 downto 0) := x"00";
  constant A_CMD   : std_logic_vector(7 downto 0) := x"0C";
  constant A_STAT  : std_logic_vector(7 downto 0) := x"10";
  constant A_TXD   : std_logic_vector(7 downto 0) := x"14";
  constant A_RXD   : std_logic_vector(7 downto 0) := x"18";
  constant A_LEVEL : std_logic_vector(7 downto 0) := x"20";

  function fb(f, i : natural) return std_logic_vector is
  begin
    if i < 6 then return x"FF"; end if;                 -- broadcast DA
    return std_logic_vector(to_unsigned((f * 17 + i * 3 + 1) mod 256, 8));
  end function;
begin
  clk <= not clk after TCLK / 2;

  dut : entity work.eth_mmio
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              mii_txd => open, mii_tx_en => open, mii_rxd => "0000", mii_rx_dv => '0');

  process
    variable rd : std_logic_vector(31 downto 0);
    variable got : integer;
    procedure wr32(a : std_logic_vector(7 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk);
      sel <= '0'; we <= '0';
    end procedure;
    procedure rd32(a : std_logic_vector(7 downto 0); res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns;
      res := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;
    procedure send(f, ln : natural) is
    begin
      for i in 0 to ln - 1 loop
        if i = ln - 1 then
          wr32(A_TXD, (31 downto 9 => '0') & '1' & fb(f, i));
        else
          wr32(A_TXD, (31 downto 9 => '0') & '0' & fb(f, i));
        end if;
      end loop;
    end procedure;
    procedure wait_tx_idle is
      variable r : std_logic_vector(31 downto 0);
    begin
      loop
        rd32(A_STAT, r);
        exit when r(0) = '0' and r(4) = '1';          -- engine idle, TX FIFO empty
      end loop;
      wait for 25 us;                                 -- loopback RX drain (1 B/clk)
    end procedure;
    procedure read_frame(f, ln : natural) is
      variable r : std_logic_vector(31 downto 0);
    begin
      for i in 0 to ln - 1 loop
        rd32(A_RXD, r);
        assert r(31) = '1'
          report "OVF: RX FIFO empty inside frame " & integer'image(f) severity failure;
        assert r(7 downto 0) = fb(f, i)
          report "OVF: frame " & integer'image(f) & " byte " & integer'image(i) & " corrupted"
          severity failure;
        if i = ln - 1 then
          assert r(8) = '1' report "OVF: missing EOF on frame " & integer'image(f) severity failure;
        else
          assert r(8) = '0' report "OVF: early EOF on frame " & integer'image(f) severity failure;
        end if;
      end loop;
    end procedure;
  begin
    rst <= '1'; wait for 20 * TCLK; wait until rising_edge(clk); rst <= '0';
    wait for 4 * TCLK;
    wr32(A_CTRL, x"00000003");                        -- EN + LOOP_INT

    -- A: three 1000-byte frames, RXD not read in between
    send(1, 1000); wait_tx_idle;
    send(2, 1000); wait_tx_idle;
    send(3, 1000); wait_tx_idle;
    read_frame(1, 1000);
    read_frame(2, 1000);
    rd32(A_RXD, rd);
    assert rd(31) = '0' report "OVF: remnant of the dropped frame in RX FIFO" severity failure;
    rd32(A_STAT, rd);
    assert rd(22) = '1' report "OVF: RXF_OVF sticky not set" severity failure;
    assert rd(16) = '1' report "OVF: RX_OK sticky not set" severity failure;

    -- B: W1C per bit
    wr32(A_STAT, x"00400000");                        -- clear RXF_OVF only
    rd32(A_STAT, rd);
    assert rd(22) = '0' report "W1C: RXF_OVF not cleared" severity failure;
    assert rd(16) = '1' report "W1C: RX_OK cleared by a write to another bit" severity failure;
    wr32(A_STAT, x"00010000");
    rd32(A_STAT, rd);
    assert rd(16) = '0' report "W1C: RX_OK not cleared" severity failure;

    -- the FIFO accepts a new frame after the drop
    send(4, 100); wait_tx_idle;
    read_frame(4, 100);

    -- D: oversize frame (1600 data bytes + FCS) looped back -> dropped
    send(5, 1600); wait_tx_idle;
    rd32(A_STAT, rd);
    assert rd(23) = '1' report "OVS: RX_OVERSIZE sticky not set" severity failure;
    rd32(A_RXD, rd);
    assert rd(31) = '0' report "OVS: oversize frame was delivered" severity failure;

    -- C: level of two committed frames (2000) via LEVEL and saturated STAT
    send(8, 1000); wait_tx_idle;
    send(9, 1000); wait_tx_idle;
    rd32(A_LEVEL, rd);
    assert unsigned(rd(11 downto 0)) = 2000
      report "LEVEL: rxf_level=" & integer'image(to_integer(unsigned(rd(11 downto 0)))) &
             " expected 2000" severity failure;
    rd32(A_STAT, rd);
    assert rd(14 downto 8) = "1111111"
      report "STAT: rxf_level view not saturated (truncated?)" severity failure;

    -- E: TX_FLUSH clears the pending-frame counter
    wr32(A_CTRL, x"00000000");                        -- EN=0: FIFOs flushed
    wr32(A_CTRL, x"00000003");
    send(6, 80);                                      -- complete frame...
    wr32(A_CMD, x"00000001");                         -- ...flushed before it leaves?
    -- (the engine may already have started: wait for idle, then check that a
    -- partial frame written now does not start)
    wait_tx_idle;
    wr32(A_STAT, x"03FF0000");                        -- clear every sticky
    wr32(A_CMD, x"00000001");
    for i in 0 to 30 loop
      wr32(A_TXD, (31 downto 9 => '0') & '0' & fb(7, i));   -- no EOF
    end loop;
    wait for 10 us;
    rd32(A_STAT, rd);
    assert rd(0) = '0' and rd(20) = '0'
      report "FLUSH: a partial frame started after TX_FLUSH (stale frame counter)"
      severity failure;

    report "TB_ETH_MMIO_OVF PASS (whole-frame RX drop, W1C, LEVEL, oversize, flush)";
    finish;
  end process;

  process
  begin
    wait for 10 ms;
    assert false report "TB_ETH_MMIO_OVF: timeout" severity failure;
    wait;
  end process;
end architecture;
