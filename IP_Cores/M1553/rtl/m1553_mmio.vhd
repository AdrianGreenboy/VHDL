-- ============================================================================
-- m1553_mmio.vhd -- IP MIL-STD-1553B completo con banco de registros MMIO
-- ============================================================================
-- Region 0xC000_0000 (decode addr[31:28]="1100" en mem_subsys; aqui llegan
-- los bits bajos). Contrato del bus dmem del RV32: sel de 1 ciclo, rdata
-- COMBINACIONAL en el mismo ciclo, pop-on-read.
--
-- Envuelve UN Bus Controller y DOS Remote Terminals (RT0, RT1) sobre DOS
-- buses redundantes A/B (dual-redundant MIL-STD-1553B), internos y
-- resueltos por tx_en en LOOP_INT, mas un FIFO TX de datos (16 b, comun:
-- quien transmite lo drena) y un FIFO RX de 24 b (dato + fuente/subaddr/
-- bcast). Ambos FIFOs son m1553_fifo (lectura registrada + prefetch FWFT).
--
-- Semanticas (audit 2026-11):
--   - STAT: stickies (b16..b28) are WRITE-1-TO-CLEAR per bit; a set in the
--     same cycle WINS over the clear. Writing 0xFFFFFFFF clears all.
--   - IRQ por NIVEL sin ack: irq = or(STAT and IRQEN) (registrado).
--   - EN=0: nucleos y FIFOs en reset/limpieza continua. EN 1->0->1 is also
--     the only way to clear a tripped fail-safe transmitter timer.
--   - CMD: escritura pulsa TX_FLUSH/RX_FLUSH/GO.
--   - LOOP_INT: buses A y B internos entre BC/RT0/RT1, pads liberados.
--   - BC: MSG.BUS selects the bus of each message. RTs listen on both buses
--     and answer on the bus of the command (superseding command on the
--     other bus aborts the current response).
--   - RX FIFO writes from BC, RT0 and RT1 in the same cycle (broadcast, or
--     RT->RT where the BC monitors the data the receiving RT stores) are
--     serialized by a 4-entry write queue: nothing is lost unless the FIFO
--     itself is full (RXF_OVF).
--   - Reset: synchronous, active high, everywhere.
--
-- Mapa (offsets de palabra, addr(7:2)):
--   0x00 CTRL    RW  b0 EN, b1 LOOP_INT
--   0x04 RTADDR  RW  b4:0 addr RT0, b12:8 addr RT1
--   0x08 CMD     W1P b0 TX_FLUSH, b1 RX_FLUSH, b2 GO
--   0x0C MSG     RW  b0 RTRT, b1 F_TR, b6:2 F_RT, b11:7 F_SA, b16:12 F_WC,
--                    b21:17 F2_RT, b26:22 F2_SA, b27 BUS (0 = A, 1 = B)
--   0x10 STAT    R   b0 BC_BUSY, b1 FS_FAULT (any fail-safe timer tripped),
--                    b2 BC_BUS (bus of the current/last BC message),
--                    b3 <res>, b4 TXF_EMPTY, b5 TXF_FULL,
--                    b6 RXF_EMPTY, b7 RXF_FULL, b14:8 rxf_level;
--                    stickies b16 DONE, b17 OK, b18 TOUT, b19 SERR, b20 MSG_ME,
--                    b21 RT0_CMD, b22 RT1_CMD, b23 RT0_ERR, b24 RT1_ERR,
--                    b25 RXF_OVF, b26 RT0_BCR, b27 RT1_BCR, b28 TX_UFLOW
--                W   write-1-to-clear stickies (sets del mismo ciclo ganan)
--   0x14 TXD     W   b15:0 data word al FIFO TX;  R b6:0 level, b8 full
--   0x18 RXD     R   pop-on-read b15:0 dato, b17:16 fuente, b22:18 subaddr,
--                    b23 bcast, b31 VALID
--   0x1C IRQEN   RW  mascara sobre STAT
--   0x20 RESULT  R   b15:0 stat1, b31:16 stat2
--   0x24 RTFLAGS RW  status-word flags: b0 RT0_BUSY, b1 RT0_SSF, b2 RT0_TF,
--                    b8 RT1_BUSY, b9 RT1_SSF, b10 RT1_TF
--   0x28 RTBUS   R   b0 RT0 bus of last command, b1 RT1 bus of last command,
--                    b4 FS_BC, b5 FS_RT0, b6 FS_RT1 (fail-safe tripped)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m1553_mmio is
  generic (
    FS_TIMEOUT : integer := 80000              -- fail-safe timer (cycles)
  );
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
    -- enlace fisico dual-redundante (en LOOP_INT no se usa)
    bus_rx_a_i   : in  std_logic;
    bus_tx_a_o   : out std_logic;
    bus_txen_a_o : out std_logic;
    bus_rx_b_i   : in  std_logic;
    bus_tx_b_o   : out std_logic;
    bus_txen_b_o : out std_logic
  );
end entity m1553_mmio;

architecture rtl of m1553_mmio is

  -- registros
  signal ctrl_r   : std_logic_vector(1 downto 0)  := (others => '0');
  signal rt0a_r   : std_logic_vector(4 downto 0)  := "00101";
  signal rt1a_r   : std_logic_vector(4 downto 0)  := "01001";
  signal irqen_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal msg_r    : std_logic_vector(27 downto 0) := (others => '0');
  signal stat1_r, stat2_r : std_logic_vector(15 downto 0) := (others => '0');
  signal rtfl_r   : std_logic_vector(10 downto 0) := (others => '0');

  signal en_i, loop_i : std_logic;

  -- stickies b28:16 (13 bits)
  signal stk : std_logic_vector(12 downto 0) := (others => '0');

  -- decode
  signal sel_ctrl, sel_rtad, sel_cmd, sel_msg, sel_stat : std_logic;
  signal sel_txd, sel_rxd, sel_irqen, sel_result        : std_logic;
  signal sel_rtfl, sel_rtbus                            : std_logic;

  -- BC
  signal bc_go     : std_logic;
  signal bc_busy, bc_done, bc_ok, bc_tout, bc_serr, bc_me, bc_uf : std_logic;
  signal bc_bus, bc_fs : std_logic;
  signal bc_s1, bc_s2 : std_logic_vector(15 downto 0);
  signal bc_txrd   : std_logic;
  signal bc_rxwe   : std_logic;
  signal bc_rxdat  : std_logic_vector(15 downto 0);
  signal bc_tx, bc_txen_a, bc_txen_b : std_logic;

  -- RTs
  signal rt0_txrd, rt0_rxwe, rt0_evc, rt0_evok, rt0_everr, rt0_uf : std_logic;
  signal rt0_rxdat : std_logic_vector(15 downto 0);
  signal rt0_rxsa  : std_logic_vector(4 downto 0);
  signal rt0_rxbc, rt0_bcr, rt0_me, rt0_bus, rt0_fs : std_logic;
  signal rt0_tx, rt0_txen_a, rt0_txen_b : std_logic;

  signal rt1_txrd, rt1_rxwe, rt1_evc, rt1_evok, rt1_everr, rt1_uf : std_logic;
  signal rt1_rxdat : std_logic_vector(15 downto 0);
  signal rt1_rxsa  : std_logic_vector(4 downto 0);
  signal rt1_rxbc, rt1_bcr, rt1_me, rt1_bus, rt1_fs : std_logic;
  signal rt1_tx, rt1_txen_a, rt1_txen_b : std_logic;

  -- buses internos / externos
  signal bus_a_v, bus_b_v, any_a, any_b : std_logic;

  -- FIFO TX (16 b) y su drenaje comun
  signal txf_clr, txf_wr, txf_rd, txf_empty, txf_full : std_logic;
  signal txf_head : std_logic_vector(15 downto 0);
  signal txf_level : std_logic_vector(6 downto 0);

  -- FIFO RX (24 b: dato(16) + fuente(2) + subaddr(5) + bcast(1))
  signal rxf_clr, rxf_wr, rxf_rd, rxf_empty, rxf_full : std_logic;
  signal rxf_wdata, rxf_head : std_logic_vector(23 downto 0);
  signal rxf_level : std_logic_vector(6 downto 0);

  -- RX write queue (serializes up to 3 same-cycle writers)
  type wq_t is array (0 to 3) of std_logic_vector(23 downto 0);
  signal wq   : wq_t := (others => (others => '0'));
  signal wq_n : integer range 0 to 4 := 0;

  signal stat_v : std_logic_vector(31 downto 0);
  signal fs_any : std_logic;

begin

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
  sel_rtfl   <= '1' when addr(7 downto 2) = "001001" else '0';
  sel_rtbus  <= '1' when addr(7 downto 2) = "001010" else '0';

  bc_go <= sel and we and sel_cmd and wdata(2);

  -- ------------------------------------------- resolucion de los buses A / B
  any_a <= bc_txen_a or rt0_txen_a or rt1_txen_a;
  any_b <= bc_txen_b or rt0_txen_b or rt1_txen_b;

  bus_a_v <= bc_tx  when bc_txen_a  = '1' else
             rt0_tx when rt0_txen_a = '1' else
             rt1_tx when rt1_txen_a = '1' else
             bus_rx_a_i when loop_i = '0' else
             '0';
  bus_b_v <= bc_tx  when bc_txen_b  = '1' else
             rt0_tx when rt0_txen_b = '1' else
             rt1_tx when rt1_txen_b = '1' else
             bus_rx_b_i when loop_i = '0' else
             '0';

  bus_tx_a_o   <= bus_a_v when any_a = '1' else '0';
  bus_txen_a_o <= any_a and (not loop_i);
  bus_tx_b_o   <= bus_b_v when any_b = '1' else '0';
  bus_txen_b_o <= any_b and (not loop_i);

  -- ------------------------------------------------------------------- FIFOs
  txf_wr <= sel and we and sel_txd and (not txf_full);
  txf_rd <= bc_txrd or rt0_txrd or rt1_txrd;      -- solo uno transmite a la vez
  rxf_rd <= sel and (not we) and sel_rxd and (not rxf_empty);

  u_txf : entity work.m1553_fifo
    generic map (LOG2_DEPTH => 6, WIDTH => 16)
    port map (
      clk => clk, rst => rst, clr => txf_clr,
      wr_en => txf_wr, wdata => wdata(15 downto 0),
      rd_en => txf_rd, rdata => txf_head,
      empty => txf_empty, full => txf_full, level => txf_level);

  u_rxf : entity work.m1553_fifo
    generic map (LOG2_DEPTH => 6, WIDTH => 24)
    port map (
      clk => clk, rst => rst, clr => rxf_clr,
      wr_en => rxf_wr, wdata => rxf_wdata,
      rd_en => rxf_rd, rdata => rxf_head,
      empty => rxf_empty, full => rxf_full, level => rxf_level);

  -- --------------------------------------------------------------- nucleos
  u_bc : entity work.m1553_bc_core
    generic map (FS_TIMEOUT => FS_TIMEOUT)
    port map (
      clk => clk, rst => rst, en => en_i,
      go => bc_go, rtrt => msg_r(0),
      f_rt => msg_r(6 downto 2), f_tr => msg_r(1),
      f_sa => msg_r(11 downto 7), f_wc => msg_r(16 downto 12),
      f2_rt => msg_r(21 downto 17), f2_sa => msg_r(26 downto 22),
      f_bus => msg_r(27),
      busy => bc_busy, done => bc_done,
      r_ok => bc_ok, r_tout => bc_tout, r_serr => bc_serr, r_me => bc_me,
      r_uflow => bc_uf, m_bus_o => bc_bus, fs_fault => bc_fs,
      stat1 => bc_s1, stat2 => bc_s2,
      tx_rd => bc_txrd, tx_wdat => txf_head, tx_empty => txf_empty,
      rx_we => bc_rxwe, rx_wdat => bc_rxdat,
      bus_rx_a => bus_a_v, bus_rx_b => bus_b_v, bus_tx => bc_tx,
      bus_txen_a => bc_txen_a, bus_txen_b => bc_txen_b);

  u_rt0 : entity work.m1553_rt_core
    generic map (FS_TIMEOUT => FS_TIMEOUT)
    port map (
      clk => clk, rst => rst, en => en_i, rt_addr => rt0a_r,
      st_busy => rtfl_r(0), st_ssf => rtfl_r(1), st_tf => rtfl_r(2),
      tx_rd => rt0_txrd, tx_wdat => txf_head, tx_empty => txf_empty,
      rx_we => rt0_rxwe, rx_wdat => rt0_rxdat,
      rx_sa => rt0_rxsa, rx_bcast => rt0_rxbc,
      ev_cmd => rt0_evc, ev_ok => rt0_evok, ev_err => rt0_everr,
      ev_uflow => rt0_uf,
      dbg_me => rt0_me, dbg_bcr => rt0_bcr,
      cur_bus => rt0_bus, fs_fault => rt0_fs,
      bus_rx_a => bus_a_v, bus_rx_b => bus_b_v, bus_tx => rt0_tx,
      bus_txen_a => rt0_txen_a, bus_txen_b => rt0_txen_b);

  u_rt1 : entity work.m1553_rt_core
    generic map (FS_TIMEOUT => FS_TIMEOUT)
    port map (
      clk => clk, rst => rst, en => en_i, rt_addr => rt1a_r,
      st_busy => rtfl_r(8), st_ssf => rtfl_r(9), st_tf => rtfl_r(10),
      tx_rd => rt1_txrd, tx_wdat => txf_head, tx_empty => txf_empty,
      rx_we => rt1_rxwe, rx_wdat => rt1_rxdat,
      rx_sa => rt1_rxsa, rx_bcast => rt1_rxbc,
      ev_cmd => rt1_evc, ev_ok => rt1_evok, ev_err => rt1_everr,
      ev_uflow => rt1_uf,
      dbg_me => rt1_me, dbg_bcr => rt1_bcr,
      cur_bus => rt1_bus, fs_fault => rt1_fs,
      bus_rx_a => bus_a_v, bus_rx_b => bus_b_v, bus_tx => rt1_tx,
      bus_txen_a => rt1_txen_a, bus_txen_b => rt1_txen_b);

  -- --------------------------------------------------------------- vista STAT
  fs_any <= bc_fs or rt0_fs or rt1_fs;

  stat_v(0)            <= bc_busy;
  stat_v(1)            <= fs_any;
  stat_v(2)            <= bc_bus;
  stat_v(3)            <= '0';
  stat_v(4)            <= txf_empty;
  stat_v(5)            <= txf_full;
  stat_v(6)            <= rxf_empty;
  stat_v(7)            <= rxf_full;
  stat_v(14 downto 8)  <= rxf_level;
  stat_v(15)           <= '0';
  stat_v(28 downto 16) <= stk;
  stat_v(31 downto 29) <= (others => '0');

  -- --------------------------------------------- rdata COMBINACIONAL (contrato)
  rdata <=
    (31 downto 2 => '0') & ctrl_r                                   when sel_ctrl   = '1' else
    (31 downto 13 => '0') & rt1a_r & "000" & rt0a_r                 when sel_rtad   = '1' else
    (31 downto 28 => '0') & msg_r                                   when sel_msg    = '1' else
    stat_v                                                          when sel_stat   = '1' else
    (31 downto 9 => '0') & txf_full & '0' & txf_level               when sel_txd    = '1' else
    (not rxf_empty) & (30 downto 24 => '0') &
      rxf_head(0) & rxf_head(5 downto 1) & rxf_head(7 downto 6) & rxf_head(23 downto 8)
                                                                   when sel_rxd    = '1' else
    irqen_r                                                         when sel_irqen  = '1' else
    stat2_r & stat1_r                                              when sel_result = '1' else
    (31 downto 11 => '0') & rtfl_r                                  when sel_rtfl   = '1' else
    (31 downto 7 => '0') & rt1_fs & rt0_fs & bc_fs & "00" & rt1_bus & rt0_bus
                                                                   when sel_rtbus  = '1' else
    (others => '0');

  -- ----------------------------------------------------------- IRQ por nivel
  irq_p : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        irq <= '0';
      else
        irq <= or (stat_v and irqen_r);
      end if;
    end if;
  end process irq_p;

  -- ------------------------------------------- cola de escrituras del FIFO RX
  -- Each source writes at most once per received word (>= 20 us apart), so
  -- a 4-entry queue drained one entry per cycle can never overflow.
  wq_p : process (clk)
    variable vq : wq_t;
    variable vn : integer range 0 to 4;
  begin
    if rising_edge(clk) then
      if rst = '1' or rxf_clr = '1' then
        wq_n   <= 0;
        rxf_wr <= '0';
      else
        vq := wq;
        vn := wq_n;
        rxf_wr <= '0';
        if vn > 0 then                            -- one write per cycle
          rxf_wr    <= '1';
          rxf_wdata <= vq(0);
          vq(0 to 2) := vq(1 to 3);
          vn := vn - 1;
        end if;
        if rt0_rxwe = '1' and vn < 4 then
          vq(vn) := rt0_rxdat & "01" & rt0_rxsa & rt0_rxbc;
          vn := vn + 1;
        end if;
        if rt1_rxwe = '1' and vn < 4 then
          vq(vn) := rt1_rxdat & "10" & rt1_rxsa & rt1_rxbc;
          vn := vn + 1;
        end if;
        if bc_rxwe = '1' and vn < 4 then
          vq(vn) := bc_rxdat & "00" & "00000" & '0';
          vn := vn + 1;
        end if;
        wq   <= vq;
        wq_n <= vn;
      end if;
    end if;
  end process wq_p;

  -- ------------------------------------------------------ registros y stickies
  regs : process (clk)
    variable wr : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ctrl_r  <= (others => '0');
        rt0a_r  <= "00101";
        rt1a_r  <= "01001";
        irqen_r <= (others => '0');
        msg_r   <= (others => '0');
        stat1_r <= (others => '0');
        stat2_r <= (others => '0');
        rtfl_r  <= (others => '0');
        stk     <= (others => '0');
        txf_clr <= '1';
        rxf_clr <= '1';
      else
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
            msg_r <= wdata(27 downto 0);
          elsif sel_irqen = '1' then
            irqen_r <= wdata;
          elsif sel_rtfl = '1' then
            rtfl_r <= wdata(10 downto 8) & "00000" & wdata(2 downto 0);
          elsif sel_stat = '1' then
            -- W1C per bit...
            stk <= stk and not wdata(28 downto 16);
          end if;
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
        -- RXF_OVF: write lost because the FIFO is full
        if rxf_wr = '1' and rxf_full = '1' then
          stk(9) <= '1';
        end if;
        if rt0_bcr = '1' then stk(10) <= '1'; end if;   -- RT0_BCR
        if rt1_bcr = '1' then stk(11) <= '1'; end if;   -- RT1_BCR
        if (bc_done = '1' and bc_uf = '1') or rt0_uf = '1' or rt1_uf = '1' then
          stk(12) <= '1';                               -- TX_UFLOW
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
