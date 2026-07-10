-- ============================================================================
-- spw_link.vhd -- Maquina de estados del enlace SpaceWire (ECSS-E-ST-50-12C 8.5)
-- ============================================================================
-- Estados: ErrorReset -> ErrorWait -> Ready -> Started -> Connecting -> Run
--   ErrorReset : TX y RX en reset. Tras 6.4 us -> ErrorWait.
--   ErrorWait  : RX habilitado. Tras 12.8 us -> Ready. Cualquier error o
--                recepcion de FCT/N-Char/Time-Code -> ErrorReset.
--   Ready      : espera [enlace habilitado] = link_start OR
--                (link_autostart AND gotNULL). Errores/chars -> ErrorReset.
--   Started    : TX emite NULLs. gotNULL -> Connecting.
--                Timeout 12.8 us o errores/chars -> ErrorReset.
--   Connecting : TX emite NULLs + FCTs. gotFCT -> Run (credito inicial 8).
--                Timeout 12.8 us, errores o N-Char/Time -> ErrorReset.
--   Run        : todo permitido. Errores (paridad, escape, desconexion,
--                credito) -> ErrorReset.
--
-- Creditos (una FCT = 8 N-Chars, maximo 56):
--   credit : lo que el companero nos ha concedido. +8 por FCT recibida
--            (si supera 56 -> error de credito), -1 por N-Char emitido (d_ack).
--   outst  : lo que nosotros hemos concedido y aun no ha llegado. +8 por FCT
--            emitida (fct_ack), -1 por N-Char recibido; N-Char con outst=0
--            -> error de credito.
--   fct_req: se solicita FCT cuando outst <= 48 y el espacio aguas abajo
--            (rx_room) cubre outst + 8.
--
-- en='0' o link_disable='1' fuerzan ErrorReset.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_link is
  generic (
    T64_CYCLES  : integer := 640;      -- 6.4 us a 100 MHz
    T128_CYCLES : integer := 1280      -- 12.8 us a 100 MHz
  );
  port (
    clk            : in  std_logic;
    arstn          : in  std_logic;
    en             : in  std_logic;
    link_start     : in  std_logic;
    link_autostart : in  std_logic;
    link_disable   : in  std_logic;
    -- desde el RX
    first_null     : in  std_logic;
    got_fct        : in  std_logic;
    got_nchar      : in  std_logic;    -- rx_we del RX
    got_time       : in  std_logic;
    rx_err_par     : in  std_logic;
    rx_err_esc     : in  std_logic;
    rx_err_disc    : in  std_logic;
    rx_room        : in  std_logic_vector(6 downto 0);
    -- hacia el TX
    txen           : out std_logic;
    allow_fct      : out std_logic;
    allow_nchar    : out std_logic;
    fct_req        : out std_logic;
    fct_ack        : in  std_logic;
    credit_ok      : out std_logic;
    d_ack          : in  std_logic;
    -- hacia el RX
    rxen           : out std_logic;
    -- estado y errores
    state          : out std_logic_vector(2 downto 0);
    err_credit     : out std_logic
  );
end entity spw_link;

architecture rtl of spw_link is

  type st_t is (S_ERST, S_EWAIT, S_READY, S_STARTED, S_CONN, S_RUN);

  signal st     : st_t := S_ERST;
  signal timer  : integer range 0 to 65535 := 0;
  signal credit : unsigned(5 downto 0) := (others => '0');
  signal outst  : unsigned(5 downto 0) := (others => '0');
  signal errc_r : std_logic := '0';

begin

  with st select state <=
    "000" when S_ERST,
    "001" when S_EWAIT,
    "010" when S_READY,
    "011" when S_STARTED,
    "100" when S_CONN,
    "101" when S_RUN;

  rxen        <= '0' when st = S_ERST else '1';
  txen        <= '1' when st = S_STARTED or st = S_CONN or st = S_RUN else '0';
  allow_fct   <= '1' when st = S_CONN or st = S_RUN else '0';
  allow_nchar <= '1' when st = S_RUN else '0';
  credit_ok   <= '1' when credit /= 0 else '0';
  err_credit  <= errc_r;

  fct_req <= '1' when (st = S_CONN or st = S_RUN)
                  and outst <= 48
                  and unsigned(rx_room) >= resize(outst, 7) + 8
             else '0';

  main : process (clk, arstn)
    variable any_err  : boolean;
    variable any_char : boolean;
    variable to_erst  : boolean;
    variable v_credit : unsigned(6 downto 0);
    variable v_outst  : unsigned(6 downto 0);
  begin
    if arstn = '0' then
      st     <= S_ERST;
      timer  <= 0;
      credit <= (others => '0');
      outst  <= (others => '0');
      errc_r <= '0';
    elsif rising_edge(clk) then
      errc_r <= '0';

      if en = '0' or link_disable = '1' then
        st     <= S_ERST;
        timer  <= 0;
        credit <= (others => '0');
        outst  <= (others => '0');
      else
        any_err  := (rx_err_par = '1') or (rx_err_esc = '1') or (rx_err_disc = '1');
        any_char := (got_fct = '1') or (got_nchar = '1') or (got_time = '1');
        to_erst  := false;

        case st is

          when S_ERST =>
            credit <= (others => '0');
            outst  <= (others => '0');
            if timer >= T64_CYCLES - 1 then
              st    <= S_EWAIT;
              timer <= 0;
            else
              timer <= timer + 1;
            end if;

          when S_EWAIT =>
            if any_err or any_char then
              to_erst := true;
            elsif timer >= T128_CYCLES - 1 then
              st    <= S_READY;
              timer <= 0;
            else
              timer <= timer + 1;
            end if;

          when S_READY =>
            if any_err or any_char then
              to_erst := true;
            elsif link_start = '1'
               or (link_autostart = '1' and first_null = '1') then
              st    <= S_STARTED;
              timer <= 0;
            end if;

          when S_STARTED =>
            if any_err or any_char then
              to_erst := true;
            elsif first_null = '1' then
              st    <= S_CONN;
              timer <= 0;
            elsif timer >= T128_CYCLES - 1 then
              to_erst := true;
            else
              timer <= timer + 1;
            end if;

          when S_CONN =>
            if any_err or got_nchar = '1' or got_time = '1' then
              to_erst := true;
            else
              if fct_ack = '1' then
                outst <= outst + 8;
              end if;
              if got_fct = '1' then
                st     <= S_RUN;
                timer  <= 0;
                credit <= to_unsigned(8, 6);
              elsif timer >= T128_CYCLES - 1 then
                to_erst := true;
              else
                timer <= timer + 1;
              end if;
            end if;

          when S_RUN =>
            if any_err then
              to_erst := true;
            else
              v_credit := resize(credit, 7);
              v_outst  := resize(outst, 7);
              if got_fct = '1' then
                v_credit := v_credit + 8;
              end if;
              if d_ack = '1' then
                v_credit := v_credit - 1;
              end if;
              if fct_ack = '1' then
                v_outst := v_outst + 8;
              end if;
              if got_nchar = '1' then
                if v_outst = 0 then
                  errc_r  <= '1';
                  to_erst := true;
                else
                  v_outst := v_outst - 1;
                end if;
              end if;
              if v_credit > 56 then
                errc_r  <= '1';
                to_erst := true;
              end if;
              if not to_erst then
                credit <= v_credit(5 downto 0);
                outst  <= v_outst(5 downto 0);
              end if;
            end if;

        end case;

        if to_erst then
          st     <= S_ERST;
          timer  <= 0;
          credit <= (others => '0');
          outst  <= (others => '0');
        end if;
      end if;
    end if;
  end process main;

end architecture rtl;
