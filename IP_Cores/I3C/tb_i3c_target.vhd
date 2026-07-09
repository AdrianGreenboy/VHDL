-- ============================================================================
--  tb_i3c_target.vhd - Capa 1b: motor target I3C contra un modelo de
--  controller INDEPENDIENTE bit-bang.
--
--  El modelo es procedural: conduce SCL push-pull y SDA con temporizacion
--  propia por cuartos (q_od / q_pp modificables en caliente), implementa a
--  mano el arbitraje open-drain, el seize del bit T y las secuencias
--  START/Sr/STOP. No comparte una linea con el RTL.
--
--  Tests:
--    U1  ENEC/DISEC broadcast (byte de eventos: ENINT y ENHJ)
--    U2  SETDASA a la direccion estatica
--    U3  RSTDAA broadcast
--    U4  ENTDAA con PERDIDA de arbitraje forzada, retirada y reintento
--    U5  Escritura privada + byte con paridad mala (rx_perr y descarte)
--    U6  Lecturas privadas: seize del controller, T=0 del target, NACK
--        con FIFO vacia
--    U7  GET dirigidos: GETPID/GETBCR/GETDCR/GETSTATUS
--    U8  SETMWL dirigido + SETMRL broadcast + GETMWL/GETMRL
--    U9  IBI desde bus libre con MDB; U9b IBI rechazado (NACK)
--    U10 IBI arbitrado sobre un START ajeno (el modelo pierde con 0x7E)
--    U11 Hot-join + ENTDAA posterior
--    U12 Repeticion de escritura/lectura/seize a cuartos minimos
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i3c_target is
end entity;

architecture sim of tb_i3c_target is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '0';

  constant TGT_SA  : std_logic_vector(6 downto 0) := "1010010";  -- 0x52
  constant TGT_PID : std_logic_vector(47 downto 0) := x"045967ABCDEF";
  constant TGT_BCR : std_logic_vector(7 downto 0)  := x"46";
  constant TGT_DCR : std_logic_vector(7 downto 0)  := x"C6";
  constant TGT_STS : std_logic_vector(15 downto 0) := x"1234";
  constant TGT_MDB : std_logic_vector(7 downto 0)  := x"9C";
  constant PAY : std_logic_vector(63 downto 0) := TGT_PID & TGT_BCR & TGT_DCR;

  signal ibi_go, hj_go : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0);
  signal tx_valid, tx_ren : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_perr : std_logic;
  signal da : std_logic_vector(6 downto 0);
  signal da_valid, ibi_en, hj_en : std_logic;
  signal mwl, mrl : std_logic_vector(15 downto 0);
  signal ibi_pend, hj_pend : std_logic;
  signal ibi_done, ibi_nakd, hj_done : std_logic;
  signal ev_daset, ev_rstdaa, in_frame : std_logic;
  signal sda_o, sda_t : std_logic;
  signal scl_iw, sda_iw : std_logic;

  -- bus con pull-up debil / keeper
  signal scl_b, sda_b : std_logic;
  signal scl_m : std_logic := '1';                   -- el modelo conduce SCL
  signal sda_m : std_logic := 'Z';

  -- cuartos del modelo (modificables en caliente)
  signal q_od : time := 100 ns;
  signal q_pp : time := 50 ns;

  -- mini-FIFO FWFT para tx del target
  type slv8_arr is array (natural range <>) of std_logic_vector(7 downto 0);
  signal ftx     : slv8_arr(0 to 7) := (others => (others => '0'));
  signal ftx_n   : integer := 0;
  signal ftx_i   : integer := 0;
  signal ftx_rst : std_logic := '0';

  -- monitores
  signal rxc : slv8_arr(0 to 7) := (others => (others => '0'));
  signal rxn : integer := 0;
  signal perr_c, ibid_c, ibin_c, hjd_c, evda_c, evrst_c, tren_c : integer := 0;
  signal mon_rst : std_logic := '0';

  function pxor(v : std_logic_vector) return std_logic is
    variable x : std_logic := '0';
  begin
    for i in v'range loop
      x := x xor v(i);
    end loop;
    return x;
  end function;

begin

  clk <= not clk after TCLK / 2;

  scl_b <= 'H';
  sda_b <= 'H';
  scl_b <= scl_m;
  sda_b <= sda_m;
  sda_b <= sda_o when sda_t = '0' else 'Z';
  scl_iw <= to_x01(scl_b);
  sda_iw <= to_x01(sda_b);

  dut : entity work.i3c_target
    port map (
      clk => clk, rst => rst, en => en,
      sa => TGT_SA, pid => TGT_PID, bcr => TGT_BCR, dcr => TGT_DCR,
      status_in => TGT_STS, mdb => TGT_MDB,
      ibi_go => ibi_go, hj_go => hj_go,
      tx_data => tx_data, tx_valid => tx_valid, tx_ren => tx_ren,
      rx_data => rx_data, rx_valid => rx_valid, rx_perr => rx_perr,
      da => da, da_valid => da_valid, ibi_en => ibi_en, hj_en => hj_en,
      mwl => mwl, mrl => mrl,
      ibi_pend => ibi_pend, hj_pend => hj_pend,
      ibi_done => ibi_done, ibi_nakd => ibi_nakd, hj_done => hj_done,
      ev_daset => ev_daset, ev_rstdaa => ev_rstdaa, in_frame => in_frame,
      scl_i => scl_iw, sda_i => sda_iw, sda_o => sda_o, sda_t => sda_t
    );

  -- FIFO FWFT diminuta para las lecturas privadas
  tx_data  <= ftx(ftx_i) when ftx_i < 8 else x"00";
  tx_valid <= '1' when ftx_i < ftx_n else '0';
  fifo : process(clk)
  begin
    if rising_edge(clk) then
      if ftx_rst = '1' then
        ftx_i <= 0;
      elsif tx_ren = '1' and ftx_i < ftx_n then
        ftx_i <= ftx_i + 1;
      end if;
    end if;
  end process;

  -- monitores de pulsos
  mon : process(clk)
  begin
    if rising_edge(clk) then
      if mon_rst = '1' then
        rxn <= 0; perr_c <= 0; ibid_c <= 0; ibin_c <= 0;
        hjd_c <= 0; evda_c <= 0; evrst_c <= 0; tren_c <= 0;
      else
        if rx_valid = '1' then
          if rxn < 8 then
            rxc(rxn) <= rx_data;
          end if;
          rxn <= rxn + 1;
        end if;
        if rx_perr  = '1' then perr_c  <= perr_c + 1;  end if;
        if ibi_done = '1' then ibid_c  <= ibid_c + 1;  end if;
        if ibi_nakd = '1' then ibin_c  <= ibin_c + 1;  end if;
        if hj_done  = '1' then hjd_c   <= hjd_c + 1;   end if;
        if ev_daset = '1' then evda_c  <= evda_c + 1;  end if;
        if ev_rstdaa = '1' then evrst_c <= evrst_c + 1; end if;
        if tx_ren   = '1' then tren_c  <= tren_c + 1;  end if;
      end if;
    end if;
  end process;

  -- ==========================================================================
  --  ESTIMULO = MODELO DE CONTROLLER INDEPENDIENTE (bit-bang)
  -- ==========================================================================
  estimulo : process
    variable s, a, t : std_logic;
    variable bv      : std_logic_vector(7 downto 0);
    variable cap     : std_logic_vector(7 downto 0);
    variable pcap    : std_logic_vector(63 downto 0);
    variable lostv   : boolean;

    procedure tick1 is
    begin
      wait until rising_edge(clk);
    end procedure;

    -- un bit completo; entrada: SCL bajo hace 1 cuarto
    procedure c_bit(constant d : std_logic; constant od : boolean;
                    variable seen : out std_logic; constant tq : time) is
    begin
      if od then
        if d = '0' then sda_m <= '0'; else sda_m <= 'Z'; end if;
      else
        if d = 'Z' then sda_m <= 'Z'; else sda_m <= d; end if;
      end if;
      wait for tq;
      scl_m <= '1';
      wait for tq + tq / 2;
      seen := to_x01(sda_b);
      wait for tq / 2;
      scl_m <= '0';
      wait for tq;
    end procedure;

    procedure c_start is
    begin
      sda_m <= '0';
      wait for 2 * q_od;
      scl_m <= '0';
      wait for q_od;
    end procedure;

    procedure c_sr(constant tq : time) is
    begin
      sda_m <= '1';
      wait for tq;
      scl_m <= '1';
      wait for 2 * tq;
      sda_m <= '0';
      wait for 2 * tq;
      scl_m <= '0';
      wait for tq;
    end procedure;

    procedure c_stop(constant tq : time) is
    begin
      sda_m <= '0';
      wait for tq;
      scl_m <= '1';
      wait for 2 * tq;
      sda_m <= 'Z';
      wait for 2 * tq;
    end procedure;

    -- header open-drain con monitoreo de arbitraje propio
    procedure c_hdr_arb(constant h : std_logic_vector(7 downto 0);
                        variable lo : out boolean;
                        variable c  : out std_logic_vector(7 downto 0);
                        constant tq : time) is
      variable sv : std_logic;
      variable l  : boolean := false;
    begin
      for i in 7 downto 0 loop
        if l then
          c_bit('1', true, sv, tq);
        else
          c_bit(h(i), true, sv, tq);
          if h(i) = '1' and sv = '0' then
            l := true;
          end if;
        end if;
        c(i) := sv;
      end loop;
      lo := l;
    end procedure;

    -- header push-pull (tras Sr)
    procedure c_hdr_pp(constant h : std_logic_vector(7 downto 0);
                       constant tq : time) is
      variable sv : std_logic;
    begin
      for i in 7 downto 0 loop
        c_bit(h(i), false, sv, tq);
      end loop;
    end procedure;

    procedure c_ack(variable av : out std_logic; constant tq : time) is
      variable sv : std_logic;
    begin
      c_bit('1', true, sv, tq);
      av := sv;
    end procedure;

    procedure c_ackdrv(constant tq : time) is
      variable sv : std_logic;
    begin
      c_bit('0', true, sv, tq);
    end procedure;

    procedure c_wr(constant d : std_logic_vector(7 downto 0);
                   constant tq : time) is
      variable sv : std_logic;
    begin
      for i in 7 downto 0 loop
        c_bit(d(i), false, sv, tq);
      end loop;
      c_bit(not pxor(d), false, sv, tq);
    end procedure;

    procedure c_wr_bad(constant d : std_logic_vector(7 downto 0);
                       constant tq : time) is
      variable sv : std_logic;
    begin
      for i in 7 downto 0 loop
        c_bit(d(i), false, sv, tq);
      end loop;
      c_bit(pxor(d), false, sv, tq);                 -- paridad INVERTIDA
    end procedure;

    -- lectura de un byte; si seize y T=1 se apodera de SDA (Sr) y deja
    -- SCL ALTO y SDA BAJO (el llamador remata con stop o continua)
    procedure c_rd(variable d : out std_logic_vector(7 downto 0);
                   variable tv : out std_logic;
                   constant seize : boolean; constant tq : time) is
      variable sv : std_logic;
      variable dd : std_logic_vector(7 downto 0);
      variable tt : std_logic;
    begin
      for i in 7 downto 0 loop
        c_bit('Z', false, sv, tq);
        dd(i) := sv;
      end loop;
      sda_m <= 'Z';
      wait for tq;
      scl_m <= '1';
      wait for tq / 2;
      tt := to_x01(sda_b);
      if seize and tt = '1' then
        wait for tq;
        sda_m <= '0';                                -- Sr durante T alto
        wait for tq / 2;
      else
        wait for tq + tq / 2;
        scl_m <= '0';
        wait for tq;
      end if;
      d  := dd;
      tv := tt;
    end procedure;

    procedure c_stop_tras_sr(constant tq : time) is
    begin
      wait for tq;
      sda_m <= 'Z';                                  -- subida con SCL alto = P
      wait for 2 * tq;
    end procedure;

    -- ronda de payload ENTDAA: 64 bits open-drain; force_bit >= 0 conduce
    -- '0' en ese indice para forzar la perdida del target
    procedure c_daa64(variable p : out std_logic_vector(63 downto 0);
                      constant force_bit : integer; constant tq : time) is
      variable sv : std_logic;
    begin
      for k in 0 to 63 loop
        if k = force_bit then
          c_bit('0', true, sv, tq);
        else
          c_bit('1', true, sv, tq);
        end if;
        p(63 - k) := sv;
      end loop;
    end procedure;

    procedure c_daa_da(constant a7 : std_logic_vector(6 downto 0);
                       variable ak : out std_logic; constant tq : time) is
      variable sv : std_logic;
    begin
      for i in 6 downto 0 loop
        c_bit(a7(i), false, sv, tq);
      end loop;
      c_bit(not pxor(a7), false, sv, tq);
      c_ack(ak, q_od);
    end procedure;

    -- respuesta del modelo a un START de target (IBI/HJ ya jalando SDA)
    procedure c_ibi_resp(constant doack : boolean;
                         variable c : out std_logic_vector(7 downto 0)) is
      variable sv : std_logic;
    begin
      wait for 2 * q_od;                             -- tCAS
      scl_m <= '0';
      wait for q_od;
      for i in 7 downto 0 loop
        c_bit('1', true, sv, q_od);
        c(i) := sv;
      end loop;
      if doack then
        c_ackdrv(q_od);
      else
        c_ack(sv, q_od);
      end if;
    end procedure;

    procedure espera_pull(msg : string) is
    begin
      wait until to_x01(sda_b) = '0' for 50 us;
      assert to_x01(sda_b) = '0'
        report "TIMEOUT esperando el START del target: " & msg
        severity failure;
    end procedure;

    procedure settle is
    begin
      wait for 1 us;
    end procedure;

  begin
    rst <= '1';
    en  <= '0';
    wait for 200 ns;
    tick1;
    rst <= '0';
    en  <= '1';
    wait for 300 ns;

    assert ibi_en = '1' and hj_en = '1'
      report "FALLO inicial: ENEC por defecto tras reset" severity failure;

    -- ------------------------------------------------------------ U1
    report "U1: ENEC/DISEC broadcast";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U1: el broadcast 0x7E/W no recibio ACK" severity failure;
    c_wr(x"01", q_pp);                               -- DISEC
    c_wr(x"09", q_pp);                               -- ENINT | ENHJ
    c_stop(q_od);
    settle;
    assert ibi_en = '0' and hj_en = '0'
      report "FALLO U1: DISEC no deshabilito IBI/HJ" severity failure;
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"00", q_pp);                               -- ENEC
    c_wr(x"09", q_pp);
    c_stop(q_od);
    settle;
    assert ibi_en = '1' and hj_en = '1'
      report "FALLO U1: ENEC no rehabilito IBI/HJ" severity failure;

    -- ------------------------------------------------------------ U2
    report "U2: SETDASA a la direccion estatica";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"87", q_pp);                               -- SETDASA
    c_sr(q_od);
    c_hdr_pp(TGT_SA & '0', q_pp);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U2: el header SA/W no recibio ACK" severity failure;
    c_wr(x"6A", q_pp);                               -- DA 0x35 << 1
    c_stop(q_od);
    settle;
    assert da_valid = '1' and da = "0110101"
      report "FALLO U2: SETDASA no asigno la DA 0x35" severity failure;

    -- ------------------------------------------------------------ U3
    report "U3: RSTDAA broadcast";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"06", q_pp);
    c_stop(q_od);
    settle;
    assert da_valid = '0'
      report "FALLO U3: RSTDAA no borro la DA" severity failure;
    assert evrst_c = 1
      report "FALLO U3: no se emitio ev_rstdaa" severity failure;

    -- ------------------------------------------------------------ U4
    report "U4: ENTDAA con perdida forzada, retirada y reintento";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"07", q_pp);                               -- ENTDAA
    -- ronda A: interferencia en el bit 5 (PAY(58)='1' -> el target pierde)
    c_sr(q_od);
    c_hdr_pp(x"FD", q_pp);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U4: la ronda A no recibio ACK" severity failure;
    c_daa64(pcap, 5, q_od);
    c_daa_da("0100001", a, q_pp);                    -- DA 0x21 (nadie debe ACKar)
    assert a = '1'
      report "FALLO U4: tras la retirada nadie debia ACKar la DA"
      severity failure;
    settle;
    assert da_valid = '0'
      report "FALLO U4: el target no se retiro del arbitraje ENTDAA"
      severity failure;
    -- ronda B: sin interferencia; el target reintenta y gana
    c_sr(q_od);
    c_hdr_pp(x"FD", q_pp);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U4: el target no reintento en la ronda B" severity failure;
    c_daa64(pcap, -1, q_od);
    assert pcap = PAY
      report "FALLO U4: el payload ENTDAA capturado no coincide con PID+BCR+DCR"
      severity failure;
    c_daa_da("0110000", a, q_pp);                    -- DA 0x30
    assert a = '0'
      report "FALLO U4: la DA asignada no recibio ACK" severity failure;
    settle;
    assert da_valid = '1' and da = "0110000"
      report "FALLO U4: la DA 0x30 no quedo registrada" severity failure;
    -- ronda C: con DA ya asignada debe NACKear
    c_sr(q_od);
    c_hdr_pp(x"FD", q_pp);
    c_ack(a, q_od);
    assert a = '1'
      report "FALLO U4: con DA asignada la ronda C debia terminar en NACK"
      severity failure;
    c_stop(q_od);
    settle;

    -- ------------------------------------------------------------ U5
    report "U5: escritura privada y paridad mala";
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_sr(q_od);
    c_hdr_pp(x"60", q_pp);                           -- DA 0x30 / W
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U5: el header DA/W no recibio ACK" severity failure;
    c_wr(x"A5", q_pp);
    c_wr(x"3C", q_pp);
    c_wr_bad(x"77", q_pp);
    c_wr(x"88", q_pp);                               -- debe ignorarse
    c_stop(q_od);
    settle;
    assert rxn = 2 and rxc(0) = x"A5" and rxc(1) = x"3C"
      report "FALLO U5: bytes de escritura privada incorrectos"
      severity failure;
    assert perr_c = 1
      report "FALLO U5: la paridad mala no genero rx_perr" severity failure;

    -- ------------------------------------------------------------ U6
    report "U6: lecturas privadas";
    ftx(0) <= x"11"; ftx(1) <= x"22"; ftx(2) <= x"33"; ftx(3) <= x"44";
    ftx_n <= 4;
    ftx_rst <= '1';
    tick1;
    ftx_rst <= '0';
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);                           -- DA 0x30 / R
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U6: el header DA/R no recibio ACK" severity failure;
    c_rd(bv, t, false, q_pp);
    assert bv = x"11" and t = '1'
      report "FALLO U6: byte 0 o T incorrectos" severity failure;
    c_rd(bv, t, false, q_pp);
    assert bv = x"22" and t = '1'
      report "FALLO U6: byte 1 o T incorrectos" severity failure;
    c_rd(bv, t, true, q_pp);                         -- seize durante T alto
    assert bv = x"33" and t = '1'
      report "FALLO U6: byte 2 o T incorrectos en el seize" severity failure;
    c_stop_tras_sr(q_od);
    settle;
    assert tren_c = 3
      report "FALLO U6: numero de pops de la FIFO incorrecto" severity failure;
    -- terminacion por el target (T=0)
    ftx(0) <= x"55"; ftx(1) <= x"66";
    ftx_n <= 2;
    ftx_rst <= '1';
    tick1;
    ftx_rst <= '0';
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = x"55" and t = '1'
      report "FALLO U6: byte 0 (frame 2) incorrecto" severity failure;
    c_rd(bv, t, false, q_pp);
    assert bv = x"66" and t = '0'
      report "FALLO U6: el target debia terminar con T=0" severity failure;
    c_stop(q_od);
    settle;
    -- FIFO vacia -> NACK
    ftx_n <= 0;
    ftx_rst <= '1';
    tick1;
    ftx_rst <= '0';
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    assert a = '1'
      report "FALLO U6: DA/R con FIFO vacia debia NACKear" severity failure;
    c_stop(q_od);
    settle;

    -- ------------------------------------------------------------ U7
    report "U7: GET dirigidos";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"8D", q_pp);                               -- GETPID
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U7: GETPID sin ACK" severity failure;
    for i in 0 to 5 loop
      c_rd(bv, t, false, q_pp);
      assert bv = TGT_PID(47 - 8*i downto 40 - 8*i)
        report "FALLO U7: byte " & integer'image(i) & " del PID no coincide"
        severity failure;
      if i < 5 then
        assert t = '1'
          report "FALLO U7: T deberia ser 1 en el PID" severity failure;
      else
        assert t = '0'
          report "FALLO U7: T deberia ser 0 al final del PID" severity failure;
      end if;
    end loop;
    c_stop(q_od);
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"8E", q_pp);                               -- GETBCR
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = TGT_BCR and t = '0'
      report "FALLO U7: GETBCR incorrecto" severity failure;
    c_stop(q_od);
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"8F", q_pp);                               -- GETDCR
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = TGT_DCR and t = '0'
      report "FALLO U7: GETDCR incorrecto" severity failure;
    c_stop(q_od);
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"90", q_pp);                               -- GETSTATUS
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = TGT_STS(15 downto 8) and t = '1'
      report "FALLO U7: GETSTATUS byte alto incorrecto" severity failure;
    c_rd(bv, t, false, q_pp);
    assert bv = TGT_STS(7 downto 0) and t = '0'
      report "FALLO U7: GETSTATUS byte bajo incorrecto" severity failure;
    c_stop(q_od);
    settle;

    -- ------------------------------------------------------------ U8
    report "U8: SETMWL dirigido, SETMRL broadcast, GETMWL/GETMRL";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"89", q_pp);                               -- SETMWL dirigido
    c_sr(q_od);
    c_hdr_pp(x"60", q_pp);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U8: SETMWL DA/W sin ACK" severity failure;
    c_wr(x"02", q_pp);
    c_wr(x"80", q_pp);
    c_stop(q_od);
    settle;
    assert mwl = x"0280"
      report "FALLO U8: SETMWL dirigido no actualizo MWL" severity failure;
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"0A", q_pp);                               -- SETMRL broadcast
    c_wr(x"03", q_pp);
    c_wr(x"00", q_pp);
    c_stop(q_od);
    settle;
    assert mrl = x"0300"
      report "FALLO U8: SETMRL broadcast no actualizo MRL" severity failure;
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"8B", q_pp);                               -- GETMWL
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = x"02" and t = '1'
      report "FALLO U8: GETMWL byte alto incorrecto" severity failure;
    c_rd(bv, t, false, q_pp);
    assert bv = x"80" and t = '0'
      report "FALLO U8: GETMWL byte bajo incorrecto" severity failure;
    c_stop(q_od);
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"8C", q_pp);                               -- GETMRL
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = x"03" and t = '1'
      report "FALLO U8: GETMRL byte alto incorrecto" severity failure;
    c_rd(bv, t, false, q_pp);
    assert bv = x"00" and t = '0'
      report "FALLO U8: GETMRL byte bajo incorrecto" severity failure;
    c_stop(q_od);
    settle;

    -- ------------------------------------------------------------ U9
    report "U9: IBI desde bus libre con mandatory byte";
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    ibi_go <= '1';
    tick1;
    ibi_go <= '0';
    espera_pull("U9");
    c_ibi_resp(true, cap);
    assert cap = x"61"
      report "FALLO U9: el header del IBI no es DA/R" severity failure;
    c_rd(bv, t, false, q_od);
    assert bv = TGT_MDB and t = '0'
      report "FALLO U9: mandatory byte o T incorrectos" severity failure;
    c_stop(q_od);
    settle;
    assert ibid_c = 1 and ibi_pend = '0'
      report "FALLO U9: ibi_done o ibi_pend incorrectos" severity failure;

    report "U9b: IBI rechazado con NACK";
    ibi_go <= '1';
    tick1;
    ibi_go <= '0';
    espera_pull("U9b");
    c_ibi_resp(false, cap);
    c_stop(q_od);
    settle;
    assert ibin_c = 1 and ibi_pend = '0'
      report "FALLO U9b: ibi_nakd o ibi_pend incorrectos" severity failure;

    -- ------------------------------------------------------------ U10
    report "U10: IBI arbitrado sobre un START ajeno";
    -- START del modelo con la peticion IBI entrando en la misma ventana
    sda_m <= '0';
    ibi_go <= '1';
    tick1;
    ibi_go <= '0';
    wait for 2 * q_od;
    scl_m <= '0';
    wait for q_od;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    assert lostv
      report "FALLO U10: el modelo debia perder el arbitraje contra el IBI"
      severity failure;
    assert cap = x"61"
      report "FALLO U10: el header ganador no es DA/R" severity failure;
    c_ackdrv(q_od);
    c_rd(bv, t, false, q_od);
    assert bv = TGT_MDB and t = '0'
      report "FALLO U10: mandatory byte tras el arbitraje incorrecto"
      severity failure;
    c_stop(q_od);
    settle;
    assert ibid_c = 2
      report "FALLO U10: ibi_done no incremento tras el arbitraje"
      severity failure;

    -- ------------------------------------------------------------ U11
    report "U11: hot-join y ENTDAA posterior";
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"06", q_pp);                               -- RSTDAA
    c_stop(q_od);
    settle;
    assert da_valid = '0'
      report "FALLO U11: RSTDAA previo al hot-join no borro la DA"
      severity failure;
    hj_go <= '1';
    tick1;
    hj_go <= '0';
    espera_pull("U11");
    c_ibi_resp(true, cap);
    assert cap = x"04"
      report "FALLO U11: el header de hot-join no es 0x02/W" severity failure;
    c_stop(q_od);
    settle;
    assert hjd_c = 1 and hj_pend = '0'
      report "FALLO U11: hj_done o hj_pend incorrectos" severity failure;
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_wr(x"07", q_pp);
    c_sr(q_od);
    c_hdr_pp(x"FD", q_pp);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U11: el target no participo en el ENTDAA tras el hot-join"
      severity failure;
    c_daa64(pcap, -1, q_od);
    assert pcap = PAY
      report "FALLO U11: payload ENTDAA tras hot-join incorrecto"
      severity failure;
    c_daa_da("0110000", a, q_pp);
    assert a = '0'
      report "FALLO U11: la DA tras hot-join no recibio ACK" severity failure;
    c_stop(q_od);
    settle;
    assert da_valid = '1' and da = "0110000"
      report "FALLO U11: la DA tras hot-join no quedo registrada"
      severity failure;

    -- ------------------------------------------------------------ U12
    report "U12: repeticion a cuartos minimos";
    q_pp <= 20 ns;
    q_od <= 40 ns;
    wait for 100 ns;
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    ftx(0) <= x"5A"; ftx(1) <= x"C3"; ftx(2) <= x"7E";
    ftx_n <= 3;
    ftx_rst <= '1';
    tick1;
    ftx_rst <= '0';
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    assert a = '0'
      report "FALLO U12: broadcast sin ACK a cuartos minimos" severity failure;
    c_sr(q_od);
    c_hdr_pp(x"60", q_pp);
    c_ack(a, q_od);
    c_wr(x"F0", q_pp);
    c_wr(x"0F", q_pp);
    c_stop(q_od);
    settle;
    assert rxn = 2 and rxc(0) = x"F0" and rxc(1) = x"0F"
      report "FALLO U12: escritura a cuartos minimos incorrecta"
      severity failure;
    c_start;
    c_hdr_arb(x"FC", lostv, cap, q_od);
    c_ack(a, q_od);
    c_sr(q_od);
    c_hdr_pp(x"61", q_pp);
    c_ack(a, q_od);
    c_rd(bv, t, false, q_pp);
    assert bv = x"5A" and t = '1'
      report "FALLO U12: byte 0 a cuartos minimos incorrecto" severity failure;
    c_rd(bv, t, true, q_pp);                         -- seize a maxima velocidad
    assert bv = x"C3" and t = '1'
      report "FALLO U12: byte 1 o seize a cuartos minimos incorrectos"
      severity failure;
    c_stop_tras_sr(q_od);
    settle;

    report "CAPA 1B COMPLETA: TODOS LOS TESTS DEL TARGET I3C PASARON";
    finish;
  end process estimulo;

  vigilante : process
  begin
    wait for 20 ms;
    assert false
      report "TIMEOUT GLOBAL: la simulacion no termino" severity failure;
  end process;

end architecture sim;
