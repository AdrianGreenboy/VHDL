-- tb_m1553_1a.vhd
-- Capa 1a: motor TX del 1553 contra un MODELO RECEPTOR INDEPENDIENTE por
-- eventos. Cero codigo compartido con el RTL: el modelo muestrea el bus por
-- tiempos absolutos (mitad de cada semibit), decodifica sync/bits/paridad por
-- su cuenta y compara contra la tabla esperada.
-- Vigilante de cable independiente: transiciones solo en rejilla de 500 ns,
-- tx_en con duracion multiplo exacto de palabra (20 us), bus en reposo a '0'.
-- Mensajes de FALLO sin tildes (GHDL rechaza no-ASCII en asserts).
-- Audit 2026-11: a second instance (u_fs, FS_TIMEOUT = 5000 cycles) checks
-- the fail-safe transmitter timer (continuous transmission cut at exactly
-- FS_TIMEOUT cycles, sticky fault, no restart until rst) and the abort
-- input. Its stimulus runs in parallel and must finish before the end.

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_m1553_1a is
end entity tb_m1553_1a;

architecture sim of tb_m1553_1a is

  constant T_CLK  : time := 10 ns;    -- 100 MHz
  constant T_HALF : time := 500 ns;   -- semibit a 1 Mbit/s
  constant T_WORD : time := 20 us;    -- 20 tiempos de bit

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal start     : std_logic := '0';
  signal word_type : std_logic := '0';
  signal data      : std_logic_vector(15 downto 0) := (others => '0');
  signal busy      : std_logic;
  signal tx_en     : std_logic;
  signal tx_data   : std_logic;

  signal rx_count  : integer := 0;

  -- fail-safe / abort instance
  constant FS_T    : integer := 5000;          -- 50 us at 100 MHz
  signal fs_rst    : std_logic := '1';
  signal fs_start  : std_logic := '0';
  signal fs_abort  : std_logic := '0';
  signal fs_busy, fs_txen, fs_txd, fs_flt : std_logic;
  signal fs_done   : boolean := false;

  constant NWORDS : integer := 14;

  type t_words is array (natural range <>) of std_logic_vector(15 downto 0);
  -- 8 palabras sueltas + rafaga de 4 encadenadas + rafaga de 2 encadenadas
  constant EXP_DATA : t_words(0 to NWORDS-1) := (
    x"0000", x"FFFF", x"5555", x"AAAA", x"8001", x"7FFE", x"1234", x"EDCB",
    x"C0DE", x"0001", x"BEEF", x"F00D",
    x"CAFE", x"1553");
  -- '1' = sync de command/status, '0' = sync de data
  constant EXP_TYPE : std_logic_vector(0 to NWORDS-1) := "10101010" & "1000" & "10";

  type t_gaps is array (natural range <>) of time;
  constant GAPS : t_gaps(0 to 7) :=
    (5 us, 4 us, 6 us, 4500 ns, 7 us, 4 us, 5500 ns, 8 us);

begin

  clk <= not clk after T_CLK/2;

  dut : entity work.m1553_word_tx
    port map (
      clk => clk, rst => rst,
      start => start, word_type => word_type, data => data,
      busy => busy, tx_en => tx_en, tx_data => tx_data);

  u_fs : entity work.m1553_word_tx
    generic map (FS_TIMEOUT => FS_T)
    port map (
      clk => clk, rst => fs_rst,
      start => fs_start, word_type => '0', data => x"A5A5",
      busy => fs_busy, abort => fs_abort, fs_fault => fs_flt,
      tx_en => fs_txen, tx_data => fs_txd);

  ------------------------------------------------------------------
  -- Fail-safe timer and abort (independent checker by absolute time)
  ------------------------------------------------------------------
  fs_stim : process
    variable t_on, t_off : time;
  begin
    fs_rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    fs_rst <= '0';
    -- continuous transmission: keep a start pending every 10 us
    wait until rising_edge(clk);
    fs_start <= '1';
    wait until rising_edge(clk);
    fs_start <= '0';
    wait until fs_txen = '1';
    t_on := now;
    for i in 1 to 9 loop            -- 90 us of requests (> 50 us limit)
      wait for 10 us;
      wait until rising_edge(clk);
      fs_start <= '1';
      wait until rising_edge(clk);
      fs_start <= '0';
    end loop;
    assert fs_txen = '0' and fs_txd = '0'
      report "FALLO FS: transmision continua no cortada por el temporizador"
      severity failure;
    assert fs_flt = '1'
      report "FALLO FS: fallo fail-safe no registrado" severity failure;
    -- the cut happened exactly FS_T cycles after tx_en rose
    t_off := t_on + FS_T * T_CLK;
    -- (checked by the monitor below)
    -- more requests: the output must stay off (sticky)
    for i in 1 to 4 loop
      wait for 10 us;
      wait until rising_edge(clk);
      fs_start <= '1';
      wait until rising_edge(clk);
      fs_start <= '0';
      assert fs_txen = '0' and fs_flt = '1'
        report "FALLO FS: el transmisor rearranco sin re-habilitacion"
        severity failure;
    end loop;
    wait for 30 us;
    -- explicit re-enable (reset) clears the fault; one word goes out normally
    wait until rising_edge(clk);
    fs_rst <= '1';
    wait until rising_edge(clk);
    fs_rst <= '0';
    wait until rising_edge(clk);
    assert fs_flt = '0'
      report "FALLO FS: el fallo no se limpio con la re-habilitacion"
      severity failure;
    fs_start <= '1';
    wait until rising_edge(clk);
    fs_start <= '0';
    wait until fs_txen = '1';
    t_on := now;
    wait until fs_txen = '0';
    assert now - t_on = T_WORD
      report "FALLO FS: palabra tras re-habilitacion de duracion incorrecta"
      severity failure;
    -- abort mid-word: line quiet on the next cycle, nothing pending
    wait for 5 us;
    wait until rising_edge(clk);
    fs_start <= '1';
    wait until rising_edge(clk);
    fs_start <= '0';
    wait for 7 us;
    wait until rising_edge(clk);
    fs_start <= '1';                -- pending second word
    fs_abort <= '1';
    wait until rising_edge(clk);
    fs_start <= '0';
    fs_abort <= '0';
    wait until rising_edge(clk);
    assert fs_txen = '0' and fs_busy = '0'
      report "FALLO FS: abort no detuvo la palabra en curso"
      severity failure;
    wait for 30 us;
    assert fs_txen = '0'
      report "FALLO FS: palabra pendiente emitida tras abort" severity failure;
    fs_done <= true;
    wait;
  end process;

  fs_mon : process
    variable t_on : time;
  begin
    wait until fs_txen = '1';
    t_on := now;
    wait until fs_txen = '0';
    assert now - t_on = FS_T * T_CLK
      report "FALLO FS: corte fail-safe fuera de FS_TIMEOUT ciclos"
      severity failure;
    wait;
  end process;

  ------------------------------------------------------------------
  -- Estimulo
  ------------------------------------------------------------------
  stim : process
    procedure send(wt : std_logic; d : std_logic_vector(15 downto 0)) is
    begin
      wait until rising_edge(clk);
      start <= '1'; word_type <= wt; data <= d;
      wait until rising_edge(clk);
      start <= '0';
    end procedure;
  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 1 us;

    -- fase A: 8 palabras sueltas con huecos variados
    for i in 0 to 7 loop
      send(EXP_TYPE(i), EXP_DATA(i));
      wait for T_WORD + GAPS(i);
    end loop;

    -- fase B: rafaga de 4 palabras contiguas (command + 3 data),
    -- el start de la siguiente se pulsa a mitad de la palabra en curso
    send(EXP_TYPE(8), EXP_DATA(8));
    wait for 10 us;
    send(EXP_TYPE(9), EXP_DATA(9));
    wait for 20 us;
    send(EXP_TYPE(10), EXP_DATA(10));
    wait for 20 us;
    send(EXP_TYPE(11), EXP_DATA(11));
    wait for 20 us;      -- mitad de la ultima palabra
    wait for 25 us;      -- fin de rafaga + hueco

    -- fase C: rafaga de 2 palabras contiguas (status + 1 data)
    send(EXP_TYPE(12), EXP_DATA(12));
    wait for 10 us;
    send(EXP_TYPE(13), EXP_DATA(13));
    wait for 40 us;

    -- cierre
    wait for 50 us;
    if not fs_done then
      wait until fs_done;
    end if;
    assert rx_count = NWORDS
      report "FALLO: cuenta de palabras recibidas incorrecta"
      severity failure;
    assert busy = '0' and tx_en = '0'
      report "FALLO: el motor no quedo en reposo"
      severity failure;
    report "M1553 CAPA 1A PASS";
    finish;
  end process;

  ------------------------------------------------------------------
  -- Modelo receptor independiente por eventos (tiempos absolutos)
  ------------------------------------------------------------------
  rx_model : process
    procedure wait_abs(t : time) is
    begin
      if t > now then
        wait for t - now;
      end if;
    end procedure;

    variable base   : time;
    variable k      : integer;                    -- palabra dentro de la rafaga
    variable smp    : std_logic_vector(0 to 39);  -- muestra a mitad de cada semibit
    variable bits   : std_logic_vector(15 downto 0);
    variable par    : std_logic;
    variable acc    : std_logic;
    variable is_cmd : boolean;
    variable cont   : boolean := false;
    variable widx   : integer := 0;
  begin
    while widx < NWORDS loop
      if not cont then
        wait until tx_en = '1';
        base := now;
        k    := 0;
      end if;

      -- muestreo por tiempos absolutos: mitad de cada semibit
      for h in 0 to 39 loop
        wait_abs(base + k*T_WORD + h*T_HALF + T_HALF/2);
        smp(h) := tx_data;
      end loop;

      -- decodificacion del sync (patron de 3 tiempos de bit)
      if smp(0 to 5) = "111000" then
        is_cmd := true;
      elsif smp(0 to 5) = "000111" then
        is_cmd := false;
      else
        report "FALLO: sync invalido en palabra " & integer'image(widx)
          severity failure;
      end if;

      -- 16 bits de dato, MSB primero, y validez Manchester
      for b in 0 to 15 loop
        assert smp(6 + 2*b) /= smp(7 + 2*b)
          report "FALLO: semibits sin transicion (Manchester) en palabra "
                 & integer'image(widx)
          severity failure;
        bits(15 - b) := smp(6 + 2*b);   -- '1' = alto->bajo
      end loop;

      -- paridad impar
      assert smp(38) /= smp(39)
        report "FALLO: bit de paridad sin transicion en palabra "
               & integer'image(widx)
        severity failure;
      par := smp(38);
      acc := par;
      for b in 0 to 15 loop
        acc := acc xor bits(b);
      end loop;
      assert acc = '1'
        report "FALLO: paridad no impar en palabra " & integer'image(widx)
        severity failure;

      -- comparacion contra lo esperado
      assert is_cmd = (EXP_TYPE(widx) = '1')
        report "FALLO: tipo de sync inesperado en palabra " & integer'image(widx)
        severity failure;
      assert bits = EXP_DATA(widx)
        report "FALLO: dato inesperado en palabra " & integer'image(widx)
        severity failure;

      widx := widx + 1;
      rx_count <= widx;

      -- frontera de palabra: 100 ns dentro de la siguiente ranura
      wait_abs(base + (k+1)*T_WORD + 100 ns);
      if tx_en = '1' then
        cont := true;
        k := k + 1;
      else
        cont := false;
      end if;
    end loop;
    wait;
  end process;

  ------------------------------------------------------------------
  -- Vigilante de cable independiente
  ------------------------------------------------------------------
  -- transiciones solo en la rejilla de 500 ns y tx_en multiplo de palabra
  wd_word : process
    variable base : time;
  begin
    wait until tx_en = '1';
    base := now;
    loop
      wait on tx_data, tx_en;
      if tx_en = '0' then
        assert ((now - base) mod T_WORD) = 0 fs and (now - base) > 0 fs
          report "FALLO: duracion de tx_en no es multiplo de palabra"
          severity failure;
        exit;
      else
        assert ((now - base) mod T_HALF) = 0 fs
          report "FALLO: transicion Manchester fuera de rejilla"
          severity failure;
      end if;
    end loop;
  end process;

  -- el bus reposa a '0' cuando no se transmite
  wd_idle : process(tx_data, tx_en)
  begin
    if tx_en = '0' then
      assert tx_data = '0'
        report "FALLO: tx_data activo con tx_en=0"
        severity failure;
    end if;
  end process;

end architecture sim;
