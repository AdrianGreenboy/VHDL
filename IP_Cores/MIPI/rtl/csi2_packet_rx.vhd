-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L2: Packet-layer parser.
-- Consumes a CSI-2 byte stream, decodes each header (ECC-corrected), classifies
-- short vs long packets, validates long-packet payloads with CRC-16, and emits
-- validated payload bytes.
--
-- Short packet data types: 0x00 FS, 0x01 FE, 0x02 LS, 0x03 LE (VC in bits 7:6).
-- Long packet: RAW12 = 0x2C. Header WC gives payload length; 2-byte CRC follows.
--
-- AUDIT 2026-11 -- line rate: the parser consumes one byte on EVERY cycle in
-- EVERY state. The header is decoded combinationally on its 4th byte (ECC over
-- h0..h2 + the incoming ECC byte) and the CRC is compared on the 2nd CRC byte,
-- so the former S_DECODE / S_CHECK dead cycles (which forced 1 byte / 3 cycles
-- pacing upstream) are gone. Back-to-back packets with no gap are supported.
-- AUDIT 2026-11 -- framing / errors:
--   byte_sot : qualifies the FIRST byte of an HS transmission (from the lane
--              layer). It always restarts header parsing on that byte; a long
--              packet still in flight is aborted (pl_drop + pkt_err).
--   byte_eot : end of the HS transmission (pulse, no byte). A long packet still
--              in flight is truncated -> pl_drop + pkt_err.
--   uncorrectable header (2-bit ECC): NO sop is emitted, hdr_2bit + pkt_err
--              pulse, and every byte is discarded until the next byte_sot.
--   cfg_multi_pkt='0': one packet per HS burst -- after a packet completes the
--              rest of the burst (e.g. D-PHY trailer bytes from a raw PHY) is
--              ignored until the next SoT. '1' (default, legacy byte streams
--              without SoT marks): keep parsing back-to-back packets.
-- hdr_2bit and pkt_err are single-cycle pulses (the MMIO latches them sticky).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.csi2_pkg.all;

entity csi2_packet_rx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- byte input (from the lane layer / self-test generator)
    byte_in    : in  std_logic_vector(7 downto 0);
    byte_valid : in  std_logic;
    byte_sot   : in  std_logic := '0';   -- with byte_valid: first byte of a burst
    byte_eot   : in  std_logic := '0';   -- pulse: burst ended (no byte)
    cfg_multi_pkt : in std_logic := '1';
    -- validated payload output
    pl_byte    : out std_logic_vector(7 downto 0);
    pl_valid   : out std_logic;      -- payload byte, CRC not yet confirmed
    pl_commit  : out std_logic;      -- pulse: last packet's CRC was GOOD
    pl_drop    : out std_logic;      -- pulse: last packet's CRC was BAD / aborted
    -- decoded header side-channel (valid with sop)
    sop        : out std_logic;      -- start of packet (header decoded)
    is_long    : out std_logic;
    vc_out     : out std_logic_vector(1 downto 0);
    dt_out     : out std_logic_vector(5 downto 0);
    hdr_2bit   : out std_logic;      -- pulse: header uncorrectable, packet aborted
    pkt_err    : out std_logic       -- pulse: any abort (ECC, SoT/EoT truncation)
  );
end entity;

architecture rtl of csi2_packet_rx is
  type state_t is (S_H0, S_H1, S_H2, S_H3, S_PAYLOAD, S_CRC0, S_CRC1, S_WAIT_SOT);
  signal state : state_t := S_H0;

  signal h0, h1, h2 : std_logic_vector(7 downto 0) := (others => '0');

  -- ECC (combinational, evaluated on the 4th header byte)
  signal ecc_data_in  : std_logic_vector(23 downto 0);
  signal ecc_data_out : std_logic_vector(23 downto 0);
  signal ecc_1bit, ecc_2bit : std_logic;

  signal crc_acc   : unsigned(15 downto 0) := x"FFFF";
  signal wc_cnt    : unsigned(15 downto 0) := (others => '0');
  signal wc_total  : unsigned(15 downto 0) := (others => '0');
  signal cur_vc    : std_logic_vector(1 downto 0) := "00";
  signal cur_dt    : std_logic_vector(5 downto 0) := (others => '0');
  signal cur_long  : std_logic := '0';
  signal crc_lo    : std_logic_vector(7 downto 0) := (others => '0');

  -- registered outputs
  signal pl_byte_i  : std_logic_vector(7 downto 0) := (others => '0');
  signal pl_valid_i : std_logic := '0';
  signal pl_commit_i: std_logic := '0';
  signal pl_drop_i  : std_logic := '0';
  signal sop_i      : std_logic := '0';
  signal hdr2_i     : std_logic := '0';
  signal perr_i     : std_logic := '0';

  function is_short_dt(dt : std_logic_vector(5 downto 0)) return boolean is
  begin
    return dt = "000000" or dt = "000001" or dt = "000010" or dt = "000011";
  end function;
begin

  ecc : entity work.csi2_ecc
    port map (data_in=>ecc_data_in, ecc_in=>byte_in(5 downto 0),
              data_out=>ecc_data_out, err_1bit=>ecc_1bit, err_2bit=>ecc_2bit);

  -- ECC input assembled from the first 3 header bytes: {WC_H,WC_L,DataID}
  ecc_data_in <= h2 & h1 & h0;

  process(clk)
    variable did  : std_logic_vector(7 downto 0);
    variable wc   : unsigned(15 downto 0);
    variable st   : state_t;
    variable done_next : state_t;
  begin
    if rising_edge(clk) then
      -- default single-cycle pulses
      pl_valid_i  <= '0';
      pl_commit_i <= '0';
      pl_drop_i   <= '0';
      sop_i       <= '0';
      hdr2_i      <= '0';
      perr_i      <= '0';

      if rst = '1' then
        state <= S_H0;
        crc_acc <= x"FFFF";
      else
        st := state;
        if cfg_multi_pkt = '1' then done_next := S_H0; else done_next := S_WAIT_SOT; end if;

        -- A new transmission (SoT) or its end (EoT) aborts a packet in flight.
        if (byte_valid = '1' and byte_sot = '1') or byte_eot = '1' then
          if st = S_PAYLOAD or st = S_CRC0 or st = S_CRC1 then
            pl_drop_i <= '1';
            perr_i    <= '1';
          elsif (st = S_H1 or st = S_H2 or st = S_H3) then
            perr_i    <= '1';            -- truncated header
          end if;
          if byte_eot = '1' then
            st := done_next;             -- nothing else in this burst
            if cfg_multi_pkt = '1' then st := S_H0; end if;
          else
            st := S_H0;                  -- this byte is h0 of a new packet
          end if;
        end if;

        if byte_valid = '1' then
          case st is
            when S_H0 =>
              h0 <= byte_in; st := S_H1;
            when S_H1 =>
              h1 <= byte_in; st := S_H2;
            when S_H2 =>
              h2 <= byte_in; st := S_H3;

            when S_H3 =>
              -- byte_in is the ECC byte: decode the header now (combinational)
              did := ecc_data_out(7 downto 0);
              wc  := unsigned(ecc_data_out(23 downto 8));
              if ecc_2bit = '1' then
                -- uncorrectable: abort, resynchronise at the next SoT
                hdr2_i <= '1';
                perr_i <= '1';
                st := S_WAIT_SOT;
              else
                cur_vc <= did(7 downto 6);
                cur_dt <= did(5 downto 0);
                sop_i  <= '1';
                if is_short_dt(did(5 downto 0)) then
                  cur_long <= '0';
                  st := done_next;                   -- short packet done
                else
                  cur_long <= '1';
                  wc_total <= wc;
                  wc_cnt   <= (others => '0');
                  crc_acc  <= x"FFFF";               -- reset CRC for payload
                  if wc = 0 then
                    st := S_CRC0;
                  else
                    st := S_PAYLOAD;
                  end if;
                end if;
              end if;

            when S_PAYLOAD =>
              -- emit payload byte, feed CRC
              pl_byte_i  <= byte_in;
              pl_valid_i <= '1';
              crc_acc    <= csi2_crc_step(crc_acc, byte_in);
              if wc_cnt = wc_total - 1 then
                st := S_CRC0;
              else
                wc_cnt <= wc_cnt + 1;
              end if;

            when S_CRC0 =>
              crc_lo <= byte_in;
              st := S_CRC1;

            when S_CRC1 =>
              -- received CRC = {byte_in, crc_lo} (LSByte first); crc_acc is final
              if std_logic_vector(crc_acc) = (byte_in & crc_lo) then
                pl_commit_i <= '1';
              else
                pl_drop_i <= '1';
              end if;
              st := done_next;

            when S_WAIT_SOT =>
              null;                                  -- discard until SoT
          end case;
        end if;
        state <= st;
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
  pkt_err   <= perr_i;

end architecture;
