-- tb_ptp_rx.vhd — capa 1b del parser RX-PTP.
-- Un "transmisor bit-bang" inyecta al parser una trama Sync conocida byte a
-- byte (via rx_data/rx_valid/rx_last) y un TS de recepcion. Verifica que el
-- parser extrae messageType, sequenceId, sourcePortIdentity y originTimestamp
-- correctamente, y que empareja el TS de recepcion. Incluye casos de
-- corrupcion (EtherType malo) que NO deben producir msg_valid.
-- Asserts en espanol, severity failure.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_ptp_rx is
end entity;

architecture sim of tb_ptp_rx is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_valid, rx_last, ev_ok : std_logic := '0';
  signal rx_ts_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal rx_ts_ns  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal rx_ts_valid : std_logic := '0';
  signal rx_ts_ack : std_logic;

  signal msg_valid : std_logic;
  signal msg_type  : std_logic_vector(3 downto 0);
  signal seq_id    : std_logic_vector(15 downto 0);
  signal src_port_id : std_logic_vector(79 downto 0);
  signal origin_sec : std_logic_vector(SEC_W-1 downto 0);
  signal origin_ns  : std_logic_vector(NS_W-1 downto 0);
  signal corr_field : std_logic_vector(63 downto 0);
  signal rx_sec, dummy_sec : std_logic_vector(SEC_W-1 downto 0);
  signal rx_ns  : std_logic_vector(NS_W-1 downto 0);
  signal rd_ack : std_logic := '0';

  -- trama Sync conocida (misma que genera el TX). 58 bytes de datos.
  type darr is array (natural range <>) of std_logic_vector(7 downto 0);
  -- construida con: clockId=0011223344556677 port=0001 seq=0000
  -- origin no importa para RX (lo lleva el emisor); aqui metemos un valor.
  constant FR : darr(0 to 57) := (
    x"01",x"80",x"C2",x"00",x"00",x"0E",          -- dst
    x"02",x"DE",x"CA",x"FB",x"AD",x"ED",          -- src
    x"88",x"F7",                                  -- EtherType
    x"00",x"02",x"00",x"2C",                      -- msgType|ver, msgLength
    x"00",x"00",x"00",x"00",                      -- domain,minorSdo,flags
    x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00", -- correctionField
    x"00",x"00",x"00",x"00",                      -- messageTypeSpecific
    x"00",x"11",x"22",x"33",x"44",x"55",x"66",x"77", -- clockIdentity
    x"00",x"01",                                  -- portNumber
    x"00",x"00",                                  -- sequenceId
    x"00",x"00",                                  -- controlField, logMsgInt
    x"00",x"00",x"00",x"00",x"00",x"05",          -- originTS secondsField=5
    x"00",x"00",x"06",x"40");                     -- originTS nanoseconds=1600

begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_rx
    port map (clk => clk, rst => rst,
              rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last, ev_ok => ev_ok,
              rx_ts_sec => rx_ts_sec, rx_ts_ns => rx_ts_ns,
              rx_ts_valid => rx_ts_valid, rx_ts_ack => rx_ts_ack,
              msg_valid => msg_valid, msg_type => msg_type, seq_id => seq_id,
              src_port_id => src_port_id, origin_sec => origin_sec, origin_ns => origin_ns,
              corr_field => corr_field, rx_sec => rx_sec, rx_ns => rx_ns, rd_ack => rd_ack);

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;

    -- inyecta la trama FR (opcionalmente corrompiendo un byte)
    procedure inject(corrupt_idx : integer; corrupt_val : std_logic_vector(7 downto 0)) is
    begin
      -- primero simular el SFD: cargar el TS de recepcion
      rx_ts_sec <= std_logic_vector(to_unsigned(9, SEC_W));
      rx_ts_ns  <= std_logic_vector(to_unsigned(4242, NS_W));
      rx_ts_valid <= '1';
      for i in 0 to 57 loop
        if i = corrupt_idx then
          rx_data <= corrupt_val;
        else
          rx_data <= FR(i);
        end if;
        rx_valid <= '1';
        if i = 57 then rx_last <= '1'; ev_ok <= '1'; else rx_last <= '0'; ev_ok <= '0'; end if;
        step;
      end loop;
      rx_valid <= '0'; rx_last <= '0'; ev_ok <= '0';
      step;
    end procedure;

  begin
    rst <= '1'; step; step; rst <= '0';

    -- ---- caso 1: trama Sync valida ----
    inject(-1, x"00");
    step;
    assert msg_valid = '1' report "FALLO: msg_valid deberia ser 1 (Sync valido)" severity failure;
    assert msg_type = MT_SYNC report "FALLO: msg_type != SYNC" severity failure;
    assert seq_id = x"0000" report "FALLO: seq_id" severity failure;
    assert src_port_id = x"00112233445566770001"
      report "FALLO: sourcePortIdentity" severity failure;
    assert origin_sec = std_logic_vector(to_unsigned(5, SEC_W))
      report "FALLO: originTS sec" severity failure;
    assert origin_ns = std_logic_vector(to_unsigned(1600, NS_W))
      report "FALLO: originTS ns" severity failure;
    assert rx_sec = std_logic_vector(to_unsigned(9, SEC_W))
      report "FALLO: rx TS sec" severity failure;
    assert rx_ns = std_logic_vector(to_unsigned(4242, NS_W))
      report "FALLO: rx TS ns" severity failure;
    report "OK caso1: Sync valido parseado, campos y TS correctos";
    -- limpiar sticky
    rd_ack <= '1'; step; rd_ack <= '0'; step;
    assert msg_valid = '0' report "FALLO: rd_ack no limpio msg_valid" severity failure;

    -- ---- caso 2: EtherType corrupto (byte 13 = 0xF8) -> NO msg_valid ----
    inject(13, x"F8");
    step;
    assert msg_valid = '0'
      report "FALLO: trama no-PTP no deberia dar msg_valid" severity failure;
    report "OK caso2: EtherType malo rechazado (no msg_valid)";

    -- ---- caso 3: otra secuencia, seq_id distinto ----
    -- reutilizamos inject pero cambiando seq en bytes 44,45 via corrupcion doble
    rx_ts_sec <= std_logic_vector(to_unsigned(10, SEC_W));
    rx_ts_ns  <= std_logic_vector(to_unsigned(555, NS_W));
    rx_ts_valid <= '1';
    for i in 0 to 57 loop
      if i = 44 then rx_data <= x"12";
      elsif i = 45 then rx_data <= x"07";      -- seq_id = 0x1207 (hi y lo distintos)
      else rx_data <= FR(i); end if;
      rx_valid <= '1';
      if i = 57 then rx_last <= '1'; else rx_last <= '0'; end if;
      step;
    end loop;
    rx_valid <= '0'; rx_last <= '0'; step; step;
    assert msg_valid = '1' report "FALLO caso3 msg_valid" severity failure;
    assert seq_id = x"1207" report "FALLO caso3 seq_id" severity failure;
    assert rx_ns = std_logic_vector(to_unsigned(555, NS_W)) report "FALLO caso3 rx_ns" severity failure;
    report "OK caso3: seq_id=0x0007 y nuevo TS correctos";

    report "=== PTP_RX LAYER 1b PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
