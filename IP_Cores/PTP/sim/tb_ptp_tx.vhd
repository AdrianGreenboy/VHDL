-- tb_ptp_tx.vhd — integracion del motor TX-PTP (capa 1a extendida).
-- Conecta ptp_tx -> spw_fifo -> eth_tx_mii(+override), con ptp_clock y
-- ptp_tstamp enganchado a tx_sfd_pulse. Envia un Sync, captura el stream MII
-- (dst..FCS) y lo compara byte a byte contra ref_sync_frame.txt (del ISS).
-- La clave: el originTimestamp lo inserta el OVERRIDE con el TS del SFD real.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;
use work.eth_pkg.all;

entity tb_ptp_tx is
end entity;

architecture sim of tb_ptp_tx is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  -- reloj PTP
  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);

  -- timestamp TX
  signal tx_sfd_pulse : std_logic;
  signal ts_sec : std_logic_vector(SEC_W-1 downto 0);
  signal ts_ns  : std_logic_vector(NS_W-1 downto 0);
  signal ts_valid : std_logic;
  signal ts_ack   : std_logic;
  signal ts_overrun : std_logic;

  -- motor -> FIFO

  -- FIFO -> MAC
  signal f_dout : std_logic_vector(8 downto 0);
  signal f_empty, f_rd, f_full : std_logic;
  signal f_din : std_logic_vector(8 downto 0);
  signal f_wr : std_logic;

  -- MAC
  signal tx_data : std_logic_vector(7 downto 0);
  signal tx_valid, tx_last, tx_ready, tx_busy, underrun : std_logic;
  signal txd : std_logic_vector(3 downto 0);
  signal tx_en : std_logic;

  -- override
  signal ovr_en : std_logic;
  signal ovr_off : std_logic_vector(10 downto 0);
  signal ovr_len : std_logic_vector(3 downto 0);
  signal ovr_data : std_logic_vector(79 downto 0);

  -- control motor
  signal send : std_logic := '0';
  signal busy, tx_done : std_logic;
  signal frame_ready : std_logic := '0';

  -- identidad
  constant CLOCK_ID : std_logic_vector(63 downto 0) := x"0011223344556677";
  constant PORT_NUM : std_logic_vector(15 downto 0) := x"0001";
  constant SRC_MAC  : std_logic_vector(47 downto 0) := x"02DECAFBADED";

begin
  clk <= not clk after TCK/2 when not done else '0';

  -- mii_ce /4
  process(clk)
    variable d : unsigned(1 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      if rst = '1' then d := (others => '0'); mii_ce <= '0';
      elsif d = 3 then d := (others => '0'); mii_ce <= '1';
      else d := d + 1; mii_ce <= '0'; end if;
    end if;
  end process;

  -- reloj PTP (libre, sin ajustes; solo necesitamos que avance)
  u_clk : entity work.ptp_clock
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, role_slave => '0', clr_servo => '0',
              kp => x"0000", ki => x"0000",
              offset_err => (others => '0'), offset_valid => '0',
              now_sec => now_sec, now_ns => now_ns,
              rate_adj_o => open, offset_applied_o => open);

  -- timestamp TX enganchado al SFD
  u_ts : entity work.ptp_tstamp
    port map (clk => clk, rst => rst, now_sec => now_sec, now_ns => now_ns,
              lat_ns => x"0000",     -- sin latencia para simplificar la ref
              sfd_pulse => tx_sfd_pulse, rd_ack => ts_ack,
              ts_sec => ts_sec, ts_ns => ts_ns,
              ts_valid => ts_valid, ts_overrun => ts_overrun);

  -- motor TX-PTP -> FIFO (interfaz de escritura explicita)
  u_tx : entity work.ptp_tx
    port map (clk => clk, rst => rst, send => send, sel => SEL_SYNC,
              busy => busy, done => tx_done,
              clock_id => CLOCK_ID, port_num => PORT_NUM, src_mac => SRC_MAC,
              req_rx_sec => (others => '0'), req_rx_ns => (others => '0'),
              req_portid => (others => '0'),
              ts_sec => ts_sec, ts_ns => ts_ns, ts_valid => ts_valid, ts_ack => ts_ack,
              fifo_wr => f_wr, fifo_din => f_din, fifo_full => f_full,
              ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data);

  u_fifo : entity work.spw_fifo
    generic map (LOG2_DEPTH => 11, WIDTH => 9)
    port map (clk => clk, aresetn => not rst, clr => '0',
              wr_en => f_wr, wdata => f_din, full => f_full,
              rdata => f_dout, rd_en => f_rd, empty => f_empty,
              level => open);

  -- store-and-forward: el MAC arranca cuando la trama COMPLETA esta en la
  -- FIFO. Detectamos el EOF escrito (f_din(8)='1' con f_wr='1') para armar
  -- frame_ready; se desarma cuando la FIFO se vacia y el MAC ya no esta busy.
  sf_gate : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        frame_ready <= '0';
      else
        if f_wr = '1' and f_din(8) = '1' then
          frame_ready <= '1';                 -- EOF en la FIFO: trama completa
        end if;
        if frame_ready = '1' and f_empty = '1' and tx_busy = '0' then
          frame_ready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- MAC lee de la FIFO gated por frame_ready
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

  -- captura de nibbles a fichero
  cap : process
    file fh : text;
    variable ln : line;
  begin
    file_open(fh, "tx_sync_stream.txt", write_mode);
    loop
      wait until rising_edge(clk);
      exit when done;
      if mii_ce = '1' and tx_en = '1' then
        write(ln, to_integer(unsigned(txd)));
        writeline(fh, ln);
      end if;
    end loop;
    file_close(fh);
    wait;
  end process;

  stim : process
    file tf : text;
    variable ln : line;
    procedure step is begin wait until rising_edge(clk); end procedure;
  begin
    rst <= '1'; step; step; step; rst <= '0';
    -- dejar avanzar el reloj un poco para tener un now no trivial
    for i in 1 to 50 loop step; end loop;
    -- enviar Sync
    send <= '1'; step; send <= '0';
    -- esperar a que el motor cargue el override con el TS del SFD
    for i in 1 to 1200 loop
      step;
      exit when tx_done = '1';
    end loop;
    -- volcar el timestamp que el motor uso (leido de ovr_data ya empaquetado):
    -- secondsField = ovr_data bytes 0..5, nanosecondsField = bytes 6..9.
    file_open(tf, "tx_sync_ts.txt", write_mode);
    write(ln, to_integer(unsigned(ts_sec)));  writeline(tf, ln);
    write(ln, to_integer(unsigned(ts_ns)));   writeline(tf, ln);
    file_close(tf);
    -- dejar terminar la transmision completa
    for i in 1 to 2000 loop step; end loop;
    done <= true;
    report "=== PTP_TX Sync transmitido, captura completa ===";
    wait;
  end process;

end architecture sim;
