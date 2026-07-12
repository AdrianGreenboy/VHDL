-- ptp_tx.vhd — motor TX-PTP unificado (IP PTP / IEEE 802.1AS v1)
-- FSM que genera Sync, Pdelay_Req, Pdelay_Resp desde plantillas ROM y parchea
-- campos variables. Override 1-step por tipo: originTimestamp (Sync/Req) o
-- correctionField=residence (Resp). Interfaz de escritura explicita a FIFO.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity ptp_tx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    send       : in  std_logic;
    sel        : in  msg_sel_t;
    busy       : out std_logic;
    done       : out std_logic;
    clock_id   : in  std_logic_vector(63 downto 0);
    port_num   : in  std_logic_vector(15 downto 0);
    src_mac    : in  std_logic_vector(47 downto 0);
    req_rx_sec : in  std_logic_vector(SEC_W-1 downto 0);
    req_rx_ns  : in  std_logic_vector(NS_W-1 downto 0);
    req_portid : in  std_logic_vector(79 downto 0);
    ts_sec     : in  std_logic_vector(SEC_W-1 downto 0);
    ts_ns      : in  std_logic_vector(NS_W-1 downto 0);
    ts_valid   : in  std_logic;
    ts_ack     : out std_logic;
    fifo_wr    : out std_logic;
    fifo_din   : out std_logic_vector(8 downto 0);
    fifo_full  : in  std_logic;
    ovr_en     : out std_logic;
    ovr_off    : out std_logic_vector(10 downto 0);
    ovr_len    : out std_logic_vector(3 downto 0);
    ovr_data   : out std_logic_vector(79 downto 0);
    dbg_st     : out std_logic_vector(2 downto 0)
  );
end entity ptp_tx;

architecture rtl of ptp_tx is


  type st_t is (S_IDLE, S_PUSH, S_WAIT_TS, S_DONE);
  signal st : st_t := S_IDLE;

  signal idx      : integer range 0 to PDELAY_FRAME_LEN := 0;
  signal frame_len: integer range 0 to PDELAY_FRAME_LEN := SYNC_FRAME_LEN;
  signal seq_r    : unsigned(15 downto 0) := (others => '0');
  signal sel_r    : msg_sel_t := SEL_SYNC;
  signal busy_r   : std_logic := '0';
  signal done_r   : std_logic := '0';
  signal ack_r    : std_logic := '0';

  signal fwr_r    : std_logic := '0';
  signal fdin_r   : std_logic_vector(8 downto 0) := (others => '0');

  signal ovr_en_r : std_logic := '0';
  signal ovr_dat_r: std_logic_vector(79 downto 0) := (others => '0');
  -- ================== TRAMA COMO SHIFT REGISTER ==========================
  -- NOTA DE SINTESIS (leccion aprendida a fuego): CUATRO formulaciones del
  -- lookup de plantilla indexado por (sel_r, idx) fueron mal sintetizadas por
  -- Vivado 2025.2.1 (ROM en ceros; luego indice con bit5 pegado: ROM(i|32),
  -- medido en silicio dos veces con estructuras RTL distintas). Solucion
  -- definitiva: NO HAY INDICE. La trama completa se carga en un shift
  -- register de 544 bits al aceptar el send (plantilla = literal hex, parches
  -- = slices con indices ESTATICOS) y S_PUSH solo desplaza 8 bits por ciclo.
  signal shreg : std_logic_vector(0 to 543) := (others => '0');
  constant FR_SYNC_LIT : std_logic_vector(0 to 543) := x"0180C200000E00000000000088F70002002C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
  constant FR_REQ_LIT  : std_logic_vector(0 to 543) := x"0180C200000E00000000000088F7020200360000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000";
  constant FR_RESP_LIT : std_logic_vector(0 to 543) := x"0180C200000E00000000000088F7030200360000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000";

  signal ovr_off_r: std_logic_vector(10 downto 0) := (others => '0');
  signal ovr_len_r: std_logic_vector(3 downto 0)  := (others => '0');


  function pack_origin_ts(sec : std_logic_vector(SEC_W-1 downto 0);
                          ns  : std_logic_vector(NS_W-1 downto 0))
    return std_logic_vector is
    variable d : std_logic_vector(79 downto 0) := (others => '0');
  begin
    for i in 0 to 5 loop
      d(i*8+7 downto i*8) := sec((5-i)*8+7 downto (5-i)*8);
    end loop;
    for i in 0 to 3 loop
      d((6+i)*8+7 downto (6+i)*8) := ns((3-i)*8+7 downto (3-i)*8);
    end loop;
    return d;
  end function;

  -- residence = (t3 - t2) en ns, escalado a 2^-16 ns (unidad del
  -- correctionField). t3 = SFD TX del Resp (ts_*), t2 = req_rx_* (SFD RX del
  -- Req). En loopback t3-t2 es pequeno y positivo. Se calcula con signo y se
  -- empaqueta big-endian en los 8 bytes del correctionField.
  function calc_residence(t3sec, t2sec : std_logic_vector(SEC_W-1 downto 0);
                          t3ns,  t2ns  : std_logic_vector(NS_W-1 downto 0))
    return std_logic_vector is
    variable t3v, t2v, dns : signed(63 downto 0);
    variable corr : signed(63 downto 0);
    variable d : std_logic_vector(79 downto 0) := (others => '0');
    -- limites de saturacion +/-2^40, construidos con shift para evitar el
    -- desborde del integer de 32b de VHDL al escribir 2**40 literal.
    constant SAT_POS : signed(63 downto 0) := shift_left(to_signed(1, 64), 40);
    constant SAT_NEG : signed(63 downto 0) := -shift_left(to_signed(1, 64), 40);
  begin
    t3v := resize(signed('0' & t3sec) * to_signed(1_000_000_000, 34), 64)
           + resize(signed('0' & t3ns), 64);
    t2v := resize(signed('0' & t2sec) * to_signed(1_000_000_000, 34), 64)
           + resize(signed('0' & t2ns), 64);
    dns := t3v - t2v;                        -- residence en ns
    -- el residence real es pequeno (ns). Saturar antes del shift de 16 para
    -- evitar overflow con valores transitorios patologicos. Limite 2^40 ns
    -- construido por patron de bits (integer VHDL de 32b no admite 2**40).
    if dns > SAT_POS then
      dns := SAT_POS;
    elsif dns < SAT_NEG then
      dns := SAT_NEG;
    end if;
    corr := shift_left(dns, 16);             -- a 2^-16 ns
    for i in 0 to 7 loop
      d(i*8+7 downto i*8) := std_logic_vector(corr((7-i)*8+7 downto (7-i)*8));
    end loop;
    return d;
  end function;

begin


  busy     <= busy_r;
  dbg_st   <= "000" when st = S_IDLE else "001" when st = S_PUSH else "010" when st = S_WAIT_TS else "011";
  done     <= done_r;
  ts_ack   <= ack_r;
  fifo_wr  <= fwr_r;
  fifo_din <= fdin_r;
  ovr_en   <= ovr_en_r;
  ovr_off  <= ovr_off_r;
  ovr_len  <= ovr_len_r;
  ovr_data <= ovr_dat_r;

  process(clk)
  begin
    if rising_edge(clk) then
      done_r <= '0';
      ack_r  <= '0';
      if rst = '1' then
        st <= S_IDLE; idx <= 0; seq_r <= (others => '0');
        busy_r <= '0'; fwr_r <= '0'; fdin_r <= (others => '0');
        ovr_en_r <= '0'; ovr_dat_r <= (others => '0');
        ovr_off_r <= (others => '0'); ovr_len_r <= (others => '0');
      else
        case st is

          when S_IDLE =>
            fwr_r <= '0';
            if send = '1' then
              busy_r <= '1'; idx <= 0; sel_r <= sel;
              ovr_en_r <= '1'; ovr_dat_r <= (others => '0');
              case sel is
                when SEL_SYNC =>
                  frame_len <= SYNC_FRAME_LEN;
                  ovr_off_r <= std_logic_vector(to_unsigned(OFF_ORIGIN_TS, 11));
                  ovr_len_r <= std_logic_vector(to_unsigned(10, 4));
                when SEL_PDELAY_REQ =>
                  frame_len <= PDELAY_FRAME_LEN;
                  ovr_off_r <= std_logic_vector(to_unsigned(OFF_ORIGIN_TS, 11));
                  ovr_len_r <= std_logic_vector(to_unsigned(10, 4));
                when SEL_PDELAY_RESP =>
                  frame_len <= PDELAY_FRAME_LEN;
                  ovr_off_r <= std_logic_vector(to_unsigned(OFF_CORR, 11));
                  ovr_len_r <= std_logic_vector(to_unsigned(8, 4));
                when others =>
                  frame_len <= SYNC_FRAME_LEN;
                  ovr_off_r <= std_logic_vector(to_unsigned(OFF_ORIGIN_TS, 11));
                  ovr_len_r <= std_logic_vector(to_unsigned(10, 4));
              end case;
              -- cargar la trama completa: literal + parches (slices ESTATICOS)
              case sel is
                when SEL_PDELAY_REQ  => shreg <= FR_REQ_LIT;
                when SEL_PDELAY_RESP => shreg <= FR_RESP_LIT;
                when others          => shreg <= FR_SYNC_LIT;
              end case;
              shreg(6*8  to 12*8-1) <= src_mac;                       -- SA
              shreg(34*8 to 42*8-1) <= clock_id;                      -- clockIdentity
              shreg(42*8 to 44*8-1) <= port_num;                      -- portNumber
              shreg(44*8 to 46*8-1) <= std_logic_vector(seq_r);       -- sequenceId
              if sel = SEL_PDELAY_RESP then
                shreg(48*8 to 54*8-1) <= req_rx_sec;                  -- t2.sec
                shreg(54*8 to 58*8-1) <= req_rx_ns;                   -- t2.ns
                shreg(58*8 to 68*8-1) <= req_portid;                  -- requestingPortId
              end if;
              st <= S_PUSH;
            end if;

          when S_PUSH =>
            if fifo_full = '0' then
              fwr_r <= '1';
              if idx = frame_len-1 then
                fdin_r <= '1' & shreg(0 to 7);
                st <= S_WAIT_TS;
              else
                fdin_r <= '0' & shreg(0 to 7);
                idx <= idx + 1;
              end if;
              shreg <= shreg(8 to 543) & x"00";   -- siguiente byte a la cabeza
            else
              fwr_r <= '0';
            end if;
            if ts_valid = '1' then
              if sel_r = SEL_PDELAY_RESP then
                ovr_dat_r <= calc_residence(ts_sec, req_rx_sec, ts_ns, req_rx_ns);
              else
                ovr_dat_r <= pack_origin_ts(ts_sec, ts_ns);
              end if;
            end if;

          when S_WAIT_TS =>
            fwr_r <= '0';
            if ts_valid = '1' then
              if sel_r = SEL_PDELAY_RESP then
                ovr_dat_r <= calc_residence(ts_sec, req_rx_sec, ts_ns, req_rx_ns);
              else
                ovr_dat_r <= pack_origin_ts(ts_sec, ts_ns);
              end if;
              ack_r <= '1';
              st <= S_DONE;
            end if;

          when S_DONE =>
            busy_r <= '0'; done_r <= '1'; seq_r <= seq_r + 1;
            st <= S_IDLE;

          when others =>
            st <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
