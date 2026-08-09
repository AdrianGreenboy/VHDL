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
    last_syn   : out std_logic_vector(9 downto 0)
  );
end entity;

architecture rtl of scrub_fsm is
  type state_t is (S_IDLE, S_START, S_WAIT1, S_EVAL, S_NEXT, S_DONE);
  signal state : state_t := S_IDLE;

  signal idx      : natural range 0 to DEPTH := 0;
  signal ce_r     : unsigned(31 downto 0) := (others => '0');
  signal ded_r    : unsigned(31 downto 0) := (others => '0');
  signal have_first : std_logic := '0';
  signal first_a  : unsigned(31 downto 0) := (others => '0');
  signal first_s  : std_logic_vector(9 downto 0) := (others => '0');
  signal last_a   : unsigned(31 downto 0) := (others => '0');
  signal last_s   : std_logic_vector(9 downto 0) := (others => '0');

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

  busy <= '1' when state /= S_IDLE and state /= S_DONE else '0';
  done <= '1' when state = S_DONE else '0';
  ce_count   <= std_logic_vector(ce_r);
  ded_count  <= std_logic_vector(ded_r);
  first_addr <= std_logic_vector(first_a);
  first_syn  <= first_s;
  last_addr  <= std_logic_vector(last_a);
  last_syn   <= last_s;

  process(clk)
    variable rec : std_logic_vector(9 downto 0);
  begin
    if rising_edge(clk) then
      we_i <= '0';  -- por defecto no escribe
      if rst = '1' then
        state <= S_IDLE;
        idx <= 0;
        ce_r <= (others => '0');
        ded_r <= (others => '0');
        have_first <= '0';
        first_a <= (others => '0'); first_s <= (others => '0');
        last_a  <= (others => '0'); last_s  <= (others => '0');
      else
        case state is
          when S_IDLE =>
            if start = '1' then
              idx <= 0;
              ce_r <= (others => '0');
              ded_r <= (others => '0');
              have_first <= '0';
              state <= S_START;
            end if;

          when S_START =>
            raddr_i <= std_logic_vector(to_unsigned(idx, 16));
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
              waddr_i <= std_logic_vector(to_unsigned(idx, 16));
              wdata_i <= enc_out;
              ce_r <= ce_r + 1;
              rec(9) := '1';  -- was_ce (bit9, formato mapa MMIO)
              if have_first = '0' then
                first_a <= to_unsigned(idx, 32);
                first_s <= rec;
                have_first <= '1';
              end if;
              last_a <= to_unsigned(idx, 32);
              last_s <= rec;
            elsif dec_ded = '1' then
              ded_r <= ded_r + 1;
              rec(8) := '1';  -- was_ded (bit8)
              if have_first = '0' then
                first_a <= to_unsigned(idx, 32);
                first_s <= rec;
                have_first <= '1';
              end if;
              last_a <= to_unsigned(idx, 32);
              last_s <= rec;
            end if;
            state <= S_NEXT;

          when S_NEXT =>
            if idx = DEPTH-1 then
              state <= S_DONE;
            else
              idx <= idx + 1;
              state <= S_START;
            end if;

          when S_DONE =>
            state <= S_DONE;  -- permanece hasta rst/start
        end case;
      end if;
    end if;
  end process;
end architecture;
