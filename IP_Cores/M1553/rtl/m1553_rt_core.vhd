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
--
-- Audit 2026-11:
--  * Dual-redundant bus (A/B): one word receiver per bus, always listening
--    (each masked only while this RT transmits on THAT bus). The RT answers
--    on the bus the command came from (cur_bus). A valid command for this RT
--    (or broadcast) received on the OTHER bus while a message is in progress
--    SUPERSEDES it: an ongoing response is cut immediately (word TX abort)
--    and the new command is processed on the new bus.
--  * Response gap guard: in S_RESP any activity on the current bus (receiver
--    busy, data word, or word error) before the status starts aborts the
--    message silently with ME (e.g. word count high).
--  * Illegal broadcast commands that are not acted on (broadcast + transmit,
--    broadcast Transmit Status, broadcast unsupported tr=1 mode codes) go to
--    S_IDLE without touching sa_r / bcast_r and without ev_cmd.
--  * TX underflow: a response that needs data from an empty TX FIFO is not
--    started (silence + ME); an underflow in the middle of a response stops
--    it after the word in flight (silence + ME). ev_uflow pulses.
--  * Status bits Busy (b3), Subsystem Flag (b2) and Terminal Flag (b0) come
--    from st_busy / st_ssf / st_tf. With Busy set the RT answers transmit
--    commands with the status word only and does not store received data
--    (non mode-code transfers), as required for the Busy bit.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m1553_rt_core is
  generic (
    RESP_DELAY : integer := 425;   -- valid del ultimo word RX -> start del status
    RX_TIMEOUT : integer := 2500;  -- espera de data word contigua (ciclos)
    ST_TIMEOUT : integer := 1800;  -- espera del status del RT transmisor (RT->RT)
    FS_TIMEOUT : integer := 80000  -- fail-safe transmitter timer (cycles)
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                       -- sincrono, activo alto
    en       : in  std_logic;
    rt_addr  : in  std_logic_vector(4 downto 0);
    -- status-word flags driven by the subsystem (MMIO)
    st_busy  : in  std_logic := '0';
    st_ssf   : in  std_logic := '0';
    st_tf    : in  std_logic := '0';
    -- fuente de datos TX (FWFT: tx_wdat valido antes del pop)
    tx_rd    : out std_logic;
    tx_wdat  : in  std_logic_vector(15 downto 0);
    tx_empty : in  std_logic;
    -- sumidero de datos RX
    rx_we    : out std_logic;
    rx_wdat  : out std_logic_vector(15 downto 0);
    rx_sa    : out std_logic_vector(4 downto 0);
    rx_bcast : out std_logic;
    -- eventos y diagnostico
    ev_cmd   : out std_logic;                       -- command valido aceptado
    ev_ok    : out std_logic;                       -- mensaje completado
    ev_err   : out std_logic;                       -- mensaje abortado
    ev_uflow : out std_logic;                       -- TX FIFO underflow
    dbg_me   : out std_logic;
    dbg_bcr  : out std_logic;
    cur_bus  : out std_logic;                       -- '0' A, '1' B (last command)
    fs_fault : out std_logic;                       -- fail-safe timer tripped
    -- dual-redundant bus
    bus_rx_a   : in  std_logic;
    bus_rx_b   : in  std_logic;
    bus_tx     : out std_logic;                     -- shared data, gated by txen
    bus_txen_a : out std_logic;
    bus_txen_b : out std_logic
  );
end entity m1553_rt_core;

architecture rtl of m1553_rt_core is

  type t_st is (S_IDLE, S_RXD, S_RRST, S_RRD, S_RESP, S_SEND);
  signal st : t_st := S_IDLE;

  signal rstc : std_logic;

  -- motores RX (bus A y bus B)
  signal rxa_g, rxb_g : std_logic;
  signal ra_valid, ra_type, ra_esync, ra_emanch, ra_epar, ra_busy : std_logic;
  signal rb_valid, rb_type, rb_esync, rb_emanch, rb_epar, rb_busy : std_logic;
  signal ra_data, rb_data : std_logic_vector(15 downto 0);

  -- motor TX (one, routed to the bus of the current message)
  signal wtx_start, wtx_wt, wtx_loaded, wtx_busy : std_logic;
  signal wtx_abort  : std_logic := '0';
  signal wtx_data   : std_logic_vector(15 downto 0);
  signal txen_i     : std_logic;
  signal cbus_r     : std_logic := '0';               -- bus of current message
  signal txbus_r    : std_logic := '0';               -- bus the TX is routed to
  signal uf_r       : std_logic := '0';               -- underflow in this response
  signal busy_r     : std_logic := '0';               -- Busy: do not store data

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

  -- enmascarar el propio TX en la entrada RX del bus por el que se emite
  rxa_g <= bus_rx_a and not (txen_i and not txbus_r);
  rxb_g <= bus_rx_b and not (txen_i and txbus_r);

  u_wrx_a : entity work.m1553_word_rx
    port map (
      clk => clk, rst => rstc, rx_data => rxa_g,
      valid => ra_valid, word_type => ra_type, data => ra_data,
      err_sync => ra_esync, err_manch => ra_emanch, err_par => ra_epar,
      busy => ra_busy);

  u_wrx_b : entity work.m1553_word_rx
    port map (
      clk => clk, rst => rstc, rx_data => rxb_g,
      valid => rb_valid, word_type => rb_type, data => rb_data,
      err_sync => rb_esync, err_manch => rb_emanch, err_par => rb_epar,
      busy => rb_busy);

  u_wtx : entity work.m1553_word_tx
    generic map (FS_TIMEOUT => FS_TIMEOUT)
    port map (
      clk => clk, rst => rstc,
      start => wtx_start, word_type => wtx_wt, data => wtx_data,
      busy => wtx_busy, loaded => wtx_loaded,
      abort => wtx_abort, fs_fault => fs_fault,
      tx_en => txen_i, tx_data => bus_tx);

  bus_txen_a <= txen_i and not txbus_r;
  bus_txen_b <= txen_i and txbus_r;
  dbg_me   <= me_f;
  dbg_bcr  <= bcr_f;
  cur_bus  <= cbus_r;

  fsm : process(clk)
    variable v_cmd, v_dat, v_err : boolean;
    variable wrx_valid, wrx_type, wrx_busy : std_logic;
    variable wrx_data : std_logic_vector(15 downto 0);
    variable v_sel  : std_logic;                    -- bus whose events are used
    variable v_sup  : boolean;                      -- superseding command
    variable v_ign  : boolean;                      -- illegal broadcast: ignore
    variable v_oaddr : std_logic_vector(4 downto 0);
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
      -- broadcast commands that are not acted on (illegal): no ev_cmd, no
      -- change of sa_r / bcast_r, back to S_IDLE
      v_ign := v_bc and v_tr = '1' and not (v_mode and v_wc = "00001");
      if v_ign then
        st <= S_IDLE;
      elsif v_mine or v_bc then
        ev_cmd  <= '1';
        sa_r    <= v_sa;
        bcast_r <= v_bcb;
        drop_r  <= '0';
        busy_r  <= '0';
        cbus_r  <= v_sel;
        if v_mode then
          if v_tr = '1' then
            if v_wc = "00010" then                    -- Transmit Status Word
              n_left <= 0;                            -- ME/BCR PRESERVADOS
              rcnt   <= 0;                            -- (broadcast: v_ign)
              st     <= S_RESP;
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
              me_f  <= '1';                           -- illegal command: ME
              bcr_f <= '0';                           -- (broadcast: v_ign)
              n_left <= 0;
              rcnt  <= 0;
              st    <= S_RESP;
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
            busy_r <= st_busy;                        -- Busy: do not store
            wc_n   <= nwords(v_wc);
            rx_cnt <= 0;
            tmo    <= 0;
            st     <= S_RXD;
          else                                        -- RT->BC (broadcast: v_ign)
            me_f   <= '0';
            bcr_f  <= '0';
            if st_busy = '1' then
              n_left <= 0;                            -- Busy: status only
            else
              n_left <= nwords(v_wc);
            end if;
            rcnt   <= 0;
            st     <= S_RESP;
          end if;
        end if;
      end if;
    end procedure;

  begin
    if rising_edge(clk) then
      if rstc = '1' then
        st <= S_IDLE;
        me_f <= '0'; bcr_f <= '0';
        wtx_start <= '0'; tx_rd <= '0'; rx_we <= '0'; wtx_abort <= '0';
        ev_cmd <= '0'; ev_ok <= '0'; ev_err <= '0'; ev_uflow <= '0';
        tmo <= 0; rcnt <= 0; guard <= 0;
        cbus_r <= '0'; txbus_r <= '0'; uf_r <= '0'; busy_r <= '0';
        drop_r <= '0'; bcast_r <= '0'; n_left <= 0;
      else
        -- pulsos por defecto
        wtx_start <= '0';
        wtx_abort <= '0';
        tx_rd     <= '0';
        rx_we     <= '0';
        ev_cmd    <= '0';
        ev_ok     <= '0';
        ev_err    <= '0';
        ev_uflow  <= '0';

        -- bus selection: in S_IDLE a valid word on either bus (A first);
        -- otherwise the current message's bus, unless the OTHER bus brings a
        -- valid command for this RT (or broadcast): superseding command
        v_sup := false;
        if cbus_r = '0' then
          v_oaddr := rb_data(15 downto 11);
        else
          v_oaddr := ra_data(15 downto 11);
        end if;
        if st = S_IDLE then
          if ra_valid = '1' then
            v_sel := '0';
          elsif rb_valid = '1' then
            v_sel := '1';
          else
            v_sel := cbus_r;
          end if;
        elsif ((cbus_r = '0' and rb_valid = '1' and rb_type = '1') or
               (cbus_r = '1' and ra_valid = '1' and ra_type = '1')) and
              (v_oaddr = rt_addr or v_oaddr = "11111") then
          v_sel := not cbus_r;
          v_sup := true;
        else
          v_sel := cbus_r;
        end if;
        if v_sel = '0' then
          wrx_valid := ra_valid; wrx_type := ra_type; wrx_data := ra_data;
          wrx_busy  := ra_busy;
          v_err := (ra_esync = '1') or (ra_emanch = '1') or (ra_epar = '1');
        else
          wrx_valid := rb_valid; wrx_type := rb_type; wrx_data := rb_data;
          wrx_busy  := rb_busy;
          v_err := (rb_esync = '1') or (rb_emanch = '1') or (rb_epar = '1');
        end if;

        v_cmd  := (wrx_valid = '1') and (wrx_type = '1');
        v_dat  := (wrx_valid = '1') and (wrx_type = '0');
        v_addr := wrx_data(15 downto 11);
        v_tr   := wrx_data(10);
        v_sa   := wrx_data(9 downto 5);
        v_wc   := wrx_data(4 downto 0);
        v_mine := (v_addr = rt_addr);
        v_bc   := (v_addr = "11111");
        v_mode := (v_sa = "00000") or (v_sa = "11111");
        if v_bc then v_bcb := '1'; else v_bcb := '0'; end if;

        if v_sup then
          -- superseding command on the other bus: cut any response now
          wtx_abort <= '1';
          uf_r      <= '0';
          decode;
        else
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
              if drop_r = '0' and busy_r = '0' then
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
            -- the timeout is deferred while a word is being received, but
            -- only by one word time (continuous garbage cannot hold it off)
            if tmo < 4095 then
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
            elsif (tmo >= ST_TIMEOUT and wrx_busy = '0') or
                  tmo >= ST_TIMEOUT + 2100 then
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            end if;

          when S_RRD =>                               -- datos del RT transmisor
            tmo <= tmo + 1;
            if v_dat then
              tmo      <= 0;
              rx_we    <= not busy_r;
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
            if wrx_busy = '1' or v_dat or v_err then
              -- bus activity before our status (e.g. word count high):
              -- invalid message, no response, ME
              ev_err <= '1';
              me_f   <= '1';
              st     <= S_IDLE;
            elsif v_cmd then
              decode;                                 -- (busy precedes valid)
            elsif rcnt = RESP_DELAY then
              txbus_r <= cbus_r;                      -- answer on the command bus
              uf_r    <= '0';
              if n_left > 0 and tx_empty = '1' then
                -- no data to send: silence + ME
                me_f     <= '1';
                ev_err   <= '1';
                ev_uflow <= '1';
                st       <= S_IDLE;
              else
                wtx_start <= '1';
                wtx_wt    <= '1';                     -- sync de command/status
                -- b10 ME, b4 BCR, b3 Busy, b2 Subsystem Flag, b0 Terminal Flag
                wtx_data  <= rt_addr & me_f & "00" & "000" & bcr_f
                             & st_busy & st_ssf & '0' & st_tf;
                guard     <= 0;
                st        <= S_SEND;
              end if;
            else
              rcnt <= rcnt + 1;
            end if;

          when S_SEND =>
            if guard < 7 then
              guard <= guard + 1;
            end if;
            if wtx_loaded = '1' and n_left > 0 then
              if tx_empty = '1' then
                -- underflow mid-response: stop after the word in flight
                n_left   <= 0;
                uf_r     <= '1';
                me_f     <= '1';
                ev_uflow <= '1';
              else
                wtx_start <= '1';
                wtx_wt    <= '0';                     -- data word
                wtx_data  <= tx_wdat;
                tx_rd     <= '1';
                n_left    <= n_left - 1;
              end if;
            end if;
            if guard >= 3 and wtx_busy = '0' then
              if uf_r = '1' then
                ev_err <= '1';
              else
                ev_ok  <= '1';
              end if;
              st    <= S_IDLE;
            end if;

        end case;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
