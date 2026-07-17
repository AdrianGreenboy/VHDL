-- rf_dma_axi.vhd - Segundo maestro AXI del RF (Paso 7, silicio).
-- Drena la RX FIFO del datapath RF hacia la DDR por su PROPIO puerto m_axi
-- (conectado a S07_AXI del NoC; el arbitraje lo hace el NoC). Envuelve el motor
-- reusable axi4_master de la familia: por cada palabra de la FIFO emite una
-- transaccion de escritura de un beat (req/we/addr/wdata) hacia DDR, con la
-- direccion incrementando en 4. El troceo en frontera de 4KB no hace falta aqui
-- porque cada beat es una transaccion independiente de una sola palabra (el NoC
-- nunca ve una rafaga que cruce 4KB). Disparo por flanco de subida de ctrl(0).
--
-- Registros de control (del banco rf_regs, dominio RF 0x6000_0000):
--   dma_addr : direccion base DDR (32 bits bajos; se extiende a ADDR_W con
--              ddr_base para el espacio del NoC).
--   dma_len  : numero de palabras a transferir.
--   dma_ctrl : bit0 = start (flanco de subida dispara).
-- Estados: X_IDLE -> X_POP (lee frente FIFO) -> X_WR (escribe beat AXI) -> ...
-- Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_dma_axi is
  generic (
    ADDR_W : natural := 40
  );
  port (
    clk       : in  std_logic;
    aresetn   : in  std_logic;
    ddr_base  : in  std_logic_vector(ADDR_W-1 downto 0);

    -- control (del banco rf_regs)
    dma_addr_i : in  std_logic_vector(31 downto 0);
    dma_len_i  : in  std_logic_vector(31 downto 0);
    dma_ctrl_i : in  std_logic_vector(31 downto 0);
    busy_o     : out std_logic;
    done_o     : out std_logic;

    -- RX FIFO (lado de lectura)
    fifo_rd_en_o   : out std_logic;
    fifo_rd_data_i : in  std_logic_vector(31 downto 0);
    fifo_empty_i   : in  std_logic;

    -- maestro AXI4 propio (a S07_AXI del NoC)
    m_axi_awaddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    m_axi_araddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic
  );
end entity rf_dma_axi;

architecture rtl of rf_dma_axi is
  type state_t is (X_IDLE, X_POP, X_WAIT, X_WR, X_DONE);
  signal state    : state_t := X_IDLE;
  signal ddr_addr : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal words_left : unsigned(31 downto 0) := (others => '0');
  signal wdata_q  : std_logic_vector(31 downto 0) := (others => '0');
  signal ctrl_prev : std_logic := '0';
  signal start_edge : std_logic;

  -- interfaz de request al motor axi4_master
  signal a_req, a_we, a_done, a_busy : std_logic;
  signal a_addr : std_logic_vector(ADDR_W-1 downto 0);
  signal a_wdata : std_logic_vector(31 downto 0);
  signal a_wstrb : std_logic_vector(3 downto 0);
  signal a_rdata : std_logic_vector(31 downto 0);
begin

  start_edge <= dma_ctrl_i(0) and not ctrl_prev;
  busy_o <= '0' when state = X_IDLE else '1';

  u_axi : entity work.axi4_master
    generic map (ADDR_W => ADDR_W)
    port map (
      clk => clk, aresetn => aresetn,
      req => a_req, we => a_we, addr => a_addr, wdata => a_wdata, wstrb => a_wstrb,
      rdata => a_rdata, done => a_done, busy => a_busy,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready
    );

  a_we    <= '1';                 -- este maestro solo escribe
  a_wstrb <= "1111";
  a_addr  <= std_logic_vector(ddr_addr);
  a_wdata <= wdata_q;

  proc : process (clk, aresetn)
  begin
    if aresetn = '0' then
      state <= X_IDLE;
      ddr_addr <= (others => '0');
      words_left <= (others => '0');
      wdata_q <= (others => '0');
      ctrl_prev <= '0';
      fifo_rd_en_o <= '0';
      a_req <= '0';
      done_o <= '0';
    elsif rising_edge(clk) then
      ctrl_prev <= dma_ctrl_i(0);
      fifo_rd_en_o <= '0';
      a_req <= '0';
      done_o <= '0';

      case state is
        when X_IDLE =>
          if start_edge = '1' then
            -- base DDR del NoC + offset de 32 bits bajos del registro
            ddr_addr   <= unsigned(ddr_base) + resize(unsigned(dma_addr_i), ADDR_W);
            words_left <= unsigned(dma_len_i);
            if unsigned(dma_len_i) = 0 then
              state <= X_DONE;
            else
              state <= X_POP;
            end if;
          end if;

        when X_POP =>
          -- esperar a que haya dato; capturar el frente y hacer pop
          if fifo_empty_i = '0' then
            wdata_q <= fifo_rd_data_i;   -- frente combinacional
            fifo_rd_en_o <= '1';         -- pop este flanco
            state <= X_WAIT;
          end if;

        when X_WAIT =>
          -- un ciclo para que el pop propague y wdata_q este estable;
          -- lanzar la transaccion AXI de escritura de un beat
          a_req <= '1';
          state <= X_WR;

        when X_WR =>
          -- esperar el done del motor AXI (respuesta B recibida)
          if a_done = '1' then
            ddr_addr   <= ddr_addr + 4;
            words_left <= words_left - 1;
            if words_left = 1 then
              state <= X_DONE;
            else
              state <= X_POP;
            end if;
          end if;

        when X_DONE =>
          done_o <= '1';
          state <= X_IDLE;
      end case;
    end if;
  end process;

end architecture rtl;
