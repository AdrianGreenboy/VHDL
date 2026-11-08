-- word_fifo.vhd - rf_word_fifo: 32-bit FWFT sample FIFO of the RF core.
--
-- AUDIT 2026-11:
--  * Entity renamed word_fifo -> rf_word_fifo (core prefix, avoids library
--    collisions with other cores' FIFOs; the file keeps its historical name).
--  * Storage now follows the ADC adc_fifo mold: 1 synchronous write port +
--    1 synchronous read port with enable (SRAM-macro / BRAM mappable; the old
--    512x32 array was read asynchronously, which an ASIC SRAM cannot do),
--    followed by a 2-register FWFT output stage (rd_word, head). rd_data is
--    the head register: valid whenever empty='0', so an MMIO bank with
--    combinational rdata still exposes it without an extra cycle.
--    Capacity = 2**LOG2_DEPTH + 2 words. A word written into an empty FIFO
--    becomes visible on rd_data 3 cycles later (was 1).
--  * Overflow is no longer silent: a write while full is dropped and sets the
--    sticky 'ovf' output, cleared by 'ovf_clr' (W1C in rf_regs) or reset.
-- Reset: asynchronous active low, like every RF block (see AUDIT_FIXES.md).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_word_fifo is
  generic (
    LOG2_DEPTH : natural := 9  -- 512 words of RAM
  );
  port (
    clk       : in  std_logic;
    aresetn   : in  std_logic;
    wr_en     : in  std_logic;
    wr_data   : in  std_logic_vector(31 downto 0);
    full      : out std_logic;
    rd_en     : in  std_logic;                       -- pop the head (ignored if empty)
    rd_data   : out std_logic_vector(31 downto 0);
    empty     : out std_logic;
    level     : out unsigned(LOG2_DEPTH downto 0);   -- saturates at 2**(LOG2_DEPTH+1)-1
    ovf       : out std_logic;                       -- sticky: a write was dropped
    ovf_clr   : in  std_logic := '0'
  );
end entity rf_word_fifo;

architecture rtl of rf_word_fifo is
  constant C_DEPTH : natural := 2**LOG2_DEPTH;
  type ram_t is array (0 to C_DEPTH - 1) of std_logic_vector(31 downto 0);
  signal buf : ram_t;
  attribute ram_style : string;
  attribute ram_style of buf : signal is "block";
  signal wr_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rd_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt_ram : unsigned(LOG2_DEPTH downto 0) := (others => '0');
  signal rd_word : std_logic_vector(31 downto 0) := (others => '0');
  signal head    : std_logic_vector(31 downto 0) := (others => '0');
  signal rv, hv  : std_logic := '0';
  signal full_i, pop, adv_h, adv_r, wr_ok : std_logic;
  signal ovf_i   : std_logic := '0';
begin
  full_i <= '1' when cnt_ram = to_unsigned(C_DEPTH, cnt_ram'length) else '0';
  pop    <= rd_en and hv;
  adv_h  <= rv and ((not hv) or pop);
  adv_r  <= '1' when (cnt_ram /= 0) and ((rv = '0') or (adv_h = '1')) else '0';
  wr_ok  <= wr_en and (not full_i);

  proc_fifo : process (clk, aresetn)
  begin
    if aresetn = '0' then
      wr_ptr <= (others => '0'); rd_ptr <= (others => '0');
      cnt_ram <= (others => '0'); rv <= '0'; hv <= '0'; ovf_i <= '0';
    elsif rising_edge(clk) then
      if wr_ok = '1' then
        buf(to_integer(wr_ptr)) <= wr_data;      -- synchronous write port
        wr_ptr <= wr_ptr + 1;
      end if;
      if adv_r = '1' then
        rd_word <= buf(to_integer(rd_ptr));      -- synchronous read port
        rd_ptr  <= rd_ptr + 1;
      end if;
      if (wr_ok = '1') and (adv_r = '0') then
        cnt_ram <= cnt_ram + 1;
      elsif (wr_ok = '0') and (adv_r = '1') then
        cnt_ram <= cnt_ram - 1;
      end if;
      rv <= adv_r or (rv and (not adv_h));
      if adv_h = '1' then
        head <= rd_word;
      end if;
      hv <= adv_h or (hv and (not pop));
      if wr_en = '1' and full_i = '1' then
        ovf_i <= '1';
      elsif ovf_clr = '1' then
        ovf_i <= '0';
      end if;
    end if;
  end process proc_fifo;

  rd_data <= head;
  empty   <= not hv;
  full    <= full_i;
  ovf     <= ovf_i;

  proc_level : process (all)
    variable v : unsigned(LOG2_DEPTH + 1 downto 0);
  begin
    v := resize(cnt_ram, v'length);
    if rv = '1' then v := v + 1; end if;
    if hv = '1' then v := v + 1; end if;
    if v > 2**(LOG2_DEPTH + 1) - 1 then
      level <= (others => '1');
    else
      level <= v(LOG2_DEPTH downto 0);
    end if;
  end process proc_level;
end architecture rtl;
