-- ============================================================================
-- tb_adcs_top.vhd — Capa 3 del IP ADCS: integracion completa del top.
--
-- Simula el papel del firmware RV32 (escribe registros por el bus dmem) y del
-- NoC/DDR (BFM AXI4 esclavo con memoria). Por cada caso:
--   1) precarga H y g en la DDR del BFM (rol del PS antes de arrancar el core)
--   2) fw: escribe UBASE/HBASE/GBASE/NDIM/MAXITER/STEP/UMAX
--   3) fw: START con MODE_LOAD_H, sondea STATUS.done
--   4) fw: START con MODE_MPC_PGD, sondea STATUS.done
--   5) verifica U escrita por el IP en DDR(u_base) contra el oraculo del solver
--
-- El oraculo son los mismos vectores de capa 1c (mpc_oracle) recargados: el
-- resultado del top DEBE coincidir bit a bit con el solver ya verificado.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use std.env.all;
use work.adcs_pkg.all;
use work.riscv_pkg.all;

entity tb_adcs_top is
  generic (
    MUT      : natural := 0;
    LAT_FMA  : natural := 8;
    VEC_FILE : string  := "vectors_mpc.txt"
  );
end entity tb_adcs_top;

architecture sim of tb_adcs_top is
  constant TCLK  : time    := 4 ns;
  constant MEM_W : natural := 16384;
  -- bases DDR (byte address) para H, g, U
  constant HBASE : natural := 16#0000#;   -- word 0
  constant GBASE : natural := 16#4000#;   -- word 0x1000
  constant UBASE : natural := 16#8000#;   -- word 0x2000

  signal clk, rst_n : std_logic := '0';
  signal irq : std_logic;

  -- bus dmem (rol del core/firmware)
  signal dmem_sel  : std_logic := '0';
  signal dmem_addr : word_t := (others => '0');
  signal dmem_wdata: word_t := (others => '0');
  signal dmem_wstrb: std_logic_vector(3 downto 0) := (others => '0');
  signal dmem_rdata: word_t;
  signal dmem_ready: std_logic;

  -- AXI master del IP
  signal araddr : std_logic_vector(31 downto 0);
  signal arlen  : std_logic_vector(7 downto 0);
  signal arsize : std_logic_vector(2 downto 0);
  signal arburst: std_logic_vector(1 downto 0);
  signal arprot : std_logic_vector(2 downto 0);
  signal arcache: std_logic_vector(3 downto 0);
  signal arvalid, arready : std_logic;
  signal rdata_ax : std_logic_vector(31 downto 0);
  signal rresp : std_logic_vector(1 downto 0);
  signal rlast, rvalid, rready : std_logic;
  signal awaddr : std_logic_vector(31 downto 0);
  signal awlen  : std_logic_vector(7 downto 0);
  signal awsize : std_logic_vector(2 downto 0);
  signal awburst: std_logic_vector(1 downto 0);
  signal awprot : std_logic_vector(2 downto 0);
  signal awcache: std_logic_vector(3 downto 0);
  signal awvalid, awready : std_logic;
  signal wdata_ax : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
  signal wlast, wvalid, wready : std_logic;
  signal bresp : std_logic_vector(1 downto 0);
  signal bvalid, bready : std_logic;

  type ddr_t is array (0 to MEM_W-1) of std_logic_vector(31 downto 0);
  signal ddr : ddr_t := (others => (others => '0'));
  -- precarga: el proceso de estimulo pide cargar via señales al BFM
  signal pre_en   : std_logic := '0';
  signal pre_addr : natural := 0;
  signal pre_data : std_logic_vector(31 downto 0) := (others => '0');

  signal fin : boolean := false;

  function lfsr_next(s : std_logic_vector(15 downto 0)) return std_logic_vector is
  begin
    return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10));
  end function;
begin

  clk <= not clk after TCLK/2 when not fin else '0';

  dut : entity work.adcs_accel_top
    generic map (LAT_FMA => LAT_FMA, LAT_ADD => 6, MUT => MUT)
    port map (
      clk => clk, rst_n => rst_n, irq => irq,
      dmem_sel => dmem_sel, dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
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
      m_axi_bresp => bresp, m_axi_bvalid => bvalid, m_axi_bready => bready);

  -- ============ BFM AXI4 esclavo (DDR) con backpressure ============
  p_bfm : process (clk, rst_n)
    variable lf : std_logic_vector(15 downto 0) := x"BEEF";
    variable araddr_q, awaddr_q : unsigned(31 downto 0);
    variable have_rd, have_wr : boolean := false;
  begin
    if rst_n = '0' then
      arready <= '0'; rvalid <= '0'; rlast <= '0'; rresp <= "00";
      rdata_ax <= (others => '0');
      awready <= '0'; wready <= '0'; bvalid <= '0'; bresp <= "00";
      have_rd := false; have_wr := false; lf := x"BEEF";
    elsif rising_edge(clk) then
      lf := lfsr_next(lf);

      -- precarga sincrona (rol del PS): pre_en escribe ddr[pre_addr]
      if pre_en = '1' then
        ddr(pre_addr) <= pre_data;
      end if;

      -- AR
      if arvalid = '1' and arready = '0' and not have_rd and lf(0) = '1' then
        arready <= '1'; araddr_q := unsigned(araddr); have_rd := true;
      else
        arready <= '0';
      end if;
      -- R
      if have_rd and rvalid = '0' and lf(1) = '1' then
        rdata_ax <= ddr(to_integer(araddr_q(15 downto 2)));
        rvalid <= '1'; rlast <= '1'; rresp <= "00";
      elsif rvalid = '1' and rready = '1' then
        rvalid <= '0'; rlast <= '0'; have_rd := false;
      end if;
      -- AW
      if awvalid = '1' and awready = '0' and not have_wr and lf(2) = '1' then
        awready <= '1'; awaddr_q := unsigned(awaddr); have_wr := true;
      else
        awready <= '0';
      end if;
      -- W
      if have_wr and wvalid = '1' and wready = '0' and lf(3) = '1' then
        wready <= '1';
        if pre_en = '0' then
          ddr(to_integer(awaddr_q(15 downto 2))) <= wdata_ax;
        end if;
      else
        wready <= '0';
      end if;
      -- B
      if have_wr and wvalid = '0' and wready = '0' and bvalid = '0' and lf(4) = '1' then
        bvalid <= '1'; bresp <= "00";
      elsif bvalid = '1' and bready = '1' then
        bvalid <= '0'; have_wr := false;
      end if;
    end if;
  end process;

  -- ============ estimulo: firmware + PS ============
  p_main : process
    file     f : text;
    variable l : line;
    variable t, n, mi : integer;
    variable w : std_logic_vector(31 downto 0);
    type mat_t is array (0 to D-1, 0 to D-1) of std_logic_vector(31 downto 0);
    type vec_t is array (0 to D-1) of std_logic_vector(31 downto 0);
    variable hm : mat_t;
    variable gv, uexp : vec_t;
    variable step_v, umax_v : std_logic_vector(31 downto 0);
    variable errores : integer := 0;
    variable sig : std_logic_vector(31 downto 0) := (others => '0');
    variable polls : integer;

    procedure fw_write(off : std_logic_vector(7 downto 0);
                       data : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      dmem_sel <= '1'; dmem_wstrb <= "1111";
      dmem_addr <= x"000000" & off; dmem_wdata <= data;
      wait until rising_edge(clk);
      dmem_sel <= '0'; dmem_wstrb <= "0000";
    end procedure;

    procedure fw_poll_done is
      variable done_bit : std_logic := '0';
    begin
      polls := 0;
      while done_bit = '0' and polls < 4000000 loop
        wait until rising_edge(clk);
        dmem_sel <= '1'; dmem_wstrb <= "0000";
        dmem_addr <= x"00000004";       -- STATUS
        wait for TCLK - 1 ns;
        done_bit := dmem_rdata(ST_DONE_BIT);
        wait until rising_edge(clk);
        dmem_sel <= '0';
        polls := polls + 1;
      end loop;
      if done_bit = '0' then
        report "TIMEOUT esperando DONE" severity failure;
      end if;
    end procedure;

    procedure ps_load(word_addr : natural; data : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      pre_en <= '1'; pre_addr <= word_addr; pre_data <= data;
      wait until rising_edge(clk);
      pre_en <= '0';
    end procedure;
  begin
    rst_n <= '0';
    wait for 6*TCLK;
    wait until rising_edge(clk);
    rst_n <= '1';
    wait until rising_edge(clk);

    file_open(f, VEC_FILE, read_mode);
    readline(f, l); read(l, t);

    for tt in 0 to t-1 loop
      readline(f, l);
      read(l, n); read(l, mi); hread(l, w); step_v := w; hread(l, w); umax_v := w;
      for i in 0 to n-1 loop
        readline(f, l);
        for j in 0 to n-1 loop hread(l, w); hm(i, j) := w; end loop;
      end loop;
      readline(f, l);
      for i in 0 to n-1 loop hread(l, w); gv(i) := w; end loop;
      readline(f, l);
      for i in 0 to n-1 loop hread(l, w); uexp(i) := w; end loop;

      -- PS: precargar H (fila-major, DP columnas por fila) y g en DDR
      for i in 0 to n-1 loop
        for j in 0 to n-1 loop
          ps_load(HBASE/4 + i*DP + j, hm(i, j));
        end loop;
      end loop;
      for i in 0 to n-1 loop
        ps_load(GBASE/4 + i, gv(i));
      end loop;

      -- firmware: programar registros
      fw_write(REG_HBASE,   std_logic_vector(to_unsigned(HBASE, 32)));
      fw_write(REG_GBASE,   std_logic_vector(to_unsigned(GBASE, 32)));
      fw_write(REG_UBASE,   std_logic_vector(to_unsigned(UBASE, 32)));
      fw_write(REG_NDIM,    std_logic_vector(to_unsigned(n, 32)));
      fw_write(REG_MAXITER, std_logic_vector(to_unsigned(mi, 32)));
      fw_write(REG_STEP,    step_v);
      fw_write(REG_UMAX,    umax_v);

      -- START LOAD_H
      fw_write(REG_MODE, std_logic_vector(resize(unsigned(MODE_LOAD_H), 32)));
      fw_write(REG_CTRL, std_logic_vector(to_unsigned(1, 32)));  -- START
      fw_poll_done;

      -- START MPC_PGD
      fw_write(REG_MODE, std_logic_vector(resize(unsigned(MODE_MPC_PGD), 32)));
      fw_write(REG_CTRL, std_logic_vector(to_unsigned(1, 32)));
      fw_poll_done;

      -- verificar U escrita en DDR(u_base) contra el oraculo
      for i in 0 to n-1 loop
        w := ddr(UBASE/4 + i);
        sig := sig(30 downto 0) & sig(31);
        sig := sig xor w;
        if w /= uexp(i) then
          errores := errores + 1;
          if errores <= 10 then
            report "top test " & integer'image(tt) & " U[" & integer'image(i) &
                   "] got=0x" & to_hstring(w) & " exp=0x" & to_hstring(uexp(i))
                   severity note;
          end if;
        end if;
      end loop;
    end loop;
    file_close(f);

    report "T=" & integer'image(t) &
           " ERRORES=" & integer'image(errores) &
           " FIRMA_L3=0x" & to_hstring(sig) &
           " T=" & time'image(now);

    assert errores = 0
      report "CAPA 3 FALLO: el top no reproduce el solver" severity failure;

    fin <= true;
    finish;
  end process;

end architecture sim;
