-- tb_ptp_pdelay_fsm.vhd — capa 1a del orquestador peer-delay.
-- Simula el parser RX (inyecta mensajes) y el motor TX (busy/done/ts) con
-- estimulos deterministas, y verifica:
--   INICIADOR: start -> Req (t1 capturado) -> Resp entrante (t4,corr) -> pd_calc
--   RESPONDEDOR: Req entrante (t2,rpid) -> Resp saliente
-- Asserts en espanol, severity failure.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_ptp_pdelay_fsm is
end entity;

architecture sim of tb_ptp_pdelay_fsm is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal start, busy : std_logic := '0';
  signal rx_mvalid : std_logic := '0';
  signal rx_mtype : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_seqid : std_logic_vector(15 downto 0) := (others => '0');
  signal rx_spid : std_logic_vector(79 downto 0) := (others => '0');
  signal rx_corr : std_logic_vector(63 downto 0) := (others => '0');
  signal rx_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal rx_ns : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal rx_ack : std_logic;

  signal tx_send : std_logic;
  signal tx_sel : msg_sel_t;
  signal tx_req_rx_sec : std_logic_vector(SEC_W-1 downto 0);
  signal tx_req_rx_ns : std_logic_vector(NS_W-1 downto 0);
  signal tx_req_portid : std_logic_vector(79 downto 0);
  signal tx_busy : std_logic := '0';
  signal tx_done : std_logic := '0';
  signal tx_ts_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal tx_ts_ns : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal tx_ts_valid : std_logic := '0';

  signal pd_calc : std_logic;
  signal pd_t1_sec, pd_t4_sec : std_logic_vector(SEC_W-1 downto 0);
  signal pd_t1_ns, pd_t4_ns : std_logic_vector(NS_W-1 downto 0);
  signal pd_corr : std_logic_vector(63 downto 0);
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_pdelay_fsm
    port map (clk => clk, rst => rst, start => start, busy => busy,
      rx_mvalid => rx_mvalid, rx_mtype => rx_mtype, rx_seqid => rx_seqid,
      rx_spid => rx_spid, rx_corr => rx_corr, rx_sec => rx_sec, rx_ns => rx_ns,
      rx_ack => rx_ack,
      tx_send => tx_send, tx_sel => tx_sel, tx_req_rx_sec => tx_req_rx_sec,
      tx_req_rx_ns => tx_req_rx_ns, tx_req_portid => tx_req_portid,
      tx_busy => tx_busy, tx_done => tx_done,
      tx_ts_sec => tx_ts_sec, tx_ts_ns => tx_ts_ns, tx_ts_valid => tx_ts_valid,
      pd_calc => pd_calc, pd_t1_sec => pd_t1_sec, pd_t1_ns => pd_t1_ns,
      pd_t4_sec => pd_t4_sec, pd_t4_ns => pd_t4_ns, pd_corr => pd_corr);

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;

    -- simula el motor: al ver tx_send, sube busy, luego pulsa ts_valid (SFD),
    -- luego done. tx_ts_* = timestamp del SFD de esa trama.
    procedure motor_run(ts_s : integer; ts_n : integer) is
    begin
      tx_busy <= '1'; step;
      tx_ts_sec <= std_logic_vector(to_unsigned(ts_s, SEC_W));
      tx_ts_ns  <= std_logic_vector(to_unsigned(ts_n, NS_W));
      tx_ts_valid <= '1'; step; tx_ts_valid <= '0';
      for i in 1 to 5 loop step; end loop;
      tx_done <= '1'; step; tx_done <= '0';
      tx_busy <= '0'; step;
    end procedure;

  begin
    rst <= '1'; step; step; rst <= '0';

    -- ============ CASO INICIADOR ============
    -- start -> el orquestador dispara Req
    start <= '1'; step; start <= '0';
    -- esperar a que dispare el Req
    for i in 1 to 10 loop
      step; exit when tx_send = '1' and tx_sel = SEL_PDELAY_REQ;
    end loop;
    assert tx_sel = SEL_PDELAY_REQ report "FALLO: no disparo Pdelay_Req" severity failure;
    report "OK iniciador disparo Pdelay_Req";
    -- simular el motor enviando el Req; t1 = SFD TX = (1, 1000)
    motor_run(1, 1000);
    -- ahora el iniciador espera el Resp. Inyectar un Pdelay_Resp entrante.
    -- t4 = SFD RX = (2, 1800); corr (residence) = 100ns en 2^-16 = 6553600
    -- (t4 en segundo distinto de t1 para detectar confusiones t4<->t1)
    rx_sec <= std_logic_vector(to_unsigned(2, SEC_W));
    rx_ns  <= std_logic_vector(to_unsigned(1800, NS_W));
    rx_corr <= std_logic_vector(to_unsigned(6553600, 64));
    rx_mtype <= MT_PDELAY_RESP;
    rx_mvalid <= '1'; step;
    rx_mvalid <= '0';
    -- esperar pd_calc
    for i in 1 to 10 loop step; exit when pd_calc = '1'; end loop;
    assert pd_calc = '1' report "FALLO: no disparo pd_calc" severity failure;
    assert pd_t1_sec = std_logic_vector(to_unsigned(1, SEC_W)) report "FALLO t1_sec" severity failure;
    assert pd_t1_ns = std_logic_vector(to_unsigned(1000, NS_W)) report "FALLO t1_ns" severity failure;
    assert pd_t4_sec = std_logic_vector(to_unsigned(2, SEC_W)) report "FALLO t4_sec" severity failure;
    assert pd_t4_ns = std_logic_vector(to_unsigned(1800, NS_W)) report "FALLO t4_ns" severity failure;
    assert pd_corr = std_logic_vector(to_unsigned(6553600, 64)) report "FALLO corr" severity failure;
    report "OK iniciador: t1=(1,1000) t4=(2,1800) corr=100ns -> pd_calc con datos correctos";
    for i in 1 to 5 loop step; end loop;

    -- ============ CASO RESPONDEDOR ============
    -- inyectar un Pdelay_Req entrante. t2 = SFD RX = (2, 500); spid del requester.
    rx_sec <= std_logic_vector(to_unsigned(2, SEC_W));
    rx_ns  <= std_logic_vector(to_unsigned(500, NS_W));
    rx_spid <= x"AABBCCDDEEFF00112233";
    rx_mtype <= MT_PDELAY_REQ;
    rx_mvalid <= '1'; step;
    rx_mvalid <= '0';
    -- el respondedor debe capturar t2 y rpid, y disparar Resp
    for i in 1 to 10 loop step; exit when tx_send = '1' and tx_sel = SEL_PDELAY_RESP; end loop;
    assert tx_sel = SEL_PDELAY_RESP report "FALLO: no disparo Pdelay_Resp" severity failure;
    assert tx_req_rx_sec = std_logic_vector(to_unsigned(2, SEC_W)) report "FALLO t2_sec al motor" severity failure;
    assert tx_req_rx_ns = std_logic_vector(to_unsigned(500, NS_W)) report "FALLO t2_ns al motor" severity failure;
    assert tx_req_portid = x"AABBCCDDEEFF00112233" report "FALLO reqPortId al motor" severity failure;
    report "OK respondedor: Req entrante -> t2=(2,500) rpid capturado -> dispara Resp";
    motor_run(2, 700);   -- el motor envia el Resp (t3=(2,700))
    for i in 1 to 5 loop step; end loop;

    report "=== PTP_PDELAY_FSM LAYER 1a PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
