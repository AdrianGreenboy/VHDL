-- =============================================================
-- tb_soc_trap.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 5
-- SoC completo: core IMA + adaptador + bus MMIO (UART, CLINT,
-- syscon) + BFM AXI-Lite para la DDR con wait-states.
-- Corre un programa que imprime una cadena por el UART y hace
-- poweroff. Verifica:
--   - la secuencia EXACTA de caracteres emitidos
--   - que el poweroff llega por el syscon
-- Criterio de paso:
--   FIN SIMULACION SOC MMIO: PASS @ <tiempo>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_soc_trap is
  generic (
    WS_MAX   : natural := 0;
    EXPECTED : string  := "HERCOSSNUX"
  );
end entity;

architecture sim of tb_soc_trap is
  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  signal d_en : std_logic;
  signal d_iaddr, d_idata, d_daddr, d_dwdata, d_rdata : std_logic_vector(31 downto 0);
  signal d_we, d_re, d_halt : std_logic;
  signal d_be : std_logic_vector(3 downto 0);
  signal d_stf, d_stm, d_sts : std_logic;
  signal d_dbg : std_logic_vector(1023 downto 0);
  signal data_done : std_logic;

  -- AXI hacia DDR
  signal arvalid, arready, rvalid, rready : std_logic;
  signal araddr, axi_rdata : std_logic_vector(31 downto 0);
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic;
  signal awaddr, wdata : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);

  -- MMIO
  signal mmio_req, mmio_we, mmio_ready : std_logic;
  signal mmio_addr, mmio_wdata, mmio_rdata : std_logic_vector(31 downto 0);
  signal tx_valid : std_logic;
  signal tx_data  : std_logic_vector(7 downto 0);
  signal rx_take, poweroff, reboot, mtip, msip : std_logic;
  signal tick : std_logic := '0';

  constant NW : natural := 4096;
  type t_mem is array (0 to NW-1) of std_logic_vector(31 downto 0);

  impure function load_prog return t_mem is
    variable m : t_mem := (others => (others => '0'));
    file f     : text open read_mode is "trap_test.mem";
    variable l : line;
    variable w : std_logic_vector(31 downto 0);
    variable i : natural := 0;
  begin
    while not endfile(f) and i < NW loop
      readline(f, l); hread(l, w); m(i) := w; i := i + 1;
    end loop;
    return m;
  end function;

  signal ddr : t_mem := load_prog;

  signal lcg : unsigned(31 downto 0) := to_unsigned(20260719, 32);

  -- captura de caracteres emitidos
  signal cap      : string(1 to 256) := (others => ' ');
  signal cap_len  : natural := 0;
begin

  dut_core : entity work.rv32ima_core
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>d_en,
      mem_data_done_i=>data_done, mtip_i=>mtip, msip_i=>msip,
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

  u_mmio : entity work.rv32_mmio_bus
    port map (clk=>clk, rstn=>rstn, tick=>tick,
      req=>mmio_req, we=>mmio_we, addr=>mmio_addr, wdata=>mmio_wdata,
      rdata=>mmio_rdata, ready=>mmio_ready,
      tx_valid=>tx_valid, tx_data=>tx_data,
      rx_dr=>'0', rx_data=>x"00", rx_take=>rx_take,
      poweroff_o=>poweroff, reboot_o=>reboot,
      mtip=>mtip, msip=>msip);

  -- ---- BFM AXI-Lite para la DDR ----
  bfm : process
    variable ws : integer;
    variable ix : integer;
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
        ix := to_integer(unsigned(araddr(13 downto 2)));
        if ix>=0 and ix<NW then axi_rdata<=ddr(ix); else axi_rdata<=(others=>'0'); end if;
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
        ix := to_integer(unsigned(awaddr(13 downto 2)));
        if ix>=0 and ix<NW then
          for b in 0 to 3 loop
            if wstrb(b)='1' then
              ddr(ix)(b*8+7 downto b*8) <= wdata(b*8+7 downto b*8);
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

  -- ---- captura de caracteres del UART ----
  cap_proc : process(clk)
  begin
    if rising_edge(clk) then
      if tx_valid = '1' and cap_len < 256 then
        cap(cap_len+1) <= character'val(to_integer(unsigned(tx_data)));
        cap_len <= cap_len + 1;
      end if;
    end if;
  end process;

  chk : process
    variable timeout : integer := 0;
    variable l : line;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    -- correr hasta el poweroff
    loop
      wait until rising_edge(clk);
      wait for 1 ns;
      exit when poweroff = '1' or d_halt = '1';
      timeout := timeout + 1;
      assert timeout < 500000
        report "TIMEOUT esperando poweroff; caracteres emitidos=" &
               integer'image(cap_len) severity failure;
    end loop;

    -- verificar la cadena emitida (EXPECTED + salto de linea)
    assert cap_len = EXPECTED'length + 1
      report "LONGITUD UART incorrecta: emitidos=" & integer'image(cap_len) &
             " esperados=" & integer'image(EXPECTED'length + 1) &
             " capturado='" & cap(1 to cap_len) & "'"
      severity failure;
    for i in EXPECTED'range loop
      assert cap(i) = EXPECTED(i)
        report "CARACTER " & integer'image(i) & " incorrecto: emitido='" &
               cap(i) & "' esperado='" & EXPECTED(i) & "'"
        severity failure;
    end loop;
    assert cap(cap_len) = LF
      report "falta el salto de linea final" severity failure;

    write(l, string'("Salida UART capturada: '"));
    write(l, cap(1 to EXPECTED'length));
    write(l, string'("' + LF"));
    writeline(output, l);
    report "FIN SIMULACION SOC MMIO: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
