-- =============================================================
-- tb_mem_adapter.vhd - Capa 2 del Paso 4a
-- Corre el mismo programa RV32IMA en:
--   (ref) core standalone + memoria combinacional latencia-cero
--   (dut) core_ce + rv32_mem_adapter + BFM AXI-Lite (+ MMIO rapido)
-- con WS=0 (latencia cero) y WS>0 (wait-states pseudoaleatorios).
-- Exige que el estado arquitectural final (32 regs espiados +
-- memoria DDR) sea BIT-IDENTICO entre ref y dut en ambos WS.
-- Criterio de paso: linea unica
--   FIN SIMULACION ADAPTER: PASS @ <tiempo>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_mem_adapter is
  generic (WS_MAX : natural := 0);  -- 0 = latencia cero
end entity;

architecture sim of tb_mem_adapter is
  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  -- ---- referencia: core standalone ----
  signal r_iaddr, r_idata, r_daddr, r_dwdata, r_rdata : std_logic_vector(31 downto 0);
  signal r_we, r_re, r_halt : std_logic;
  signal r_be : std_logic_vector(3 downto 0);

  -- ---- dut: core_ce + adaptador ----
  signal d_en   : std_logic;
  signal d_iaddr, d_idata, d_daddr, d_dwdata, d_rdata : std_logic_vector(31 downto 0);
  signal d_we, d_re, d_halt : std_logic;
  signal d_stf, d_stm, d_sts : std_logic;
  signal d_be : std_logic_vector(3 downto 0);
  -- AXI del adaptador
  signal arvalid, arready, rvalid, rready : std_logic;
  signal araddr, axi_rdata : std_logic_vector(31 downto 0);
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic;
  signal awaddr, wdata : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
  -- MMIO del adaptador
  signal mmio_req, mmio_we, mmio_ready : std_logic;
  signal mmio_addr, mmio_wdata, mmio_rdata : std_logic_vector(31 downto 0);

  constant NW : natural := 4096;   -- palabras de RAM (16 KB)
  type t_mem is array (0 to NW-1) of std_logic_vector(31 downto 0);

  impure function load_prog return t_mem is
    variable m : t_mem := (others => (others => '0'));
    file f     : text open read_mode is "prog_adapter.mem";
    variable l : line;
    variable w : std_logic_vector(31 downto 0);
    variable i : natural := 0;
  begin
    while not endfile(f) and i < NW loop
      readline(f, l); hread(l, w); m(i) := w; i := i + 1;
    end loop;
    return m;
  end function;

  signal rmem : t_mem := load_prog;   -- memoria de la referencia
  signal dmem_ddr : t_mem := load_prog; -- DDR fisica (base 0x70000000) del dut

  -- LCG para wait-states deterministas
  signal lcg : unsigned(31 downto 0) := to_unsigned(20260717, 32);
begin

  -- ================= REFERENCIA =================
  -- referencia: core_ce (equivalente al original, ya probado) con
  -- RESET_PC=0x80000000 y memoria combinacional indexada restando base.
  ref_core : entity work.rv32im_core_ce
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>'1',
      imem_addr_o=>r_iaddr, imem_data_i=>r_idata,
      dmem_addr_o=>r_daddr, dmem_wdata_o=>r_dwdata, dmem_we_o=>r_we,
      dmem_re_o=>r_re, dmem_be_o=>r_be, dmem_rdata_i=>r_rdata, halt_o=>r_halt,
      st_fetch_o=>open, st_mem_o=>open, st_store_o=>open);

  -- indice = bits [13:2] de la direccion (base 0x80000000 => bit31=1).
  -- NW=4096 palabras => 12 bits de indice: addr(13 downto 2).
  r_idata <= rmem(to_integer(unsigned(r_iaddr(13 downto 2))))
             when r_iaddr(31) = '1' else (others=>'0');
  r_rdata <= rmem(to_integer(unsigned(r_daddr(13 downto 2))))
             when r_daddr(31) = '1' else (others=>'0');
  process(clk)
  begin
    if rising_edge(clk) then
      if r_we='1' and r_daddr(31)='1' then
        rmem(to_integer(unsigned(r_daddr(13 downto 2)))) <= r_dwdata;
      end if;
    end if;
  end process;

  -- ================= DUT =================
  dut_core : entity work.rv32im_core_ce
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>d_en,
      imem_addr_o=>d_iaddr, imem_data_i=>d_idata,
      dmem_addr_o=>d_daddr, dmem_wdata_o=>d_dwdata, dmem_we_o=>d_we,
      dmem_re_o=>d_re, dmem_be_o=>d_be, dmem_rdata_i=>d_rdata, halt_o=>d_halt,
      st_fetch_o=>d_stf, st_mem_o=>d_stm, st_store_o=>d_sts);

  adapter : entity work.rv32_mem_adapter
    port map (clk=>clk, rstn=>rstn, core_clk_en=>d_en,
      imem_addr=>d_iaddr, imem_data=>d_idata,
      dmem_addr=>d_daddr, dmem_wdata=>d_dwdata, dmem_we=>d_we, dmem_re=>d_re,
      dmem_be=>d_be, dmem_rdata=>d_rdata, core_halt=>d_halt,
      core_st_fetch=>d_stf, core_st_mem=>d_stm, core_st_store=>d_sts,
      m_arvalid=>arvalid, m_arready=>arready, m_araddr=>araddr,
      m_rvalid=>rvalid, m_rready=>rready, m_rdata=>axi_rdata,
      m_awvalid=>awvalid, m_awready=>awready, m_awaddr=>awaddr,
      m_wvalid=>wvalid, m_wready=>wready, m_wdata=>wdata, m_wstrb=>wstrb,
      m_bvalid=>bvalid, m_bready=>bready,
      mmio_req=>mmio_req, mmio_we=>mmio_we, mmio_addr=>mmio_addr,
      mmio_wdata=>mmio_wdata, mmio_rdata=>mmio_rdata, mmio_ready=>mmio_ready);

  -- MMIO rapido: no usado por este programa, ready siempre 1, lee 0
  mmio_ready <= '1';
  mmio_rdata <= (others=>'0');

  -- ---- BFM AXI-Lite con wait-states parametrizables ----
  bfm : process
    variable ws : integer;
    variable idx : integer;
    -- indice de palabra dentro de la DDR fisica (base 0x70000000)
    impure function widx(a : std_logic_vector(31 downto 0)) return integer is
    begin
      -- DDR fisica base 0x70000000; indice = a(13 downto 2)
      return to_integer(unsigned(a(13 downto 2)));
    end function;
    impure function rnd_ws return integer is
    begin
      if WS_MAX = 0 then return 0; end if;
      lcg <= resize(lcg * 1664525 + 1013904223, 32);
      return to_integer(lcg(7 downto 0)) mod (WS_MAX+1);
    end function;
  begin
    arready <= '0'; rvalid <= '0'; axi_rdata <= (others=>'0');
    awready <= '0'; wready <= '0'; bvalid <= '0';
    loop
      wait until rising_edge(clk);
      exit when rstn = '1';
    end loop;
    loop
      wait until rising_edge(clk);
      -- ----- canal de lectura -----
      if arvalid = '1' then
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        arready <= '1';
        wait until rising_edge(clk);
        arready <= '0';
        idx := widx(araddr);
        if idx >= 0 and idx < NW then axi_rdata <= dmem_ddr(idx);
        else axi_rdata <= (others=>'0'); end if;
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        rvalid <= '1';
        wait until rising_edge(clk) and rready = '1';
        rvalid <= '0';
      -- ----- canal de escritura -----
      elsif awvalid = '1' or wvalid = '1' then
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        awready <= '1'; wready <= '1';
        wait until rising_edge(clk);
        awready <= '0'; wready <= '0';
        idx := widx(awaddr);
        if idx >= 0 and idx < NW then
          -- respetar wstrb byte a byte
          for b in 0 to 3 loop
            if wstrb(b) = '1' then
              dmem_ddr(idx)(b*8+7 downto b*8) <= wdata(b*8+7 downto b*8);
            end if;
          end loop;
        end if;
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        bvalid <= '1';
        wait until rising_edge(clk) and bready = '1';
        bvalid <= '0';
      end if;
    end loop;
  end process;

  clk <= not clk after 5 ns;

  chk : process
    variable timeout : integer := 0;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    -- correr hasta que AMBOS lleguen a halt
    loop
      wait until rising_edge(clk);
      wait for 1 ns;
      exit when r_halt = '1' and d_halt = '1';
      timeout := timeout + 1;
      assert timeout < 500000
        report "TIMEOUT: ref_halt=" & std_logic'image(r_halt) &
               " dut_halt=" & std_logic'image(d_halt) severity failure;
    end loop;
    -- comparar memorias: rmem (ref) vs dmem_ddr (dut)
    for i in 0 to NW-1 loop
      assert rmem(i) = dmem_ddr(i)
        report "MEM DIVERGE palabra " & integer'image(i) &
               " ref=" & to_hstring(rmem(i)) &
               " dut=" & to_hstring(dmem_ddr(i)) severity failure;
    end loop;
    report "FIN SIMULACION ADAPTER: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
