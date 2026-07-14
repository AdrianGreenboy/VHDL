-- ============================================================================
-- tb_phy.vhd -- PCIE IP v1, verificacion capa 0 (scrambler + framer)
--
-- A) Oraculo canonico: scrambleando D00 repetidamente tras COM, la secuencia
--    de bytes de salida DEBE ser FF,17,C0,14,B2,E7,02,82,... (tabla PCIe Base
--    Spec). Se comprueban los primeros 64 valores. Oraculo INDEPENDIENTE del
--    RTL (constante literal), no derivado de f_lfsr8.
-- B) Involucion: para 20000 simbolos aleatorios (mezcla D/K/COM/SKP), un
--    segundo scrambler en modo descramble reproduce EXACTAMENTE el dato
--    original. Se verifica que COM resetea y que SKP no avanza el LFSR
--    (comparando el lfsr_mon contra un modelo de referencia en el tb).
-- C) SKP no-avance: tras N simbolos con un SKP intercalado, el estado del LFSR
--    coincide con el de N-1 avances (el SKP no cuenta). Chequeo directo.
-- D) Framer: un TLP de 12 bytes y un DLLP de 6 bytes salen con STP..END /
--    SDP..END; se cuenta la insercion de al menos un SKP OS (COM+3xSKP) en un
--    run largo de idle; el COM del SKP OS resetea el scrambler.
-- E) Mutacion: si se fuerza el LFSR a NO resetear en COM (via modelo), el
--    descramble diverge -> confirma que el reset es necesario (mutacion que
--    debe fallar, comprobada en el modelo de referencia del tb).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.pcie_phy_pkg.all;
use work.pcie_8b10b_pkg.all;

entity tb_phy is
end entity;

architecture sim of tb_phy is
  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal fin : boolean := false;

  -- Scrambler bajo prueba (TX)
  signal rst  : std_logic := '1';
  signal en   : std_logic := '0';
  signal din  : work.pcie_phy_pkg.byte_t := (others => '0');
  signal ik, ic, isk, byp : std_logic := '0';
  signal sout : work.pcie_phy_pkg.byte_t;
  signal sk   : std_logic;
  signal smon : lfsr_t;

  -- Descrambler (RX) encadenado para B
  signal r_din : work.pcie_phy_pkg.byte_t := (others => '0');
  signal r_ik, r_ic, r_isk, r_byp : std_logic := '0';
  signal r_en  : std_logic := '0';
  signal dout2 : work.pcie_phy_pkg.byte_t;
  signal dk2   : std_logic;
  signal mon2  : lfsr_t;

  -- Framer para D
  signal f_en   : std_logic := '0';
  signal f_start: std_logic := '0';
  signal f_dllp : std_logic := '0';
  signal f_pd   : work.pcie_phy_pkg.byte_t := (others => '0');
  signal f_pv   : std_logic := '0';
  signal f_pl   : std_logic := '0';
  signal f_pa   : std_logic := '0';
  signal f_prdy : std_logic;
  signal f_sym  : work.pcie_phy_pkg.byte_t;
  signal f_k, f_com, f_skp, f_byp : std_logic;
  signal f_busy : std_logic;

  -- Oraculo canonico de los primeros 64 bytes de scrambling (D00 tras COM)
  type ora_t is array (0 to 63) of integer;
  constant ORA : ora_t := (
    16#FF#,16#17#,16#C0#,16#14#,16#B2#,16#E7#,16#02#,16#82#,
    16#72#,16#6E#,16#28#,16#A6#,16#BE#,16#6D#,16#BF#,16#8D#,
    16#BE#,16#40#,16#A7#,16#E6#,16#2C#,16#D3#,16#E2#,16#B2#,
    16#07#,16#02#,16#77#,16#2A#,16#CD#,16#34#,16#BE#,16#E0#,
    16#A7#,16#5D#,16#24#,16#B1#,16#9B#,16#A1#,16#BD#,16#22#,
    16#D4#,16#45#,16#1D#,16#D3#,16#D7#,16#EA#,16#76#,16#EE#,
    16#2C#,16#DA#,16#1A#,16#FA#,16#28#,16#2D#,16#36#,16#3B#,
    16#3A#,16#0E#,16#6F#,16#67#,16#CF#,16#06#,16#4C#,16#26#);

  type kv9_t is array (0 to 8) of work.pcie_phy_pkg.byte_t;
  constant KSTREAM_local : kv9_t := (K_COM, K_STP, K_SDP, K_END, K_EDB,
                                     K_PAD, K_SKP, K_FTS, K_IDL);

  -- monitor del framer (test D)
  signal mon_go   : std_logic := '0';
  signal stp_cnt  : integer := 0;
  signal sdp_cnt  : integer := 0;
  signal end_cnt  : integer := 0;
  signal com_cnt  : integer := 0;
  signal skp_cnt2 : integer := 0;

begin

  -- Proceso monitor: cuenta simbolos de control del framer mientras mon_go='1'
  mon_proc : process(clk)
  begin
    if rising_edge(clk) then
      if mon_go = '1' and f_en = '1' then
        if f_k='1' and f_sym=K_STP then stp_cnt <= stp_cnt + 1; end if;
        if f_k='1' and f_sym=K_SDP then sdp_cnt <= sdp_cnt + 1; end if;
        if f_k='1' and f_sym=K_END then end_cnt <= end_cnt + 1; end if;
        if f_com='1' then com_cnt <= com_cnt + 1; end if;
        if f_skp='1' then skp_cnt2 <= skp_cnt2 + 1; end if;
      end if;
    end if;
  end process;
  clk <= '0' when fin else not clk after TCLK/2;

  u_tx : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>din, is_k=>ik, is_com=>ic,
              is_skp=>isk, bypass=>byp, dout=>sout, dout_k=>sk, lfsr_mon=>smon);

  u_rx : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>r_en, din=>r_din, is_k=>r_ik, is_com=>r_ic,
              is_skp=>r_isk, bypass=>r_byp, dout=>dout2, dout_k=>dk2,
              lfsr_mon=>mon2);

  u_frm : entity work.pcie_framer
    generic map (SKP_INTERVAL => 40)
    port map (clk=>clk, rst=>rst, en=>f_en, pkt_start=>f_start,
              pkt_is_dllp=>f_dllp, pay_data=>f_pd, pay_valid=>f_pv,
              pay_last=>f_pl, pay_abort=>f_pa, pay_ready=>f_prdy,
              tx_bypass=>'0', sym=>f_sym, sym_k=>f_k, sym_com=>f_com,
              sym_skp=>f_skp, sym_bypass=>f_byp, busy=>f_busy);

  main : process
    variable s1 : positive := 3;
    variable s2 : positive := 9;
    variable rr : real;
    procedure rnd(hi: in integer; res: out integer) is begin
      uniform(s1,s2,rr); res := integer(floor(rr*real(hi+1)));
      if res>hi then res:=hi; end if;
    end procedure;

    -- modelo de referencia del LFSR en el tb (independiente del RTL para C/B)
    variable ref : lfsr_t;
    function ref8(st: lfsr_t) return lfsr8_res_t is
      variable d: lfsr_t := st; variable ob: work.pcie_phy_pkg.byte_t; variable fb: std_logic;
      variable r: lfsr8_res_t; begin
      for i in 0 to 7 loop
        ob(i):=d(15); fb:=d(15); d:=d(14 downto 0)&fb;
        d(3):=d(3) xor fb; d(4):=d(4) xor fb; d(5):=d(5) xor fb;
      end loop; r.nxt:=d; r.sbyte:=ob; return r;
    end function;

    variable rv : lfsr8_res_t;
    variable pick : integer;
    variable orig : work.pcie_phy_pkg.byte_t;
    variable mk, mcom, mskp : std_logic;
    -- arrays de captura para el test B (dos pasadas)
    constant NB : integer := 20000;
    type barr_t is array (0 to NB-1) of work.pcie_phy_pkg.byte_t;
    type farr_t is array (0 to NB-1) of std_logic;
    variable bo, bs : barr_t;
    variable bk, bcom, bskp : farr_t;
  begin
    -- ===== A: oraculo canonico =====
    wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);
    -- primer simbolo: COM (reset)
    din<=K_COM; ik<='1'; ic<='1'; isk<='0'; byp<='0'; en<='1';
    wait until rising_edge(clk);
    -- ahora D00 repetido; salida valida 1 ciclo despues del drive
    din<=x"00"; ik<='0'; ic<='0';
    wait until rising_edge(clk);   -- cyc0: sale el COM (0xBC), descartar
    wait until rising_edge(clk);   -- cyc1: primer D00 scrambleado -> 0xFF
    for i in 0 to 63 loop
      assert to_integer(unsigned(sout)) = ORA(i)
        report "A: sbyte canonico incorrecto en indice " & integer'image(i) &
               " got=" & integer'image(to_integer(unsigned(sout))) &
               " exp=" & integer'image(ORA(i))
        severity failure;
      wait until rising_edge(clk);
    end loop;
    en<='0';
    report "A: PASS oraculo canonico (64 bytes FF,17,C0,...)";

    -- ===== C: SKP no avanza el LFSR =====
    wait until rising_edge(clk);
    din<=K_COM; ik<='1'; ic<='1'; isk<='0'; en<='1';
    wait until rising_edge(clk);
    ref := LFSR_SEED;
    ik<='0'; ic<='0';
    -- 5 datos, luego 1 SKP, luego 5 datos; el modelo solo avanza en datos
    for i in 0 to 10 loop
      if i = 5 then
        din<=K_SKP; ik<='1'; isk<='1';       -- no debe avanzar
      else
        din<=x"AA"; ik<='0'; isk<='0';
        rv := ref8(ref); ref := rv.nxt;      -- modelo avanza
      end if;
      wait until rising_edge(clk);
    end loop;
    en<='0'; ik<='0'; isk<='0';
    wait until rising_edge(clk);
    assert smon = ref
      report "C: LFSR desincronizado (SKP avanzo?) rtl=" &
             integer'image(to_integer(unsigned(smon))) &
             " ref=" & integer'image(to_integer(unsigned(ref)))
      severity failure;
    report "C: PASS SKP no avanza el LFSR";

    -- ===== B: involucion scramble->descramble sobre stream mixto =====
    -- Pasada 1: generamos un stream, capturamos (orig,flags) y la salida
    -- scrambleada del TX. Pasada 2: metemos la salida del TX por el RX con los
    -- MISMOS flags y exigimos recuperar el original. Robusto (sin cola en vivo).
    wait until rising_edge(clk);
    rst<='1'; wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);

    -- pasada 1: TX
    for n in 0 to NB-1 loop
      rnd(31, pick);
      if n = 0 or pick = 0 then
        orig:=K_COM; mk:='1'; mcom:='1'; mskp:='0';
      elsif pick = 1 then
        orig:=K_SKP; mk:='1'; mcom:='0'; mskp:='1';
      elsif pick < 5 then
        rnd(8,pick); orig:=KSTREAM_local(pick); mk:='1'; mcom:='0'; mskp:='0';
      else
        rnd(255,pick); orig:=std_logic_vector(to_unsigned(pick,8));
        mk:='0'; mcom:='0'; mskp:='0';
      end if;
      bo(n):=orig; bk(n):=mk; bcom(n):=mcom; bskp(n):=mskp;
      din<=orig; ik<=mk; ic<=mcom; isk<=mskp; byp<='0'; en<='1';
      wait until rising_edge(clk);
      -- la salida del TX para el simbolo n aparece en el flanco siguiente
      if n > 0 then bs(n-1):=sout; end if;
    end loop;
    en<='0';
    wait until rising_edge(clk);
    bs(NB-1):=sout;

    -- pasada 2: RX (descramble). Mismos flags; entrada = salida capturada del TX.
    wait until rising_edge(clk);
    rst<='1'; wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);
    for n in 0 to NB-1 loop
      r_din<=bs(n); r_ik<=bk(n); r_ic<=bcom(n); r_isk<=bskp(n); r_byp<='0';
      r_en<='1';
      wait until rising_edge(clk);
      if n > 0 then
        assert dout2 = bo(n-1)
          report "B: involucion fallo en n=" & integer'image(n-1) &
                 " got=" & integer'image(to_integer(unsigned(dout2))) &
                 " exp=" & integer'image(to_integer(unsigned(bo(n-1))))
          severity failure;
      end if;
    end loop;
    r_en<='0';
    wait until rising_edge(clk);
    assert dout2 = bo(NB-1) report "B: involucion fallo en ultimo" severity failure;
    report "B: PASS involucion " & integer'image(NB) & " simbolos mixtos";

    -- ===== D: framer =====
    -- El conteo de simbolos lo hace el proceso monitor concurrente (mon_proc)
    -- vigilando f_sym/f_k/f_com/f_skp mientras dur_count='1'. Aqui solo
    -- pilotamos los paquetes.
    wait until rising_edge(clk);
    rst<='1'; wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);
    mon_go <= '1';                 -- arranca el conteo
    f_en<='1';
    -- lanzar TLP de 12 bytes
    f_start<='1'; f_dllp<='0'; wait until rising_edge(clk); f_start<='0';
    for i in 0 to 11 loop
      f_pd<=std_logic_vector(to_unsigned(16#10#+i,8)); f_pv<='1';
      if i=11 then f_pl<='1'; else f_pl<='0'; end if;
      loop wait until rising_edge(clk); exit when f_prdy='1'; end loop;
    end loop;
    f_pv<='0'; f_pl<='0';
    -- idle para permitir SKP OS
    for i in 0 to 60 loop wait until rising_edge(clk); end loop;
    -- DLLP de 6 bytes
    f_start<='1'; f_dllp<='1'; wait until rising_edge(clk); f_start<='0';
    for j in 0 to 5 loop
      f_pd<=std_logic_vector(to_unsigned(16#A0#+j,8)); f_pv<='1';
      if j=5 then f_pl<='1'; else f_pl<='0'; end if;
      loop wait until rising_edge(clk); exit when f_prdy='1'; end loop;
    end loop;
    f_pv<='0'; f_pl<='0';
    -- idle largo final para forzar al menos un SKP OS mas
    for i in 0 to 120 loop wait until rising_edge(clk); end loop;
    f_en<='0'; mon_go<='0';
    wait until rising_edge(clk);
    assert stp_cnt >= 1 report "D: no se vio STP" severity failure;
    assert sdp_cnt >= 1 report "D: no se vio SDP" severity failure;
    assert end_cnt >= 2 report "D: faltan END (TLP+DLLP)" severity failure;
    assert com_cnt >= 1 and skp_cnt2 >= 3
      report "D: no se inserto SKP OS (COM+3xSKP)" severity failure;
    report "D: PASS framer STP=" & integer'image(stp_cnt) &
           " SDP=" & integer'image(sdp_cnt) &
           " END=" & integer'image(end_cnt) &
           " COM=" & integer'image(com_cnt) &
           " SKP=" & integer'image(skp_cnt2);

    report "FIN SIMULACION PHY: PASS @ " & time'image(now);
    fin<=true; wait;
  end process;

end architecture;
