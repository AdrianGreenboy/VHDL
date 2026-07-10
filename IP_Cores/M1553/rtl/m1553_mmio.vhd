-- ============================================================================
-- m1553_mmio.vhd -- IP MIL-STD-1553B completo con banco de registros MMIO
-- ============================================================================
-- Region 0xC000_0000 (decode addr[31:28]="1100" en mem_subsys; aqui llegan
-- los bits bajos). Contrato del bus dmem del RV32: sel de 1 ciclo, rdata
-- COMBINACIONAL en el mismo ciclo, pop-on-read.
--
-- Envuelve UN Bus Controller y DOS Remote Terminals (RT0, RT1) sobre un bus
-- interno resuelto por tx_en (LOOP_INT), mas un FIFO TX de datos (16 b, comun:
-- quien transmite lo drena) y un FIFO RX de 24 b (dato + fuente/subaddr/bcast).
--
-- Semanticas heredadas (SPW/CAN/IIC/I3C):
--   - STAT: los stickies (b16..) se limpian con CUALQUIER escritura a STAT;
--     los sets del mismo ciclo GANAN sobre la limpieza.
--   - IRQ por NIVEL sin ack: irq = or(STAT and IRQEN).
--   - EN=0: nucleos y FIFOs en reset/limpieza continua.
--   - CMD: escritura pulsa TX_FLUSH/RX_FLUSH/GO.
--   - LOOP_INT: bus interno entre BC/RT0/RT1, pads liberados. Self-test de
--     silicio.
--
-- Mapa (offsets de palabra, addr(7:2)):
--   0x00 CTRL   RW  b0 EN, b1 LOOP_INT
--   0x04 RTADDR RW  b4:0 addr RT0, b12:8 addr RT1
--   0x08 CMD    W1P b0 TX_FLUSH, b1 RX_FLUSH, b2 GO
--   0x0C MSG    RW  b0 RTRT, b1 F_TR, b6:2 F_RT, b11:7 F_SA, b16:12 F_WC,
--                   b21:17 F2_RT, b26:22 F2_SA
--   0x10 STAT   R   b0 BC_BUSY, b3:1 <res>, b4 TXF_EMPTY, b5 TXF_FULL,
--                   b6 RXF_EMPTY, b7 RXF_FULL, b14:8 rxf_level;
--                   stickies b16 DONE, b17 OK, b18 TOUT, b19 SERR, b20 MSG_ME,
--                   b21 RT0_CMD, b22 RT1_CMD, b23 RT0_ERR, b24 RT1_ERR,
--                   b25 RXF_OVF, b26 RT0_BCR, b27 RT1_BCR
--               W   limpia stickies (sets del mismo ciclo ganan)
--   0x14 TXD    W   b15:0 data word al FIFO TX;  R b6:0 level, b8 full
--   0x18 RXD    R   pop-on-read b15:0 dato, b17:16 fuente, b22:18 subaddr,
--                   b23 bcast, b31 VALID
--   0x1C IRQEN  RW  mascara sobre STAT
--   0x20 RESULT R   b15:0 stat1, b31:16 stat2
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m1553_mmio is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;                          -- sincrono, activo alto
    -- bus dmem
    sel   : in  std_logic;
    we    : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    rdata : out std_logic_vector(31 downto 0);      -- COMBINACIONAL
    irq   : out std_logic;
    -- enlace fisico (bus 1553 unico; en LOOP_INT no se usa)
    bus_rx_i : in  std_logic;
    bus_tx_o : out std_logic;
    bus_txen_o : out std_logic
  );
end entity m1553_mmio;

architecture rtl of m1553_mmio is

  signal arstn : std_logic;

  -- registros
  signal ctrl_r   : std_logic_vector(1 downto 0)  := (others => '0');
  signal rt0a_r   : std_logic_vector(4 downto 0)  := "00101";
  signal rt1a_r   : std_logic_vector(4 downto 0)  := "01001";
  signal irqen_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal msg_r    : std_logic_vector(26 downto 0) := (others => '0');
  signal stat1_r, stat2_r : std_logic_vector(15 downto 0) := (others => '0');

  signal en_i, loop_i : std_logic;

  -- stickies b27:16 (12 bits)
  signal stk : std_logic_vector(11 downto 0) := (others => '0');

  -- decode
  signal sel_ctrl, sel_rtad, sel_cmd, sel_msg, sel_stat : std_logic;
  signal sel_txd, sel_rxd, sel_irqen, sel_result        : std_logic;

  -- BC
  signal bc_go     : std_logic;
  signal bc_busy, bc_done, bc_ok, bc_tout, bc_serr, bc_me : std_logic;
  signal bc_s1, bc_s2 : std_logic_vector(15 downto 0);
  signal bc_txrd   : std_logic;
  signal bc_rxwe   : std_logic;
  signal bc_rxdat  : std_logic_vector(15 downto 0);
  signal bc_tx, bc_txen : std_logic;

  -- RTs
  signal rt0_txrd, rt0_rxwe, rt0_evc, rt0_evok, rt0_everr : std_logic;
  signal rt0_rxdat : std_logic_vector(15 downto 0);
  signal rt0_rxsa  : std_logic_vector(4 downto 0);
  signal rt0_rxbc, rt0_bcr, rt0_me : std_logic;
  signal rt0_tx, rt0_txen : std_logic;

  signal rt1_txrd, rt1_rxwe, rt1_evc, rt1_evok, rt1_everr : std_logic;
  signal rt1_rxdat : std_logic_vector(15 downto 0);
  signal rt1_rxsa  : std_logic_vector(4 downto 0);
  signal rt1_rxbc, rt1_bcr, rt1_me : std_logic;
  signal rt1_tx, rt1_txen : std_logic;

  -- bus interno / externo
  signal bus_v : std_logic;

  -- FIFO TX (16 b) y su drenaje comun
  signal txf_clr, txf_wr, txf_rd, txf_empty, txf_full : std_logic;
  signal txf_head : std_logic_vector(15 downto 0);
  signal txf_level : std_logic_vector(6 downto 0);

  -- FIFO RX (24 b: dato(16) + fuente(2) + subaddr(5) + bcast(1))
  signal rxf_clr, rxf_wr, rxf_rd, rxf_empty, rxf_full : std_logic;
  signal rxf_wdata, rxf_head : std_logic_vector(23 downto 0);
  signal rxf_level : std_logic_vector(6 downto 0);
  signal skid_v : std_logic := '0';
  signal skid_d : std_logic_vector(23 downto 0) := (others => '0');

  signal stat_v : std_logic_vector(31 downto 0);

begin

  arstn <= not rst;
  en_i   <= ctrl_r(0);
  loop_i <= ctrl_r(1);

  -- ------------------------------------------------------------------ decode
  sel_ctrl   <= '1' when addr(7 downto 2) = "000000" else '0';
  sel_rtad   <= '1' when addr(7 downto 2) = "000001" else '0';
  sel_cmd    <= '1' when addr(7 downto 2) = "000010" else '0';
  sel_msg    <= '1' when addr(7 downto 2) = "000011" else '0';
  sel_stat   <= '1' when addr(7 downto 2) = "000100" else '0';
  sel_txd    <= '1' when addr(7 downto 2) = "000101" else '0';
  sel_rxd    <= '1' when addr(7 downto 2) = "000110" else '0';
  sel_irqen  <= '1' when addr(7 downto 2) = "000111" else '0';
  sel_result <= '1' when addr(7 downto 2) = "001000" else '0';

  bc_go <= sel and we and sel_cmd and wdata(2);

  -- ------------------------------------------------------ resolucion del bus
  bus_v <= bc_tx  when bc_txen  = '1' else
           rt0_tx when rt0_txen = '1' else
           rt1_tx when rt1_txen = '1' else
           bus_rx_i when loop_i = '0' else
           '0';

  bus_tx_o   <= bus_v when (bc_txen or rt0_txen or rt1_txen) = '1' else '0';
  bus_txen_o <= (bc_txen or rt0_txen or rt1_txen) and (not loop_i);

  -- ------------------------------------------------------------------- FIFOs
  txf_wr <= sel and we and sel_txd and (not txf_full);
  txf_rd <= bc_txrd or rt0_txrd or rt1_txrd;      -- solo uno transmite a la vez
  rxf_rd <= sel and (not we) and sel_rxd and (not rxf_empty);

  u_txf : entity work.spw_fifo
    generic map (LOG2_DEPTH => 6, WIDTH => 16)
    port map (
      clk => clk, aresetn => arstn, clr => txf_clr,
      wr_en => txf_wr, wdata => wdata(15 downto 0),
      rd_en => txf_rd, rdata => txf_head,
      empty => txf_empty, full => txf_full, level => txf_level);

  -- multiplexado de la escritura RX. En broadcast RT0 y RT1 escriben el mismo
  -- ciclo; el FIFO solo admite una escritura, asi que se serializa con un skid
  -- de 1 (la copia de RT1 espera un ciclo). El resto de formatos nunca colisiona.
  rxf_wr <= bc_rxwe or rt0_rxwe or rt1_rxwe or skid_v;
  rxf_wdata <=
      skid_d                                 when skid_v = '1' else
      rt0_rxdat & "01" & rt0_rxsa & rt0_rxbc when rt0_rxwe = '1' else
      rt1_rxdat & "10" & rt1_rxsa & rt1_rxbc when rt1_rxwe = '1' else
      bc_rxdat  & "00" & "00000" & '0';

  u_rxf : entity work.spw_fifo
    generic map (LOG2_DEPTH => 6, WIDTH => 24)
    port map (
      clk => clk, aresetn => arstn, clr => rxf_clr,
      wr_en => rxf_wr, wdata => rxf_wdata,
      rd_en => rxf_rd, rdata => rxf_head,
      empty => rxf_empty, full => rxf_full, level => rxf_level);

  -- --------------------------------------------------------------- nucleos
  u_bc : entity work.m1553_bc_core
    port map (
      clk => clk, rst => rst, en => en_i,
      go => bc_go, rtrt => msg_r(0),
      f_rt => msg_r(6 downto 2), f_tr => msg_r(1),
      f_sa => msg_r(11 downto 7), f_wc => msg_r(16 downto 12),
      f2_rt => msg_r(21 downto 17), f2_sa => msg_r(26 downto 22),
      busy => bc_busy, done => bc_done,
      r_ok => bc_ok, r_tout => bc_tout, r_serr => bc_serr, r_me => bc_me,
      stat1 => bc_s1, stat2 => bc_s2,
      tx_rd => bc_txrd, tx_wdat => txf_head,
      rx_we => bc_rxwe, rx_wdat => bc_rxdat,
      bus_rx => bus_v, bus_tx => bc_tx, bus_txen => bc_txen);

  u_rt0 : entity work.m1553_rt_core
    port map (
      clk => clk, rst => rst, en => en_i, rt_addr => rt0a_r,
      tx_rd => rt0_txrd, tx_wdat => txf_head,
      rx_we => rt0_rxwe, rx_wdat => rt0_rxdat,
      rx_sa => rt0_rxsa, rx_bcast => rt0_rxbc,
      ev_cmd => rt0_evc, ev_ok => rt0_evok, ev_err => rt0_everr,
      dbg_me => rt0_me, dbg_bcr => rt0_bcr,
      bus_rx => bus_v, bus_tx => rt0_tx, bus_txen => rt0_txen);

  u_rt1 : entity work.m1553_rt_core
    port map (
      clk => clk, rst => rst, en => en_i, rt_addr => rt1a_r,
      tx_rd => rt1_txrd, tx_wdat => txf_head,
      rx_we => rt1_rxwe, rx_wdat => rt1_rxdat,
      rx_sa => rt1_rxsa, rx_bcast => rt1_rxbc,
      ev_cmd => rt1_evc, ev_ok => rt1_evok, ev_err => rt1_everr,
      dbg_me => rt1_me, dbg_bcr => rt1_bcr,
      bus_rx => bus_v, bus_tx => rt1_tx, bus_txen => rt1_txen);

  -- --------------------------------------------------------------- vista STAT
  stat_v(0)            <= bc_busy;
  stat_v(3 downto 1)   <= (others => '0');
  stat_v(4)            <= txf_empty;
  stat_v(5)            <= txf_full;
  stat_v(6)            <= rxf_empty;
  stat_v(7)            <= rxf_full;
  stat_v(14 downto 8)  <= rxf_level;
  stat_v(15)           <= '0';
  stat_v(27 downto 16) <= stk;
  stat_v(31 downto 28) <= (others => '0');

  -- --------------------------------------------- rdata COMBINACIONAL (contrato)
  rdata <=
    (31 downto 2 => '0') & ctrl_r                                   when sel_ctrl   = '1' else
    (31 downto 13 => '0') & rt1a_r & "000" & rt0a_r                 when sel_rtad   = '1' else
    (31 downto 27 => '0') & msg_r                                   when sel_msg    = '1' else
    stat_v                                                          when sel_stat   = '1' else
    (31 downto 9 => '0') & txf_full & '0' & txf_level               when sel_txd    = '1' else
    (not rxf_empty) & (30 downto 24 => '0') &
      rxf_head(0) & rxf_head(5 downto 1) & rxf_head(7 downto 6) & rxf_head(23 downto 8)
                                                                   when sel_rxd    = '1' else
    irqen_r                                                         when sel_irqen  = '1' else
    stat2_r & stat1_r                                              when sel_result = '1' else
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
      ctrl_r  <= (others => '0');
      rt0a_r  <= "00101";
      rt1a_r  <= "01001";
      irqen_r <= (others => '0');
      msg_r   <= (others => '0');
      stat1_r <= (others => '0');
      stat2_r <= (others => '0');
      stk     <= (others => '0');
      txf_clr <= '0';
      rxf_clr <= '0';
    elsif rising_edge(clk) then
      wr := (sel = '1') and (we = '1');

      -- pulsos por defecto
      txf_clr <= not en_i;                 -- EN=0: FIFOs en limpieza continua
      rxf_clr <= not en_i;

      -- escrituras de registros
      if wr then
        if sel_ctrl = '1' then
          ctrl_r <= wdata(1 downto 0);
        elsif sel_rtad = '1' then
          rt0a_r <= wdata(4 downto 0);
          rt1a_r <= wdata(12 downto 8);
        elsif sel_cmd = '1' then
          if wdata(0) = '1' then txf_clr <= '1'; end if;
          if wdata(1) = '1' then rxf_clr <= '1'; end if;
        elsif sel_msg = '1' then
          msg_r <= wdata(26 downto 0);
        elsif sel_irqen = '1' then
          irqen_r <= wdata;
        elsif sel_stat = '1' then
          stk <= (others => '0');           -- limpiar stickies...
        end if;
      end if;

      -- serializador de escrituras RX simultaneas (broadcast RT0+RT1)
      skid_v <= '0';
      if rt0_rxwe = '1' and rt1_rxwe = '1' then
        skid_v <= '1';
        skid_d <= rt1_rxdat & "10" & rt1_rxsa & rt1_rxbc;
      end if;

      -- captura de resultados del BC
      if bc_done = '1' then
        stat1_r <= bc_s1;
        stat2_r <= bc_s2;
      end if;

      -- ...y los sets del mismo ciclo GANAN
      if bc_done  = '1' then stk(0) <= '1'; end if;   -- DONE
      if bc_done = '1' and bc_ok   = '1' then stk(1) <= '1'; end if;  -- OK
      if bc_done = '1' and bc_tout = '1' then stk(2) <= '1'; end if;  -- TOUT
      if bc_done = '1' and bc_serr = '1' then stk(3) <= '1'; end if;  -- SERR
      if bc_done = '1' and bc_me   = '1' then stk(4) <= '1'; end if;  -- MSG_ME
      if rt0_evc  = '1' then stk(5) <= '1'; end if;   -- RT0_CMD
      if rt1_evc  = '1' then stk(6) <= '1'; end if;   -- RT1_CMD
      if rt0_everr = '1' then stk(7) <= '1'; end if;  -- RT0_ERR
      if rt1_everr = '1' then stk(8) <= '1'; end if;  -- RT1_ERR
      -- RXF_OVF: escritura perdida por FIFO lleno (la del skid cuenta si se
      -- pierde con el FIFO lleno; la colision en si no es overflow)
      if (bc_rxwe or rt0_rxwe or rt1_rxwe or skid_v) = '1' and rxf_full = '1' then
        stk(9) <= '1';
      end if;
      if rt0_bcr = '1' then stk(10) <= '1'; end if;   -- RT0_BCR
      if rt1_bcr = '1' then stk(11) <= '1'; end if;   -- RT1_BCR
    end if;
  end process regs;

end architecture rtl;
