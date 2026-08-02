-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5: synthetic CSI-2 frame generator (self-test camera).
-- Emits a byte stream byte-identical to the Python oracle:
--   VC0: gradient  pixel(x,y) = (y*W + x) mod 4096
--   VC1: bars      pixel(x,y) = 0xFFF if (x/16) odd else 0x000
-- Each frame: FS short packet, H long packets (RAW12), FE short packet.
-- RAW12 pack: b0=P0[11:4], b1=P1[11:4], b2=(P1[3:0]<<4)|P0[3:0].
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.csi2_pkg.all;

entity frame_gen is
  generic (
    W : integer := 128;
    H : integer := 96;
    BAR_W : integer := 16
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    start     : in  std_logic;                       -- pulse to begin generation
    stall     : in  std_logic;                        -- hold generation (FIFO full)
    byte_out  : out std_logic_vector(7 downto 0);
    byte_valid: out std_logic;
    busy      : out std_logic;
    done      : out std_logic                        -- pulse when both frames sent
  );
end entity;

architecture rtl of frame_gen is
  constant LINE_BYTES : integer := W*3/2;  -- 192 for W=128

  type st_t is (S_IDLE, S_FS0, S_FS1, S_FS2, S_FS3,
                S_LH0, S_LH1, S_LH2, S_LH3,
                S_PAY, S_CRC0, S_CRC1,
                S_FE0, S_FE1, S_FE2, S_FE3, S_NEXTVC, S_DONE);
  signal st : st_t := S_IDLE;

  signal vc    : integer range 0 to 1 := 0;
  signal yline : integer range 0 to 4095 := 0;
  signal xpair : integer range 0 to 4095 := 0;  -- pixel-pair index within line
  signal byte_ph : integer range 0 to 2 := 0;   -- which of the 3 packed bytes

  signal crc_acc : unsigned(15 downto 0) := (others=>'0');

  signal bo  : std_logic_vector(7 downto 0) := (others=>'0');
  signal bv  : std_logic := '0';
  signal busy_i : std_logic := '0';
  signal done_i : std_logic := '0';

  -- pixel function
  function pixgen(vc:integer; x:integer; y:integer; wi:integer; bw:integer)
    return unsigned is
    variable p : unsigned(11 downto 0);
  begin
    if vc = 0 then
      p := to_unsigned((y*wi + x) mod 4096, 12);
    else
      if ((x/bw) mod 2) = 1 then p := (others=>'1'); else p := (others=>'0'); end if;
    end if;
    return p;
  end function;

  -- data id for current vc long packet
  function did_lp(vc:integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(vc,2)) & DT_RAW12;
  end function;

  signal p0_r, p1_r : unsigned(11 downto 0) := (others=>'0');
begin

  process(clk)
    variable did : std_logic_vector(7 downto 0);
    variable wc  : integer;
    variable ecc : std_logic_vector(5 downto 0);
    variable field : std_logic_vector(23 downto 0);
    variable b2 : std_logic_vector(7 downto 0);
    variable x0, x1 : integer;
    variable wc_slv : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      bv <= '0'; done_i <= '0';
      if rst='1' then
        st <= S_IDLE; busy_i <= '0'; vc <= 0; yline <= 0; xpair <= 0; byte_ph <= 0;
      elsif stall='1' then
        -- hold: emit nothing, keep state frozen (FIFO back-pressure)
        null;
      else
        case st is
          when S_IDLE =>
            if start='1' then
              busy_i <= '1'; vc <= 0; yline <= 0; xpair <= 0; byte_ph <= 0;
              st <= S_FS0;
            end if;

          -- Frame Start short packet: DataID=vc<<6|FS, data16=0, ECC
          when S_FS0 =>
            did := std_logic_vector(to_unsigned(vc,2)) & DT_FS;
            bo <= did; bv <= '1'; st <= S_FS1;
          when S_FS1 =>
            bo <= x"00"; bv <= '1'; st <= S_FS2;
          when S_FS2 =>
            bo <= x"00"; bv <= '1'; st <= S_FS3;
          when S_FS3 =>
            did := std_logic_vector(to_unsigned(vc,2)) & DT_FS;
            field := x"0000" & did;
            ecc := csi2_ecc_enc(field);
            bo <= "00" & ecc; bv <= '1';
            yline <= 0; xpair <= 0; byte_ph <= 0;
            st <= S_LH0;

          -- Long packet header
          when S_LH0 =>
            did := did_lp(vc);
            bo <= did; bv <= '1'; st <= S_LH1;
          when S_LH1 =>
            wc := LINE_BYTES;
            wc_slv := std_logic_vector(to_unsigned(wc,16));
            bo <= wc_slv(7 downto 0); bv <= '1'; st <= S_LH2;
          when S_LH2 =>
            wc := LINE_BYTES;
            wc_slv := std_logic_vector(to_unsigned(wc,16));
            bo <= wc_slv(15 downto 8); bv <= '1'; st <= S_LH3;
          when S_LH3 =>
            did := did_lp(vc);
            wc := LINE_BYTES;
            field := std_logic_vector(to_unsigned(wc,16)) & did;
            ecc := csi2_ecc_enc(field);
            bo <= "00" & ecc; bv <= '1';
            crc_acc <= x"FFFF";
            xpair <= 0; byte_ph <= 0;
            st <= S_PAY;

          -- Payload: 3 bytes per pixel-pair, W/2 pairs
          when S_PAY =>
            x0 := xpair*2; x1 := xpair*2+1;
            p0_r <= pixgen(vc, x0, yline, W, BAR_W);
            p1_r <= pixgen(vc, x1, yline, W, BAR_W);
            -- emit according to byte_ph; compute pixel values fresh each phase
            case byte_ph is
              when 0 =>
                bo <= std_logic_vector(pixgen(vc,x0,yline,W,BAR_W)(11 downto 4));
                bv <= '1';
                crc_acc <= csi2_crc_step(crc_acc, std_logic_vector(pixgen(vc,x0,yline,W,BAR_W)(11 downto 4)));
                byte_ph <= 1;
              when 1 =>
                bo <= std_logic_vector(pixgen(vc,x1,yline,W,BAR_W)(11 downto 4));
                bv <= '1';
                crc_acc <= csi2_crc_step(crc_acc, std_logic_vector(pixgen(vc,x1,yline,W,BAR_W)(11 downto 4)));
                byte_ph <= 2;
              when others =>
                b2 := std_logic_vector(pixgen(vc,x1,yline,W,BAR_W)(3 downto 0)) &
                      std_logic_vector(pixgen(vc,x0,yline,W,BAR_W)(3 downto 0));
                bo <= b2; bv <= '1';
                crc_acc <= csi2_crc_step(crc_acc, b2);
                byte_ph <= 0;
                if xpair = (W/2 - 1) then
                  st <= S_CRC0;
                else
                  xpair <= xpair + 1;
                end if;
            end case;

          when S_CRC0 =>
            bo <= std_logic_vector(crc_acc(7 downto 0)); bv <= '1'; st <= S_CRC1;
          when S_CRC1 =>
            bo <= std_logic_vector(crc_acc(15 downto 8)); bv <= '1';
            if yline = (H-1) then
              st <= S_FE0;
            else
              yline <= yline + 1;
              st <= S_LH0;
            end if;

          -- Frame End short packet
          when S_FE0 =>
            did := std_logic_vector(to_unsigned(vc,2)) & DT_FE;
            bo <= did; bv <= '1'; st <= S_FE1;
          when S_FE1 =>
            bo <= x"00"; bv <= '1'; st <= S_FE2;
          when S_FE2 =>
            bo <= x"00"; bv <= '1'; st <= S_FE3;
          when S_FE3 =>
            did := std_logic_vector(to_unsigned(vc,2)) & DT_FE;
            field := x"0000" & did;
            ecc := csi2_ecc_enc(field);
            bo <= "00" & ecc; bv <= '1';
            st <= S_NEXTVC;

          when S_NEXTVC =>
            if vc = 0 then
              vc <= 1; yline <= 0; xpair <= 0; byte_ph <= 0;
              st <= S_FS0;
            else
              st <= S_DONE;
            end if;

          when S_DONE =>
            busy_i <= '0'; done_i <= '1'; st <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  byte_out   <= bo;
  byte_valid <= bv;
  busy       <= busy_i;
  done       <= done_i;
end architecture;
