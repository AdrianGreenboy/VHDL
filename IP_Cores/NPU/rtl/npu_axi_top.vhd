-- HERCOSSNUX NPU - top de integracion AXI.
--
-- Une el npu_top verificado (Pasos 1-11) con el motor DMA (Paso 12) y el
-- esclavo AXI4 de registros (Paso 13).
--
-- Patron doorbell:
--   PS escribe pesos e imagen en DDR
--   PS escribe CTRL.load_weights -> el core trae W1,B1,W2,B2,W3,B3 de DDR
--   PS escribe CTRL.start        -> trae la imagen, infiere, escribe resultado
--   PS lee STATUS.done y recoge el resultado de DDR
--
-- El demultiplexor traduce el flujo plano de bytes del DMA a los puertos
-- we/addr/data del nucleo. Los bias son int32: se acumulan 4 bytes en little
-- endian y se escriben cuando llega el ultimo.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;
use work.npu_axi_pkg.all;

entity npu_axi_top is
  generic (
    G_ID_W : natural := 4
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- esclavo de registros
    s_awvalid : in  std_logic;
    s_awready : out std_logic;
    s_awaddr  : in  std_logic_vector(31 downto 0);
    s_awlen   : in  std_logic_vector(7 downto 0);
    s_awsize  : in  std_logic_vector(2 downto 0);
    s_awburst : in  std_logic_vector(1 downto 0);
    s_awid    : in  std_logic_vector(G_ID_W-1 downto 0);
    s_wvalid  : in  std_logic;
    s_wready  : out std_logic;
    s_wdata   : in  std_logic_vector(31 downto 0);
    s_wstrb   : in  std_logic_vector(3 downto 0);
    s_wlast   : in  std_logic;
    s_bvalid  : out std_logic;
    s_bready  : in  std_logic;
    s_bresp   : out std_logic_vector(1 downto 0);
    s_bid     : out std_logic_vector(G_ID_W-1 downto 0);
    s_arvalid : in  std_logic;
    s_arready : out std_logic;
    s_araddr  : in  std_logic_vector(31 downto 0);
    s_arlen   : in  std_logic_vector(7 downto 0);
    s_arsize  : in  std_logic_vector(2 downto 0);
    s_arburst : in  std_logic_vector(1 downto 0);
    s_arid    : in  std_logic_vector(G_ID_W-1 downto 0);
    s_rvalid  : out std_logic;
    s_rready  : in  std_logic;
    s_rdata   : out std_logic_vector(31 downto 0);
    s_rresp   : out std_logic_vector(1 downto 0);
    s_rlast   : out std_logic;
    s_rid     : out std_logic_vector(G_ID_W-1 downto 0);

    -- maestro hacia DDR
    m_arvalid : out std_logic;
    m_arready : in  std_logic;
    m_araddr  : out std_logic_vector(31 downto 0);
    m_arlen   : out std_logic_vector(7 downto 0);
    m_arsize  : out std_logic_vector(2 downto 0);
    m_arburst : out std_logic_vector(1 downto 0);
    m_rvalid  : in  std_logic;
    m_rready  : out std_logic;
    m_rdata   : in  std_logic_vector(31 downto 0);
    m_rresp   : in  std_logic_vector(1 downto 0);
    m_rlast   : in  std_logic;
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_awaddr  : out std_logic_vector(31 downto 0);
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_wdata   : out std_logic_vector(31 downto 0);
    m_wstrb   : out std_logic_vector(3 downto 0);
    m_wlast   : out std_logic;
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic;
    m_bresp   : in  std_logic_vector(1 downto 0)
  );
end entity npu_axi_top;

architecture rtl of npu_axi_top is

  -- registros
  signal reg_start, reg_loadw : std_logic;
  signal reg_base : std_logic_vector(31 downto 0);

  -- DMA
  signal dma_rd_start : std_logic := '0';
  signal dma_rd_addr  : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_rd_bytes : natural := 0;
  signal dma_rd_busy, dma_rd_done : std_logic;
  signal dma_out_we   : std_logic;
  signal dma_out_idx  : natural;
  signal dma_out_data : std_logic_vector(7 downto 0);

  signal dma_wr_start : std_logic := '0';
  signal dma_wr_addr  : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_wr_bytes : natural := 0;
  signal dma_wr_busy, dma_wr_done : std_logic;
  signal dma_in_idx   : natural;
  signal dma_in_data  : std_logic_vector(7 downto 0);
  signal dma_err      : std_logic;
  signal dma_errcode  : std_logic_vector(1 downto 0);

  -- puertos del nucleo
  signal img_we   : std_logic := '0';
  signal img_addr : unsigned(7 downto 0) := (others => '0');
  signal img_data : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal w1_we    : std_logic := '0';
  signal w1_addr  : unsigned(6 downto 0) := (others => '0');
  signal w1_data  : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b1_we    : std_logic := '0';
  signal b1_addr  : unsigned(2 downto 0) := (others => '0');
  signal b1_data  : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal w2_we    : std_logic := '0';
  signal w2_addr  : unsigned(10 downto 0) := (others => '0');
  signal w2_data  : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b2_we    : std_logic := '0';
  signal b2_addr  : unsigned(3 downto 0) := (others => '0');
  signal b2_data  : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal w3_we    : std_logic := '0';
  signal w3_addr  : unsigned(11 downto 0) := (others => '0');
  signal w3_data  : signed(C_DATA_W-1 downto 0) := (others => '0');
  signal b3_we    : std_logic := '0';
  signal b3_addr  : unsigned(3 downto 0) := (others => '0');
  signal b3_data  : signed(C_ACC_W-1 downto 0) := (others => '0');

  signal core_start : std_logic := '0';
  signal core_busy, core_done : std_logic;
  signal core_clase : unsigned(3 downto 0);
  signal p1_addr : unsigned(8 downto 0) := (others => '0');
  signal p1_data : signed(C_DATA_W-1 downto 0);
  signal p2_addr : unsigned(7 downto 0) := (others => '0');
  signal p2_data : signed(C_DATA_W-1 downto 0);
  signal lg_addr : unsigned(3 downto 0) := (others => '0');
  signal lg_data : signed(C_DATA_W-1 downto 0);

  -- FSM de orquestacion
  type t_state is (T_IDLE,
                   T_W1, T_B1, T_W2, T_B2, T_W3, T_B3, T_LOADED,
                   T_IMG, T_INFER, T_WRES, T_DONE);
  signal state : t_state := T_IDLE;

  -- destino actual del flujo de bytes del DMA
  type t_dest is (D_NONE, D_W1, D_B1, D_W2, D_B2, D_W3, D_B3, D_IMG);
  signal dest : t_dest := D_NONE;

  -- acumulador de bias (4 bytes little endian)
  signal bacc : std_logic_vector(31 downto 0) := (others => '0');

  signal busy_r  : std_logic := '0';
  signal done_r  : std_logic := '0';
  signal error_r : std_logic := '0';

  -- resultado a escribir: clase en el byte 0, logits en 1..10
  signal res_clase : std_logic_vector(7 downto 0) := (others => '0');

begin

  u_slv : entity work.npu_axi_slave
    generic map (G_ID_W => G_ID_W)
    port map (clk => clk, rst_n => rst_n,
      s_awvalid => s_awvalid, s_awready => s_awready, s_awaddr => s_awaddr,
      s_awlen => s_awlen, s_awsize => s_awsize, s_awburst => s_awburst,
      s_awid => s_awid,
      s_wvalid => s_wvalid, s_wready => s_wready, s_wdata => s_wdata,
      s_wstrb => s_wstrb, s_wlast => s_wlast,
      s_bvalid => s_bvalid, s_bready => s_bready, s_bresp => s_bresp,
      s_bid => s_bid,
      s_arvalid => s_arvalid, s_arready => s_arready, s_araddr => s_araddr,
      s_arlen => s_arlen, s_arsize => s_arsize, s_arburst => s_arburst,
      s_arid => s_arid,
      s_rvalid => s_rvalid, s_rready => s_rready, s_rdata => s_rdata,
      s_rresp => s_rresp, s_rlast => s_rlast, s_rid => s_rid,
      o_start => reg_start, o_loadw => reg_loadw, o_base => reg_base,
      i_busy => busy_r, i_done => done_r, i_error => error_r,
      i_clase => std_logic_vector(core_clase), i_errcode => dma_errcode);

  u_dma : entity work.npu_dma
    port map (clk => clk, rst_n => rst_n,
      rd_start => dma_rd_start, rd_addr => dma_rd_addr,
      rd_bytes => dma_rd_bytes, rd_busy => dma_rd_busy, rd_done => dma_rd_done,
      out_we => dma_out_we, out_idx => dma_out_idx, out_data => dma_out_data,
      wr_start => dma_wr_start, wr_addr => dma_wr_addr,
      wr_bytes => dma_wr_bytes, wr_busy => dma_wr_busy, wr_done => dma_wr_done,
      in_idx => dma_in_idx, in_data => dma_in_data,
      err_out => dma_err, errcode => dma_errcode,
      m_arvalid => m_arvalid, m_arready => m_arready, m_araddr => m_araddr,
      m_arlen => m_arlen, m_arsize => m_arsize, m_arburst => m_arburst,
      m_rvalid => m_rvalid, m_rready => m_rready, m_rdata => m_rdata,
      m_rresp => m_rresp, m_rlast => m_rlast,
      m_awvalid => m_awvalid, m_awready => m_awready, m_awaddr => m_awaddr,
      m_awlen => m_awlen, m_awsize => m_awsize, m_awburst => m_awburst,
      m_wvalid => m_wvalid, m_wready => m_wready, m_wdata => m_wdata,
      m_wstrb => m_wstrb, m_wlast => m_wlast,
      m_bvalid => m_bvalid, m_bready => m_bready, m_bresp => m_bresp);

  u_core : entity work.npu_top
    generic map (G_MUT => 0)
    port map (clk => clk, rst_n => rst_n,
      img_we => img_we, img_addr => img_addr, img_data => img_data,
      w1_we => w1_we, w1_addr => w1_addr, w1_data => w1_data,
      b1_we => b1_we, b1_addr => b1_addr, b1_data => b1_data,
      w2_we => w2_we, w2_addr => w2_addr, w2_data => w2_data,
      b2_we => b2_we, b2_addr => b2_addr, b2_data => b2_data,
      w3_we => w3_we, w3_addr => w3_addr, w3_data => w3_data,
      b3_we => b3_we, b3_addr => b3_addr, b3_data => b3_data,
      mult1_in => to_signed(5064654, C_MULT_W),
      mult2_in => to_signed(5353067, C_MULT_W),
      mult3_in => to_signed(4101566, C_MULT_W),
      start => core_start, busy => core_busy, done => core_done,
      p1_addr => p1_addr, p1_data => p1_data,
      p2_addr => p2_addr, p2_data => p2_data,
      lg_addr => lg_addr, lg_data => lg_data, clase => core_clase);

  -- El DMA pide bytes del resultado: byte 0 = clase, 1..10 = logits.
  -- lg_addr es combinacional desde dma_in_idx para que lg_data sea valido.
  lg_addr <= to_unsigned(dma_in_idx - 1, 4) when dma_in_idx >= 1 and dma_in_idx <= 10
             else (others => '0');
  dma_in_data <= res_clase when dma_in_idx = 0
                 else std_logic_vector(lg_data) when dma_in_idx <= 10
                 else (others => '0');

  -- ---- demultiplexor del flujo de bytes --------------------------------
  demux : process(clk)
    variable idx : natural;
    variable bsel : natural range 0 to 3;
  begin
    if rising_edge(clk) then
      img_we <= '0'; w1_we <= '0'; b1_we <= '0';
      w2_we  <= '0'; b2_we <= '0'; w3_we <= '0'; b3_we <= '0';

      if dma_out_we = '1' then
        idx  := dma_out_idx;
        bsel := idx mod 4;

        case dest is
          when D_W1 =>
            w1_addr <= to_unsigned(idx, 7);
            w1_data <= signed(dma_out_data);
            w1_we   <= '1';

          when D_W2 =>
            w2_addr <= to_unsigned(idx, 11);
            w2_data <= signed(dma_out_data);
            w2_we   <= '1';

          when D_W3 =>
            w3_addr <= to_unsigned(idx, 12);
            w3_data <= signed(dma_out_data);
            w3_we   <= '1';

          when D_IMG =>
            img_addr <= to_unsigned(idx, 8);
            img_data <= signed(dma_out_data);
            img_we   <= '1';

          when D_B1 | D_B2 | D_B3 =>
            -- int32 little endian: acumular y escribir con el ultimo byte
            bacc(8*bsel + 7 downto 8*bsel) <= dma_out_data;
            if bsel = 3 then
              case dest is
                when D_B1 =>
                  b1_addr <= to_unsigned(idx/4, 3);
                  b1_data <= signed(dma_out_data & bacc(23 downto 0));
                  b1_we   <= '1';
                when D_B2 =>
                  b2_addr <= to_unsigned(idx/4, 4);
                  b2_data <= signed(dma_out_data & bacc(23 downto 0));
                  b2_we   <= '1';
                when others =>
                  b3_addr <= to_unsigned(idx/4, 4);
                  b3_data <= signed(dma_out_data & bacc(23 downto 0));
                  b3_we   <= '1';
              end case;
            end if;

          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  -- ---- FSM de orquestacion ---------------------------------------------
  fsm : process(clk)

    procedure pedir (dst : t_dest; off : natural; n : natural) is
    begin
      dest         <= dst;
      dma_rd_addr  <= std_logic_vector(unsigned(reg_base) + to_unsigned(off, 32));
      dma_rd_bytes <= n;
      dma_rd_start <= '1';
    end procedure;

  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state <= T_IDLE; busy_r <= '0'; done_r <= '0'; error_r <= '0';
        dma_rd_start <= '0'; dma_wr_start <= '0'; core_start <= '0';
        dest <= D_NONE;
      else
        dma_rd_start <= '0';
        dma_wr_start <= '0';
        core_start   <= '0';

        if dma_err = '1' then
          error_r <= '1';
        end if;

        case state is

          when T_IDLE =>
            busy_r <= '0';
            if reg_loadw = '1' then
              busy_r <= '1'; done_r <= '0'; error_r <= '0';
              pedir(D_W1, C_OFF_W1, C_N_W1);
              state <= T_W1;
            elsif reg_start = '1' then
              busy_r <= '1'; done_r <= '0'; error_r <= '0';
              pedir(D_IMG, C_OFF_IMG, C_N_IMG);
              state <= T_IMG;
            end if;

          when T_W1 =>
            if dma_rd_done = '1' then
              pedir(D_B1, C_OFF_B1, C_N_B1*4);
              state <= T_B1;
            end if;

          when T_B1 =>
            if dma_rd_done = '1' then
              pedir(D_W2, C_OFF_W2, C_N_W2);
              state <= T_W2;
            end if;

          when T_W2 =>
            if dma_rd_done = '1' then
              pedir(D_B2, C_OFF_B2, C_N_B2*4);
              state <= T_B2;
            end if;

          when T_B2 =>
            if dma_rd_done = '1' then
              pedir(D_W3, C_OFF_W3, C_N_W3);
              state <= T_W3;
            end if;

          when T_W3 =>
            if dma_rd_done = '1' then
              pedir(D_B3, C_OFF_B3, C_N_B3*4);
              state <= T_B3;
            end if;

          when T_B3 =>
            if dma_rd_done = '1' then
              dest  <= D_NONE;
              state <= T_LOADED;
            end if;

          when T_LOADED =>
            busy_r <= '0';
            done_r <= '1';
            state  <= T_IDLE;

          when T_IMG =>
            if dma_rd_done = '1' then
              dest       <= D_NONE;
              core_start <= '1';
              state      <= T_INFER;
            end if;

          when T_INFER =>
            if core_done = '1' then
              res_clase    <= std_logic_vector(resize(core_clase, 8));
              dma_wr_addr  <= std_logic_vector(
                                unsigned(reg_base) + to_unsigned(C_OFF_RES, 32));
              dma_wr_bytes <= 16;
              dma_wr_start <= '1';
              state        <= T_WRES;
            end if;

          when T_WRES =>
            if dma_wr_done = '1' then
              state <= T_DONE;
            end if;

          when T_DONE =>
            busy_r <= '0';
            done_r <= '1';
            state  <= T_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
