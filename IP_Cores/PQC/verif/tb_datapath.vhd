-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- tb_datapath: integration test of the compute blocks through the arbiter.
--
-- Layer 1 verified ntt_unit and basemul_k against dedicated memory models.
-- This testbench re-runs the same reference vectors with the blocks wired to
-- the shared poly_mem instead, which is the configuration the algorithm FSM
-- will use. A block that passes standalone and fails here has an arbiter or
-- slot-routing problem, not an arithmetic one.
--
-- The chain checked is the one KeyGen actually performs:
--   NTT(a) -> slot A, NTT(s) -> slot S, basemul(A, S) accumulating into TMP
-- run twice to confirm accumulation across separate basemul invocations.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;

entity tb_datapath is
  generic (
    G_NFILE : string := "ntt_k_vectors.txt";
    G_BFILE : string := "basemul_vectors.txt");
end entity tb_datapath;

architecture sim of tb_datapath is

  constant C_PERIOD : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  signal grant    : integer range 0 to 4 := C_CLI_NONE;
  signal slot_rd  : integer range 0 to C_SLOTS - 1 := 0;
  signal slot_rd2 : integer range 0 to C_SLOTS - 1 := 0;
  signal slot_wr  : integer range 0 to C_SLOTS - 1 := 0;

  signal ntt_raddr : std_logic_vector(7 downto 0);
  signal ntt_rdata : std_logic_vector(15 downto 0);
  signal ntt_waddr : std_logic_vector(7 downto 0);
  signal ntt_wdata : std_logic_vector(15 downto 0);
  signal ntt_we    : std_logic;

  signal bm_aaddr  : std_logic_vector(7 downto 0);
  signal bm_adata  : std_logic_vector(15 downto 0);
  signal bm_baddr  : std_logic_vector(7 downto 0);
  signal bm_bdata  : std_logic_vector(15 downto 0);
  signal bm_daddr  : std_logic_vector(7 downto 0);
  signal bm_drdata : std_logic_vector(15 downto 0);
  signal bm_dwdata : std_logic_vector(15 downto 0);
  signal bm_dwe    : std_logic;

  signal sm_waddr  : std_logic_vector(7 downto 0) := (others => '0');
  signal sm_wdata  : std_logic_vector(15 downto 0) := (others => '0');
  signal sm_we     : std_logic := '0';

  signal fsm_raddr : std_logic_vector(7 downto 0) := (others => '0');
  signal fsm_rdata : std_logic_vector(15 downto 0);
  signal fsm_waddr : std_logic_vector(7 downto 0) := (others => '0');
  signal fsm_wdata : std_logic_vector(15 downto 0) := (others => '0');
  signal fsm_we    : std_logic := '0';

  signal ntt_start : std_logic := '0';
  signal ntt_inv   : std_logic := '0';
  signal ntt_done  : std_logic;

  signal bm_start  : std_logic := '0';
  signal bm_accum  : std_logic := '0';
  signal bm_done   : std_logic;

  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

begin

  clk <= not clk after C_PERIOD / 2 when not sim_done else '0';

  u_mem : entity work.poly_mem
    port map (clk => clk, rst_n => rst_n, grant => grant,
              slot_rd => slot_rd, slot_rd2 => slot_rd2, slot_wr => slot_wr,
              ntt_raddr => ntt_raddr, ntt_rdata => ntt_rdata,
              ntt_waddr => ntt_waddr, ntt_wdata => ntt_wdata, ntt_we => ntt_we,
              bm_aaddr => bm_aaddr, bm_adata => bm_adata,
              bm_baddr => bm_baddr, bm_bdata => bm_bdata,
              bm_daddr => bm_daddr, bm_drdata => bm_drdata,
              bm_dwdata => bm_dwdata, bm_dwe => bm_dwe,
              sm_waddr => sm_waddr, sm_wdata => sm_wdata, sm_we => sm_we,
              fsm_raddr => fsm_raddr, fsm_rdata => fsm_rdata,
              fsm_waddr => fsm_waddr, fsm_wdata => fsm_wdata, fsm_we => fsm_we);

  u_ntt : entity work.ntt_unit
    generic map (G_Q => C_QK, G_QINV => C_QINVK, G_RBITS => 16,
                 G_WIDTH => 16, G_LAYERS => 7, G_SCALE => C_SK)
    port map (clk => clk, rst_n => rst_n, start => ntt_start,
              inverse => ntt_inv,
              rd_addr => ntt_raddr, rd_data => ntt_rdata,
              wr_addr => ntt_waddr, wr_data => ntt_wdata, wr_en => ntt_we,
              busy => open, done => ntt_done);

  u_bm : entity work.basemul_k
    port map (clk => clk, rst_n => rst_n, start => bm_start, accum => bm_accum,
              a_addr => bm_aaddr, a_data => bm_adata,
              b_addr => bm_baddr, b_data => bm_bdata,
              d_addr => bm_daddr, d_rdata => bm_drdata,
              d_wdata => bm_dwdata, d_we => bm_dwe,
              busy => open, done => bm_done);

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable nn     : integer := 0;
    variable nb     : integer := 0;
    variable v      : integer;
    type t_poly is array (0 to 255) of integer;
    variable pin, pexp, pa, pb, pc : t_poly;

    procedure wait_clk (k : integer := 1) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure wait_clk;

    procedure sig_update (variable s : inout unsigned(63 downto 0);
                          x : in integer) is
      variable u : unsigned(63 downto 0);
      variable w : unsigned(31 downto 0);
    begin
      w := to_unsigned(x, 32);
      for i in 0 to 3 loop
        u := s xor resize(w(8 * i + 7 downto 8 * i), 64);
        u := u + shift_left(u, 1) + shift_left(u, 4) + shift_left(u, 5) +
             shift_left(u, 7) + shift_left(u, 8) + shift_left(u, 40);
        s := u;
      end loop;
    end procedure sig_update;

    procedure load_slot (slot : in integer; p : in t_poly) is
    begin
      grant   <= C_CLI_FSM;
      slot_wr <= slot;
      for i in 0 to 255 loop
        fsm_waddr <= std_logic_vector(to_unsigned(i, 8));
        if p(i) > C_QK / 2 then
          fsm_wdata <= std_logic_vector(to_signed(p(i) - C_QK, 16));
        else
          fsm_wdata <= std_logic_vector(to_signed(p(i), 16));
        end if;
        fsm_we <= '1';
        wait_clk(1);
      end loop;
      fsm_we <= '0';
      wait_clk(1);
    end procedure load_slot;

    procedure read_slot (slot : in integer; idx : in integer;
                         result : out integer) is
    begin
      grant     <= C_CLI_FSM;
      slot_rd   <= slot;
      fsm_raddr <= std_logic_vector(to_unsigned(idx, 8));
      wait_clk(2);
      result := to_integer(signed(fsm_rdata));
    end procedure read_slot;

    procedure run_ntt (slot : in integer; inv : in std_logic) is
    begin
      grant     <= C_CLI_NTT;
      slot_rd   <= slot;
      slot_wr   <= slot;
      ntt_inv   <= inv;
      ntt_start <= '1';
      wait_clk(1);
      ntt_start <= '0';
      while ntt_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);
    end procedure run_ntt;

    procedure run_bmul (sa : in integer; sb : in integer; sd : in integer;
                        acc : in std_logic) is
    begin
      grant    <= C_CLI_BMUL;
      slot_rd  <= sa;
      slot_rd2 <= sb;
      slot_wr  <= sd;
      bm_accum <= acc;
      bm_start <= '1';
      wait_clk(1);
      bm_start <= '0';
      while bm_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);
    end procedure run_bmul;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    ------------------------------------------------------------------
    -- NTT through the arbiter, against the Layer 1 reference vectors
    ------------------------------------------------------------------
    file_open(status, fp, G_NFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open NTT vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;
      for i in 0 to 255 loop
        read(ln, pin(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pexp(i));
      end loop;

      load_slot(C_SLOT_S, pin);
      run_ntt(C_SLOT_S, '0');
      for i in 0 to 255 loop
        read_slot(C_SLOT_S, i, v);
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = pexp(i)
          report "TB FAIL arbitrated NTT vector " & integer'image(nn) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      run_ntt(C_SLOT_S, '1');
      for i in 0 to 255 loop
        read_slot(C_SLOT_S, i, v);
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = pin(i)
          report "TB FAIL arbitrated INTT vector " & integer'image(nn) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      nn := nn + 1;
    end loop;
    file_close(fp);

    ------------------------------------------------------------------
    -- basemul through the arbiter, with cross-slot operands and
    -- accumulation across two separate invocations
    ------------------------------------------------------------------
    file_open(status, fp, G_BFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open basemul vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;
      for i in 0 to 255 loop
        read(ln, pa(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pb(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pc(i));
      end loop;

      -- operands in two different slots, destination in a third
      load_slot(C_SLOT_A, pa);
      load_slot(C_SLOT_Y, pb);
      for i in 0 to 255 loop
        pin(i) := 0;
      end loop;
      load_slot(C_SLOT_TMP, pin);

      run_bmul(C_SLOT_A, C_SLOT_Y, C_SLOT_TMP, '1');
      run_bmul(C_SLOT_A, C_SLOT_Y, C_SLOT_TMP, '1');

      for i in 0 to 255 loop
        read_slot(C_SLOT_TMP, i, v);
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = (2 * pc(i)) mod C_QK
          report "TB FAIL arbitrated basemul vector " & integer'image(nb) &
                 " coef " & integer'image(i) &
                 " got=" & integer'image(v) &
                 " exp=" & integer'image((2 * pc(i)) mod C_QK)
          severity failure;
        sig_update(sig, v);
      end loop;

      nb := nb + 1;
    end loop;
    file_close(fp);

    report "PQC L3A DATAPATH PASS ntt=" & integer'image(nn) &
           " bmul=" & integer'image(nb) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
