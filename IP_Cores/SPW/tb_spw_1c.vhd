-- ============================================================================
-- tb_spw_1c.vhd -- Capa 1c: RTL contra RTL, dos codecs en enlace full-duplex
-- ============================================================================
-- Dout_A -> Din_B, Sout_A -> Sin_B y simetrico (con inyector de corrupcion en
-- la linea D de A->B). A arranca con link_start; B con link_autostart (se
-- prueban ambos caminos de habilitacion del ECSS).
-- Fases:
--   1: bring-up completo ErrorReset->...->Run en ambos extremos, sin errores
--   2: datos full-duplex concurrentes: 100 bytes+EOP A->B y 30 bytes B->A
--      (ejercita la reposicion de creditos mas alla de los 56 iniciales)
--   3: time-codes en ambos sentidos
--   4: control de flujo real: rx_room de A a 0 -> B agota exactamente los 56
--      creditos concedidos y se atasca; al reponer room llegan los 14 restantes
--   5: corrupcion en la linea -> error en B, desconexion en A, y
--      reconexion automatica de ambos hasta Run con datos despues
--   6: apagado de A (en=0) -> B detecta el fallo y ambos se recuperan
--   7: re-arranque con tasas asimetricas (A a 50 Mbit/s, B a 10 Mbit/s),
--      legal en SpaceWire: cada sentido lleva su propia tasa
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spw_1c is
end entity tb_spw_1c;

architecture tb of tb_spw_1c is

  constant K_DATA : integer := 4;
  constant K_TIME : integer := 5;
  constant K_EOP  : integer := 2;
  constant K_EEP  : integer := 3;
  constant K_ERRP : integer := 6;
  constant K_ERRE : integer := 7;
  constant K_ERRD : integer := 8;
  constant K_ERRC : integer := 9;

  constant S_RUN : std_logic_vector(2 downto 0) := "101";

  type tok_t is record
    kind : integer;
    data : std_logic_vector(7 downto 0);
  end record;
  type tok_arr_t is array (0 to 2047) of tok_t;

  signal toks_a, toks_b       : tok_arr_t := (others => (kind => -1, data => (others => '0')));
  signal tok_cnt_a, tok_cnt_b : integer   := 0;

  signal clk   : std_logic := '0';
  signal arstn : std_logic := '0';

  signal en_a, en_b                     : std_logic := '0';
  signal div_a, div_b                   : std_logic_vector(7 downto 0) := x"0A";
  signal start_a, auto_b                : std_logic := '0';
  signal dis_a, dis_b                   : std_logic := '0';
  signal tick_a, tick_b                 : std_logic := '0';
  signal timein_a, timein_b             : std_logic_vector(7 downto 0) := (others => '0');
  signal tickout_a, tickout_b           : std_logic;
  signal timeout_a, timeout_b           : std_logic_vector(7 downto 0);
  signal txv_a, txv_b                   : std_logic := '0';
  signal txd_a, txd_b                   : std_logic_vector(8 downto 0) := (others => '0');
  signal txack_a, txack_b               : std_logic;
  signal rxwe_a, rxwe_b                 : std_logic;
  signal rxd_a, rxd_b                   : std_logic_vector(8 downto 0);
  signal room_a, room_b                 : std_logic_vector(6 downto 0) := "1000000";
  signal state_a, state_b               : std_logic_vector(2 downto 0);
  signal ep_a, ee_a, ed_a, ec_a         : std_logic;
  signal ep_b, ee_b, ed_b, ec_b         : std_logic;
  signal da, sa, db, sb                 : std_logic;   -- salidas de cada codec
  signal d_ab, s_ab, d_ba, s_ba         : std_logic;   -- cables del enlace
  signal inj_d                          : std_logic := '0';

  -- interfaz de mando del proceso auxiliar que emite por B
  signal b_cmd  : integer := 0;
  signal b_cnt  : integer := 0;
  signal b_base : integer := 0;
  signal b_eop  : std_logic := '0';
  signal b_done : integer := 0;

  signal done : boolean := false;

begin

  clk <= not clk after 5 ns when not done else '0';

  -- cables cruzados, con inyector de corrupcion en la linea D de A->B
  d_ab <= da xor inj_d;
  s_ab <= sa;
  d_ba <= db;
  s_ba <= sb;

  codec_a : entity work.spw_codec
    port map (
      clk => clk, arstn => arstn, en => en_a, div => div_a,
      link_start => start_a, link_autostart => '0', link_disable => dis_a,
      tick_in => tick_a, time_in => timein_a,
      tick_out => tickout_a, time_out => timeout_a,
      tx_valid => txv_a, tx_data => txd_a, tx_ack => txack_a,
      rx_we => rxwe_a, rx_data => rxd_a, rx_room => room_a,
      state => state_a,
      err_par => ep_a, err_esc => ee_a, err_disc => ed_a, err_credit => ec_a,
      din => d_ba, sin => s_ba, dout => da, sout => sa
    );

  codec_b : entity work.spw_codec
    port map (
      clk => clk, arstn => arstn, en => en_b, div => div_b,
      link_start => '0', link_autostart => auto_b, link_disable => dis_b,
      tick_in => tick_b, time_in => timein_b,
      tick_out => tickout_b, time_out => timeout_b,
      tx_valid => txv_b, tx_data => txd_b, tx_ack => txack_b,
      rx_we => rxwe_b, rx_data => rxd_b, rx_room => room_b,
      state => state_b,
      err_par => ep_b, err_esc => ee_b, err_disc => ed_b, err_credit => ec_b,
      din => d_ab, sin => s_ab, dout => db, sout => sb
    );

  -- vigilantes independientes: primer caracter tras silencio largo = NULL
  wire_watch_ab : process
    variable tlast : time := 0 ns;
    variable sh    : std_logic_vector(7 downto 0);
  begin
    loop
      wait on d_ab, s_ab;
      if (now - tlast) > 3 us then
        sh := "0000000" & d_ab;
        for i in 1 to 7 loop
          wait on d_ab, s_ab;
          sh := sh(6 downto 0) & d_ab;
        end loop;
        assert sh = "01110100"
          report "FALLO: primer caracter A->B tras silencio no es NULL" severity failure;
      end if;
      tlast := now;
    end loop;
  end process wire_watch_ab;

  wire_watch_ba : process
    variable tlast : time := 0 ns;
    variable sh    : std_logic_vector(7 downto 0);
  begin
    loop
      wait on d_ba, s_ba;
      if (now - tlast) > 3 us then
        sh := "0000000" & d_ba;
        for i in 1 to 7 loop
          wait on d_ba, s_ba;
          sh := sh(6 downto 0) & d_ba;
        end loop;
        assert sh = "01110100"
          report "FALLO: primer caracter B->A tras silencio no es NULL" severity failure;
      end if;
      tlast := now;
    end loop;
  end process wire_watch_ba;

  watchdog : process
  begin
    wait for 5 ms;
    assert false report "FALLO: timeout global del testbench" severity failure;
  end process watchdog;

  -- ==========================================================================
  -- Monitores por extremo
  -- ==========================================================================
  mon_a : process (clk)
    variable w : integer := 0;
    procedure push (constant k : in integer; constant d : in std_logic_vector(7 downto 0)) is
    begin
      toks_a(w mod 2048) <= (kind => k, data => d);
      w                  := w + 1;
      tok_cnt_a          <= w;
    end procedure;
  begin
    if rising_edge(clk) then
      if rxwe_a = '1' then
        if rxd_a(8) = '0' then push(K_DATA, rxd_a(7 downto 0));
        elsif rxd_a(0) = '0' then push(K_EOP, x"00");
        else push(K_EEP, x"00"); end if;
      end if;
      if tickout_a = '1' then push(K_TIME, timeout_a); end if;
      if ep_a = '1' then push(K_ERRP, x"00"); end if;
      if ee_a = '1' then push(K_ERRE, x"00"); end if;
      if ed_a = '1' then push(K_ERRD, x"00"); end if;
      if ec_a = '1' then push(K_ERRC, x"00"); end if;
    end if;
  end process mon_a;

  mon_b : process (clk)
    variable w : integer := 0;
    procedure push (constant k : in integer; constant d : in std_logic_vector(7 downto 0)) is
    begin
      toks_b(w mod 2048) <= (kind => k, data => d);
      w                  := w + 1;
      tok_cnt_b          <= w;
    end procedure;
  begin
    if rising_edge(clk) then
      if rxwe_b = '1' then
        if rxd_b(8) = '0' then push(K_DATA, rxd_b(7 downto 0));
        elsif rxd_b(0) = '0' then push(K_EOP, x"00");
        else push(K_EEP, x"00"); end if;
      end if;
      if tickout_b = '1' then push(K_TIME, timeout_b); end if;
      if ep_b = '1' then push(K_ERRP, x"00"); end if;
      if ee_b = '1' then push(K_ERRE, x"00"); end if;
      if ed_b = '1' then push(K_ERRD, x"00"); end if;
      if ec_b = '1' then push(K_ERRC, x"00"); end if;
    end if;
  end process mon_b;

  -- ==========================================================================
  -- Emisor auxiliar por B (unico driver de txv_b/txd_b)
  -- ==========================================================================
  aux_b : process
    variable d : integer := 0;
  begin
    loop
      wait on b_cmd;
      for i in 0 to b_cnt - 1 loop
        txd_b <= '0' & std_logic_vector(to_unsigned((b_base + i) mod 256, 8));
        txv_b <= '1';
        loop
          wait until rising_edge(clk);
          exit when txack_b = '1';
        end loop;
        txv_b <= '0';
        wait until rising_edge(clk);
      end loop;
      if b_eop = '1' then
        txd_b <= "100000000";
        txv_b <= '1';
        loop
          wait until rising_edge(clk);
          exit when txack_b = '1';
        end loop;
        txv_b <= '0';
        wait until rising_edge(clk);
      end if;
      d      := d + 1;
      b_done <= d;
    end loop;
  end process aux_b;

  -- ==========================================================================
  -- Estimulo principal
  -- ==========================================================================
  stim : process
    variable rd_a, rd_b : integer := 0;
    variable n, n0      : integer := 0;
    variable tk         : tok_t;

    procedure expect_a (constant k : in integer;
                        constant d : in std_logic_vector(7 downto 0) := x"00") is
    begin
      while tok_cnt_a <= rd_a loop
        wait on tok_cnt_a;
      end loop;
      tk   := toks_a(rd_a mod 2048);
      rd_a := rd_a + 1;
      assert tk.kind = k report "FALLO: token inesperado en A" severity failure;
      if k = K_DATA or k = K_TIME then
        assert tk.data = d report "FALLO: dato inesperado en A" severity failure;
      end if;
    end procedure;

    procedure expect_b (constant k : in integer;
                        constant d : in std_logic_vector(7 downto 0) := x"00") is
    begin
      while tok_cnt_b <= rd_b loop
        wait on tok_cnt_b;
      end loop;
      tk   := toks_b(rd_b mod 2048);
      rd_b := rd_b + 1;
      assert tk.kind = k report "FALLO: token inesperado en B" severity failure;
      if k = K_DATA or k = K_TIME then
        assert tk.data = d report "FALLO: dato inesperado en B" severity failure;
      end if;
    end procedure;

    procedure expect_a_err_any is
    begin
      while tok_cnt_a <= rd_a loop
        wait on tok_cnt_a;
      end loop;
      tk   := toks_a(rd_a mod 2048);
      rd_a := rd_a + 1;
      assert tk.kind = K_ERRP or tk.kind = K_ERRE or tk.kind = K_ERRD or tk.kind = K_ERRC
        report "FALLO: se esperaba un error en A" severity failure;
    end procedure;

    procedure expect_b_err_any is
    begin
      while tok_cnt_b <= rd_b loop
        wait on tok_cnt_b;
      end loop;
      tk   := toks_b(rd_b mod 2048);
      rd_b := rd_b + 1;
      assert tk.kind = K_ERRP or tk.kind = K_ERRE or tk.kind = K_ERRD or tk.kind = K_ERRC
        report "FALLO: se esperaba un error en B" severity failure;
    end procedure;

    procedure wait_bdone (constant nb : in integer) is
    begin
      while b_done /= nb loop
        wait on b_done;
      end loop;
    end procedure;

    procedure send_a (constant v : in std_logic_vector(8 downto 0)) is
    begin
      txd_a <= v;
      txv_a <= '1';
      loop
        wait until rising_edge(clk);
        exit when txack_a = '1';
      end loop;
      txv_a <= '0';
      wait until rising_edge(clk);
    end procedure;

    procedure wait_both_run is
    begin
      for i in 1 to 40000 loop
        wait until rising_edge(clk);
        exit when state_a = S_RUN and state_b = S_RUN;
      end loop;
      assert state_a = S_RUN and state_b = S_RUN
        report "FALLO: los enlaces no alcanzan Run" severity failure;
    end procedure;

  begin
    arstn <= '0';
    wait for 100 ns;
    wait until rising_edge(clk);
    arstn <= '1';
    wait until rising_edge(clk);

    -- FASE 0: con el companero apagado, Started debe expirar por timeout
    -- (12.8 us) y volver a ErrorReset; jamas Connecting sin gotNULL
    en_a    <= '1';
    start_a <= '1';
    for i in 1 to 5000 loop
      wait until rising_edge(clk);
      assert state_a /= "100" and state_a /= "101"
        report "FALLO: Connecting sin gotNULL" severity failure;
    end loop;
    report "FASE 0 OK: Started expira por timeout sin NULL del companero";

    -- rearme limpio de A para un bring-up conjunto sin transitorios
    dis_a <= '1';
    wait for 1 us;
    wait until rising_edge(clk);
    dis_a  <= '0';
    en_b   <= '1';
    auto_b <= '1';

    -- FASE 1: bring-up ErrorReset -> Run en ambos extremos
    wait_both_run;
    wait for 3 us;                      -- regimen permanente de creditos
    assert tok_cnt_a = 0 and tok_cnt_b = 0
      report "FALLO: eventos espurios durante el bring-up" severity failure;
    report "FASE 1 OK: ambos enlaces en Run (link_start y autostart)";

    -- FASE 2: datos full-duplex concurrentes
    b_cnt  <= 30;
    b_base <= 100;
    b_eop  <= '0';
    b_cmd  <= b_cmd + 1;                -- arranca B->A en paralelo
    for i in 0 to 99 loop
      send_a('0' & std_logic_vector(to_unsigned((i * 7 + 3) mod 256, 8)));
    end loop;
    send_a("100000000");                -- EOP
    for i in 0 to 99 loop
      expect_b(K_DATA, std_logic_vector(to_unsigned((i * 7 + 3) mod 256, 8)));
    end loop;
    expect_b(K_EOP);
    for i in 0 to 29 loop
      expect_a(K_DATA, std_logic_vector(to_unsigned((100 + i) mod 256, 8)));
    end loop;
    wait_bdone(1);
    report "FASE 2 OK: 100+EOP A->B y 30 B->A concurrentes";

    -- FASE 3: time-codes en ambos sentidos
    timein_a <= x"0D";
    tick_a   <= '1';
    wait until rising_edge(clk);
    tick_a   <= '0';
    expect_b(K_TIME, x"0D");
    timein_b <= x"2A";
    tick_b   <= '1';
    wait until rising_edge(clk);
    tick_b   <= '0';
    expect_a(K_TIME, x"2A");
    report "FASE 3 OK: time-codes en ambos sentidos";

    -- FASE 4: control de flujo real por creditos. El credito en regimen
    -- permanente depende del historial mod 8 (se concede en unidades de 8 al
    -- cruzar outst=48), asi que el punto de atasco N se descubre en runtime.
    wait for 3 us;
    room_a <= "0000000";                -- A deja de conceder FCTs
    wait for 2 us;                      -- no queda ninguna FCT en vuelo
    b_cnt  <= 70;
    b_base <= 200;
    b_eop  <= '0';
    b_cmd  <= b_cmd + 1;
    loop                                -- esperar al atasco: 5 us sin tokens
      n0 := tok_cnt_a;
      wait for 5 us;
      exit when tok_cnt_a = n0;
    end loop;
    n := tok_cnt_a - rd_a;              -- entregados antes de agotar credito
    assert n > 0 and n <= 56 and n < 70
      report "FALLO: atasco de creditos fuera de rango" severity failure;
    for i in 0 to n - 1 loop
      expect_a(K_DATA, std_logic_vector(to_unsigned((200 + i) mod 256, 8)));
    end loop;
    wait for 10 us;
    assert tok_cnt_a = rd_a
      report "FALLO: B envia sin credito" severity failure;
    room_a <= "1000000";                -- reponer espacio -> FCTs -> resto
    for i in n to 69 loop
      expect_a(K_DATA, std_logic_vector(to_unsigned((200 + i) mod 256, 8)));
    end loop;
    wait_bdone(2);
    report "FASE 4 OK: atasco por agotamiento de creditos y reanudacion";

    -- FASE 5: corrupcion en la linea -> error, caida y reconexion automatica
    wait for 2 us;
    inj_d <= '1';
    wait for 100 ns;                    -- un bit corrupto sostenido
    inj_d <= '0';
    expect_b_err_any;                   -- B detecta el error
    expect_a_err_any;                   -- A ve caer la linea de B
    wait_both_run;
    send_a('0' & x"B7");
    expect_b(K_DATA, x"B7");
    report "FASE 5 OK: error por corrupcion y reconexion automatica";

    -- FASE 6: apagado de A -> B lo detecta y ambos se recuperan
    wait for 2 us;
    wait until rising_edge(clk);
    en_a <= '0';
    expect_b_err_any;
    wait for 2 us;
    wait until rising_edge(clk);
    en_a <= '1';
    wait_both_run;
    b_cnt  <= 1;
    b_base <= 16#5E#;
    b_cmd  <= b_cmd + 1;
    expect_a(K_DATA, x"5E");
    wait_bdone(3);
    report "FASE 6 OK: apagado de A detectado y recuperado";

    -- FASE 7: tasas asimetricas (A 50 Mbit/s, B 10 Mbit/s)
    wait until rising_edge(clk);
    dis_a <= '1';
    dis_b <= '1';
    wait for 1 us;
    div_a <= x"02";
    div_b <= x"0A";
    wait until rising_edge(clk);
    dis_a <= '0';
    dis_b <= '0';
    wait_both_run;
    rd_a := tok_cnt_a;                  -- descartar posibles eventos de la caida
    rd_b := tok_cnt_b;
    send_a('0' & x"66");
    send_a("100000001");                -- EEP
    expect_b(K_DATA, x"66");
    expect_b(K_EEP);
    b_cnt  <= 1;
    b_base <= 16#99#;
    b_cmd  <= b_cmd + 1;
    expect_a(K_DATA, x"99");
    timein_a <= x"3F";
    tick_a   <= '1';
    wait until rising_edge(clk);
    tick_a   <= '0';
    expect_b(K_TIME, x"3F");
    wait_bdone(4);
    report "FASE 7 OK: enlace asimetrico 50/10 Mbit/s";

    report "CAPA 1c PASS";
    done <= true;
    wait for 1 ns;
    finish;
  end process stim;

end architecture tb;
