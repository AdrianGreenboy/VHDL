-- eth_cdc_sync.vhd - clock-domain-crossing primitives (ETH/PTP/TSN family)
-- ---------------------------------------------------------------------------
-- Three small, reusable CDC cells. Each is the ONLY place in the family where
-- a signal crosses between unrelated clocks, so synthesis/STA constraints can
-- be attached to them by name (see AUDIT_FIXES.md, "CDC constraints"):
--
--   eth_sync_bit   : 2-FF level synchronizer for a single quasi-static bit.
--   eth_pulse_sync : toggle-based pulse synchronizer. A 1-cycle pulse in the
--                    source domain becomes a 1-cycle pulse in the destination
--                    domain. Requirement: source pulses spaced by at least
--                    3 destination clock periods (guaranteed for MII events,
--                    which are >= 1 MII clock = 40 ns apart, vs 10 ns core).
--   eth_rst_sync   : reset synchronizer. Asynchronous ASSERT, synchronous
--                    DE-ASSERT. Its output is consumed as a plain SYNCHRONOUS
--                    active-high reset by the logic of the destination
--                    domain. Because the output is asserted asynchronously, it
--                    is already '1' while the destination clock is absent
--                    (e.g. PHY clock not yet running), and it stays '1' for
--                    2 destination edges after the source reset is released,
--                    so the destination logic always sees >= 2 reset edges.
--                    This is the single, intentional use of an asynchronous
--                    clear in the family (reset-synchronizer cell only).
--
-- Reset convention for everything else: synchronous, active-high, per domain.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity eth_sync_bit is
  generic (
    G_INIT : std_logic := '0'
  );
  port (
    clk  : in  std_logic;               -- destination clock
    rst  : in  std_logic;               -- destination sync reset (active high)
    d    : in  std_logic;               -- asynchronous input
    q    : out std_logic
  );
end entity eth_sync_bit;

architecture rtl of eth_sync_bit is
  signal s1, s2 : std_logic := G_INIT;
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1 : signal is "TRUE";
  attribute ASYNC_REG of s2 : signal is "TRUE";
begin
  q <= s2;
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        s1 <= G_INIT;
        s2 <= G_INIT;
      else
        s1 <= d;
        s2 <= s1;
      end if;
    end if;
  end process;
end architecture rtl;

-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity eth_pulse_sync is
  port (
    src_clk   : in  std_logic;
    src_rst   : in  std_logic;          -- source-domain sync reset
    src_pulse : in  std_logic;          -- 1-cycle pulse (source domain)
    dst_clk   : in  std_logic;
    dst_rst   : in  std_logic;          -- destination-domain sync reset
    dst_pulse : out std_logic           -- 1-cycle pulse (destination domain)
  );
end entity eth_pulse_sync;

architecture rtl of eth_pulse_sync is
  signal tgl        : std_logic := '0';
  signal s1, s2, s3 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1 : signal is "TRUE";
  attribute ASYNC_REG of s2 : signal is "TRUE";
begin
  p_src : process(src_clk)
  begin
    if rising_edge(src_clk) then
      if src_rst = '1' then
        tgl <= '0';
      elsif src_pulse = '1' then
        tgl <= not tgl;
      end if;
    end if;
  end process;

  p_dst : process(dst_clk)
  begin
    if rising_edge(dst_clk) then
      if dst_rst = '1' then
        s1 <= '0'; s2 <= '0'; s3 <= '0';
      else
        s1 <= tgl;
        s2 <= s1;
        s3 <= s2;
      end if;
    end if;
  end process;

  dst_pulse <= s2 xor s3;
end architecture rtl;

-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity eth_rst_sync is
  port (
    clk      : in  std_logic;           -- destination clock
    rst_in   : in  std_logic;           -- reset from another domain (active high)
    rst_out  : out std_logic            -- synchronous-deassert reset (active high)
  );
end entity eth_rst_sync;

architecture rtl of eth_rst_sync is
  signal r1, r2 : std_logic := '1';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of r1 : signal is "TRUE";
  attribute ASYNC_REG of r2 : signal is "TRUE";
begin
  rst_out <= r2;
  -- Reset-synchronizer cell: the only asynchronous clear in the family.
  process(clk, rst_in)
  begin
    if rst_in = '1' then
      r1 <= '1';
      r2 <= '1';
    elsif rising_edge(clk) then
      r1 <= '0';
      r2 <= r1;
    end if;
  end process;
end architecture rtl;
