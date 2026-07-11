-- tb_ptp_tx_pdelay.vhd — integracion TX de Pdelay_Req y Pdelay_Resp.
-- Emite un Pdelay_Req (override originTS=t1) y un Pdelay_Resp (override
-- correctionField=residence, + campos t2 y requestingPortIdentity), captura
-- ambos streams MII y vuelca los valores usados para verificacion Python.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;
use work.eth_pkg.all;

entity tb_ptp_tx_pdelay is
end entity;

architecture sim of tb_ptp_tx_pdelay is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);
  signal tx_sfd_pulse : std_logic;
  signal ts_sec : std_logic_vector(SEC_W-1 downto 0);
  signal ts_ns  : std_logic_vector(NS_W-1 downto 0);
  signal ts_valid, ts_ack, ts_overrun : std_logic;

  signal f_dout : std_logic_vector(8 downto 0);
  signal f_empty, f_rd, f_full, f_wr : std_logic;
  signal f_din : std_logic_vector(8 downto 0);

  signal tx_data : std_logic_vector(7 downto 0);
  signal tx_valid, tx_last, tx_ready, tx_busy, underrun : std_logic;
  signal txd : std_logic_vector(3 downto 0);
  signal tx_en : std_logic;
  signal ovr_en : std_logic;
  signal ovr_off : std_logic_vector(10 downto 0);
  signal ovr_len : std_logic_vector(3 downto 0);
  signal ovr_data : std_logic_vector(79 downto 0);

  signal send : std_logic := '0';
  signal sel : msg_sel_t := SEL_PDELAY_REQ;
  signal busy, tx_done : std_logic;
  signal frame_ready : std_logic := '0';

  -- campos Resp
  signal req_rx_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal req_rx_ns  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal req_portid : std_logic_vector(79 downto 0) := (others => '0');
  signal resid_corr : std_logic_vector(63 downto 0) := (others => '0');

  constant CLOCK_ID : std_logic_vector(63 downto 0) := x"0011223344556677";
  constant PORT_NUM : std_logic_vector(15 downto 0) := x"0001";
  constant SRC_MAC  : std_logic_vector(47 downto 0) := x"02DECAFBADED";

  signal cap_enable : std_logic := '0';
  signal cap_file_sel : integer := 0;  -- 0=req, 1=resp

begin
  clk <= not clk after TCK/2 when not done else '0';

  process(clk)
    variable d : unsigned(1 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      if rst = '1' then d := (others => '0'); mii_ce <= '0';
      elsif d = 3 then d := (others => '0'); mii_ce <= '1';
      else d := d + 1; mii_ce <= '0'; end if;
    end if;
  end process;

  u_clk : entity work.ptp_clock
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, role_slave => '0', clr_servo => '0',
              kp => x"0000", ki => x"0000", offset_err => (others => '0'),
              offset_valid => '0', now_sec => now_sec, now_ns => now_ns,
              rate_adj_o => open, offset_applied_o => open);

  u_ts : entity work.ptp_tstamp
    port map (clk => clk, rst => rst, now_sec => now_sec, now_ns => now_ns,
              lat_ns => x"0000", sfd_pulse => tx_sfd_pulse, rd_ack => ts_ack,
              ts_sec => ts_sec, ts_ns => ts_ns, ts_valid => ts_valid, ts_overrun => ts_overrun);

  u_tx : entity work.ptp_tx
    port map (clk => clk, rst => rst, send => send, sel => sel,
              busy => busy, done => tx_done,
              clock_id => CLOCK_ID, port_num => PORT_NUM, src_mac => SRC_MAC,
              req_rx_sec => req_rx_sec, req_rx_ns => req_rx_ns,
              req_portid => req_portid,
              ts_sec => ts_sec, ts_ns => ts_ns, ts_valid => ts_valid, ts_ack => ts_ack,
              fifo_wr => f_wr, fifo_din => f_din, fifo_full => f_full,
              ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data);

  u_fifo : entity work.spw_fifo
    generic map (LOG2_DEPTH => 11, WIDTH => 9)
    port map (clk => clk, aresetn => not rst, clr => '0',
              wr_en => f_wr, wdata => f_din, full => f_full,
              rdata => f_dout, rd_en => f_rd, empty => f_empty, level => open);

  sf_gate : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then frame_ready <= '0';
      else
        if f_wr = '1' and f_din(8) = '1' then frame_ready <= '1'; end if;
        if frame_ready = '1' and f_empty = '1' and tx_busy = '0' then frame_ready <= '0'; end if;
      end if;
    end if;
  end process;

  tx_valid <= (not f_empty) and frame_ready;
  tx_data  <= f_dout(7 downto 0);
  tx_last  <= f_dout(8);
  f_rd     <= tx_ready and (not f_empty) and frame_ready;

  u_mac : entity work.eth_tx_mii
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
              tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
              tx_ready => tx_ready, tx_busy => tx_busy, underrun => underrun,
              txd => txd, tx_en => tx_en, tx_sfd_pulse => tx_sfd_pulse,
              ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data);

  cap : process
    file fr : text;
    file fs : text;
    variable ln : line;
  begin
    file_open(fr, "tx_req_stream.txt", write_mode);
    file_open(fs, "tx_resp_stream.txt", write_mode);
    loop
      wait until rising_edge(clk);
      exit when done;
      if mii_ce = '1' and tx_en = '1' and cap_enable = '1' then
        write(ln, to_integer(unsigned(txd)));
        if cap_file_sel = 0 then writeline(fr, ln); else writeline(fs, ln); end if;
      end if;
    end loop;
    file_close(fr); file_close(fs);
    wait;
  end process;

  stim : process
    file tf : text;
    variable ln : line;
    procedure step is begin wait until rising_edge(clk); end procedure;
  begin
    rst <= '1'; step; step; step; rst <= '0';
    for i in 1 to 50 loop step; end loop;

    -- ---- Pdelay_Req (override originTS = t1) ----
    sel <= SEL_PDELAY_REQ;
    cap_file_sel <= 0; cap_enable <= '1';
    send <= '1'; step; send <= '0';
    for i in 1 to 1500 loop step; exit when tx_done = '1'; end loop;
    file_open(tf, "tx_req_ts.txt", write_mode);
    write(ln, to_integer(unsigned(ts_sec))); writeline(tf, ln);
    write(ln, to_integer(unsigned(ts_ns)));  writeline(tf, ln);
    file_close(tf);
    for i in 1 to 2000 loop step; end loop;   -- dejar terminar la trama
    cap_enable <= '0';

    -- ---- Pdelay_Resp (override corrField, campos t2 y reqPortId) ----
    req_rx_sec <= std_logic_vector(to_unsigned(7, SEC_W));
    req_rx_ns  <= std_logic_vector(to_unsigned(2500, NS_W));
    req_portid <= x"00AABBCCDDEEFF00" & x"0002";   -- clockId+port del requester
    resid_corr <= std_logic_vector(to_unsigned(150*65536, 64)); -- 150 ns residence
    sel <= SEL_PDELAY_RESP;
    cap_file_sel <= 1; cap_enable <= '1';
    send <= '1'; step; send <= '0';
    for i in 1 to 1500 loop step; exit when tx_done = '1'; end loop;
    -- volcar t3 (TS del SFD del Resp) para calcular el residence esperado
    file_open(tf, "tx_resp_t3.txt", write_mode);
    write(ln, to_integer(unsigned(ts_sec))); writeline(tf, ln);
    write(ln, to_integer(unsigned(ts_ns)));  writeline(tf, ln);
    file_close(tf);
    for i in 1 to 2000 loop step; end loop;
    cap_enable <= '0';

    done <= true;
    report "=== PTP_TX Pdelay Req+Resp transmitidos ===";
    wait;
  end process;

end architecture sim;
