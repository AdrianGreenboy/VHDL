-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L2: Packet-layer parser.
-- Consumes a CSI-2 byte stream, decodes each header (ECC-corrected), classifies
-- short vs long packets, validates long-packet payloads with CRC-16, and emits
-- validated payload bytes.
--
-- Short packet data types: 0x00 FS, 0x01 FE, 0x02 LS, 0x03 LE (VC in bits 7:6).
-- Long packet: RAW12 = 0x2C. Header WC gives payload length; 2-byte CRC follows.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_packet_rx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- byte input (from byte-clock D-PHY model)
    byte_in    : in  std_logic_vector(7 downto 0);
    byte_valid : in  std_logic;
    -- validated payload output
    pl_byte    : out std_logic_vector(7 downto 0);
    pl_valid   : out std_logic;      -- payload byte, CRC not yet confirmed
    pl_commit  : out std_logic;      -- pulse: last packet's CRC was GOOD
    pl_drop    : out std_logic;      -- pulse: last packet's CRC was BAD
    -- decoded header side-channel (valid with sop)
    sop        : out std_logic;      -- start of packet (header decoded)
    is_long    : out std_logic;
    vc_out     : out std_logic_vector(1 downto 0);
    dt_out     : out std_logic_vector(5 downto 0);
    hdr_2bit   : out std_logic       -- header uncorrectable error
  );
end entity;

architecture rtl of csi2_packet_rx is
  type state_t is (S_H0, S_H1, S_H2, S_H3, S_DECODE, S_PAYLOAD, S_CRC0, S_CRC1, S_CHECK);
  signal state : state_t := S_H0;

  signal h0, h1, h2, h3 : std_logic_vector(7 downto 0) := (others => '0');

  -- ECC
  signal ecc_data_in  : std_logic_vector(23 downto 0);
  signal ecc_data_out : std_logic_vector(23 downto 0);
  signal ecc_1bit, ecc_2bit : std_logic;

  -- CRC
  signal crc_init  : std_logic;
  signal crc_din   : std_logic_vector(7 downto 0);
  signal crc_valid : std_logic;
  signal crc_val   : std_logic_vector(15 downto 0);

  signal wc_cnt    : unsigned(15 downto 0) := (others => '0');
  signal wc_total  : unsigned(15 downto 0) := (others => '0');
  signal cur_vc    : std_logic_vector(1 downto 0) := "00";
  signal cur_dt    : std_logic_vector(5 downto 0) := (others => '0');
  signal cur_long  : std_logic := '0';
  signal crc_lo    : std_logic_vector(7 downto 0) := (others => '0');
  signal crc_rx    : std_logic_vector(15 downto 0);

  -- registered outputs
  signal pl_byte_i  : std_logic_vector(7 downto 0) := (others => '0');
  signal pl_valid_i : std_logic := '0';
  signal pl_commit_i: std_logic := '0';
  signal pl_drop_i  : std_logic := '0';
  signal sop_i      : std_logic := '0';
  signal hdr2_i     : std_logic := '0';

  function is_short_dt(dt : std_logic_vector(5 downto 0)) return boolean is
  begin
    return dt = "000000" or dt = "000001" or dt = "000010" or dt = "000011";
  end function;
begin

  ecc : entity work.csi2_ecc
    port map (data_in=>ecc_data_in, ecc_in=>h3(5 downto 0),
              data_out=>ecc_data_out, err_1bit=>ecc_1bit, err_2bit=>ecc_2bit);

  crc : entity work.csi2_crc16
    port map (clk=>clk, rst=>rst, init=>crc_init,
              data_in=>crc_din, valid=>crc_valid, crc=>crc_val);

  -- ECC input assembled from the first 3 header bytes: {WC_H,WC_L,DataID}
  ecc_data_in <= h2 & h1 & h0;

  process(clk)
    variable did : std_logic_vector(7 downto 0);
    variable wc  : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then
      -- default single-cycle pulses
      pl_valid_i  <= '0';
      pl_commit_i <= '0';
      pl_drop_i   <= '0';
      sop_i       <= '0';
      crc_init    <= '0';
      crc_valid   <= '0';

      if rst = '1' then
        state <= S_H0;
        hdr2_i <= '0';
      else
        case state is
          when S_H0 =>
            if byte_valid = '1' then h0 <= byte_in; state <= S_H1; end if;
          when S_H1 =>
            if byte_valid = '1' then h1 <= byte_in; state <= S_H2; end if;
          when S_H2 =>
            if byte_valid = '1' then h2 <= byte_in; state <= S_H3; end if;
          when S_H3 =>
            if byte_valid = '1' then h3 <= byte_in; state <= S_DECODE; end if;

          when S_DECODE =>
            -- ECC combinational result is valid now (h0..h3 stable)
            did := ecc_data_out(7 downto 0);
            wc  := unsigned(ecc_data_out(23 downto 8));
            cur_vc <= did(7 downto 6);
            cur_dt <= did(5 downto 0);
            hdr2_i <= ecc_2bit;
            sop_i  <= '1';
            if is_short_dt(did(5 downto 0)) then
              cur_long <= '0';
              state <= S_H0;                     -- short packet done
            else
              cur_long <= '1';
              wc_total <= wc;
              wc_cnt   <= (others => '0');
              crc_init <= '1';                   -- reset CRC for payload
              if wc = 0 then
                state <= S_CRC0;
              else
                state <= S_PAYLOAD;
              end if;
            end if;

          when S_PAYLOAD =>
            if byte_valid = '1' then
              -- emit payload byte, feed CRC
              pl_byte_i  <= byte_in;
              pl_valid_i <= '1';
              crc_din    <= byte_in;
              crc_valid  <= '1';
              if wc_cnt = wc_total - 1 then
                state <= S_CRC0;
              else
                wc_cnt <= wc_cnt + 1;
              end if;
            end if;

          when S_CRC0 =>
            if byte_valid = '1' then
              crc_lo <= byte_in;
              state  <= S_CRC1;
            end if;

          when S_CRC1 =>
            if byte_valid = '1' then
              crc_rx <= byte_in & crc_lo;   -- LSByte first: byte_in is MSB
              state  <= S_CHECK;
            end if;

          when S_CHECK =>
            -- crc_val holds the computed CRC (last payload byte processed one
            -- cycle before CRC0). Compare.
            if crc_val = crc_rx then
              pl_commit_i <= '1';
            else
              pl_drop_i <= '1';
            end if;
            state <= S_H0;
        end case;
      end if;
    end if;
  end process;

  pl_byte   <= pl_byte_i;
  pl_valid  <= pl_valid_i;
  pl_commit <= pl_commit_i;
  pl_drop   <= pl_drop_i;
  sop       <= sop_i;
  is_long   <= cur_long;
  vc_out    <= cur_vc;
  dt_out    <= cur_dt;
  hdr_2bit  <= hdr2_i;

end architecture;
