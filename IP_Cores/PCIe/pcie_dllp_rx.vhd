-- ============================================================================
-- pcie_dllp_rx.vhd -- PCIE IP (audit 2026-11)
-- Receives DLLPs from the deframer token stream (SDP, 6 data bytes, END),
-- checks the DLLP CRC-16 and decodes Ack/Nak for the local DLL TX:
--   ak_valid pulse, ak_is_nak, ak_seq = AckNak_Seq_Num of the PEER.
-- DLLPs with a bad CRC, a wrong length or a framing error are discarded
-- (spec: no action other than error logging) and counted in bad_o.
-- Other DLLP types (FC, PM) are ignored and counted in other_o.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;   -- rx_kind_t
use work.pcie_dll_pkg.all;

entity pcie_dllp_rx is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    tok       : in  rx_kind_t;
    tok_data  : in  work.pcie_dll_pkg.byte_t;
    tok_valid : in  std_logic;
    ak_valid  : out std_logic;
    ak_is_nak : out std_logic;
    ak_seq    : out std_logic_vector(11 downto 0);
    good_o    : out std_logic_vector(15 downto 0);
    bad_o     : out std_logic_vector(15 downto 0);
    other_o   : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of pcie_dllp_rx is
  type b6_t is array (0 to 5) of work.pcie_dll_pkg.byte_t;
  signal b    : b6_t := (others => (others => '0'));
  signal n    : integer range 0 to 7 := 0;
  signal busy : std_logic := '0';
  signal good, bad, other : unsigned(15 downto 0) := (others => '0');
begin
  good_o <= std_logic_vector(good);
  bad_o  <= std_logic_vector(bad);
  other_o <= std_logic_vector(other);

  process(clk)
    variable c : crc16_t;
  begin
    if rising_edge(clk) then
      ak_valid <= '0';
      if rst = '1' then
        busy <= '0'; n <= 0;
        good <= (others => '0'); bad <= (others => '0'); other <= (others => '0');
        ak_is_nak <= '0'; ak_seq <= (others => '0');
      elsif tok_valid = '1' then
        case tok is
          when RK_DLLP_START =>
            if busy = '1' then bad <= bad + 1; end if;
            busy <= '1'; n <= 0;
          when RK_DLLP_DATA =>
            if busy = '1' then
              if n < 6 then b(n) <= tok_data; end if;
              if n < 7 then n <= n + 1; end if;
            end if;
          when RK_DLLP_END =>
            if busy = '1' then
              c := f_dllp_crc(b(0), b(1), b(2), b(3));
              if n = 6 and b(4) = c(7 downto 0) and b(5) = c(15 downto 8) then
                if b(0) = DB_ACK or b(0) = DB_NAK then
                  ak_valid  <= '1';
                  ak_is_nak <= '1' when b(0) = DB_NAK else '0';
                  ak_seq    <= b(2)(3 downto 0) & b(3);
                  good <= good + 1;
                else
                  other <= other + 1;
                end if;
              else
                bad <= bad + 1;
              end if;
            end if;
            busy <= '0';
          when RK_ERR | RK_TLP_START | RK_TS1 | RK_TS2 | RK_EIOS =>
            if busy = '1' then bad <= bad + 1; end if;
            busy <= '0';
          when others => null;
        end case;
      end if;
    end if;
  end process;
end architecture;
