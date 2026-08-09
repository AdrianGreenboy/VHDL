-- ecc_codec_mmio.vhd - Acelerador de codec ECC como bloque MMIO (Layer 5).
-- Core 20 HERCOSSNUX. Expone el codec SECDED (39,32) combinacional (ecc_codec,
-- ya validado en Layer 1) como registros para que el firmware RV32 barra una
-- region por tiles: reconstruye 39b desde LO/HI, decodifica, corrige, reencoda.
--
-- Bus dmem simple (rdata COMBINACIONAL, ready='1'). Offsets (base del bloque):
--   0x04 ENC_IN     WO  dato 32b a codificar (latcheado)
--   0x08 ENC_OUT_LO RO  bits 31:0 de la palabra ECC de enc_in
--   0x0C ENC_OUT_HI RO  bits 38:32
--   0x10 DEC_IN_LO  WO  bits 31:0 de la palabra ECC a decodificar (latcheado)
--   0x14 DEC_IN_HI  WO  bits 38:32 (latcheado; el decode es combinacional)
--   0x18 DEC_DATA   RO  dato decodificado/corregido (32b)
--   0x1C DEC_STATUS RO  bit6:0 syndrome, bit8 ded, bit9 corrected
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ecc_pkg.all;

entity ecc_codec_mmio is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    sel   : in  std_logic;
    wr    : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);   -- offset dentro del bloque codec
    wdata : in  std_logic_vector(31 downto 0);
    rdata : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of ecc_codec_mmio is
  constant OFF_ENC_IN     : std_logic_vector(7 downto 0) := x"04";
  constant OFF_ENC_OUT_LO : std_logic_vector(7 downto 0) := x"08";
  constant OFF_ENC_OUT_HI : std_logic_vector(7 downto 0) := x"0C";
  constant OFF_DEC_IN_LO  : std_logic_vector(7 downto 0) := x"10";
  constant OFF_DEC_IN_HI  : std_logic_vector(7 downto 0) := x"14";
  constant OFF_DEC_DATA   : std_logic_vector(7 downto 0) := x"18";
  constant OFF_DEC_STATUS : std_logic_vector(7 downto 0) := x"1C";

  signal enc_in  : data_t := (others => '0');
  signal enc_out : ecc_t;
  signal dec_lo  : std_logic_vector(31 downto 0) := (others => '0');
  signal dec_hi  : std_logic_vector(31 downto 0) := (others => '0');
  signal dec_code : ecc_t;
  signal dec_data : data_t;
  signal dec_syn  : std_logic_vector(6 downto 0);
  signal dec_cor  : std_logic;
  signal dec_ded  : std_logic;
begin

  dec_code <= dec_hi(6 downto 0) & dec_lo;   -- reconstruye 39b: HI(6:0) & LO(31:0)

  codec : entity work.ecc_codec
    port map (
      enc_data => enc_in,   enc_code => enc_out,
      dec_code => dec_code, dec_data => dec_data,
      dec_syn  => dec_syn,  dec_cor  => dec_cor, dec_ded => dec_ded
    );

  -- latches de entrada
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        enc_in <= (others => '0');
        dec_lo <= (others => '0');
        dec_hi <= (others => '0');
      elsif sel = '1' and wr = '1' then
        case addr is
          when OFF_ENC_IN    => enc_in <= wdata;
          when OFF_DEC_IN_LO => dec_lo <= wdata;
          when OFF_DEC_IN_HI => dec_hi <= wdata;
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- lectura combinacional
  process(addr, enc_out, dec_data, dec_syn, dec_cor, dec_ded)
    variable v : std_logic_vector(31 downto 0);
  begin
    v := (others => '0');
    case addr is
      when OFF_ENC_OUT_LO => v := enc_out(31 downto 0);
      when OFF_ENC_OUT_HI => v := (others => '0'); v(6 downto 0) := enc_out(38 downto 32);
      when OFF_DEC_DATA   => v := dec_data;
      when OFF_DEC_STATUS =>
        v := (others => '0');
        v(6 downto 0) := dec_syn;
        v(8) := dec_ded;
        v(9) := dec_cor;
      when others => v := (others => '0');
    end case;
    rdata <= v;
  end process;

end architecture;
