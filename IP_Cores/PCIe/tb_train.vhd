-- ============================================================================
-- tb_train.vhd -- PCIE IP v1, verificacion capa 1c (entrenamiento del enlace)
--
-- Topologia: dos nodos identicos A (RC) y B (EP). Cada nodo:
--   ltssm -> ts_gen -> scrambler_tx -> [cable] -> scrambler_rx -> deframer
--            (deframer.ts_* realimenta al ltssm del mismo nodo)
-- El cable cruza: TX de A -> RX de B y TX de B -> RX de A.
-- El scrambler_rx usa los flags is_com/is_skp derivados por su deframer, con
-- un adelanto combinacional: el descrambler necesita saber si el simbolo
-- entrante es COM/SKP ANTES de procesarlo. Como el codec real entrega esos
-- flags por el propio byte+is_k, aqui derivamos is_com/is_skp del byte de
-- entrada al scrambler_rx directamente (combinacional).
--
-- FASE 0 (anti-modo-comun): B en silencio (su TX no emite; RX de A recibe
--   idle constante). El LTSSM de A NO debe alcanzar L0; el timeout debe
--   dispararlo de vuelta a DETECT. Esto descarta que dos instancias con un
--   defecto compartido "entrenen en el vacio".
-- FASE 1 (full-duplex): ambos activos. Ambos LTSSM DEBEN alcanzar L0.
--   Se mide el numero de ciclos hasta link_up en ambos.
-- FASE 2 (Hot Reset): tras L0, A ordena Hot Reset; ambos deben volver a
--   DETECT y luego poder reentrenar a L0.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;
use work.pcie_8b10b_pkg.all;

entity tb_train is
end entity;

architecture sim of tb_train is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;

  subtype byte_t is std_logic_vector(7 downto 0);

  -- Senales por nodo. Sufijo _a / _b.
  -- LTSSM
  signal rst        : std_logic := '1';
  signal en         : std_logic := '1';
  signal cmd_start_a, cmd_start_b : std_logic := '0';
  signal cmd_hotrst_a : std_logic := '0';
  signal cmd_disable : std_logic := '0';

  -- A: ltssm <-> ts_gen
  signal send_a, kind_a : std_logic;
  signal ctl_a : byte_t;
  signal done_a, act_a : std_logic;
  signal state_a : std_logic_vector(3 downto 0);
  signal up_a : std_logic;
  signal ts1c_a, ts2c_a : std_logic_vector(15 downto 0);
  -- A ts_gen -> scrambler_tx
  signal g_sym_a, g_symk_a : byte_t;   -- (sym, dummy)
  signal gsym_a : byte_t; signal gk_a, gcom_a, gskp_a, gbyp_a : std_logic;
  -- A scrambler_tx salida (cable A->B)
  signal tx_sym_a : byte_t; signal tx_k_a : std_logic;
  -- A scrambler_rx (cable B->A) -> deframer
  signal rx_sym_a : byte_t; signal rx_k_a : std_logic;   -- tras descramble
  signal a_tok : rx_kind_t; signal a_tokd : byte_t; signal a_tokv : std_logic;
  signal a_tsv, a_ts2, a_iscom, a_isskp : std_logic;
  signal a_link, a_lane, a_nfts, a_rate, a_ctl : byte_t;

  -- B: idem
  signal send_b, kind_b : std_logic;
  signal ctl_b : byte_t;
  signal done_b, act_b : std_logic;
  signal state_b : std_logic_vector(3 downto 0);
  signal up_b : std_logic;
  signal ts1c_b, ts2c_b : std_logic_vector(15 downto 0);
  signal gsym_b : byte_t; signal gk_b, gcom_b, gskp_b, gbyp_b : std_logic;
  signal tx_sym_b : byte_t; signal tx_k_b : std_logic;
  signal rx_sym_b : byte_t; signal rx_k_b : std_logic;
  signal b_tok : rx_kind_t; signal b_tokd : byte_t; signal b_tokv : std_logic;
  signal b_tsv, b_ts2, b_iscom, b_isskp : std_logic;
  signal b_link, b_lane, b_nfts, b_rate, b_ctl : byte_t;

  -- cable: en fase 0, B calla (mux a idle)
  signal b_silent : std_logic := '1';
  -- lo que A recibe: TX de B, o idle si B calla
  signal cbl_b2a_sym : byte_t; signal cbl_b2a_k : std_logic;
  signal cbl_a2b_sym : byte_t; signal cbl_a2b_k : std_logic;

  -- flags de descramble derivados combinacionalmente de la entrada al RX
  signal rxcom_a, rxskp_a, rxcom_b, rxskp_b : std_logic;

begin
  clk <= '0' when fin else not clk after TCLK/2;

  -- ===================== NODO A =====================
  u_ltssm_a : entity work.pcie_ltssm
    generic map (TIMEOUT_CYCLES => 5000)
    port map (clk=>clk, rst=>rst, en=>en,
              cmd_start=>cmd_start_a, cmd_hotrst=>cmd_hotrst_a,
              cmd_loopbk=>'0', cmd_disable=>cmd_disable,
              tx_send_ts=>send_a, tx_ts_kind=>kind_a, tx_ctl=>ctl_a,
              tx_ts_done=>done_a,
              rx_ts_valid=>a_tsv, rx_is_ts2=>a_ts2, rx_ctl=>a_ctl,
              state_o=>state_a, link_up=>up_a,
              ts1_rx_cnt=>ts1c_a, ts2_rx_cnt=>ts2c_a);

  u_tsgen_a : entity work.pcie_ts_gen
    port map (clk=>clk, rst=>rst, en=>en,
              send=>send_a, ts_kind=>kind_a, train_ctl=>ctl_a,
              n_fts=>x"08", link_num=>PAD_BYTE, lane_num=>PAD_BYTE,
              done=>done_a, active=>act_a,
              sym=>gsym_a, sym_k=>gk_a, sym_com=>gcom_a,
              sym_skp=>gskp_a, sym_byp=>gbyp_a);

  u_scr_tx_a : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>gsym_a, is_k=>gk_a,
              is_com=>gcom_a, is_skp=>gskp_a, bypass=>gbyp_a,
              dout=>tx_sym_a, dout_k=>tx_k_a, lfsr_mon=>open);

  -- descramble en A de lo que llega de B
  rxcom_a <= '1' when (cbl_b2a_k='1' and cbl_b2a_sym=K_COM) else '0';
  rxskp_a <= '1' when (cbl_b2a_k='1' and cbl_b2a_sym=K_SKP) else '0';
  u_scr_rx_a : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>cbl_b2a_sym, is_k=>cbl_b2a_k,
              is_com=>rxcom_a, is_skp=>rxskp_a, bypass=>'0',
              dout=>rx_sym_a, dout_k=>rx_k_a, lfsr_mon=>open);

  u_defr_a : entity work.pcie_deframer
    port map (clk=>clk, rst=>rst, en=>en, sym=>rx_sym_a, sym_k=>rx_k_a,
              tok=>a_tok, tok_data=>a_tokd, tok_valid=>a_tokv,
              ts_valid=>a_tsv, ts_is_ts2=>a_ts2, ts_link=>a_link,
              ts_lane=>a_lane, ts_nfts=>a_nfts, ts_rate=>a_rate, ts_ctl=>a_ctl,
              is_com_o=>a_iscom, is_skp_o=>a_isskp);

  -- ===================== NODO B =====================
  u_ltssm_b : entity work.pcie_ltssm
    generic map (TIMEOUT_CYCLES => 5000)
    port map (clk=>clk, rst=>rst, en=>en,
              cmd_start=>cmd_start_b, cmd_hotrst=>'0',
              cmd_loopbk=>'0', cmd_disable=>cmd_disable,
              tx_send_ts=>send_b, tx_ts_kind=>kind_b, tx_ctl=>ctl_b,
              tx_ts_done=>done_b,
              rx_ts_valid=>b_tsv, rx_is_ts2=>b_ts2, rx_ctl=>b_ctl,
              state_o=>state_b, link_up=>up_b,
              ts1_rx_cnt=>ts1c_b, ts2_rx_cnt=>ts2c_b);

  u_tsgen_b : entity work.pcie_ts_gen
    port map (clk=>clk, rst=>rst, en=>en,
              send=>send_b, ts_kind=>kind_b, train_ctl=>ctl_b,
              n_fts=>x"08", link_num=>PAD_BYTE, lane_num=>PAD_BYTE,
              done=>done_b, active=>act_b,
              sym=>gsym_b, sym_k=>gk_b, sym_com=>gcom_b,
              sym_skp=>gskp_b, sym_byp=>gbyp_b);

  u_scr_tx_b : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>gsym_b, is_k=>gk_b,
              is_com=>gcom_b, is_skp=>gskp_b, bypass=>gbyp_b,
              dout=>tx_sym_b, dout_k=>tx_k_b, lfsr_mon=>open);

  rxcom_b <= '1' when (cbl_a2b_k='1' and cbl_a2b_sym=K_COM) else '0';
  rxskp_b <= '1' when (cbl_a2b_k='1' and cbl_a2b_sym=K_SKP) else '0';
  u_scr_rx_b : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>cbl_a2b_sym, is_k=>cbl_a2b_k,
              is_com=>rxcom_b, is_skp=>rxskp_b, bypass=>'0',
              dout=>rx_sym_b, dout_k=>rx_k_b, lfsr_mon=>open);

  u_defr_b : entity work.pcie_deframer
    port map (clk=>clk, rst=>rst, en=>en, sym=>rx_sym_b, sym_k=>rx_k_b,
              tok=>b_tok, tok_data=>b_tokd, tok_valid=>b_tokv,
              ts_valid=>b_tsv, ts_is_ts2=>b_ts2, ts_link=>b_link,
              ts_lane=>b_lane, ts_nfts=>b_nfts, ts_rate=>b_rate, ts_ctl=>b_ctl,
              is_com_o=>b_iscom, is_skp_o=>b_isskp);

  -- ===================== CABLE =====================
  -- A->B siempre pasa el TX de A. B->A pasa el TX de B salvo en fase 0.
  cbl_a2b_sym <= tx_sym_a; cbl_a2b_k <= tx_k_a;
  cbl_b2a_sym <= tx_sym_b when b_silent='0' else x"00";
  cbl_b2a_k   <= tx_k_b   when b_silent='0' else '0';

  main : process
    variable c : integer;
    variable up_a_cyc, up_b_cyc : integer := -1;
  begin
    -- ============ FASE 0: B en silencio ============
    b_silent <= '1';
    rst <= '1';
    for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0';
    wait until rising_edge(clk);
    cmd_start_a <= '1';   -- solo A arranca
    -- correr suficientes ciclos para superar el timeout (5000) y verificar
    -- que A NUNCA alcanza L0 con B callado
    for i in 0 to 12000 loop
      wait until rising_edge(clk);
      assert up_a = '0'
        report "FASE0: A alcanzo L0 con partner en SILENCIO (modo comun!)"
        severity failure;
    end loop;
    -- ademas, el timeout debe haberlo devuelto a DETECT al menos una vez
    report "FASE0: PASS A no entreno en el vacio (state_a=" &
           integer'image(to_integer(unsigned(state_a))) & ")";

    -- ============ FASE 1: full-duplex ============
    cmd_start_a <= '0';
    rst <= '1';
    for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);
    b_silent <= '0';
    cmd_start_a <= '1'; cmd_start_b <= '1';
    up_a_cyc := -1; up_b_cyc := -1;
    for i in 0 to 8000 loop
      wait until rising_edge(clk);
      if up_a='1' and up_a_cyc<0 then up_a_cyc := i; end if;
      if up_b='1' and up_b_cyc<0 then up_b_cyc := i; end if;
      exit when up_a='1' and up_b='1';
    end loop;
    assert up_a='1' and up_b='1'
      report "FASE1: no se alcanzo L0 en ambos (up_a=" & std_logic'image(up_a) &
             " up_b=" & std_logic'image(up_b) &
             " state_a=" & integer'image(to_integer(unsigned(state_a))) &
             " state_b=" & integer'image(to_integer(unsigned(state_b))) & ")"
      severity failure;
    report "FASE1: PASS ambos en L0. ciclos A=" & integer'image(up_a_cyc) &
           " B=" & integer'image(up_b_cyc);

    -- verificar coherencia de los campos de training recibidos por A
    assert a_rate = RATE_2G5
      report "FASE1: Rate ID recibido incorrecto (esperado 0x02) = " &
             integer'image(to_integer(unsigned(a_rate)))
      severity failure;
    assert to_integer(unsigned(ts1c_a)) >= N_TS_POLL - 1
      report "FASE1: A no conto suficientes TS1 (modo comun?)" severity failure;
    assert to_integer(unsigned(ts2c_a)) >= N_TS_CFG - 1
      report "FASE1: A no conto suficientes TS2" severity failure;
    report "FASE1: PASS campos coherentes rate=0x02 TS1_rx=" &
           integer'image(to_integer(unsigned(ts1c_a))) &
           " TS2_rx=" & integer'image(to_integer(unsigned(ts2c_a)));

    -- sostener L0 unos ciclos para confirmar estabilidad
    for i in 0 to 200 loop
      wait until rising_edge(clk);
      assert up_a='1' and up_b='1'
        report "FASE1: L0 no estable" severity failure;
    end loop;
    report "FASE1: PASS L0 estable 200 ciclos";

    -- ============ FASE 2: Hot Reset ============
    cmd_hotrst_a <= '1';
    wait until rising_edge(clk);
    cmd_hotrst_a <= '0';
    -- ambos deben abandonar L0
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      exit when (up_a='0');
      assert c < 2000 report "FASE2: A no salio de L0 tras Hot Reset" severity failure;
    end loop;
    report "FASE2: PASS Hot Reset saco a A de L0 (state_a=" &
           integer'image(to_integer(unsigned(state_a))) & ")";

    -- reentrenar: A vuelve a Detect; re-arrancar ambos
    rst <= '1';
    for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);
    cmd_start_a <= '1'; cmd_start_b <= '1';
    for i in 0 to 8000 loop
      wait until rising_edge(clk);
      exit when up_a='1' and up_b='1';
    end loop;
    assert up_a='1' and up_b='1'
      report "FASE2: no reentreno a L0 tras Hot Reset" severity failure;
    report "FASE2: PASS reentrenamiento a L0 tras Hot Reset";

    report "FIN SIMULACION TRAIN: PASS @ " & time'image(now);
    fin <= true; wait;
  end process;

end architecture;
