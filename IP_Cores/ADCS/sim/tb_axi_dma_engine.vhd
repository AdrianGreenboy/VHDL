-- ============================================================================
-- tb_axi_dma_engine.vhd — Capa 2 del IP ADCS: DMA vs modelo de memoria (BFM).
--
-- BFM AXI4-Full esclavo con memoria DDR simulada y BACKPRESSURE aleatoria pero
-- determinista (LFSR) en ar/aw/w/b/r: replica el punto donde vive el deadlock
-- resuelto en la tesis. Verifica:
--   LOAD_H : DDR -> h_bank, comprobado leyendo filas por el puerto ancho.
--   LOAD_G : DDR -> g_bank, comprobado por lecturas palabra a palabra.
--   STORE_U: u_bank -> DDR, comprobado contra los valores precargados en U.
-- El BFM tambien RECHAZA transacciones con AxPROT=000 (secure): un flag que
-- nunca se limpia => el tb detecta el deadlock por timeout (MUT=1).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.env.all;
use work.adcs_pkg.all;

entity tb_axi_dma_engine is
  generic (
    MUT : natural := 0
  );
end entity tb_axi_dma_engine;

architecture sim of tb_axi_dma_engine is
  constant TCLK : time := 4 ns;
  constant NW_H : natural := DP*DP;
  constant MEM_W : natural := 8192;

  signal clk, rst_n : std_logic := '0';

  signal cmd_valid : std_logic := '0';
  signal cmd_op    : std_logic_vector(1 downto 0) := (others => '0');
  signal cmd_addr  : std_logic_vector(31 downto 0) := (others => '0');
  signal cmd_words : std_logic_vector(15 downto 0) := (others => '0');
  signal cmd_done, cmd_busy : std_logic;
  signal dbg_st    : std_logic_vector(3 downto 0);
  signal dbg_beat  : std_logic_vector(15 downto 0);

  -- AXI master signals
  signal araddr : std_logic_vector(31 downto 0);
  signal arlen  : std_logic_vector(7 downto 0);
  signal arsize : std_logic_vector(2 downto 0);
  signal arburst: std_logic_vector(1 downto 0);
  signal arprot : std_logic_vector(2 downto 0);
  signal arcache: std_logic_vector(3 downto 0);
  signal arvalid, arready : std_logic;
  signal rdata_ax : std_logic_vector(31 downto 0);
  signal rresp  : std_logic_vector(1 downto 0);
  signal rlast, rvalid, rready : std_logic;
  signal awaddr : std_logic_vector(31 downto 0);
  signal awlen  : std_logic_vector(7 downto 0);
  signal awsize : std_logic_vector(2 downto 0);
  signal awburst: std_logic_vector(1 downto 0);
  signal awprot : std_logic_vector(2 downto 0);
  signal awcache: std_logic_vector(3 downto 0);
  signal awvalid, awready : std_logic;
  signal wdata_ax : std_logic_vector(31 downto 0);
  signal wstrb  : std_logic_vector(3 downto 0);
  signal wlast, wvalid, wready : std_logic;
  signal bresp  : std_logic_vector(1 downto 0);
  signal bvalid, bready : std_logic;

  -- bancos
  signal h_wr_en : std_logic;
  signal h_wr_row, h_wr_col : std_logic_vector(IDX_W-1 downto 0);
  signal h_wr_data : std_logic_vector(FP_W-1 downto 0);
  signal g_wr_en : std_logic;
  signal g_wr_addr : std_logic_vector(IDX_W-1 downto 0);
  signal g_wr_data : std_logic_vector(FP_W-1 downto 0);
  signal u_ext_rd_addr : std_logic_vector(IDX_W-1 downto 0);
  signal u_ext_rd_data : std_logic_vector(FP_W-1 downto 0);
  signal lin_addr : std_logic_vector(15 downto 0);

  -- puertos de lectura de bancos para verificacion
  signal h_rd_en : std_logic := '0';
  signal h_rd_row : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal h_row_data : std_logic_vector(D*FP_W-1 downto 0);
  signal g_rd_en : std_logic := '0';
  signal g_rd_addr : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal g_rd_data : std_logic_vector(FP_W-1 downto 0);
  -- u_bank: precarga por su puerto RW normal
  signal u_wr_en : std_logic := '0';
  signal u_wr_addr : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal u_wr_data : std_logic_vector(FP_W-1 downto 0) := (others => '0');
  signal u_rd_en  : std_logic := '0';
  signal u_snap   : std_logic := '0';
  signal u_vec_u  : std_logic_vector(D*FP_W-1 downto 0);

  -- memoria DDR del BFM (signal: el unico driver de escritura es el BFM)
  type ddr_t is array (0 to MEM_W-1) of std_logic_vector(31 downto 0);
  signal ddr : ddr_t := (others => (others => '0'));

  signal fin : boolean := false;

  function lfsr_next(s : std_logic_vector(15 downto 0)) return std_logic_vector is
  begin
    return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10));
  end function;
begin

  clk <= not clk after TCLK/2 when not fin else '0';

  dut : entity work.axi_dma_engine
    generic map (MUT => MUT)
    port map (
      clk => clk, rst_n => rst_n,
      cmd_valid => cmd_valid, cmd_op => cmd_op, cmd_addr => cmd_addr,
      cmd_words => cmd_words, cmd_done => cmd_done, cmd_busy => cmd_busy,
      dbg_st => dbg_st, dbg_beat => dbg_beat,
      m_axi_araddr => araddr, m_axi_arlen => arlen, m_axi_arsize => arsize,
      m_axi_arburst => arburst, m_axi_arprot => arprot, m_axi_arcache => arcache,
      m_axi_arvalid => arvalid, m_axi_arready => arready,
      m_axi_rdata => rdata_ax, m_axi_rresp => rresp, m_axi_rlast => rlast,
      m_axi_rvalid => rvalid, m_axi_rready => rready,
      m_axi_awaddr => awaddr, m_axi_awlen => awlen, m_axi_awsize => awsize,
      m_axi_awburst => awburst, m_axi_awprot => awprot, m_axi_awcache => awcache,
      m_axi_awvalid => awvalid, m_axi_awready => awready,
      m_axi_wdata => wdata_ax, m_axi_wstrb => wstrb, m_axi_wlast => wlast,
      m_axi_wvalid => wvalid, m_axi_wready => wready,
      m_axi_bresp => bresp, m_axi_bvalid => bvalid, m_axi_bready => bready,
      h_wr_en => h_wr_en, h_wr_row => h_wr_row, h_wr_col => h_wr_col,
      h_wr_data => h_wr_data,
      g_wr_en => g_wr_en, g_wr_addr => g_wr_addr, g_wr_data => g_wr_data,
      u_ext_rd_addr => u_ext_rd_addr, u_ext_rd_data => u_ext_rd_data,
      lin_addr => lin_addr);

  u_h : entity work.h_bank
    port map (clk => clk, wr_en => h_wr_en, wr_row => h_wr_row, wr_col => h_wr_col,
              wr_data => h_wr_data, rd_en => h_rd_en, rd_row => h_rd_row,
              row_data => h_row_data);

  u_g : entity work.g_bank
    port map (clk => clk, wr_en => g_wr_en, wr_addr => g_wr_addr,
              wr_data => g_wr_data, rd_en => g_rd_en, rd_addr => g_rd_addr,
              rd_data => g_rd_data);

  u_u : entity work.u_bank
    port map (clk => clk, rst_n => rst_n,
              wr_en => u_wr_en, wr_addr => u_wr_addr, wr_data => u_wr_data,
              rd_en => u_rd_en, rd_addr => (others => '0'), rd_data => open,
              snap_tick => u_snap, u_vec => u_vec_u,
              ext_rd_addr => u_ext_rd_addr, ext_rd_data => u_ext_rd_data);

  -- ============ BFM AXI4-Full esclavo con backpressure ============
  p_bfm : process (clk, rst_n)
    variable lf : std_logic_vector(15 downto 0) := x"ACE1";
    variable araddr_q : unsigned(31 downto 0);
    variable awaddr_q : unsigned(31 downto 0);
    variable have_rd  : boolean := false;
    variable have_wr  : boolean := false;
    variable prot_bad : boolean := false;
    variable inited   : boolean := false;
  begin
    if rst_n = '0' then
      arready <= '0'; rvalid <= '0'; rlast <= '0'; rresp <= "00";
      rdata_ax <= (others => '0');
      awready <= '0'; wready <= '0'; bvalid <= '0'; bresp <= "00";
      have_rd := false; have_wr := false; prot_bad := false;
      lf := x"ACE1";
      if not inited then
        for i in 0 to MEM_W-1 loop
          ddr(i) <= std_logic_vector(x"A0000000" + to_unsigned(i, 32));
        end loop;
        inited := true;
      end if;
    elsif rising_edge(clk) then
      lf := lfsr_next(lf);

      -- rechazo permanente si alguna vez llega AxPROT secure (000)
      if (arvalid = '1' and arprot = "000") or
         (awvalid = '1' and awprot = "000") then
        prot_bad := true;
      end if;

      -- ---- canal AR ----
      if prot_bad then
        arready <= '0';
      elsif arvalid = '1' and arready = '0' and not have_rd and lf(0) = '1' then
        arready  <= '1';
        araddr_q := unsigned(araddr);
        have_rd  := true;
      else
        arready <= '0';
      end if;

      -- ---- canal R ----
      if have_rd and rvalid = '0' and lf(1) = '1' then
        rdata_ax <= ddr(to_integer(araddr_q(14 downto 2)));
        rvalid   <= '1';
        rlast    <= '1';
        rresp    <= "00";
      elsif rvalid = '1' and rready = '1' then
        rvalid  <= '0';
        rlast   <= '0';
        have_rd := false;
      end if;

      -- ---- canal AW ----
      if prot_bad then
        awready <= '0';
      elsif awvalid = '1' and awready = '0' and not have_wr and lf(2) = '1' then
        awready  <= '1';
        awaddr_q := unsigned(awaddr);
        have_wr  := true;
      else
        awready <= '0';
      end if;

      -- ---- canal W ----
      if have_wr and wvalid = '1' and wready = '0' and lf(3) = '1' then
        wready <= '1';
        ddr(to_integer(awaddr_q(14 downto 2))) <= wdata_ax;
      else
        wready <= '0';
      end if;

      -- ---- canal B ----
      if have_wr and wvalid = '0' and wready = '0' and bvalid = '0' and lf(4) = '1' then
        bvalid <= '1';
        bresp  <= "00";
      elsif bvalid = '1' and bready = '1' then
        bvalid  <= '0';
        have_wr := false;
      end if;
    end if;
  end process;

  -- ============ secuencia de prueba ============
  p_main : process
    variable errores : integer := 0;
    variable polls : integer;
    variable expw : std_logic_vector(31 downto 0);

    procedure run_cmd(op : std_logic_vector(1 downto 0);
                      base : std_logic_vector(31 downto 0);
                      words : natural) is
    begin
      wait until rising_edge(clk);
      cmd_op    <= op;
      cmd_addr  <= base;
      cmd_words <= std_logic_vector(to_unsigned(words, 16));
      cmd_valid <= '1';
      wait until rising_edge(clk);
      cmd_valid <= '0';
      polls := 0;
      while cmd_done /= '1' and polls < 200000 loop
        wait until rising_edge(clk);
        polls := polls + 1;
      end loop;
      if polls >= 200000 then
        report "TIMEOUT/DEADLOCK en DMA op=" & to_hstring(op) severity failure;
      end if;
    end procedure;
  begin
    -- la DDR la precarga el BFM en reset con patron 0xA0000000+i

    rst_n <= '0';
    wait for 6*TCLK;
    wait until rising_edge(clk);
    rst_n <= '1';
    wait until rising_edge(clk);

    -- ---- LOAD_G: DP palabras desde base 0x100 (word 0x40) ----
    run_cmd("01", x"00000100", DP);
    for i in 0 to DP-1 loop
      g_rd_en <= '1';
      g_rd_addr <= std_logic_vector(to_unsigned(i, IDX_W));
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait for 1 ns;
      expw := ddr(16#40# + i);
      if g_rd_data /= expw then
        errores := errores + 1;
        if errores <= 8 then
          report "LOAD_G g[" & integer'image(i) & "] got=0x" &
                 to_hstring(g_rd_data) & " exp=0x" & to_hstring(expw)
                 severity note;
        end if;
      end if;
    end loop;
    g_rd_en <= '0';

    -- ---- LOAD_H: unas cuantas filas (words = 3*DP) desde base 0x800 ----
    run_cmd("00", x"00000800", 3*DP);
    for row in 0 to 2 loop
      h_rd_en  <= '1';
      h_rd_row <= std_logic_vector(to_unsigned(row, IDX_W));
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait for 1 ns;
      for col in 0 to D-1 loop
        expw := ddr(16#200# + row*DP + col);
        if h_row_data((col+1)*FP_W-1 downto col*FP_W) /= expw then
          errores := errores + 1;
          if errores <= 8 then
            report "LOAD_H H[" & integer'image(row) & "][" &
                   integer'image(col) & "] mismatch" severity note;
          end if;
        end if;
      end loop;
    end loop;
    h_rd_en <= '0';

    -- ---- STORE_U: precargar U con patron, DMA a DDR base 0x1000, verificar ----
    for i in 0 to DP-1 loop
      u_wr_en   <= '1';
      u_wr_addr <= std_logic_vector(to_unsigned(i, IDX_W));
      u_wr_data <= std_logic_vector(x"55000000" + to_unsigned(i, 32));
      wait until rising_edge(clk);
    end loop;
    u_wr_en <= '0';
    wait until rising_edge(clk);

    run_cmd("10", x"00001000", DP);
    for i in 0 to DP-1 loop
      expw := std_logic_vector(x"55000000" + to_unsigned(i, 32));
      if ddr(16#400# + i) /= expw then
        errores := errores + 1;
        if errores <= 8 then
          report "STORE_U DDR[" & integer'image(i) & "] got=0x" &
                 to_hstring(ddr(16#400# + i)) & " exp=0x" & to_hstring(expw)
                 severity note;
        end if;
      end if;
    end loop;

    report "ERRORES=" & integer'image(errores) & " T=" & time'image(now);
    assert errores = 0
      report "CAPA 2 DMA FALLO" severity failure;

    fin <= true;
    finish;
  end process;

end architecture sim;
