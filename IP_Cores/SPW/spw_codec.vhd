-- ============================================================================
-- spw_codec.vhd -- Codec SpaceWire completo: spw_tx + spw_rx + spw_link
-- ============================================================================
-- Interfaz de usuario (hacia los FIFOs FWFT del MMIO en la siguiente capa):
--   tx_valid/tx_data/tx_ack : N-Chars a emitir (b8='1': b0='0' EOP, '1' EEP).
--                             El codec solo consume con credito disponible y
--                             en estado Run.
--   rx_we/rx_data           : N-Chars recibidos, mismo formato de 9 bits.
--   rx_room                 : espacio libre aguas abajo en N-Chars; gobierna
--                             la emision de FCTs (control de flujo).
--   tick_in/time_in         : pulso + valor -> emite Time-Code (en Run).
--   tick_out/time_out       : pulso + valor por Time-Code recibido.
--   state                   : 0 ErrorReset, 1 ErrorWait, 2 Ready, 3 Started,
--                             4 Connecting, 5 Run.
--   err_*                   : pulsos de 1 ciclo (stickies en el MMIO).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_codec is
  generic (
    DISC_CYCLES : integer := 85;
    T64_CYCLES  : integer := 640;
    T128_CYCLES : integer := 1280
  );
  port (
    clk            : in  std_logic;
    arstn          : in  std_logic;
    en             : in  std_logic;
    div            : in  std_logic_vector(7 downto 0);
    link_start     : in  std_logic;
    link_autostart : in  std_logic;
    link_disable   : in  std_logic;
    -- time-codes
    tick_in        : in  std_logic;
    time_in        : in  std_logic_vector(7 downto 0);
    tick_out       : out std_logic;
    time_out       : out std_logic_vector(7 downto 0);
    -- datos
    tx_valid       : in  std_logic;
    tx_data        : in  std_logic_vector(8 downto 0);
    tx_ack         : out std_logic;
    rx_we          : out std_logic;
    rx_data        : out std_logic_vector(8 downto 0);
    rx_room        : in  std_logic_vector(6 downto 0);
    -- estado y errores
    state          : out std_logic_vector(2 downto 0);
    err_par        : out std_logic;
    err_esc        : out std_logic;
    err_disc       : out std_logic;
    err_credit     : out std_logic;
    -- enlace fisico
    din            : in  std_logic;
    sin            : in  std_logic;
    dout           : out std_logic;
    sout           : out std_logic
  );
end entity spw_codec;

architecture rtl of spw_codec is

  signal txen_i, allow_fct_i, allow_nchar_i : std_logic;
  signal rxen_i                             : std_logic;
  signal fct_req_i, fct_ack_i               : std_logic;
  signal credit_ok_i                        : std_logic;
  signal d_valid_i, d_ack_i                 : std_logic;
  signal time_req_i, time_ack_i             : std_logic;
  signal time_lat                           : std_logic_vector(7 downto 0);
  signal first_null_i                       : std_logic;
  signal got_null_i, got_fct_i, got_time_i  : std_logic;
  signal rx_we_i                            : std_logic;
  signal rx_data_i                          : std_logic_vector(8 downto 0);
  signal time_out_i                         : std_logic_vector(7 downto 0);
  signal e_par, e_esc, e_disc               : std_logic;

begin

  -- el TX solo consume N-Chars con credito del companero
  d_valid_i <= tx_valid and credit_ok_i;
  tx_ack    <= d_ack_i;

  rx_we    <= rx_we_i;
  rx_data  <= rx_data_i;
  tick_out <= got_time_i;
  time_out <= time_out_i;

  err_par  <= e_par;
  err_esc  <= e_esc;
  err_disc <= e_disc;

  -- latch de peticion de time-code
  time_latch : process (clk, arstn)
  begin
    if arstn = '0' then
      time_req_i <= '0';
      time_lat   <= (others => '0');
    elsif rising_edge(clk) then
      if en = '0' then
        time_req_i <= '0';
      elsif tick_in = '1' then
        time_lat   <= time_in;
        time_req_i <= '1';
      elsif time_ack_i = '1' then
        time_req_i <= '0';
      end if;
    end if;
  end process time_latch;

  u_tx : entity work.spw_tx
    port map (
      clk         => clk,
      arstn       => arstn,
      en          => en,
      div         => div,
      txen        => txen_i,
      allow_fct   => allow_fct_i,
      allow_nchar => allow_nchar_i,
      fct_req     => fct_req_i,
      fct_ack     => fct_ack_i,
      time_req    => time_req_i,
      time_val    => time_lat,
      time_ack    => time_ack_i,
      d_valid     => d_valid_i,
      d_data      => tx_data,
      d_ack       => d_ack_i,
      dout        => dout,
      sout        => sout
    );

  u_rx : entity work.spw_rx
    generic map (DISC_CYCLES => DISC_CYCLES)
    port map (
      clk        => clk,
      arstn      => arstn,
      en         => en,
      rxen       => rxen_i,
      din        => din,
      sin        => sin,
      first_null => first_null_i,
      got_null   => got_null_i,
      got_fct    => got_fct_i,
      got_time   => got_time_i,
      time_out   => time_out_i,
      rx_we      => rx_we_i,
      rx_data    => rx_data_i,
      err_par    => e_par,
      err_esc    => e_esc,
      err_disc   => e_disc
    );

  u_link : entity work.spw_link
    generic map (
      T64_CYCLES  => T64_CYCLES,
      T128_CYCLES => T128_CYCLES
    )
    port map (
      clk            => clk,
      arstn          => arstn,
      en             => en,
      link_start     => link_start,
      link_autostart => link_autostart,
      link_disable   => link_disable,
      first_null     => first_null_i,
      got_fct        => got_fct_i,
      got_nchar      => rx_we_i,
      got_time       => got_time_i,
      rx_err_par     => e_par,
      rx_err_esc     => e_esc,
      rx_err_disc    => e_disc,
      rx_room        => rx_room,
      txen           => txen_i,
      allow_fct      => allow_fct_i,
      allow_nchar    => allow_nchar_i,
      fct_req        => fct_req_i,
      fct_ack        => fct_ack_i,
      credit_ok      => credit_ok_i,
      d_ack          => d_ack_i,
      rxen           => rxen_i,
      state          => state,
      err_credit     => err_credit
    );

end architecture rtl;
