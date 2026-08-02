-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- Packet Header ECC: Hamming 24->6 decoder.
--
-- Input : 24 data bits {DataID, WC_L, WC_H} (LSB-first: d0..d7=DataID,
--         d8..d15=WC_L, d16..d23=WC_H) plus the received 6-bit ECC.
-- Output: corrected 24-bit field, plus status:
--            err_none : header clean or single-bit corrected
--            err_2bit : uncorrectable (2-bit error detected)
--
-- The parity equations are the canonical MIPI D-PHY / CSI-2 ECC masks and
-- MUST match the Python oracle's _ECC_MASKS byte-for-byte.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_ecc is
  port (
    data_in   : in  std_logic_vector(23 downto 0);  -- {WC_H, WC_L, DataID}
    ecc_in    : in  std_logic_vector(5 downto 0);
    data_out  : out std_logic_vector(23 downto 0);   -- corrected
    err_1bit  : out std_logic;                        -- a single-bit error was corrected
    err_2bit  : out std_logic                         -- uncorrectable
  );
end entity;

architecture rtl of csi2_ecc is
  type integer_vector is array(natural range <>) of integer;
  -- Parity masks: for each parity bit p, the set of data-bit indices XORed.
  type mask_arr is array(0 to 5) of std_logic_vector(23 downto 0);

  -- Build masks from the oracle index lists. A '1' at position i means data
  -- bit i participates in that parity bit.
  function build_mask(indices : integer_vector) return std_logic_vector is
    variable m : std_logic_vector(23 downto 0) := (others => '0');
  begin
    for k in indices'range loop
      m(indices(k)) := '1';
    end loop;
    return m;
  end function;

  constant MASKS : mask_arr := (
    0 => build_mask((0,1,2,4,5,7,10,11,13,16,20,21,22,23)),
    1 => build_mask((0,1,3,4,6,8,10,12,14,17,20,21,22,23)),
    2 => build_mask((0,2,3,5,6,9,11,12,15,18,20,21,22)),
    3 => build_mask((1,2,3,7,8,9,13,14,15,19,20,21,23)),
    4 => build_mask((4,5,6,7,8,9,16,17,18,19,20,22,23)),
    5 => build_mask((10,11,12,13,14,15,16,17,18,19,21,22,23))
  );

  -- compute the 6-bit ECC of a 24-bit field
  function calc_ecc(d : std_logic_vector(23 downto 0)) return std_logic_vector is
    variable e : std_logic_vector(5 downto 0);
    variable p : std_logic;
  begin
    for i in 0 to 5 loop
      p := '0';
      for b in 0 to 23 loop
        if MASKS(i)(b) = '1' then
          p := p xor d(b);
        end if;
      end loop;
      e(i) := p;
    end loop;
    return e;
  end function;

  signal syndrome : std_logic_vector(5 downto 0);
begin

  syndrome <= calc_ecc(data_in) xor ecc_in;

  process(data_in, ecc_in, syndrome)
    variable corrected : std_logic_vector(23 downto 0);
    variable found     : std_logic;
    variable trial     : std_logic_vector(23 downto 0);
  begin
    corrected := data_in;
    found     := '0';
    err_1bit  <= '0';
    err_2bit  <= '0';

    if syndrome = "000000" then
      -- clean header, no error
      corrected := data_in;
    else
      -- try to match the syndrome to a single flipped data bit: flipping data
      -- bit i changes the syndrome to MASKS(*)(i). Search for i whose column
      -- equals the syndrome.
      for i in 0 to 23 loop
        if (MASKS(5)(i) & MASKS(4)(i) & MASKS(3)(i) &
            MASKS(2)(i) & MASKS(1)(i) & MASKS(0)(i)) = syndrome then
          trial := data_in;
          trial(i) := not trial(i);
          corrected := trial;
          found := '1';
          err_1bit <= '1';
        end if;
      end loop;

      -- if the syndrome has a single bit set, the error is in an ECC bit; the
      -- data is intact (single-bit error, correctable, data unchanged).
      if found = '0' then
        if (syndrome = "000001" or syndrome = "000010" or syndrome = "000100" or
            syndrome = "001000" or syndrome = "010000" or syndrome = "100000") then
          corrected := data_in;
          found := '1';
          err_1bit <= '1';
        end if;
      end if;

      -- no single-bit explanation -> 2-bit (or more) error, uncorrectable
      if found = '0' then
        err_2bit <= '1';
      end if;
    end if;

    data_out <= corrected;
  end process;

end architecture;
