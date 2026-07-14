-- ============================================================================
-- pcie_mmio.vhd -- PCIE IP v1
-- Periferico PCIe completo visto por el RV32: banco de registros MMIO +
-- FIFOs TX/RX + una instancia de pcie_node. El firmware:
--   1) escribe CONTROL.start para entrenar el enlace,
--   2) empuja bytes de un TLP por TX_DATA y marca TX_CTRL.push_last al final,
--   3) el nodo transmite el TLP; las respuestas (CplD) se capturan en RX FIFO,
--   4) el firmware lee STATUS/IRQ y drena RX_DATA.
--
-- CONTRATO dmem (identico a la familia):
--   req='1' con we/wstrb para escritura; rdata COMBINACIONAL para lectura.
--   El decode de region lo hace el SoC; aqui addr son offsets locales (7 bits).
--
-- rdata COMBINACIONAL: mux directo del registro seleccionado por addr. NO
-- registrar (bug de Layer 4 documentado).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_mmio_pkg.all;
use work.pcie_8b10b_pkg.all;
use work.pcie_tl_pkg.all;

entity pcie_mmio is
  generic (
    is_rc     : boolean := true;
    TIMEOUT_C : integer := 5000
  );
  port (
    clk      : in  std_logic;
    resetn   : in  std_logic;               -- reset async activo-bajo

    -- interfaz dmem
    req      : in  std_logic;
    we       : in  std_logic;
    addr     : in  std_logic_vector(6 downto 0);   -- offset local (128 bytes)
    wdata    : in  std_logic_vector(31 downto 0);
    wstrb    : in  std_logic_vector(3 downto 0);
    rdata    : out std_logic_vector(31 downto 0);   -- COMBINACIONAL

    -- IRQ hacia el RV32 (nivel)
    irq      : out std_logic;

    -- PIPE hacia el otro nodo (para LOOP_INT / silicio)
    pt_sym   : out work.pcie_8b10b_pkg.byte_t;
    pt_k     : out std_logic;
    pr_sym   : in  work.pcie_8b10b_pkg.byte_t;
    pr_k     : in  std_logic
  );
end entity;

architecture rtl of pcie_mmio is
  signal rst : std_logic;

  -- registros
  signal reg_control : std_logic_vector(31 downto 0) := (others=>'0');
  signal reg_irq_en  : std_logic_vector(31 downto 0) := (others=>'0');
  signal reg_irq_stat: std_logic_vector(31 downto 0) := (others=>'0');
  signal reg_msi_addr: std_logic_vector(31 downto 0) := (others=>'0');
  signal reg_msi_data: std_logic_vector(31 downto 0) := (others=>'0');

  -- nodo
  signal n_start, n_hotrst, n_msi : std_logic;
  signal n_req_v, n_req_l, n_req_rdy : std_logic;
  signal n_req_d : work.pcie_8b10b_pkg.byte_t;
  signal n_up : std_logic; signal n_state : std_logic_vector(3 downto 0);
  signal n_bar : dw_t;
  signal n_mwr, n_mrd, n_good, n_rpl : std_logic_vector(15 downto 0);
  signal n_tr_v, n_tr_s, n_tr_l : std_logic; signal n_tr_d : work.pcie_8b10b_pkg.byte_t;
  signal n_rx_v, n_rx_s, n_rx_l : std_logic; signal n_rx_d : work.pcie_8b10b_pkg.byte_t;

  -- FIFO TX (firmware -> nodo)
  signal txf_wr, txf_full, txf_rd, txf_empty : std_logic;
  signal txf_wdata, txf_rdata : std_logic_vector(7 downto 0);
  signal txf_level : unsigned(9 downto 0);
  signal tx_push_last : std_logic := '0';
  -- marca de "ultimo byte" paralela a la FIFO (1 bit por entrada) via 2a FIFO
  signal txl_wr, txl_full, txl_rd, txl_empty : std_logic;
  signal txl_wdata, txl_rdata : std_logic_vector(7 downto 0);
  signal txl_level : unsigned(9 downto 0);

  -- FIFO RX (nodo -> firmware)
  signal rxf_wr, rxf_full, rxf_rd, rxf_empty : std_logic;
  signal rxf_wdata, rxf_rdata : std_logic_vector(7 downto 0);
  signal rxf_level : unsigned(9 downto 0);

  -- maquina de drenado TX: saca bytes de la FIFO hacia el nodo
  type txst_t is (TX_IDLE, TX_RUN);
  signal txst : txst_t := TX_IDLE;
  signal tlp_ready : integer range 0 to 255 := 0;   -- TLPs completos en la FIFO

  signal wr_hit : std_logic;
  signal a_idx  : integer;
begin
  rst <= not resetn;
  a_idx <= to_integer(unsigned(addr)) * 4;   -- addr es indice DW -> byte offset
  wr_hit <= req and we;

  -- ================= nodo PCIe =================
  u_node : entity work.pcie_node
    generic map (is_rc => is_rc, TIMEOUT_C => TIMEOUT_C)
    port map (clk=>clk, rst=>rst, en=>'1',
              cmd_start=>n_start, cmd_hotrst=>n_hotrst,
              pt_sym=>pt_sym, pt_k=>pt_k, pr_sym=>pr_sym, pr_k=>pr_k,
              req_valid=>n_req_v, req_data=>n_req_d, req_last=>n_req_l,
              req_ready=>n_req_rdy, msi_trigger=>n_msi,
              link_up=>n_up, ltssm_state=>n_state, bar0_dbg=>n_bar,
              mwr_cnt=>n_mwr, mrd_cnt=>n_mrd, good_rx=>n_good, replays=>n_rpl,
              tlresp_valid=>n_tr_v, tlresp_data=>n_tr_d,
              tlresp_start=>n_tr_s, tlresp_last=>n_tr_l,
              rxtlp_valid=>n_rx_v, rxtlp_data=>n_rx_d,
              rxtlp_start=>n_rx_s, rxtlp_last=>n_rx_l);

  n_start  <= reg_control(C_START);
  n_hotrst <= reg_control(C_HOTRST);

  -- ================= FIFOs =================
  u_txfifo : entity work.byte_fifo
    generic map (LOG2_DEPTH => 9)
    port map (clk=>clk, aresetn=>resetn, wr_en=>txf_wr, wr_data=>txf_wdata,
              full=>txf_full, rd_en=>txf_rd, rd_data=>txf_rdata,
              empty=>txf_empty, level=>txf_level);
  u_txlast : entity work.byte_fifo
    generic map (LOG2_DEPTH => 9)
    port map (clk=>clk, aresetn=>resetn, wr_en=>txl_wr, wr_data=>txl_wdata,
              full=>txl_full, rd_en=>txl_rd, rd_data=>txl_rdata,
              empty=>txl_empty, level=>txl_level);
  u_rxfifo : entity work.byte_fifo
    generic map (LOG2_DEPTH => 9)
    port map (clk=>clk, aresetn=>resetn, wr_en=>rxf_wr, wr_data=>rxf_wdata,
              full=>rxf_full, rd_en=>rxf_rd, rd_data=>rxf_rdata,
              empty=>rxf_empty, level=>rxf_level);

  -- escritura en la FIFO TX: cuando el firmware escribe REG_TX_DATA
  txf_wdata <= wdata(7 downto 0);
  txf_wr <= '1' when (wr_hit='1' and a_idx=work.pcie_mmio_pkg.REG_TX_DATA) else '0';
  -- la marca de last se empuja en paralelo: 0x01 si push_last, else 0x00.
  -- El firmware escribe REG_TX_DATA con el byte; para el ULTIMO byte, escribe
  -- ese byte y ademas pone bit push_last en los bits altos de wdata (wdata[8]).
  txl_wdata <= x"01" when wdata(8)='1' else x"00";
  txl_wr <= txf_wr;

  -- ================= drenado TX -> nodo =================
  -- Drenado como stream FWFT contiguo. Con el byte_fifo FWFT, rd_data muestra
  -- siempre el frente; 'valid' se mantiene alto durante todo el TLP (que ya
  -- esta COMPLETO en la FIFO gracias a tlp_ready). Al aceptar la DLL
  -- (n_req_rdy='1') se pulsa rd_en y el siguiente byte queda visible el mismo
  -- ciclo -> sin huecos entre bytes del TLP, requisito del framing PCIe.
  n_req_v <= '1' when (txst = TX_RUN and txf_empty = '0') else '0';
  n_req_d <= txf_rdata;
  n_req_l <= txl_rdata(0);
  txf_rd <= '1' when (txst = TX_RUN and txf_empty = '0' and n_req_rdy = '1') else '0';
  txl_rd <= txf_rd;

  process(clk, resetn)
  begin
    if resetn='0' then
      txst <= TX_IDLE;
      tlp_ready <= 0;
    elsif rising_edge(clk) then
      -- contabilidad de TLPs completos: +1 al escribir un 'last'
      if txf_wr='1' and wdata(8)='1' then
        tlp_ready <= tlp_ready + 1;
      end if;

      case txst is
        when TX_IDLE =>
          if tlp_ready > 0 then
            txst <= TX_RUN;              -- arranca: hay un TLP completo
          end if;
        when TX_RUN =>
          -- avanza mientras la DLL acepte; al drenar el 'last' cierra el TLP
          if txf_empty='0' and n_req_rdy='1' and txl_rdata(0)='1' then
            txst <= TX_IDLE;
            if not (txf_wr='1' and wdata(8)='1') then
              tlp_ready <= tlp_ready - 1;
            end if;
          end if;
        when others =>
          txst <= TX_IDLE;
      end case;
    end if;
  end process;

  -- ================= captura RX (nodo -> FIFO) =================
  -- Se capturan los TLPs RECIBIDOS del enlace (n_rx_*): en el RC son CplDs y
  -- otros TLPs entrantes que el firmware drena por REG_RX_DATA. (tlresp es la
  -- respuesta que genera el completer local; el datapath entrante es n_rx.)
  rxf_wdata <= n_rx_d;
  rxf_wr <= n_rx_v;
  rxf_rd <= '1' when (req='1' and we='0' and a_idx=work.pcie_mmio_pkg.REG_RX_DATA) else '0';

  -- ================= IRQ sticky =================
  process(clk, resetn)
  begin
    if resetn='0' then
      reg_irq_stat <= (others=>'0');
    elsif rising_edge(clk) then
      -- set por eventos
      if n_rx_v='1' and n_rx_s='1' then
        reg_irq_stat(I_CPL_RX) <= '1';
      end if;
      if n_msi='1' then reg_irq_stat(I_MSI_TX) <= '1'; end if;
      -- W1C: escribir 1 limpia el bit
      if wr_hit='1' and a_idx=work.pcie_mmio_pkg.REG_IRQ_STAT then
        for b in 0 to 3 loop
          if wdata(b)='1' then reg_irq_stat(b) <= '0'; end if;
        end loop;
      end if;
    end if;
  end process;

  irq <= '1' when (reg_irq_stat and reg_irq_en) /= x"00000000" else '0';

  -- ================= escritura de registros R/W =================
  process(clk, resetn)
  begin
    if resetn='0' then
      reg_control<=(others=>'0'); reg_irq_en<=(others=>'0');
      reg_msi_addr<=(others=>'0'); reg_msi_data<=(others=>'0');
      n_msi<='0';
    elsif rising_edge(clk) then
      n_msi<='0';
      if wr_hit='1' then
        case a_idx is
          when work.pcie_mmio_pkg.REG_CONTROL =>
            reg_control<=wdata;
            if wdata(C_MSITRIG)='1' then n_msi<='1'; end if;
          when work.pcie_mmio_pkg.REG_IRQ_EN   => reg_irq_en<=wdata;
          when work.pcie_mmio_pkg.REG_MSI_ADDR => reg_msi_addr<=wdata;
          when work.pcie_mmio_pkg.REG_MSI_DATA => reg_msi_data<=wdata;
          when others => null;
        end case;
      end if;
      -- auto-clear del bit de trigger (pulso)
      reg_control(C_MSITRIG)<='0';
    end if;
  end process;

  -- ================= rdata COMBINACIONAL =================
  process(a_idx, reg_control, n_up, n_state, reg_irq_stat, reg_irq_en,
          rxf_rdata, rxf_empty, rxf_level, txf_full, txf_level,
          n_bar, n_mwr, n_mrd, n_good, reg_msi_addr, reg_msi_data)
  begin
    case a_idx is
      when work.pcie_mmio_pkg.REG_CONTROL   => rdata <= reg_control;
      when work.pcie_mmio_pkg.REG_STATUS    =>
        rdata <= (others=>'0');
        rdata(S_LINKUP) <= n_up;
        rdata(7 downto 4) <= n_state;
      when work.pcie_mmio_pkg.REG_IRQ_STAT  => rdata <= reg_irq_stat;
      when work.pcie_mmio_pkg.REG_IRQ_EN    => rdata <= reg_irq_en;
      when work.pcie_mmio_pkg.REG_TX_CTRL   =>
        rdata <= (others=>'0');
        rdata(15 downto 8) <= std_logic_vector(txf_level(7 downto 0));
        rdata(16) <= txf_full;
      when work.pcie_mmio_pkg.REG_RX_DATA   =>
        rdata <= (others=>'0');
        rdata(7 downto 0) <= rxf_rdata;
      when work.pcie_mmio_pkg.REG_RX_CTRL   =>
        rdata <= (others=>'0');
        rdata(R_EMPTY) <= rxf_empty;
        rdata(15 downto 8) <= std_logic_vector(rxf_level(7 downto 0));
      when work.pcie_mmio_pkg.REG_BAR0_LAST => rdata <= n_bar;
      when work.pcie_mmio_pkg.REG_MWR_CNT   => rdata <= x"0000" & n_mwr;
      when work.pcie_mmio_pkg.REG_MRD_CNT   => rdata <= x"0000" & n_mrd;
      when work.pcie_mmio_pkg.REG_GOOD_RX   => rdata <= x"0000" & n_good;
      when work.pcie_mmio_pkg.REG_MSI_ADDR  => rdata <= reg_msi_addr;
      when work.pcie_mmio_pkg.REG_MSI_DATA  => rdata <= reg_msi_data;
      when work.pcie_mmio_pkg.REG_DBG_STATE =>
        rdata <= (others=>'0');
        rdata(3 downto 0) <= n_state;
        rdata(4) <= n_up;
        rdata(15 downto 8) <= std_logic_vector(rxf_level(7 downto 0));
      when others => rdata <= (others=>'0');
    end case;
  end process;

end architecture;
