-- tb_cpu.vhd - Capa 3 con caches: rv64_cpu (core + I$ + D$ + AXI4) contra un
-- esclavo AXI4 con retardos aleatorios en los 5 canales.
--   * RAM de MEM_KB en 0x8000_0000 (rafagas INCR, transferencias estrechas)
--   * CLINT y UART por el bus (mismas reglas de tamano que el ISS); DECERR fuera
--   * HTIF: los stores a tohost se observan en la interfaz core -> D$ (con
--     write-back nunca llegarian al bus), via nombres externos VHDL-2008
--   * Traza de retiro identica a tb_core (compare.py --tb cpu)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.rv64_pkg.all;

entity tb_cpu is
  generic (
    HEX      : string  := "test.hex";
    TRACE    : string  := "trace.txt";
    TOHOST   : integer := 16#1000#;
    ENTRY    : integer := 0;
    MEM_KB   : integer := 8192;
    MAXLAT   : integer := 1;
    SEED     : integer := 1;
    TIMEOUT  : integer := 4000000;
    TIME_DIV : integer := 4
  );
end entity;

architecture sim of tb_cpu is
  constant DRAM : xword := x"0000000080000000";
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin : boolean := false;
  signal fin_bus, fin_htif : boolean := false;
  signal mtip, msip : std_logic := '0';
  signal mtime : xword := XZERO;

  signal awid, arid, bid, rid : std_logic_vector(3 downto 0);
  signal awaddr, araddr, wdata, rdata : xword;
  signal awlen, arlen : std_logic_vector(7 downto 0);
  signal awsize, arsize, awprot, arprot : std_logic_vector(2 downto 0);
  signal awburst, arburst, bresp, rresp : std_logic_vector(1 downto 0);
  signal awcache, arcache : std_logic_vector(3 downto 0);
  signal awvalid, awready, wlast, wvalid, wready, bvalid, bready : std_logic := '0';
  signal arvalid, arready, rlast, rvalid, rready : std_logic := '0';
  signal wstrb : std_logic_vector(7 downto 0);

  signal rvfi_valid, rvfi_trap : std_logic;
  signal rvfi_pc, rvfi_rd_wdata, rvfi_cause, rvfi_tval : xword;
  signal rvfi_insn : std_logic_vector(31 downto 0);
  signal rvfi_rd : std_logic_vector(4 downto 0);
  signal rvfi_mem_addr, rvfi_mem_wdata : xword;
  signal rvfi_mem_wstrb : std_logic_vector(7 downto 0);
  signal rvfi_mip : xword;
begin
  fin <= fin_bus or fin_htif;
  clk <= not clk after 5 ns when not fin;

  dut : entity work.rv64_cpu
    generic map (RESET_PC => std_logic_vector(unsigned(DRAM) + to_unsigned(ENTRY, 64)))
    port map (
      clk => clk, rst => rst, mtip => mtip, msip => msip, meip => '0', seip => '0', time_i => mtime,
      m_awid => awid, m_awaddr => awaddr, m_awlen => awlen, m_awsize => awsize, m_awburst => awburst,
      m_awcache => awcache, m_awprot => awprot, m_awvalid => awvalid, m_awready => awready,
      m_wdata => wdata, m_wstrb => wstrb, m_wlast => wlast, m_wvalid => wvalid, m_wready => wready,
      m_bid => bid, m_bresp => bresp, m_bvalid => bvalid, m_bready => bready,
      m_arid => arid, m_araddr => araddr, m_arlen => arlen, m_arsize => arsize, m_arburst => arburst,
      m_arcache => arcache, m_arprot => arprot, m_arvalid => arvalid, m_arready => arready,
      m_rid => rid, m_rdata => rdata, m_rresp => rresp, m_rlast => rlast, m_rvalid => rvalid,
      m_rready => rready,
      rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => rvfi_insn, rvfi_rd => rvfi_rd,
      rvfi_rd_wdata => rvfi_rd_wdata, rvfi_trap => rvfi_trap, rvfi_cause => rvfi_cause,
      rvfi_tval => rvfi_tval, rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
      rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => rvfi_mip);

  -- ================================================================ esclavo AXI4
  p_slave : process (clk)
    constant WORDS : integer := MEM_KB * 128;
    type ram_t is array (0 to WORDS - 1) of std_logic_vector(63 downto 0);
    variable ram      : ram_t;
    variable loaded   : boolean := false;
    file fh           : text;
    variable l        : line;
    variable a64, d64 : std_logic_vector(63 downto 0);
    variable lfsr     : unsigned(31 downto 0) := to_unsigned(SEED * 2654435 + 777, 32);
    variable cyc      : integer := 0;
    -- CLINT
    variable msip_r   : std_logic := '0';
    variable mtimecmp : unsigned(63 downto 0) := (others => '1');
    variable mtime_v  : unsigned(63 downto 0) := (others => '0');
    -- lectura
    variable r_act    : boolean := false;
    variable r_addr   : unsigned(63 downto 0);
    variable r_left   : integer;
    variable r_size   : integer;
    variable r_wait   : integer := 0;
    variable r_shown  : boolean := false;
    -- escritura
    variable w_act    : boolean := false;
    variable w_addr   : unsigned(63 downto 0);
    variable w_size   : integer;
    variable w_err    : boolean;
    variable b_pend   : boolean := false;
    variable b_wait   : integer := 0;
    variable b_err    : boolean;
    variable w_left   : integer := 0;               -- beats que faltan segun awlen
    variable ar_wait, aw_wait : integer := 0;

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
    impure function ram_idx(a : unsigned) return integer is
      variable o : unsigned(63 downto 0);
    begin
      o := a - unsigned(DRAM);
      if a >= unsigned(DRAM) and o < to_unsigned(WORDS * 8, 64) then
        return to_integer(o(31 downto 3));
      end if;
      return -1;
    end function;
    -- lectura de un beat; ok=false -> DECERR
    procedure bus_rd(a : unsigned; sz : integer; d : out xword; ok : out boolean) is
      variable i : integer;
      variable off : unsigned(63 downto 0);
    begin
      i := ram_idx(a); d := XZERO; ok := true;
      if i >= 0 then
        d := ram(i);
      elsif a >= x"0000000002000000" and a < x"0000000002010000" and (sz = 4 or sz = 8) then
        off := a - x"0000000002000000";
        case to_integer(off(15 downto 3)) is
          when 0 => d := (0 => msip_r, others => '0');
          when 16#800# => d := std_logic_vector(mtimecmp);
          when 16#17FF# => d := std_logic_vector(mtime_v);
          when others => d := XZERO;
        end case;
      elsif a >= x"0000000010000000" and a < x"0000000010001000" and sz = 1 then
        if a(11 downto 0) = x"005" then
          d := std_logic_vector(shift_left(to_unsigned(16#60#, 64), 8 * to_integer(a(2 downto 0))));
        end if;
      else
        ok := false;
      end if;
    end procedure;
    procedure bus_wr(a : unsigned; sz : integer; d : xword; s : std_logic_vector(7 downto 0); ok : out boolean) is
      variable i : integer;
      variable m, old, nw : xword;
      variable off : unsigned(63 downto 0);
    begin
      for k in 0 to 7 loop m(8 * k + 7 downto 8 * k) := (others => s(k)); end loop;
      i := ram_idx(a); ok := true;
      if i >= 0 then
        ram(i) := (ram(i) and not m) or (d and m);
      elsif a >= x"0000000002000000" and a < x"0000000002010000" and (sz = 4 or sz = 8) then
        off := a - x"0000000002000000";
        case to_integer(off(15 downto 3)) is
          when 0 => old := (0 => msip_r, others => '0');
          when 16#800# => old := std_logic_vector(mtimecmp);
          when 16#17FF# => old := std_logic_vector(mtime_v);
          when others => old := XZERO;
        end case;
        nw := (old and not m) or (d and m);
        case to_integer(off(15 downto 3)) is
          when 0 => msip_r := nw(0);
          when 16#800# => mtimecmp := unsigned(nw);
          when 16#17FF# => mtime_v := unsigned(nw);
          when others => null;
        end case;
      elsif a >= x"0000000010000000" and a < x"0000000010001000" and sz = 1 then
        if a(11 downto 0) = x"000" then
          write(output, "" & character'val(to_integer(unsigned(d(7 downto 0)))));
        end if;
      else
        ok := false;
      end if;
    end procedure;

    variable d : xword;
    variable ok : boolean;
  begin
    if rising_edge(clk) then
      if not loaded then
        for k in 0 to WORDS - 1 loop ram(k) := XZERO; end loop;
        file_open(fh, HEX, read_mode);
        while not endfile(fh) loop
          readline(fh, l); hread(l, a64); hread(l, d64);
          ram(ram_idx(unsigned(a64))) := d64;
        end loop;
        file_close(fh);
        loaded := true;
      end if;
      cyc := cyc + 1;
      if cyc = 3 then rst <= '0'; end if;
      if cyc > TIMEOUT then report "TIMEOUT"; fin_bus <= true; end if;
      if cyc mod TIME_DIV = 0 then mtime_v := mtime_v + 1; end if;
      mtime <= std_logic_vector(mtime_v);
      if mtime_v >= mtimecmp then mtip <= '1'; else mtip <= '0'; end if;
      msip <= msip_r;

      -- ---------------------------------------------- AR / R
      if rvalid = '1' and rready = '1' then
        if r_left = 0 then
          r_act := false;
        else
          r_left := r_left - 1;
          r_addr := r_addr + to_unsigned(r_size, 64);
          r_wait := rdelay;
        end if;
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
          bus_rd(r_addr, r_size, d, ok);
          rdata <= d;
          if ok then rresp <= "00"; else rresp <= "11"; end if;
          if r_left = 0 then rlast <= '1'; else rlast <= '0'; end if;
          rvalid <= '1';
        else
          r_wait := r_wait - 1;
        end if;
      end if;

      -- ---------------------------------------------- AW / W / B
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
        bus_wr(w_addr, w_size, wdata, wstrb, ok);
        if not ok then w_err := true; end if;
        w_addr := w_addr + to_unsigned(w_size, 64);
        -- protocolo: wlast exactamente en el beat awlen+1
        assert (wlast = '1') = (w_left = 0)
          report "AXI: wlast no coincide con awlen" severity failure;
        w_left := w_left - 1;
        if wlast = '1' then
          w_act := false; b_pend := true; b_err := w_err; b_wait := rdelay;
        end if;
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

  -- ================================================================ HTIF (stores retirados)
  -- Con write-back el store a tohost nunca llega al bus: se observa en el retiro
  -- (rvfi_mem_*), que ademas es el punto arquitectonico correcto.
  p_htif : process (clk)
    variable th  : xword := XZERO;
    variable m   : xword;
    variable cyc : integer := 0;
  begin
    if rising_edge(clk) then
      cyc := cyc + 1;
      if rvfi_valid = '1' and rvfi_mem_wstrb /= x"00" and
         unsigned(rvfi_mem_addr(63 downto 3)) = (unsigned(DRAM(63 downto 3)) + to_unsigned(TOHOST / 8, 61)) then
        for k in 0 to 7 loop m(8 * k + 7 downto 8 * k) := (others => rvfi_mem_wstrb(k)); end loop;
        th := (th and not m) or (rvfi_mem_wdata and m);
        if th(63 downto 48) = x"0000" and th(0) = '1' then
          if th(63 downto 1) = (62 downto 0 => '0') then report "TOHOST PASS ciclos=" & integer'image(cyc);
          else report "TOHOST FAIL codigo=" & integer'image(to_integer(unsigned(th(31 downto 1)))); end if;
          fin_htif <= true;
        elsif th(63 downto 48) = x"0101" then
          write(output, "" & character'val(to_integer(unsigned(th(7 downto 0)))));
          th := XZERO;
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
