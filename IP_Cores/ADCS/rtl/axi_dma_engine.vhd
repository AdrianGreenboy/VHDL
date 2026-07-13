-- ============================================================================
-- axi_dma_engine.vhd — DMA maestro AXI4-Full del IP ADCS (port de axi_dma_engine.sv).
--   OP_LOAD_H  (0): DP*DP palabras DDR(h_base)  -> h_bank (row,col incrementales)
--   OP_LOAD_G  (1): DP palabras   DDR(g_base)   -> g_bank
--   OP_STORE_U (2): DP palabras   u_bank(extRD) -> DDR(u_base)
--
-- 32-bit por beat, 1 outstanding (arlen/awlen=0). AxPROT=010 (unpriv,
-- NON-SECURE, data) y AxCACHE=0011: sin esto Vivado ata AxPROT a 000 (secure)
-- y las unidades de proteccion del NoC Versal descartan la transaccion sin
-- respuesta => deadlock (leccion de silicio de la tesis, preservada).
-- Indices (row,col) por contadores incrementales (no div/mod por 72, que
-- violaba timing).
--
-- Timing critico preservado del original: en STORE_U, u_ext_rd_data del u_bank
-- es REGISTRADO (latencia 1); u_ext_rd_addr se fija en IDLE/WRESP y el dato se
-- consume un ciclo despues en DMA_WDATA.
--
-- MUT (solo verificacion, 0 en uso normal):
--   1 = AxPROT=000 (secure): el BFM del NoC lo rechaza => timeout/deadlock
--   2 = beat termina en total (off-by-one): una palabra de mas
--   3 = STORE_U consume el dato sin esperar la latencia del u_bank (dato viejo)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;

entity axi_dma_engine is
  generic (
    AXI_ADDR_W : natural := 32;
    AXI_DATA_W : natural := 32;
    MUT        : natural := 0
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    -- comando
    cmd_valid  : in  std_logic;
    cmd_op     : in  std_logic_vector(1 downto 0);
    cmd_addr   : in  std_logic_vector(AXI_ADDR_W-1 downto 0);
    cmd_words  : in  std_logic_vector(15 downto 0);
    cmd_done   : out std_logic;
    cmd_busy   : out std_logic;
    dbg_st     : out std_logic_vector(3 downto 0);
    dbg_beat   : out std_logic_vector(15 downto 0);
    -- AXI4-Full master: read
    m_axi_araddr  : out std_logic_vector(AXI_ADDR_W-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arprot  : out std_logic_vector(2 downto 0);
    m_axi_arcache : out std_logic_vector(3 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(AXI_DATA_W-1 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;
    -- AXI4-Full master: write
    m_axi_awaddr  : out std_logic_vector(AXI_ADDR_W-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awprot  : out std_logic_vector(2 downto 0);
    m_axi_awcache : out std_logic_vector(3 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(AXI_DATA_W-1 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    -- BRAMs
    h_wr_en   : out std_logic;
    h_wr_row  : out std_logic_vector(IDX_W-1 downto 0);
    h_wr_col  : out std_logic_vector(IDX_W-1 downto 0);
    h_wr_data : out std_logic_vector(FP_W-1 downto 0);
    g_wr_en   : out std_logic;
    g_wr_addr : out std_logic_vector(IDX_W-1 downto 0);
    g_wr_data : out std_logic_vector(FP_W-1 downto 0);
    u_ext_rd_addr : out std_logic_vector(IDX_W-1 downto 0);
    u_ext_rd_data : in  std_logic_vector(FP_W-1 downto 0);
    lin_addr  : out std_logic_vector(15 downto 0)
  );
end entity axi_dma_engine;

architecture rtl of axi_dma_engine is
  constant OP_LOAD_H  : std_logic_vector(1 downto 0) := "00";
  constant OP_LOAD_G  : std_logic_vector(1 downto 0) := "01";
  constant OP_STORE_U : std_logic_vector(1 downto 0) := "10";

  type st_e is (DMA_IDLE, DMA_RADDR, DMA_RWAIT, DMA_RDATA,
                DMA_WADDR, DMA_WAWAIT, DMA_WDATA, DMA_WDWAIT, DMA_WRESP, DMA_FIN);
  signal st : st_e;

  signal op_q    : std_logic_vector(1 downto 0);
  signal base_q  : unsigned(AXI_ADDR_W-1 downto 0);
  signal beat    : unsigned(15 downto 0);
  signal total   : unsigned(15 downto 0);
  signal cur_row, cur_col : unsigned(IDX_W-1 downto 0);

  function st_code(s : st_e) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(st_e'pos(s), 4));
  end function;
begin

  cmd_busy <= '0' when st = DMA_IDLE else '1';
  dbg_st   <= st_code(st);
  dbg_beat <= std_logic_vector(beat);
  lin_addr <= std_logic_vector(beat);

  -- constantes AXI
  m_axi_arsize  <= "010";
  m_axi_awsize  <= "010";
  m_axi_arburst <= "01";
  m_axi_awburst <= "01";
  m_axi_arlen   <= (others => '0');
  m_axi_awlen   <= (others => '0');
  m_axi_arprot  <= "000" when MUT = 1 else "010";   -- MUT1: secure -> rechazo
  m_axi_awprot  <= "000" when MUT = 1 else "010";
  m_axi_arcache <= "0011";
  m_axi_awcache <= "0011";
  m_axi_wstrb   <= "1111";

  p_fsm : process (clk, rst_n)
    variable last_beat : unsigned(15 downto 0);
  begin
    if rst_n = '0' then
      st <= DMA_IDLE;
      cmd_done <= '0';
      beat <= (others => '0');  total <= (others => '0');
      cur_row <= (others => '0');  cur_col <= (others => '0');
      op_q <= (others => '0');  base_q <= (others => '0');
      m_axi_arvalid <= '0';  m_axi_rready <= '0';
      m_axi_awvalid <= '0';  m_axi_wvalid <= '0';  m_axi_wlast <= '0';
      m_axi_bready  <= '0';
      m_axi_araddr  <= (others => '0');  m_axi_awaddr <= (others => '0');
      m_axi_wdata   <= (others => '0');
      h_wr_en <= '0';  g_wr_en <= '0';
      h_wr_row <= (others => '0');  h_wr_col <= (others => '0');
      h_wr_data <= (others => '0');
      g_wr_addr <= (others => '0');  g_wr_data <= (others => '0');
      u_ext_rd_addr <= (others => '0');
    elsif rising_edge(clk) then
      cmd_done <= '0';
      h_wr_en  <= '0';
      g_wr_en  <= '0';

      -- total efectivo con MUT2 (una palabra de mas)
      case st is

        when DMA_IDLE =>
          if cmd_valid = '1' then
            op_q    <= cmd_op;
            base_q  <= unsigned(cmd_addr);
            beat    <= (others => '0');
            cur_row <= (others => '0');
            cur_col <= (others => '0');
            if cmd_op = OP_LOAD_H then
              if unsigned(cmd_words) /= 0 then
                total <= unsigned(cmd_words);
              else
                total <= to_unsigned(DP*DP, 16);
              end if;
              st <= DMA_RADDR;
            elsif cmd_op = OP_LOAD_G then
              if unsigned(cmd_words) /= 0 then
                total <= unsigned(cmd_words);
              else
                total <= to_unsigned(DP, 16);
              end if;
              st <= DMA_RADDR;
            elsif cmd_op = OP_STORE_U then
              if unsigned(cmd_words) /= 0 then
                total <= unsigned(cmd_words);
              else
                total <= to_unsigned(DP, 16);
              end if;
              u_ext_rd_addr <= (others => '0');
              st <= DMA_WADDR;
            else
              st <= DMA_FIN;
            end if;
          end if;

        -- LECTURA
        when DMA_RADDR =>
          m_axi_araddr  <= std_logic_vector(base_q + (beat & "00"));
          m_axi_arvalid <= '1';
          st            <= DMA_RWAIT;

        when DMA_RWAIT =>
          if m_axi_arready = '1' then
            m_axi_arvalid <= '0';
            m_axi_rready  <= '1';
            st            <= DMA_RDATA;
          end if;

        when DMA_RDATA =>
          if m_axi_rvalid = '1' and m_axi_rready = '1' then
            m_axi_rready <= '0';
            if op_q = OP_LOAD_H then
              h_wr_en   <= '1';
              h_wr_row  <= std_logic_vector(cur_row);
              h_wr_col  <= std_logic_vector(cur_col);
              h_wr_data <= m_axi_rdata;
            else
              g_wr_en   <= '1';
              g_wr_addr <= std_logic_vector(beat(IDX_W-1 downto 0));
              g_wr_data <= m_axi_rdata;
            end if;
            last_beat := total - 1;
            if MUT = 2 then last_beat := total; end if;
            if beat = last_beat then
              st <= DMA_FIN;
            else
              beat <= beat + 1;
              if cur_col = DP-1 then
                cur_col <= (others => '0');
                cur_row <= cur_row + 1;
              else
                cur_col <= cur_col + 1;
              end if;
              st <= DMA_RADDR;
            end if;
          end if;

        -- ESCRITURA (STORE_U)
        when DMA_WADDR =>
          m_axi_awaddr  <= std_logic_vector(base_q + (beat & "00"));
          m_axi_awvalid <= '1';
          st            <= DMA_WAWAIT;

        when DMA_WAWAIT =>
          if m_axi_awready = '1' then
            m_axi_awvalid <= '0';
            st            <= DMA_WDATA;
          end if;

        when DMA_WDATA =>
          -- u_ext_rd_data valido aqui (fijado en IDLE/WRESP, latencia 1).
          -- MUT3 lo consume igual pero salta el emparejamiento addr->dato.
          m_axi_wdata  <= u_ext_rd_data;
          m_axi_wvalid <= '1';
          m_axi_wlast  <= '1';
          st           <= DMA_WDWAIT;

        when DMA_WDWAIT =>
          if m_axi_wready = '1' then
            m_axi_wvalid <= '0';
            m_axi_wlast  <= '0';
            m_axi_bready <= '1';
            st           <= DMA_WRESP;
          end if;

        when DMA_WRESP =>
          if m_axi_bvalid = '1' and m_axi_bready = '1' then
            m_axi_bready <= '0';
            last_beat := total - 1;
            if MUT = 2 then last_beat := total; end if;
            if beat = last_beat then
              st <= DMA_FIN;
            else
              beat <= beat + 1;
              if MUT = 3 then
                u_ext_rd_addr <= std_logic_vector(beat(IDX_W-1 downto 0) + 2);
              else
                u_ext_rd_addr <= std_logic_vector(beat(IDX_W-1 downto 0) + 1);
              end if;
              st <= DMA_WADDR;
            end if;
          end if;

        when DMA_FIN =>
          cmd_done <= '1';
          st       <= DMA_IDLE;

      end case;
    end if;
  end process;

end architecture rtl;
