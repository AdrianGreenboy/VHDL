-- ============================================================================
--  i3c_target.vhd - Motor target MIPI I3C SDR completo (capa 1b)
--
--  Esclavo puro de flancos: NUNCA conduce SCL (en I3C no hay stretching);
--  observa SCL/SDA sincronizados con doble FF y conduce SDA en las ventanas
--  que le corresponden. START/Sr/STOP se detectan globalmente en cualquier
--  estado.
--
--  Capacidades:
--    - Matching de header contra 0x7E, la DA dinamica y la SA estatica
--      (esta ultima solo bajo SETDASA pendiente).
--    - ENTDAA completo: ACK a 0x7E/R mientras este armado y sin DA,
--      emision open-drain de PID+BCR+DCR con monitoreo de arbitraje bit a
--      bit, retirada limpia al perder y REINTENTO automatico en la
--      siguiente ronda (Sr + 0x7E/R). Recepcion de DA+paridad, ACK y
--      captura de la DA.
--    - CCCs broadcast en hardware: ENEC(0x00)/DISEC(0x01) con byte de
--      eventos (bit0 ENINT -> ibi_en, bit3 ENHJ -> hj_en), RSTDAA(0x06),
--      ENTDAA(0x07), SETMWL(0x09)/SETMRL(0x0A) de 2 bytes.
--    - CCCs dirigidos en hardware: ENEC(0x80)/DISEC(0x81), SETDASA(0x87)
--      a la SA, SETMWL(0x89)/SETMRL(0x8A), GETMWL(0x8B)/GETMRL(0x8C),
--      GETPID(0x8D)/GETBCR(0x8E)/GETDCR(0x8F), GETSTATUS(0x90). Los GET
--      responden en trama desde los puertos/registros con T=0 al final.
--    - Escritura privada con verificacion de paridad T: byte bueno ->
--      rx_valid; paridad mala -> rx_perr y se ignora el resto de la trama.
--    - Lectura privada desde interfaz FIFO FWFT (tx_data/tx_valid/tx_ren);
--      T=1 mientras haya mas datos; NACK a DA/R con la FIFO vacia. Maneja
--      la terminacion por el controller (Sr durante T alto) y la propia
--      (T=0 en el ultimo byte).
--    - IBI con mandatory byte: peticion por pulso ibi_go; se lanza desde
--      bus libre (jala SDA = START) o arbitra el header de un START ajeno.
--      Si pierde el arbitraje se retira y el header recibido se procesa
--      con normalidad. Tras el ACK del controller emite el MDB con T=0.
--    - Hot-join: pulso hj_go sin DA valida; header 0x02/W arbitrado; tras
--      el ACK espera el ENTDAA del controller.
--
--  Handoffs criticos (documentados por ser el riesgo n.1 del proyecto):
--    - El ACK se conduce en la bajada de SCL posterior al bit 8 y se
--      libera en la bajada siguiente (o se encadena el primer bit de dato
--      de lectura en ese mismo flanco).
--    - En lecturas con T=1 el target libera SDA al detectar la SUBIDA de
--      SCL del bit T (via 2FF, +2 ciclos), dejando la linea al keeper para
--      que el controller pueda apoderarse (Sr) o dejar caer SCL (continua).
--    - Tras el bit 63 del payload ENTDAA libera SDA en la bajada siguiente
--      para ceder el bus a la DA que envia el controller.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i3c_target is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                       -- sincrono, activo alto
    en        : in  std_logic;

    -- identidad y configuracion
    sa        : in  std_logic_vector(6 downto 0);    -- direccion estatica
    pid       : in  std_logic_vector(47 downto 0);
    bcr       : in  std_logic_vector(7 downto 0);
    dcr       : in  std_logic_vector(7 downto 0);
    status_in : in  std_logic_vector(15 downto 0);   -- respuesta GETSTATUS
    mdb       : in  std_logic_vector(7 downto 0);    -- mandatory byte de IBI

    -- peticiones de eventos
    ibi_go    : in  std_logic;                       -- pulso
    hj_go     : in  std_logic;                       -- pulso

    -- datos target -> controller (lecturas privadas), FIFO FWFT
    tx_data   : in  std_logic_vector(7 downto 0);
    tx_valid  : in  std_logic;
    tx_ren    : out std_logic;                       -- pulso: byte consumido

    -- datos controller -> target (escrituras privadas)
    rx_data   : out std_logic_vector(7 downto 0);
    rx_valid  : out std_logic;                       -- pulso
    rx_perr   : out std_logic;                       -- pulso: paridad mala

    -- estado
    da        : out std_logic_vector(6 downto 0);
    da_valid  : out std_logic;
    ibi_en    : out std_logic;
    hj_en     : out std_logic;
    mwl       : out std_logic_vector(15 downto 0);
    mrl       : out std_logic_vector(15 downto 0);
    ibi_pend  : out std_logic;
    hj_pend   : out std_logic;
    ibi_done  : out std_logic;                       -- pulso
    ibi_nakd  : out std_logic;                       -- pulso
    hj_done   : out std_logic;                       -- pulso
    ev_daset  : out std_logic;                       -- pulso: DA asignada
    ev_rstdaa : out std_logic;                       -- pulso
    in_frame  : out std_logic;

    -- pads (el target jamas conduce SCL)
    scl_i     : in  std_logic;
    sda_i     : in  std_logic;
    sda_o     : out std_logic;
    sda_t     : out std_logic                        -- '1' libera
  );
end entity i3c_target;

architecture rtl of i3c_target is

  type gt_t is (G_FREE, G_WAITF, G_HDR, G_PREACK, G_ACK, G_IBIA,
                G_CCC, G_CCCD, G_WD, G_SDAW,
                G_RD, G_RDT, G_RD0,
                G_DAAP, G_DAAA, G_DAAK, G_DAAK2);

  signal st : gt_t := G_FREE;

  -- siguiente estado tras el ACK propio
  signal nxt_r : gt_t := G_WAITF;

  -- sincronizadores y flancos
  signal scl_f1, scl_f2, scl_f3 : std_logic := '1';
  signal sda_f1, sda_f2, sda_f3 : std_logic := '1';

  -- header / datos
  signal sh     : std_logic_vector(7 downto 0) := (others => '0');
  signal bitc   : unsigned(3 downto 0) := (others => '0');
  signal curb   : std_logic_vector(7 downto 0) := (others => '0');
  signal txbit  : unsigned(3 downto 0) := (others => '0');
  signal tsel   : unsigned(2 downto 0) := (others => '0');
  -- tsel: 0 fifo, 1 pid, 2 bcr, 3 dcr, 4 status, 5 mwl, 6 mrl, 7 mdb
  signal idx    : unsigned(2 downto 0) := (others => '0');
  signal rlen   : unsigned(2 downto 0) := (others => '0');
  signal tdrv   : std_logic := '0';

  -- ENTDAA
  signal dk       : unsigned(6 downto 0) := (others => '0');
  signal lost_r   : std_logic := '0';
  signal daa_arm  : std_logic := '0';
  signal dan      : std_logic_vector(6 downto 0) := (others => '0');
  signal relneed  : std_logic := '0';

  -- CCC
  signal dirccc : std_logic_vector(7 downto 0) := x"FF";
  signal ccap   : unsigned(2 downto 0) := (others => '0');
  -- ccap: 0 ignorar, 1 enec, 2 disec, 3 mwl, 4 mrl
  signal ccnt   : unsigned(1 downto 0) := (others => '0');

  -- IBI / HJ
  signal arb_r    : std_logic := '0';
  signal selfarb  : std_logic := '0';
  signal hjmode   : std_logic := '0';
  signal myhdr    : std_logic_vector(7 downto 0) := (others => '0');
  signal ibip_r   : std_logic := '0';
  signal hjp_r    : std_logic := '0';

  -- registros de estado I3C
  signal da_r     : std_logic_vector(6 downto 0) := (others => '0');
  signal dav_r    : std_logic := '0';
  signal ibien_r  : std_logic := '1';                -- habilitados tras reset
  signal hjen_r   : std_logic := '1';
  signal mwl_r    : std_logic_vector(15 downto 0) := x"0100";
  signal mrl_r    : std_logic_vector(15 downto 0) := x"0100";

  -- salidas registradas
  signal sdao_r, sdat_r : std_logic := '1';
  signal txren_p, rxv_p, rxperr_p : std_logic := '0';
  signal ibid_p, ibin_p, hjd_p : std_logic := '0';
  signal evda_p, evrst_p : std_logic := '0';
  signal rxd_r : std_logic_vector(7 downto 0) := (others => '0');

  function pxor(v : std_logic_vector) return std_logic is
    variable x : std_logic := '0';
  begin
    for i in v'range loop
      x := x xor v(i);
    end loop;
    return x;
  end function;

begin

  tx_ren    <= txren_p;
  rx_data   <= rxd_r;
  rx_valid  <= rxv_p;
  rx_perr   <= rxperr_p;
  da        <= da_r;
  da_valid  <= dav_r;
  ibi_en    <= ibien_r;
  hj_en     <= hjen_r;
  mwl       <= mwl_r;
  mrl       <= mrl_r;
  ibi_pend  <= ibip_r;
  hj_pend   <= hjp_r;
  ibi_done  <= ibid_p;
  ibi_nakd  <= ibin_p;
  hj_done   <= hjd_p;
  ev_daset  <= evda_p;
  ev_rstdaa <= evrst_p;
  in_frame  <= '0' when st = G_FREE else '1';
  sda_o     <= sdao_r;
  sda_t     <= sdat_r;

  process(clk)
    variable scl_re, scl_fe : boolean;
    variable sta_ev, sto_ev : boolean;
    variable b    : std_logic;
    variable hdr  : std_logic_vector(7 downto 0);
    variable ackd : boolean;
    variable nx   : gt_t;
    variable pay  : std_logic_vector(63 downto 0);
    variable morev : std_logic;

    -- byte n del origen de lectura seleccionado (rango normalizado 7..0)
    impure function getb(sel : unsigned(2 downto 0);
                         i   : unsigned(2 downto 0))
      return std_logic_vector is
      variable ii : integer;
      variable r  : std_logic_vector(7 downto 0);
    begin
      ii := to_integer(i);
      case sel is
        when "000"  => r := tx_data;
        when "001"  =>
          if ii > 5 then ii := 5; end if;
          r := pid(47 - 8*ii downto 40 - 8*ii);
        when "010"  => r := bcr;
        when "011"  => r := dcr;
        when "100"  =>
          if ii = 0 then r := status_in(15 downto 8);
          else r := status_in(7 downto 0); end if;
        when "101"  =>
          if ii = 0 then r := mwl_r(15 downto 8);
          else r := mwl_r(7 downto 0); end if;
        when "110"  =>
          if ii = 0 then r := mrl_r(15 downto 8);
          else r := mrl_r(7 downto 0); end if;
        when others => r := mdb;
      end case;
      return r;
    end function;

  begin
    if rising_edge(clk) then
      scl_f1 <= scl_i;  scl_f2 <= scl_f1;  scl_f3 <= scl_f2;
      sda_f1 <= sda_i;  sda_f2 <= sda_f1;  sda_f3 <= sda_f2;

      txren_p <= '0';  rxv_p <= '0';  rxperr_p <= '0';
      ibid_p  <= '0';  ibin_p <= '0'; hjd_p <= '0';
      evda_p  <= '0';  evrst_p <= '0';

      pay := pid & bcr & dcr;

      if rst = '1' or en = '0' then
        st      <= G_FREE;
        sdat_r  <= '1';
        sdao_r  <= '1';
        dav_r   <= '0';
        daa_arm <= '0';
        dirccc  <= x"FF";
        ibip_r  <= '0';
        hjp_r   <= '0';
        arb_r   <= '0';
        selfarb <= '0';
        hjmode  <= '0';
        lost_r  <= '0';
        ibien_r <= '1';
        hjen_r  <= '1';
        mwl_r   <= x"0100";
        mrl_r   <= x"0100";
      else
        scl_re := (scl_f2 = '1') and (scl_f3 = '0');
        scl_fe := (scl_f2 = '0') and (scl_f3 = '1');
        sta_ev := (sda_f2 = '0') and (sda_f3 = '1') and (scl_f2 = '1');
        sto_ev := (sda_f2 = '1') and (sda_f3 = '0') and (scl_f2 = '1');

        -- peticiones de eventos
        if ibi_go = '1' then
          ibip_r <= '1';
        end if;
        if hj_go = '1' then
          hjp_r <= '1';
        end if;

        -- ------------------------------------------------------------
        -- START / STOP globales
        -- ------------------------------------------------------------
        if sto_ev then
          st      <= G_FREE;
          sdat_r  <= '1';
          dirccc  <= x"FF";
          arb_r   <= '0';
          selfarb <= '0';
          lost_r  <= '0';
          daa_arm <= '0';                            -- ENTDAA muere con la trama

        elsif sta_ev then
          if selfarb = '1' then
            -- START propio (IBI/HJ): mantener SDA bajo hasta el primer
            -- flanco de bajada de SCL
            arb_r   <= '1';
            selfarb <= '0';
          elsif st = G_FREE and
                ((ibip_r = '1' and ibien_r = '1' and dav_r = '1') or
                 (hjp_r = '1' and hjen_r = '1' and dav_r = '0')) then
            -- START ajeno con evento pendiente: arbitrar el header
            arb_r  <= '1';
            hjmode <= not dav_r;
            if dav_r = '1' then
              myhdr <= da_r & '1';
            else
              myhdr <= x"04";
            end if;
            sdat_r <= '1';
          else
            arb_r  <= '0';
            sdat_r <= '1';
          end if;
          st    <= G_HDR;
          bitc  <= (others => '0');
          sh    <= (others => '0');
          lost_r <= '0';

        else
          case st is

            -- --------------------------------------------------------
            when G_FREE =>
              -- lanzamiento de IBI/HJ desde bus libre
              if scl_f2 = '1' and sda_f2 = '1' and selfarb = '0' then
                if ibip_r = '1' and ibien_r = '1' and dav_r = '1' then
                  sdat_r  <= '0';
                  sdao_r  <= '0';
                  selfarb <= '1';
                  hjmode  <= '0';
                  myhdr   <= da_r & '1';
                elsif hjp_r = '1' and hjen_r = '1' and dav_r = '0' then
                  sdat_r  <= '0';
                  sdao_r  <= '0';
                  selfarb <= '1';
                  hjmode  <= '1';
                  myhdr   <= x"04";
                end if;
              end if;

            -- --------------------------------------------------------
            when G_HDR =>
              if scl_fe then
                if arb_r = '1' and lost_r = '0' then
                  if myhdr(7 - to_integer(bitc)) = '0' then
                    sdat_r <= '0';
                    sdao_r <= '0';
                  else
                    sdat_r <= '1';
                  end if;
                end if;
              elsif scl_re then
                b := sda_f2;
                if arb_r = '1' and lost_r = '0' and
                   myhdr(7 - to_integer(bitc)) = '1' and b = '0' then
                  lost_r <= '1';
                  sdat_r <= '1';
                end if;
                sh <= sh(6 downto 0) & b;
                if bitc = 7 then
                  hdr := sh(6 downto 0) & b;
                  bitc <= (others => '0');
                  if arb_r = '1' and lost_r = '0' and
                     not (myhdr(0) = '1' and b = '0') then
                    -- header propio ganado: el ACK lo conduce el controller
                    st <= G_IBIA;
                  else
                    arb_r <= '0';
                    ackd := false;
                    nx   := G_WAITF;
                    if hdr = x"FC" then
                      ackd := true;
                      nx   := G_CCC;
                    elsif hdr = x"FD" and daa_arm = '1' and dav_r = '0' then
                      ackd := true;
                      nx   := G_DAAP;
                      dk   <= (others => '0');
                    elsif dirccc = x"87" and dav_r = '0' and
                          hdr(7 downto 1) = sa and hdr(0) = '0' then
                      ackd := true;
                      nx   := G_SDAW;
                    elsif dav_r = '1' and hdr(7 downto 1) = da_r then
                      if hdr(0) = '0' then
                        case dirccc is
                          when x"FF" =>
                            ackd := true;  nx := G_WD;
                          when x"80" =>
                            ackd := true;  nx := G_CCCD;  ccap <= "001";
                            ccnt <= (others => '0');
                          when x"81" =>
                            ackd := true;  nx := G_CCCD;  ccap <= "010";
                            ccnt <= (others => '0');
                          when x"89" =>
                            ackd := true;  nx := G_CCCD;  ccap <= "011";
                            ccnt <= (others => '0');
                          when x"8A" =>
                            ackd := true;  nx := G_CCCD;  ccap <= "100";
                            ccnt <= (others => '0');
                          when others =>
                            ackd := false;
                        end case;
                      else
                        case dirccc is
                          when x"FF" =>
                            if tx_valid = '1' then
                              ackd := true;  nx := G_RD;
                              tsel <= "000";  rlen <= "000";
                            end if;
                          when x"8D" =>
                            ackd := true;  nx := G_RD;
                            tsel <= "001";  rlen <= to_unsigned(5, 3);
                          when x"8E" =>
                            ackd := true;  nx := G_RD;
                            tsel <= "010";  rlen <= "000";
                          when x"8F" =>
                            ackd := true;  nx := G_RD;
                            tsel <= "011";  rlen <= "000";
                          when x"90" =>
                            ackd := true;  nx := G_RD;
                            tsel <= "100";  rlen <= to_unsigned(1, 3);
                          when x"8B" =>
                            ackd := true;  nx := G_RD;
                            tsel <= "101";  rlen <= to_unsigned(1, 3);
                          when x"8C" =>
                            ackd := true;  nx := G_RD;
                            tsel <= "110";  rlen <= to_unsigned(1, 3);
                          when others =>
                            ackd := false;
                        end case;
                      end if;
                    end if;
                    if ackd then
                      st    <= G_PREACK;
                      nxt_r <= nx;
                    else
                      st <= G_WAITF;
                    end if;
                  end if;
                else
                  bitc <= bitc + 1;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_PREACK =>
              if scl_fe then
                sdat_r <= '0';
                sdao_r <= '0';                       -- ACK conducido bajo
                st <= G_ACK;
              end if;

            -- --------------------------------------------------------
            when G_ACK =>
              if scl_fe then
                case nxt_r is
                  when G_RD =>
                    curb  <= getb(tsel, "000");
                    idx   <= (others => '0');
                    if tsel = "000" then
                      txren_p <= '1';
                    end if;
                    sdat_r <= '0';
                    sdao_r <= getb(tsel, "000")(7);  -- primer bit ya
                    txbit  <= to_unsigned(1, 4);
                    st <= G_RD;
                  when G_DAAP =>
                    if pay(63) = '1' then
                      sdat_r <= '1';
                    else
                      sdat_r <= '0';
                      sdao_r <= '0';
                    end if;
                    dk <= (others => '0');
                    st <= G_DAAP;
                  when others =>
                    sdat_r <= '1';
                    bitc   <= (others => '0');
                    sh     <= (others => '0');
                    st <= nxt_r;
                end case;
              end if;

            -- --------------------------------------------------------
            when G_IBIA =>
              if scl_fe then
                sdat_r <= '1';                       -- ceder el bit de ACK
              elsif scl_re then
                b := sda_f2;
                if b = '0' then
                  if hjmode = '1' then
                    hjp_r <= '0';
                    hjd_p <= '1';
                    st <= G_WAITF;
                  else
                    curb  <= mdb;
                    tsel  <= "111";
                    rlen  <= "000";
                    idx   <= (others => '0');
                    nxt_r <= G_RD;
                    st    <= G_ACK;                  -- conduce el MDB en la bajada
                  end if;
                else
                  if hjmode = '1' then
                    hjp_r <= '0';
                  else
                    ibip_r <= '0';
                  end if;
                  ibin_p <= '1';
                  st <= G_WAITF;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_CCC =>
              if scl_re then
                if bitc < 8 then
                  sh   <= sh(6 downto 0) & sda_f2;
                  bitc <= bitc + 1;
                else
                  bitc <= (others => '0');
                  if sda_f2 /= (not pxor(sh)) then
                    rxperr_p <= '1';
                    st <= G_WAITF;
                  else
                    ccap <= "000";
                    ccnt <= (others => '0');
                    case sh is
                      when x"00" => ccap <= "001";              -- ENEC
                      when x"01" => ccap <= "010";              -- DISEC
                      when x"06" =>
                        dav_r   <= '0';                         -- RSTDAA
                        evrst_p <= '1';
                      when x"07" => daa_arm <= '1';             -- ENTDAA
                      when x"09" => ccap <= "011";              -- SETMWL bcast
                      when x"0A" => ccap <= "100";              -- SETMRL bcast
                      when others =>
                        if sh(7) = '1' then
                          dirccc <= sh;                         -- dirigido
                        end if;
                    end case;
                    sh <= (others => '0');
                    st <= G_CCCD;
                  end if;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_CCCD =>
              if scl_re then
                if bitc < 8 then
                  sh   <= sh(6 downto 0) & sda_f2;
                  bitc <= bitc + 1;
                else
                  bitc <= (others => '0');
                  if sda_f2 /= (not pxor(sh)) then
                    rxperr_p <= '1';
                    st <= G_WAITF;
                  else
                    case ccap is
                      when "001" =>                             -- ENEC
                        if sh(0) = '1' then ibien_r <= '1'; end if;
                        if sh(3) = '1' then hjen_r <= '1'; end if;
                      when "010" =>                             -- DISEC
                        if sh(0) = '1' then ibien_r <= '0'; end if;
                        if sh(3) = '1' then hjen_r <= '0'; end if;
                      when "011" =>                             -- SETMWL
                        if ccnt = 0 then
                          mwl_r(15 downto 8) <= sh;
                        elsif ccnt = 1 then
                          mwl_r(7 downto 0) <= sh;
                        end if;
                        ccnt <= ccnt + 1;
                      when "100" =>                             -- SETMRL
                        if ccnt = 0 then
                          mrl_r(15 downto 8) <= sh;
                        elsif ccnt = 1 then
                          mrl_r(7 downto 0) <= sh;
                        end if;
                        ccnt <= ccnt + 1;
                      when others =>
                        null;
                    end case;
                    sh <= (others => '0');
                  end if;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_WD =>
              if scl_re then
                if bitc < 8 then
                  sh   <= sh(6 downto 0) & sda_f2;
                  bitc <= bitc + 1;
                else
                  bitc <= (others => '0');
                  if sda_f2 /= (not pxor(sh)) then
                    rxperr_p <= '1';
                    st <= G_WAITF;
                  else
                    rxd_r <= sh;
                    rxv_p <= '1';
                  end if;
                  sh <= (others => '0');
                end if;
              end if;

            -- --------------------------------------------------------
            when G_SDAW =>
              if scl_re then
                if bitc < 8 then
                  sh   <= sh(6 downto 0) & sda_f2;
                  bitc <= bitc + 1;
                else
                  bitc <= (others => '0');
                  if sda_f2 /= (not pxor(sh)) then
                    rxperr_p <= '1';
                  else
                    da_r   <= sh(7 downto 1);
                    dav_r  <= '1';
                    evda_p <= '1';
                  end if;
                  st <= G_WAITF;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_RD =>
              if scl_fe then
                if txbit < 8 then
                  sdat_r <= '0';
                  sdao_r <= curb(7 - to_integer(txbit));
                  txbit  <= txbit + 1;
                elsif txbit = 8 then
                  if tsel = "000" then
                    morev := tx_valid;
                  elsif idx < rlen then
                    morev := '1';
                  else
                    morev := '0';
                  end if;
                  tdrv   <= morev;
                  sdat_r <= '0';
                  sdao_r <= morev;                   -- bit T
                  txbit  <= to_unsigned(9, 4);
                end if;
              elsif scl_re then
                if txbit = 9 then
                  txbit <= (others => '0');
                  if tdrv = '1' then
                    sdat_r <= '1';                   -- handoff del T al keeper
                    st <= G_RDT;
                  else
                    st <= G_RD0;
                  end if;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_RDT =>
              -- T=1 entregado; Sr/P los captura la logica global
              if scl_fe then
                idx  <= idx + 1;
                curb <= getb(tsel, idx + 1);
                if tsel = "000" then
                  txren_p <= '1';
                end if;
                sdat_r <= '0';
                sdao_r <= getb(tsel, idx + 1)(7);
                txbit  <= to_unsigned(1, 4);
                st <= G_RD;
              end if;

            -- --------------------------------------------------------
            when G_RD0 =>
              if scl_fe then
                sdat_r <= '1';
                if tsel = "111" then                 -- MDB de IBI entregado
                  ibip_r <= '0';
                  ibid_p <= '1';
                end if;
                st <= G_WAITF;
              end if;

            -- --------------------------------------------------------
            when G_DAAP =>
              if scl_fe then
                if dk < 64 then
                  if pay(63 - to_integer(dk)) = '1' then
                    sdat_r <= '1';
                  else
                    sdat_r <= '0';
                    sdao_r <= '0';
                  end if;
                end if;
              elsif scl_re then
                b := sda_f2;
                if pay(63 - to_integer(dk)) = '1' and b = '0' then
                  lost_r <= '1';
                  sdat_r <= '1';
                  st <= G_WAITF;                     -- retirada; reintento en Sr
                else
                  if dk = 63 then
                    bitc    <= (others => '0');
                    sh      <= (others => '0');
                    relneed <= '1';
                    st <= G_DAAA;
                  else
                    dk <= dk + 1;
                  end if;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_DAAA =>
              if scl_fe then
                if relneed = '1' then
                  sdat_r  <= '1';                    -- ceder SDA al controller
                  relneed <= '0';
                end if;
              elsif scl_re then
                sh   <= sh(6 downto 0) & sda_f2;
                if bitc = 7 then
                  bitc <= (others => '0');
                  hdr := sh(6 downto 0) & sda_f2;
                  if hdr(0) = (not pxor(hdr(7 downto 1))) then
                    dan <= hdr(7 downto 1);
                    st  <= G_DAAK;
                  else
                    rxperr_p <= '1';
                    st <= G_WAITF;                   -- sin ACK: sigue sin DA
                  end if;
                else
                  bitc <= bitc + 1;
                end if;
              end if;

            -- --------------------------------------------------------
            when G_DAAK =>
              if scl_fe then
                sdat_r <= '0';
                sdao_r <= '0';                       -- ACK de la DA
                st <= G_DAAK2;
              end if;

            when G_DAAK2 =>
              if scl_fe then
                sdat_r <= '1';
                da_r   <= dan;
                dav_r  <= '1';
                evda_p <= '1';
                st <= G_WAITF;
              end if;

            -- --------------------------------------------------------
            when G_WAITF =>
              null;

          end case;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
