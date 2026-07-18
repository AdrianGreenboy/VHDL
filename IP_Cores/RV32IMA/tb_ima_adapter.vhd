-- =============================================================
-- tb_ima_adapter.vhd - Integracion core IMA + adaptador de memoria
-- Corre el mismo programa en:
--   (ref) core IMA + memoria combinacional latencia-cero
--   (dut) core IMA + rv32_mem_adapter + BFM AXI-Lite con wait-states
-- Exige estado arquitectural final BIT-IDENTICO (memoria DDR completa).
-- Criterio de paso:
--   FIN SIMULACION IMA+ADAPTER: PASS @ <tiempo>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_ima_adapter is
  generic (WS_MAX : natural := 0);
end entity;

architecture sim of tb_ima_adapter is
  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  -- ---- referencia: core IMA con memoria latencia-cero ----
  signal r_iaddr, r_idata, r_daddr, r_dwdata, r_rdata : std_logic_vector(31 downto 0);
  signal r_we, r_re, r_halt : std_logic;
  signal r_be : std_logic_vector(3 downto 0);
  signal r_dbg : std_logic_vector(1023 downto 0);

  -- ---- dut: core IMA + adaptador ----
  signal d_en : std_logic;
  signal d_iaddr, d_idata, d_daddr, d_dwdata, d_rdata : std_logic_vector(31 downto 0);
  signal d_we, d_re, d_halt : std_logic;
  signal d_be : std_logic_vector(3 downto 0);
  signal d_stf, d_stm, d_sts : std_logic;
  signal d_dbg : std_logic_vector(1023 downto 0);
  -- AXI
  signal arvalid, arready, rvalid, rready : std_logic;
  signal araddr, axi_rdata : std_logic_vector(31 downto 0);
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic;
  signal awaddr, wdata : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
  -- MMIO
  signal mmio_req, mmio_we, mmio_ready : std_logic;
  signal mmio_addr, mmio_wdata, mmio_rdata : std_logic_vector(31 downto 0);
  signal data_done : std_logic;

  constant NW : natural := 4096;
  type t_mem is array (0 to NW-1) of std_logic_vector(31 downto 0);

  impure function load_prog return t_mem is
    variable m : t_mem := (others => (others => '0'));
    file f     : text open read_mode is "lockstep.mem";
    variable l : line;
    variable w : std_logic_vector(31 downto 0);
    variable i : natural := 0;
  begin
    while not endfile(f) and i < NW loop
      readline(f, l); hread(l, w); m(i) := w; i := i + 1;
    end loop;
    return m;
  end function;

  signal rmem     : t_mem := load_prog;   -- memoria de la referencia
  signal dmem_ddr : t_mem := load_prog;   -- DDR fisica del dut

  function idx(a : std_logic_vector(31 downto 0)) return integer is
  begin
    return to_integer(unsigned(a(13 downto 2)));
  end function;

  -- indice en la DDR FISICA del dut: valida la traduccion 0x8xxx->0x7xxx
  -- en vez de descartarla quedandose con los bits bajos
  function pidx(a : std_logic_vector(31 downto 0)) return integer is
    variable ua : unsigned(31 downto 0);
  begin
    ua := unsigned(a);
    if ua < x"70000000" then return -1; end if;
    if (ua - x"70000000") >= to_unsigned(NW*4, 32) then return -1; end if;
    return to_integer((ua - x"70000000") srl 2);
  end function;

  signal lcg : unsigned(31 downto 0) := to_unsigned(20260718, 32);
  signal ref_off, dut_off : boolean := false;   -- poweroff detectado
begin

  -- ================= REFERENCIA (latencia cero) =================
  ref_core : entity work.rv32ima_core
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>'1',
      imem_addr_o=>r_iaddr, imem_data_i=>r_idata,
      dmem_addr_o=>r_daddr, dmem_wdata_o=>r_dwdata, dmem_we_o=>r_we,
      dmem_re_o=>r_re, dmem_be_o=>r_be, dmem_rdata_i=>r_rdata, halt_o=>r_halt,
      st_fetch_o=>open, st_mem_o=>open, st_store_o=>open, dbg_regs_o=>r_dbg);

  r_idata <= rmem(idx(r_iaddr)) when r_iaddr(31)='1' else (others=>'0');
  r_rdata <= rmem(idx(r_daddr)) when r_daddr(31)='1' else (others=>'0');

  ref_wr : process(clk)
  begin
    if rising_edge(clk) then
      if r_we='1' and r_daddr(31)='1' and r_daddr /= x"11100000" then
        for b in 0 to 3 loop
          if r_be(b)='1' then
            rmem(idx(r_daddr))(b*8+7 downto b*8) <= r_dwdata(b*8+7 downto b*8);
          end if;
        end loop;
      end if;
      if r_we='1' and r_daddr = x"11100000" and r_dwdata = x"00005555" then
        ref_off <= true;
      end if;
    end if;
  end process;

  -- ================= DUT (core IMA + adaptador) =================
  dut_core : entity work.rv32ima_core
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>d_en,
      mem_data_done_i=>data_done,
      imem_addr_o=>d_iaddr, imem_data_i=>d_idata,
      dmem_addr_o=>d_daddr, dmem_wdata_o=>d_dwdata, dmem_we_o=>d_we,
      dmem_re_o=>d_re, dmem_be_o=>d_be, dmem_rdata_i=>d_rdata, halt_o=>d_halt,
      st_fetch_o=>d_stf, st_mem_o=>d_stm, st_store_o=>d_sts, dbg_regs_o=>d_dbg);

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
      mmio_wdata=>mmio_wdata, mmio_rdata=>mmio_rdata, mmio_ready=>mmio_ready,
      data_done=>data_done);

  -- MMIO rapido: aqui vive el syscon (0x11100000). ready siempre 1.
  mmio_ready <= '1';
  mmio_rdata <= (others=>'0');

  mmio_mon : process(clk)
  begin
    if rising_edge(clk) then
      if mmio_req='1' and mmio_we='1' and mmio_addr=x"11100000"
         and mmio_wdata=x"00005555" then
        dut_off <= true;
      end if;
    end if;
  end process;

  -- ---- BFM AXI-Lite con wait-states ----
  bfm : process
    variable ws  : integer;
    variable ix  : integer;
    impure function rnd_ws return integer is
    begin
      if WS_MAX = 0 then return 0; end if;
      lcg <= resize(lcg * 1664525 + 1013904223, 32);
      return to_integer(lcg(7 downto 0)) mod (WS_MAX+1);
    end function;
  begin
    arready<='0'; rvalid<='0'; axi_rdata<=(others=>'0');
    awready<='0'; wready<='0'; bvalid<='0';
    loop
      wait until rising_edge(clk);
      exit when rstn='1';
    end loop;
    loop
      wait until rising_edge(clk);
      if arvalid='1' then
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        arready<='1'; wait until rising_edge(clk); arready<='0';
        ix := pidx(araddr);
        if ix>=0 and ix<NW then axi_rdata<=dmem_ddr(ix); else axi_rdata<=(others=>'0'); end if;
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        rvalid<='1';
        wait until rising_edge(clk) and rready='1';
        rvalid<='0';
      elsif awvalid='1' or wvalid='1' then
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        awready<='1'; wready<='1'; wait until rising_edge(clk);
        awready<='0'; wready<='0';
        ix := pidx(awaddr);
        if ix>=0 and ix<NW then
          for b in 0 to 3 loop
            if wstrb(b)='1' then
              dmem_ddr(ix)(b*8+7 downto b*8) <= wdata(b*8+7 downto b*8);
            end if;
          end loop;
        end if;
        ws := rnd_ws;
        for k in 1 to ws loop wait until rising_edge(clk); end loop;
        bvalid<='1';
        wait until rising_edge(clk) and bready='1';
        bvalid<='0';
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
    loop
      wait until rising_edge(clk);
      wait for 1 ns;
      exit when (ref_off or r_halt='1') and (dut_off or d_halt='1');
      timeout := timeout + 1;
      assert timeout < 500000
        report "TIMEOUT: ref_off=" & boolean'image(ref_off) &
               " dut_off=" & boolean'image(dut_off) severity failure;
    end loop;
    -- margen de estabilizacion: ambos cores quedan en el bucle infinito
    -- 'done: beq x0,x0,done' tras el poweroff, que no altera registros.
    -- El dut puede tener instrucciones sin retirar por la latencia del NoC,
    -- asi que le damos ciclos para alcanzar el mismo punto arquitectural.
    for k in 1 to 200 loop
      wait until rising_edge(clk);
    end loop;
    wait for 1 ns;
    -- comparar memoria completa
    for i in 0 to NW-1 loop
      assert rmem(i) = dmem_ddr(i)
        report "MEM DIVERGE palabra " & integer'image(i) &
               " ref=" & to_hstring(rmem(i)) &
               " dut=" & to_hstring(dmem_ddr(i)) severity failure;
    end loop;
    -- comparar banco de registros completo
    for i in 0 to 31 loop
      assert r_dbg(i*32+31 downto i*32) = d_dbg(i*32+31 downto i*32)
        report "REG DIVERGE x" & integer'image(i) &
               " ref=" & to_hstring(r_dbg(i*32+31 downto i*32)) &
               " dut=" & to_hstring(d_dbg(i*32+31 downto i*32)) severity failure;
    end loop;
    report "FIN SIMULACION IMA+ADAPTER: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
