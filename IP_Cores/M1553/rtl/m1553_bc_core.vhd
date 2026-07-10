-- m1553_bc_core.vhd
-- Bus Controller MIL-STD-1553B sobre los motores de palabra.
-- Ejecuta UN mensaje por pulso de go segun los campos latcheados:
--   BC->RT   : tr=0, sa normal  -> cmd + N datos, espera status
--   RT->BC   : tr=1, sa normal  -> cmd, espera status + N datos contiguos
--   RT->RT   : rtrt=1           -> cmd_rx(f_rt) + cmd_tx(f2_rt) sin hueco,
--                                  espera status(f2_rt) + N datos + status(f_rt)
--   mode     : sa=00000/11111   -> wc = mode code; tr=1 espera status
--                                  (+1 dato si wc>=16); tr=0 con wc>=16
--                                  envia 1 dato y espera status
--   broadcast: rt=31            -> envia y termina sin esperar status
-- Timeout de respuesta ~14 us desde mid-parity de la ultima palabra emitida
-- (TOUT_CYCLES desde la caida de tx_en). Hueco intermensaje >= GAP_CYCLES de
-- bus en reposo antes de emitir. El RX propio se enmascara al transmitir.
-- Resultado (mantenido hasta el siguiente done): r_ok, r_tout, r_serr
-- (status/secuencia invalida), r_me (bit Message Error en algun status),
-- stat1/stat2 capturados.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m1553_bc_core is
  generic (
    TOUT_CYCLES : integer := 1350;  -- desde caida de tx_en (~14 us mid-parity)
    DATA_TOUT   : integer := 2500;  -- espera de data word contigua
    GAP_CYCLES  : integer := 400    -- hueco intermensaje minimo (~4 us)
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                       -- sincrono, activo alto
    en       : in  std_logic;
    -- peticion de mensaje
    go       : in  std_logic;                       -- pulso
    rtrt     : in  std_logic;
    f_rt     : in  std_logic_vector(4 downto 0);
    f_tr     : in  std_logic;
    f_sa     : in  std_logic_vector(4 downto 0);
    f_wc     : in  std_logic_vector(4 downto 0);
    f2_rt    : in  std_logic_vector(4 downto 0);
    f2_sa    : in  std_logic_vector(4 downto 0);
    busy     : out std_logic;
    done     : out std_logic;                       -- pulso
    r_ok     : out std_logic;
    r_tout   : out std_logic;
    r_serr   : out std_logic;
    r_me     : out std_logic;
    stat1    : out std_logic_vector(15 downto 0);
    stat2    : out std_logic_vector(15 downto 0);
    -- fuente de datos TX (FWFT)
    tx_rd    : out std_logic;
    tx_wdat  : in  std_logic_vector(15 downto 0);
    -- sumidero de datos RX
    rx_we    : out std_logic;
    rx_wdat  : out std_logic_vector(15 downto 0);
    -- bus
    bus_rx   : in  std_logic;
    bus_tx   : out std_logic;
    bus_txen : out std_logic
  );
end entity m1553_bc_core;

architecture rtl of m1553_bc_core is

  type t_st is (S_IDLE, S_GAP, S_SEND, S_WST1, S_RXD, S_WST2, S_FIN);
  signal st : t_st := S_IDLE;

  signal rstc : std_logic;

  signal rx_g      : std_logic;
  signal wrx_valid, wrx_type : std_logic;
  signal wrx_data  : std_logic_vector(15 downto 0);
  signal wrx_esync, wrx_emanch, wrx_epar, wrx_busy : std_logic;

  signal wtx_start, wtx_wt, wtx_loaded, wtx_busy : std_logic;
  signal wtx_data  : std_logic_vector(15 downto 0);
  signal txen_i, txen_d : std_logic;

  -- campos latcheados
  signal m_rtrt : std_logic;
  signal m_rt, m_sa, m_wc, m2_rt, m2_sa : std_logic_vector(4 downto 0);
  signal m_tr   : std_logic;
  signal m_mode, m_bcast : std_logic;

  signal n_send  : integer range 0 to 34 := 0;      -- palabras pendientes de emitir
  signal n_exp   : integer range 0 to 32 := 0;      -- datos esperados en RX
  signal rx_cnt  : integer range 0 to 32 := 0;
  signal sendsel : integer range 0 to 34 := 0;      -- indice de palabra a emitir
  signal tmo     : integer range 0 to 4095 := 0;
  signal idle_c  : integer range 0 to 1023 := 0;    -- reposo global del bus

  -- resultado
  signal ok_r, tout_r, serr_r, me_r : std_logic := '0';

  function nwords(wc : std_logic_vector(4 downto 0)) return integer is
  begin
    if wc = "00000" then
      return 32;
    else
      return to_integer(unsigned(wc));
    end if;
  end function;

begin

  rstc <= rst or (not en);
  rx_g <= bus_rx and (not txen_i);

  u_wrx : entity work.m1553_word_rx
    port map (
      clk => clk, rst => rstc, rx_data => rx_g,
      valid => wrx_valid, word_type => wrx_type, data => wrx_data,
      err_sync => wrx_esync, err_manch => wrx_emanch, err_par => wrx_epar,
      busy => wrx_busy);

  u_wtx : entity work.m1553_word_tx
    port map (
      clk => clk, rst => rstc,
      start => wtx_start, word_type => wtx_wt, data => wtx_data,
      busy => wtx_busy, loaded => wtx_loaded,
      tx_en => txen_i, tx_data => bus_tx);

  bus_txen <= txen_i;
  busy  <= '0' when st = S_IDLE else '1';
  r_ok   <= ok_r;
  r_tout <= tout_r;
  r_serr <= serr_r;
  r_me   <= me_r;

  fsm : process(clk)
    variable v_cmd, v_dat, v_err : boolean;
    variable v_exp_addr : std_logic_vector(4 downto 0);
    variable v_fin : boolean;
    variable v_ns  : integer range 0 to 34;
  begin
    if rising_edge(clk) then
      if rstc = '1' then
        st <= S_IDLE;
        wtx_start <= '0'; tx_rd <= '0'; rx_we <= '0'; done <= '0';
        ok_r <= '0'; tout_r <= '0'; serr_r <= '0'; me_r <= '0';
        idle_c <= 0; tmo <= 0; txen_d <= '0';
      else
        wtx_start <= '0';
        tx_rd     <= '0';
        rx_we     <= '0';
        done      <= '0';
        txen_d    <= txen_i;

        -- reposo global del bus (para el hueco intermensaje)
        if rx_g = '1' or wrx_busy = '1' or txen_i = '1' then
          idle_c <= 0;
        elsif idle_c < 1023 then
          idle_c <= idle_c + 1;
        end if;

        v_cmd := (wrx_valid = '1') and (wrx_type = '1');
        v_dat := (wrx_valid = '1') and (wrx_type = '0');
        v_err := (wrx_esync = '1') or (wrx_emanch = '1') or (wrx_epar = '1');

        case st is

          when S_IDLE =>
            if go = '1' then
              m_rtrt <= rtrt;
              m_rt   <= f_rt;  m_tr <= f_tr;
              m_sa   <= f_sa;  m_wc <= f_wc;
              m2_rt  <= f2_rt; m2_sa <= f2_sa;
              if f_sa = "00000" or f_sa = "11111" then
                m_mode <= '1';
              else
                m_mode <= '0';
              end if;
              if f_rt = "11111" then
                m_bcast <= '1';
              else
                m_bcast <= '0';
              end if;
              st <= S_GAP;
            end if;

          when S_GAP =>
            if idle_c >= GAP_CYCLES then
              -- numero de palabras a emitir
              v_ns := 1;
              if m_rtrt = '1' then
                v_ns := v_ns + 1;
              elsif m_mode = '1' then
                if m_tr = '0' and m_wc(4) = '1' then
                  v_ns := v_ns + 1;                   -- modo con dato (tr=0)
                end if;
              elsif m_tr = '0' then
                v_ns := v_ns + nwords(m_wc);          -- BC->RT
              end if;
              n_send  <= v_ns - 1;                    -- pendientes tras cmd1
              sendsel <= 1;
              -- datos esperados en recepcion
              if m_rtrt = '1' then
                n_exp <= nwords(m_wc);
              elsif m_mode = '1' and m_tr = '1' and m_wc(4) = '1' then
                n_exp <= 1;
              elsif m_mode = '0' and m_tr = '1' then
                n_exp <= nwords(m_wc);
              else
                n_exp <= 0;
              end if;
              -- emitir cmd1
              wtx_start <= '1';
              wtx_wt    <= '1';
              if m_rtrt = '1' then
                wtx_data <= m_rt & '0' & m_sa & m_wc; -- cmd de recepcion (RTA)
              else
                wtx_data <= m_rt & m_tr & m_sa & m_wc;
              end if;
              ok_r <= '0'; tout_r <= '0'; serr_r <= '0'; me_r <= '0';
              st <= S_SEND;
            end if;

          when S_SEND =>
            if wtx_loaded = '1' and n_send > 0 then
              wtx_start <= '1';
              if m_rtrt = '1' and sendsel = 1 then
                wtx_wt   <= '1';
                wtx_data <= m2_rt & '1' & m2_sa & m_wc;  -- cmd de transmision (RTB)
              else
                wtx_wt   <= '0';
                wtx_data <= tx_wdat;
                tx_rd    <= '1';
              end if;
              sendsel <= sendsel + 1;
              n_send  <= n_send - 1;
            end if;
            -- fin de emision: caida de tx_en sin nada pendiente
            if txen_d = '1' and txen_i = '0' and n_send = 0
               and wtx_busy = '0' then
              if m_bcast = '1' then
                ok_r <= '1';
                st   <= S_FIN;
              else
                tmo    <= 0;
                rx_cnt <= 0;
                st     <= S_WST1;
              end if;
            end if;

          when S_WST1 =>
            if wrx_busy = '1' then
              tmo <= 0;                               -- la respuesta ya empezo
            else
              tmo <= tmo + 1;
            end if;
            if m_rtrt = '1' then
              v_exp_addr := m2_rt;                    -- primero responde el transmisor
            else
              v_exp_addr := m_rt;
            end if;
            if v_cmd then
              stat1 <= wrx_data;
              if wrx_data(15 downto 11) /= v_exp_addr then
                serr_r <= '1';
                st     <= S_FIN;
              else
                if wrx_data(10) = '1' then
                  me_r <= '1';
                end if;
                if n_exp > 0 then
                  tmo    <= 0;
                  rx_cnt <= 0;
                  st     <= S_RXD;
                else
                  ok_r <= '1';
                  st   <= S_FIN;
                end if;
              end if;
            elsif v_dat then
              serr_r <= '1';
              st     <= S_FIN;
            elsif tmo >= TOUT_CYCLES then
              tout_r <= '1';
              st     <= S_FIN;
            end if;

          when S_RXD =>
            tmo <= tmo + 1;
            if v_dat then
              tmo     <= 0;
              rx_we   <= '1';
              rx_wdat <= wrx_data;
              if rx_cnt + 1 = n_exp then
                if m_rtrt = '1' then
                  tmo <= 0;
                  st  <= S_WST2;
                else
                  ok_r <= '1';
                  st   <= S_FIN;
                end if;
              else
                rx_cnt <= rx_cnt + 1;
              end if;
            elsif v_cmd then
              serr_r <= '1';
              st     <= S_FIN;
            elsif v_err then
              serr_r <= '1';
              st     <= S_FIN;
            elsif tmo >= DATA_TOUT then
              tout_r <= '1';
              st     <= S_FIN;
            end if;

          when S_WST2 =>                              -- status del RT receptor
            if wrx_busy = '1' then
              tmo <= 0;
            else
              tmo <= tmo + 1;
            end if;
            if v_cmd then
              stat2 <= wrx_data;
              if wrx_data(15 downto 11) /= m_rt then
                serr_r <= '1';
              else
                if wrx_data(10) = '1' then
                  me_r <= '1';
                end if;
                ok_r <= '1';
              end if;
              st <= S_FIN;
            elsif v_dat then
              serr_r <= '1';
              st     <= S_FIN;
            elsif tmo >= TOUT_CYCLES then
              tout_r <= '1';
              st     <= S_FIN;
            end if;

          when S_FIN =>
            done <= '1';
            st   <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
