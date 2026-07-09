-- ============================================================================
--  tb_i2c_slave.vhd — Capa 1b: motor esclavo I2C en aislamiento
--
--  Modelo de maestro INDEPENDIENTE (requisito de capa 1): bit-bang puramente
--  por 'wait for' con medio-bit de ~1.25 us (~400 kHz), sin divisor ni
--  relación alguna con el reloj del DUT. Es STRETCH-AWARE: tras liberar SCL
--  espera a que la línea suba de verdad antes de continuar (como un maestro
--  real).
--
--  La fuente TX emula un byte_fifo FWFT: tx_valid/tx_data presentes cuando
--  hay dato, tx_ren consume. Un proceso "pusher" permite encolar bytes con
--  retardo programable (para el test de stretching mientras el maestro está
--  a medio ciclo).
--
--  T1: escritura de 2 bytes a la dirección propia -> ACKs, rx_valid x2
--  T2: dirección ajena -> NACK, sin rx_valid
--  T3: rx_full -> NACK + rx_ovf (drop-newest); al liberar, el byte pasa
--  T4: lectura de 2 bytes precargados (ACK, NACK) -> datos y consumo FWFT
--  T5: lectura con FIFO vacío y stretch_en=1 -> SCL retenida ~25 us y dato ok
--  T6: lectura con FIFO vacío y stretch_en=0 -> 0xFF + tx_ur
--  T7: escritura + START repetido + lectura (addressed / rd_active)
--  T8: en=0 -> NACK a la propia dirección; en=1 recupera
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i2c_slave is
end entity;

architecture sim of tb_i2c_slave is

  constant TCLK : time := 10 ns;                    -- 100 MHz
  constant HB   : time := 1.25 us;                  -- medio bit (~400 kHz)

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '1';

  constant OWN : std_logic_vector(6 downto 0) := "0101010";   -- 0x2A
  signal own_addr   : std_logic_vector(6 downto 0) := OWN;
  signal stretch_en : std_logic := '1';

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid, rx_ovf : std_logic;
  signal rx_full  : std_logic := '0';

  signal tx_data  : std_logic_vector(7 downto 0);
  signal tx_valid : std_logic;
  signal tx_ren, tx_ur : std_logic;

  signal addressed, rd_active, start_det, stop_det : std_logic;

  signal scl_t, sda_t : std_logic;

  -- bus open-drain con pull-up débil
  signal scl_bus, sda_bus : std_logic;
  signal scl_x, sda_x     : std_logic;

  -- drivers del modelo de maestro ('0' jala, '1' suelta)
  signal m_scl, m_sda : std_logic := '1';

  -- emulación FWFT de la fuente TX
  type q_t is array (0 to 7) of std_logic_vector(7 downto 0);
  signal txq     : q_t := (others => (others => '0'));
  signal txq_wr  : natural := 0;                    -- solo lo escribe pusher
  signal txq_rd  : natural := 0;                    -- solo lo escribe consume

  signal push_tgl   : std_logic := '0';
  signal push_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal push_delay : time := 0 ns;

  -- monitores
  signal rx_cnt, ovf_cnt, ur_cnt : integer := 0;
  signal rx_last : std_logic_vector(7 downto 0) := (others => '0');

begin

  clk <= not clk after TCLK / 2;

  -- ================= wired-AND con pull-up =================
  scl_bus <= 'H';
  scl_bus <= '0' when scl_t = '0' else 'Z';
  scl_bus <= '0' when m_scl = '0' else 'Z';

  sda_bus <= 'H';
  sda_bus <= '0' when sda_t = '0' else 'Z';
  sda_bus <= '0' when m_sda = '0' else 'Z';

  scl_x <= to_x01(scl_bus);
  sda_x <= to_x01(sda_bus);

  -- ================= DUT =================
  dut : entity work.i2c_slave
    port map (
      clk => clk, rst => rst, en => en,
      own_addr => own_addr, stretch_en => stretch_en,
      rx_data => rx_data, rx_valid => rx_valid,
      rx_full => rx_full, rx_ovf => rx_ovf,
      tx_data => tx_data, tx_valid => tx_valid,
      tx_ren => tx_ren, tx_ur => tx_ur,
      addressed => addressed, rd_active => rd_active,
      start_det => start_det, stop_det => stop_det,
      scl_i => scl_x, scl_t => scl_t,
      sda_i => sda_x, sda_t => sda_t
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
    end if;
  end process;

  -- ================= watchdog global =================
  watchdog : process
  begin
    wait for 5 ms;
    assert false
      report "WATCHDOG: la simulacion no termino a tiempo (cuelgue probable)"
      severity failure;
  end process;

  -- ================= estímulos: modelo de maestro bit-bang =================
  stim : process
    variable ackn : std_logic;
    variable rb   : std_logic_vector(7 downto 0);
    variable t0   : time;

    -- espera stretch-aware: liberar SCL y aguardar a que suba de verdad
    procedure scl_release_wait is
    begin
      m_scl <= '1';
      if scl_x /= '1' then
        wait until scl_x = '1' for 1 ms;
        assert scl_x = '1'
          report "maestro modelo: SCL nunca subio (stretch sin fin?)"
          severity failure;
      end if;
    end procedure;

    procedure i2c_start is
    begin
      m_sda <= '1';
      wait for HB / 2;
      scl_release_wait;
      wait for HB;
      m_sda <= '0';                        -- START: SDA cae con SCL alta
      wait for HB;
      m_scl <= '0';
      wait for HB / 2;
    end procedure;

    procedure i2c_wbit(constant b : in std_logic) is
    begin
      m_sda <= b;
      wait for HB / 2;
      scl_release_wait;
      wait for HB;
      m_scl <= '0';
      wait for HB / 2;
    end procedure;

    procedure i2c_rbit(variable b : out std_logic) is
    begin
      m_sda <= '1';                        -- liberar: el otro extremo maneja
      wait for HB / 2;
      scl_release_wait;
      wait for HB / 2;
      b := sda_x;                          -- muestrear a mitad del alto
      wait for HB / 2;
      m_scl <= '0';
      wait for HB / 2;
    end procedure;

    procedure i2c_wbyte(constant v : in std_logic_vector(7 downto 0);
                        variable ack_n : out std_logic) is
    begin
      for i in 7 downto 0 loop
        i2c_wbit(v(i));
      end loop;
      i2c_rbit(ack_n);                     -- slot de ACK del esclavo
    end procedure;

    procedure i2c_rbyte(variable v : out std_logic_vector(7 downto 0);
                        constant ack_out : in std_logic) is
      variable bt : std_logic;
    begin
      for i in 7 downto 0 loop
        i2c_rbit(bt);
        v(i) := bt;
      end loop;
      i2c_wbit(ack_out);                   -- ACK/NACK del maestro
    end procedure;

    procedure i2c_stop is
    begin
      m_sda <= '0';
      wait for HB / 2;
      scl_release_wait;
      wait for HB;
      m_sda <= '1';                        -- STOP: SDA sube con SCL alta
      wait for HB;
    end procedure;

    -- encolar un byte en la fuente TX (con retardo opcional)
    procedure push(constant v : in std_logic_vector(7 downto 0);
                   constant d : in time) is
    begin
      push_data  <= v;
      push_delay <= d;
      push_tgl   <= not push_tgl;
      wait for 2 ns;                       -- separar eventos de push
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 200 ns;

    ------------------------------------------------------------------ T1
    report "T1: escritura de 2 bytes a la direccion propia (0x2A)";
    i2c_start;
    i2c_wbyte(OWN & '0', ackn);
    assert ackn = '0'
      report "T1: la direccion propia no recibio ACK" severity failure;
    wait for 1 ns;
    assert addressed = '1' and rd_active = '0'
      report "T1: addressed/rd_active incorrectos en escritura" severity failure;
    i2c_wbyte(x"54", ackn);
    assert ackn = '0'
      report "T1: el primer dato no recibio ACK" severity failure;
    i2c_wbyte(x"A5", ackn);
    assert ackn = '0'
      report "T1: el segundo dato no recibio ACK" severity failure;
    i2c_stop;
    wait for 1 us;
    assert rx_cnt = 2
      report "T1: no se registraron exactamente 2 bytes en RX" severity failure;
    assert rx_last = x"A5"
      report "T1: el ultimo byte RX no es 0xA5" severity failure;
    assert addressed = '0'
      report "T1: addressed no se limpio tras el STOP" severity failure;

    ------------------------------------------------------------------ T2
    report "T2: direccion ajena (0x33) -> sin ACK, sin rx_valid";
    i2c_start;
    i2c_wbyte("0110011" & '0', ackn);
    assert ackn = '1'
      report "T2: una direccion ajena recibio ACK" severity failure;
    i2c_stop;
    wait for 1 us;
    assert rx_cnt = 2
      report "T2: rx_cnt cambio con una direccion ajena" severity failure;

    ------------------------------------------------------------------ T3
    report "T3: rx_full -> NACK + rx_ovf; al liberar, el byte pasa";
    rx_full <= '1';
    i2c_start;
    i2c_wbyte(OWN & '0', ackn);
    assert ackn = '0'
      report "T3: la direccion no recibio ACK (rx_full no afecta direccion)"
      severity failure;
    i2c_wbyte(x"11", ackn);
    assert ackn = '1'
      report "T3: con rx_full el dato debio recibir NACK" severity failure;
    i2c_stop;
    wait for 1 us;
    assert ovf_cnt = 1
      report "T3: rx_ovf no pulso exactamente una vez" severity failure;
    assert rx_cnt = 2
      report "T3: el byte NACKeado no debio entrar a RX" severity failure;
    rx_full <= '0';
    i2c_start;
    i2c_wbyte(OWN & '0', ackn);
    i2c_wbyte(x"22", ackn);
    assert ackn = '0'
      report "T3: tras liberar rx_full el dato no recibio ACK" severity failure;
    i2c_stop;
    wait for 1 us;
    assert rx_cnt = 3 and rx_last = x"22"
      report "T3: el byte tras liberar rx_full no llego a RX" severity failure;

    ------------------------------------------------------------------ T4
    report "T4: lectura de 2 bytes precargados (ACK, NACK)";
    push(x"DE", 0 ns);
    push(x"AD", 0 ns);
    wait for 1 us;
    i2c_start;
    i2c_wbyte(OWN & '1', ackn);
    assert ackn = '0'
      report "T4: la direccion de lectura no recibio ACK" severity failure;
    wait for 1 ns;
    assert rd_active = '1'
      report "T4: rd_active no subio en fase de lectura" severity failure;
    i2c_rbyte(rb, '0');                    -- ACK: quiero otro
    assert rb = x"DE"
      report "T4: el primer byte leido no es 0xDE" severity failure;
    i2c_rbyte(rb, '1');                    -- NACK: ultimo
    assert rb = x"AD"
      report "T4: el segundo byte leido no es 0xAD" severity failure;
    i2c_stop;
    wait for 1 us;
    assert tx_valid = '0'
      report "T4: la fuente TX no quedo vacia (consumo FWFT incorrecto)"
      severity failure;

    ------------------------------------------------------------------ T5
    report "T5: stretching: lectura con FIFO vacio y push retrasado 25 us";
    assert tx_valid = '0'
      report "T5: precondicion rota, la fuente TX no esta vacia" severity failure;
    stretch_en <= '1';
    i2c_start;
    i2c_wbyte(OWN & '1', ackn);
    assert ackn = '0'
      report "T5: la direccion de lectura no recibio ACK" severity failure;
    push(x"B7", 25 us);                    -- el dato llegara a media espera
    t0 := now;
    i2c_rbyte(rb, '1');                    -- el modelo espera el stretch
    assert now - t0 > 20 us
      report "T5: la lectura no se alargo por el stretching" severity failure;
    assert rb = x"B7"
      report "T5: el byte leido tras el stretching no es 0xB7" severity failure;
    i2c_stop;
    wait for 1 us;

    ------------------------------------------------------------------ T6
    report "T6: underrun: FIFO vacio con stretch_en=0 -> 0xFF + tx_ur";
    stretch_en <= '0';
    i2c_start;
    i2c_wbyte(OWN & '1', ackn);
    i2c_rbyte(rb, '1');
    assert rb = x"FF"
      report "T6: el byte de underrun no es 0xFF" severity failure;
    i2c_stop;
    wait for 1 us;
    assert ur_cnt = 1
      report "T6: tx_ur no pulso exactamente una vez" severity failure;
    stretch_en <= '1';

    ------------------------------------------------------------------ T7
    report "T7: escritura + START repetido + lectura";
    push(x"C3", 0 ns);
    wait for 1 us;
    i2c_start;
    i2c_wbyte(OWN & '0', ackn);
    i2c_wbyte(x"5C", ackn);
    assert ackn = '0'
      report "T7: el dato de escritura no recibio ACK" severity failure;
    i2c_start;                             -- START repetido (SCL abajo)
    i2c_wbyte(OWN & '1', ackn);
    assert ackn = '0'
      report "T7: la direccion tras START repetido no recibio ACK"
      severity failure;
    i2c_rbyte(rb, '1');
    assert rb = x"C3"
      report "T7: el byte leido tras START repetido no es 0xC3" severity failure;
    i2c_stop;
    wait for 1 us;
    assert rx_last = x"5C"
      report "T7: el byte escrito antes del START repetido no llego"
      severity failure;

    ------------------------------------------------------------------ T8
    report "T8: en=0 -> NACK a la direccion propia; en=1 recupera";
    en <= '0';
    i2c_start;
    i2c_wbyte(OWN & '0', ackn);
    assert ackn = '1'
      report "T8: con en=0 la direccion propia recibio ACK" severity failure;
    i2c_stop;
    en <= '1';
    i2c_start;
    i2c_wbyte(OWN & '0', ackn);
    assert ackn = '0'
      report "T8: con en=1 la direccion propia no recupero el ACK"
      severity failure;
    i2c_stop;
    wait for 1 us;

    report "== TODOS LOS TESTS PASARON (T1-T8) ==";
    finish;
  end process;

end architecture sim;
