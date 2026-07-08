--------------------------------------------------------------------------------
-- usart_engine.vhd -- MMUSART core engine (baud NCO + TX + RX). Layer 1 of 5.
-- Target: RV32I SoC v3 peripheral (region 0x6000_0000), TE0950 / xcve2302.
-- No FIFOs and no registers here: byte_fifo x2 + usart_mmio come in layer 2.
--
-- Features
--   * Baud generator: 33-bit phase accumulator (NCO). tick16 = carry out.
--       K = baud * 16 * 2^32 / Fclk        (Fclk = 100 MHz on this SoC)
--     Error is sub-0.01% at any standard rate, 300 baud .. 6.25 Mbaud.
--   * RX: 2FF synchronizer, false-start rejection (majority vote at mid start
--     bit), data sampled by majority vote over oversampling ticks 7/8/9.
--   * Formats: 7/8 data bits, parity none/even/odd, 1/2 stop bits.
--     STOP2 affects TX only; RX always validates a single stop bit (standard
--     receiver practice, tolerates 1 or 2 incoming stops).
--   * Error events (1-cycle pulses; sticky W1C logic lives in usart_mmio):
--       frame_err : stop bit low, data non-zero. Data IS pushed (16550-style).
--       par_err   : parity mismatch on good stop. Data IS pushed.
--       break_det : entire frame low incl. stop. Data NOT pushed.
--     After frame_err/break the RX holds (R_HOLD) until the line returns
--     high, so a long break generates exactly one event.
--   * FLOW_EN=1: CTS_n (2FF-synced) gates TX at character boundaries only,
--     never mid-frame. FLOW_EN=0: CTS_n fully ignored.
--   * HALF_DUP=1: single shared line on the TXD pad. txd_t releases the pad
--     to Hi-Z when idle (external pull-up REQUIRED in the XDC). RX listens to
--     txd_line_i (IOBUF .O readback). Echo suppression while tx_active plus a
--     1 bit-time post-TX guard; TX defers to an ongoing RX and waits a
--     1 bit-time turnaround after RX goes idle. tx_active spans the whole
--     frame -> ready-made DE strobe for an external RS-485 transceiver.
--   * LOOP_INT=1: RX listens to the internal TX line (no pads). In half
--     duplex this deliberately verifies echo suppression (RX stays silent).
--
-- Assumptions / contract
--   * Configuration inputs change only while EN='0' or both engines idle.
--   * tx_valid/tx_data follow FWFT semantics: data valid before the pop;
--     tx_ready is the 1-cycle pop strobe.
--   * bit_tick is a free-running one-pulse-per-bit-time strobe for the RX
--     idle-timeout counter implemented upstream in usart_mmio.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usart_engine is
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    -- configuration
    en         : in  std_logic;
    tx_en      : in  std_logic;
    rx_en      : in  std_logic;
    par_en     : in  std_logic;
    par_odd    : in  std_logic;
    stop2      : in  std_logic;
    data7      : in  std_logic;
    flow_en    : in  std_logic;
    half_dup   : in  std_logic;
    loop_int   : in  std_logic;
    baud_k     : in  std_logic_vector(31 downto 0);
    -- TX byte stream (from FWFT FIFO)
    tx_valid   : in  std_logic;
    tx_data    : in  std_logic_vector(7 downto 0);
    tx_ready   : out std_logic;   -- 1-cycle pop pulse
    -- RX byte stream (to FIFO)
    rx_valid   : out std_logic;   -- 1-cycle push pulse
    rx_data    : out std_logic_vector(7 downto 0);
    -- event pulses
    frame_err  : out std_logic;
    par_err    : out std_logic;
    break_det  : out std_logic;
    -- status
    tx_busy    : out std_logic;
    rx_busy    : out std_logic;
    bit_tick   : out std_logic;
    -- physical side
    rxd_i      : in  std_logic;   -- RXD pad (full duplex)
    txd_line_i : in  std_logic;   -- shared-line readback (half duplex)
    txd_o      : out std_logic;
    txd_t      : out std_logic;   -- '1' = release pad
    cts_n_i    : in  std_logic;
    tx_active  : out std_logic
  );
end entity usart_engine;

architecture rtl of usart_engine is

  -- NCO ----------------------------------------------------------------------
  signal acc     : unsigned(32 downto 0) := (others => '0');
  signal tick16  : std_logic;
  signal btcnt   : unsigned(3 downto 0)  := (others => '0');

  -- input synchronizers ------------------------------------------------------
  signal rxd_m, rxd_s : std_logic := '1';
  signal lin_m, lin_s : std_logic := '1';
  signal cts_m, cts_s : std_logic := '1';

  -- RX line select + edge register -------------------------------------------
  signal rx_line   : std_logic;
  signal rx_line_q : std_logic := '1';
  signal rx_mask   : std_logic;

  -- TX -------------------------------------------------------------------------
  type t_txs is (T_IDLE, T_START, T_DATA, T_PAR, T_STOP1, T_STOP2);
  signal txs      : t_txs := T_IDLE;
  signal tx_sh    : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_parb  : std_logic := '0';
  signal tx_cnt   : unsigned(3 downto 0) := (others => '0');
  signal tx_bit   : unsigned(2 downto 0) := (others => '0');
  signal txd_int  : std_logic := '1';
  signal tx_act_i : std_logic;

  -- RX -------------------------------------------------------------------------
  type t_rxs is (R_IDLE, R_START, R_DATA, R_PAR, R_STOP, R_HOLD);
  signal rxs       : t_rxs := R_IDLE;
  signal rx_cnt    : unsigned(3 downto 0) := (others => '0');
  signal rx_bit    : unsigned(2 downto 0) := (others => '0');
  signal rx_sh     : std_logic_vector(7 downto 0) := (others => '0');
  signal s7, s8    : std_logic := '1';
  signal vote      : std_logic;
  signal rx_allz   : std_logic := '0';
  signal rx_perr   : std_logic := '0';
  signal rx_busy_i : std_logic;

  -- half-duplex helpers (counted in tick16 units) ------------------------------
  signal guard : unsigned(4 downto 0) := (others => '0'); -- post-TX RX mask
  signal turn  : unsigned(4 downto 0) := (others => '0'); -- post-RX TX turnaround

  -- format helpers --------------------------------------------------------------
  signal nlast   : unsigned(2 downto 0);                 -- index of last data bit
  signal dmask   : std_logic_vector(7 downto 0);         -- data bit mask
  signal rx_pexp : std_logic;                            -- expected RX parity

begin

  nlast <= "110" when data7 = '1' else "111";
  dmask <= x"7F"  when data7 = '1' else x"FF";

  ------------------------------------------------------------------------------
  -- Baud NCO: acc(32) is the carry of the last addition -> exactly one clk wide.
  ------------------------------------------------------------------------------
  p_nco : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' or en = '0' then
        acc   <= (others => '0');
        btcnt <= (others => '0');
      else
        acc <= ('0' & acc(31 downto 0)) + resize(unsigned(baud_k), 33);
        if tick16 = '1' then
          btcnt <= btcnt + 1;
        end if;
      end if;
    end if;
  end process;

  tick16   <= acc(32);
  bit_tick <= '1' when tick16 = '1' and btcnt = 15 else '0';

  ------------------------------------------------------------------------------
  -- Input synchronizers (2FF). loop_int path stays in-domain, no sync needed.
  ------------------------------------------------------------------------------
  p_sync : process(clk)
  begin
    if rising_edge(clk) then
      rxd_m <= rxd_i;      rxd_s <= rxd_m;
      lin_m <= txd_line_i; lin_s <= lin_m;
      cts_m <= cts_n_i;    cts_s <= cts_m;
    end if;
  end process;

  rx_line <= txd_int when loop_int = '1' else
             lin_s   when half_dup = '1' else
             rxd_s;

  -- half-duplex echo suppression: masked while transmitting + 1 bit-time guard
  rx_mask <= '1' when half_dup = '1' and (tx_act_i = '1' or guard /= 0) else '0';

  ------------------------------------------------------------------------------
  -- Half-duplex guard/turnaround counters (tick16 units, 16 = one bit time)
  ------------------------------------------------------------------------------
  p_hd : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' or en = '0' then
        guard <= (others => '0');
        turn  <= (others => '0');
      elsif tick16 = '1' then
        if tx_act_i = '1' then
          guard <= to_unsigned(16, guard'length);
        elsif guard /= 0 then
          guard <= guard - 1;
        end if;
        if rx_busy_i = '1' then
          turn <= to_unsigned(16, turn'length);
        elsif turn /= 0 then
          turn <= turn - 1;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- TX FSM. All transitions on tick16 -> every bit cell is exactly 16 ticks,
  -- including the start bit (launch waits for the next tick16, <=1/16 bit).
  ------------------------------------------------------------------------------
  p_tx : process(clk)
    variable go : boolean;
  begin
    if rising_edge(clk) then
      tx_ready <= '0';
      if rst_n = '0' or en = '0' or tx_en = '0' then
        txs     <= T_IDLE;
        txd_int <= '1';
      elsif tick16 = '1' then
        case txs is

          when T_IDLE =>
            txd_int <= '1';
            go := (tx_valid = '1');
            if flow_en = '1' and cts_s = '1' then
              go := false;                                -- CTS gate, char boundary only
            end if;
            if half_dup = '1' and (rx_busy_i = '1' or turn /= 0) then
              go := false;                                -- defer to RX + turnaround
            end if;
            if go then
              tx_sh    <= tx_data;
              tx_parb  <= (xor (tx_data and dmask)) xor par_odd;
              tx_ready <= '1';
              tx_cnt   <= (others => '0');
              tx_bit   <= (others => '0');
              txd_int  <= '0';                            -- start bit
              txs      <= T_START;
            end if;

          when T_START =>
            if tx_cnt = 15 then
              tx_cnt  <= (others => '0');
              tx_bit  <= (others => '0');
              txd_int <= tx_sh(0);                        -- LSB first
              txs     <= T_DATA;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

          when T_DATA =>
            if tx_cnt = 15 then
              tx_cnt <= (others => '0');
              if tx_bit = nlast then
                if par_en = '1' then
                  txd_int <= tx_parb;
                  txs     <= T_PAR;
                else
                  txd_int <= '1';
                  txs     <= T_STOP1;
                end if;
              else
                txd_int <= tx_sh(to_integer(tx_bit) + 1);
                tx_bit  <= tx_bit + 1;
              end if;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

          when T_PAR =>
            if tx_cnt = 15 then
              tx_cnt  <= (others => '0');
              txd_int <= '1';
              txs     <= T_STOP1;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

          when T_STOP1 =>
            if tx_cnt = 15 then
              tx_cnt <= (others => '0');
              if stop2 = '1' then
                txs <= T_STOP2;                           -- line stays '1'
              else
                txs <= T_IDLE;
              end if;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

          when T_STOP2 =>
            if tx_cnt = 15 then
              tx_cnt <= (others => '0');
              txs    <= T_IDLE;
            else
              tx_cnt <= tx_cnt + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  tx_act_i  <= '1' when txs /= T_IDLE else '0';
  tx_active <= tx_act_i;
  tx_busy   <= tx_act_i;
  txd_o     <= txd_int;
  -- full duplex: always drive. half duplex: release the pad when not sending.
  txd_t     <= '1' when half_dup = '1' and tx_act_i = '0' else '0';

  ------------------------------------------------------------------------------
  -- RX FSM. Arm on the falling edge at clk resolution (phase error <= 1/16 bit),
  -- then count tick16: samples at ticks 7/8, majority vote closed at tick 9.
  ------------------------------------------------------------------------------
  vote <= (s7 and s8) or (s7 and rx_line) or (s8 and rx_line);

  p_rx : process(clk)
  begin
    if rising_edge(clk) then
      rx_valid  <= '0';
      frame_err <= '0';
      par_err   <= '0';
      break_det <= '0';
      rx_line_q <= rx_line;

      if rst_n = '0' or en = '0' or rx_en = '0' then
        rxs <= R_IDLE;
      else
        case rxs is

          when R_IDLE =>
            if rx_line_q = '1' and rx_line = '0' and rx_mask = '0' then
              rxs     <= R_START;
              rx_cnt  <= (others => '0');
              rx_allz <= '1';
              rx_perr <= '0';
            end if;

          when R_HOLD =>                                  -- wait for line high
            if rx_line = '1' then
              rxs <= R_IDLE;
            end if;

          when others =>
            if tick16 = '1' then
              if rx_cnt = 7 then s7 <= rx_line; end if;
              if rx_cnt = 8 then s8 <= rx_line; end if;

              case rxs is

                when R_START =>
                  if rx_cnt = 9 and vote = '1' then
                    rxs <= R_IDLE;                        -- glitch: false start
                  elsif rx_cnt = 15 then
                    rx_cnt <= (others => '0');
                    rx_bit <= (others => '0');
                    rxs    <= R_DATA;
                  else
                    rx_cnt <= rx_cnt + 1;
                  end if;

                when R_DATA =>
                  if rx_cnt = 9 then
                    rx_sh(to_integer(rx_bit)) <= vote;
                    if vote = '1' then rx_allz <= '0'; end if;
                  end if;
                  if rx_cnt = 15 then
                    rx_cnt <= (others => '0');
                    if rx_bit = nlast then
                      if par_en = '1' then rxs <= R_PAR;
                      else                 rxs <= R_STOP;
                      end if;
                    else
                      rx_bit <= rx_bit + 1;
                    end if;
                  else
                    rx_cnt <= rx_cnt + 1;
                  end if;

                when R_PAR =>
                  if rx_cnt = 9 then
                    if vote = '1' then rx_allz <= '0'; end if;
                    if vote /= rx_pexp then rx_perr <= '1'; end if;
                  end if;
                  if rx_cnt = 15 then
                    rx_cnt <= (others => '0');
                    rxs    <= R_STOP;
                  else
                    rx_cnt <= rx_cnt + 1;
                  end if;

                when R_STOP =>
                  if rx_cnt = 9 then
                    -- decision at mid stop bit (standard: frees the receiver
                    -- half a bit early, tolerant to slightly slow remote TX)
                    if vote = '1' then
                      rx_valid <= '1';
                      rx_data  <= rx_sh and dmask;
                      if par_en = '1' and rx_perr = '1' then
                        par_err <= '1';                   -- data pushed anyway
                      end if;
                      rxs <= R_IDLE;
                    else
                      if rx_allz = '1' then
                        break_det <= '1';                 -- break: no push
                      else
                        frame_err <= '1';                 -- bad stop: push data
                        rx_valid  <= '1';
                        rx_data   <= rx_sh and dmask;
                      end if;
                      rxs <= R_HOLD;
                    end if;
                  else
                    rx_cnt <= rx_cnt + 1;
                  end if;

                when others =>
                  rxs <= R_IDLE;

              end case;
            end if;
        end case;
      end if;
    end if;
  end process;

  rx_busy_i <= '0' when rxs = R_IDLE else '1';
  rx_busy   <= rx_busy_i;

  -- expected parity over the received data bits (mask covers data7)
  rx_pexp <= (xor (rx_sh and dmask)) xor par_odd;

end architecture rtl;
