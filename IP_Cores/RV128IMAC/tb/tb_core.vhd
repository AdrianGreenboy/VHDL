-- tb_core.vhd (RV128IMAC) - Capas 2/3: core con modelo de memoria de dos puertos.
-- Derivado de RV64IMAC/tb/tb_core.vhd con el puerto de datos a 128 bit.
--  * RAM de MEM_KB a partir de 0x8000_0000, cargada desde un .hex (addr64 data128)
--  * Latencia aleatoria 1..MAXLAT por puerto y ready aleatorio (MAXLAT>1 = capa 3)
--  * CLINT (msip/mtimecmp/mtime) y UART minima, con las mismas reglas de acceso
--    que el Bus de iss128.py (CLINT 4/8 bytes, UART 1 byte; resto -> error)
--  * PLIC (4 bytes), ranuras MMIO y ventana AXI-Lite (1..8 bytes) como stubs, igual que
--    STUB_REGIONS de iss64/iss128: leen 0 y descartan escrituras (Zephyr programa el PLIC)
--  * HTIF de riscv-tests en TOHOST: fin con codigo, putchar
--  * Traza de retiro en TRACE para el comparador lockstep (compare128.py):
--    pc insn rd val time mip [T cause tval] [W addr wstrb16 wdata]
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.rv128_pkg.all;

entity tb_core is
  generic (
    HEX      : string  := "test.hex";
    TRACE    : string  := "trace.txt";
    TOHOST   : integer := 16#1000#;          -- desplazamiento desde 0x8000_0000
    ENTRY    : integer := 0;                 -- punto de entrada, desplazamiento desde 0x8000_0000
    MEM_KB   : integer := 4096;
    MAXLAT   : integer := 1;
    SEED     : integer := 1;
    TIMEOUT  : integer := 2000000;
    TIME_DIV : integer := 4;
    XLEN64   : boolean := false             -- true: el core arranca en modo RV64
  );
end entity;

architecture sim of tb_core is
  constant DRAM : xword := (31 => '1', others => '0');
  subtype w128 is std_logic_vector(127 downto 0);
  constant Z128 : w128 := (others => '0');
  signal clk : std_logic := '0';
  signal m64 : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin : boolean := false;

  signal i_req_valid, i_req_ready, i_rsp_valid, i_rsp_err : std_logic := '0';
  signal i_req_addr : xword;
  signal i_rsp_data : std_logic_vector(31 downto 0);
  signal d_req_valid, d_req_ready, d_rsp_valid, d_rsp_err : std_logic := '0';
  signal d_req_addr, d_req_wdata, d_rsp_rdata : xword;
  signal d_req_kind : std_logic_vector(1 downto 0);
  signal d_req_size : std_logic_vector(2 downto 0);
  signal d_req_amo_op : std_logic_vector(4 downto 0);
  signal d_req_wstrb : std_logic_vector(15 downto 0);
  signal mtip, msip : std_logic := '0';
  signal mtime : std_logic_vector(63 downto 0) := (others => '0');
  signal fencei : std_logic;
  signal rvfi_valid, rvfi_trap : std_logic;
  signal rvfi_pc, rvfi_rd_wdata, rvfi_cause, rvfi_tval : xword;
  signal rvfi_insn : std_logic_vector(31 downto 0);
  signal rvfi_rd : std_logic_vector(4 downto 0);
  signal rvfi_mem_addr, rvfi_mem_wdata : xword;
  signal rvfi_mem_wstrb : std_logic_vector(15 downto 0);
  signal rvfi_mip : std_logic_vector(11 downto 0);

  signal i_pend, d_pend : std_logic := '0';
  signal i_cnt, d_cnt   : integer := 0;
  signal i_data_r       : std_logic_vector(31 downto 0);
  signal i_err_r        : std_logic;
  signal d_data_r       : xword;
  signal d_err_r        : std_logic;
  signal rnd_i, rnd_d   : std_logic := '1';
begin
  clk <= not clk after 5 ns when not fin;
  m64 <= '1' when XLEN64 else '0';

  dut : entity work.rv128_core
    generic map (RESET_PC => std_logic_vector(unsigned(DRAM) + to_unsigned(ENTRY, XLEN)))
    port map (
      clk => clk, rst => rst, m64 => m64,
      i_req_valid => i_req_valid, i_req_ready => i_req_ready, i_req_addr => i_req_addr,
      i_rsp_valid => i_rsp_valid, i_rsp_data => i_rsp_data, i_rsp_err => i_rsp_err,
      d_req_valid => d_req_valid, d_req_ready => d_req_ready, d_req_addr => d_req_addr,
      d_req_kind => d_req_kind, d_req_amo_op => d_req_amo_op, d_req_size => d_req_size,
      d_req_wdata => d_req_wdata, d_req_wstrb => d_req_wstrb,
      d_rsp_valid => d_rsp_valid, d_rsp_rdata => d_rsp_rdata, d_rsp_err => d_rsp_err,
      mtip => mtip, msip => msip, meip => '0', seip => '0', time_i => mtime,
      fencei_o => fencei, sfence_o => open,
      rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => rvfi_insn, rvfi_rd => rvfi_rd,
      rvfi_rd_wdata => rvfi_rd_wdata, rvfi_trap => rvfi_trap, rvfi_cause => rvfi_cause,
      rvfi_tval => rvfi_tval, rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
      rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => rvfi_mip);

  i_req_ready <= rnd_i when (i_pend = '0' or i_cnt = 0) else '0';
  d_req_ready <= rnd_d when (d_pend = '0' or d_cnt = 0) else '0';
  i_rsp_valid <= '1' when i_pend = '1' and i_cnt = 0 else '0';
  d_rsp_valid <= '1' when d_pend = '1' and d_cnt = 0 else '0';
  i_rsp_data <= i_data_r; i_rsp_err <= i_err_r;
  d_rsp_rdata <= d_data_r; d_rsp_err <= d_err_r;

  process (clk)
    constant WORDS : integer := MEM_KB * 64;                 -- palabras de 16 bytes
    type ram_t is array (0 to WORDS - 1) of w128;
    variable ram       : ram_t;
    variable loaded    : boolean := false;
    file fh            : text;
    variable l         : line;
    variable a64       : std_logic_vector(63 downto 0);
    variable d128      : w128;
    variable lfsr      : unsigned(31 downto 0) := to_unsigned(SEED * 2654435 + 12345, 32);
    variable msip_r    : std_logic := '0';
    variable mtimecmp  : unsigned(63 downto 0) := (others => '1');
    variable mtime_v   : unsigned(63 downto 0) := (others => '0');
    variable cyc       : integer := 0;
    variable old, nw, wd, m : w128;
    variable idx       : integer;
    variable lane      : integer range 0 to 15;
    variable off       : unsigned(31 downto 0);
    variable creg      : std_logic_vector(63 downto 0);
    variable cm, cw    : std_logic_vector(63 downto 0);
    variable lat       : integer;
    variable sz        : integer;
    variable so, sb    : signed(127 downto 0);
    variable uo, ub    : unsigned(127 downto 0);
    variable sh        : unsigned(127 downto 0);

    impure function rnd return unsigned is
    begin
      lfsr := lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
      return lfsr;
    end function;

    impure function ram_idx(a : xword) return integer is
      variable o : unsigned(127 downto 0);
    begin
      o := unsigned(a) - unsigned(DRAM);
      if unsigned(a) >= unsigned(DRAM) and o < to_unsigned(WORDS * 16, 128) then
        return to_integer(o(31 downto 4));
      end if;
      return -1;
    end function;

    procedure htif(v : std_logic_vector(63 downto 0)) is
    begin
      if v(63 downto 48) = x"0000" and v(0) = '1' then
        if v(63 downto 1) = (62 downto 0 => '0') then
          report "TOHOST PASS ciclos=" & integer'image(cyc);
        else
          report "TOHOST FAIL codigo=" & integer'image(to_integer(unsigned(v(31 downto 1))));
        end if;
        fin <= true;
      elsif v(63 downto 48) = x"0101" then
        write(output, "" & character'val(to_integer(unsigned(v(7 downto 0)))));
      elsif v /= (63 downto 0 => '0') then
        report "TOHOST syscall no soportado v=" & to_hstring(v);
        fin <= true;
      end if;
    end procedure;
  begin
    if rising_edge(clk) then
      if not loaded then
        for k in 0 to WORDS - 1 loop ram(k) := Z128; end loop;
        file_open(fh, HEX, read_mode);
        while not endfile(fh) loop
          readline(fh, l);
          hread(l, a64); hread(l, d128);
          ram(ram_idx((127 downto 64 => '0') & a64)) := d128;
        end loop;
        file_close(fh);
        loaded := true;
      end if;
      cyc := cyc + 1;
      if cyc = 3 then rst <= '0'; end if;
      if cyc > TIMEOUT then
        report "TIMEOUT" severity note;
        fin <= true;
      end if;

      -- CLINT
      if cyc mod TIME_DIV = 0 then mtime_v := mtime_v + 1; end if;
      mtime <= std_logic_vector(mtime_v);
      if mtime_v >= mtimecmp then mtip <= '1'; else mtip <= '0'; end if;
      msip <= msip_r;

      if MAXLAT > 1 then
        rnd_i <= rnd(0) or rnd(1);
        rnd_d <= rnd(2) or rnd(3);
      end if;

      -- -------------------------------------------- puerto I
      if i_pend = '1' and i_cnt = 0 then i_pend <= '0'; end if;
      if i_pend = '1' and i_cnt > 0 then i_cnt <= i_cnt - 1; end if;
      if i_req_valid = '1' and i_req_ready = '1' then
        idx := ram_idx(i_req_addr);
        if idx >= 0 then
          d128 := ram(idx);
          case i_req_addr(3 downto 2) is
            when "00"   => i_data_r <= d128(31 downto 0);
            when "01"   => i_data_r <= d128(63 downto 32);
            when "10"   => i_data_r <= d128(95 downto 64);
            when others => i_data_r <= d128(127 downto 96);
          end case;
          i_err_r <= '0';
        else
          i_data_r <= x"00000000"; i_err_r <= '1';
        end if;
        lat := 1;
        if MAXLAT > 1 then lat := 1 + to_integer(rnd(7 downto 0)) mod MAXLAT; end if;
        i_pend <= '1'; i_cnt <= lat - 1;
      end if;

      -- -------------------------------------------- puerto D
      if d_pend = '1' and d_cnt = 0 then d_pend <= '0'; end if;
      if d_pend = '1' and d_cnt > 0 then d_cnt <= d_cnt - 1; end if;
      if d_req_valid = '1' and d_req_ready = '1' then
        idx := ram_idx(d_req_addr);
        sz := 2 ** to_integer(unsigned(d_req_size));
        lane := to_integer(unsigned(d_req_addr(3 downto 0)));
        d_err_r <= '0'; d_data_r <= XZERO;
        m := Z128;
        for k in 0 to 15 loop
          if d_req_wstrb(k) = '1' then m(8 * k + 7 downto 8 * k) := x"FF"; end if;
        end loop;
        if idx >= 0 then
          old := ram(idx);
          if d_req_kind = "00" then
            d_data_r <= old;
          elsif d_req_kind = "01" then
            ram(idx) := (old and not m) or (d_req_wdata and m);
            if idx = TOHOST / 16 then
              if (TOHOST mod 16) = 0 then htif(ram(idx)(63 downto 0)); else htif(ram(idx)(127 downto 64)); end if;
            end if;
          elsif d_req_kind = "11" then
            d_data_r <= old;                                 -- Zicbom: sin caches, sin efecto
          else
            -- AMO sobre el carril (W: 32 bit, D: 64 bit, Q: 128 bit)
            sh := shift_right(unsigned(old), 8 * lane);
            wd := std_logic_vector(shift_right(unsigned(d_req_wdata), 8 * lane));
            if sz = 4 then
              so := resize(signed(sh(31 downto 0)), 128); sb := resize(signed(wd(31 downto 0)), 128);
              uo := resize(sh(31 downto 0), 128);         ub := resize(unsigned(wd(31 downto 0)), 128);
            elsif sz = 8 then
              so := resize(signed(sh(63 downto 0)), 128); sb := resize(signed(wd(63 downto 0)), 128);
              uo := resize(sh(63 downto 0), 128);         ub := resize(unsigned(wd(63 downto 0)), 128);
            else
              so := signed(sh); sb := signed(wd); uo := sh; ub := unsigned(wd);
            end if;
            case d_req_amo_op is
              when "00000" => nw := std_logic_vector(uo + ub);
              when "00001" => nw := std_logic_vector(ub);
              when "00100" => nw := std_logic_vector(uo xor ub);
              when "01000" => nw := std_logic_vector(uo or ub);
              when "01100" => nw := std_logic_vector(uo and ub);
              when "10000" => if so < sb then nw := std_logic_vector(so); else nw := std_logic_vector(sb); end if;
              when "10100" => if so > sb then nw := std_logic_vector(so); else nw := std_logic_vector(sb); end if;
              when "11000" => if uo < ub then nw := std_logic_vector(uo); else nw := std_logic_vector(ub); end if;
              when others  => if uo > ub then nw := std_logic_vector(uo); else nw := std_logic_vector(ub); end if;
            end case;
            nw := std_logic_vector(shift_left(unsigned(nw), 8 * lane));
            ram(idx) := (old and not m) or (nw and m);
            d_data_r <= old;
          end if;
        elsif d_req_addr(127 downto 32) = (127 downto 32 => '0')
              and unsigned(d_req_addr(31 downto 0)) >= x"02000000" and unsigned(d_req_addr(31 downto 0)) < x"02010000"
              and (sz = 4 or sz = 8) and d_req_kind /= "10" then
          -- CLINT (registros de 64 bit; la palabra de 128 lleva dos)
          off := unsigned(d_req_addr(31 downto 0)) - x"02000000";
          case to_integer(off(15 downto 3)) is
            when 0        => creg := (0 => msip_r, others => '0');
            when 16#800#  => creg := std_logic_vector(mtimecmp);
            when 16#17FF# => creg := std_logic_vector(mtime_v);
            when others   => creg := (others => '0');
          end case;
          if d_req_kind = "00" then
            if d_req_addr(3) = '1' then d_data_r <= creg & (63 downto 0 => '0');
            else d_data_r <= (127 downto 64 => '0') & creg; end if;
          else
            if d_req_addr(3) = '1' then cm := m(127 downto 64); cw := d_req_wdata(127 downto 64);
            else cm := m(63 downto 0); cw := d_req_wdata(63 downto 0); end if;
            creg := (creg and not cm) or (cw and cm);
            case to_integer(off(15 downto 3)) is
              when 0        => msip_r := creg(0);
              when 16#800#  => mtimecmp := unsigned(creg);
              when 16#17FF# => mtime_v := unsigned(creg);
              when others   => null;
            end case;
          end if;
        elsif d_req_addr(127 downto 32) = (127 downto 32 => '0')
              and unsigned(d_req_addr(31 downto 0)) >= x"10000000" and unsigned(d_req_addr(31 downto 0)) < x"10001000"
              and sz = 1 and d_req_kind /= "10" then
          -- UART
          if d_req_kind = "00" then
            if d_req_addr(11 downto 0) = x"005" then
              d_data_r <= std_logic_vector(shift_left(to_unsigned(16#60#, 128), 8 * lane));
            end if;
          elsif d_req_addr(11 downto 0) = x"000" then
            write(output, "" & character'val(to_integer(unsigned(d_req_wdata(7 downto 0)))));
          end if;
        elsif d_req_addr(127 downto 32) = (127 downto 32 => '0') and (d_req_kind = "00" or d_req_kind = "01") and
              ((unsigned(d_req_addr(31 downto 0)) >= x"0C000000" and unsigned(d_req_addr(31 downto 0)) < x"10000000" and sz = 4) or
               (unsigned(d_req_addr(31 downto 0)) >= x"10010000" and unsigned(d_req_addr(31 downto 0)) < x"10110000" and sz <= 8) or
               (unsigned(d_req_addr(31 downto 0)) >= x"20000000" and unsigned(d_req_addr(31 downto 0)) < x"30000000" and sz <= 8)) then
          -- PLIC / MMIO slots / AXI-Lite: same stubs as the ISS STUB_REGIONS (reads 0, writes
          -- dropped; the lockstep copies stub loads from the RTL)
          null;
        else
          d_err_r <= '1';
        end if;
        lat := 1;
        if MAXLAT > 1 then lat := 1 + to_integer(rnd(15 downto 8)) mod MAXLAT; end if;
        d_pend <= '1'; d_cnt <= lat - 1;
      end if;
    end if;
  end process;

  -- traza de retiro
  process (clk)
    file ft : text open write_mode is TRACE;
    variable l : line;
  begin
    if rising_edge(clk) then
      if rvfi_valid = '1' then
        hwrite(l, rvfi_pc); write(l, string'(" ")); hwrite(l, rvfi_insn); write(l, string'(" "));
        write(l, to_integer(unsigned(rvfi_rd))); write(l, string'(" ")); hwrite(l, rvfi_rd_wdata);
        write(l, string'(" ")); hwrite(l, mtime);
        write(l, string'(" ")); hwrite(l, rvfi_mip);
        if rvfi_trap = '1' then
          write(l, string'(" T ")); hwrite(l, rvfi_cause); write(l, string'(" ")); hwrite(l, rvfi_tval);
        end if;
        if rvfi_mem_wstrb /= x"0000" then
          write(l, string'(" W ")); hwrite(l, rvfi_mem_addr); write(l, string'(" "));
          hwrite(l, rvfi_mem_wstrb); write(l, string'(" ")); hwrite(l, rvfi_mem_wdata);
        end if;
        writeline(ft, l);
      end if;
    end if;
  end process;
end architecture;
