-- tb_m1553_1a.vhd
-- Capa 1a: motor TX del 1553 contra un MODELO RECEPTOR INDEPENDIENTE por
-- eventos. Cero codigo compartido con el RTL: el modelo muestrea el bus por
-- tiempos absolutos (mitad de cada semibit), decodifica sync/bits/paridad por
-- su cuenta y compara contra la tabla esperada.
-- Vigilante de cable independiente: transiciones solo en rejilla de 500 ns,
-- tx_en con duracion multiplo exacto de palabra (20 us), bus en reposo a '0'.
-- Mensajes de FALLO sin tildes (GHDL rechaza no-ASCII en asserts).

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
