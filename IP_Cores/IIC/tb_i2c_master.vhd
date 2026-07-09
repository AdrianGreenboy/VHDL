-- ============================================================================
--  tb_i2c_master.vhd — Capa 1a: motor maestro I2C en aislamiento
--
--  Modelo de esclavo INDEPENDIENTE (requisito de capa 1): puramente por
--  eventos de línea, sin divisor ni noción del reloj del DUT — funciona a
--  cualquier F_SCL sin tocarlo. Semántica EEPROM-style en dirección 0x50:
--  el primer byte tras el ACK de dirección fija el puntero (4 LSB), los
--  siguientes escriben mem[ptr++]; la lectura devuelve mem[ptr++] hasta el
--  NACK del maestro. Estiramiento de SCL configurable tras el ACK de
--  dirección (mdl_stretch).
--
--  Además: un AGRESOR que pelea el arbitraje transmitiendo ceros desde el
--  START, y un MAESTRO AJENO que ejecuta una transacción completa para
--  probar el monitor bus_busy y la espera ST_WAITFREE.
--
--  Bus modelado como wired-AND con pull-up débil ('H') y cuatro drivers
--  open-drain resueltos por std_logic.
--
--  T1: escritura multi-byte con ACKs + periodo de SCL a ~400 kHz
--  T2: dirección inexistente -> NACK + STOP puro (cmd_nobyte)
--  T3: lectura EEPROM-style con START repetido (ACK y NACK del maestro)
--  T4: clock stretching de 30 us (compara duración contra transacción gemela)
--  T5: pérdida de arbitraje, liberación de líneas y recuperación
--  T6: comando con bus ocupado por otro maestro -> espera WAITFREE
--  T7: periodo de SCL a 100 kHz (div=249)
--  T8: periodo de SCL a 1 MHz Fm+ (div=24)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i2c_master is
end entity;

architecture sim of tb_i2c_master is

  constant TCLK : time := 10 ns;                    -- 100 MHz

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '1';

  signal scl_div : std_logic_vector(15 downto 0)
                 := std_logic_vector(to_unsigned(62, 16));   -- ~400 kHz

  signal cmd_valid, cmd_start, cmd_stop, cmd_read : std_logic := '0';
  signal cmd_ackout, cmd_nobyte : std_logic := '0';
  signal cmd_wdata : std_logic_vector(7 downto 0) := (others => '0');

  signal busy, done, arb_lost, bus_busy, xact_open : std_logic;
  signal rdata  : std_logic_vector(7 downto 0);
  signal ack_in : std_logic;

  signal scl_t, sda_t : std_logic;

  -- bus open-drain con pull-up débil
  signal scl_bus, sda_bus : std_logic;
  signal scl_x, sda_x     : std_logic;

  -- drivers open-drain de los modelos ('0' jala, '1' suelta)
  signal slv_sda,  slv_scl  : std_logic := '1';
  signal agg_sda,  agg_scl  : std_logic := '1';
  signal fake_sda, fake_scl : std_logic := '1';

  -- control / observación del modelo esclavo
  constant SLV_ADDR : std_logic_vector(6 downto 0) := "1010000";  -- 0x50
  signal mdl_stretch : time := 0 ns;
  signal mdl_last    : std_logic_vector(7 downto 0) := (others => '0');
  signal mdl_wr_cnt  : integer := 0;

  -- disparadores
  signal arb_go, fake_go : boolean := false;

  -- medición de periodo de SCL (flanco de bajada a flanco de bajada)
  signal scl_period : time := 0 ns;

begin

  clk <= not clk after TCLK / 2;

  -- ================= wired-AND con pull-up =================
  scl_bus <= 'H';
  scl_bus <= '0' when scl_t    = '0' else 'Z';
  scl_bus <= '0' when slv_scl  = '0' else 'Z';
  scl_bus <= '0' when agg_scl  = '0' else 'Z';
  scl_bus <= '0' when fake_scl = '0' else 'Z';

  sda_bus <= 'H';
  sda_bus <= '0' when sda_t    = '0' else 'Z';
  sda_bus <= '0' when slv_sda  = '0' else 'Z';
  sda_bus <= '0' when agg_sda  = '0' else 'Z';
  sda_bus <= '0' when fake_sda = '0' else 'Z';

  scl_x <= to_x01(scl_bus);
  sda_x <= to_x01(sda_bus);

  -- ================= DUT =================
  dut : entity work.i2c_master
    port map (
      clk => clk, rst => rst, en => en, scl_div => scl_div,
      cmd_valid => cmd_valid, cmd_start => cmd_start, cmd_stop => cmd_stop,
      cmd_read => cmd_read, cmd_ackout => cmd_ackout,
      cmd_nobyte => cmd_nobyte, cmd_wdata => cmd_wdata,
      busy => busy, done => done, rdata => rdata, ack_in => ack_in,
      arb_lost => arb_lost, bus_busy => bus_busy, xact_open => xact_open,
      scl_i => scl_x, scl_t => scl_t, sda_i => sda_x, sda_t => sda_t
    );

  -- ================= medidor de periodo de SCL =================
  meas : process
    variable t_prev : time := 0 ns;
  begin
    wait until falling_edge(scl_x);
    if t_prev /= 0 ns then
      scl_period <= now - t_prev;
    end if;
    t_prev := now;
  end process;

  -- ================= modelo de esclavo (independiente) =================
  slave : process
    type mem_t is array (0 to 15) of std_logic_vector(7 downto 0);
    variable mem : mem_t := (others => (others => '0'));
    variable ptr : natural range 0 to 15 := 0;
    variable b   : std_logic_vector(7 downto 0);
    variable evt : integer;   -- 0 = byte completo, 1 = START rep, 2 = STOP
    variable first : boolean;

    -- un bit: muestrea en subida de SCL; detecta START/STOP (SDA cambia
    -- con SCL alta) mientras espera la bajada
    procedure get_bit(variable v : out std_logic; variable e : out integer) is
    begin
      wait until rising_edge(scl_x);
      v := sda_x;
      e := 0;
      loop
        wait until scl_x'event or sda_x'event;
        if scl_x = '0' then
          exit;
        elsif sda_x'event and scl_x = '1' then
          if sda_x = '0' then e := 1; else e := 2; end if;
          exit;
        end if;
      end loop;
    end procedure;

    procedure get_byte(variable v : out std_logic_vector(7 downto 0);
                       variable e : out integer) is
      variable bt : std_logic;
      variable eb : integer;
    begin
      for i in 7 downto 0 loop
        get_bit(bt, eb);
        if eb /= 0 then
          e := eb;
          return;
        end if;
        v(i) := bt;
      end loop;
      e := 0;
    end procedure;

    -- ACK del esclavo, con estiramiento opcional de SCL justo antes
    procedure send_ack(constant stretch : in time) is
    begin
      slv_sda <= '0';
      if stretch > 0 ns then
        slv_scl <= '0';                    -- retiene SCL abajo: stretching
        wait for stretch;
        slv_scl <= '1';
      end if;
      wait until rising_edge(scl_x);
      wait until falling_edge(scl_x);
      slv_sda <= '1';
    end procedure;

    procedure wait_stop_or_start(variable e : out integer) is
    begin
      loop
        wait until sda_x'event;
        if scl_x = '1' then
          if sda_x = '1' then e := 2; else e := 1; end if;
          exit;
        end if;
      end loop;
    end procedure;

  begin
    slv_sda <= '1';
    slv_scl <= '1';

    -- esperar un START real (SDA cae con SCL alta)
    wait until falling_edge(sda_x);
    if scl_x = '1' then
      xact : loop
        get_byte(b, evt);
        if evt = 1 then
          next xact;                       -- START repetido: byte = dirección
        elsif evt = 2 then
          exit xact;                       -- STOP
        end if;

        if b(7 downto 1) = SLV_ADDR then
          if b(0) = '0' then
            -- ==================== ESCRITURA ====================
            send_ack(mdl_stretch);
            first := true;
            wr : loop
              get_byte(b, evt);
              if evt = 1 then next xact; end if;
              if evt = 2 then exit xact; end if;
              if first then
                ptr   := to_integer(unsigned(b(3 downto 0)));
                first := false;
              else
                mem(ptr)   := b;
                ptr        := (ptr + 1) mod 16;
                mdl_last   <= b;
                mdl_wr_cnt <= mdl_wr_cnt + 1;
              end if;
              send_ack(0 ns);
            end loop;
          else
            -- ==================== LECTURA ====================
            send_ack(mdl_stretch);
            rd : loop
              b   := mem(ptr);
              ptr := (ptr + 1) mod 16;
              for i in 7 downto 0 loop
                slv_sda <= b(i);           -- '0' jala, '1' suelta
                wait until rising_edge(scl_x);
                wait until falling_edge(scl_x);
              end loop;
              slv_sda <= '1';              -- soltar para el ACK del maestro
              wait until rising_edge(scl_x);
              if sda_x = '0' then          -- ACK: siguiente byte
                wait until falling_edge(scl_x);
              else                         -- NACK: viene STOP o START rep
                wait_stop_or_start(evt);
                if evt = 1 then next xact; else exit xact; end if;
              end if;
            end loop;
          end if;
        else
          -- no soy yo: sin ACK, esperar el fin de la transacción
          wait_stop_or_start(evt);
          if evt = 1 then next xact; else exit xact; end if;
        end if;
      end loop;
    end if;
  end process;

  -- ================= agresor de arbitraje =================
  -- Al ver el START del DUT transmite ceros: el primer bit '1' del DUT
  -- colisiona (0xA0 arranca en '1') y el DUT debe soltar el bus. Luego el
  -- agresor cierra "su" transacción con un STOP limpio.
  aggressor : process
  begin
    wait until arb_go;
    wait until falling_edge(sda_x) and scl_x = '1';
    agg_sda <= '0';
    wait for 40 us;
    agg_scl <= '0';  wait for 2 us;
    agg_scl <= '1';  wait for 2 us;
    agg_sda <= '1';                        -- STOP
    wait;
  end process;

  -- ================= maestro ajeno (para bus_busy / WAITFREE) =================
  fake_master : process
  begin
    wait until fake_go;
    fake_sda <= '0';                       -- START
    wait for 3 us;
    for i in 0 to 7 loop
      fake_scl <= '0';  wait for 1.5 us;
      fake_scl <= '1';  wait for 1.5 us;
    end loop;
    fake_scl <= '0';  wait for 2 us;
    fake_scl <= '1';  wait for 2 us;
    fake_sda <= '1';                       -- STOP
    wait;
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
    variable got_arb   : boolean;
    variable t0        : time;
    variable t_a, t_b  : time;

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

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 200 ns;

    ------------------------------------------------------------------ T1
    report "T1: escritura multi-byte (addr 0x50, ptr=2, datos 0x77 0x88)";
    wr('1', '0', x"A0");
    assert ack_in = '0'
      report "T1: la direccion 0x50/W no recibio ACK del esclavo" severity failure;
    wr('0', '0', x"02");
    assert ack_in = '0'
      report "T1: el byte de puntero no recibio ACK" severity failure;
    wr('0', '0', x"77");
    wr('0', '1', x"88");
    assert ack_in = '0'
      report "T1: el ultimo dato no recibio ACK" severity failure;
    wait for 1 us;
    assert mdl_wr_cnt = 2
      report "T1: el esclavo no registro exactamente 2 bytes escritos"
      severity failure;
    assert mdl_last = x"88"
      report "T1: el ultimo byte visto por el esclavo no es 0x88" severity failure;
    assert scl_period > 2.26 us and scl_period < 2.78 us
      report "T1: periodo de SCL fuera de +/-10% para ~400 kHz (esp. 2.52 us)"
      severity failure;
    assert bus_busy = '0'
      report "T1: bus_busy no regreso a 0 tras el STOP" severity failure;
    assert xact_open = '0'
      report "T1: xact_open no se limpio tras el STOP" severity failure;

    ------------------------------------------------------------------ T2
    report "T2: direccion inexistente (0x60) -> NACK + STOP puro (NOBYTE)";
    wr('1', '0', x"C0");
    assert ack_in = '1'
      report "T2: se esperaba NACK de una direccion sin esclavo" severity failure;
    cmd('0', '1', '0', '0', '1', x"00", got_arb);   -- STOP sin byte
    wait for 1 us;
    assert bus_busy = '0' and scl_x = '1' and sda_x = '1'
      report "T2: el bus no quedo libre tras el STOP" severity failure;
    assert xact_open = '0'
      report "T2: xact_open no se limpio tras el STOP puro" severity failure;

    ------------------------------------------------------------------ T3
    report "T3: lectura EEPROM-style con START repetido";
    wr('1', '0', x"A0");
    wr('0', '0', x"02");                   -- puntero = 2
    wr('1', '0', x"A1");                   -- START repetido, direccion + R
    assert ack_in = '0'
      report "T3: la direccion de lectura no recibio ACK" severity failure;
    rd('0', '0');                          -- leer con ACK
    assert rdata = x"77"
      report "T3: el primer byte leido no es 0x77" severity failure;
    rd('1', '1');                          -- leer con NACK + STOP
    assert rdata = x"88"
      report "T3: el segundo byte leido no es 0x88" severity failure;

    ------------------------------------------------------------------ T4
    report "T4: clock stretching de 30 us tras el ACK de direccion";
    t0 := now;
    wr('1', '0', x"A0");  wr('0', '0', x"05");  wr('0', '1', x"AB");
    t_a := now - t0;
    mdl_stretch <= 30 us;
    wait for 1 us;
    t0 := now;
    wr('1', '0', x"A0");  wr('0', '0', x"06");  wr('0', '1', x"CD");
    t_b := now - t0;
    mdl_stretch <= 0 ns;
    assert (t_b > t_a + 25 us) and (t_b < t_a + 40 us)
      report "T4: el estiramiento no alargo la transaccion ~30 us como se esperaba"
      severity failure;
    wait for 1 us;
    assert mdl_last = x"CD"
      report "T4: el dato bajo stretching no llego al esclavo" severity failure;

    ------------------------------------------------------------------ T5
    report "T5: perdida de arbitraje y recuperacion";
    arb_go <= true;
    cmd('1', '1', '0', '0', '0', x"A0", got_arb);
    assert got_arb
      report "T5: no se detecto la perdida de arbitraje" severity failure;
    wait for 1 ns;
    assert busy = '0' and xact_open = '0'
      report "T5: el motor no quedo ocioso tras perder arbitraje" severity failure;
    assert scl_t = '1' and sda_t = '1'
      report "T5: las lineas no se liberaron tras perder arbitraje"
      severity failure;
    if bus_busy = '1' then
      wait until bus_busy = '0' for 200 us;
    end if;
    assert bus_busy = '0'
      report "T5: bus_busy no bajo tras el STOP del otro maestro" severity failure;
    wr('1', '0', x"A0");  wr('0', '0', x"07");  wr('0', '1', x"5A");
    wait for 1 us;
    assert mdl_last = x"5A"
      report "T5: la recuperacion tras arbitraje fallo" severity failure;

    ------------------------------------------------------------------ T6
    report "T6: comando con bus ocupado por otro maestro -> WAITFREE";
    fake_go <= true;
    wait for 5 us;                         -- el maestro ajeno ya arranco
    t0 := now;
    wr('1', '0', x"A0");
    assert now - t0 > 20 us
      report "T6: el motor no espero a que el bus quedara libre" severity failure;
    wr('0', '0', x"08");  wr('0', '1', x"E7");
    wait for 1 us;
    assert mdl_last = x"E7"
      report "T6: el dato tras WAITFREE no llego al esclavo" severity failure;

    ------------------------------------------------------------------ T7
    report "T7: periodo de SCL a 100 kHz (div=249)";
    scl_div <= std_logic_vector(to_unsigned(249, 16));
    wait for 1 us;
    wr('1', '0', x"A0");  wr('0', '1', x"09");
    assert scl_period > 9.0 us and scl_period < 11.0 us
      report "T7: periodo de SCL fuera de +/-10% para 100 kHz (esp. 10 us)"
      severity failure;

    ------------------------------------------------------------------ T8
    report "T8: periodo de SCL a 1 MHz Fm+ (div=24)";
    scl_div <= std_logic_vector(to_unsigned(24, 16));
    wait for 1 us;
    wr('1', '0', x"A0");  wr('0', '1', x"0A");
    assert scl_period > 0.9 us and scl_period < 1.1 us
      report "T8: periodo de SCL fuera de +/-10% para 1 MHz (esp. 1 us)"
      severity failure;

    report "== TODOS LOS TESTS PASARON (T1-T8) ==";
    finish;
  end process;

end architecture sim;
