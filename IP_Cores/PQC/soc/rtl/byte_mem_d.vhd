-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- byte_mem_d: byte-addressed scratch for the ML-DSA sequencer.
-- VHDL-2008. ASCII-only. MIT license.
--
-- 16 KB, 14-bit addresses. The map in dsa_sign.vhd tops out at 11500 for the
-- signature, so this leaves room without another widening.
--
-- PHYSICAL ORGANISATION (audit 2026-11): single-address 1RW SRAM, organised
-- as 16384/G_LANES words of G_LANES bytes with a per-byte write mask (one 1RW
-- macro with byte mask, or one FPGA BRAM with byte enables). A normal access
-- touches one lane; the zeroizer writes a whole word per cycle. On a write
-- cycle no read is performed and dout HOLDS its previous value. Storage is
-- std_logic_vector without an initial value (ASIC SRAM powers up random);
-- the previous integer typing and its (others => 0) initialiser were a
-- workaround for a GHDL segfault that GHDL 4.1 no longer exhibits.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

package byte_mem_d_pkg is
  -- storage type (unconstrained so that testbenches can inspect the array
  -- through VHDL-2008 external names)
  type t_bmd_arr is array (natural range <>) of std_logic_vector;
end package byte_mem_d_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.byte_mem_d_pkg.all;

entity byte_mem_d is
  generic (
    G_LANES : integer := 8);
  port (
    clk  : in  std_logic;
    rst_n : in std_logic := '1';
    addr : in  std_logic_vector(13 downto 0);
    din  : in  std_logic_vector(7 downto 0);
    we   : in  std_logic;
    dout : out std_logic_vector(7 downto 0);
    -- zeroization: a one-cycle z_start pulse wipes words z_lo .. z_hi
    -- (inclusive, word = G_LANES bytes); accesses are ignored while z_busy.
    z_start : in  std_logic := '0';
    z_lo    : in  integer range 0 to 16384 / G_LANES - 1 := 0;
    z_hi    : in  integer range 0 to 16384 / G_LANES - 1 := 0;
    z_busy  : out std_logic);
end entity byte_mem_d;

architecture rtl of byte_mem_d is
  constant C_WORDS : integer := 16384 / G_LANES;
  subtype t_word is std_logic_vector(8 * G_LANES - 1 downto 0);
  signal mem    : t_bmd_arr(0 to C_WORDS - 1)(8 * G_LANES - 1 downto 0);
  signal q      : t_word;
  signal lane_q : integer range 0 to G_LANES - 1 := 0;
  signal z_run  : std_logic := '0';
  signal z_ptr  : integer range 0 to C_WORDS - 1 := 0;
  signal z_end  : integer range 0 to C_WORDS - 1 := 0;
begin
  process (clk)
    variable a : integer range 0 to 16383;
  begin
    if rising_edge(clk) then
      a := to_integer(unsigned(addr));
      if z_run = '1' then
        mem(z_ptr) <= (others => '0');
      elsif we = '1' then
        mem(a / G_LANES)(8 * (a mod G_LANES) + 7 downto
                         8 * (a mod G_LANES)) <= din;
      else
        q      <= mem(a / G_LANES);
        lane_q <= a mod G_LANES;
      end if;
    end if;
  end process;

  dout <= q(8 * lane_q + 7 downto 8 * lane_q);

  zero_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        z_run <= '0';
        z_ptr <= 0;
        z_end <= 0;
      elsif z_run = '1' then
        if z_ptr = z_end then
          z_run <= '0';
        else
          z_ptr <= z_ptr + 1;
        end if;
      elsif z_start = '1' then
        z_run <= '1';
        z_ptr <= z_lo;
        z_end <= z_hi;
      end if;
    end if;
  end process;
  z_busy <= z_run;
end architecture rtl;
