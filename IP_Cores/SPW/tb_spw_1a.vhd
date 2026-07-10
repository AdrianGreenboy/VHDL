-- ============================================================================
-- tb_spw_1a.vhd -- Capa 1a: spw_tx contra modelo receptor independiente
-- ============================================================================
-- El modelo NO comparte codigo con el RTL:
--   * despierta por eventos en D/S y recupera cada bit (reloj = D xor S)
--   * verifica que NUNCA transicionan D y S a la vez
--   * verifica el periodo de bit por tiempos absolutos (div * 10 ns exacto)
--   * se sincroniza buscando el patron del primer NULL "01110100"
--   * recalcula la paridad impar por su cuenta y clasifica caracteres con
--     su propio estado ESC (NULL=ESC+FCT, TIME=ESC+dato)
-- Fases:
--   A: NULLs continuos a 10 Mbit/s          B: FCTs bajo peticion
--   C: datos, EOP, EEP                       D: Time-Codes y prioridad
--   E: gating de N-Chars con allow_nchar     F: re-arranque a 50 Mbit/s
--   G: deshabilitacion en mitad de caracter y silencio en D/S
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spw_1a is
end entity tb_spw_1a;

architecture tb of tb_spw_1a is

  constant K_NULL : integer := 0;
  constant K_FCT  : integer := 1;
  constant K_EOP  : integer := 2;
  constant K_EEP  : integer := 3;
  constant K_DATA : integer := 4;
  constant K_TIME : integer := 5;

  type tok_t is record
    kind : integer;
    data : std_logic_vector(7 downto 0);
  end record;
  type tok_arr_t is array (0 to 1023) of tok_t;

  signal toks    : tok_arr_t := (others => (kind => -1, data => (others => '0')));
  signal tok_cnt : integer   := 0;

  signal clk         : std_logic := '0';
  signal arstn       : std_logic := '0';
  signal en          : std_logic := '0';
  signal txen        : std_logic := '0';
  signal allow_fct   : std_logic := '0';
  signal allow_nchar : std_logic := '0';
  signal div         : std_logic_vector(7 downto 0) := x"0A";
  signal fct_req     : std_logic := '0';
  signal fct_ack     : std_logic;
  signal time_req    : std_logic := '0';
  signal time_val    : std_logic_vector(7 downto 0) := (others => '0');
  signal time_ack    : std_logic;
  signal d_valid     : std_logic := '0';
  signal d_data      : std_logic_vector(8 downto 0) := (others => '0');
  signal d_ack       : std_logic;
  signal dout        : std_logic;
  signal sout        : std_logic;

  signal mon_en  : std_logic := '0';
  signal bitper  : time      := 100 ns;
  signal bad_ack : std_logic := '0';
  signal done    : boolean   := false;

begin

  clk <= not clk after 5 ns when not done else '0';

  dut : entity work.spw_tx
    port map (
      clk         => clk,
      arstn       => arstn,
      en          => en,
      div         => div,
      txen        => txen,
      allow_fct   => allow_fct,
      allow_nchar => allow_nchar,
      fct_req     => fct_req,
      fct_ack     => fct_ack,
      time_req    => time_req,
      time_val    => time_val,
      time_ack    => time_ack,
      d_valid     => d_valid,
      d_data      => d_data,
      d_ack       => d_ack,
      dout        => dout,
      sout        => sout
    );

  -- vigilancia: d_ack jamas debe pulsar con allow_nchar bajo
  watch_ack : process (clk)
  begin
    if rising_edge(clk) then
      if d_ack = '1' and allow_nchar = '0' then
        bad_ack <= '1';
      end if;
    end if;
  end process watch_ack;

  -- watchdog global
  watchdog : process
  begin
    wait for 5 ms;
    assert false report "FALLO: timeout global del testbench" severity failure;
  end process watchdog;

  -- ==========================================================================
  -- Modelo receptor independiente por eventos
  -- ==========================================================================
  model : process
    variable b, p, f, b1, b2 : std_logic;
    variable pay             : std_logic_vector(7 downto 0);
    variable acc             : std_logic;
    variable sh              : std_logic_vector(7 downto 0);
    variable synced, esc     : boolean;
    variable abortv          : boolean;
    variable t_prev          : time;
    variable have_prev       : boolean;
    variable wcnt            : integer := 0;

    procedure push (constant k : in integer;
                    constant d : in std_logic_vector(7 downto 0)) is
    begin
      toks(wcnt mod 1024) <= (kind => k, data => d);
      wcnt                := wcnt + 1;
      tok_cnt             <= wcnt;
    end procedure;

    procedure get_bit (variable bo : out std_logic) is
    begin
      if abortv then
        bo := '0';
        return;
      end if;
      wait on dout, sout, mon_en;
      if mon_en = '0' then
        abortv := true;
        bo     := '0';
        return;
      end if;
      assert not (dout'event and sout'event)
        report "FALLO: transicion simultanea en D y S" severity failure;
      if have_prev then
        assert (now - t_prev) = bitper
          report "FALLO: periodo de bit incorrecto" severity failure;
      end if;
      t_prev    := now;
      have_prev := true;
      bo        := dout;
    end procedure;

  begin
    outer : loop
      abortv    := false;
      synced    := false;
      esc       := false;
      acc       := '0';
      sh        := (others => '0');
      have_prev := false;
      if mon_en /= '1' then
        wait until mon_en = '1';
      end if;

      decode : loop
        if not synced then
          -- caza del primer NULL: P0 ESC(111) P0 F1 0 0
          get_bit(b);
          exit decode when abortv;
          sh := sh(6 downto 0) & b;
          if sh = "01110100" then
            synced := true;
            acc    := '0';               -- payload del FCT del NULL = "00"
            push(K_NULL, x"00");
          end if;
        else
          get_bit(p);
          exit decode when abortv;
          get_bit(f);
          exit decode when abortv;
          assert (acc xor p xor f) = '1'
            report "FALLO: paridad incorrecta en TX" severity failure;
          if f = '1' then
            get_bit(b1);
            exit decode when abortv;
            get_bit(b2);
            exit decode when abortv;
            acc := b1 xor b2;
            if b1 = '0' and b2 = '0' then                 -- FCT
              if esc then
                esc := false;
                push(K_NULL, x"00");
              else
                push(K_FCT, x"00");
              end if;
            elsif b1 = '0' and b2 = '1' then              -- EOP
              assert not esc report "FALLO: EOP tras ESC" severity failure;
              push(K_EOP, x"00");
            elsif b1 = '1' and b2 = '0' then              -- EEP
              assert not esc report "FALLO: EEP tras ESC" severity failure;
              push(K_EEP, x"00");
            else                                          -- ESC
              assert not esc report "FALLO: ESC tras ESC" severity failure;
              esc := true;
            end if;
          else
            acc := '0';
            for i in 0 to 7 loop
              get_bit(b);
              exit decode when abortv;
              pay(i) := b;
              acc    := acc xor b;
            end loop;
            if esc then
              esc := false;
              push(K_TIME, pay);
            else
              push(K_DATA, pay);
            end if;
          end if;
        end if;
      end loop decode;
    end loop outer;
  end process model;

  -- ==========================================================================
  -- Estimulo y verificacion
  -- ==========================================================================
  stim : process
    variable rd : integer := 0;
    variable t0 : time;

    procedure expect_tok (constant k : in integer;
                          constant d : in std_logic_vector(7 downto 0) := x"00") is
      variable tk : tok_t;
    begin
      loop
        while tok_cnt <= rd loop
          wait on tok_cnt;
        end loop;
        tk := toks(rd mod 1024);
        rd := rd + 1;
        if tk.kind = K_NULL and k /= K_NULL then
          null;                                   -- saltar NULLs de relleno
        else
          assert tk.kind = k
            report "FALLO: tipo de caracter inesperado" severity failure;
          if k = K_DATA or k = K_TIME then
            assert tk.data = d
              report "FALLO: dato inesperado" severity failure;
          end if;
          exit;
        end if;
      end loop;
    end procedure;

    procedure expect_nulls (constant n : in integer) is
      variable tk : tok_t;
    begin
      for i in 1 to n loop
        while tok_cnt <= rd loop
          wait on tok_cnt;
        end loop;
        tk := toks(rd mod 1024);
        rd := rd + 1;
        assert tk.kind = K_NULL
          report "FALLO: se esperaba NULL" severity failure;
      end loop;
    end procedure;

    procedure send_d (constant v : in std_logic_vector(8 downto 0)) is
    begin
      d_data  <= v;
      d_valid <= '1';
      loop
        wait until rising_edge(clk);
        exit when d_ack = '1';
      end loop;
      d_valid <= '0';
    end procedure;

  begin
    arstn <= '0';
    wait for 100 ns;
    wait until rising_edge(clk);
    arstn <= '1';
    en    <= '1';
    div   <= x"0A";
    bitper <= 100 ns;
    wait until rising_edge(clk);

    -- FASE A: NULLs continuos a 10 Mbit/s
    mon_en <= '1';
    txen   <= '1';
    expect_nulls(5);
    report "FASE A OK: NULLs continuos a 10 Mbit/s";

    -- FASE B: FCTs bajo peticion, con NULLs de relleno entre medias
    allow_fct <= '1';
    for i in 1 to 3 loop
      fct_req <= '1';
      loop
        wait until rising_edge(clk);
        exit when fct_ack = '1';
      end loop;
      fct_req <= '0';
      expect_tok(K_FCT);
    end loop;
    report "FASE B OK: FCTs bajo peticion";

    -- FASE C: datos, EOP y EEP
    allow_nchar <= '1';
    send_d('0' & x"AA");  expect_tok(K_DATA, x"AA");
    send_d('0' & x"55");  expect_tok(K_DATA, x"55");
    send_d('0' & x"0F");  expect_tok(K_DATA, x"0F");
    send_d("100000000");  expect_tok(K_EOP);
    send_d("100000001");  expect_tok(K_EEP);
    report "FASE C OK: N-Chars, EOP y EEP";

    -- FASE D: Time-Code y prioridad TIME > FCT > DATA
    time_val <= x"3C";
    time_req <= '1';
    loop
      wait until rising_edge(clk);
      exit when time_ack = '1';
    end loop;
    time_req <= '0';
    expect_tok(K_TIME, x"3C");

    time_val <= x"91";
    d_data   <= '0' & x"77";
    time_req <= '1';
    fct_req  <= '1';
    d_valid  <= '1';
    loop
      wait until rising_edge(clk);
      exit when time_ack = '1';
    end loop;
    time_req <= '0';
    loop
      wait until rising_edge(clk);
      exit when fct_ack = '1';
    end loop;
    fct_req <= '0';
    loop
      wait until rising_edge(clk);
      exit when d_ack = '1';
    end loop;
    d_valid <= '0';
    expect_tok(K_TIME, x"91");
    expect_tok(K_FCT);
    expect_tok(K_DATA, x"77");
    report "FASE D OK: Time-Codes y prioridad TIME > FCT > DATA";

    -- FASE E: gating de N-Chars (dato pendiente sin allow_nchar -> solo NULLs)
    allow_nchar <= '0';
    d_data      <= '0' & x"5A";
    d_valid     <= '1';
    expect_nulls(4);
    assert bad_ack = '0'
      report "FALLO: d_ack con allow_nchar bajo" severity failure;
    allow_nchar <= '1';
    loop
      wait until rising_edge(clk);
      exit when d_ack = '1';
    end loop;
    d_valid <= '0';
    expect_tok(K_DATA, x"5A");
    report "FASE E OK: gating de N-Chars por allow_nchar";

    -- FASE F: parada limpia y re-arranque a 50 Mbit/s
    mon_en <= '0';
    wait until rising_edge(clk);
    txen <= '0';
    wait for 500 ns;
    div    <= x"02";
    bitper <= 20 ns;
    wait until rising_edge(clk);
    txen   <= '1';
    mon_en <= '1';
    expect_nulls(3);
    send_d('0' & x"C3");
    expect_tok(K_DATA, x"C3");
    report "FASE F OK: re-arranque a 50 Mbit/s";

    -- FASE G: deshabilitar en mitad de caracter -> D/S a cero y silencio
    mon_en <= '0';
    wait until rising_edge(clk);
    en <= '0';
    wait for 50 ns;
    assert dout = '0' and sout = '0'
      report "FALLO: D/S no vuelven a cero al deshabilitar" severity failure;
    t0 := now;
    wait on dout, sout for 2 us;
    assert (now - t0) = 2 us
      report "FALLO: actividad en D/S tras deshabilitar" severity failure;
    report "FASE G OK: deshabilitacion limpia y silencio";

    report "CAPA 1a PASS";
    done <= true;
    wait for 1 ns;
    finish;
  end process stim;

end architecture tb;
