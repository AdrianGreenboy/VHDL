-- ============================================================================
-- tb_spw_1b.vhd -- Capa 1b: spw_rx contra modelo transmisor bit-bang
-- ============================================================================
-- El modelo transmisor es procedural, cero codigo compartido con el RTL:
-- mantiene su propio estado de linea D/S, su propia cadena de paridad, y
-- genera cada bit con la regla DS (exactamente una transicion por bit,
-- sostenida el periodo completo -- leccion del sincronizador 2FF).
-- Corrupciones inyectadas: paridad invertida, ESC+ESC, ESC+EOP,
-- desconexion (silencio > 850 ns), y caida de rxen a mitad de caracter.
-- Fases:
--   A: silencio previo sin desconexion + sincronizacion con primer NULL
--   B: trafico valido exacto (NULL/DATA/EOP/EEP/FCT/TIME)
--   C: paridad corrupta -> err_par + HALT (ignora trafico valido posterior)
--   D: ESC+ESC y ESC+EOP -> err_esc
--   E: desconexion -> err_disc en ventana de 850 ns, y no antes
--   F: caida de rxen a mitad de caracter sin efectos espurios
--   G: trafico a 50 Mbit/s (periodo 20 ns)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spw_1b is
end entity tb_spw_1b;

architecture tb of tb_spw_1b is

  constant K_NULL : integer := 0;
  constant K_FCT  : integer := 1;
  constant K_EOP  : integer := 2;
  constant K_EEP  : integer := 3;
  constant K_DATA : integer := 4;
  constant K_TIME : integer := 5;
  constant K_ERRP : integer := 6;
  constant K_ERRE : integer := 7;
  constant K_ERRD : integer := 8;

  type tok_t is record
    kind : integer;
    data : std_logic_vector(7 downto 0);
  end record;
  type tok_arr_t is array (0 to 1023) of tok_t;

  signal toks    : tok_arr_t := (others => (kind => -1, data => (others => '0')));
  signal tok_cnt : integer   := 0;

  signal clk        : std_logic := '0';
  signal arstn      : std_logic := '0';
  signal en         : std_logic := '0';
  signal rxen       : std_logic := '0';
  signal din        : std_logic := '0';
  signal sin        : std_logic := '0';
  signal first_null : std_logic;
  signal got_null   : std_logic;
  signal got_fct    : std_logic;
  signal got_time   : std_logic;
  signal time_out   : std_logic_vector(7 downto 0);
  signal rx_we      : std_logic;
  signal rx_data    : std_logic_vector(8 downto 0);
  signal err_par    : std_logic;
  signal err_esc    : std_logic;
  signal err_disc   : std_logic;

  signal done : boolean := false;

begin

  clk <= not clk after 5 ns when not done else '0';

  dut : entity work.spw_rx
    generic map (DISC_CYCLES => 85)
    port map (
      clk        => clk,
      arstn      => arstn,
      en         => en,
      rxen       => rxen,
      din        => din,
      sin        => sin,
      first_null => first_null,
      got_null   => got_null,
      got_fct    => got_fct,
      got_time   => got_time,
      time_out   => time_out,
      rx_we      => rx_we,
      rx_data    => rx_data,
      err_par    => err_par,
      err_esc    => err_esc,
      err_disc   => err_disc
    );

  -- watchdog global
  watchdog : process
  begin
    wait for 5 ms;
    assert false report "FALLO: timeout global del testbench" severity failure;
  end process watchdog;

  -- ==========================================================================
  -- Monitor: captura los pulsos del DUT como tokens ordenados
  -- ==========================================================================
  monitor : process (clk)
    variable wcnt : integer := 0;
    procedure push (constant k : in integer;
                    constant d : in std_logic_vector(7 downto 0)) is
    begin
      toks(wcnt mod 1024) <= (kind => k, data => d);
      wcnt                := wcnt + 1;
      tok_cnt             <= wcnt;
    end procedure;
  begin
    if rising_edge(clk) then
      if got_null = '1' then push(K_NULL, x"00"); end if;
      if got_fct = '1' then push(K_FCT, x"00"); end if;
      if rx_we = '1' then
        if rx_data(8) = '0' then
          push(K_DATA, rx_data(7 downto 0));
        elsif rx_data(0) = '0' then
          push(K_EOP, x"00");
        else
          push(K_EEP, x"00");
        end if;
      end if;
      if got_time = '1' then push(K_TIME, time_out); end if;
      if err_par = '1' then push(K_ERRP, x"00"); end if;
      if err_esc = '1' then push(K_ERRE, x"00"); end if;
      if err_disc = '1' then push(K_ERRD, x"00"); end if;
    end if;
  end process monitor;

  -- ==========================================================================
  -- Estimulo: transmisor bit-bang procedural con corrupciones
  -- ==========================================================================
  stim : process
    variable rd  : integer   := 0;
    variable vd  : std_logic := '0';   -- estado de linea D del modelo
    variable vs  : std_logic := '0';   -- estado de linea S del modelo
    variable acc : std_logic := '0';   -- cadena de paridad del modelo
    variable bp  : time      := 100 ns;
    variable t0  : time;

    -- un bit DS: exactamente una transicion, sostenida el periodo completo
    procedure bb_bit (constant b : in std_logic) is
    begin
      if b /= vd then
        vd  := b;
        din <= vd;
      else
        vs  := not vs;
        sin <= vs;
      end if;
      wait for bp;
    end procedure;

    -- un caracter completo con paridad propia del modelo
    procedure bb_char (constant f        : in std_logic;
                       constant pay      : in std_logic_vector(7 downto 0);
                       constant plen     : in integer;
                       constant flip_par : in boolean := false) is
      variable p : std_logic;
      variable a : std_logic;
    begin
      p := not (acc xor f);
      if flip_par then
        p := not p;
      end if;
      bb_bit(p);
      bb_bit(f);
      a := '0';
      for i in 0 to plen - 1 loop
        bb_bit(pay(i));
        a := a xor pay(i);
      end loop;
      acc := a;
    end procedure;

    procedure bb_fct  is begin bb_char('1', x"00", 2); end procedure;
    procedure bb_eop  is begin bb_char('1', "00000010", 2); end procedure;
    procedure bb_eep  is begin bb_char('1', "00000001", 2); end procedure;
    procedure bb_esc  is begin bb_char('1', "00000011", 2); end procedure;
    procedure bb_null is begin bb_esc; bb_fct; end procedure;
    procedure bb_data (constant v : in std_logic_vector(7 downto 0);
                       constant flip_par : in boolean := false) is
    begin
      bb_char('0', v, 8, flip_par);
    end procedure;
    procedure bb_time (constant v : in std_logic_vector(7 downto 0)) is
    begin
      bb_esc;
      bb_char('0', v, 8);
    end procedure;

    -- rearme del enlace: rxen abajo/arriba y cadena de paridad del modelo a cero
    procedure relink is
    begin
      wait until rising_edge(clk);
      rxen <= '0';
      wait for 100 ns;
      wait until rising_edge(clk);
      rxen <= '1';
      acc  := '0';
      wait until rising_edge(clk);
    end procedure;

    -- verificacion exacta (en 1b no se salta nada: el modelo sabe que envio)
    procedure expect_tok (constant k : in integer;
                          constant d : in std_logic_vector(7 downto 0) := x"00") is
      variable tk : tok_t;
    begin
      while tok_cnt <= rd loop
        wait on tok_cnt;
      end loop;
      tk := toks(rd mod 1024);
      rd := rd + 1;
      assert tk.kind = k
        report "FALLO: token inesperado" severity failure;
      if k = K_DATA or k = K_TIME then
        assert tk.data = d
          report "FALLO: dato inesperado" severity failure;
      end if;
    end procedure;

    procedure expect_quiet is
    begin
      assert tok_cnt = rd
        report "FALLO: tokens espurios" severity failure;
    end procedure;

  begin
    arstn <= '0';
    wait for 100 ns;
    wait until rising_edge(clk);
    arstn <= '1';
    en    <= '1';
    wait until rising_edge(clk);

    -- FASE A: silencio previo sin desconexion + primer NULL
    rxen <= '1';
    wait for 2 us;
    expect_quiet;                        -- sin primer NULL no hay err_disc
    assert first_null = '0'
      report "FALLO: first_null antes de tiempo" severity failure;
    bp := 100 ns;
    bb_null;
    bb_null;
    expect_tok(K_NULL);
    expect_tok(K_NULL);
    wait until rising_edge(clk);
    assert first_null = '1'
      report "FALLO: first_null no se ha fijado" severity failure;
    report "FASE A OK: sincronizacion con primer NULL";

    -- FASE B: trafico valido exacto
    bb_data(x"A5");
    bb_null;
    bb_data(x"3C");
    bb_eop;
    bb_eep;
    bb_fct;
    bb_time(x"7E");
    bb_null;
    expect_tok(K_DATA, x"A5");
    expect_tok(K_NULL);
    expect_tok(K_DATA, x"3C");
    expect_tok(K_EOP);
    expect_tok(K_EEP);
    expect_tok(K_FCT);
    expect_tok(K_TIME, x"7E");
    expect_tok(K_NULL);
    report "FASE B OK: trafico valido";

    -- FASE C: paridad corrupta -> err_par + HALT
    bb_data(x"11", flip_par => true);
    expect_tok(K_ERRP);
    bb_data(x"22");                      -- valido, debe ignorarse en HALT
    wait for 500 ns;
    expect_quiet;
    relink;
    bb_null;
    bb_data(x"33");
    expect_tok(K_NULL);
    expect_tok(K_DATA, x"33");
    report "FASE C OK: err_par y HALT hasta rearme";

    -- FASE D: errores de escape
    bb_esc;
    bb_esc;
    expect_tok(K_ERRE);
    relink;
    bb_null;
    expect_tok(K_NULL);
    bb_esc;
    bb_eop;
    expect_tok(K_ERRE);
    relink;
    bb_null;
    expect_tok(K_NULL);
    report "FASE D OK: ESC+ESC y ESC+EOP -> err_esc";

    -- FASE E: desconexion tras 850 ns de silencio
    t0 := now;
    expect_tok(K_ERRD);
    assert (now - t0) > 600 ns and (now - t0) < 1000 ns
      report "FALLO: desconexion fuera de ventana" severity failure;
    relink;
    bb_null;
    expect_tok(K_NULL);
    report "FASE E OK: err_disc en ventana de 850 ns";

    -- FASE F: caida de rxen a mitad de caracter
    bb_bit('1');                         -- P valido (acc=0, flag=0 -> P=1)
    bb_bit('0');                         -- flag de dato
    bb_bit('1');                         -- primer bit de payload
    wait until rising_edge(clk);
    rxen <= '0';
    wait for 300 ns;
    expect_quiet;
    assert first_null = '0'
      report "FALLO: first_null no se limpia con rxen" severity failure;
    wait until rising_edge(clk);
    rxen <= '1';
    acc  := '0';
    wait until rising_edge(clk);
    report "FASE F OK: caida de rxen sin efectos espurios";

    -- FASE G: trafico a 50 Mbit/s
    bp := 20 ns;
    bb_null;
    bb_null;
    bb_data(x"C3");
    bb_time(x"55");
    bb_eop;
    bb_null;
    expect_tok(K_NULL);
    expect_tok(K_NULL);
    expect_tok(K_DATA, x"C3");
    expect_tok(K_TIME, x"55");
    expect_tok(K_EOP);
    expect_tok(K_NULL);
    report "FASE G OK: trafico a 50 Mbit/s";

    report "CAPA 1b PASS";
    done <= true;
    wait for 1 ns;
    finish;
  end process stim;

end architecture tb;
