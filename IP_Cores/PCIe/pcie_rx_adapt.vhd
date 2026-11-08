-- ============================================================================
-- pcie_rx_adapt.vhd -- PCIE IP (reworked in audit 2026-11)
-- RX adapter: turns the deframer tokens (RK_TLP_START/DATA/END/ABORT/ERR)
-- into the raw byte stream of one TLP for the DLL RX:
--   [seq_hi seq_lo][header+payload][lcrc0..3]
-- out_start on the first byte (seq_hi); out_last on the final data byte
-- (lcrc3). A one-byte holding register lets 'last' be attached to that byte
-- when the END token arrives.
--
-- Audit changes:
--   * The TL is NO LONGER fed from here (it was fed before LCRC/seq
--     validation). The validated path is DLL RX -> pcie_rx_tlp_fifo -> TL.
--   * out_abort: EDB, a framing error (RK_ERR), a new STP / ordered set inside
--     an open TLP, or more than MAX_BYTES bytes -> the DLL RX discards the TLP.
--   * The byte counter saturates (no integer overflow on a runaway TLP).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;   -- rx_kind_t

entity pcie_rx_adapt is
  generic (
    MAX_BYTES : integer := 134    -- MAX_TLP + 2 (seq) + 4 (LCRC)
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    tok       : in  rx_kind_t;
    tok_data  : in  byte_t;
    tok_valid : in  std_logic;

    -- raw stream (seq+tlp+lcrc) -> DLL RX
    out_valid : out std_logic;
    out_data  : out byte_t;
    out_start : out std_logic;
    out_last  : out std_logic;
    out_abort : out std_logic
  );
end entity;

architecture rtl of pcie_rx_adapt is
  type st_t is (A_IDLE, A_RUN);
  signal st   : st_t := A_IDLE;
  signal bcnt : integer range 0 to MAX_BYTES+1 := 0;
  -- one byte of delay so that 'last' can be attached to the final byte
  signal hold_v : std_logic := '0';
  signal hold_d : byte_t := (others => '0');
  signal hold_s : std_logic := '0';
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        st <= A_IDLE; bcnt <= 0; hold_v <= '0'; hold_s <= '0';
        out_valid<='0'; out_start<='0'; out_last<='0'; out_abort<='0';
        out_data<=(others=>'0');
      else
        out_valid<='0'; out_start<='0'; out_last<='0'; out_abort<='0';
        if tok_valid = '1' then
          case st is
            when A_IDLE =>
              if tok = RK_TLP_START then
                st <= A_RUN; bcnt <= 0; hold_v <= '0'; hold_s <= '1';
              end if;

            when A_RUN =>
              case tok is
                when RK_TLP_DATA =>
                  if bcnt > MAX_BYTES then
                    out_valid <= '1'; out_abort <= '1';      -- runaway TLP
                    st <= A_IDLE; hold_v <= '0';
                  else
                    bcnt <= bcnt + 1;
                    if hold_v = '1' then
                      out_valid <= '1'; out_data <= hold_d; out_start <= hold_s;
                      hold_s <= '0';
                    end if;
                    hold_v <= '1'; hold_d <= tok_data;
                  end if;
                when RK_TLP_END =>
                  if hold_v = '1' then
                    out_valid <= '1'; out_data <= hold_d; out_start <= hold_s;
                    out_last <= '1';
                  else
                    out_valid <= '1'; out_abort <= '1';       -- empty TLP
                  end if;
                  hold_v <= '0'; st <= A_IDLE;
                when RK_TLP_START =>
                  -- STP inside an open TLP: abort the old one, start a new one
                  out_valid <= '1'; out_abort <= '1';
                  bcnt <= 0; hold_v <= '0'; hold_s <= '1';
                when RK_TLP_ABORT | RK_ERR | RK_TS1 | RK_TS2 | RK_EIOS |
                     RK_DLLP_START =>
                  out_valid <= '1'; out_abort <= '1';
                  hold_v <= '0'; st <= A_IDLE;
                when others =>
                  null;   -- RK_SKP etc. cannot appear inside a TLP: ignore
              end case;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;
