-- tb_m1553_1b.vhd
-- Capa 1b: motor RX del 1553 contra un MODELO TRANSMISOR BIT-BANG procedural
-- (cero codigo compartido: codifica Manchester con waits absolutos y calcula
-- la paridad por su cuenta), con corrupciones:
--   paridad rota, sync invalido (segunda mitad), error Manchester (celda sin
--   transicion, sosteniendo el nivel ofensivo hasta el final del bit -
--   leccion del sincronizador 2FF), palabra truncada, data word AISLADA
--   (debe ignorarse: su sync se funde con el idle), tasa 20% rapida (debe
--   ignorarse) y glitch corto de bus.
-- Cada caso comprueba los DELTAS exactos de valid/err_sync/err_manch/err_par.
-- Mensajes de FALLO sin tildes.

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_m1553_1b is
end entity tb_m1553_1b;

architecture sim of tb_m1553_1b is

  constant T_CLK  : time := 10 ns;
  constant T_HALF : time := 500 ns;

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';
  signal line : std_logic := '0';

  signal valid, err_sync, err_manch, err_par, busy : std_logic;
  signal o_wt   : std_logic;
  signal o_data : std_logic_vector(15 downto 0);

  -- contadores del monitor
  signal n_valid, n_es, n_em, n_ep : integer := 0;
  signal last_wt   : std_logic := '0';
  signal last_data : std_logic_vector(15 downto 0) := (others => '0');

begin

  clk <= not clk after T_CLK/2;

  dut : entity work.m1553_word_rx
    port map (
      clk => clk, rst => rst, rx_data => line,
      valid => valid, word_type => o_wt, data => o_data,
      err_sync => err_sync, err_manch => err_manch, err_par => err_par,
      busy => busy);

  ------------------------------------------------------------------
  -- Monitor de pulsos del DUT
  ------------------------------------------------------------------
  mon : process(clk)
  begin
    if rising_edge(clk) then
      if valid = '1' then
        n_valid   <= n_valid + 1;
        last_wt   <= o_wt;
        last_data <= o_data;
      end if;
      if err_sync  = '1' then n_es <= n_es + 1; end if;
      if err_manch = '1' then n_em <= n_em + 1; end if;
      if err_par   = '1' then n_ep <= n_ep + 1; end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Estimulo: transmisor bit-bang independiente + comprobaciones
  ------------------------------------------------------------------
  stim : process
    -- transmisor procedural: sync + 17 celdas Manchester
    procedure tx_word(wt : std_logic; d : std_logic_vector(15 downto 0);
                      corrupt_par : boolean := false;
                      kill_bit    : integer := -1;
                      bad_sync2   : boolean := false;
                      trunc_after : integer := -1;
                      halfbit     : time    := T_HALF) is
      variable v : std_logic_vector(16 downto 0);
      variable p : std_logic := '1';
      variable b : std_logic;
    begin
      -- paridad impar calculada por el modelo (independiente del RTL)
      for i in 0 to 15 loop
        p := p xor d(i);
      end loop;
      if corrupt_par then
        p := not p;
      end if;
      v := d & p;

      -- sync: 1.5 bits a wt + 1.5 bits a not wt
      line <= wt;
      wait for 3*halfbit;
      if bad_sync2 then
        -- segunda mitad rota: 0.5 bits a not wt y vuelta a wt, luego reposo
        line <= not wt; wait for halfbit;
        line <= wt;     wait for 2*halfbit;
        line <= '0';
        return;
      end if;
      line <= not wt;
      wait for 3*halfbit;

      -- 17 celdas (16 datos MSB primero + paridad)
      for k in 0 to 16 loop
        if trunc_after >= 0 and k >= trunc_after then
          exit;
        end if;
        b := v(16 - k);
        if k = kill_bit then
          -- error Manchester: nivel sostenido TODA la celda (leccion 2FF:
          -- sostener el bit ofensivo hasta el final antes de soltar)
          line <= b;
          wait for 2*halfbit;
        else
          line <= b;     wait for halfbit;
          line <= not b; wait for halfbit;
        end if;
      end loop;
      line <= '0';                      -- reposo
    end procedure;

    -- snapshot y comprobacion de deltas exactos
    variable s_v, s_es, s_em, s_ep : integer;

    procedure snap is
    begin
      s_v := n_valid; s_es := n_es; s_em := n_em; s_ep := n_ep;
    end procedure;

    procedure chk(caso : string;
                  dv, des, dem, dep : integer) is
    begin
      assert n_valid - s_v = dv
        report "FALLO caso " & caso & ": delta de valid incorrecto"
        severity failure;
      assert n_es - s_es = des
        report "FALLO caso " & caso & ": delta de err_sync incorrecto"
        severity failure;
      assert n_em - s_em = dem
        report "FALLO caso " & caso & ": delta de err_manch incorrecto"
        severity failure;
      assert n_ep - s_ep = dep
        report "FALLO caso " & caso & ": delta de err_par incorrecto"
        severity failure;
    end procedure;

    procedure chk_word(caso : string; wt : std_logic;
                       d : std_logic_vector(15 downto 0)) is
    begin
      assert last_wt = wt
        report "FALLO caso " & caso & ": tipo de palabra incorrecto"
        severity failure;
      assert last_data = d
        report "FALLO caso " & caso & ": dato incorrecto"
        severity failure;
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 5 us;

    -- caso 1: command suelta
    snap;
    tx_word('1', x"1234");
    wait for 5 us;
    chk("1", 1, 0, 0, 0);
    chk_word("1", '1', x"1234");

    -- caso 2: command + data CONTIGUA (la primera mitad del sync de data
    -- se funde con el semibit anterior; debe decodificarse igual)
    snap;
    tx_word('1', x"A5A5");
    tx_word('0', x"0F0F");
    wait for 5 us;
    chk("2", 2, 0, 0, 0);
    chk_word("2", '0', x"0F0F");

    -- caso 3: rafaga command + 3 data contiguas
    snap;
    tx_word('1', x"C0DE");
    tx_word('0', x"DEAD");
    tx_word('0', x"BEEF");
    tx_word('0', x"0001");
    wait for 5 us;
    chk("3", 4, 0, 0, 0);
    chk_word("3", '0', x"0001");

    -- caso 4: paridad corrupta
    snap;
    tx_word('1', x"7777", corrupt_par => true);
    wait for 5 us;
    chk("4", 0, 0, 0, 1);

    -- caso 5: sync invalido (segunda mitad rota)
    snap;
    tx_word('1', x"FFFF", bad_sync2 => true);
    wait for 5 us;
    chk("5", 0, 1, 0, 0);

    -- caso 6: error Manchester en la celda 7 (dato elegido con b6=0 y b8=1
    -- para que la celda muerta no funda una rafaga >= RUN_MIN con sus
    -- vecinas y no aparezca un falso candidato de sync tras el error)
    snap;
    tx_word('1', x"38D6", kill_bit => 7);
    wait for 25 us;
    chk("6", 0, 0, 1, 0);

    -- caso 7: palabra truncada tras 5 celdas
    snap;
    tx_word('1', x"8421", trunc_after => 5);
    wait for 25 us;
    chk("7", 0, 0, 1, 0);

    -- caso 8: data word AISLADA desde reposo: su primera mitad se funde con
    -- el idle (rafaga > RUN_MAX) y NO debe dar valid; con dato 0x0000 el
    -- falso candidato posterior cae en err_sync (determinista)
    snap;
    tx_word('0', x"0000");
    wait for 25 us;
    chk("8", 0, 1, 0, 0);

    -- caso 9: palabra 20% rapida (semibit de 400 ns): rafagas < RUN_MIN,
    -- debe ignorarse por completo (dato con b0=1 para que la segunda mitad
    -- del sync rapido no funda una rafaga >= RUN_MIN con el bit 0)
    snap;
    tx_word('1', x"BC3C", halfbit => 400 ns);
    wait for 25 us;
    chk("9", 0, 0, 0, 0);

    -- caso 10: glitch corto de bus (1 us en alto)
    snap;
    line <= '1';
    wait for 1 us;
    line <= '0';
    wait for 10 us;
    chk("10", 0, 0, 0, 0);

    -- caso 11: recuperacion tras los errores: palabra buena
    snap;
    tx_word('1', x"1553");
    wait for 5 us;
    chk("11", 1, 0, 0, 0);
    chk_word("11", '1', x"1553");

    -- caso 12: dos mensajes con hueco minimo de 4 us
    snap;
    tx_word('1', x"AA55");
    wait for 4 us;
    tx_word('1', x"55AA");
    wait for 5 us;
    chk("12", 2, 0, 0, 0);
    chk_word("12", '1', x"55AA");

    wait for 20 us;
    assert busy = '0'
      report "FALLO: el receptor no quedo en reposo"
      severity failure;
    report "M1553 CAPA 1B PASS";
    finish;
  end process;

end architecture sim;
