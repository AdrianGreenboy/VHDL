-- HERCOSSNUX NPU - banco de regresion del audit 2026-11 (autocomprobado).
-- Cada prueba falla con el RTL anterior al audit:
--   A1/A2 npu_dma: un error de RRESP se reporta en su peticion y NO queda
--         pegado en la siguiente peticion limpia (err_out / errcode)
--   A3/A4 npu_dma: peticiones de 0 bytes terminan sin trafico AXI
--   S1    npu_axi_slave: rafaga de escritura que entra en zona no mapeada
--         -> SLVERR (antes OKAY: solo se miraba la direccion de AW)
--   S2    npu_axi_slave: AWSIZE=0 (narrow), 4 beats a BASE byte a byte
--         -> BASE = 0x44332211 (antes la direccion avanzaba 4 por beat)
--   S3    npu_axi_slave: AWSIZE=3 (mas ancho que el bus) -> SLVERR
--   R1    npu_requant con G_SHIFT=40: redondeo correcto (antes 2**39 como
--         integer desbordaba)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;
use work.npu_axi_pkg.all;

entity tb_npu_audit is
end entity;

architecture sim of tb_npu_audit is
  constant CP : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst_n : std_logic := '0';

  -- DMA
  signal rd_start, wr_start : std_logic := '0';
  signal rd_addr, wr_addr : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_bytes, wr_bytes : natural := 0;
  signal rd_busy, rd_done, wr_busy, wr_done, out_we, err_out : std_logic;
  signal out_idx, in_idx : natural;
  signal out_data : std_logic_vector(7 downto 0);
  signal errcode : std_logic_vector(1 downto 0);
  signal arvalid, arready, rvalid, rready, rlast, awvalid, awready : std_logic;
  signal wvalid, wready, wlast, bvalid, bready : std_logic;
  signal araddr, awaddr, rdata, wdata : std_logic_vector(31 downto 0);
  signal arlen, awlen : std_logic_vector(7 downto 0);
  signal arsize, awsize : std_logic_vector(2 downto 0);
  signal arburst, awburst, rresp, bresp : std_logic_vector(1 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
  signal n_ar, n_aw : natural := 0;

  -- slave
  signal s_awvalid, s_wvalid, s_wlast, s_bready, s_arvalid, s_rready : std_logic := '0';
  signal s_awready, s_wready, s_bvalid, s_arready, s_rvalid, s_rlast : std_logic;
  signal s_awaddr, s_araddr, s_wdata, s_rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal s_awlen, s_arlen : std_logic_vector(7 downto 0) := (others => '0');
  signal s_awsize, s_arsize : std_logic_vector(2 downto 0) := "010";
  signal s_awburst, s_arburst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal s_awid, s_arid, s_bid, s_rid : std_logic_vector(3 downto 0) := (others => '0');
  signal s_wstrb : std_logic_vector(3 downto 0) := (others => '1');
  signal s_bresp, s_rresp : std_logic_vector(1 downto 0);

  -- requant
  signal rq_vin, rq_vout : std_logic := '0';
  signal rq_acc : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal rq_mult : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal rq_out : signed(C_DATA_W-1 downto 0);
begin
  clk <= '0' when fin else not clk after CP/2;

  u_dma : entity work.npu_dma
    port map (clk => clk, rst_n => rst_n,
      rd_start => rd_start, rd_addr => rd_addr, rd_bytes => rd_bytes,
      rd_busy => rd_busy, rd_done => rd_done,
      out_we => out_we, out_idx => out_idx, out_data => out_data,
      wr_start => wr_start, wr_addr => wr_addr, wr_bytes => wr_bytes,
      wr_busy => wr_busy, wr_done => wr_done,
      in_idx => in_idx, in_data => x"5A",
      err_out => err_out, errcode => errcode,
      m_arvalid => arvalid, m_arready => arready, m_araddr => araddr,
      m_arlen => arlen, m_arsize => arsize, m_arburst => arburst,
      m_rvalid => rvalid, m_rready => rready, m_rdata => rdata,
      m_rresp => rresp, m_rlast => rlast,
      m_awvalid => awvalid, m_awready => awready, m_awaddr => awaddr,
      m_awlen => awlen, m_awsize => awsize, m_awburst => awburst,
      m_wvalid => wvalid, m_wready => wready, m_wdata => wdata,
      m_wstrb => wstrb, m_wlast => wlast,
      m_bvalid => bvalid, m_bready => bready, m_bresp => bresp);

  u_ddr : entity work.axi_ddr_model
    generic map (G_SIZE_BYTES => 16#1000#, G_STALL => 0, G_ERR_ADDR => 16#100#)
    port map (clk => clk, rst_n => rst_n,
      arvalid => arvalid, arready => arready, araddr => araddr, arlen => arlen,
      arburst => arburst, rvalid => rvalid, rready => rready, rdata => rdata,
      rresp => rresp, rlast => rlast,
      awvalid => awvalid, awready => awready, awaddr => awaddr, awlen => awlen,
      awburst => awburst, wvalid => wvalid, wready => wready, wdata => wdata,
      wstrb => wstrb, wlast => wlast, bvalid => bvalid, bready => bready, bresp => bresp,
      dbg_addr => 0, dbg_data => open);

  cnt : process(clk)
  begin
    if rising_edge(clk) then
      if arvalid = '1' and arready = '1' then n_ar <= n_ar + 1; end if;
      if awvalid = '1' and awready = '1' then n_aw <= n_aw + 1; end if;
    end if;
  end process;

  u_slv : entity work.npu_axi_slave
    generic map (G_ID_W => 4)
    port map (clk => clk, rst_n => rst_n,
      s_awvalid => s_awvalid, s_awready => s_awready, s_awaddr => s_awaddr,
      s_awlen => s_awlen, s_awsize => s_awsize, s_awburst => s_awburst, s_awid => s_awid,
      s_wvalid => s_wvalid, s_wready => s_wready, s_wdata => s_wdata,
      s_wstrb => s_wstrb, s_wlast => s_wlast,
      s_bvalid => s_bvalid, s_bready => s_bready, s_bresp => s_bresp, s_bid => s_bid,
      s_arvalid => s_arvalid, s_arready => s_arready, s_araddr => s_araddr,
      s_arlen => s_arlen, s_arsize => s_arsize, s_arburst => s_arburst, s_arid => s_arid,
      s_rvalid => s_rvalid, s_rready => s_rready, s_rdata => s_rdata,
      s_rresp => s_rresp, s_rlast => s_rlast, s_rid => s_rid,
      o_start => open, o_loadw => open, o_base => open,
      i_busy => '0', i_done => '0', i_error => '0',
      i_clase => "0000", i_errcode => "00");

  u_rq : entity work.npu_requant
    generic map (G_ACC_W => C_ACC_W, G_SHIFT => 40, G_MUT => 0)
    port map (clk => clk, rst_n => rst_n, valid_in => rq_vin, relu_en => '0',
              acc_in => rq_acc, mult_in => rq_mult, valid_out => rq_vout, data_out => rq_out);

  main : process
    variable c : natural;
    variable resp : std_logic_vector(1 downto 0);
    variable v : std_logic_vector(31 downto 0);

    procedure dma_rd(a : natural; n : natural) is
    begin
      rd_addr <= std_logic_vector(to_unsigned(a, 32)); rd_bytes <= n; rd_start <= '1';
      wait until rising_edge(clk); rd_start <= '0';
      c := 0;
      loop wait until rising_edge(clk); c := c + 1; exit when rd_done = '1';
        assert c < 2000 report "DMA read did not finish" severity failure; end loop;
      wait until rising_edge(clk);
    end procedure;

    -- AXI write burst on the slave: beats = len+1, data/strobe per beat
    type v4 is array (0 to 3) of std_logic_vector(31 downto 0);
    type s4 is array (0 to 3) of std_logic_vector(3 downto 0);
    procedure s_write(a : natural; len : natural; sz : natural; d : v4; st : s4;
                      r : out std_logic_vector(1 downto 0)) is
    begin
      s_awaddr <= std_logic_vector(to_unsigned(a, 32)); s_awlen <= std_logic_vector(to_unsigned(len, 8));
      s_awsize <= std_logic_vector(to_unsigned(sz, 3)); s_awburst <= C_BURST_INCR; s_awvalid <= '1';
      loop wait until rising_edge(clk); exit when s_awready = '1'; end loop;
      s_awvalid <= '0';
      for i in 0 to len loop
        s_wdata <= d(i); s_wstrb <= st(i); s_wvalid <= '1';
        if i = len then s_wlast <= '1'; else s_wlast <= '0'; end if;
        loop wait until rising_edge(clk); exit when s_wready = '1'; end loop;
      end loop;
      s_wvalid <= '0'; s_wlast <= '0';
      s_bready <= '1';
      loop wait until rising_edge(clk); exit when s_bvalid = '1'; end loop;
      r := s_bresp;
      s_bready <= '0';
      wait until rising_edge(clk);
    end procedure;
    procedure s_read(a : natural; d : out std_logic_vector(31 downto 0)) is
    begin
      s_araddr <= std_logic_vector(to_unsigned(a, 32)); s_arlen <= x"00"; s_arsize <= "010";
      s_arvalid <= '1';
      loop wait until rising_edge(clk); exit when s_arready = '1'; end loop;
      s_arvalid <= '0'; s_rready <= '1';
      loop wait until rising_edge(clk); exit when s_rvalid = '1'; end loop;
      d := s_rdata; s_rready <= '0';
      wait until rising_edge(clk);
    end procedure;
  begin
    rst_n <= '0'; for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst_n <= '1'; wait until rising_edge(clk);

    -- A1: read covering the error address
    dma_rd(16#100#, 64);
    assert err_out = '1' and errcode = C_RESP_SLVERR
      report "A1: RRESP error not reported" severity failure;
    report "A1 PASS RRESP error reported";
    -- A2: next clean read must not report the old error
    dma_rd(16#200#, 64);
    assert err_out = '0'
      report "A2: stale DMA error carried into a clean request" severity failure;
    report "A2 PASS error cleared at the next request";
    -- A3: 0-byte read
    c := n_ar;
    dma_rd(16#300#, 0);
    assert n_ar = c report "A3: 0-byte read produced AXI traffic" severity failure;
    report "A3 PASS 0-byte read";
    -- A4: 0-byte write
    c := n_aw;
    wr_addr <= x"00000400"; wr_bytes <= 0; wr_start <= '1';
    wait until rising_edge(clk); wr_start <= '0';
    for i in 0 to 50 loop
      wait until rising_edge(clk);
      exit when wr_done = '1';
      assert i < 50 report "A4: 0-byte write did not finish" severity failure;
    end loop;
    assert n_aw = c report "A4: 0-byte write produced AXI traffic" severity failure;
    report "A4 PASS 0-byte write";

    -- S1: burst BASE(0x0C) -> ERRCODE(0x10) -> 0x14 (unmapped)
    s_write(16#0C#, 2, 2, (x"70001000", x"00000000", x"00000000", x"00000000"),
            ("1111", "1111", "1111", "1111"), resp);
    assert resp = C_RESP_SLVERR report "S1: burst into unmapped space returned OKAY" severity failure;
    report "S1 PASS burst into unmapped space -> SLVERR";
    -- S2: narrow writes, one byte lane per beat
    s_write(16#0C#, 3, 0, (x"00000011", x"00002200", x"00330000", x"44000000"),
            ("0001", "0010", "0100", "1000"), resp);
    assert resp = C_RESP_OKAY report "S2: narrow burst rejected" severity failure;
    s_read(16#0C#, v);
    assert v = x"44332211" report "S2: AWSIZE ignored, BASE=" & to_hstring(v) severity failure;
    report "S2 PASS AWSIZE=0 narrow burst";
    -- S3: AWSIZE=3 (64-bit) on a 32-bit slave
    s_write(16#0C#, 0, 3, (x"DEADBEEF", x"00000000", x"00000000", x"00000000"), ("1111", "0000", "0000", "0000"), resp);
    assert resp = C_RESP_SLVERR report "S3: AWSIZE=3 accepted" severity failure;
    s_read(16#0C#, v);
    assert v = x"44332211" report "S3: AWSIZE=3 beat was written" severity failure;
    report "S3 PASS AWSIZE>2 -> SLVERR, no write";

    -- R1: requant with G_SHIFT = 40: (2^20 * (2^20 + 2^19)) / 2^40 = 1.5 -> rounds to 2
    rq_acc <= to_signed(2**20, C_ACC_W); rq_mult <= to_signed(2**20 + 2**19, C_MULT_W);
    rq_vin <= '1'; wait until rising_edge(clk); rq_vin <= '0';
    loop wait until rising_edge(clk); exit when rq_vout = '1'; end loop;
    assert rq_out = 2 report "R1: requant G_SHIFT=40 wrong: " & integer'image(to_integer(rq_out))
      severity failure;
    report "R1 PASS requant G_SHIFT=40";

    report "TB_NPU_AUDIT PASS";
    fin <= true; wait;
  end process;
end architecture;
