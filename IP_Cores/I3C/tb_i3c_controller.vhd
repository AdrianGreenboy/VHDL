-- ============================================================================
--  tb_i3c_controller.vhd - Capa 1a: motor controller I3C contra un modelo
--  de target INDEPENDIENTE por eventos.
--
--  El modelo no comparte una linea de codigo con el RTL: es una FSM propia
--  que vive de los flancos de SCL/SDA del bus (con pull-up 'H'), decodifica
--  START/Sr/STOP globalmente, verifica las paridades T con asserts, arbitra
--  su propia direccion cuando emite IBI y participa en ENTDAA bit a bit con
--  su payload PID+BCR+DCR.
--
--  Tests:
--    T1  CCC broadcast (ENEC + byte definitorio) y STOP
--    T2  ENTDAA completo: colecta de 64 bits, asignacion de DA, ronda NACK
--    T2b CCC dirigido GETPID (Sr DA/R, 6 bytes, T=0 final)
--    T3  Escritura privada con paridad
--    T4  Lectura terminada por el controller (rlast + stop: Sr + P)
--    T5  Lectura terminada por el target (T=0) y STOP sin byte
--    T6  NACK a direccion desconocida
--    T7  IBI desde reposo con mandatory byte; T7b IBI rechazado (NACK)
--    T8  Perdida de arbitraje del header contra un IBI
--    T9  Hot-join aceptado (IBI desde 0x02/W)
--    T10 Repeticion a divisor minimo (div_pp=1 -> 12.5 MHz)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i3c_controller is
end entity;

architecture sim of tb_i3c_controller is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '0';
  signal div_pp : std_logic_vector(15 downto 0) := x"0004";
  signal div_od : std_logic_vector(15 downto 0) := x"0009";

  signal cmd_valid, cmd_start, cmd_stop, cmd_read, cmd_rlast : std_logic := '0';
  signal cmd_nobyte, cmd_daa, cmd_daadr, cmd_ibiack, cmd_ibinak : std_logic := '0';
  signal cmd_wdata : std_logic_vector(7 downto 0) := (others => '0');

  signal busy, done, rvalid, ack_in, t_bit, arb_lost : std_logic;
  signal rdata, ibi_addr : std_logic_vector(7 downto 0);
  signal ibi_req, ibi_avalid, xact_open : std_logic;

  signal scl_o, scl_t, sda_o, sda_t : std_logic;
  signal scl_iw, sda_iw : std_logic;

  -- bus con pull-up debil
  signal scl_b, sda_b : std_logic;
  signal m_sda : std_logic := 'Z';

  -- constantes del target modelado
  constant TGT_PID : std_logic_vector(47 downto 0) := x"045967ABCDEF";
  constant TGT_BCR : std_logic_vector(7 downto 0)  := x"46";
  constant TGT_DCR : std_logic_vector(7 downto 0)  := x"C6";
  constant TGT_MDB : std_logic_vector(7 downto 0)  := x"9C";
  constant PAY : std_logic_vector(63 downto 0) := TGT_PID & TGT_BCR & TGT_DCR;

  type slv8_arr is array (natural range <>) of std_logic_vector(7 downto 0);

  -- control y observacion del modelo
  signal m_tx      : slv8_arr(0 to 7) := (others => (others => '0'));
  signal m_tx_len  : integer := 0;
  signal ibi_go    : std_logic := '0';
  signal ibi_arb   : std_logic := '0';
  signal ibi_hj    : std_logic := '0';
  signal m_da      : std_logic_vector(6 downto 0) := (others => '0');
  signal m_has_da  : std_logic := '0';
  signal m_ccc     : std_logic_vector(7 downto 0) := x"FF";
  signal m_cccd    : slv8_arr(0 to 3) := (others => (others => '0'));
  signal m_cccd_n  : integer := 0;
  signal m_rx      : slv8_arr(0 to 7) := (others => (others => '0'));
  signal m_rx_n    : integer := 0;
  signal m_stops   : integer := 0;
  signal m_ibi_acked  : integer := 0;
  signal m_ibi_nacked : integer := 0;

  -- monitor de pulsos
  signal saw_arb : std_logic := '0';
  signal clr_mon : std_logic := '0';

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

  -- pull-ups y conductores del bus
  scl_b <= 'H';
  sda_b <= 'H';
  scl_b <= scl_o when scl_t = '0' else 'Z';
  sda_b <= sda_o when sda_t = '0' else 'Z';
  sda_b <= m_sda;
  scl_iw <= to_x01(scl_b);
  sda_iw <= to_x01(sda_b);

  dut : entity work.i3c_controller
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
      scl_o => scl_o, scl_t => scl_t, scl_i => scl_iw,
      sda_o => sda_o, sda_t => sda_t, sda_i => sda_iw
    );

  -- monitor de arb_lost (pulso -> pegajoso)
  process(clk)
  begin
    if rising_edge(clk) then
      if clr_mon = '1' then
        saw_arb <= '0';
      elsif arb_lost = '1' then
        saw_arb <= '1';
      end if;
    end if;
  end process;

  -- ==========================================================================
  --  MODELO DE TARGET INDEPENDIENTE (por eventos de bus)
  -- ==========================================================================
  modelo : process
    type tm_t is (MI_IDLE, MI_HDR, MI_HACKF, MI_HACKR, MI_IBIACK,
                  MI_CCC, MI_CCCD, MI_WD, MI_RD, MI_RDT, MI_RD0,
                  MI_DAAP, MI_DAAA, MI_DAAK, MI_DAAK2, MI_WAITP);
    variable pscl, psda : std_logic := '1';
    variable vscl, vsda : std_logic;
    variable sclr, sclf, sdar, sdaf : boolean;
    variable startc, stopc : boolean;
    variable mst   : tm_t := MI_IDLE;
    variable nxtv  : tm_t := MI_WAITP;
    variable bitc  : integer := 0;
    variable sh    : std_logic_vector(7 downto 0) := (others => '0');
    variable b     : std_logic;
    variable arb, lostv, selfstart : boolean := false;
    variable ibipend : boolean := false;
    variable myhdr : std_logic_vector(7 downto 0) := (others => '0');
    variable dirccc : std_logic_vector(7 downto 0) := x"FF";
    variable txsrc, txi, txbit, txlen : integer := 0;
    variable curb  : std_logic_vector(7 downto 0) := (others => '0');
    variable tlast : std_logic := '0';
    variable dk    : integer := 0;
    variable rxn   : integer := 0;
    variable cccn  : integer := 0;
    variable dav   : std_logic_vector(6 downto 0) := (others => '0');
    variable hasda, daaen : boolean := false;
    variable ackd  : boolean;

    impure function fget(src : integer; i : integer)
      return std_logic_vector is
    begin
      if src = 1 then
        return TGT_PID(47 - 8*i downto 40 - 8*i);
      elsif src = 2 then
        return TGT_MDB;
      else
        return m_tx(i);
      end if;
    end function;

  begin
    wait on scl_b, sda_b, ibi_go;
    vscl := to_x01(scl_b);
    vsda := to_x01(sda_b);
    sclr := (vscl = '1') and (pscl = '0');
    sclf := (vscl = '0') and (pscl = '1');
    sdar := (vsda = '1') and (psda = '0');
    sdaf := (vsda = '0') and (psda = '1');
    startc := sdaf and (vscl = '1');
    stopc  := sdar and (vscl = '1');

    -- lanzamiento de IBI propio cuando el bus esta libre
    if ibi_go = '1' and not ibipend then
      ibipend := true;
    end if;
    if ibipend and mst = MI_IDLE and vscl = '1' and vsda = '1' then
      ibipend := false;
      selfstart := true;
      if ibi_hj = '1' then
        myhdr := x"04";                      -- 0x02 << 1 | W (hot-join)
      else
        myhdr := dav & '1';                  -- DA propia + R
      end if;
      m_sda <= '0';                          -- START de target
    end if;

    if stopc then
      mst := MI_IDLE;
      m_sda <= 'Z';
      m_stops <= m_stops + 1;
      dirccc := x"FF";
      arb := false;
      selfstart := false;

    elsif startc then
      if selfstart then
        arb := true;                         -- IBI propio: mantener SDA bajo
        selfstart := false;
      else
        arb := (ibi_arb = '1') and (mst = MI_IDLE);
        if arb then
          myhdr := dav & '1';
        end if;
        m_sda <= 'Z';
      end if;
      mst := MI_HDR;
      bitc := 0;
      sh := (others => '0');
      lostv := false;

    else
      case mst is

        when MI_IDLE | MI_WAITP =>
          null;

        when MI_HDR =>
          if sclf then
            if arb and not lostv then
              if myhdr(7 - bitc) = '0' then
                m_sda <= '0';
              else
                m_sda <= 'Z';
              end if;
            end if;
          elsif sclr then
            b := vsda;
            if arb and not lostv then
              if myhdr(7 - bitc) = '1' and b = '0' then
                lostv := true;
                m_sda <= 'Z';
              end if;
            end if;
            sh := sh(6 downto 0) & b;
            bitc := bitc + 1;
            if bitc = 8 then
              mst := MI_HACKF;
            end if;
          end if;

        when MI_HACKF =>
          if sclf then
            if arb and not lostv then
              m_sda <= 'Z';                  -- ganamos el IBI: ACK del controller
              mst := MI_IBIACK;
            else
              ackd := false;
              nxtv := MI_WAITP;
              if sh = x"FC" then
                ackd := true;
                nxtv := MI_CCC;
              elsif sh = x"FD" and daaen and (not hasda) then
                ackd := true;
                nxtv := MI_DAAP;
              elsif hasda and sh(7 downto 1) = dav then
                ackd := true;
                if sh(0) = '0' then
                  nxtv := MI_WD;
                  rxn := 0;
                else
                  nxtv := MI_RD;
                  if dirccc = x"8D" then
                    txsrc := 1; txlen := 6;  -- GETPID
                  else
                    txsrc := 0; txlen := m_tx_len;
                  end if;
                  txi := 0;
                end if;
              end if;
              if ackd then
                m_sda <= '0';
                mst := MI_HACKR;
              else
                m_sda <= 'Z';
                mst := MI_WAITP;
              end if;
            end if;
          end if;

        when MI_HACKR =>
          if sclf then
            if nxtv = MI_RD then
              curb := fget(txsrc, txi);
              if curb(7) = '1' then m_sda <= '1'; else m_sda <= '0'; end if;
              txbit := 1;
              mst := MI_RD;
            elsif nxtv = MI_DAAP then
              if PAY(63) = '1' then m_sda <= 'Z'; else m_sda <= '0'; end if;
              dk := 0;
              mst := MI_DAAP;
            else
              m_sda <= 'Z';
              bitc := 0;
              sh := (others => '0');
              cccn := 0;
              mst := nxtv;
            end if;
          end if;

        when MI_IBIACK =>
          if sclr then
            b := vsda;
            if b = '0' then
              m_ibi_acked <= m_ibi_acked + 1;
              if myhdr(0) = '1' then
                txsrc := 2; txlen := 1; txi := 0;
                nxtv := MI_RD;
                mst := MI_HACKR;             -- al siguiente flanco conduce el MDB
              else
                mst := MI_WAITP;             -- hot-join: direccion de escritura
              end if;
            else
              m_ibi_nacked <= m_ibi_nacked + 1;
              mst := MI_WAITP;
            end if;
          end if;

        when MI_CCC =>
          if sclr then
            if bitc < 8 then
              sh := sh(6 downto 0) & vsda;
              bitc := bitc + 1;
            else
              assert vsda = (not pxor(sh))
                report "FALLO modelo: paridad del byte CCC incorrecta"
                severity failure;
              m_ccc <= sh;
              case sh is
                when x"00" => null;                       -- ENEC
                when x"01" => null;                       -- DISEC
                when x"06" => hasda := false;             -- RSTDAA
                              m_has_da <= '0';
                when x"07" => daaen := true;              -- ENTDAA
                when others =>
                  if sh(7) = '1' then
                    dirccc := sh;                         -- CCC dirigido
                  end if;
              end case;
              bitc := 0;
              sh := (others => '0');
              cccn := 0;
              mst := MI_CCCD;
            end if;
          end if;

        when MI_CCCD =>
          if sclr then
            if bitc < 8 then
              sh := sh(6 downto 0) & vsda;
              bitc := bitc + 1;
            else
              assert vsda = (not pxor(sh))
                report "FALLO modelo: paridad de byte de datos CCC incorrecta"
                severity failure;
              if cccn < 4 then
                m_cccd(cccn) <= sh;
                cccn := cccn + 1;
                m_cccd_n <= cccn;
              end if;
              bitc := 0;
              sh := (others => '0');
            end if;
          end if;

        when MI_WD =>
          if sclr then
            if bitc < 8 then
              sh := sh(6 downto 0) & vsda;
              bitc := bitc + 1;
            else
              assert vsda = (not pxor(sh))
                report "FALLO modelo: paridad de escritura privada incorrecta"
                severity failure;
              if rxn < 8 then
                m_rx(rxn) <= sh;
                rxn := rxn + 1;
                m_rx_n <= rxn;
              end if;
              bitc := 0;
              sh := (others => '0');
            end if;
          end if;

        when MI_RD =>
          if sclf then
            if txbit < 8 then
              if curb(7 - txbit) = '1' then m_sda <= '1'; else m_sda <= '0'; end if;
              txbit := txbit + 1;
            elsif txbit = 8 then
              if txi < txlen - 1 then tlast := '1'; else tlast := '0'; end if;
              if tlast = '1' then m_sda <= '1'; else m_sda <= '0'; end if;
              txbit := 9;
            end if;
          elsif sclr then
            if txbit = 9 then
              if tlast = '1' then
                m_sda <= 'Z';                -- handoff del T: suelta en la subida
                mst := MI_RDT;
              else
                mst := MI_RD0;               -- T=0: mantiene bajo hasta la bajada
              end if;
            end if;
          end if;

        when MI_RDT =>
          if sclf then
            txi := txi + 1;
            curb := fget(txsrc, txi);
            if curb(7) = '1' then m_sda <= '1'; else m_sda <= '0'; end if;
            txbit := 1;
            mst := MI_RD;
          end if;

        when MI_RD0 =>
          if sclf then
            m_sda <= 'Z';
            mst := MI_WAITP;
          end if;

        when MI_DAAP =>
          if sclr then
            b := vsda;
            if (not lostv) and PAY(63 - dk) = '1' and b = '0' then
              lostv := true;
              m_sda <= 'Z';
              mst := MI_WAITP;
            else
              dk := dk + 1;
              if dk = 64 then
                bitc := 0;
                sh := (others => '0');
                mst := MI_DAAA;
              end if;
            end if;
          elsif sclf then
            if dk < 64 then
              if PAY(63 - dk) = '1' then m_sda <= 'Z'; else m_sda <= '0'; end if;
            end if;
          end if;

        when MI_DAAA =>
          if sclf then
            m_sda <= 'Z';                    -- soltar tras el ultimo bit de payload
          elsif sclr then
            sh := sh(6 downto 0) & vsda;
            bitc := bitc + 1;
            if bitc = 8 then
              assert sh(0) = (not pxor(sh(7 downto 1)))
                report "FALLO modelo: paridad de la DA en ENTDAA incorrecta"
                severity failure;
              dav := sh(7 downto 1);
              hasda := true;
              m_da <= dav;
              m_has_da <= '1';
              mst := MI_DAAK;
            end if;
          end if;

        when MI_DAAK =>
          if sclf then
            m_sda <= '0';                    -- ACK de la DA asignada
            mst := MI_DAAK2;
          end if;

        when MI_DAAK2 =>
          if sclf then
            m_sda <= 'Z';
            mst := MI_WAITP;
          end if;

      end case;
    end if;

    pscl := vscl;
    psda := vsda;
  end process modelo;

  -- ==========================================================================
  --  ESTIMULO
  -- ==========================================================================
  estimulo : process
    variable db  : slv8_arr(0 to 7);
    variable okv : boolean;
    variable est : integer := 0;   -- STOPs esperados

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

  begin
    rst <= '1';
    en  <= '0';
    wait for 200 ns;
    tick1;
    rst <= '0';
    en  <= '1';
    wait for 100 ns;

    -- ------------------------------------------------------------ T1
    report "T1: CCC broadcast ENEC";
    hdr(x"FC", '0', "T1 header 0x7E/W");
    assert ack_in = '0'
      report "FALLO T1: el broadcast 0x7E/W no recibio ACK" severity failure;
    wrb(x"00", '0', "T1 CCC ENEC");
    wrb(x"01", '1', "T1 byte definitorio + STOP");
    est := est + 1;
    wait for 2 us;
    assert m_ccc = x"00"
      report "FALLO T1: el modelo no registro el CCC ENEC" severity failure;
    assert m_cccd_n = 1 and m_cccd(0) = x"01"
      report "FALLO T1: byte definitorio del CCC incorrecto" severity failure;
    assert m_stops = est
      report "FALLO T1: el modelo no vio el STOP" severity failure;

    -- ------------------------------------------------------------ T2
    report "T2: ENTDAA completo";
    hdr(x"FC", '0', "T2 header 0x7E/W");
    assert ack_in = '0'
      report "FALLO T2: el broadcast 0x7E/W no recibio ACK" severity failure;
    wrb(x"07", '0', "T2 CCC ENTDAA");
    daa_round(okv, db, "T2 primera ronda");
    assert okv
      report "FALLO T2: la ronda ENTDAA no recibio ACK" severity failure;
    for i in 0 to 7 loop
      assert db(i) = PAY(63 - 8*i downto 56 - 8*i)
        report "FALLO T2: byte " & integer'image(i) &
               " del payload ENTDAA no coincide" severity failure;
    end loop;
    daadr(x"60", "T2 asignacion de DA 0x30");
    assert ack_in = '0'
      report "FALLO T2: la DA asignada no recibio ACK" severity failure;
    wait for 1 us;
    assert m_has_da = '1' and m_da = "0110000"
      report "FALLO T2: el modelo no registro la DA 0x30" severity failure;
    daa_round(okv, db, "T2 segunda ronda");
    assert not okv
      report "FALLO T2: la segunda ronda ENTDAA debia terminar en NACK"
      severity failure;
    stopc("T2 STOP");
    est := est + 1;
    wait for 2 us;
    assert m_stops = est
      report "FALLO T2: STOP no registrado" severity failure;

    -- ------------------------------------------------------------ T2b
    report "T2b: CCC dirigido GETPID";
    hdr(x"FC", '0', "T2b header 0x7E/W");
    wrb(x"8D", '0', "T2b CCC GETPID");
    hdr(x"61", '0', "T2b Sr DA/R");
    assert ack_in = '0'
      report "FALLO T2b: el header DA/R no recibio ACK" severity failure;
    for i in 0 to 5 loop
      rdb('0', '0', "T2b byte PID " & integer'image(i));
      assert rdata = TGT_PID(47 - 8*i downto 40 - 8*i)
        report "FALLO T2b: byte " & integer'image(i) & " del PID no coincide"
        severity failure;
      if i < 5 then
        assert t_bit = '1'
          report "FALLO T2b: T deberia ser 1 con mas datos" severity failure;
      else
        assert t_bit = '0'
          report "FALLO T2b: T deberia ser 0 en el ultimo byte" severity failure;
      end if;
    end loop;
    stopc("T2b STOP");
    est := est + 1;
    wait for 2 us;

    -- ------------------------------------------------------------ T3
    report "T3: escritura privada";
    hdr(x"FC", '0', "T3 header 0x7E/W");
    hdr(x"60", '0', "T3 Sr DA/W");
    assert ack_in = '0'
      report "FALLO T3: el header DA/W no recibio ACK" severity failure;
    wrb(x"A5", '0', "T3 dato 1");
    wrb(x"3C", '1', "T3 dato 2 + STOP");
    est := est + 1;
    wait for 2 us;
    assert m_rx_n = 2 and m_rx(0) = x"A5" and m_rx(1) = x"3C"
      report "FALLO T3: datos de escritura privada incorrectos en el modelo"
      severity failure;
    assert m_stops = est
      report "FALLO T3: STOP no registrado" severity failure;

    -- ------------------------------------------------------------ T4
    report "T4: lectura terminada por el controller (rlast+stop)";
    m_tx(0) <= x"11"; m_tx(1) <= x"22"; m_tx(2) <= x"33"; m_tx(3) <= x"44";
    m_tx_len <= 4;
    tick1;
    hdr(x"FC", '0', "T4 header 0x7E/W");
    hdr(x"61", '0', "T4 Sr DA/R");
    assert ack_in = '0'
      report "FALLO T4: el header DA/R no recibio ACK" severity failure;
    rdb('0', '0', "T4 byte 0");
    assert rdata = x"11" and t_bit = '1'
      report "FALLO T4: byte 0 o T incorrectos" severity failure;
    rdb('0', '0', "T4 byte 1");
    assert rdata = x"22" and t_bit = '1'
      report "FALLO T4: byte 1 o T incorrectos" severity failure;
    rdb('1', '1', "T4 byte 2 con rlast+stop");
    assert rdata = x"33" and t_bit = '1'
      report "FALLO T4: byte 2 o T incorrectos" severity failure;
    est := est + 1;
    wait for 2 us;
    assert m_stops = est
      report "FALLO T4: el modelo no vio el STOP tras el Sr de terminacion"
      severity failure;

    -- ------------------------------------------------------------ T5
    report "T5: lectura terminada por el target (T=0)";
    m_tx_len <= 2;
    tick1;
    hdr(x"FC", '0', "T5 header 0x7E/W");
    hdr(x"61", '0', "T5 Sr DA/R");
    rdb('0', '0', "T5 byte 0");
    assert rdata = x"11" and t_bit = '1'
      report "FALLO T5: byte 0 o T incorrectos" severity failure;
    rdb('0', '0', "T5 byte 1");
    assert rdata = x"22" and t_bit = '0'
      report "FALLO T5: el target debia terminar con T=0" severity failure;
    stopc("T5 STOP sin byte");
    est := est + 1;
    wait for 2 us;
    assert m_stops = est
      report "FALLO T5: STOP no registrado" severity failure;

    -- ------------------------------------------------------------ T6
    report "T6: NACK a direccion desconocida";
    hdr(x"54", '1', "T6 header DA desconocida + STOP");
    assert ack_in = '1'
      report "FALLO T6: una DA desconocida no debia recibir ACK"
      severity failure;
    est := est + 1;
    wait for 2 us;
    assert m_stops = est
      report "FALLO T6: STOP no registrado" severity failure;

    -- ------------------------------------------------------------ T7
    report "T7: IBI desde reposo con mandatory byte";
    ibi_go <= '1';
    wibi("T7");
    assert ibi_addr = x"61"
      report "FALLO T7: la direccion del IBI no es DA/R" severity failure;
    ibi_go <= '0';
    icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
    wdone("T7 ibiack");
    rdb('0', '0', "T7 mandatory byte");
    assert rdata = TGT_MDB and t_bit = '0'
      report "FALLO T7: mandatory byte o T incorrectos" severity failure;
    stopc("T7 STOP");
    est := est + 1;
    wait for 2 us;
    assert m_ibi_acked = 1
      report "FALLO T7: el modelo no vio el ACK de su IBI" severity failure;

    -- ------------------------------------------------------------ T7b
    report "T7b: IBI rechazado con NACK";
    ibi_go <= '1';
    wibi("T7b");
    ibi_go <= '0';
    icmd('0', '1', '0', '0', '0', '0', '0', '0', '1', x"00");
    wdone("T7b ibinak+stop");
    est := est + 1;
    wait for 2 us;
    assert m_ibi_nacked = 1
      report "FALLO T7b: el modelo no vio el NACK de su IBI" severity failure;
    assert m_stops = est
      report "FALLO T7b: STOP no registrado" severity failure;

    -- ------------------------------------------------------------ T8
    report "T8: perdida de arbitraje contra un IBI";
    clr_mon <= '1';
    tick1;
    clr_mon <= '0';
    ibi_arb <= '1';
    hdr(x"FC", '0', "T8 header 0x7E/W arbitrado");
    ibi_arb <= '0';
    tick1;
    tick1;
    assert saw_arb = '1'
      report "FALLO T8: no se emitio arb_lost" severity failure;
    assert ibi_req = '1' and ibi_addr = x"61"
      report "FALLO T8: el header capturado tras la perdida no es DA/R"
      severity failure;
    icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
    wdone("T8 ibiack");
    rdb('0', '0', "T8 mandatory byte");
    assert rdata = TGT_MDB and t_bit = '0'
      report "FALLO T8: mandatory byte tras arbitraje incorrecto"
      severity failure;
    stopc("T8 STOP");
    est := est + 1;
    wait for 2 us;
    assert m_ibi_acked = 2
      report "FALLO T8: el modelo no vio el ACK tras ganar el arbitraje"
      severity failure;

    -- ------------------------------------------------------------ T9
    report "T9: hot-join aceptado";
    ibi_hj <= '1';
    ibi_go <= '1';
    wibi("T9");
    assert ibi_addr = x"04"
      report "FALLO T9: el header de hot-join no es 0x02/W" severity failure;
    ibi_go <= '0';
    ibi_hj <= '0';
    icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
    wdone("T9 ibiack");
    stopc("T9 STOP");
    est := est + 1;
    wait for 2 us;
    assert m_ibi_acked = 3
      report "FALLO T9: el modelo no vio el ACK del hot-join" severity failure;

    -- ------------------------------------------------------------ T10
    report "T10: repeticion a divisor minimo (12.5 MHz)";
    div_pp <= x"0001";
    div_od <= x"0004";
    m_tx(0) <= x"5A"; m_tx(1) <= x"C3";
    m_tx_len <= 2;
    tick1;
    hdr(x"FC", '0', "T10 header 0x7E/W");
    assert ack_in = '0'
      report "FALLO T10: broadcast sin ACK a divisor minimo" severity failure;
    hdr(x"60", '0', "T10 Sr DA/W");
    wrb(x"F0", '0', "T10 dato 1");
    wrb(x"0F", '1', "T10 dato 2 + STOP");
    est := est + 1;
    wait for 1 us;
    assert m_rx_n = 2 and m_rx(0) = x"F0" and m_rx(1) = x"0F"
      report "FALLO T10: escritura a divisor minimo incorrecta"
      severity failure;
    hdr(x"FC", '0', "T10 header 0x7E/W lectura");
    hdr(x"61", '0', "T10 Sr DA/R");
    rdb('0', '0', "T10 byte 0");
    assert rdata = x"5A" and t_bit = '1'
      report "FALLO T10: byte 0 a divisor minimo incorrecto" severity failure;
    rdb('1', '1', "T10 byte 1 con rlast+stop");
    assert rdata = x"C3" and t_bit = '0'
      report "FALLO T10: byte 1 o T a divisor minimo incorrectos"
      severity failure;
    est := est + 1;
    wait for 2 us;
    assert m_stops = est
      report "FALLO T10: STOPs finales no registrados" severity failure;

    report "CAPA 1A COMPLETA: TODOS LOS TESTS DEL CONTROLLER I3C PASARON";
    finish;
  end process estimulo;

  -- vigilante global
  vigilante : process
  begin
    wait for 12 ms;
    assert false
      report "TIMEOUT GLOBAL: la simulacion no termino" severity failure;
  end process;

end architecture sim;
