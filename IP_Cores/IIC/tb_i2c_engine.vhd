-- ============================================================================
--  tb_i2c_engine.vhd — Capa 1c: i2c_master <-> i2c_slave por wired-AND
--
--  SIN modelos de comportamiento: los dos motores RTL reales hablando entre
--  si sobre un bus open-drain con pull-up. Esta es la pre-validacion exacta
--  del self-test loop_int que ira en el mmio (capa 2) y en silicio (capa 5).
--
--  El cruce critico es T4: el congelamiento del contador de cuartos del
--  maestro (stretching pasivo) contra el scl_hold del esclavo (stretching
--  activo) — dos implementaciones independientes del mismo mecanismo que
--  solo aqui se encuentran por primera vez.
--
--  T1: escritura de 3 bytes -> ACKs, rx_valid x3, bus libre al final
--  T2: direccion ajena -> NACK + STOP puro (NOBYTE)
--  T3: lectura de 2 bytes precargados (ACK, NACK) -> datos y consumo FWFT
--  T4: stretching end-to-end: FIFO TX vacio, push retrasado 25 us
--  T5: rx_full -> el maestro ve NACK en el dato + rx_ovf; cierre con NOBYTE
--  T6: underrun con stretch_en=0 -> el maestro lee 0xFF + tx_ur
--  T7: escritura + START repetido + lectura (contadores de start/stop)
--  T8: barrido de velocidad: 100 kHz (div=249) y 1 MHz (div=24)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i2c_engine is
end entity;

architecture sim of tb_i2c_engine is

  constant TCLK : time := 10 ns;                    -- 100 MHz

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- ---------------- maestro ----------------
  signal m_en    : std_logic := '1';
  signal scl_div : std_logic_vector(15 downto 0)
                 := std_logic_vector(to_unsigned(62, 16));   -- ~400 kHz

  signal cmd_valid, cmd_start, cmd_stop, cmd_read : std_logic := '0';
  signal cmd_ackout, cmd_nobyte : std_logic := '0';
  signal cmd_wdata : std_logic_vector(7 downto 0) := (others => '0');

  signal busy, done, arb_lost, bus_busy, xact_open : std_logic;
  signal rdata  : std_logic_vector(7 downto 0);
  signal ack_in : std_logic;

  signal m_scl_t, m_sda_t : std_logic;

  -- ---------------- esclavo ----------------
  constant OWN : std_logic_vector(6 downto 0) := "0101010";   -- 0x2A
  signal s_en       : std_logic := '1';
  signal stretch_en : std_logic := '1';

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid, rx_ovf : std_logic;
  signal rx_full  : std_logic := '0';

  signal tx_data  : std_logic_vector(7 downto 0);
  signal tx_valid : std_logic;
  signal tx_ren, tx_ur : std_logic;

  signal addressed, rd_active, start_det, stop_det : std_logic;

  signal s_scl_t, s_sda_t : std_logic;

  -- ---------------- bus wired-AND ----------------
  signal scl_bus, sda_bus : std_logic;
  signal scl_x, sda_x     : std_logic;

  -- ---------------- fuente TX estilo FWFT ----------------
  type q_t is array (0 to 7) of std_logic_vector(7 downto 0);
  signal txq    : q_t := (others => (others => '0'));
  signal txq_wr : natural := 0;
  signal txq_rd : natural := 0;

  signal push_tgl   : std_logic := '0';
  signal push_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal push_delay : time := 0 ns;

  -- ---------------- monitores ----------------
  signal rx_cnt, ovf_cnt, ur_cnt   : integer := 0;
  signal start_cnt, stop_cnt       : integer := 0;
  signal rx_last : std_logic_vector(7 downto 0) := (others => '0');
  signal scl_period : time := 0 ns;

begin

  clk <= not clk after TCLK / 2;

  -- ================= wired-AND con pull-up =================
  scl_bus <= 'H';
  scl_bus <= '0' when m_scl_t = '0' else 'Z';
  scl_bus <= '0' when s_scl_t = '0' else 'Z';

  sda_bus <= 'H';
  sda_bus <= '0' when m_sda_t = '0' else 'Z';
  sda_bus <= '0' when s_sda_t = '0' else 'Z';

  scl_x <= to_x01(scl_bus);
  sda_x <= to_x01(sda_bus);

  -- ================= DUT maestro =================
  u_master : entity work.i2c_master
    port map (
      clk => clk, rst => rst, en => m_en, scl_div => scl_div,
      cmd_valid => cmd_valid, cmd_start => cmd_start, cmd_stop => cmd_stop,
      cmd_read => cmd_read, cmd_ackout => cmd_ackout,
      cmd_nobyte => cmd_nobyte, cmd_wdata => cmd_wdata,
      busy => busy, done => done, rdata => rdata, ack_in => ack_in,
      arb_lost => arb_lost, bus_busy => bus_busy, xact_open => xact_open,
      scl_i => scl_x, scl_t => m_scl_t, sda_i => sda_x, sda_t => m_sda_t
    );

  -- ================= DUT esclavo =================
  u_slave : entity work.i2c_slave
    port map (
      clk => clk, rst => rst, en => s_en,
      own_addr => OWN, stretch_en => stretch_en,
      rx_data => rx_data, rx_valid => rx_valid,
      rx_full => rx_full, rx_ovf => rx_ovf,
      tx_data => tx_data, tx_valid => tx_valid,
      tx_ren => tx_ren, tx_ur => tx_ur,
      addressed => addressed, rd_active => rd_active,
      start_det => start_det, stop_det => stop_det,
      scl_i => scl_x, scl_t => s_scl_t, sda_i => sda_x, sda_t => s_sda_t
    );

  -- ================= fuente TX estilo FWFT =================
  tx_valid <= '1' when txq_rd /= txq_wr else '0';
  tx_data  <= txq(txq_rd mod 8);

  consume : process(clk)
  begin
    if rising_edge(clk) then
      if tx_ren = '1' and txq_rd /= txq_wr then
        txq_rd <= txq_rd + 1;
      end if;
    end if;
  end process;

  pusher : process
  begin
    wait on push_tgl;
    wait for push_delay;
    txq(txq_wr mod 8) <= push_data;
    txq_wr <= txq_wr + 1;
  end process;

  -- ================= monitores =================
  mon : process(clk)
  begin
    if rising_edge(clk) then
      if rx_valid = '1' then
        rx_cnt  <= rx_cnt + 1;
        rx_last <= rx_data;
      end if;
      if rx_ovf = '1' then
        ovf_cnt <= ovf_cnt + 1;
      end if;
      if tx_ur = '1' then
        ur_cnt <= ur_cnt + 1;
      end if;
      if start_det = '1' then
        start_cnt <= start_cnt + 1;
      end if;
      if stop_det = '1' then
        stop_cnt <= stop_cnt + 1;
      end if;
    end if;
  end process;

  meas : process
    variable t_prev : time := 0 ns;
  begin
    wait until falling_edge(scl_x);
    if t_prev /= 0 ns then
      scl_period <= now - t_prev;
    end if;
    t_prev := now;
  end process;

  -- ================= watchdog global =================
  watchdog : process
  begin
    wait for 5 ms;
    assert false
      report "WATCHDOG: la simulacion no termino a tiempo (cuelgue probable)"
      severity failure;
  end process;

  -- ================= estímulos =================
  stim : process
    variable got_arb : boolean;
    variable t0      : time;
    variable sc0     : integer;

    procedure cmd(constant c_start  : in std_logic;
                  constant c_stop   : in std_logic;
                  constant c_read   : in std_logic;
                  constant c_ack    : in std_logic;
                  constant c_nob    : in std_logic;
                  constant data     : in std_logic_vector(7 downto 0);
                  variable arb      : out boolean) is
    begin
      if busy = '1' then
        wait until busy = '0';
      end if;
      wait until rising_edge(clk);
      cmd_valid  <= '1';
      cmd_start  <= c_start;
      cmd_stop   <= c_stop;
      cmd_read   <= c_read;
      cmd_ackout <= c_ack;
      cmd_nobyte <= c_nob;
      cmd_wdata  <= data;
      wait until rising_edge(clk);
      cmd_valid  <= '0';
      arb := false;
      loop
        wait until rising_edge(clk);
        if arb_lost = '1' then
          arb := true;
          exit;
        end if;
        exit when done = '1';
      end loop;
      wait for 1 ns;                       -- settle (lección: carreras de delta)
    end procedure;

    procedure wr(constant c_start : in std_logic;
                 constant c_stop  : in std_logic;
                 constant data    : in std_logic_vector(7 downto 0)) is
      variable a : boolean;
    begin
      cmd(c_start, c_stop, '0', '0', '0', data, a);
      assert not a
        report "escritura perdio arbitraje inesperadamente" severity failure;
    end procedure;

    procedure rd(constant c_stop : in std_logic;
                 constant c_ack  : in std_logic) is
      variable a : boolean;
    begin
      cmd('0', c_stop, '1', c_ack, '0', x"00", a);
      assert not a
        report "lectura perdio arbitraje inesperadamente" severity failure;
    end procedure;

    procedure push(constant v : in std_logic_vector(7 downto 0);
                   constant d : in time) is
    begin
      push_data  <= v;
      push_delay <= d;
      push_tgl   <= not push_tgl;
      wait for 2 ns;
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 200 ns;

    ------------------------------------------------------------------ T1
    report "T1: escritura de 3 bytes maestro->esclavo (0x10 0x20 0x30)";
    wr('1', '0', OWN & '0');
    assert ack_in = '0'
      report "T1: la direccion no recibio ACK" severity failure;
    assert addressed = '1' and rd_active = '0'
      report "T1: addressed/rd_active incorrectos en el esclavo" severity failure;
    wr('0', '0', x"10");
    assert ack_in = '0'
      report "T1: el primer dato no recibio ACK" severity failure;
    wr('0', '0', x"20");
    wr('0', '1', x"30");
    assert ack_in = '0'
      report "T1: el ultimo dato no recibio ACK" severity failure;
    wait for 1 us;
    assert rx_cnt = 3
      report "T1: el esclavo no registro exactamente 3 bytes" severity failure;
    assert rx_last = x"30"
      report "T1: el ultimo byte RX no es 0x30" severity failure;
    assert bus_busy = '0' and xact_open = '0'
      report "T1: el bus no quedo libre tras el STOP" severity failure;
    assert addressed = '0'
      report "T1: addressed no se limpio tras el STOP" severity failure;
    assert scl_period > 2.26 us and scl_period < 2.78 us
      report "T1: periodo de SCL fuera de +/-10% para ~400 kHz" severity failure;

    ------------------------------------------------------------------ T2
    report "T2: direccion ajena (0x33) -> NACK + STOP puro (NOBYTE)";
    wr('1', '0', "0110011" & '0');
    assert ack_in = '1'
      report "T2: una direccion ajena recibio ACK" severity failure;
    cmd('0', '1', '0', '0', '1', x"00", got_arb);
    wait for 1 us;
    assert rx_cnt = 3
      report "T2: rx_cnt cambio con una direccion ajena" severity failure;
    assert bus_busy = '0' and scl_x = '1' and sda_x = '1'
      report "T2: el bus no quedo libre tras el STOP" severity failure;

    ------------------------------------------------------------------ T3
    report "T3: lectura de 2 bytes precargados (0xDE 0xAD)";
    push(x"DE", 0 ns);
    push(x"AD", 0 ns);
    wait for 1 us;
    wr('1', '0', OWN & '1');
    assert ack_in = '0'
      report "T3: la direccion de lectura no recibio ACK" severity failure;
    assert rd_active = '1'
      report "T3: rd_active no subio en el esclavo" severity failure;
    rd('0', '0');                          -- ACK: quiero otro
    assert rdata = x"DE"
      report "T3: el primer byte leido no es 0xDE" severity failure;
    rd('1', '1');                          -- NACK + STOP
    assert rdata = x"AD"
      report "T3: el segundo byte leido no es 0xAD" severity failure;
    wait for 1 us;
    assert tx_valid = '0'
      report "T3: la fuente TX no quedo vacia (consumo FWFT incorrecto)"
      severity failure;

    ------------------------------------------------------------------ T4
    report "T4: stretching end-to-end (freeze del maestro vs scl_hold)";
    assert tx_valid = '0'
      report "T4: precondicion rota, la fuente TX no esta vacia" severity failure;
    stretch_en <= '1';
    wr('1', '0', OWN & '1');
    push(x"B7", 25 us);
    t0 := now;
    rd('1', '1');                          -- el maestro congela su contador
    assert now - t0 > 20 us
      report "T4: la lectura no se alargo por el stretching" severity failure;
    assert rdata = x"B7"
      report "T4: el byte leido tras el stretching no es 0xB7" severity failure;
    wait for 1 us;

    ------------------------------------------------------------------ T5
    report "T5: rx_full -> NACK visto por el maestro + rx_ovf";
    rx_full <= '1';
    wr('1', '0', OWN & '0');
    assert ack_in = '0'
      report "T5: la direccion no recibio ACK (rx_full no afecta direccion)"
      severity failure;
    wr('0', '0', x"11");
    assert ack_in = '1'
      report "T5: con rx_full el maestro debio ver NACK" severity failure;
    cmd('0', '1', '0', '0', '1', x"00", got_arb);   -- STOP puro
    rx_full <= '0';
    wait for 1 us;
    assert ovf_cnt = 1
      report "T5: rx_ovf no pulso exactamente una vez" severity failure;
    assert rx_cnt = 3
      report "T5: el byte NACKeado no debio entrar a RX" severity failure;

    ------------------------------------------------------------------ T6
    report "T6: underrun con stretch_en=0 -> el maestro lee 0xFF";
    stretch_en <= '0';
    wr('1', '0', OWN & '1');
    rd('1', '1');
    assert rdata = x"FF"
      report "T6: el byte de underrun no es 0xFF" severity failure;
    wait for 1 us;
    assert ur_cnt = 1
      report "T6: tx_ur no pulso exactamente una vez" severity failure;
    stretch_en <= '1';

    ------------------------------------------------------------------ T7
    report "T7: escritura + START repetido + lectura";
    push(x"C3", 0 ns);
    wait for 1 us;
    sc0 := start_cnt;
    wr('1', '0', OWN & '0');
    wr('0', '0', x"5C");
    wr('1', '0', OWN & '1');               -- START repetido
    assert ack_in = '0'
      report "T7: la direccion tras START repetido no recibio ACK"
      severity failure;
    rd('1', '1');
    assert rdata = x"C3"
      report "T7: el byte leido tras START repetido no es 0xC3" severity failure;
    wait for 1 us;
    assert rx_last = x"5C"
      report "T7: el byte escrito antes del START repetido no llego"
      severity failure;
    assert start_cnt = sc0 + 2
      report "T7: el esclavo no conto START + START repetido" severity failure;

    ------------------------------------------------------------------ T8
    report "T8: barrido de velocidad: 100 kHz y 1 MHz";
    scl_div <= std_logic_vector(to_unsigned(249, 16));
    wait for 1 us;
    wr('1', '0', OWN & '0');
    wr('0', '1', x"99");
    assert ack_in = '0'
      report "T8: dato a 100 kHz sin ACK" severity failure;
    wait for 1 us;
    assert rx_last = x"99"
      report "T8: el byte a 100 kHz no llego al esclavo" severity failure;
    assert scl_period > 9.0 us and scl_period < 11.0 us
      report "T8: periodo de SCL fuera de +/-10% para 100 kHz" severity failure;

    scl_div <= std_logic_vector(to_unsigned(24, 16));
    wait for 1 us;
    wr('1', '0', OWN & '0');
    wr('0', '1', x"66");
    assert ack_in = '0'
      report "T8: dato a 1 MHz sin ACK" severity failure;
    wait for 1 us;
    assert rx_last = x"66"
      report "T8: el byte a 1 MHz no llego al esclavo" severity failure;
    assert scl_period > 0.9 us and scl_period < 1.1 us
      report "T8: periodo de SCL fuera de +/-10% para 1 MHz" severity failure;

    report "== TODOS LOS TESTS PASARON (T1-T8) ==";
    finish;
  end process;

end architecture sim;
