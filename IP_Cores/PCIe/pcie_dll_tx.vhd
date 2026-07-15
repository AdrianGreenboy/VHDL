-- ============================================================================
-- pcie_dll_tx.vhd -- PCIE IP v1
-- Data Link Layer TX. Asigna seq de 12 bits, calcula LCRC-32, guarda en replay
-- buffer (BRAM SDP) y procesa ACK/NAK (purga / retransmision).
--
-- Formato entregado al framer (que lo envolvera en STP..END):
--   [seq_hi][seq_lo][payload...][lcrc0][lcrc1][lcrc2][lcrc3]
-- LCRC-32 sobre {seq_hi, seq_lo, payload}, seed 0xFFFFFFFF, finalizado
-- (complemento + bit-reverse por byte).
--
-- Replay buffer: un BRAM de bytes (1 wr / 1 rd) + metadatos por slot
-- (seq, base, len, used). Hasta REPLAY_SLOTS TLPs en vuelo.
--   ACK(seq): purga slots con seq en (acked, ak]; acked<-ak.
--   NAK(seq): retransmite en orden todos los slots con seq > ak.
--
-- Emision nueva (T_NEW_*) y retransmision (T_RPL_*) tienen estados SEPARADOS
-- para no compartir el cierre de slot (que solo ocurre en emision nueva).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_dll_pkg.all;

entity pcie_dll_tx is
  generic (
    MAX_TLP      : integer := 64;
    REPLAY_SLOTS : integer := 8
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    tl_valid  : in  std_logic;
    tl_data   : in  byte_t;
    tl_last   : in  std_logic;
    tl_ready  : out std_logic;

    fr_valid  : out std_logic;
    fr_data   : out byte_t;
    fr_last   : out std_logic;
    fr_ready  : in  std_logic;
    fr_start  : out std_logic;

    ak_valid  : in  std_logic;
    ak_is_nak : in  std_logic;
    ak_seq    : in  std_logic_vector(11 downto 0);

    nseq_o    : out std_logic_vector(11 downto 0);
    acked_o   : out std_logic_vector(11 downto 0);
    inflight_o: out std_logic_vector(7 downto 0);
    replays_o : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of pcie_dll_tx is
  constant ADDR_BITS : integer := 10;

  type ram_t is array (0 to 2**ADDR_BITS - 1) of byte_t;
  signal ram : ram_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";

  type len_t  is array (0 to REPLAY_SLOTS-1) of integer range 0 to MAX_TLP;
  type base_t is array (0 to REPLAY_SLOTS-1) of integer range 0 to 2**ADDR_BITS-1;
  type seqm_t is array (0 to REPLAY_SLOTS-1) of seq_t;
  signal slot_len  : len_t  := (others => 0);
  signal slot_base : base_t := (others => 0);
  signal slot_seq  : seqm_t := (others => (others => '0'));
  signal slot_used : std_logic_vector(REPLAY_SLOTS-1 downto 0) := (others=>'0');

  type tstate_t is (T_IDLE, T_NEW_SEQ, T_NEW_PAY, T_NEW_CRC,
                    T_RPL_FIND, T_RPL_SEQ, T_RPL_PAY, T_RPL_CRC);
  signal st : tstate_t := T_IDLE;

  signal nseq    : seq_t := (others => '0');
  signal acked   : seq_t := (others => '0');
  signal inflight_cnt : integer range 0 to REPLAY_SLOTS := 0;
  signal replays : unsigned(15 downto 0) := (others => '0');

  signal wr_slot : integer range 0 to REPLAY_SLOTS-1 := 0;
  signal wr_ptr  : integer range 0 to 2**ADDR_BITS-1 := 0;
  signal cur_len : integer range 0 to MAX_TLP := 0;
  signal cur_base: integer range 0 to 2**ADDR_BITS-1 := 0;

  signal crc     : crc32_t := LCRC_SEED;
  signal crc_fin : crc32_t := (others => '0');
  signal ci      : integer range 0 to 4 := 0;
  signal sbyte   : integer range 0 to 2 := 0;

  signal rpl_pending : std_logic := '0';
  signal rpl_from    : seq_t := (others => '0');
  signal rpl_slot    : integer range 0 to REPLAY_SLOTS-1 := 0;
  signal rpl_i       : integer range 0 to MAX_TLP := 0;
  signal rpl_len     : integer range 0 to MAX_TLP := 0;
  signal rpl_base    : integer range 0 to 2**ADDR_BITS-1 := 0;
  signal rpl_target  : seq_t := (others => '0');

  function seq_hi(s : seq_t) return byte_t is
  begin return "0000" & std_logic_vector(s(11 downto 8)); end function;
  function seq_lo(s : seq_t) return byte_t is
  begin return std_logic_vector(s(7 downto 0)); end function;
  function sdist(a, b : seq_t) return integer is
    -- Distancia modular de numeros de secuencia de 12 bits. Se calcula como
    -- resta en unsigned de 12 bits (envuelve naturalmente a 2^12), lo que
    -- equivale a (a-b) mod 4096 pero sin lógica de division/mod con signo:
    -- el 'mod' original saturaba la sintesis al replicarse en bucles.
    variable d : unsigned(11 downto 0);
  begin
    d := a - b;                 -- resta modular 12-bit (wrap-around implicito)
    return to_integer(d);
  end function;
begin

  -- inflight se DERIVA de slot_used para evitar la colision incremento/
  -- decremento en el mismo ciclo (ACK que purga mientras se cierra un TLP).
  process(slot_used)
    variable n : integer;
  begin
    n := 0;
    for i in 0 to REPLAY_SLOTS-1 loop
      if slot_used(i) = '1' then n := n + 1; end if;
    end loop;
    inflight_cnt <= n;
  end process;

  nseq_o     <= std_logic_vector(nseq);
  acked_o    <= std_logic_vector(acked);
  inflight_o <= std_logic_vector(to_unsigned(inflight_cnt, 8));
  replays_o  <= std_logic_vector(replays);
  tl_ready   <= '1' when (st = T_NEW_PAY and fr_ready = '1') else '0';

  process(clk)
    variable purge_n : integer;
    variable ak : integer;
    variable found : boolean;
    variable best_d : integer;
    variable best_i : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= T_IDLE; nseq <= (others=>'0'); acked <= (others=>'0');
        replays <= (others=>'0');
        wr_slot <= 0; wr_ptr <= 0; cur_len <= 0; cur_base <= 0;
        crc <= LCRC_SEED; ci <= 0; sbyte <= 0;
        slot_used <= (others=>'0');
        fr_valid <= '0'; fr_last <= '0'; fr_start <= '0'; fr_data <= (others=>'0');
        rpl_pending <= '0'; rpl_i <= 0;
      else
        fr_start <= '0';

        -- ------- ACK/NAK -------
        if ak_valid = '1' then
          ak := to_integer(unsigned(ak_seq));
          if ak_is_nak = '0' then
            purge_n := 0;
            for i in 0 to REPLAY_SLOTS-1 loop
              if slot_used(i) = '1' then
                if sdist(slot_seq(i), acked) >= 1 and
                   sdist(slot_seq(i), acked) <= sdist(to_unsigned(ak,12), acked) then
                  slot_used(i) <= '0';
                  slot_len(i)  <= 0;
                  purge_n := purge_n + 1;
                end if;
              end if;
            end loop;
            acked <= to_unsigned(ak, 12);
          else
            rpl_pending <= '1';
            rpl_from    <= to_unsigned(ak, 12);
            replays     <= replays + 1;
          end if;
        end if;

        -- ------- FSM -------
        case st is
          when T_IDLE =>
            fr_valid <= '0'; fr_last <= '0';
            if rpl_pending = '1' and inflight_cnt > 0 then
              st <= T_RPL_FIND;
            elsif tl_valid = '1' then
              cur_base <= wr_ptr; cur_len <= 0;
              crc <= f_crc32_byte(f_crc32_byte(LCRC_SEED, seq_hi(nseq)),
                                  seq_lo(nseq));
              fr_start <= '1'; sbyte <= 0;
              st <= T_NEW_SEQ;
            end if;

          when T_NEW_SEQ =>
            if fr_ready = '1' then
              fr_valid <= '1'; fr_last <= '0';
              if sbyte = 0 then fr_data <= seq_hi(nseq); sbyte <= 1;
              else fr_data <= seq_lo(nseq); sbyte <= 0; st <= T_NEW_PAY; end if;
            else fr_valid <= '0'; end if;

          when T_NEW_PAY =>
            if tl_valid = '1' and fr_ready = '1' then
              fr_valid <= '1'; fr_data <= tl_data; fr_last <= '0';
              ram(cur_base + cur_len) <= tl_data;
              cur_len <= cur_len + 1;
              crc <= f_crc32_byte(crc, tl_data);
              if tl_last = '1' then
                crc_fin <= f_lcrc_final(f_crc32_byte(crc, tl_data));
                ci <= 0; st <= T_NEW_CRC;
              end if;
            else fr_valid <= '0'; end if;

          when T_NEW_CRC =>
            if fr_ready = '1' then
              fr_valid <= '1';
              case ci is
                when 0 => fr_data <= crc_fin(7 downto 0);
                when 1 => fr_data <= crc_fin(15 downto 8);
                when 2 => fr_data <= crc_fin(23 downto 16);
                when others => fr_data <= crc_fin(31 downto 24);
              end case;
              if ci = 3 then
                fr_last <= '1';
                slot_seq(wr_slot)  <= nseq;
                slot_base(wr_slot) <= cur_base;
                slot_len(wr_slot)  <= cur_len;
                slot_used(wr_slot) <= '1';
                wr_ptr  <= cur_base + cur_len;
                if wr_slot = REPLAY_SLOTS-1 then wr_slot <= 0;
                else wr_slot <= wr_slot + 1; end if;
                nseq    <= nseq + 1;
                st <= T_IDLE;
              else
                fr_last <= '0'; ci <= ci + 1;
              end if;
            else fr_valid <= '0'; end if;

          when T_RPL_FIND =>
            found := false; best_d := 4096; best_i := 0;
            for i in 0 to REPLAY_SLOTS-1 loop
              if slot_used(i) = '1' and sdist(slot_seq(i), rpl_from) >= 1
                 and sdist(slot_seq(i), rpl_from) < 2048 then
                if sdist(slot_seq(i), rpl_from) < best_d then
                  best_d := sdist(slot_seq(i), rpl_from);
                  best_i := i; found := true;
                end if;
              end if;
            end loop;
            if found then
              rpl_slot   <= best_i;
              rpl_target <= slot_seq(best_i);
              rpl_len    <= slot_len(best_i);
              rpl_base   <= slot_base(best_i);
              crc <= f_crc32_byte(f_crc32_byte(LCRC_SEED, seq_hi(slot_seq(best_i))),
                                  seq_lo(slot_seq(best_i)));
              fr_start <= '1'; sbyte <= 0; rpl_i <= 0;
              st <= T_RPL_SEQ;
            else
              rpl_pending <= '0';
              st <= T_IDLE;
            end if;

          when T_RPL_SEQ =>
            if fr_ready = '1' then
              fr_valid <= '1'; fr_last <= '0';
              if sbyte = 0 then fr_data <= seq_hi(rpl_target); sbyte <= 1;
              else fr_data <= seq_lo(rpl_target); sbyte <= 0; st <= T_RPL_PAY; end if;
            else fr_valid <= '0'; end if;

          when T_RPL_PAY =>
            if fr_ready = '1' then
              if rpl_i < rpl_len then
                fr_valid <= '1'; fr_last <= '0';
                fr_data <= ram(rpl_base + rpl_i);
                crc <= f_crc32_byte(crc, ram(rpl_base + rpl_i));
                rpl_i <= rpl_i + 1;
              else
                crc_fin <= f_lcrc_final(crc);
                ci <= 0; fr_valid <= '0'; st <= T_RPL_CRC;
              end if;
            else fr_valid <= '0'; end if;

          when T_RPL_CRC =>
            if fr_ready = '1' then
              fr_valid <= '1';
              case ci is
                when 0 => fr_data <= crc_fin(7 downto 0);
                when 1 => fr_data <= crc_fin(15 downto 8);
                when 2 => fr_data <= crc_fin(23 downto 16);
                when others => fr_data <= crc_fin(31 downto 24);
              end case;
              if ci = 3 then
                fr_last <= '1';
                rpl_from <= rpl_target;
                st <= T_RPL_FIND;
              else
                fr_last <= '0'; ci <= ci + 1;
              end if;
            else fr_valid <= '0'; end if;
        end case;
      end if;
    end if;
  end process;

end architecture;
