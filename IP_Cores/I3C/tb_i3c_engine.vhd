-- ============================================================================
--  tb_i3c_engine.vhd - Capa 1c: controller RTL <-> target RTL cableados en
--  un bus resuelto con pull-up/keeper ('H'). Sin modelos: los dos motores
--  reales negocian ENTDAA, trafico privado, CCCs, IBI, hot-join y el
--  arbitraje, con sus latencias 2FF reales en ambos extremos.
--
--  Esta capa es la pre-validacion exacta del self-test loop_int que ira en
--  silicio: si algo de los handoffs no cierra, debe caer aqui y no en la
--  placa.
--
--  Tests:
--    V1  ENTDAA real de punta a punta (payload, DA 0x30, ronda NACK)
--    V2  Escritura privada con paridad
--    V3  Lectura con seize del controller (rlast+stop) entre dos RTL
--    V4  Lectura terminada por el target (T=0) + STOP sin byte
--    V5  CCC dirigido GETPID real
--    V6  IBI target->controller con mandatory byte
--    V7  Arbitraje simultaneo: el controller pierde 0x7E contra el IBI
--    V8  Hot-join + ENTDAA de reasignacion
--    V9  Barrido de divisores: (div_pp,div_od) = (2,5) y (1,4)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i3c_engine is
end entity;

architecture sim of tb_i3c_engine is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '0';
  signal div_pp : std_logic_vector(15 downto 0) := x"0004";
  signal div_od : std_logic_vector(15 downto 0) := x"0009";

  -- interfaz de comando del controller
  signal cmd_valid, cmd_start, cmd_stop, cmd_read, cmd_rlast : std_logic := '0';
  signal cmd_nobyte, cmd_daa, cmd_daadr, cmd_ibiack, cmd_ibinak : std_logic := '0';
  signal cmd_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal busy, done, rvalid, ack_in, t_bit, arb_lost : std_logic;
  signal rdata, ibi_addr : std_logic_vector(7 downto 0);
  signal ibi_req, ibi_avalid, xact_open : std_logic;
  signal c_scl_o, c_scl_t, c_sda_o, c_sda_t : std_logic;

  -- interfaz del target
  constant TGT_SA  : std_logic_vector(6 downto 0) := "1010010";
  constant TGT_PID : std_logic_vector(47 downto 0) := x"045967ABCDEF";
  constant TGT_BCR : std_logic_vector(7 downto 0)  := x"46";
  constant TGT_DCR : std_logic_vector(7 downto 0)  := x"C6";
  constant TGT_STS : std_logic_vector(15 downto 0) := x"1234";
  constant TGT_MDB : std_logic_vector(7 downto 0)  := x"9C";
  constant PAY : std_logic_vector(63 downto 0) := TGT_PID & TGT_BCR & TGT_DCR;

  signal t_ibi_go, t_hj_go : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0);
  signal tx_valid, tx_ren : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_perr : std_logic;
  signal t_da : std_logic_vector(6 downto 0);
  signal t_da_valid, t_ibi_en, t_hj_en : std_logic;
  signal t_mwl, t_mrl : std_logic_vector(15 downto 0);
  signal t_ibi_pend, t_hj_pend : std_logic;
  signal t_ibi_done, t_ibi_nakd, t_hj_done : std_logic;
  signal t_ev_daset, t_ev_rstdaa, t_in_frame : std_logic;
  signal t_sda_o, t_sda_t : std_logic;

  -- bus resuelto
  signal scl_b, sda_b : std_logic;
  signal scl_iw, sda_iw : std_logic;

  type slv8_arr is array (natural range <>) of std_logic_vector(7 downto 0);

  -- mini-FIFO FWFT del target
  signal ftx     : slv8_arr(0 to 7) := (others => (others => '0'));
  signal ftx_n   : integer := 0;
  signal ftx_i   : integer := 0;
  signal ftx_rst : std_logic := '0';

  -- monitores
  signal rxc : slv8_arr(0 to 7) := (others => (others => '0'));
  signal rxn : integer := 0;
  signal perr_c, ibid_c, ibin_c, hjd_c, evda_c, tren_c : integer := 0;
  signal saw_arb : std_logic := '0';
  signal mon_rst : std_logic := '0';

begin

  clk <= not clk after TCLK / 2;

  -- bus con pull-up/keeper; dos conductores RTL
  scl_b <= 'H';
  sda_b <= 'H';
  scl_b <= c_scl_o when c_scl_t = '0' else 'Z';
  sda_b <= c_sda_o when c_sda_t = '0' else 'Z';
  sda_b <= t_sda_o when t_sda_t = '0' else 'Z';
  scl_iw <= to_x01(scl_b);
  sda_iw <= to_x01(sda_b);

  u_ctrl : entity work.i3c_controller
    port map (
      clk => clk, rst => rst, en => en,
      div_pp => div_pp, div_od => div_od,
      cmd_valid => cmd_valid, cmd_start => cmd_start, cmd_stop => cmd_stop,
      cmd_read => cmd_read, cmd_rlast => cmd_rlast, cmd_nobyte => cmd_nobyte,
      cmd_daa => cmd_daa, cmd_daadr => cmd_daadr,
      cmd_ibiack => cmd_ibiack, cmd_ibinak => cmd_ibinak,
      cmd_wdata => cmd_wdata,
      busy => busy, done => done, rdata => rdata, rvalid => rvalid,
      ack_in => ack_in, t_bit => t_bit, arb_lost => arb_lost,
      ibi_req => ibi_req, ibi_addr => ibi_addr, ibi_avalid => ibi_avalid,
      xact_open => xact_open,
      scl_o => c_scl_o, scl_t => c_scl_t, scl_i => scl_iw,
      sda_o => c_sda_o, sda_t => c_sda_t, sda_i => sda_iw
    );

  u_tgt : entity work.i3c_target
    port map (
      clk => clk, rst => rst, en => en,
      sa => TGT_SA, pid => TGT_PID, bcr => TGT_BCR, dcr => TGT_DCR,
      status_in => TGT_STS, mdb => TGT_MDB,
      ibi_go => t_ibi_go, hj_go => t_hj_go,
      tx_data => tx_data, tx_valid => tx_valid, tx_ren => tx_ren,
      rx_data => rx_data, rx_valid => rx_valid, rx_perr => rx_perr,
      da => t_da, da_valid => t_da_valid, ibi_en => t_ibi_en, hj_en => t_hj_en,
      mwl => t_mwl, mrl => t_mrl,
      ibi_pend => t_ibi_pend, hj_pend => t_hj_pend,
      ibi_done => t_ibi_done, ibi_nakd => t_ibi_nakd, hj_done => t_hj_done,
      ev_daset => t_ev_daset, ev_rstdaa => t_ev_rstdaa, in_frame => t_in_frame,
      scl_i => scl_iw, sda_i => sda_iw, sda_o => t_sda_o, sda_t => t_sda_t
    );

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

  mon : process(clk)
  begin
    if rising_edge(clk) then
      if mon_rst = '1' then
        rxn <= 0; perr_c <= 0; ibid_c <= 0; ibin_c <= 0;
        hjd_c <= 0; evda_c <= 0; tren_c <= 0; saw_arb <= '0';
      else
        if rx_valid = '1' then
          if rxn < 8 then
            rxc(rxn) <= rx_data;
          end if;
          rxn <= rxn + 1;
        end if;
        if rx_perr    = '1' then perr_c <= perr_c + 1; end if;
        if t_ibi_done = '1' then ibid_c <= ibid_c + 1; end if;
        if t_ibi_nakd = '1' then ibin_c <= ibin_c + 1; end if;
        if t_hj_done  = '1' then hjd_c  <= hjd_c + 1;  end if;
        if t_ev_daset = '1' then evda_c <= evda_c + 1; end if;
        if tx_ren     = '1' then tren_c <= tren_c + 1; end if;
        if arb_lost   = '1' then saw_arb <= '1';       end if;
      end if;
    end if;
  end process;

  -- ==========================================================================
  --  ESTIMULO: firmware de ambos extremos
  -- ==========================================================================
  estimulo : process
    variable db  : slv8_arr(0 to 7);
    variable okv : boolean;

    procedure tick1 is
    begin
      wait until rising_edge(clk);
    end procedure;

    procedure icmd(s, p, r, rl, nb, dda, ddr, ia, ink : std_logic;
                   d : std_logic_vector(7 downto 0)) is
    begin
      cmd_start  <= s;  cmd_stop  <= p;  cmd_read   <= r;
      cmd_rlast  <= rl; cmd_nobyte <= nb;
      cmd_daa    <= dda; cmd_daadr <= ddr;
      cmd_ibiack <= ia; cmd_ibinak <= ink;
      cmd_wdata  <= d;
      cmd_valid  <= '1';
      tick1;
      cmd_valid  <= '0';
      cmd_start  <= '0'; cmd_stop <= '0'; cmd_read <= '0'; cmd_rlast <= '0';
      cmd_nobyte <= '0'; cmd_daa <= '0'; cmd_daadr <= '0';
      cmd_ibiack <= '0'; cmd_ibinak <= '0';
    end procedure;

    procedure wdone(msg : string) is
      variable t : integer := 0;
    begin
      loop
        tick1;
        exit when done = '1';
        t := t + 1;
        assert t < 400000
          report "TIMEOUT esperando done: " & msg severity failure;
      end loop;
    end procedure;

    procedure hdr(d : std_logic_vector(7 downto 0); sp : std_logic;
                  msg : string) is
    begin
      icmd('1', sp, '0', '0', '0', '0', '0', '0', '0', d);
      wdone(msg);
    end procedure;

    procedure wrb(d : std_logic_vector(7 downto 0); sp : std_logic;
                  msg : string) is
    begin
      icmd('0', sp, '0', '0', '0', '0', '0', '0', '0', d);
      wdone(msg);
    end procedure;

    procedure rdb(rl, sp : std_logic; msg : string) is
    begin
      icmd('0', sp, '1', rl, '0', '0', '0', '0', '0', x"00");
      wdone(msg);
    end procedure;

    procedure stopc(msg : string) is
    begin
      icmd('0', '1', '0', '0', '1', '0', '0', '0', '0', x"00");
      wdone(msg);
    end procedure;

    procedure daadr(d : std_logic_vector(7 downto 0); msg : string) is
    begin
      icmd('0', '0', '0', '0', '0', '0', '1', '0', '0', d);
      wdone(msg);
    end procedure;

    procedure daa_round(ok : out boolean; bytes : out slv8_arr(0 to 7);
                        msg : string) is
      variable n : integer := 0;
      variable t : integer := 0;
    begin
      icmd('0', '0', '0', '0', '0', '1', '0', '0', '0', x"00");
      loop
        tick1;
        if rvalid = '1' and n < 8 then
          bytes(n) := rdata;
          n := n + 1;
        end if;
        exit when done = '1';
        t := t + 1;
        assert t < 400000
          report "TIMEOUT en ronda ENTDAA: " & msg severity failure;
      end loop;
      ok := (ack_in = '0');
    end procedure;

    procedure wibi(msg : string) is
      variable t : integer := 0;
    begin
      loop
        tick1;
        exit when ibi_req = '1';
        t := t + 1;
        assert t < 400000
          report "TIMEOUT esperando IBI: " & msg severity failure;
      end loop;
    end procedure;

    -- secuencia completa de trafico privado (usada en el barrido V9)
    procedure trafico(tag : string) is
    begin
      ftx(0) <= x"5A"; ftx(1) <= x"C3"; ftx(2) <= x"7E";
      ftx_n <= 3;
      ftx_rst <= '1';
      tick1;
      ftx_rst <= '0';
      mon_rst <= '1';
      tick1;
      mon_rst <= '0';
      hdr(x"FC", '0', tag & " header 0x7E/W");
      assert ack_in = '0'
        report "FALLO " & tag & ": broadcast sin ACK" severity failure;
      hdr(x"60", '0', tag & " Sr DA/W");
      assert ack_in = '0'
        report "FALLO " & tag & ": DA/W sin ACK" severity failure;
      wrb(x"F0", '0', tag & " dato 1");
      wrb(x"0F", '1', tag & " dato 2 + STOP");
      wait for 2 us;
      assert rxn = 2 and rxc(0) = x"F0" and rxc(1) = x"0F"
        report "FALLO " & tag & ": escritura RTL a RTL incorrecta"
        severity failure;
      hdr(x"FC", '0', tag & " header 0x7E/W lectura");
      hdr(x"61", '0', tag & " Sr DA/R");
      assert ack_in = '0'
        report "FALLO " & tag & ": DA/R sin ACK" severity failure;
      rdb('0', '0', tag & " byte 0");
      assert rdata = x"5A" and t_bit = '1'
        report "FALLO " & tag & ": byte 0 incorrecto" severity failure;
      rdb('1', '1', tag & " byte 1 con rlast+stop");
      assert rdata = x"C3" and t_bit = '1'
        report "FALLO " & tag & ": byte 1 o seize incorrectos"
        severity failure;
      wait for 2 us;
    end procedure;

  begin
    rst <= '1';
    en  <= '0';
    wait for 200 ns;
    tick1;
    rst <= '0';
    en  <= '1';
    wait for 300 ns;

    -- ------------------------------------------------------------ V1
    report "V1: ENTDAA real de punta a punta";
    hdr(x"FC", '0', "V1 header 0x7E/W");
    assert ack_in = '0'
      report "FALLO V1: el broadcast 0x7E/W no recibio ACK del target RTL"
      severity failure;
    wrb(x"07", '0', "V1 CCC ENTDAA");
    daa_round(okv, db, "V1 primera ronda");
    assert okv
      report "FALLO V1: la ronda ENTDAA no recibio ACK" severity failure;
    for i in 0 to 7 loop
      assert db(i) = PAY(63 - 8*i downto 56 - 8*i)
        report "FALLO V1: byte " & integer'image(i) &
               " del payload ENTDAA no coincide" severity failure;
    end loop;
    daadr(x"60", "V1 asignacion de DA 0x30");
    assert ack_in = '0'
      report "FALLO V1: la DA asignada no recibio ACK" severity failure;
    wait for 1 us;
    assert t_da_valid = '1' and t_da = "0110000"
      report "FALLO V1: el target RTL no registro la DA 0x30"
      severity failure;
    daa_round(okv, db, "V1 segunda ronda");
    assert not okv
      report "FALLO V1: la segunda ronda debia terminar en NACK"
      severity failure;
    stopc("V1 STOP");
    wait for 2 us;

    -- ------------------------------------------------------------ V2
    report "V2: escritura privada RTL a RTL";
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    hdr(x"FC", '0', "V2 header 0x7E/W");
    hdr(x"60", '0', "V2 Sr DA/W");
    assert ack_in = '0'
      report "FALLO V2: DA/W sin ACK" severity failure;
    wrb(x"A5", '0', "V2 dato 1");
    wrb(x"3C", '1', "V2 dato 2 + STOP");
    wait for 2 us;
    assert rxn = 2 and rxc(0) = x"A5" and rxc(1) = x"3C"
      report "FALLO V2: los bytes no llegaron al target con paridad valida"
      severity failure;
    assert perr_c = 0
      report "FALLO V2: hubo errores de paridad inesperados" severity failure;

    -- ------------------------------------------------------------ V3
    report "V3: lectura con seize entre dos RTL";
    ftx(0) <= x"11"; ftx(1) <= x"22"; ftx(2) <= x"33"; ftx(3) <= x"44";
    ftx_n <= 4;
    ftx_rst <= '1';
    tick1;
    ftx_rst <= '0';
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    hdr(x"FC", '0', "V3 header 0x7E/W");
    hdr(x"61", '0', "V3 Sr DA/R");
    assert ack_in = '0'
      report "FALLO V3: DA/R sin ACK" severity failure;
    rdb('0', '0', "V3 byte 0");
    assert rdata = x"11" and t_bit = '1'
      report "FALLO V3: byte 0 incorrecto" severity failure;
    rdb('0', '0', "V3 byte 1");
    assert rdata = x"22" and t_bit = '1'
      report "FALLO V3: byte 1 incorrecto" severity failure;
    rdb('1', '1', "V3 byte 2 con rlast+stop");
    assert rdata = x"33" and t_bit = '1'
      report "FALLO V3: el seize del T no funciono entre los dos RTL"
      severity failure;
    wait for 2 us;
    assert tren_c = 3
      report "FALLO V3: pops de la FIFO del target incorrectos"
      severity failure;
    assert t_in_frame = '0'
      report "FALLO V3: el target no volvio a bus libre tras el STOP"
      severity failure;

    -- ------------------------------------------------------------ V4
    report "V4: lectura terminada por el target (T=0)";
    ftx(0) <= x"55"; ftx(1) <= x"66";
    ftx_n <= 2;
    ftx_rst <= '1';
    tick1;
    ftx_rst <= '0';
    hdr(x"FC", '0', "V4 header 0x7E/W");
    hdr(x"61", '0', "V4 Sr DA/R");
    rdb('0', '0', "V4 byte 0");
    assert rdata = x"55" and t_bit = '1'
      report "FALLO V4: byte 0 incorrecto" severity failure;
    rdb('0', '0', "V4 byte 1");
    assert rdata = x"66" and t_bit = '0'
      report "FALLO V4: el target RTL debia terminar con T=0"
      severity failure;
    stopc("V4 STOP sin byte");
    wait for 2 us;

    -- ------------------------------------------------------------ V5
    report "V5: CCC dirigido GETPID real";
    hdr(x"FC", '0', "V5 header 0x7E/W");
    wrb(x"8D", '0', "V5 CCC GETPID");
    hdr(x"61", '0', "V5 Sr DA/R");
    assert ack_in = '0'
      report "FALLO V5: GETPID sin ACK" severity failure;
    for i in 0 to 5 loop
      rdb('0', '0', "V5 byte PID " & integer'image(i));
      assert rdata = TGT_PID(47 - 8*i downto 40 - 8*i)
        report "FALLO V5: byte " & integer'image(i) & " del PID no coincide"
        severity failure;
      if i < 5 then
        assert t_bit = '1'
          report "FALLO V5: T deberia ser 1 en el PID" severity failure;
      else
        assert t_bit = '0'
          report "FALLO V5: T deberia ser 0 al final del PID"
          severity failure;
      end if;
    end loop;
    stopc("V5 STOP");
    wait for 2 us;

    -- ------------------------------------------------------------ V6
    report "V6: IBI target RTL -> controller RTL";
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    t_ibi_go <= '1';
    tick1;
    t_ibi_go <= '0';
    wibi("V6");
    assert ibi_addr = x"61"
      report "FALLO V6: la direccion del IBI no es DA/R" severity failure;
    icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
    wdone("V6 ibiack");
    rdb('0', '0', "V6 mandatory byte");
    assert rdata = TGT_MDB and t_bit = '0'
      report "FALLO V6: mandatory byte o T incorrectos" severity failure;
    stopc("V6 STOP");
    wait for 2 us;
    assert ibid_c = 1 and t_ibi_pend = '0'
      report "FALLO V6: ibi_done o ibi_pend del target incorrectos"
      severity failure;

    -- ------------------------------------------------------------ V7
    report "V7: arbitraje simultaneo (el controller pierde)";
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    -- comando del controller y peticion del target en la misma ventana
    cmd_start <= '1';
    cmd_wdata <= x"FC";
    cmd_valid <= '1';
    t_ibi_go  <= '1';
    tick1;
    cmd_valid <= '0';
    cmd_start <= '0';
    t_ibi_go  <= '0';
    wdone("V7 header arbitrado");
    tick1;
    tick1;
    assert saw_arb = '1'
      report "FALLO V7: el controller no reporto arb_lost" severity failure;
    assert ibi_req = '1' and ibi_addr = x"61"
      report "FALLO V7: el header capturado tras la perdida no es DA/R"
      severity failure;
    icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
    wdone("V7 ibiack");
    rdb('0', '0', "V7 mandatory byte");
    assert rdata = TGT_MDB and t_bit = '0'
      report "FALLO V7: mandatory byte tras el arbitraje incorrecto"
      severity failure;
    stopc("V7 STOP");
    wait for 2 us;
    assert ibid_c = 1
      report "FALLO V7: el target no completo su IBI tras ganar"
      severity failure;

    -- ------------------------------------------------------------ V8
    report "V8: hot-join y ENTDAA de reasignacion";
    mon_rst <= '1';
    tick1;
    mon_rst <= '0';
    hdr(x"FC", '0', "V8 header 0x7E/W");
    wrb(x"06", '1', "V8 RSTDAA + STOP");
    wait for 2 us;
    assert t_da_valid = '0'
      report "FALLO V8: RSTDAA no borro la DA del target" severity failure;
    t_hj_go <= '1';
    tick1;
    t_hj_go <= '0';
    wibi("V8 hot-join");
    assert ibi_addr = x"04"
      report "FALLO V8: el header de hot-join no es 0x02/W" severity failure;
    icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
    wdone("V8 ibiack");
    wait for 1 us;
    assert hjd_c = 1 and t_hj_pend = '0'
      report "FALLO V8: hj_done o hj_pend del target incorrectos"
      severity failure;
    hdr(x"FC", '0', "V8 Sr 0x7E/W");
    wrb(x"07", '0', "V8 CCC ENTDAA");
    daa_round(okv, db, "V8 ronda de reasignacion");
    assert okv
      report "FALLO V8: la ronda tras hot-join no recibio ACK"
      severity failure;
    daadr(x"60", "V8 DA 0x30");
    assert ack_in = '0'
      report "FALLO V8: la DA tras hot-join no recibio ACK" severity failure;
    stopc("V8 STOP");
    wait for 2 us;
    assert t_da_valid = '1' and t_da = "0110000"
      report "FALLO V8: la DA tras hot-join no quedo registrada"
      severity failure;

    -- ------------------------------------------------------------ V9
    report "V9: barrido de divisores (2,5)";
    div_pp <= x"0002";
    div_od <= x"0005";
    wait for 200 ns;
    trafico("V9a");

    report "V9: barrido de divisores (1,4) - 12.5 MHz";
    div_pp <= x"0001";
    div_od <= x"0004";
    wait for 200 ns;
    trafico("V9b");

    report "CAPA 1C COMPLETA: CONTROLLER Y TARGET RTL SE ENTIENDEN EN EL BUS";
    finish;
  end process estimulo;

  vigilante : process
  begin
    wait for 20 ms;
    assert false
      report "TIMEOUT GLOBAL: la simulacion no termino" severity failure;
  end process;

end architecture sim;
