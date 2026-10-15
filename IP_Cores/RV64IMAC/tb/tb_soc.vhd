-- tb_soc.vhd - Capa 4: SoC completo arrancando desde la boot ROM.
--   * DRAM: esclavo AXI4 con retardos aleatorios (rafagas, transferencias estrechas)
--   * Ranura MMIO 0: USART real de IP_Cores (usart_axi_top, bucle interno), irq -> PLIC 2,
--     con su DMA (maestro AXI4 32 bit) conectado a la DRAM como segundo puerto: DMA
--     NO coherente con la D$ (lo gestiona el software con Zicbom). Cada escritura del
--     DMA se anota en la traza ("D addr strb data") para que el ISS la vea igual.
--   * Ventana AXI4-Lite: banco de 16 registros que acepta AW y W en ciclos distintos
--   * UART 16550 del SoC en bucle tx -> rx
--   * HTIF por los stores retirados (rvfi_mem_*); consola por los stores al THR
--   * Traza de retiro igual que tb_core/tb_cpu, con mtime del CLINT del SoC y las
--     lineas meip/seip del PLIC (el comparador las inyecta en el ISS)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.rv64_pkg.all;

entity tb_soc is
  generic (
    HEX      : string  := "test.hex";
    TRACE    : string  := "trace.txt";
    TOHOST   : integer := 16#1000#;
    ENTRY    : integer := 0;                 -- no se usa: arranca en la boot ROM
    MEM_KB   : integer := 8192;
    MAXLAT   : integer := 1;
    SEED     : integer := 1;
    TIMEOUT  : integer := 4000000;
    TIME_DIV : integer := 4
  );
end entity;

architecture sim of tb_soc is
  constant DRAM : xword := x"0000000080000000";
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin, fin_bus, fin_htif : boolean := false;

  signal awid, arid, bid, rid : std_logic_vector(3 downto 0);
  signal awaddr, araddr, wdata, rdata : xword;
  signal awlen, arlen : std_logic_vector(7 downto 0);
  signal awsize, arsize, awprot, arprot : std_logic_vector(2 downto 0);
  signal awburst, arburst, bresp, rresp : std_logic_vector(1 downto 0);
  signal awcache, arcache : std_logic_vector(3 downto 0);
  signal awvalid, awready, wlast, wvalid, wready, bvalid, bready : std_logic := '0';
  signal arvalid, arready, rlast, rvalid, rready : std_logic := '0';
  signal wstrb : std_logic_vector(7 downto 0);

  signal mm_sel : std_logic_vector(15 downto 0);
  signal mm_req : std_logic;
  signal mm_addr : std_logic_vector(15 downto 0);
  signal mm_wdata : std_logic_vector(31 downto 0);
  signal mm_wstrb : std_logic_vector(3 downto 0);
  signal mm_rdata : std_logic_vector(16 * 32 - 1 downto 0) := (others => '0');
  signal irq_ip : std_logic_vector(15 downto 0) := (others => '0');
  signal us_rdata : std_logic_vector(31 downto 0);
  signal us_irq, us_txd, us_txt, us_rts : std_logic;
  -- DMA del USART (AXI4 32 bit, 40 bit de direccion)
  signal u_awaddr, u_araddr : std_logic_vector(39 downto 0);
  signal u_awlen, u_arlen : std_logic_vector(7 downto 0);
  signal u_awsize, u_arsize : std_logic_vector(2 downto 0);
  signal u_awburst, u_arburst, u_bresp, u_rresp : std_logic_vector(1 downto 0) := "00";
  signal u_awvalid, u_awready, u_wvalid, u_wready, u_wlast, u_bvalid, u_bready : std_logic := '0';
  signal u_arvalid, u_arready, u_rvalid, u_rready, u_rlast : std_logic := '0';
  signal u_wdata, u_rdata : std_logic_vector(31 downto 0);
  signal u_wstrb : std_logic_vector(3 downto 0);
  signal dmaw_v : std_logic := '0';
  signal dmaw_a : xword;
  signal dmaw_s : std_logic_vector(3 downto 0);
  signal dmaw_d : std_logic_vector(31 downto 0);

  signal l_awaddr, l_araddr, l_wdata, l_rdata : std_logic_vector(31 downto 0);
  signal l_awprot, l_arprot : std_logic_vector(2 downto 0);
  signal l_awvalid, l_awready, l_wvalid, l_wready, l_bvalid, l_bready : std_logic := '0';
  signal l_arvalid, l_arready, l_rvalid, l_rready : std_logic := '0';
  signal l_wstrb : std_logic_vector(3 downto 0);
  signal l_bresp, l_rresp : std_logic_vector(1 downto 0) := "00";

  signal uart_line : std_logic;
  signal rvfi_valid, rvfi_trap : std_logic;
  signal rvfi_pc, rvfi_rd_wdata, rvfi_cause, rvfi_tval, rvfi_mem_addr, rvfi_mem_wdata, mtime : xword;
  signal rvfi_insn : std_logic_vector(31 downto 0);
  signal rvfi_rd : std_logic_vector(4 downto 0);
  signal rvfi_mem_wstrb : std_logic_vector(7 downto 0);
  signal rvfi_mip : xword;
begin
  fin <= fin_bus or fin_htif;
  clk <= not clk after 5 ns when not fin;

  dut : entity work.rv64_soc generic map (TICK_DIV => TIME_DIV) port map (
    clk => clk, rst => rst,
    dram_awid => awid, dram_awaddr => awaddr, dram_awlen => awlen, dram_awsize => awsize,
    dram_awburst => awburst, dram_awcache => awcache, dram_awprot => awprot, dram_awvalid => awvalid,
    dram_awready => awready, dram_wdata => wdata, dram_wstrb => wstrb, dram_wlast => wlast,
    dram_wvalid => wvalid, dram_wready => wready, dram_bid => bid, dram_bresp => bresp,
    dram_bvalid => bvalid, dram_bready => bready, dram_arid => arid, dram_araddr => araddr,
    dram_arlen => arlen, dram_arsize => arsize, dram_arburst => arburst, dram_arcache => arcache,
    dram_arprot => arprot, dram_arvalid => arvalid, dram_arready => arready, dram_rid => rid,
    dram_rdata => rdata, dram_rresp => rresp, dram_rlast => rlast, dram_rvalid => rvalid,
    dram_rready => rready,
    mm_sel => mm_sel, mm_req => mm_req, mm_addr => mm_addr, mm_wdata => mm_wdata, mm_wstrb => mm_wstrb,
    mm_rdata => mm_rdata, irq_ip => irq_ip,
    l_awaddr => l_awaddr, l_awprot => l_awprot, l_awvalid => l_awvalid, l_awready => l_awready,
    l_wdata => l_wdata, l_wstrb => l_wstrb, l_wvalid => l_wvalid, l_wready => l_wready,
    l_bresp => l_bresp, l_bvalid => l_bvalid, l_bready => l_bready,
    l_araddr => l_araddr, l_arprot => l_arprot, l_arvalid => l_arvalid, l_arready => l_arready,
    l_rdata => l_rdata, l_rresp => l_rresp, l_rvalid => l_rvalid, l_rready => l_rready,
    uart_tx => uart_line, uart_rx => uart_line,
    rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => rvfi_insn, rvfi_rd => rvfi_rd,
    rvfi_rd_wdata => rvfi_rd_wdata, rvfi_trap => rvfi_trap, rvfi_cause => rvfi_cause,
    rvfi_tval => rvfi_tval, rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
    rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => rvfi_mip, mtime_o => mtime);

  -- ================================================================ USART real (ranura 0)
  usart_u : entity work.usart_axi_top generic map (ADDR_W => 40) port map (
    clk => clk, aresetn => not rst, ddr_base => x"0080000000",
    sel => mm_sel(0), req => mm_req, addr => mm_addr(7 downto 0), wdata => mm_wdata,
    wstrb => mm_wstrb, rdata => us_rdata, irq_out => us_irq,
    m_axi_awaddr => u_awaddr, m_axi_awlen => u_awlen, m_axi_awsize => u_awsize,
    m_axi_awburst => u_awburst, m_axi_awvalid => u_awvalid, m_axi_awready => u_awready,
    m_axi_wdata => u_wdata, m_axi_wstrb => u_wstrb, m_axi_wlast => u_wlast,
    m_axi_wvalid => u_wvalid, m_axi_wready => u_wready,
    m_axi_bresp => u_bresp, m_axi_bvalid => u_bvalid, m_axi_bready => u_bready,
    m_axi_araddr => u_araddr, m_axi_arlen => u_arlen, m_axi_arsize => u_arsize,
    m_axi_arburst => u_arburst, m_axi_arvalid => u_arvalid, m_axi_arready => u_arready,
    m_axi_rdata => u_rdata, m_axi_rresp => u_rresp, m_axi_rlast => u_rlast,
    m_axi_rvalid => u_rvalid, m_axi_rready => u_rready,
    rxd_i => '1', txd_line_i => us_txd, txd_o => us_txd, txd_t => us_txt,
    cts_n_i => '0', rts_n_o => us_rts);
  mm_rdata(31 downto 0) <= us_rdata;
  irq_ip(0) <= us_irq;

  -- ================================================================ esclavo AXI-Lite (16 registros)
  process (clk)
    type regs_t is array (0 to 15) of std_logic_vector(31 downto 0);
    variable regs : regs_t := (others => (others => '0'));
    variable aw_ok, w_ok : boolean := false;
    variable aw_a : std_logic_vector(31 downto 0);
    variable w_d : std_logic_vector(31 downto 0);
    variable w_s : std_logic_vector(3 downto 0);
    variable t : integer := 0;
    variable i : integer;
  begin
    if rising_edge(clk) then
      t := t + 1;
      -- AW y W en ciclos distintos a proposito
      l_awready <= '0'; l_wready <= '0'; l_arready <= '0';
      if l_awvalid = '1' and l_awready = '1' then aw_ok := true; aw_a := l_awaddr; end if;
      if l_wvalid = '1' and l_wready = '1' then w_ok := true; w_d := l_wdata; w_s := l_wstrb; end if;
      if l_awvalid = '1' and not aw_ok and l_awready = '0' and t mod 2 = 0 then l_awready <= '1'; end if;
      if l_wvalid = '1' and not w_ok and l_wready = '0' and t mod 3 = 0 then l_wready <= '1'; end if;
      if aw_ok and w_ok and l_bvalid = '0' then
        i := to_integer(unsigned(aw_a(5 downto 2)));
        for k in 0 to 3 loop
          if w_s(k) = '1' then regs(i)(8 * k + 7 downto 8 * k) := w_d(8 * k + 7 downto 8 * k); end if;
        end loop;
        l_bvalid <= '1'; l_bresp <= "00"; aw_ok := false; w_ok := false;
      end if;
      if l_bvalid = '1' and l_bready = '1' then l_bvalid <= '0'; end if;
      if l_arvalid = '1' and l_arready = '0' and l_rvalid = '0' then l_arready <= '1'; end if;
      if l_arvalid = '1' and l_arready = '1' then
        l_rdata <= regs(to_integer(unsigned(l_araddr(5 downto 2)))) xor x"A5A50000";
        l_rresp <= "00"; l_rvalid <= '1';
      end if;
      if l_rvalid = '1' and l_rready = '1' then l_rvalid <= '0'; end if;
    end if;
  end process;

  -- ================================================================ DRAM (AXI4)
  p_dram : process (clk)
    constant WORDS : integer := MEM_KB * 128;
    -- RAM como pares de enteros de 32 bit: en GHDL un std_logic ocupa 1 byte, asi
    -- 128 MiB de DRAM simulada ocupan 128 MiB y no 1 GiB
    type half_t is array (0 to WORDS - 1) of integer;
    variable ram_lo, ram_hi : half_t;
    variable loaded   : boolean := false;
    file fh           : text;
    variable l        : line;
    variable a64, d64 : std_logic_vector(63 downto 0);
    variable lfsr     : unsigned(31 downto 0) := to_unsigned(SEED * 2654435 + 999, 32);
    variable cyc      : integer := 0;
    variable r_act    : boolean := false;
    variable r_addr   : unsigned(63 downto 0);
    variable r_left, r_size, r_wait : integer := 0;
    variable w_act, b_pend : boolean := false;
    variable w_left : integer := 0;                 -- beats que faltan segun awlen
    variable w_addr   : unsigned(63 downto 0);
    variable w_size, b_wait, ar_wait, aw_wait : integer := 0;
    variable w_err, b_err : boolean := false;
    variable i : integer;
    variable m : xword;
    -- puerto DMA (32 bit)
    variable dr_act, dw_act, db_pend : boolean := false;
    variable dr_addr, dw_addr : unsigned(63 downto 0);
    variable dr_left : integer := 0;
    variable dw : xword;
    impure function rnd return unsigned is
    begin
      lfsr := lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
      return lfsr;
    end function;
    impure function rdelay return integer is
    begin
      if MAXLAT <= 1 then return 0; end if;
      return to_integer(rnd(7 downto 0)) mod MAXLAT;
    end function;
    impure function rd64(i : integer) return std_logic_vector is
      variable r : std_logic_vector(63 downto 0);
    begin
      r(63 downto 32) := std_logic_vector(to_signed(ram_hi(i), 32));
      r(31 downto 0)  := std_logic_vector(to_signed(ram_lo(i), 32));
      return r;
    end function;
    procedure wr64(i : integer; d : std_logic_vector(63 downto 0)) is
    begin
      ram_lo(i) := to_integer(signed(d(31 downto 0)));
      ram_hi(i) := to_integer(signed(d(63 downto 32)));
    end procedure;
    impure function ram_idx(a : unsigned) return integer is
      variable o : unsigned(63 downto 0);
    begin
      o := a - unsigned(DRAM);
      if a >= unsigned(DRAM) and o < to_unsigned(WORDS * 8, 64) then return to_integer(o(31 downto 3)); end if;
      return -1;
    end function;
  begin
    if rising_edge(clk) then
      if not loaded then
        for k in 0 to WORDS - 1 loop ram_lo(k) := 0; ram_hi(k) := 0; end loop;
        file_open(fh, HEX, read_mode);
        while not endfile(fh) loop
          readline(fh, l); hread(l, a64); hread(l, d64);
          wr64(ram_idx(unsigned(a64)), d64);
        end loop;
        file_close(fh);
        loaded := true;
      end if;
      cyc := cyc + 1;
      if cyc = 3 then rst <= '0'; end if;
      if cyc > TIMEOUT then report "TIMEOUT"; fin_bus <= true; end if;
      -- AR / R
      if rvalid = '1' and rready = '1' then
        if r_left = 0 then r_act := false;
        else r_left := r_left - 1; r_addr := r_addr + to_unsigned(r_size, 64); r_wait := rdelay; end if;
        rvalid <= '0';
      end if;
      if arvalid = '1' and arready = '1' then
        r_act := true; r_addr := unsigned(araddr); r_left := to_integer(unsigned(arlen));
        r_size := 2 ** to_integer(unsigned(arsize)); r_wait := rdelay; rid <= arid;
      end if;
      arready <= '0';
      if not r_act and arvalid = '1' and arready = '0' then
        if ar_wait = 0 then arready <= '1'; ar_wait := rdelay; else ar_wait := ar_wait - 1; end if;
      end if;
      if r_act and not (rvalid = '1' and rready = '0') then
        if r_wait = 0 then
          i := ram_idx(r_addr);
          if i >= 0 then rdata <= rd64(i); rresp <= "00"; else rdata <= XZERO; rresp <= "11"; end if;
          if r_left = 0 then rlast <= '1'; else rlast <= '0'; end if;
          rvalid <= '1';
        else
          r_wait := r_wait - 1;
        end if;
      end if;
      -- ---------------------------------------------- puerto DMA del USART (32 bit)
      dmaw_v <= '0';
      if u_rvalid = '1' and u_rready = '1' then
        if dr_left = 0 then dr_act := false; else dr_left := dr_left - 1; dr_addr := dr_addr + 4; end if;
        u_rvalid <= '0';
      end if;
      if u_arvalid = '1' and u_arready = '1' then
        dr_act := true; dr_addr := resize(unsigned(u_araddr), 64); dr_left := to_integer(unsigned(u_arlen));
      end if;
      u_arready <= '0';
      if not dr_act and u_arvalid = '1' and u_arready = '0' then u_arready <= '1'; end if;
      if dr_act and not (u_rvalid = '1' and u_rready = '0') then
        i := ram_idx(dr_addr);
        if i >= 0 then
          if dr_addr(2) = '1' then u_rdata <= rd64(i)(63 downto 32); else u_rdata <= rd64(i)(31 downto 0); end if;
          u_rresp <= "00";
        else
          u_rdata <= (others => '0'); u_rresp <= "11";
        end if;
        if dr_left = 0 then u_rlast <= '1'; else u_rlast <= '0'; end if;
        u_rvalid <= '1';
      end if;
      if u_bvalid = '1' and u_bready = '1' then u_bvalid <= '0'; end if;
      if u_awvalid = '1' and u_awready = '1' then
        dw_act := true; dw_addr := resize(unsigned(u_awaddr), 64);
      end if;
      u_awready <= '0';
      if not dw_act and not db_pend and u_awvalid = '1' and u_awready = '0' then u_awready <= '1'; end if;
      if u_wvalid = '1' and u_wready = '1' then
        i := ram_idx(dw_addr);
        if i >= 0 then
          m := XZERO;
          for k in 0 to 3 loop
            if u_wstrb(k) = '1' then
              if dw_addr(2) = '1' then m(32 + 8 * k + 7 downto 32 + 8 * k) := x"FF";
              else m(8 * k + 7 downto 8 * k) := x"FF"; end if;
            end if;
          end loop;
          dw := u_wdata & u_wdata;
          wr64(i, (rd64(i) and not m) or (dw and m));
          dmaw_v <= '1'; dmaw_a <= std_logic_vector(dw_addr); dmaw_s <= u_wstrb; dmaw_d <= u_wdata;
        end if;
        dw_addr := dw_addr + 4;
        if u_wlast = '1' then dw_act := false; db_pend := true; end if;
      end if;
      u_wready <= '0';
      if dw_act and not (u_wvalid = '1' and u_wready = '1' and u_wlast = '1') then u_wready <= '1'; end if;
      if db_pend and u_bvalid = '0' then u_bvalid <= '1'; u_bresp <= "00"; db_pend := false; end if;

      -- AW / W / B
      if bvalid = '1' and bready = '1' then bvalid <= '0'; end if;
      if awvalid = '1' and awready = '1' then
        w_act := true; w_addr := unsigned(awaddr); w_size := 2 ** to_integer(unsigned(awsize));
        w_err := false; bid <= awid;
        w_left := to_integer(unsigned(awlen));
        assert awlen = x"00" or awburst = "01"
          report "AXI: rafaga de escritura no INCR" severity failure;
      end if;
      awready <= '0';
      if not w_act and not b_pend and awvalid = '1' and awready = '0' then
        if aw_wait = 0 then awready <= '1'; aw_wait := rdelay; else aw_wait := aw_wait - 1; end if;
      end if;
      if wvalid = '1' and wready = '1' then
        i := ram_idx(w_addr);
        for k in 0 to 7 loop m(8 * k + 7 downto 8 * k) := (others => wstrb(k)); end loop;
        if i >= 0 then wr64(i, (rd64(i) and not m) or (wdata and m)); else w_err := true; end if;
        w_addr := w_addr + to_unsigned(w_size, 64);
        assert (wlast = '1') = (w_left = 0)
          report "AXI: wlast no coincide con awlen" severity failure;
        w_left := w_left - 1;
        if wlast = '1' then w_act := false; b_pend := true; b_err := w_err; b_wait := rdelay; end if;
      end if;
      wready <= '0';
      if w_act and not (wvalid = '1' and wready = '1' and wlast = '1') then
        if MAXLAT <= 1 or rnd(3 downto 0) /= "0000" then wready <= '1'; end if;
      end if;
      if b_pend and bvalid = '0' then
        if b_wait = 0 then
          bvalid <= '1'; b_pend := false;
          if b_err then bresp <= "11"; else bresp <= "00"; end if;
        else
          b_wait := b_wait - 1;
        end if;
      end if;
    end if;
  end process;

  -- ================================================================ HTIF y consola
  p_htif : process (clk)
    variable th  : xword := XZERO;
    variable m   : xword;
    variable cyc : integer := 0;
  begin
    if rising_edge(clk) then
      cyc := cyc + 1;
      if rvfi_valid = '1' and rvfi_mem_wstrb /= x"00" then
        if unsigned(rvfi_mem_addr(63 downto 3)) = (unsigned(DRAM(63 downto 3)) + to_unsigned(TOHOST / 8, 61)) then
          for k in 0 to 7 loop m(8 * k + 7 downto 8 * k) := (others => rvfi_mem_wstrb(k)); end loop;
          th := (th and not m) or (rvfi_mem_wdata and m);
          if th(63 downto 48) = x"0000" and th(0) = '1' then
            if th(63 downto 1) = (62 downto 0 => '0') then report "TOHOST PASS ciclos=" & integer'image(cyc);
            else report "TOHOST FAIL codigo=" & integer'image(to_integer(unsigned(th(31 downto 1)))); end if;
            fin_htif <= true;
          end if;
        elsif rvfi_mem_addr = x"0000000010000000" then
          write(output, "" & character'val(to_integer(unsigned(rvfi_mem_wdata(7 downto 0)))));
        end if;
      end if;
    end if;
  end process;

  -- ================================================================ traza
  p_trace : process (clk)
    file ft : text open write_mode is TRACE;
    variable l : line;
  begin
    if rising_edge(clk) then
      if dmaw_v = '1' then                       -- escritura del DMA: el ISS la aplica
        write(l, string'("D ")); hwrite(l, dmaw_a); write(l, string'(" "));
        hwrite(l, dmaw_s); write(l, string'(" ")); hwrite(l, dmaw_d);
        writeline(ft, l);
      end if;
      if rvfi_valid = '1' then
        hwrite(l, rvfi_pc); write(l, string'(" ")); hwrite(l, rvfi_insn); write(l, string'(" "));
        write(l, to_integer(unsigned(rvfi_rd))); write(l, string'(" ")); hwrite(l, rvfi_rd_wdata);
        write(l, string'(" ")); hwrite(l, mtime);
        write(l, string'(" ")); hwrite(l, rvfi_mip(11 downto 0));
        if rvfi_trap = '1' then
          write(l, string'(" T ")); hwrite(l, rvfi_cause); write(l, string'(" ")); hwrite(l, rvfi_tval);
        end if;
        if rvfi_mem_wstrb /= x"00" then
          write(l, string'(" W ")); hwrite(l, rvfi_mem_addr); write(l, string'(" "));
          hwrite(l, rvfi_mem_wstrb); write(l, string'(" ")); hwrite(l, rvfi_mem_wdata);
        end if;
        writeline(ft, l);
      end if;
    end if;
  end process;
end architecture;
