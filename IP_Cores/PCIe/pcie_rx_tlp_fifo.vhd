-- ============================================================================
-- pcie_rx_tlp_fifo.vhd -- PCIE IP (audit 2026-11)
-- Store-and-forward receive buffer between the DLL RX and the Transaction
-- Layer. It gives the TL real backpressure (rd_ready) and lets the DLL RX
-- hand bytes over BEFORE the LCRC/sequence check:
--   * the DLL writes the TLP tentatively (wr_en/wr_data/wr_last),
--   * on a good, in-order TLP it pulses 'commit'  -> bytes become visible,
--   * on a bad / duplicate / out-of-order TLP it pulses 'rollback' -> the
--     tentative bytes vanish, nothing ever reaches the TL.
-- A write while the buffer is full sets 'wr_ovf' (cleared by commit/rollback)
-- and the DLL must roll the TLP back (it is NAKed and replayed later).
--
-- Entry = data byte + 'last' flag. The read side is FWFT with a registered
-- (synchronous) memory read + prefetch (SRAM/BRAM friendly). rd_start marks
-- the first byte of each TLP.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_rx_tlp_fifo is
  generic (
    LOG2_DEPTH : integer := 9
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- write side (DLL RX)
    wr_en    : in  std_logic;
    wr_data  : in  std_logic_vector(7 downto 0);
    wr_last  : in  std_logic;
    commit   : in  std_logic;   -- takes effect after a same-cycle write
    rollback : in  std_logic;
    wr_ovf   : out std_logic;   -- a tentative write was dropped (buffer full)
    wr_space : out unsigned(LOG2_DEPTH downto 0);
    -- read side (TL)
    rd_valid : out std_logic;
    rd_data  : out std_logic_vector(7 downto 0);
    rd_start : out std_logic;
    rd_last  : out std_logic;
    rd_ready : in  std_logic
  );
end entity;

architecture rtl of pcie_rx_tlp_fifo is
  constant DEPTH : integer := 2**LOG2_DEPTH;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(8 downto 0);
  signal mem : mem_t;
  attribute ram_style : string;
  attribute ram_style of mem : signal is "block";

  signal wptr_t, wptr_c, rptr : unsigned(LOG2_DEPTH downto 0) := (others=>'0');
  signal dout   : std_logic_vector(8 downto 0) := (others=>'0');
  signal dout_v : std_logic := '0';
  signal first  : std_logic := '1';   -- next byte handed out starts a TLP
  signal ovf_r  : std_logic := '0';
  signal used_t : unsigned(LOG2_DEPTH downto 0);
  signal full_i, do_wr, do_rd, fetch : std_logic;
begin
  used_t  <= wptr_t - rptr;
  full_i  <= '1' when used_t = to_unsigned(DEPTH, LOG2_DEPTH+1) else '0';
  do_wr   <= wr_en and not full_i and not rollback;
  do_rd   <= rd_ready and dout_v;
  fetch   <= '1' when wptr_c /= rptr and (dout_v = '0' or do_rd = '1') else '0';

  wr_ovf   <= ovf_r;
  wr_space <= to_unsigned(DEPTH, LOG2_DEPTH+1) - used_t;
  rd_valid <= dout_v;
  rd_data  <= dout(7 downto 0);
  rd_last  <= dout(8);
  rd_start <= dout_v and first;

  mem_p : process(clk)
  begin
    if rising_edge(clk) then
      if do_wr = '1' then
        mem(to_integer(wptr_t(LOG2_DEPTH-1 downto 0))) <= wr_last & wr_data;
      end if;
      if fetch = '1' then
        dout <= mem(to_integer(rptr(LOG2_DEPTH-1 downto 0)));
      end if;
    end if;
  end process;

  ctl_p : process(clk)
    variable wt : unsigned(LOG2_DEPTH downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wptr_t <= (others=>'0'); wptr_c <= (others=>'0'); rptr <= (others=>'0');
        dout_v <= '0'; first <= '1'; ovf_r <= '0';
      else
        wt := wptr_t;
        if do_wr = '1' then wt := wt + 1; end if;
        if wr_en = '1' and full_i = '1' then ovf_r <= '1'; end if;
        if rollback = '1' then
          wptr_t <= wptr_c; ovf_r <= '0';
        elsif commit = '1' then
          wptr_t <= wt; wptr_c <= wt; ovf_r <= '0';
        else
          wptr_t <= wt;
        end if;
        if fetch = '1' then
          rptr <= rptr + 1; dout_v <= '1';
        elsif do_rd = '1' then
          dout_v <= '0';
        end if;
        if do_rd = '1' then first <= dout(8); end if;   -- after 'last' a new TLP starts
      end if;
    end if;
  end process;
end architecture;
