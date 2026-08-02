-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- Shared CSI-2 primitives package.
-- Single source of the ECC parity masks and CRC step so the encoder
-- (frame_gen) and decoder (csi2_ecc) cannot diverge on convention.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package csi2_pkg is
  -- RAW12 data type and short-packet data types
  constant DT_RAW12 : std_logic_vector(5 downto 0) := "101100"; -- 0x2C
  constant DT_FS    : std_logic_vector(5 downto 0) := "000000";
  constant DT_FE    : std_logic_vector(5 downto 0) := "000001";
  constant DT_LS    : std_logic_vector(5 downto 0) := "000010";
  constant DT_LE    : std_logic_vector(5 downto 0) := "000011";

  -- ECC: encode 6-bit ECC over 24-bit {WC_H,WC_L,DataID} field
  function csi2_ecc_enc(d : std_logic_vector(23 downto 0)) return std_logic_vector;

  -- CRC-16 CSI-2: one-byte incremental update (reflected 0x8408)
  function csi2_crc_step(c : unsigned(15 downto 0); b : std_logic_vector(7 downto 0))
    return unsigned;
end package;

package body csi2_pkg is
  type integer_vector is array(natural range <>) of integer;
  type mask_arr is array(0 to 5) of std_logic_vector(23 downto 0);

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

  function csi2_ecc_enc(d : std_logic_vector(23 downto 0)) return std_logic_vector is
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

  function csi2_crc_step(c : unsigned(15 downto 0); b : std_logic_vector(7 downto 0))
    return unsigned is
    variable cc : unsigned(15 downto 0);
  begin
    cc := c xor resize(unsigned(b), 16);
    for i in 0 to 7 loop
      if cc(0) = '1' then
        cc := ('0' & cc(15 downto 1)) xor x"8408";
      else
        cc := '0' & cc(15 downto 1);
      end if;
    end loop;
    return cc;
  end function;
end package body;
