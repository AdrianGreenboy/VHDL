-- rv128_proto_top.vhd - bare-metal prototype of the RV128IMAC core on Versal (TE0950).
-- Self-contained in the PL: no NoC, no DDR. The program runs from on-chip BRAM.
--
--   core I port  -> BRAM port A (read only, 1 cycle)
--   core D port  -> BRAM port B (byte lanes, AMO read-modify-write in 2 cycles),
--                   CLINT (msip/mtimecmp/mtime) and a console byte port
--   PS (A72, M_AXI_FPD) -> AXI4-Lite control bank + BRAM window (core held in reset)
--
-- Memory map seen by the core (same rules as tb_core.vhd and iss128.py):
--   0x8000_0000 + MEM_KB KiB   RAM (BRAM)
--   0x0200_0000                CLINT, 4/8-byte accesses, no AMO
--   0x1000_0000                console: byte store at +0 -> RX FIFO for the PS,
--                              byte load at +5 -> 0x60 (LSR: THR empty)
--   anything else              bus error -> access fault
-- A full console FIFO back-pressures the core (d_req_ready low): no byte is lost.
--
-- Control bank (32-bit AXI4-Lite, 256 KiB window):
--   0x00 CTRL        bit0 RUN (releases the core reset), bit1 RST (forces it)
--   0x04 STATUS      bit0 running, bit1 HALT (tohost written), bit2 console FIFO not empty
--   0x08/0x0C        RETIRED lo/hi: committed instructions (traps excluded)
--   0x10 PC          low 32 bits of the last retired pc
--   0x14 TOHOST_OFF  RW: byte offset of 'tohost' from 0x8000_0000 (from the .sym file)
--   0x18 HALT_CODE   tohost >> 1 (0 = PASS)
--   0x1C CONSOLE     read pops one byte: bit8 valid, bits 7:0 data
--   0x20/0x24        CYCLES lo/hi since RUN, frozen at HALT
--   0x28/0x2C        HALT_RETIRED lo/hi: commits before the tohost store
--   0x30 MEM_KB      RO
--   0x34 ID          RO 0x5256_3132 ("RV12")
--   0x20000-0x3FFFF  BRAM window, 32-bit words; only while the core is in reset
--                    (reads return 0 and writes are dropped while it runs)
-- HALT is detected at the retirement of a store to tohost (RVFI), so HALT_RETIRED is
-- exact and comparable with the ISS. HTIF: tohost = (code << 1) | 1.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;

entity rv128_proto_top is
  generic (
    MEM_KB   : positive := 128;                     -- BRAM size (power of two, <= 128)
    TICK_DIV : positive := 50;                      -- mtime tick = clk / TICK_DIV
    FIFO_LG  : positive := 12                       -- console FIFO depth = 2**FIFO_LG
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    s_axi_ctrl_awaddr  : in  std_logic_vector(17 downto 0);
    s_axi_ctrl_awvalid : in  std_logic;
    s_axi_ctrl_awready : out std_logic;
    s_axi_ctrl_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_ctrl_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_ctrl_wvalid  : in  std_logic;
    s_axi_ctrl_wready  : out std_logic;
    s_axi_ctrl_bresp   : out std_logic_vector(1 downto 0);
    s_axi_ctrl_bvalid  : out std_logic;
    s_axi_ctrl_bready  : in  std_logic;
    s_axi_ctrl_araddr  : in  std_logic_vector(17 downto 0);
    s_axi_ctrl_arvalid : in  std_logic;
    s_axi_ctrl_arready : out std_logic;
    s_axi_ctrl_rdata   : out std_logic_vector(31 downto 0);
    s_axi_ctrl_rresp   : out std_logic_vector(1 downto 0);
    s_axi_ctrl_rvalid  : out std_logic;
    s_axi_ctrl_rready  : in  std_logic;
    halt_o  : out std_logic                          -- for an LED / ILA
  );
end entity;

architecture rtl of rv128_proto_top is
  constant WORDS : natural := MEM_KB * 64;          -- 16-byte words
  function clog2(n : natural) return natural is
    variable r : natural := 0;
  begin
    while 2 ** r < n loop r := r + 1; end loop;
    return r;
  end function;
  constant AW : natural := clog2(WORDS);

  subtype w128 is std_logic_vector(127 downto 0);
  type ram_t is array (0 to WORDS - 1) of w128;
  signal ram : ram_t := (others => (others => '0'));

  -- reset / control
  signal rst_soc  : std_logic;
  signal rst_sync : std_logic_vector(1 downto 0) := "11";
  signal ctrl_run, ctrl_rst : std_logic;
  signal tohost_off : std_logic_vector(31 downto 0);
  signal halted   : std_logic;
  signal halt_code : std_logic_vector(31 downto 0);
  signal retired, cycles, halt_ret : unsigned(63 downto 0);
  signal last_pc  : std_logic_vector(31 downto 0);

  -- core ports
  signal i_req_valid, i_req_ready, i_rsp_valid, i_rsp_err : std_logic;
  signal i_req_addr : xword;
  signal i_rsp_data : std_logic_vector(31 downto 0);
  signal d_req_valid, d_req_ready, d_rsp_valid, d_rsp_err : std_logic;
  signal d_req_addr, d_req_wdata, d_rsp_rdata : xword;
  signal d_req_kind : std_logic_vector(1 downto 0);
  signal d_req_size : std_logic_vector(2 downto 0);
  signal d_req_amo_op : std_logic_vector(4 downto 0);
  signal d_req_wstrb : std_logic_vector(15 downto 0);
  signal mtip, msip : std_logic;
  signal mtime : unsigned(63 downto 0);
  signal rvfi_valid, rvfi_trap : std_logic;
  signal rvfi_pc, rvfi_mem_addr, rvfi_mem_wdata : xword;
  signal rvfi_mem_wstrb : std_logic_vector(15 downto 0);

  -- BRAM ports
  signal a_addr : unsigned(AW - 1 downto 0);
  signal a_dout : w128;
  signal b_en, b_we_any : std_logic;
  signal b_addr : unsigned(AW - 1 downto 0);
  signal b_we   : std_logic_vector(15 downto 0);
  signal b_din, b_dout : w128;

  -- fetch response
  signal i_pend, i_err_r : std_logic;
  signal i_sel : std_logic_vector(1 downto 0);

  -- data side
  type dsrc_t is (S_RAM, S_REG);
  type dst_t is (D_IDLE, D_AMO);
  signal dst      : dst_t;
  signal d_src    : dsrc_t;
  signal d_pend   : std_logic;
  signal d_err_r  : std_logic;
  signal d_reg    : w128;
  signal amo_idx  : unsigned(AW - 1 downto 0);
  signal amo_lane : natural range 0 to 15;
  signal amo_sz   : natural range 0 to 16;
  signal amo_op   : std_logic_vector(4 downto 0);
  signal amo_wd   : w128;
  signal amo_m    : w128;
  signal core_b_en : std_logic;
  signal core_b_addr : unsigned(AW - 1 downto 0);
  signal core_b_we : std_logic_vector(15 downto 0);
  signal core_b_din : w128;
  signal msip_r   : std_logic;
  signal mtimecmp : unsigned(63 downto 0);
  signal tick     : natural range 0 to TICK_DIV - 1;

  -- console FIFO
  type fifo_t is array (0 to 2 ** FIFO_LG - 1) of std_logic_vector(7 downto 0);
  signal fifo : fifo_t;
  signal f_wp, f_rp, f_wp_d : unsigned(FIFO_LG downto 0);
  signal f_full, f_empty, f_push, f_pop : std_logic;
  signal f_din, f_dout : std_logic_vector(7 downto 0);

  -- AXI-Lite
  type cst_t is (C_IDLE, C_BRD1, C_BRD2, C_WRESP, C_RRESP);
  signal cst : cst_t;
  signal c_rdata : std_logic_vector(31 downto 0);
  signal c_lane  : std_logic_vector(1 downto 0);
  signal ps_b_en : std_logic;
  signal ps_b_addr : unsigned(AW - 1 downto 0);
  signal ps_b_we : std_logic_vector(15 downto 0);
  signal ps_b_din : w128;

  function in_ram(a : xword) return boolean is
  begin
    return a(127 downto 32) = (127 downto 32 => '0') and a(31) = '1'
           and unsigned(a(30 downto 0)) < to_unsigned(WORDS * 16, 31);
  end function;
  function is_clint(a : xword) return boolean is
  begin
    return a(127 downto 32) = (127 downto 32 => '0') and a(31 downto 16) = x"0200";
  end function;
  function is_cons(a : xword) return boolean is
  begin
    return a(127 downto 32) = (127 downto 32 => '0') and a(31 downto 12) = x"10000";
  end function;
begin
  halt_o <= halted;

  -- ============================================================ reset of the core
  process (clk)
  begin
    if rising_edge(clk) then
      rst_sync <= rst_sync(0) & ((not aresetn) or (not ctrl_run) or ctrl_rst);
    end if;
  end process;
  rst_soc <= rst_sync(1);

  core_u : entity work.rv128_core port map (
    clk => clk, rst => rst_soc, m64 => '0',
    i_req_valid => i_req_valid, i_req_ready => i_req_ready, i_req_addr => i_req_addr,
    i_rsp_valid => i_rsp_valid, i_rsp_data => i_rsp_data, i_rsp_err => i_rsp_err,
    d_req_valid => d_req_valid, d_req_ready => d_req_ready, d_req_addr => d_req_addr,
    d_req_kind => d_req_kind, d_req_amo_op => d_req_amo_op, d_req_size => d_req_size,
    d_req_wdata => d_req_wdata, d_req_wstrb => d_req_wstrb,
    d_rsp_valid => d_rsp_valid, d_rsp_rdata => d_rsp_rdata, d_rsp_err => d_rsp_err,
    mtip => mtip, msip => msip, meip => '0', seip => '0', time_i => std_logic_vector(mtime),
    fencei_o => open, sfence_o => open,
    rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => open, rvfi_rd => open,
    rvfi_rd_wdata => open, rvfi_trap => rvfi_trap, rvfi_cause => open, rvfi_tval => open,
    rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
    rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => open);

  -- ============================================================ BRAM (simple dual port)
  -- port A: read only (fetch). port B: read/write with byte enables (core or PS).
  process (clk)
  begin
    if rising_edge(clk) then
      a_dout <= ram(to_integer(a_addr));
    end if;
  end process;
  process (clk)
  begin
    if rising_edge(clk) then
      if b_en = '1' then
        for k in 0 to 15 loop
          if b_we(k) = '1' then
            ram(to_integer(b_addr))(8 * k + 7 downto 8 * k) <= b_din(8 * k + 7 downto 8 * k);
          end if;
        end loop;
        b_dout <= ram(to_integer(b_addr));
      end if;
    end if;
  end process;

  b_en   <= ps_b_en   when rst_soc = '1' else core_b_en;
  b_addr <= ps_b_addr when rst_soc = '1' else core_b_addr;
  b_we   <= ps_b_we   when rst_soc = '1' else core_b_we;
  b_din  <= ps_b_din  when rst_soc = '1' else core_b_din;

  -- ============================================================ fetch
  i_req_ready <= '1';
  a_addr <= unsigned(i_req_addr(AW + 3 downto 4));
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_soc = '1' then
        i_pend <= '0';
      else
        i_pend <= i_req_valid;
        i_sel  <= i_req_addr(3 downto 2);
        if in_ram(i_req_addr) then i_err_r <= '0'; else i_err_r <= '1'; end if;
      end if;
    end if;
  end process;
  i_rsp_valid <= i_pend;
  i_rsp_err   <= i_err_r;
  with i_sel select i_rsp_data <=
    a_dout(31 downto 0)   when "00",
    a_dout(63 downto 32)  when "01",
    a_dout(95 downto 64)  when "10",
    a_dout(127 downto 96) when others;

  -- ============================================================ data port
  -- accept: RAM loads/stores/AMOs, CLINT, console. AMO: read in cycle 0, write in cycle 1.
  d_req_ready <= '1' when dst = D_IDLE and not (is_cons(d_req_addr) and d_req_kind = "01" and f_full = '1')
                 else '0';
  d_rsp_valid <= d_pend;
  d_rsp_err   <= d_err_r;
  d_rsp_rdata <= b_dout when d_src = S_RAM else d_reg;
  mtip <= '1' when mtime >= mtimecmp else '0';
  msip <= msip_r;

  process (all)
    variable m   : w128;
    variable sh  : unsigned(127 downto 0);
    variable wd  : w128;
    variable so, sb : signed(127 downto 0);
    variable uo, ub : unsigned(127 downto 0);
    variable nw  : w128;
  begin
    core_b_en <= '0'; core_b_we <= (others => '0');
    core_b_addr <= unsigned(d_req_addr(AW + 3 downto 4));
    core_b_din  <= d_req_wdata;
    f_push <= '0'; f_din <= d_req_wdata(7 downto 0);
    if dst = D_AMO then
      -- write phase of the AMO: old value is on b_dout
      sh := shift_right(unsigned(b_dout), 8 * amo_lane);
      wd := std_logic_vector(shift_right(unsigned(amo_wd), 8 * amo_lane));
      if amo_sz = 4 then
        so := resize(signed(sh(31 downto 0)), 128); sb := resize(signed(wd(31 downto 0)), 128);
        uo := resize(sh(31 downto 0), 128);         ub := resize(unsigned(wd(31 downto 0)), 128);
      elsif amo_sz = 8 then
        so := resize(signed(sh(63 downto 0)), 128); sb := resize(signed(wd(63 downto 0)), 128);
        uo := resize(sh(63 downto 0), 128);         ub := resize(unsigned(wd(63 downto 0)), 128);
      else
        so := signed(sh); sb := signed(wd); uo := sh; ub := unsigned(wd);
      end if;
      case amo_op is
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
      core_b_en   <= '1';
      core_b_addr <= amo_idx;
      core_b_din  <= std_logic_vector(shift_left(unsigned(nw), 8 * amo_lane));
      for k in 0 to 15 loop
        core_b_we(k) <= amo_m(8 * k);
      end loop;
    elsif d_req_valid = '1' and d_req_ready = '1' and in_ram(d_req_addr) then
      core_b_en <= '1';
      if d_req_kind = "01" then core_b_we <= d_req_wstrb; end if;
    elsif d_req_valid = '1' and d_req_ready = '1' and is_cons(d_req_addr) and d_req_kind = "01"
          and d_req_size = "000" and d_req_addr(11 downto 0) = x"000" then
      f_push <= '1';
    end if;
  end process;

  process (clk)
    variable sz   : natural range 0 to 16;
    variable creg : std_logic_vector(63 downto 0);
    variable cm, cw : std_logic_vector(63 downto 0);
    variable m    : w128;
    variable sel  : natural range 0 to 8191;
  begin
    if rising_edge(clk) then
      -- CLINT time base (runs only while the core runs, like the testbench)
      if rst_soc = '1' then
        mtime <= (others => '0'); tick <= 0;
      elsif tick = TICK_DIV - 1 then
        tick <= 0; mtime <= mtime + 1;
      else
        tick <= tick + 1;
      end if;
      if rst_soc = '1' then
        dst <= D_IDLE; d_pend <= '0'; d_err_r <= '0'; d_src <= S_REG;
        msip_r <= '0'; mtimecmp <= (others => '1');
      else
        d_pend <= '0';
        if dst = D_AMO then
          dst <= D_IDLE;                          -- response was given in the read cycle
        end if;
        if d_req_valid = '1' and d_req_ready = '1' then
          sz := 2 ** to_integer(unsigned(d_req_size));
          d_pend <= '1'; d_err_r <= '0'; d_reg <= (others => '0'); d_src <= S_REG;
          m := (others => '0');
          for k in 0 to 15 loop
            if d_req_wstrb(k) = '1' then m(8 * k + 7 downto 8 * k) := x"FF"; end if;
          end loop;
          if in_ram(d_req_addr) then
            d_src <= S_RAM;
            if d_req_kind = "10" then
              dst <= D_AMO;
              amo_idx  <= unsigned(d_req_addr(AW + 3 downto 4));
              amo_lane <= to_integer(unsigned(d_req_addr(3 downto 0)));
              amo_sz   <= sz;
              amo_op   <= d_req_amo_op;
              amo_wd   <= d_req_wdata;
              amo_m    <= m;
            end if;
          elsif is_clint(d_req_addr) and (sz = 4 or sz = 8) and d_req_kind /= "10" then
            sel := to_integer(unsigned(d_req_addr(15 downto 3)));
            case sel is
              when 0        => creg := (0 => msip_r, others => '0');
              when 16#800#  => creg := std_logic_vector(mtimecmp);
              when 16#17FF# => creg := std_logic_vector(mtime);
              when others   => creg := (others => '0');
            end case;
            if d_req_kind = "00" then
              if d_req_addr(3) = '1' then d_reg <= creg & (63 downto 0 => '0');
              else d_reg <= (127 downto 64 => '0') & creg; end if;
            else
              if d_req_addr(3) = '1' then cm := m(127 downto 64); cw := d_req_wdata(127 downto 64);
              else cm := m(63 downto 0); cw := d_req_wdata(63 downto 0); end if;
              creg := (creg and not cm) or (cw and cm);
              case sel is
                when 0        => msip_r <= creg(0);
                when 16#800#  => mtimecmp <= unsigned(creg);
                when others   => null;     -- mtime is read-only here (no test writes it)
              end case;
            end if;
          elsif is_cons(d_req_addr) and sz = 1 and d_req_kind /= "10" then
            if d_req_kind = "00" and d_req_addr(11 downto 0) = x"005" then
              d_reg <= std_logic_vector(shift_left(to_unsigned(16#60#, 128),
                                                   8 * to_integer(unsigned(d_req_addr(3 downto 0)))));
            end if;
          else
            d_err_r <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ============================================================ console FIFO
  f_full  <= '1' when f_wp(FIFO_LG) /= f_rp(FIFO_LG) and f_wp(FIFO_LG - 1 downto 0) = f_rp(FIFO_LG - 1 downto 0) else '0';
  -- 'empty' uses the write pointer delayed by one cycle: a byte becomes visible only when
  -- the registered read port (f_dout) already holds it (BRAM read-before-write)
  f_empty <= '1' when f_wp_d = f_rp else '0';
  process (clk)
  begin
    if rising_edge(clk) then
      if f_push = '1' then
        fifo(to_integer(f_wp(FIFO_LG - 1 downto 0))) <= f_din;
      end if;
      f_dout <= fifo(to_integer(f_rp(FIFO_LG - 1 downto 0)));
    end if;
  end process;
  process (clk)
  begin
    if rising_edge(clk) then
      f_wp_d <= f_wp;
      if aresetn = '0' or (ctrl_rst = '1') then
        f_wp <= (others => '0'); f_rp <= (others => '0'); f_wp_d <= (others => '0');
      else
        if f_push = '1' then f_wp <= f_wp + 1; end if;
        if f_pop = '1' then f_rp <= f_rp + 1; end if;
      end if;
    end if;
  end process;

  -- ============================================================ HTIF / counters (from RVFI)
  process (clk)
    variable th  : std_logic_vector(31 downto 0);
    variable v   : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk) then
      if rst_soc = '1' then
        retired <= (others => '0'); cycles <= (others => '0');
        halted <= '0'; halt_code <= (others => '0'); halt_ret <= (others => '0');
      else
        if halted = '0' then cycles <= cycles + 1; end if;
        if rvfi_valid = '1' and rvfi_trap = '0' then
          retired <= retired + 1;
          last_pc <= rvfi_pc(31 downto 0);
        end if;
        th := std_logic_vector(unsigned(tohost_off) + x"80000000");
        if halted = '0' and rvfi_valid = '1' and rvfi_trap = '0' and rvfi_mem_wstrb /= x"0000"
           and rvfi_mem_addr(127 downto 32) = (127 downto 32 => '0')
           and rvfi_mem_addr(31 downto 4) = th(31 downto 4) then
          if th(3) = '0' then v := rvfi_mem_wdata(63 downto 0); else v := rvfi_mem_wdata(127 downto 64); end if;
          if v(63 downto 48) = x"0000" and v(0) = '1' then
            halted <= '1';
            halt_code <= v(32 downto 1);
            halt_ret <= retired;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ============================================================ AXI4-Lite control bank
  s_axi_ctrl_awready <= '1' when cst = C_IDLE and s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' else '0';
  s_axi_ctrl_wready  <= '1' when cst = C_IDLE and s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' else '0';
  s_axi_ctrl_arready <= '1' when cst = C_IDLE and s_axi_ctrl_arvalid = '1' and
                                 not (s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1') else '0';
  s_axi_ctrl_bvalid  <= '1' when cst = C_WRESP else '0';
  s_axi_ctrl_bresp   <= "00";
  s_axi_ctrl_rvalid  <= '1' when cst = C_RRESP else '0';
  s_axi_ctrl_rresp   <= "00";
  s_axi_ctrl_rdata   <= c_rdata;

  process (all)
    variable lane : natural range 0 to 3;
  begin
    ps_b_en <= '0'; ps_b_we <= (others => '0');
    ps_b_addr <= unsigned(s_axi_ctrl_araddr(AW + 3 downto 4));
    ps_b_din  <= (others => '0');
    f_pop <= '0';
    if cst = C_IDLE and s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' then
      if s_axi_ctrl_awaddr(17) = '1' then
        lane := to_integer(unsigned(s_axi_ctrl_awaddr(3 downto 2)));
        ps_b_en   <= '1';
        ps_b_addr <= unsigned(s_axi_ctrl_awaddr(AW + 3 downto 4));
        for k in 0 to 3 loop
          ps_b_din(32 * k + 31 downto 32 * k) <= s_axi_ctrl_wdata;
        end loop;
        for k in 0 to 3 loop
          ps_b_we(4 * lane + k) <= s_axi_ctrl_wstrb(k);
        end loop;
      end if;
    elsif cst = C_IDLE and s_axi_ctrl_arvalid = '1' then
      if s_axi_ctrl_araddr(17) = '1' then
        ps_b_en <= '1';
      elsif s_axi_ctrl_araddr(15 downto 0) = x"001C" and f_empty = '0' then
        f_pop <= '1';
      end if;
    end if;
  end process;

  process (clk)
    variable a : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        cst <= C_IDLE; ctrl_run <= '0'; ctrl_rst <= '0'; tohost_off <= x"00001000";
      else
        case cst is
          when C_IDLE =>
            if s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' then
              a := s_axi_ctrl_awaddr(15 downto 0);
              if s_axi_ctrl_awaddr(17) = '0' then
                if a = x"0000" then ctrl_run <= s_axi_ctrl_wdata(0); ctrl_rst <= s_axi_ctrl_wdata(1); end if;
                if a = x"0014" then tohost_off <= s_axi_ctrl_wdata; end if;
              end if;
              cst <= C_WRESP;
            elsif s_axi_ctrl_arvalid = '1' then
              a := s_axi_ctrl_araddr(15 downto 0);
              c_rdata <= (others => '0');
              c_lane  <= s_axi_ctrl_araddr(3 downto 2);
              if s_axi_ctrl_araddr(17) = '1' then
                cst <= C_BRD1;
              else
                case a is
                  when x"0000" => c_rdata(1 downto 0) <= ctrl_rst & ctrl_run;
                  when x"0004" => c_rdata(2 downto 0) <= (not f_empty) & halted & (not rst_soc);
                  when x"0008" => c_rdata <= std_logic_vector(retired(31 downto 0));
                  when x"000C" => c_rdata <= std_logic_vector(retired(63 downto 32));
                  when x"0010" => c_rdata <= last_pc;
                  when x"0014" => c_rdata <= tohost_off;
                  when x"0018" => c_rdata <= halt_code;
                  when x"001C" => if f_empty = '0' then c_rdata(8) <= '1'; c_rdata(7 downto 0) <= f_dout; end if;
                  when x"0020" => c_rdata <= std_logic_vector(cycles(31 downto 0));
                  when x"0024" => c_rdata <= std_logic_vector(cycles(63 downto 32));
                  when x"0028" => c_rdata <= std_logic_vector(halt_ret(31 downto 0));
                  when x"002C" => c_rdata <= std_logic_vector(halt_ret(63 downto 32));
                  when x"0030" => c_rdata <= std_logic_vector(to_unsigned(MEM_KB, 32));
                  when x"0034" => c_rdata <= x"52563132";
                  when others  => null;
                end case;
                cst <= C_RRESP;
              end if;
            end if;
          when C_BRD1 =>
            cst <= C_BRD2;                         -- BRAM output valid now
          when C_BRD2 =>
            if rst_soc = '1' then
              case c_lane is
                when "00"   => c_rdata <= b_dout(31 downto 0);
                when "01"   => c_rdata <= b_dout(63 downto 32);
                when "10"   => c_rdata <= b_dout(95 downto 64);
                when others => c_rdata <= b_dout(127 downto 96);
              end case;
            end if;
            cst <= C_RRESP;
          when C_WRESP =>
            if s_axi_ctrl_bready = '1' then cst <= C_IDLE; end if;
          when C_RRESP =>
            if s_axi_ctrl_rready = '1' then cst <= C_IDLE; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
