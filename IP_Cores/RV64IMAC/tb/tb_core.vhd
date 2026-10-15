-- tb_core.vhd - Capas 2/3: core con modelo de memoria de dos puertos.
--  * RAM de MEM_KB a partir de 0x8000_0000, cargada desde un .hex (addr data64)
--  * Latencia aleatoria 1..MAXLAT por puerto y ready aleatorio (MAXLAT>1 = capa 3)
--  * CLINT (msip/mtimecmp/mtime) y UART minima, con las mismas reglas de acceso
--    que el Bus de iss64.py (CLINT 4/8 bytes, UART 1 byte; resto -> error)
--  * HTIF de riscv-tests en TOHOST: fin con codigo, putchar
--  * Traza de retiro en TRACE para el comparador lockstep (compare.py)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.rv64_pkg.all;

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
    TIME_DIV : integer := 4
  );
end entity;

architecture sim of tb_core is
  constant XWORD_DRAM : xword := x"0000000080000000";
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin : boolean := false;

  signal i_req_valid, i_req_ready, i_rsp_valid, i_rsp_err : std_logic := '0';
  signal i_req_addr : xword;
  signal i_rsp_data : std_logic_vector(31 downto 0);
  signal d_req_valid, d_req_ready, d_rsp_valid, d_rsp_err : std_logic := '0';
  signal d_req_addr, d_req_wdata, d_rsp_rdata : xword;
  signal d_req_kind, d_req_size : std_logic_vector(1 downto 0);
  signal d_req_amo_op : std_logic_vector(4 downto 0);
  signal d_req_wstrb : std_logic_vector(7 downto 0);
  signal mtip, msip : std_logic := '0';
  signal mtime : xword := XZERO;
  signal fencei, sfence : std_logic;
  signal rvfi_valid, rvfi_trap : std_logic;
  signal rvfi_pc, rvfi_rd_wdata, rvfi_cause, rvfi_tval : xword;
  signal rvfi_insn : std_logic_vector(31 downto 0);
  signal rvfi_rd : std_logic_vector(4 downto 0);
  signal rvfi_mem_addr, rvfi_mem_wdata : xword;
  signal rvfi_mem_wstrb : std_logic_vector(7 downto 0);
  signal rvfi_mip : xword;

  -- respuesta registrada por puerto
  signal i_pend, d_pend : std_logic := '0';
  signal i_cnt, d_cnt   : integer := 0;
  signal i_data_r       : std_logic_vector(31 downto 0);
  signal i_err_r        : std_logic;
  signal d_data_r       : xword;
  signal d_err_r        : std_logic;
  signal rnd_i, rnd_d   : std_logic := '1';
begin
  clk <= not clk after 5 ns when not fin;

  dut : entity work.rv64_core
    generic map (RESET_PC => std_logic_vector(unsigned(XWORD_DRAM) + to_unsigned(ENTRY, 64)))
    port map (
      clk => clk, rst => rst,
      i_req_valid => i_req_valid, i_req_ready => i_req_ready, i_req_addr => i_req_addr,
      i_rsp_valid => i_rsp_valid, i_rsp_data => i_rsp_data, i_rsp_err => i_rsp_err,
      d_req_valid => d_req_valid, d_req_ready => d_req_ready, d_req_addr => d_req_addr,
      d_req_kind => d_req_kind, d_req_amo_op => d_req_amo_op, d_req_size => d_req_size,
      d_req_wdata => d_req_wdata, d_req_wstrb => d_req_wstrb,
      d_rsp_valid => d_rsp_valid, d_rsp_rdata => d_rsp_rdata, d_rsp_err => d_rsp_err,
      mtip => mtip, msip => msip, meip => '0', seip => '0', time_i => mtime,
      fencei_o => fencei, sfence_o => sfence,
      rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => rvfi_insn, rvfi_rd => rvfi_rd,
      rvfi_rd_wdata => rvfi_rd_wdata, rvfi_trap => rvfi_trap, rvfi_cause => rvfi_cause,
      rvfi_tval => rvfi_tval, rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
      rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => rvfi_mip);

  -- ready: libre o entregando respuesta este ciclo, con huecos aleatorios
  i_req_ready <= rnd_i when (i_pend = '0' or i_cnt = 0) else '0';
  d_req_ready <= rnd_d when (d_pend = '0' or d_cnt = 0) else '0';
  i_rsp_valid <= '1' when i_pend = '1' and i_cnt = 0 else '0';
  d_rsp_valid <= '1' when d_pend = '1' and d_cnt = 0 else '0';
  i_rsp_data <= i_data_r; i_rsp_err <= i_err_r;
  d_rsp_rdata <= d_data_r; d_rsp_err <= d_err_r;

  process (clk)
    constant WORDS : integer := MEM_KB * 128;
    type ram_t is array (0 to WORDS - 1) of std_logic_vector(63 downto 0);
    variable ram       : ram_t;
    variable loaded    : boolean := false;
    file fh            : text;
    variable l         : line;
    variable a64, d64  : std_logic_vector(63 downto 0);
    variable lfsr      : unsigned(31 downto 0) := to_unsigned(SEED * 2654435 + 12345, 32);
    variable msip_r    : std_logic := '0';
    variable mtimecmp  : unsigned(63 downto 0) := (others => '1');
    variable mtime_v   : unsigned(63 downto 0) := (others => '0');
    variable cyc       : integer := 0;
    variable old, nw, wd, m : std_logic_vector(63 downto 0);
    variable idx       : integer;
    variable ok        : boolean;
    variable off       : unsigned(63 downto 0);
    variable lat       : integer;
    variable sz        : integer;
    variable bits      : integer;
    variable so, sb    : signed(63 downto 0);
    variable uo, ub    : unsigned(63 downto 0);

    impure function rnd return unsigned is
    begin
      lfsr := lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
      return lfsr;
    end function;

    impure function ram_idx(a : xword) return integer is
      variable o : unsigned(63 downto 0);
    begin
      o := unsigned(a) - x"0000000080000000";
      if unsigned(a) >= x"0000000080000000" and o < to_unsigned(WORDS * 8, 64) then
        return to_integer(o(31 downto 3));
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
      elsif v /= XZERO then
        report "TOHOST syscall no soportado (fallo en entorno v) v=" & to_hstring(v);
        fin <= true;
      end if;
    end procedure;
  begin
    if rising_edge(clk) then
      if not loaded then
        for k in 0 to WORDS - 1 loop ram(k) := XZERO; end loop;
        file_open(fh, HEX, read_mode);
        while not endfile(fh) loop
          readline(fh, l);
          hread(l, a64); hread(l, d64);
          ram(ram_idx(a64)) := d64;
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

      -- ready aleatorio
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
          d64 := ram(idx);
          if i_req_addr(2) = '1' then i_data_r <= d64(63 downto 32); else i_data_r <= d64(31 downto 0); end if;
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
        d_err_r <= '0'; d_data_r <= XZERO;
        m := XZERO;
        for k in 0 to 7 loop
          if d_req_wstrb(k) = '1' then m(8 * k + 7 downto 8 * k) := x"FF"; end if;
        end loop;
        if idx >= 0 then
          old := ram(idx);
          if d_req_kind = "00" then
            d_data_r <= old;
          elsif d_req_kind = "01" then
            ram(idx) := (old and not m) or (d_req_wdata and m);
            if idx = TOHOST / 8 then htif(ram(idx)); end if;
          elsif d_req_kind = "11" then
            null;                                     -- cbo.*: sin cache, no-op
          else
            -- AMO sobre el carril (W: 32 bit en 0 o 4; D: 64 bit)
            bits := 8 * sz;
            off := shift_right(unsigned(old), 8 * to_integer(unsigned(d_req_addr(2 downto 0))));
            wd := std_logic_vector(shift_right(unsigned(d_req_wdata), 8 * to_integer(unsigned(d_req_addr(2 downto 0)))));
            if bits = 32 then
              so := resize(signed(off(31 downto 0)), 64); sb := resize(signed(wd(31 downto 0)), 64);
              uo := resize(off(31 downto 0), 64);         ub := resize(unsigned(wd(31 downto 0)), 64);
            else
              so := signed(off); sb := signed(wd); uo := off; ub := unsigned(wd);
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
            nw := std_logic_vector(shift_left(unsigned(nw), 8 * to_integer(unsigned(d_req_addr(2 downto 0)))));
            ram(idx) := (old and not m) or (nw and m);
            d_data_r <= old;
          end if;
        elsif unsigned(d_req_addr) >= x"0000000002000000" and unsigned(d_req_addr) < x"0000000002010000"
              and (sz = 4 or sz = 8) then
          -- CLINT
          off := unsigned(d_req_addr) - x"0000000002000000";
          case to_integer(off(15 downto 3)) is
            when 0      => old := (0 => msip_r, others => '0');
            when 16#800# => old := std_logic_vector(mtimecmp);
            when 16#17FF# => old := std_logic_vector(mtime_v);
            when others => old := XZERO;
          end case;
          if d_req_kind = "00" then
            d_data_r <= old;
          else
            nw := (old and not m) or (d_req_wdata and m);
            case to_integer(off(15 downto 3)) is
              when 0       => msip_r := nw(0);
              when 16#800# => mtimecmp := unsigned(nw);
              when 16#17FF# => mtime_v := unsigned(nw);
              when others  => null;
            end case;
          end if;
        elsif unsigned(d_req_addr) >= x"0000000010000000" and unsigned(d_req_addr) < x"0000000010001000"
              and sz = 1 then
          -- UART
          if d_req_kind = "00" then
            if d_req_addr(11 downto 0) = x"005" then
              d_data_r <= std_logic_vector(shift_left(to_unsigned(16#60#, 64), 8 * to_integer(unsigned(d_req_addr(2 downto 0)))));
            end if;
          elsif d_req_addr(11 downto 0) = x"000" then
            write(output, "" & character'val(to_integer(unsigned(d_req_wdata(7 downto 0)))));
          end if;
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
