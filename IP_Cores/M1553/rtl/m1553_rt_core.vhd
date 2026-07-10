-- m1553_rt_core.vhd
-- Remote Terminal MIL-STD-1553B sobre los motores de palabra.
-- Formatos: BC->RT (recibe N datos, responde status), RT->BC (responde
-- status + N datos encadenados sin hueco), RT->RT (lado receptor: acepta el
-- par de commands, salta el status del RT transmisor, captura los datos y
-- responde), mode codes (00001 Synchronize, 00010 Transmit Status Word,
-- 10001 Synchronize con dato; los no soportados responden con Message Error)
-- y broadcast (direccion 31: acepta, pone Broadcast Received, JAMAS responde).
-- Temporizacion de respuesta: mid-parity -> mid-sync = RESP_DELAY + 175
-- ciclos (RESP_DELAY=425 -> 6 us, dentro de la ventana 4-12 us).
-- Ante mensaje invalido (paridad/Manchester/cuenta/timeout): silencio + ME.
-- ME y BCR se limpian al aceptar un command valido nuevo, salvo Transmit
-- Status Word, que preserva ambos. El RX propio se enmascara mientras se
-- transmite. EN=0 mantiene todo en reset sincrono. El RT jamas transmite
-- espontaneamente.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m1553_rt_core is
  generic (
    RESP_DELAY : integer := 425;   -- valid del ultimo word RX -> start del status
    RX_TIMEOUT : integer := 2500;  -- espera de data word contigua (ciclos)
    ST_TIMEOUT : integer := 1800   -- espera del status del RT transmisor (RT->RT)
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                       -- sincrono, activo alto
    en       : in  std_logic;
    rt_addr  : in  std_logic_vector(4 downto 0);
    -- fuente de datos TX (FWFT: tx_wdat valido antes del pop)
    tx_rd    : out std_logic;
    tx_wdat  : in  std_logic_vector(15 downto 0);
    -- sumidero de datos RX
    rx_we    : out std_logic;
    rx_wdat  : out std_logic_vector(15 downto 0);
    rx_sa    : out std_logic_vector(4 downto 0);
    rx_bcast : out std_logic;
    -- eventos y diagnostico
    ev_cmd   : out std_logic;                       -- command valido aceptado
    ev_ok    : out std_logic;                       -- mensaje completado
    ev_err   : out std_logic;                       -- mensaje abortado
    dbg_me   : out std_logic;
    dbg_bcr  : out std_logic;
    -- bus
    bus_rx   : in  std_logic;
    bus_tx   : out std_logic;
    bus_txen : out std_logic
  );
end entity m1553_rt_core;

architecture rtl of m1553_rt_core is

  type t_st is (S_IDLE, S_RXD, S_RRST, S_RRD, S_RESP, S_SEND);
  signal st : t_st := S_IDLE;

  signal rstc : std_logic;

  -- motor RX
  signal rx_g       : std_logic;
  signal wrx_valid  : std_logic;
  signal wrx_type   : std_logic;
  signal wrx_data   : std_logic_vector(15 downto 0);
  signal wrx_esync, wrx_emanch, wrx_epar, wrx_busy : std_logic;

  -- motor TX
  signal wtx_start, wtx_wt, wtx_loaded, wtx_busy : std_logic;
  signal wtx_data   : std_logic_vector(15 downto 0);
  signal txen_i     : std_logic;

  -- mensaje en curso
  signal sa_r    : std_logic_vector(4 downto 0) := (others => '0');
  signal bcast_r : std_logic := '0';
  signal drop_r  : std_logic := '0';
  signal wc_n    : integer range 0 to 32 := 0;
  signal rx_cnt  : integer range 0 to 32 := 0;
  signal n_left  : integer range 0 to 32 := 0;
  signal rtrt_src: std_logic_vector(4 downto 0) := (others => '0');
  signal tmo     : integer range 0 to 4095 := 0;
  signal rcnt    : integer range 0 to 4095 := 0;
  signal guard   : integer range 0 to 7 := 0;

  -- flags de status
  signal me_f, bcr_f : std_logic := '0';

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

  -- enmascarar el propio TX en la entrada RX
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
  dbg_me   <= me_f;
  dbg_bcr  <= bcr_f;

  fsm : process(clk)
    variable v_cmd, v_dat, v_err : boolean;
    variable v_addr : std_logic_vector(4 downto 0);
    variable v_tr   : std_logic;
    variable v_sa   : std_logic_vector(4 downto 0);
    variable v_wc   : std_logic_vector(4 downto 0);
    variable v_mine, v_bc, v_mode : boolean;
    variable v_bcb  : std_logic;

    -- decodifica un command valido dirigido (o no) a este RT;
    -- asigna senales directamente (procedimiento local del proceso)
    procedure decode is
    begin
      if v_mine or v_bc then
        ev_cmd  <= '1';
        sa_r    <= v_sa;
        bcast_r <= v_bcb;
        drop_r  <= '0';
        if v_mode then
          if v_tr = '1' then
            if v_wc = "00010" then                    -- Transmit Status Word
              if v_bc then
                null;                                 -- broadcast+TxStatus: ilegal, silencio
              else
                n_left <= 0;                          -- ME/BCR PRESERVADOS
                rcnt   <= 0;
                st     <= S_RESP;
              end if;
            elsif v_wc = "00001" then                 -- Synchronize sin dato
              me_f  <= '0';
              bcr_f <= v_bcb;
              if v_bc then
                ev_ok <= '1';                         -- broadcast: sin respuesta
                st    <= S_IDLE;
              else
                n_left <= 0;
                rcnt   <= 0;
                st     <= S_RESP;
              end if;
            else                                      -- tr=1 no soportado
              if v_bc then
                null;                                 -- silencio
              else
                me_f  <= '1';                         -- illegal command: ME
                bcr_f <= '0';
                n_left <= 0;
                rcnt  <= 0;
                st    <= S_RESP;
              end if;
            end if;
          else                                        -- modo tr=0
            if v_wc = "10001" then                    -- Synchronize con dato
              me_f   <= '0';
              bcr_f  <= v_bcb;
              wc_n   <= 1;
              rx_cnt <= 0;
              tmo    <= 0;
              st     <= S_RXD;
            else                                      -- tr=0 no soportado
              me_f  <= '1';
              bcr_f <= '0';
              if v_wc(4) = '1' then                   -- trae dato: consumirlo
                drop_r <= '1';
                wc_n   <= 1;
                rx_cnt <= 0;
                tmo    <= 0;
                st     <= S_RXD;
              elsif v_bc then
                st <= S_IDLE;                         -- silencio
              else
                n_left <= 0;
                rcnt   <= 0;
                st     <= S_RESP;
              end if;
            end if;
          end if;
        else
          if v_tr = '0' then                          -- BC->RT (o broadcast)
            me_f   <= '0';
            bcr_f  <= v_bcb;
            wc_n   <= nwords(v_wc);
            rx_cnt <= 0;
            tmo    <= 0;
            st     <= S_RXD;
          else                                        -- RT->BC (transmision)
            if v_bc then
              null;                                   -- broadcast+transmit: ilegal
            else
              me_f   <= '0';
              bcr_f  <= '0';
              n_left <= nwords(v_wc);
              rcnt   <= 0;
              st     <= S_RESP;
            end if;
          end if;
        end if;
      end if;
    end procedure;

  begin
    if rising_edge(clk) then
      if rstc = '1' then
        st <= S_IDLE;
        me_f <= '0'; bcr_f <= '0';
        wtx_start <= '0'; tx_rd <= '0'; rx_we <= '0';
        ev_cmd <= '0'; ev_ok <= '0'; ev_err <= '0';
        tmo <= 0; rcnt <= 0; guard <= 0;
      else
        -- pulsos por defecto
        wtx_start <= '0';
        tx_rd     <= '0';
        rx_we     <= '0';
        ev_cmd    <= '0';
        ev_ok     <= '0';
        ev_err    <= '0';

        v_cmd  := (wrx_valid = '1') and (wrx_type = '1');
        v_dat  := (wrx_valid = '1') and (wrx_type = '0');
        v_err  := (wrx_esync = '1') or (wrx_emanch = '1') or (wrx_epar = '1');
        v_addr := wrx_data(15 downto 11);
        v_tr   := wrx_data(10);
        v_sa   := wrx_data(9 downto 5);
        v_wc   := wrx_data(4 downto 0);
        v_mine := (v_addr = rt_addr);
        v_bc   := (v_addr = "11111");
        v_mode := (v_sa = "00000") or (v_sa = "11111");
        if v_bc then v_bcb := '1'; else v_bcb := '0'; end if;

        case st is

          when S_IDLE =>
            if v_cmd then
              decode;
            end if;
            -- data words y errores en reposo: se ignoran

          when S_RXD =>
            tmo <= tmo + 1;
            if v_dat then
              tmo <= 0;
              if drop_r = '0' then
                rx_we    <= '1';
                rx_wdat  <= wrx_data;
                rx_sa    <= sa_r;
                rx_bcast <= bcast_r;
              end if;
              if rx_cnt + 1 = wc_n then
                if drop_r = '1' then                  -- modo no soportado con dato
                  if bcast_r = '1' then
                    st <= S_IDLE;                     -- silencio
                  else
                    rcnt <= 0;
                    st   <= S_RESP;                   -- responde con ME
                  end if;
                elsif bcast_r = '1' then
                  ev_ok <= '1';                       -- broadcast: sin respuesta
                  st    <= S_IDLE;
                else
                  rcnt   <= 0;
                  n_left <= 0;
                  st     <= S_RESP;
                end if;
              else
                rx_cnt <= rx_cnt + 1;
              end if;
            elsif v_cmd then
              if rx_cnt = 0 and v_tr = '1' and (not v_mine) and (not v_bc)
                 and (not v_mode) then
                rtrt_src <= v_addr;                   -- RT->RT: cmd de transmision
                tmo      <= 0;
                st       <= S_RRST;
              else
                decode;                               -- command superpuesto
              end if;
            elsif v_err then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            elsif tmo >= RX_TIMEOUT then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            end if;

          when S_RRST =>                              -- espera status del transmisor
            if wrx_busy = '1' then
              tmo <= 0;                               -- el status ya esta en el aire
            else
              tmo <= tmo + 1;
            end if;
            if v_cmd then
              if v_addr = rtrt_src then
                rx_cnt <= 0;
                tmo    <= 0;
                st     <= S_RRD;
              elsif v_mine or v_bc then
                decode;
              end if;
            elsif v_err then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            elsif tmo >= ST_TIMEOUT then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            end if;

          when S_RRD =>                               -- datos del RT transmisor
            tmo <= tmo + 1;
            if v_dat then
              tmo      <= 0;
              rx_we    <= '1';
              rx_wdat  <= wrx_data;
              rx_sa    <= sa_r;
              rx_bcast <= bcast_r;
              if rx_cnt + 1 = wc_n then
                if bcast_r = '1' then
                  ev_ok <= '1';
                  st    <= S_IDLE;
                else
                  rcnt   <= 0;
                  n_left <= 0;
                  st     <= S_RESP;
                end if;
              else
                rx_cnt <= rx_cnt + 1;
              end if;
            elsif v_cmd then
              decode;
            elsif v_err then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            elsif tmo >= RX_TIMEOUT then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            end if;

          when S_RESP =>
            if rcnt = RESP_DELAY then
              wtx_start <= '1';
              wtx_wt    <= '1';                       -- sync de command/status
              wtx_data  <= rt_addr & me_f & "00" & "000" & bcr_f & "0000";
              guard     <= 0;
              st        <= S_SEND;
            else
              rcnt <= rcnt + 1;
            end if;

          when S_SEND =>
            if guard < 7 then
              guard <= guard + 1;
            end if;
            if wtx_loaded = '1' and n_left > 0 then
              wtx_start <= '1';
              wtx_wt    <= '0';                       -- data word
              wtx_data  <= tx_wdat;
              tx_rd     <= '1';
              n_left    <= n_left - 1;
            end if;
            if guard >= 3 and wtx_busy = '0' then
              ev_ok <= '1';
              st    <= S_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
