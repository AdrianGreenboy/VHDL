-- ============================================================================
-- tb_can_engine.vhd : capa 1a - motor CAN (transmisor) contra modelo receptor
-- independiente por eventos. El modelo muestrea el bus por tiempos absolutos
-- desde el flanco de SOF, con destuffing, CRC-15 y verificacion de forma
-- propios (cero codigo compartido con el RTL). Ademas incluye un transmisor
-- bit-bang para forzar arbitraje y un inyector de errores.
--
-- Temporizacion: clk 100 MHz; brp=9 (tq = 100 ns), tseg1=12 (13 tq),
-- tseg2=5 (6 tq) -> 20 tq = 2 us/bit (500 kbit/s), muestreo al 70 %.
--
-- Modos del modelo (m_mode):
--   0 = recibir + ACK + registrar
--   1 = recibir sin ACK, verificar flag de error ACTIVO del motor
--   2 = recibir sin ACK, verificar silencio (flag PASIVO)
--   3 = inyectar dominante en el primer bit de DATA, verificar flag ACTIVO
--   5 = inyectar dominante en el primer bit de DATA, sin verificacion (loop)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_can_engine is
end entity;

architecture sim of tb_can_engine is

  constant C_CLK  : time := 10 ns;
  constant C_BIT  : time := 2 us;
  constant C_SAMP : time := 1400 ns;

  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  -- bus con pull recesivo
  signal busw : std_logic := 'H';

  signal eng_tx, eng_rx : std_logic;

  -- peticion de TX del motor
  signal e_req, e_abort : std_logic := '0';
  signal e_id   : std_logic_vector(28 downto 0) := (others => '0');
  signal e_ide  : std_logic := '0';
  signal e_rtr  : std_logic := '0';
  signal e_dlc  : std_logic_vector(3 downto 0) := (others => '0');
  signal e_data : std_logic_vector(63 downto 0) := (others => '0');

  signal g_busy, g_done, g_arb, g_txe, g_rxv, g_errp : std_logic;
  signal g_rid  : std_logic_vector(28 downto 0);
  signal g_ride, g_rrtr : std_logic;
  signal g_rdlc : std_logic_vector(3 downto 0);
  signal g_rdat : std_logic_vector(63 downto 0);
  signal g_tec  : std_logic_vector(8 downto 0);
  signal g_rec  : std_logic_vector(7 downto 0);
  signal g_est  : std_logic_vector(1 downto 0);

  -- contadores de pulsos (proceso monitor)
  signal n_done, n_arb, n_rxv, n_err : integer := 0;

  -- registro del modelo
  signal md_id   : std_logic_vector(28 downto 0) := (others => '0');
  signal md_ide  : std_logic := '0';
  signal md_rtr  : std_logic := '0';
  signal md_dlc  : std_logic_vector(3 downto 0) := (others => '0');
  signal md_data : std_logic_vector(63 downto 0) := (others => '0');
  signal m_frames : integer := 0;
  signal m_events : integer := 0;   -- sucesos especiales (modos 1/2/3/5)
  signal m_mode   : integer := 0;

  -- transmisor bit-bang del modelo
  signal mtx_go   : std_logic := '0';
  signal mtx_join : boolean := false;
  signal mtx_id   : std_logic_vector(28 downto 0) := (others => '0');
  signal mtx_ide  : std_logic := '0';
  signal mtx_rtr  : std_logic := '0';
  signal mtx_dlc  : std_logic_vector(3 downto 0) := (others => '0');
  signal mtx_data : std_logic_vector(63 downto 0) := (others => '0');
  signal m_txdone : integer := 0;

  function mcrc(bits : std_logic_vector; n : integer) return std_logic_vector is
    variable c   : std_logic_vector(14 downto 0) := (others => '0');
    variable inv : std_logic;
  begin
    for i in 0 to n - 1 loop
      inv := bits(i) xor c(14);
      c := c(13 downto 0) & '0';
      if inv = '1' then
        c := c xor "100010110011001";
      end if;
    end loop;
    return c;
  end function;

begin

  clk <= not clk after C_CLK / 2;

  -- pull recesivo + conductor del motor (colector abierto)
  busw <= 'H';
  busw <= '0' when eng_tx = '0' else 'Z';
  eng_rx <= to_x01(busw);

  dut : entity work.can_engine
    port map (
      clk => clk, rstn => rstn,
      brp => x"09", tseg1 => "1100", tseg2 => "101", sjw => "01",
      tx_req => e_req, tx_abort => e_abort,
      tx_id => e_id, tx_ide => e_ide, tx_rtr => e_rtr,
      tx_dlc => e_dlc, tx_data => e_data,
      tx_busy => g_busy, tx_done => g_done, tx_arb_lost => g_arb,
      tx_err => g_txe,
      rx_valid => g_rxv, rx_id => g_rid, rx_ide => g_ride,
      rx_rtr => g_rrtr, rx_dlc => g_rdlc, rx_data => g_rdat,
      tec => g_tec, rec => g_rec, err_state => g_est, err_pulse => g_errp,
      can_rx => eng_rx, can_tx => eng_tx );

  -- contadores de pulsos de 1 clk
  mon_p : process(clk)
  begin
    if rising_edge(clk) then
      if g_done = '1' then n_done <= n_done + 1; end if;
      if g_arb  = '1' then n_arb  <= n_arb  + 1; end if;
      if g_rxv  = '1' then n_rxv  <= n_rxv  + 1; end if;
      if g_errp = '1' then n_err  <= n_err  + 1; end if;
    end if;
  end process;

  -- --------------------------------------------------------------------
  -- modelo independiente por eventos
  -- --------------------------------------------------------------------
  model_p : process
    variable t0   : time;
    variable kk   : integer;            -- indice del ultimo bit crudo leido
    variable rn   : integer;            -- racha de stuffing
    variable lb   : std_logic;
    variable cb   : std_logic_vector(0 to 149); -- bits SOF..DATA para CRC
    variable cn   : integer;
    variable vid  : std_logic_vector(28 downto 0);
    variable vide, vrtr : std_logic;
    variable vdlc : std_logic_vector(3 downto 0);
    variable vdat : std_logic_vector(63 downto 0);
    variable vcrc : std_logic_vector(14 downto 0);
    variable nb   : integer;
    variable b    : std_logic;
    variable mode : integer;
    variable inj  : boolean;

    -- muestrear el bit crudo k por tiempo absoluto
    procedure graw(k : in integer; bo : out std_logic) is
      variable tgt : time;
    begin
      tgt := t0 + k * C_BIT + C_SAMP;
      if tgt > now then
        wait for tgt - now;
      end if;
      bo := to_x01(busw);
    end procedure;

    -- conducir dominante durante el bit crudo k
    procedure ginj(k : in integer) is
      variable tgt : time;
    begin
      tgt := t0 + k * C_BIT + 50 ns;
      if tgt > now then
        wait for tgt - now;
      end if;
      busw <= '0';
      wait for 1900 ns;
      busw <= 'Z';
    end procedure;

    -- siguiente bit destuffeado (verifica los bits de stuff)
    procedure gds(bo : out std_logic) is
      variable r : std_logic;
    begin
      loop
        kk := kk + 1;
        graw(kk, r);
        if rn = 5 then
          assert r /= lb
            report "FALLO: modelo detecta error de stuffing en bit crudo "
                   & integer'image(kk)
            severity failure;
          rn := 1; lb := r;
        else
          if r = lb then
            rn := rn + 1;
          else
            rn := 1; lb := r;
          end if;
          bo := r;
          exit;
        end if;
      end loop;
    end procedure;

    -- siguiente bit de datos: leerlo o inyectar dominante en su lugar
    procedure gds_or_inject(doinj : in boolean; injected : out boolean;
                            bo : out std_logic) is
      variable r : std_logic;
    begin
      injected := false;
      loop
        if rn = 5 then
          kk := kk + 1;
          graw(kk, r);
          assert r /= lb
            report "FALLO: modelo detecta error de stuffing (zona de datos)"
            severity failure;
          rn := 1; lb := r;
        else
          kk := kk + 1;
          if doinj then
            ginj(kk);
            injected := true;
            bo := '0';
          else
            graw(kk, r);
            if r = lb then
              rn := rn + 1;
            else
              rn := 1; lb := r;
            end if;
            bo := r;
          end if;
          exit;
        end if;
      end loop;
    end procedure;

    -- verificar flag de error ACTIVO del motor a partir del bit crudo ke+1
    procedure chk_active_flag(ke : in integer) is
      variable r : std_logic;
    begin
      for i in 1 to 6 loop
        graw(ke + i, r);
        assert r = '0'
          report "FALLO: flag de error activo incompleto en bit "
                 & integer'image(i)
          severity failure;
      end loop;
      graw(ke + 7, r);
      assert r = '1'
        report "FALLO: falta delimitador tras el flag de error activo"
        severity failure;
    end procedure;

    -- verificar silencio (flag pasivo) a partir del bit crudo ke+1
    procedure chk_quiet(ke : in integer) is
      variable r : std_logic;
    begin
      for i in 1 to 6 loop
        graw(ke + i, r);
        assert r = '1'
          report "FALLO: se esperaba flag pasivo (bus recesivo) en bit "
                 & integer'image(i)
          severity failure;
      end loop;
    end procedure;

    -- saltar un posible flag de error activo tras una inyeccion
    procedure skip_flag(ke : in integer) is
      variable r : std_logic;
      variable j : integer;
    begin
      j := ke + 1;
      graw(j, r);
      while r = '0' loop
        j := j + 1;
        assert j < ke + 20
          report "FALLO: flag dominante demasiado largo tras la inyeccion"
          severity failure;
        graw(j, r);
      end loop;
    end procedure;

    -- recepcion de una trama segun el modo
    procedure do_receive(md : in integer) is
      variable r    : std_logic;
      variable injd : boolean;
      variable ka   : integer;
    begin
      -- t0 = flanco de SOF (ya detectado por el llamante)
      kk := 0;
      graw(0, r);
      assert r = '0'
        report "FALLO: SOF no dominante en el muestreo del modelo"
        severity failure;
      rn := 1; lb := '0';
      cn := 0; cb(0) := '0'; cn := 1;
      vid := (others => '0');
      vdat := (others => '0');
      nb := 0;

      -- 11 bits de identificador base
      for i in 10 downto 0 loop
        gds(b); vid(i) := b; cb(cn) := b; cn := cn + 1;
      end loop;
      -- SRR/RTR
      gds(b); vrtr := b; cb(cn) := b; cn := cn + 1;
      -- IDE
      gds(b); vide := b; cb(cn) := b; cn := cn + 1;
      if vide = '1' then
        for i in 17 downto 0 loop
          gds(b); vid(i + 11) := b; cb(cn) := b; cn := cn + 1;
        end loop;
        -- reordenar: base en [28:18], extension en [17:0]
        vid := vid(10 downto 0) & vid(28 downto 11);
        gds(b); vrtr := b; cb(cn) := b; cn := cn + 1; -- RTR
        gds(b); cb(cn) := b; cn := cn + 1;            -- r1
      end if;
      -- r0
      gds(b); cb(cn) := b; cn := cn + 1;
      -- DLC
      for i in 3 downto 0 loop
        gds(b); vdlc(i) := b; cb(cn) := b; cn := cn + 1;
      end loop;
      nb := to_integer(unsigned(vdlc));
      if nb > 8 then nb := 8; end if;
      if vrtr = '1' then nb := 0; end if;
      nb := nb * 8;

      -- datos (con posible inyeccion en el primer bit)
      for i in 0 to nb - 1 loop
        if i = 0 and (md = 3 or md = 5) then
          gds_or_inject(true, injd, b);
          if injd then
            if md = 3 then
              chk_active_flag(kk);
            else
              skip_flag(kk);
            end if;
            m_events <= m_events + 1;
            return;
          end if;
        else
          gds(b);
        end if;
        vdat := vdat(62 downto 0) & b;
        cb(cn) := b; cn := cn + 1;
      end loop;

      -- CRC recibido
      for i in 14 downto 0 loop
        gds(b); vcrc(i) := b;
      end loop;
      assert vcrc = mcrc(cb, cn)
        report "FALLO: CRC del modelo no coincide con el recibido"
        severity failure;

      -- delimitador de CRC
      kk := kk + 1; graw(kk, b);
      assert b = '1'
        report "FALLO: delimitador de CRC no recesivo"
        severity failure;

      -- ranura de ACK
      ka := kk + 1;
      if md = 0 then
        ginj(ka);          -- conducir ACK dominante
        kk := ka;
      else
        kk := ka;
        graw(ka, b);       -- sin ACK: el motor debe ver recesivo
        assert b = '1'
          report "FALLO: ranura de ACK dominante inesperada"
          severity failure;
        if md = 1 then
          chk_active_flag(ka);
        else
          chk_quiet(ka);
        end if;
        m_events <= m_events + 1;
        return;
      end if;

      -- delimitador de ACK
      kk := kk + 1; graw(kk, b);
      assert b = '1'
        report "FALLO: delimitador de ACK no recesivo"
        severity failure;

      -- EOF
      for i in 1 to 7 loop
        kk := kk + 1; graw(kk, b);
        assert b = '1'
          report "FALLO: EOF no recesivo en bit " & integer'image(i)
          severity failure;
      end loop;

      -- registrar la trama
      md_id <= vid;
      md_ide <= vide;
      md_rtr <= vrtr;
      md_dlc <= vdlc;
      if nb = 0 then
        md_data <= (others => '0');
      else
        md_data <= std_logic_vector(shift_left(unsigned(vdat), 64 - nb));
      end if;
      m_frames <= m_frames + 1;
    end procedure;

    -- transmisor bit-bang del modelo (con stuffing y CRC propios)
    procedure do_tx is
      variable seq  : std_logic_vector(0 to 127);
      variable sl   : integer;
      variable c15  : std_logic_vector(14 downto 0);
      variable k    : integer;
      variable idx  : integer;
      variable sb   : std_logic;
      variable r    : std_logic;
      variable nbt  : integer;

      procedure putraw(bv : in std_logic; isack : in boolean) is
        variable tgt : time;
      begin
        tgt := t0 + k * C_BIT;
        if tgt > now then
          wait for tgt - now;
        end if;
        if bv = '0' and not isack then
          busw <= '0';
        else
          busw <= 'Z';
        end if;
        wait for C_SAMP;
        r := to_x01(busw);
        if isack then
          assert r = '0'
            report "FALLO: el modelo no vio ACK del motor"
            severity failure;
        else
          assert r = bv
            report "FALLO: bit transmitido por el modelo no coincide en el bus"
            severity failure;
        end if;
        k := k + 1;
      end procedure;

    begin
      -- construir secuencia sin stuffing: SOF..DATA
      sl := 0;
      seq(sl) := '0'; sl := sl + 1; -- SOF
      if mtx_ide = '1' then
        for i in 10 downto 0 loop
          seq(sl) := mtx_id(18 + i); sl := sl + 1;
        end loop;
        seq(sl) := '1'; sl := sl + 1;       -- SRR
        seq(sl) := '1'; sl := sl + 1;       -- IDE
        for i in 17 downto 0 loop
          seq(sl) := mtx_id(i); sl := sl + 1;
        end loop;
        seq(sl) := mtx_rtr; sl := sl + 1;   -- RTR
        seq(sl) := '0'; sl := sl + 1;       -- r1
      else
        for i in 10 downto 0 loop
          seq(sl) := mtx_id(i); sl := sl + 1;
        end loop;
        seq(sl) := mtx_rtr; sl := sl + 1;   -- RTR
        seq(sl) := '0'; sl := sl + 1;       -- IDE
      end if;
      seq(sl) := '0'; sl := sl + 1;         -- r0
      for i in 3 downto 0 loop
        seq(sl) := mtx_dlc(i); sl := sl + 1;
      end loop;
      nbt := to_integer(unsigned(mtx_dlc));
      if nbt > 8 then nbt := 8; end if;
      if mtx_rtr = '1' then nbt := 0; end if;
      nbt := nbt * 8;
      for i in 0 to nbt - 1 loop
        seq(sl) := mtx_data(63 - i); sl := sl + 1;
      end loop;
      c15 := mcrc(seq, sl);
      for i in 14 downto 0 loop
        seq(sl) := c15(i); sl := sl + 1;
      end loop;

      if mtx_join then
        -- esperar el SOF del motor y entrar en arbitraje desde el bit de ID
        if to_x01(busw) /= '0' then
          wait until to_x01(busw) = '0';
        end if;
        t0 := now;
        k := 1;
        idx := 1;                 -- el SOF ya esta en el bus
        rn := 1; lb := '0';
      else
        -- respetar la intermision del receptor anterior (3 bits tras el EOF)
        t0 := now + 4 * C_BIT;
        k := 0;
        idx := 0;
        rn := 0; lb := '1';
      end if;

      -- transmitir con stuffing SOF..CRC
      while idx < sl loop
        if rn = 5 then
          sb := not lb;
          putraw(sb, false);
          rn := 1; lb := sb;
        else
          sb := seq(idx);
          putraw(sb, false);
          if rn = 0 then
            rn := 1; lb := sb;
          elsif sb = lb then
            rn := rn + 1;
          else
            rn := 1; lb := sb;
          end if;
          idx := idx + 1;
        end if;
      end loop;

      putraw('1', false);  -- delimitador de CRC
      putraw('1', true);   -- ranura de ACK: esperar dominante del motor
      putraw('1', false);  -- delimitador de ACK
      for i in 1 to 7 loop
        putraw('1', false); -- EOF
      end loop;
      busw <= 'Z';
    end procedure;

  begin
    busw <= 'Z';
    wait until rstn = '1';
    loop
      if mtx_go = '0' and to_x01(busw) /= '0' then
        wait until (to_x01(busw) = '0') or (mtx_go = '1');
      end if;
      if mtx_go = '1' then
        do_tx;
        m_txdone <= m_txdone + 1;
        wait until mtx_go = '0';
      else
        t0 := now;
        mode := m_mode;
        do_receive(mode);
      end if;
    end loop;
  end process;

  -- --------------------------------------------------------------------
  -- estimulos
  -- --------------------------------------------------------------------
  stim_p : process
    variable exp_done, exp_rxv, exp_frames, exp_ev, exp_txd : integer := 0;

    procedure e_send(id : std_logic_vector(28 downto 0); ide, rtr : std_logic;
                     dlc : std_logic_vector(3 downto 0);
                     dat : std_logic_vector(63 downto 0)) is
    begin
      e_id <= id; e_ide <= ide; e_rtr <= rtr; e_dlc <= dlc; e_data <= dat;
      wait until rising_edge(clk);
      e_req <= '1';
      wait until rising_edge(clk);
      e_req <= '0';
    end procedure;

    procedure chk_tec(v : integer; msg : string) is
    begin
      wait for 1 ns;
      assert to_integer(unsigned(g_tec)) = v
        report "FALLO: TEC=" & integer'image(to_integer(unsigned(g_tec)))
               & " esperado " & integer'image(v) & " en " & msg
        severity failure;
    end procedure;

    procedure wdone(msg : string) is
    begin
      exp_done := exp_done + 1;
      if n_done /= exp_done then
        wait until n_done = exp_done for 2 ms;
      end if;
      assert n_done = exp_done
        report "FALLO: timeout esperando tx_done en " & msg
        severity failure;
    end procedure;

    procedure wframe(msg : string) is
    begin
      exp_frames := exp_frames + 1;
      if m_frames /= exp_frames then
        wait until m_frames = exp_frames for 2 ms;
      end if;
      assert m_frames = exp_frames
        report "FALLO: timeout esperando trama del modelo en " & msg
        severity failure;
      wait for 1 ns;
    end procedure;

    procedure wevent(msg : string) is
    begin
      exp_ev := exp_ev + 1;
      if m_events /= exp_ev then
        wait until m_events = exp_ev for 2 ms;
      end if;
      assert m_events = exp_ev
        report "FALLO: timeout esperando suceso del modelo en " & msg
        severity failure;
      wait for 1 ns;
    end procedure;

    variable dexp : std_logic_vector(63 downto 0);
  begin
    rstn <= '0';
    wait for 200 ns;
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 20 us;

    -- ------------------------------------------------------------------
    -- T1: trama base, DLC=8
    -- ------------------------------------------------------------------
    report "T1: trama base DLC=8";
    e_send("000000000000000000" & "00100100011", '0', '0', x"8",
           x"0123456789ABCDEF");
    wdone("T1");
    wframe("T1");
    assert md_id(10 downto 0) = "00100100011"
      report "FALLO: T1 identificador incorrecto en el modelo"
      severity failure;
    assert md_ide = '0' and md_rtr = '0'
      report "FALLO: T1 IDE/RTR incorrectos" severity failure;
    assert md_dlc = x"8"
      report "FALLO: T1 DLC incorrecto" severity failure;
    assert md_data = x"0123456789ABCDEF"
      report "FALLO: T1 datos incorrectos" severity failure;
    chk_tec(0, "T1");

    -- ------------------------------------------------------------------
    -- T2: trama extendida, DLC=3
    -- ------------------------------------------------------------------
    report "T2: trama extendida DLC=3";
    e_send("10101101001011010010110100101", '1', '0', x"3",
           x"AABBCC0000000000");
    wdone("T2");
    wframe("T2");
    assert md_id = "10101101001011010010110100101"
      report "FALLO: T2 identificador extendido incorrecto"
      severity failure;
    assert md_ide = '1' and md_rtr = '0'
      report "FALLO: T2 IDE/RTR incorrectos" severity failure;
    assert md_dlc = x"3"
      report "FALLO: T2 DLC incorrecto" severity failure;
    assert md_data = x"AABBCC0000000000"
      report "FALLO: T2 datos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- T3: trama remota base, DLC=4
    -- ------------------------------------------------------------------
    report "T3: trama remota DLC=4";
    e_send("000000000000000000" & "11111111111", '0', '1', x"4",
           (others => '0'));
    wdone("T3");
    wframe("T3");
    assert md_id(10 downto 0) = "11111111111"
      report "FALLO: T3 identificador incorrecto" severity failure;
    assert md_rtr = '1'
      report "FALLO: T3 RTR no marcado" severity failure;
    assert md_dlc = x"4"
      report "FALLO: T3 DLC incorrecto" severity failure;

    -- ------------------------------------------------------------------
    -- T4a/T4b: stuffing intensivo (ceros y unos)
    -- ------------------------------------------------------------------
    report "T4a: stuffing con ceros";
    e_send((others => '0'), '0', '0', x"2", (others => '0'));
    wdone("T4a");
    wframe("T4a");
    assert md_id(10 downto 0) = "00000000000" and md_dlc = x"2"
      report "FALLO: T4a campos incorrectos" severity failure;
    assert md_data = x"0000000000000000"
      report "FALLO: T4a datos incorrectos" severity failure;

    report "T4b: stuffing con unos";
    e_send("000000000000000000" & "11111111111", '0', '0', x"2",
           x"FFFF000000000000");
    wdone("T4b");
    wframe("T4b");
    assert md_data = x"FFFF000000000000"
      report "FALLO: T4b datos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- T4c: el modelo transmite solo; el motor recibe y da ACK
    -- ------------------------------------------------------------------
    report "T4c: modelo transmite, motor recibe";
    mtx_id <= "000000000000000000" & "01100100001";
    mtx_ide <= '0'; mtx_rtr <= '0'; mtx_dlc <= x"2";
    mtx_data <= x"CAFE000000000000";
    mtx_join <= false;
    wait until rising_edge(clk);
    mtx_go <= '1';
    exp_txd := exp_txd + 1;
    if m_txdone /= exp_txd then
      wait until m_txdone = exp_txd for 2 ms;
    end if;
    assert m_txdone = exp_txd
      report "FALLO: timeout en la transmision del modelo (T4c)"
      severity failure;
    mtx_go <= '0';
    exp_rxv := exp_rxv + 1;
    if n_rxv /= exp_rxv then
      wait until n_rxv = exp_rxv for 1 ms;
    end if;
    assert n_rxv = exp_rxv
      report "FALLO: el motor no valido la trama del modelo (T4c)"
      severity failure;
    wait for 1 ns;
    assert g_rid(10 downto 0) = "01100100001"
      report "FALLO: T4c identificador recibido incorrecto" severity failure;
    assert g_ride = '0' and g_rrtr = '0' and g_rdlc = x"2"
      report "FALLO: T4c campos recibidos incorrectos" severity failure;
    assert g_rdat = x"CAFE000000000000"
      report "FALLO: T4c datos recibidos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- T5: arbitraje - el modelo gana, el motor recibe y reintenta
    -- ------------------------------------------------------------------
    report "T5: arbitraje con reintento automatico";
    mtx_id <= "000000000000000000" & "00011110000";
    mtx_ide <= '0'; mtx_rtr <= '0'; mtx_dlc <= x"1";
    mtx_data <= x"7700000000000000";
    mtx_join <= true;
    wait until rising_edge(clk);
    mtx_go <= '1';
    wait for 100 ns;
    e_send("000000000000000000" & "00100100011", '0', '0', x"1",
           x"5500000000000000");
    -- el motor pierde el arbitraje y recibe la trama del modelo
    exp_rxv := exp_rxv + 1;
    if n_rxv /= exp_rxv then
      wait until n_rxv = exp_rxv for 1 ms;
    end if;
    assert n_rxv = exp_rxv
      report "FALLO: el motor no recibio la trama ganadora (T5)"
      severity failure;
    wait for 1 ns;
    assert n_arb = 1
      report "FALLO: no se registro la perdida de arbitraje (T5)"
      severity failure;
    assert g_rid(10 downto 0) = "00011110000" and g_rdlc = x"1"
      report "FALLO: T5 trama ganadora incorrecta" severity failure;
    assert g_rdat = x"7700000000000000"
      report "FALLO: T5 datos ganadores incorrectos" severity failure;
    exp_txd := exp_txd + 1;
    if m_txdone /= exp_txd then
      wait until m_txdone = exp_txd for 1 ms;
    end if;
    assert m_txdone = exp_txd
      report "FALLO: timeout en la transmision del modelo (T5)"
      severity failure;
    mtx_go <= '0';
    -- reintento automatico del motor
    wdone("T5");
    wframe("T5");
    assert md_id(10 downto 0) = "00100100011" and md_dlc = x"1"
      report "FALLO: T5 reintento con campos incorrectos" severity failure;
    assert md_data = x"5500000000000000"
      report "FALLO: T5 reintento con datos incorrectos" severity failure;
    chk_tec(0, "T5");

    -- ------------------------------------------------------------------
    -- T6: error de bit inyectado en DATA -> flag activo, TEC+8, reintento
    -- ------------------------------------------------------------------
    report "T6: error de bit inyectado";
    m_mode <= 3;
    e_send("000000000000000000" & "01010101010", '0', '0', x"1",
           x"AA00000000000000");
    wevent("T6 inyeccion");
    m_mode <= 0;
    chk_tec(8, "T6 tras el error");
    wdone("T6");
    wframe("T6");
    assert md_data = x"AA00000000000000"
      report "FALLO: T6 datos del reintento incorrectos" severity failure;
    chk_tec(7, "T6 tras el reintento");

    -- ------------------------------------------------------------------
    -- T7: error de ACK -> flag activo, TEC+8, reintento
    -- ------------------------------------------------------------------
    report "T7: error de ACK";
    m_mode <= 1;
    e_send("000000000000000000" & "00100100011", '0', '0', x"1",
           x"5500000000000000");
    wevent("T7 sin ACK");
    m_mode <= 0;
    chk_tec(15, "T7 tras el error");
    wdone("T7");
    wframe("T7");
    chk_tec(14, "T7 tras el reintento");

    -- ------------------------------------------------------------------
    -- T8: escalada a error pasivo y retorno a activo
    -- ------------------------------------------------------------------
    report "T8: escalada a error pasivo";
    m_mode <= 1;
    e_send("000000000000000000" & "01010101010", '0', '0', x"1",
           x"AA00000000000000");
    for i in 1 to 14 loop
      wevent("T8 fallo activo " & integer'image(i));
      chk_tec(14 + 8 * i, "T8 fallo " & integer'image(i));
      if i = 14 then
        m_mode <= 2; -- el proximo fallo cruza a pasivo
      end if;
    end loop;
    wevent("T8 fallo pasivo 15");
    chk_tec(134, "T8 cruce a pasivo");
    wait for 1 ns;
    assert g_est = "01"
      report "FALLO: T8 no se alcanzo el estado pasivo" severity failure;
    -- error de ACK en pasivo: excepcion, TEC no incrementa
    wevent("T8 fallo pasivo 16");
    chk_tec(134, "T8 excepcion ACK pasivo");
    m_mode <= 0;
    wdone("T8 exito");
    wframe("T8 exito");
    chk_tec(133, "T8 tras el primer exito");
    for i in 1 to 6 loop
      e_send("000000000000000000" & "00100100011", '0', '0', x"1",
             x"5500000000000000");
      wdone("T8 exito " & integer'image(i));
      wframe("T8 exito " & integer'image(i));
    end loop;
    chk_tec(127, "T8 retorno a activo");
    wait for 1 ns;
    assert g_est = "00"
      report "FALLO: T8 no se recupero el estado activo" severity failure;

    -- ------------------------------------------------------------------
    -- T9: escalada a bus-off y recuperacion (128 x 11 recesivos)
    -- ------------------------------------------------------------------
    report "T9: bus-off y recuperacion";
    m_mode <= 5;
    e_send("000000000000000000" & "01010101010", '0', '0', x"1",
           x"AA00000000000000");
    if g_est /= "10" then
      wait until g_est = "10" for 15 ms;
    end if;
    assert g_est = "10"
      report "FALLO: T9 no se alcanzo bus-off" severity failure;
    m_mode <= 0;
    if g_est /= "00" then
      wait until g_est = "00" for 6 ms;
    end if;
    assert g_est = "00"
      report "FALLO: T9 no se recupero de bus-off" severity failure;
    chk_tec(0, "T9 tras la recuperacion");
    wait for 1 ns;
    assert to_integer(unsigned(g_rec)) = 0
      report "FALLO: T9 REC no se reinicio" severity failure;
    -- la peticion pendiente se conserva: el motor transmite tras recuperar
    wdone("T9 trama tras recuperacion");
    wframe("T9 trama tras recuperacion");
    assert md_data = x"AA00000000000000"
      report "FALLO: T9 datos tras recuperacion incorrectos" severity failure;
    chk_tec(0, "T9 final");

    report "CAPA 1a OK: motor CAN contra modelo receptor independiente";
    finish;
  end process;

  -- vigilante global
  wd_p : process
  begin
    wait for 60 ms;
    assert false
      report "FALLO: timeout global del testbench"
      severity failure;
  end process;

end architecture;
