-- ============================================================================
-- spw_mmio.vhd -- IP SpaceWire completo con banco de registros MMIO
-- ============================================================================
-- Region 0xB000_0000 (decode addr[31:28]="1011" en mem_subsys; aqui llegan los
-- bits bajos). Contrato del bus dmem del RV32: req de 1 ciclo, rdata
-- COMBINACIONAL en el mismo ciclo, pop-on-read.
--
-- Mapa (offsets de palabra, addr(7:2)):
--   0x00 CTRL  RW  b0 EN (reset sincrono del nucleo y FIFOs mientras 0)
--                  b1 START  b2 AUTOSTART  b3 DISABLE  b4 LOOP_INT
--   0x04 DIV   RW  b7:0 ciclos de clk por bit (min 2; reset 0x0A = 10 Mbit/s)
--                  registro propio: parcheable con un solo addi (leccion BRP)
--   0x08 CMD   W1P b0 TX_FLUSH  b1 RX_FLUSH (escritura pulsa la accion)
--   0x0C TIME  W   b7:0 valor -> latch + tick_in (emite Time-Code en Run)
--              R   b7:0 ultimo time_out recibido, b15:8 contador de ticks
--   0x10 STAT  R   vivos:    b2:0 estado del enlace, b3 RUN, b4 TX_SPACE,
--                            b5 RX_AVAIL, b6 TX_EMPTY, b7 RX_FULL,
--                            b14:8 rx_level
--                  stickies: b16 PAR, b17 ESC, b18 DISC, b19 CRED, b20 TICK,
--                            b21 LINKDOWN (salida de Run), b22 RUNOK (llegada
--                            a Run), b23 TXOVF, b24 RXOVF
--              W   limpia stickies; los sets del mismo ciclo GANAN
--   0x14 TXD   W   b8:0 N-Char al FIFO TX (b8='1': b0='0' EOP, '1' EEP)
--              R   b6:0 tx_level, b8 tx_full
--   0x18 RXD   R   pop-on-read: b8:0 N-Char, b31 VALID
--   0x1C IRQEN RW  mascara bit a bit sobre STAT; irq = OR(STAT and IRQEN)
--                  (IRQ por nivel, sin ack)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_mmio is
  generic (
    DISC_CYCLES : integer := 85;
    T64_CYCLES  : integer := 640;
    T128_CYCLES : integer := 1280
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;                        -- sincrono, activo alto
    -- bus dmem
    sel   : in  std_logic;                        -- req de 1 ciclo
    we    : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    rdata : out std_logic_vector(31 downto 0);
    irq   : out std_logic;
    -- enlace fisico
    din   : in  std_logic;
    sin   : in  std_logic;
    dout  : out std_logic;
    sout  : out std_logic
  );
end entity spw_mmio;

architecture rtl of spw_mmio is

  signal arstn : std_logic;

  -- registros
  signal ctrl_r  : std_logic_vector(4 downto 0)  := (others => '0');
  signal div_r   : std_logic_vector(7 downto 0)  := x"0A";
  signal irqen_r : std_logic_vector(31 downto 0) := (others => '0');

  -- stickies b24:16 de STAT
  signal stk : std_logic_vector(8 downto 0) := (others => '0');

  -- time-codes
  signal tick_in_p  : std_logic := '0';
  signal time_in_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal time_last  : std_logic_vector(7 downto 0) := (others => '0');
  signal tick_cnt   : unsigned(7 downto 0) := (others => '0');

  -- codec
  signal en_i                            : std_logic;
  signal tick_out_i                      : std_logic;
  signal time_out_i                      : std_logic_vector(7 downto 0);
  signal tx_valid_i, tx_ack_i            : std_logic;
  signal tx_head                         : std_logic_vector(8 downto 0);
  signal rx_we_i                         : std_logic;
  signal rx_data_i                       : std_logic_vector(8 downto 0);
  signal state_i                         : std_logic_vector(2 downto 0);
  signal e_par, e_esc, e_disc, e_cred    : std_logic;
  signal din_i, sin_i, dout_i, sout_i    : std_logic;

  -- FIFOs
  signal txf_clr, rxf_clr                : std_logic;
  signal txf_wr, rxf_rd                  : std_logic;
  signal txf_empty, txf_full             : std_logic;
  signal rxf_empty, rxf_full             : std_logic;
  signal txf_level, rxf_level            : std_logic_vector(6 downto 0);
  signal rxf_head                        : std_logic_vector(8 downto 0);
  signal rx_room_i                       : std_logic_vector(6 downto 0);

  -- deteccion de flancos de RUN
  signal run_now, run_d                  : std_logic := '0';

  -- vista STAT de 32 bits
  signal stat_v : std_logic_vector(31 downto 0);

  -- decodificacion
  signal sel_ctrl, sel_div, sel_cmd, sel_time  : std_logic;
  signal sel_stat, sel_txd, sel_rxd, sel_irqen : std_logic;

begin

  arstn <= not rst;

  -- ------------------------------------------------------------------ decode
  sel_ctrl  <= '1' when addr(7 downto 2) = "000000" else '0';
  sel_div   <= '1' when addr(7 downto 2) = "000001" else '0';
  sel_cmd   <= '1' when addr(7 downto 2) = "000010" else '0';
  sel_time  <= '1' when addr(7 downto 2) = "000011" else '0';
  sel_stat  <= '1' when addr(7 downto 2) = "000100" else '0';
  sel_txd   <= '1' when addr(7 downto 2) = "000101" else '0';
  sel_rxd   <= '1' when addr(7 downto 2) = "000110" else '0';
  sel_irqen <= '1' when addr(7 downto 2) = "000111" else '0';

  en_i    <= ctrl_r(0);
  run_now <= '1' when state_i = "101" else '0';

  -- --------------------------------------------------------------- loopback
  din_i <= dout_i when ctrl_r(4) = '1' else din;
  sin_i <= sout_i when ctrl_r(4) = '1' else sin;
  dout  <= dout_i;
  sout  <= sout_i;

  -- ------------------------------------------------------------------ FIFOs
  -- escritura del bus al FIFO TX
  txf_wr <= sel and we and sel_txd;
  -- pop-on-read del FIFO RX
  rxf_rd <= sel and (not we) and sel_rxd and (not rxf_empty);

  tx_valid_i <= not txf_empty;
  rx_room_i  <= std_logic_vector(to_unsigned(64, 7) - unsigned(rxf_level));

  u_txf : entity work.spw_fifo
    generic map (LOG2_DEPTH => 6, WIDTH => 9)
    port map (
      clk => clk, aresetn => arstn, clr => txf_clr,
      wr_en => txf_wr, wdata => wdata(8 downto 0),
      rd_en => tx_ack_i, rdata => tx_head,
      empty => txf_empty, full => txf_full, level => txf_level
    );

  u_rxf : entity work.spw_fifo
    generic map (LOG2_DEPTH => 6, WIDTH => 9)
    port map (
      clk => clk, aresetn => arstn, clr => rxf_clr,
      wr_en => rx_we_i, wdata => rx_data_i,
      rd_en => rxf_rd, rdata => rxf_head,
      empty => rxf_empty, full => rxf_full, level => rxf_level
    );

  -- ------------------------------------------------------------------ codec
  u_codec : entity work.spw_codec
    generic map (
      DISC_CYCLES => DISC_CYCLES,
      T64_CYCLES  => T64_CYCLES,
      T128_CYCLES => T128_CYCLES
    )
    port map (
      clk => clk, arstn => arstn, en => en_i, div => div_r,
      link_start => ctrl_r(1), link_autostart => ctrl_r(2),
      link_disable => ctrl_r(3),
      tick_in => tick_in_p, time_in => time_in_r,
      tick_out => tick_out_i, time_out => time_out_i,
      tx_valid => tx_valid_i, tx_data => tx_head, tx_ack => tx_ack_i,
      rx_we => rx_we_i, rx_data => rx_data_i, rx_room => rx_room_i,
      state => state_i,
      err_par => e_par, err_esc => e_esc,
      err_disc => e_disc, err_credit => e_cred,
      din => din_i, sin => sin_i, dout => dout_i, sout => sout_i
    );

  -- ------------------------------------------------------------- vista STAT
  stat_v(2 downto 0)   <= state_i;
  stat_v(3)            <= run_now;
  stat_v(4)            <= not txf_full;          -- TX_SPACE
  stat_v(5)            <= not rxf_empty;         -- RX_AVAIL
  stat_v(6)            <= txf_empty;
  stat_v(7)            <= rxf_full;
  stat_v(14 downto 8)  <= rxf_level;
  stat_v(15)           <= '0';
  stat_v(24 downto 16) <= stk;
  stat_v(31 downto 25) <= (others => '0');

  -- ------------------------------------------- rdata COMBINACIONAL (contrato)
  rdata <= (31 downto 5 => '0') & ctrl_r                          when sel_ctrl  = '1' else
           (31 downto 8 => '0') & div_r                           when sel_div   = '1' else
           (31 downto 16 => '0') & std_logic_vector(tick_cnt) & time_last
                                                                  when sel_time  = '1' else
           stat_v                                                 when sel_stat  = '1' else
           (31 downto 9 => '0') & txf_full & '0' & txf_level      when sel_txd   = '1' else
           (not rxf_empty) & (30 downto 9 => '0') & rxf_head      when sel_rxd   = '1' else
           irqen_r                                                when sel_irqen = '1' else
           (others => '0');

  -- ----------------------------------------------------------- IRQ por nivel
  irq_p : process (clk, arstn)
  begin
    if arstn = '0' then
      irq <= '0';
    elsif rising_edge(clk) then
      irq <= or (stat_v and irqen_r);
    end if;
  end process irq_p;

  -- ------------------------------------------------------ registros y stickies
  regs : process (clk, arstn)
    variable wr : boolean;
  begin
    if arstn = '0' then
      ctrl_r    <= (others => '0');
      div_r     <= x"0A";
      irqen_r   <= (others => '0');
      stk       <= (others => '0');
      tick_in_p <= '0';
      time_in_r <= (others => '0');
      time_last <= (others => '0');
      tick_cnt  <= (others => '0');
      txf_clr   <= '0';
      rxf_clr   <= '0';
      run_d     <= '0';
    elsif rising_edge(clk) then
      wr := (sel = '1') and (we = '1');

      -- pulsos por defecto
      tick_in_p <= '0';
      txf_clr   <= not en_i;              -- EN=0: FIFOs en limpieza continua
      rxf_clr   <= not en_i;
      run_d     <= run_now;

      -- escrituras de registros
      if wr then
        if sel_ctrl = '1' then
          ctrl_r <= wdata(4 downto 0);
        elsif sel_div = '1' then
          div_r <= wdata(7 downto 0);
        elsif sel_cmd = '1' then
          if wdata(0) = '1' then txf_clr <= '1'; end if;
          if wdata(1) = '1' then rxf_clr <= '1'; end if;
        elsif sel_time = '1' then
          time_in_r <= wdata(7 downto 0);
          tick_in_p <= '1';
        elsif sel_irqen = '1' then
          irqen_r <= wdata;
        elsif sel_stat = '1' then
          stk <= (others => '0');         -- limpiar stickies...
        end if;
      end if;

      -- ...y los sets del mismo ciclo GANAN
      if e_par = '1' then stk(0) <= '1'; end if;
      if e_esc = '1' then stk(1) <= '1'; end if;
      if e_disc = '1' then stk(2) <= '1'; end if;
      if e_cred = '1' then stk(3) <= '1'; end if;
      if tick_out_i = '1' then
        stk(4)    <= '1';
        time_last <= time_out_i;
        tick_cnt  <= tick_cnt + 1;
      end if;
      if run_d = '1' and run_now = '0' then stk(5) <= '1'; end if;  -- LINKDOWN
      if run_d = '0' and run_now = '1' then stk(6) <= '1'; end if;  -- RUNOK
      if txf_wr = '1' and txf_full = '1' then stk(7) <= '1'; end if;
      if rx_we_i = '1' and rxf_full = '1' then stk(8) <= '1'; end if;
    end if;
  end process regs;

end architecture rtl;
