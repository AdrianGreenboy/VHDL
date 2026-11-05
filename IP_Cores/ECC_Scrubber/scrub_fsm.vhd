-- scrub_fsm.vhd - FSM de scrubbing (Layer 2). Core 20 HERCOSSNUX.
-- Recorre una region de BRAM SDP, decodifica cada palabra (codec combinacional
-- colgando de la lectura registrada), hace read-correct-writeback (RCW) con
-- dwell para respetar la latencia de 1 ciclo de la BRAM, y contabiliza:
--   CE_COUNT  (errores de 1 bit corregidos, con writeback)
--   DED_COUNT (errores de 2 bits detectados, sin writeback)
-- Sticky first/last: primer y ultimo error del barrido (addr, syndrome, flags).
--
-- Secuencia por palabra:
--   IDLE -> START (fija raddr=i) -> WAIT1 (dwell: dato valido en rdata) ->
--   EVAL (decode combinacional; si CE, we=1 con palabra re-encodeada) ->
--   NEXT (i++). Al terminar la region -> DONE.
--
-- Audit 2026-11 (AUDIT_FIXES.md):
--   * S_DONE is no longer a trap: a new start (or periodic trigger) re-arms the
--     FSM from S_DONE exactly as from S_IDLE.
--   * Region sweep: words (region_base + i) mod DEPTH, i = 0 .. min(len,DEPTH)-1.
--     region_len = 0 completes immediately without touching memory.
--   * Periodic scrubbing: if 'period' /= 0 and the last CPU start had
--     oneshot = '0', a new sweep is triggered 'period' cycles after the previous
--     sweep completed. Periodic sweeps ACCUMULATE counters / sticky records (a
--     CPU start clears them, as the frozen register-map oracle specifies).
--   * Start requests are latched (start_pend) and only served when 'hold' = '0',
--     so the owner of the shared BRAM read port (injector, data window) can
--     finish its access without being hijacked mid-sweep.
--   * clr_cnt / clr_sticky pulses and W1C sticky flags (ce_flag / ded_flag).
-- All new inputs have defaults that reproduce the original behaviour (full
-- region from word 0, no period, no hold) so the Layer 2 bench is unchanged.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ecc_pkg.all;

entity scrub_fsm is
  generic (
    DEPTH : natural := 64
  );
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;               -- sincrono, activo alto
    start  : in  std_logic;               -- pulso: arranca un barrido
    -- configuration (defaults = original behaviour)
    oneshot     : in  std_logic := '1';   -- '1': no periodic re-trigger
    region_base : in  std_logic_vector(31 downto 0) := (others => '0');  -- word index
    region_len  : in  std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(DEPTH, 32));
    period      : in  std_logic_vector(31 downto 0) := (others => '0');  -- cycles, 0 = off
    hold        : in  std_logic := '0';   -- '1': another agent owns the BRAM read port
    clr_cnt     : in  std_logic := '0';   -- pulse: clear CE/DED counters
    clr_sticky  : in  std_logic := '0';   -- pulse: clear first/last records and flags
    w1c_flags   : in  std_logic_vector(1 downto 0) := "00";  -- bit0 ded, bit1 ce (W1C)
    -- interfaz BRAM
    we     : out std_logic;
    waddr  : out std_logic_vector(15 downto 0);
    wdata  : out ecc_t;
    raddr  : out std_logic_vector(15 downto 0);
    rdata  : in  ecc_t;
    -- estado / resultados
    busy       : out std_logic;
    done       : out std_logic;
    ce_count   : out std_logic_vector(31 downto 0);
    ded_count  : out std_logic_vector(31 downto 0);
    first_addr : out std_logic_vector(31 downto 0);
    first_syn  : out std_logic_vector(9 downto 0);  -- bit6..0 syn, bit8 ded, bit9 ce
    last_addr  : out std_logic_vector(31 downto 0);
    last_syn   : out std_logic_vector(9 downto 0);
    ce_flag    : out std_logic;   -- sticky, W1C
    ded_flag   : out std_logic;   -- sticky, W1C
    periodic   : out std_logic    -- '1' while the periodic trigger is armed
  );
end entity;

architecture rtl of scrub_fsm is
  type state_t is (S_IDLE, S_START, S_WAIT1, S_EVAL, S_NEXT, S_DONE);
  signal state : state_t := S_IDLE;

  signal idx      : natural range 0 to DEPTH := 0;          -- words swept
  signal cur      : natural range 0 to DEPTH-1 := 0;        -- current BRAM index
  signal len_eff  : natural range 0 to DEPTH := DEPTH;      -- latched at sweep start
  signal ce_r     : unsigned(31 downto 0) := (others => '0');
  signal ded_r    : unsigned(31 downto 0) := (others => '0');
  signal have_first : std_logic := '0';
  signal first_a  : unsigned(31 downto 0) := (others => '0');
  signal first_s  : std_logic_vector(9 downto 0) := (others => '0');
  signal last_a   : unsigned(31 downto 0) := (others => '0');
  signal last_s   : std_logic_vector(9 downto 0) := (others => '0');
  signal ce_f, ded_f : std_logic := '0';

  -- start handling
  signal start_pend : std_logic := '0';   -- a sweep is requested
  signal pend_clear : std_logic := '0';   -- '1': CPU start (clear results), '0': periodic
  signal per_armed  : std_logic := '0';
  signal per_cnt    : unsigned(31 downto 0) := (others => '0');

  -- codec combinacional
  signal dec_data : data_t;
  signal dec_syn  : std_logic_vector(6 downto 0);
  signal dec_cor  : std_logic;
  signal dec_ded  : std_logic;
  signal enc_out  : ecc_t;

  signal we_i     : std_logic := '0';
  signal waddr_i  : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata_i  : ecc_t := (others => '0');
  signal raddr_i  : std_logic_vector(15 downto 0) := (others => '0');

  signal active   : std_logic;
begin

  -- codec combinacional: decodifica la palabra leida y reencoda el dato corregido
  codec : entity work.ecc_codec
    port map (
      enc_data => dec_data,   -- reencoda el dato ya corregido por decode
      enc_code => enc_out,
      dec_code => rdata,
      dec_data => dec_data,
      dec_syn  => dec_syn,
      dec_cor  => dec_cor,
      dec_ded  => dec_ded
    );

  we    <= we_i;
  waddr <= waddr_i;
  wdata <= wdata_i;
  raddr <= raddr_i;

  active <= '1' when state /= S_IDLE and state /= S_DONE else '0';
  -- busy also covers a latched / just-arriving start so that a poll of STATUS
  -- right after the CONTROL write can never see the stale 'done' of the
  -- previous sweep.
  busy <= active or start_pend or start;
  done <= '1' when state = S_DONE and start_pend = '0' and start = '0' else '0';
  ce_count   <= std_logic_vector(ce_r);
  ded_count  <= std_logic_vector(ded_r);
  first_addr <= std_logic_vector(first_a);
  first_syn  <= first_s;
  last_addr  <= std_logic_vector(last_a);
  last_syn   <= last_s;
  ce_flag    <= ce_f;
  ded_flag   <= ded_f;
  periodic   <= per_armed;

  process(clk)
    variable rec : std_logic_vector(9 downto 0);
    variable b   : natural range 0 to DEPTH-1;
    variable l   : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      we_i <= '0';  -- por defecto no escribe
      if rst = '1' then
        state <= S_IDLE;
        idx <= 0; cur <= 0; len_eff <= DEPTH;
        ce_r <= (others => '0');
        ded_r <= (others => '0');
        have_first <= '0';
        first_a <= (others => '0'); first_s <= (others => '0');
        last_a  <= (others => '0'); last_s  <= (others => '0');
        ce_f <= '0'; ded_f <= '0';
        start_pend <= '0'; pend_clear <= '0';
        per_armed <= '0'; per_cnt <= (others => '0');
      else
        -- ---------------- requests / maintenance ------------------------
        if start = '1' then
          start_pend <= '1';
          pend_clear <= '1';
          per_armed  <= not oneshot;
          per_cnt    <= (others => '0');
        end if;
        -- PERIOD = 0 disarms the periodic trigger (as does a start with oneshot=1)
        if unsigned(period) = 0 then
          per_armed <= '0';
        end if;
        -- periodic trigger: counts idle cycles after a completed sweep
        if per_armed = '1' and state = S_DONE and start_pend = '0' and start = '0' then
          if per_cnt >= unsigned(period) - 1 then
            per_cnt    <= (others => '0');
            start_pend <= '1';
            pend_clear <= '0';
          else
            per_cnt <= per_cnt + 1;
          end if;
        end if;
        if clr_cnt = '1' then
          ce_r <= (others => '0'); ded_r <= (others => '0');
        end if;
        if clr_sticky = '1' then
          have_first <= '0';
          first_a <= (others => '0'); first_s <= (others => '0');
          last_a  <= (others => '0'); last_s  <= (others => '0');
          ce_f <= '0'; ded_f <= '0';
        end if;
        if w1c_flags(0) = '1' then ded_f <= '0'; end if;
        if w1c_flags(1) = '1' then ce_f  <= '0'; end if;

        -- ---------------- sweep FSM -------------------------------------
        case state is
          when S_IDLE | S_DONE =>
            if start_pend = '1' and start = '0' and hold = '0' then
              start_pend <= '0';
              if pend_clear = '1' then
                ce_r <= (others => '0');
                ded_r <= (others => '0');
                have_first <= '0';
                ce_f <= '0'; ded_f <= '0';
              end if;
              -- latch the region: base mod DEPTH, length clamped to DEPTH
              b := to_integer(unsigned(region_base) mod to_unsigned(DEPTH, 32));
              l := unsigned(region_len);
              idx <= 0;
              cur <= b;
              if l = 0 then
                len_eff <= 0;
                state   <= S_DONE;            -- empty region: nothing to do
              else
                if l > to_unsigned(DEPTH, 32) then
                  len_eff <= DEPTH;
                else
                  len_eff <= to_integer(l);
                end if;
                state <= S_START;
              end if;
            end if;

          when S_START =>
            raddr_i <= std_logic_vector(to_unsigned(cur, 16));
            state <= S_WAIT1;

          when S_WAIT1 =>
            -- dwell: la BRAM entrega mem(raddr) en rdata este ciclo
            state <= S_EVAL;

          when S_EVAL =>
            rec := (others => '0');
            rec(6 downto 0) := dec_syn;
            if dec_cor = '1' then
              -- writeback de la palabra corregida (reencodeada)
              we_i    <= '1';
              waddr_i <= std_logic_vector(to_unsigned(cur, 16));
              wdata_i <= enc_out;
              ce_r <= ce_r + 1;
              ce_f <= '1';
              rec(9) := '1';  -- was_ce (bit9, formato mapa MMIO)
              if have_first = '0' then
                first_a <= to_unsigned(cur, 32);
                first_s <= rec;
                have_first <= '1';
              end if;
              last_a <= to_unsigned(cur, 32);
              last_s <= rec;
            elsif dec_ded = '1' then
              ded_r <= ded_r + 1;
              ded_f <= '1';
              rec(8) := '1';  -- was_ded (bit8)
              if have_first = '0' then
                first_a <= to_unsigned(cur, 32);
                first_s <= rec;
                have_first <= '1';
              end if;
              last_a <= to_unsigned(cur, 32);
              last_s <= rec;
            end if;
            state <= S_NEXT;

          when S_NEXT =>
            if idx + 1 >= len_eff then
              state <= S_DONE;
            else
              idx <= idx + 1;
              if cur = DEPTH-1 then cur <= 0; else cur <= cur + 1; end if;  -- wrap
              state <= S_START;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
