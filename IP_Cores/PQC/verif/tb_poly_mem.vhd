-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- tb_poly_mem: validates the shared coefficient memory and its arbiter.
--
-- The arbiter is the one piece of Layer 3A that no earlier layer exercised,
-- so it is verified on its own before the algorithm FSM is built on top.
-- Three properties are checked:
--   1. slot isolation: writing one slot must not disturb any other
--   2. client routing: each grant reaches the intended slot and address
--   3. basemul read-modify-write: the destination read must return what the
--      previous write to that address stored
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;

entity tb_poly_mem is
end entity tb_poly_mem;

architecture sim of tb_poly_mem is

  constant C_PERIOD : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  signal grant    : integer range 0 to 4 := C_CLI_NONE;
  signal slot_rd  : integer range 0 to C_SLOTS - 1 := 0;
  signal slot_rd2 : integer range 0 to C_SLOTS - 1 := 0;
  signal slot_wr  : integer range 0 to C_SLOTS - 1 := 0;

  signal ntt_raddr : std_logic_vector(7 downto 0) := (others => '0');
  signal ntt_rdata : std_logic_vector(15 downto 0);
  signal ntt_waddr : std_logic_vector(7 downto 0) := (others => '0');
  signal ntt_wdata : std_logic_vector(15 downto 0) := (others => '0');
  signal ntt_we    : std_logic := '0';

  signal bm_aaddr  : std_logic_vector(7 downto 0) := (others => '0');
  signal bm_adata  : std_logic_vector(15 downto 0);
  signal bm_baddr  : std_logic_vector(7 downto 0) := (others => '0');
  signal bm_bdata  : std_logic_vector(15 downto 0);
  signal bm_daddr  : std_logic_vector(7 downto 0) := (others => '0');
  signal bm_drdata : std_logic_vector(15 downto 0);
  signal bm_dwdata : std_logic_vector(15 downto 0) := (others => '0');
  signal bm_dwe    : std_logic := '0';

  signal sm_waddr  : std_logic_vector(7 downto 0) := (others => '0');
  signal sm_wdata  : std_logic_vector(15 downto 0) := (others => '0');
  signal sm_we     : std_logic := '0';

  signal fsm_raddr : std_logic_vector(7 downto 0) := (others => '0');
  signal fsm_rdata : std_logic_vector(15 downto 0);
  signal fsm_waddr : std_logic_vector(7 downto 0) := (others => '0');
  signal fsm_wdata : std_logic_vector(15 downto 0) := (others => '0');
  signal fsm_we    : std_logic := '0';

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

  dut : entity work.poly_mem
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

  main : process
    variable sig : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable v   : integer;
    variable n   : integer := 0;

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
      if x < 0 then
        w := to_unsigned(x + 2147483647 + 1, 32);
      else
        w := to_unsigned(x, 32);
      end if;
      for i in 0 to 3 loop
        u := s xor resize(w(8 * i + 7 downto 8 * i), 64);
        u := u + shift_left(u, 1) + shift_left(u, 4) + shift_left(u, 5) +
             shift_left(u, 7) + shift_left(u, 8) + shift_left(u, 40);
        s := u;
      end loop;
    end procedure sig_update;

    -- write one coefficient through the FSM port
    procedure wr_fsm (slot : in integer; idx : in integer; val : in integer) is
    begin
      grant     <= C_CLI_FSM;
      slot_wr   <= slot;
      fsm_waddr <= std_logic_vector(to_unsigned(idx, 8));
      fsm_wdata <= std_logic_vector(to_signed(val, 16));
      fsm_we    <= '1';
      wait_clk(1);
      fsm_we    <= '0';
      wait_clk(1);
    end procedure wr_fsm;

    -- read one coefficient through the FSM port
    procedure rd_fsm (slot : in integer; idx : in integer;
                      result : out integer) is
    begin
      grant     <= C_CLI_FSM;
      slot_rd   <= slot;
      fsm_raddr <= std_logic_vector(to_unsigned(idx, 8));
      wait_clk(2);
      result := to_integer(signed(fsm_rdata));
    end procedure rd_fsm;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    ------------------------------------------------------------------
    -- 1. slot isolation: distinct value in every slot at the same index
    ------------------------------------------------------------------
    for s in 0 to C_SLOTS - 1 loop
      wr_fsm(s, 17, 100 + s);
    end loop;
    for s in 0 to C_SLOTS - 1 loop
      rd_fsm(s, 17, v);
      assert v = 100 + s
        report "TB FAIL slot isolation slot=" & integer'image(s) &
               " got=" & integer'image(v) &
               " exp=" & integer'image(100 + s)
        severity failure;
      sig_update(sig, v);
      n := n + 1;
    end loop;

    ------------------------------------------------------------------
    -- 2. index isolation within one slot, including both extremes
    ------------------------------------------------------------------
    for i in 0 to 255 loop
      wr_fsm(C_SLOT_T, i, i - 128);
    end loop;
    for i in 0 to 255 loop
      rd_fsm(C_SLOT_T, i, v);
      assert v = i - 128
        report "TB FAIL index isolation idx=" & integer'image(i)
        severity failure;
      sig_update(sig, v);
      n := n + 1;
    end loop;

    ------------------------------------------------------------------
    -- 3. NTT client routing: write through NTT, read back through FSM
    ------------------------------------------------------------------
    grant     <= C_CLI_NTT;
    slot_wr   <= C_SLOT_S;
    for i in 0 to 7 loop
      ntt_waddr <= std_logic_vector(to_unsigned(i, 8));
      ntt_wdata <= std_logic_vector(to_signed(-1000 - i, 16));
      ntt_we    <= '1';
      wait_clk(1);
    end loop;
    ntt_we <= '0';
    wait_clk(2);
    for i in 0 to 7 loop
      rd_fsm(C_SLOT_S, i, v);
      assert v = -1000 - i
        report "TB FAIL NTT routing idx=" & integer'image(i) &
               " got=" & integer'image(v)
        severity failure;
      sig_update(sig, v);
      n := n + 1;
    end loop;

    ------------------------------------------------------------------
    -- 4. sampler client routing
    ------------------------------------------------------------------
    grant   <= C_CLI_SAMP;
    slot_wr <= C_SLOT_Y;
    for i in 0 to 7 loop
      sm_waddr <= std_logic_vector(to_unsigned(i, 8));
      sm_wdata <= std_logic_vector(to_signed(500 + i, 16));
      sm_we    <= '1';
      wait_clk(1);
    end loop;
    sm_we <= '0';
    wait_clk(2);
    for i in 0 to 7 loop
      rd_fsm(C_SLOT_Y, i, v);
      assert v = 500 + i
        report "TB FAIL sampler routing idx=" & integer'image(i)
        severity failure;
      sig_update(sig, v);
      n := n + 1;
    end loop;

    ------------------------------------------------------------------
    -- 5. basemul dual read: two different slots at two different indices
    ------------------------------------------------------------------
    grant    <= C_CLI_BMUL;
    slot_rd  <= C_SLOT_S;
    slot_rd2 <= C_SLOT_Y;
    bm_aaddr <= std_logic_vector(to_unsigned(3, 8));
    bm_baddr <= std_logic_vector(to_unsigned(5, 8));
    wait_clk(2);
    assert to_integer(signed(bm_adata)) = -1003
      report "TB FAIL basemul port A got=" &
             integer'image(to_integer(signed(bm_adata)))
      severity failure;
    assert to_integer(signed(bm_bdata)) = 505
      report "TB FAIL basemul port B got=" &
             integer'image(to_integer(signed(bm_bdata)))
      severity failure;
    sig_update(sig, to_integer(signed(bm_adata)));
    sig_update(sig, to_integer(signed(bm_bdata)));
    n := n + 2;

    ------------------------------------------------------------------
    -- 6. basemul read-modify-write on the destination port
    ------------------------------------------------------------------
    grant     <= C_CLI_BMUL;
    slot_wr   <= C_SLOT_TMP;
    bm_daddr  <= std_logic_vector(to_unsigned(9, 8));
    bm_dwdata <= std_logic_vector(to_signed(1234, 16));
    bm_dwe    <= '1';
    wait_clk(1);
    bm_dwe    <= '0';
    wait_clk(2);
    assert to_integer(signed(bm_drdata)) = 1234
      report "TB FAIL basemul destination readback got=" &
             integer'image(to_integer(signed(bm_drdata)))
      severity failure;
    sig_update(sig, to_integer(signed(bm_drdata)));
    n := n + 1;

    ------------------------------------------------------------------
    -- 7. writes must not leak across slot boundaries
    ------------------------------------------------------------------
    rd_fsm(C_SLOT_T, 17, v);
    assert v = 17 - 128
      report "TB FAIL slot boundary leak into t_hat got=" & integer'image(v)
      severity failure;
    sig_update(sig, v);
    n := n + 1;

    report "PQC L3A POLYMEM PASS checks=" & integer'image(n) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
