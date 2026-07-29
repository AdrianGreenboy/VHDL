-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- keccak_sponge: byte-serial sponge wrapper over keccak_f1600.
-- Modes: 0 = SHAKE128 (rate 168), 1 = SHAKE256 (rate 136),
--        2 = SHA3-256 (rate 136),  3 = SHA3-512 (rate 72).
-- VHDL-2008. ASCII-only. MIT license.
--
-- Incremental squeeze is mandatory for the ML-KEM / ML-DSA rejection
-- samplers: the caller pulls bytes one at a time for as long as it needs and
-- the sponge permutes on demand when a rate block is exhausted.
--
-- Protocol:
--   1. pulse init with mode set -> state cleared, absorb phase begins
--   2. for each message byte: hold din valid and pulse din_we when ready='1'
--   3. pulse absorb_done -> padding is applied and the final block permuted
--   4. read bytes: pulse dout_re when dout_valid='1'; dout holds the byte.
--      The sponge permutes transparently between rate blocks.
--   ready is low while a permutation is in flight.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.keccak_pkg.all;

entity keccak_sponge is
  port (
    clk         : in  std_logic;
    rst_n       : in  std_logic;
    -- control
    mode        : in  std_logic_vector(1 downto 0);
    init        : in  std_logic;
    -- absorb
    din         : in  std_logic_vector(7 downto 0);
    din_we      : in  std_logic;
    absorb_done : in  std_logic;
    -- squeeze
    dout        : out std_logic_vector(7 downto 0);
    dout_re     : in  std_logic;
    dout_valid  : out std_logic;
    -- status
    ready       : out std_logic);
end entity keccak_sponge;

architecture rtl of keccak_sponge is

  type t_fsm is (S_IDLE, S_ABSORB, S_PERM_ABS, S_PAD, S_PERM_PAD,
                 S_SQUEEZE, S_PERM_SQZ);

  signal fsm       : t_fsm := S_IDLE;

  signal st        : t_state := (others => (others => '0'));
  signal rate      : integer range 0 to 168 := 168;
  signal ds        : std_logic_vector(7 downto 0) := x"1F";
  signal pos       : integer range 0 to 168 := 0;

  -- keccak_f1600 interface
  signal k_start   : std_logic := '0';
  signal k_in      : t_state := (others => (others => '0'));
  signal k_out     : t_state;
  signal k_done    : std_logic;
  signal k_busy    : std_logic;

  signal ready_r   : std_logic := '0';
  signal dvalid_r  : std_logic := '0';

  -- XOR one byte into the state at byte offset p (little-endian lanes).
  function xor_byte (s : t_state; p : integer; b : std_logic_vector(7 downto 0))
    return t_state is
    variable r  : t_state;
    variable ln : integer;
    variable bo : integer;
  begin
    r  := s;
    ln := p / 8;
    bo := p mod 8;
    r(ln)(8 * bo + 7 downto 8 * bo) := r(ln)(8 * bo + 7 downto 8 * bo) xor b;
    return r;
  end function xor_byte;

  -- Read one byte from the state at byte offset p.
  function get_byte (s : t_state; p : integer)
    return std_logic_vector is
    variable ln : integer;
    variable bo : integer;
  begin
    ln := p / 8;
    bo := p mod 8;
    return s(ln)(8 * bo + 7 downto 8 * bo);
  end function get_byte;

begin

  u_perm : entity work.keccak_f1600
    port map (
      clk       => clk,
      rst_n     => rst_n,
      start     => k_start,
      state_in  => k_in,
      state_out => k_out,
      busy      => k_busy,
      done      => k_done);

  ready      <= ready_r;
  dout_valid <= dvalid_r;

  process (clk)
    variable s_tmp : t_state;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm      <= S_IDLE;
        st       <= (others => (others => '0'));
        pos      <= 0;
        rate     <= 168;
        ds       <= x"1F";
        k_start  <= '0';
        ready_r  <= '0';
        dvalid_r <= '0';
        dout     <= (others => '0');
      else
        k_start <= '0';

        if init = '1' and k_busy = '0' then
          -- Global synchronous restart. Accepted from any state so that a
          -- caller can begin a new absorb without first draining a squeeze.
          st  <= (others => (others => '0'));
          pos <= 0;
          case mode is
            when "00" => rate <= 168; ds <= x"1F";  -- SHAKE128
            when "01" => rate <= 136; ds <= x"1F";  -- SHAKE256
            when "10" => rate <= 136; ds <= x"06";  -- SHA3-256
            when others => rate <= 72; ds <= x"06"; -- SHA3-512
          end case;
          fsm      <= S_ABSORB;
          ready_r  <= '1';
          dvalid_r <= '0';
        else

        case fsm is

          when S_IDLE =>
            -- Parked state after reset. Start-up is handled by the global
            -- init branch above.
            ready_r  <= '0';
            dvalid_r <= '0';

          when S_ABSORB =>
            if absorb_done = '1' then
              ready_r <= '0';
              fsm     <= S_PAD;
            elsif din_we = '1' then
              s_tmp := xor_byte(st, pos, din);
              st    <= s_tmp;
              if pos = rate - 1 then
                -- rate block full: permute before taking more bytes
                k_in    <= s_tmp;
                k_start <= '1';
                ready_r <= '0';
                pos     <= 0;
                fsm     <= S_PERM_ABS;
              else
                pos <= pos + 1;
              end if;
            end if;

          when S_PERM_ABS =>
            if k_done = '1' then
              st      <= k_out;
              ready_r <= '1';
              fsm     <= S_ABSORB;
            end if;

          when S_PAD =>
            -- pad10*1: domain separator at pos, 0x80 at rate-1.
            s_tmp   := xor_byte(st, pos, ds);
            s_tmp   := xor_byte(s_tmp, rate - 1, x"80");
            st      <= s_tmp;
            k_in    <= s_tmp;
            k_start <= '1';
            pos     <= 0;
            fsm     <= S_PERM_PAD;

          when S_PERM_PAD =>
            if k_done = '1' then
              st       <= k_out;
              dout     <= get_byte(k_out, 0);
              dvalid_r <= '1';
              ready_r  <= '1';
              pos      <= 0;
              fsm      <= S_SQUEEZE;
            end if;

          when S_SQUEEZE =>
            if dout_re = '1' then
              if pos = rate - 1 then
                -- current block exhausted: permute for the next one
                k_in     <= st;
                k_start  <= '1';
                dvalid_r <= '0';
                ready_r  <= '0';
                pos      <= 0;
                fsm      <= S_PERM_SQZ;
              else
                dout <= get_byte(st, pos + 1);
                pos  <= pos + 1;
              end if;
            end if;

          when S_PERM_SQZ =>
            if k_done = '1' then
              st       <= k_out;
              dout     <= get_byte(k_out, 0);
              dvalid_r <= '1';
              ready_r  <= '1';
              fsm      <= S_SQUEEZE;
            end if;

        end case;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
