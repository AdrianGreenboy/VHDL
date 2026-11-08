-- =============================================================================
-- HERCOSSNUX PQC IP Core - audit 2026-11
-- tb_mem_banks: randomized self-checking test of the restructured memories.
-- VHDL-2008. ASCII-only. MIT license.
--
-- For poly_mem, poly_mem_d, byte_mem and byte_mem_d it drives a long random
-- sequence of client accesses against a behavioural reference model and
-- checks every read the client would consume:
--   * poly_mem: NTT, basemul (two operand reads plus the strobed destination
--     read of the read-modify-write), sampler and FSM clients, read-first on
--     a same-address read/write; the two physical 1R1W copies must stay
--     identical word for word (inspected through external names).
--   * poly_mem_d: port-A read+write and port-B read in the same cycle.
--   * byte_mem / byte_mem_d: single-address 1RW, output holds on a write
--     cycle, ranged zeroization.
--   * every memory: a zeroization pulse leaves every physical word at zero
--     and later reads return zero until rewritten.
-- Expected final line:  PQC MEMBANKS PASS ...
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.poly_mem_pkg.all;
use work.poly_mem_d_pkg.all;
use work.byte_mem_pkg.all;
use work.byte_mem_d_pkg.all;
use work.ntt_d_tables_pkg.all;

entity tb_mem_banks is
  generic (G_N : integer := 20000);
end entity tb_mem_banks;

architecture sim of tb_mem_banks is
  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal done_sim : boolean := false;

  -- poly_mem
  signal grant    : integer range 0 to 4 := 0;
  signal slot_rd, slot_rd2, slot_wr : integer range 0 to C_SLOTS - 1 := 0;
  signal ntt_raddr, ntt_waddr : std_logic_vector(7 downto 0) := (others => '0');
  signal ntt_wdata : std_logic_vector(15 downto 0) := (others => '0');
  signal ntt_we : std_logic := '0';
  signal ntt_rdata, bm_adata, bm_bdata, bm_drdata, fsm_rdata :
    std_logic_vector(15 downto 0);
  signal bm_aaddr, bm_baddr, bm_daddr : std_logic_vector(7 downto 0) :=
    (others => '0');
  signal bm_dre, bm_dwe : std_logic := '0';
  signal bm_dwdata : std_logic_vector(15 downto 0) := (others => '0');
  signal sm_waddr : std_logic_vector(7 downto 0) := (others => '0');
  signal sm_wdata : std_logic_vector(15 downto 0) := (others => '0');
  signal sm_we : std_logic := '0';
  signal fsm_raddr, fsm_waddr : std_logic_vector(7 downto 0) :=
    (others => '0');
  signal fsm_wdata : std_logic_vector(15 downto 0) := (others => '0');
  signal fsm_we : std_logic := '0';
  signal pz_start, pz_busy : std_logic := '0';

  -- poly_mem_d
  signal da_slot, db_slot : integer range 0 to C_SLOTS_D - 1 := 0;
  signal da_raddr, da_waddr, db_raddr : std_logic_vector(7 downto 0) :=
    (others => '0');
  signal da_wdata : std_logic_vector(C_CW - 1 downto 0) := (others => '0');
  signal da_we : std_logic := '0';
  signal da_rdata, db_rdata : std_logic_vector(C_CW - 1 downto 0);
  signal dz_start, dz_busy : std_logic := '0';

  -- byte_mem
  signal b_addr : std_logic_vector(12 downto 0) := (others => '0');
  signal b_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal b_we   : std_logic := '0';
  signal b_dout, b_dout2 : std_logic_vector(7 downto 0);
  signal bz_start, bz_busy : std_logic := '0';
  signal bz_lo, bz_hi : integer range 0 to 1023 := 0;

  -- byte_mem_d
  signal e_addr : std_logic_vector(13 downto 0) := (others => '0');
  signal e_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal e_we   : std_logic := '0';
  signal e_dout : std_logic_vector(7 downto 0);
  signal ez_start, ez_busy : std_logic := '0';
  signal ez_lo, ez_hi : integer range 0 to 2047 := 0;

begin
  clk <= not clk after 5 ns when not done_sim else '0';

  u_pm : entity work.poly_mem
    port map (clk => clk, rst_n => rst_n, grant => grant,
              slot_rd => slot_rd, slot_rd2 => slot_rd2, slot_wr => slot_wr,
              ntt_raddr => ntt_raddr, ntt_rdata => ntt_rdata,
              ntt_waddr => ntt_waddr, ntt_wdata => ntt_wdata, ntt_we => ntt_we,
              bm_aaddr => bm_aaddr, bm_adata => bm_adata,
              bm_baddr => bm_baddr, bm_bdata => bm_bdata,
              bm_daddr => bm_daddr, bm_dre => bm_dre, bm_drdata => bm_drdata,
              bm_dwdata => bm_dwdata, bm_dwe => bm_dwe,
              sm_waddr => sm_waddr, sm_wdata => sm_wdata, sm_we => sm_we,
              fsm_raddr => fsm_raddr, fsm_rdata => fsm_rdata,
              fsm_waddr => fsm_waddr, fsm_wdata => fsm_wdata, fsm_we => fsm_we,
              z_start => pz_start, z_busy => pz_busy);

  u_pmd : entity work.poly_mem_d
    port map (clk => clk, rst_n => rst_n,
              a_slot => da_slot, a_raddr => da_raddr, a_rdata => da_rdata,
              a_waddr => da_waddr, a_wdata => da_wdata, a_we => da_we,
              b_slot => db_slot, b_raddr => db_raddr, b_rdata => db_rdata,
              z_start => dz_start, z_busy => dz_busy);

  u_bm : entity work.byte_mem
    port map (clk => clk, rst_n => rst_n, a_addr => b_addr, a_din => b_din,
              a_we => b_we, a_dout => b_dout, b_addr => b_addr,
              b_dout => b_dout2, z_start => bz_start, z_lo => bz_lo,
              z_hi => bz_hi, z_busy => bz_busy);

  u_bmd : entity work.byte_mem_d
    port map (clk => clk, rst_n => rst_n, addr => e_addr, din => e_din,
              we => e_we, dout => e_dout, z_start => ez_start, z_lo => ez_lo,
              z_hi => ez_hi, z_busy => ez_busy);

  main : process
    type t_ipm  is array (0 to C_SLOTS * 256 - 1) of integer;
    type t_ipmd is array (0 to C_SLOTS_D * 256 - 1) of integer;
    type t_ib   is array (0 to 8191) of integer;
    type t_ibd  is array (0 to 16383) of integer;
    variable rpm  : t_ipm  := (others => 0);
    variable rpmd : t_ipmd := (others => 0);
    variable rb   : t_ib   := (others => 0);
    variable rbd  : t_ibd  := (others => 0);
    -- what each port must show after the next edge (-100000 = don't care)
    variable e_ntt, e_bma, e_bmb, e_bmd, e_fsm : integer;
    variable e_da, e_db, e_b, e_e : integer;
    variable s1, s2 : positive := 7;
    variable r : real;
    variable n_chk : integer := 0;
    variable cl, sr, sr2, sw, ar, ar2, aw, v : integer;
    variable bwe : boolean;
    variable last_b, last_e : integer := 0;
    constant DC : integer := -100000;

    alias pma is <<signal .tb_mem_banks.u_pm.mem_a : t_pm_arr>>;
    alias pmb is <<signal .tb_mem_banks.u_pm.mem_b : t_pm_arr>>;
    alias pda is <<signal .tb_mem_banks.u_pmd.mem_a : t_pmd_arr>>;
    alias pdb is <<signal .tb_mem_banks.u_pmd.mem_b : t_pmd_arr>>;
    alias bmm is <<signal .tb_mem_banks.u_bm.mem : t_bm_arr>>;
    alias bdm is <<signal .tb_mem_banks.u_bmd.mem : t_bmd_arr>>;

    impure function rnd (n : integer) return integer is
    begin
      uniform(s1, s2, r);
      return integer(floor(r * real(n))) mod n;
    end function;

    procedure chk (name : string; got : std_logic_vector; exp : integer;
                   signd : boolean) is
      variable g : integer;
    begin
      if exp = DC then
        return;
      end if;
      assert not is_x(got)
        report "TB FAIL " & name & " returned metavalue" severity failure;
      if signd then
        g := to_integer(signed(got));
      else
        g := to_integer(unsigned(got));
      end if;
      assert g = exp
        report "TB FAIL " & name & " got " & integer'image(g) & " exp " &
               integer'image(exp) severity failure;
      n_chk := n_chk + 1;
    end procedure;

    procedure all_zero (name : string) is
    begin
      for i in pma'range loop
        assert pma(i) = (pma(i)'range => '0') and pmb(i) = (pmb(i)'range => '0')
          report "TB FAIL " & name & " poly_mem word not zero" severity failure;
      end loop;
      for i in pda'range loop
        assert pda(i) = (pda(i)'range => '0') and pdb(i) = (pdb(i)'range => '0')
          report "TB FAIL " & name & " poly_mem_d word not zero" severity failure;
      end loop;
    end procedure;

  begin
    rst_n <= '0';
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    rst_n <= '1';

    -- Initialise every location through the client ports (the arrays have
    -- no initial value, exactly like an ASIC SRAM).
    pz_start <= '1'; dz_start <= '1';
    bz_lo <= 0; bz_hi <= 1023; bz_start <= '1';
    ez_lo <= 0; ez_hi <= 2047; ez_start <= '1';
    wait until rising_edge(clk);
    pz_start <= '0'; dz_start <= '0'; bz_start <= '0'; ez_start <= '0';
    wait until rising_edge(clk);
    while pz_busy = '1' or dz_busy = '1' or bz_busy = '1' or ez_busy = '1' loop
      wait until rising_edge(clk);
    end loop;
    wait until rising_edge(clk);
    all_zero("initial wipe");

    e_ntt := DC; e_bma := DC; e_bmb := DC; e_bmd := DC; e_fsm := DC;
    e_da := DC; e_db := DC; e_b := DC; e_e := DC;

    for it in 1 to G_N loop
      ------------------------------------------------------------------
      -- poly_mem: one client per cycle
      ------------------------------------------------------------------
      ntt_we <= '0'; bm_dwe <= '0'; bm_dre <= '0'; sm_we <= '0';
      fsm_we <= '0';
      cl := 1 + rnd(4);
      sr := rnd(C_SLOTS); sr2 := rnd(C_SLOTS); sw := rnd(C_SLOTS);
      ar := rnd(256); ar2 := rnd(256); aw := rnd(256);
      if rnd(4) = 0 then aw := ar; sw := sr; end if;    -- same-address cases
      v := rnd(65536) - 32768;
      bwe := rnd(2) = 0;
      grant <= cl; slot_rd <= sr; slot_rd2 <= sr2; slot_wr <= sw;
      e_ntt := DC; e_bma := DC; e_bmb := DC; e_bmd := DC; e_fsm := DC;
      case cl is
        when C_CLI_NTT =>
          ntt_raddr <= std_logic_vector(to_unsigned(ar, 8));
          ntt_waddr <= std_logic_vector(to_unsigned(aw, 8));
          ntt_wdata <= std_logic_vector(to_signed(v, 16));
          e_ntt := rpm(sr * 256 + ar);                 -- read-first
          if bwe then ntt_we <= '1'; rpm(sw * 256 + aw) := v; end if;
        when C_CLI_BMUL =>
          bm_aaddr <= std_logic_vector(to_unsigned(ar, 8));
          bm_baddr <= std_logic_vector(to_unsigned(ar2, 8));
          bm_daddr <= std_logic_vector(to_unsigned(aw, 8));
          bm_dwdata <= std_logic_vector(to_signed(v, 16));
          e_bmb := rpm(sr2 * 256 + ar2);
          if rnd(2) = 0 then
            -- destination read strobe: served by copy A at the write address
            bm_dre <= '1';
            e_bmd := rpm(sw * 256 + aw);
          else
            e_bma := rpm(sr * 256 + ar);
          end if;
          if bwe then bm_dwe <= '1'; rpm(sw * 256 + aw) := v; end if;
        when C_CLI_SAMP =>
          sm_waddr <= std_logic_vector(to_unsigned(aw, 8));
          sm_wdata <= std_logic_vector(to_signed(v, 16));
          if bwe then sm_we <= '1'; rpm(sw * 256 + aw) := v; end if;
        when others =>
          fsm_raddr <= std_logic_vector(to_unsigned(ar, 8));
          fsm_waddr <= std_logic_vector(to_unsigned(aw, 8));
          fsm_wdata <= std_logic_vector(to_signed(v, 16));
          e_fsm := rpm(sr * 256 + ar);
          if bwe then fsm_we <= '1'; rpm(sw * 256 + aw) := v; end if;
      end case;

      ------------------------------------------------------------------
      -- poly_mem_d: A read + A write + B read
      ------------------------------------------------------------------
      sr := rnd(C_SLOTS_D); sr2 := rnd(C_SLOTS_D);
      ar := rnd(256); ar2 := rnd(256); aw := rnd(256);
      if rnd(4) = 0 then aw := ar; end if;
      if rnd(4) = 0 then ar2 := aw; sr2 := sr; end if;
      v := rnd(2 ** 30) - 2 ** 29;
      da_slot <= sr; db_slot <= sr2;
      da_raddr <= std_logic_vector(to_unsigned(ar, 8));
      da_waddr <= std_logic_vector(to_unsigned(aw, 8));
      db_raddr <= std_logic_vector(to_unsigned(ar2, 8));
      da_wdata <= std_logic_vector(to_signed(v, C_CW));
      e_da := rpmd(sr * 256 + ar);
      e_db := rpmd(sr2 * 256 + ar2);
      da_we <= '0';
      if rnd(2) = 0 then da_we <= '1'; rpmd(sr * 256 + aw) := v; end if;

      ------------------------------------------------------------------
      -- byte memories: 1RW, output holds on a write cycle
      ------------------------------------------------------------------
      ar := rnd(8192); v := rnd(256);
      b_addr <= std_logic_vector(to_unsigned(ar, 13));
      b_din  <= std_logic_vector(to_unsigned(v, 8));
      if rnd(3) = 0 then
        b_we <= '1'; rb(ar) := v; e_b := last_b;
      else
        b_we <= '0'; e_b := rb(ar); last_b := rb(ar);
      end if;
      ar := rnd(16384); v := rnd(256);
      e_addr <= std_logic_vector(to_unsigned(ar, 14));
      e_din  <= std_logic_vector(to_unsigned(v, 8));
      if rnd(3) = 0 then
        e_we <= '1'; rbd(ar) := v; e_e := last_e;
      else
        e_we <= '0'; e_e := rbd(ar); last_e := rbd(ar);
      end if;

      wait until rising_edge(clk);
      wait for 1 ns;
      chk("ntt_rdata", ntt_rdata, e_ntt, true);
      chk("bm_adata", bm_adata, e_bma, true);
      chk("bm_bdata", bm_bdata, e_bmb, true);
      chk("bm_drdata", bm_drdata, e_bmd, true);
      chk("fsm_rdata", fsm_rdata, e_fsm, true);
      chk("pmd a_rdata", da_rdata, e_da, true);
      chk("pmd b_rdata", db_rdata, e_db, true);
      chk("byte_mem a", b_dout, e_b, false);
      chk("byte_mem b", b_dout2, e_b, false);
      chk("byte_mem_d", e_dout, e_e, false);

      ------------------------------------------------------------------
      -- occasional ranged zeroization of the byte memories
      ------------------------------------------------------------------
      if it mod 5000 = 2500 then
        ntt_we <= '0'; bm_dwe <= '0'; sm_we <= '0'; fsm_we <= '0';
        da_we <= '0'; b_we <= '0'; e_we <= '0';
        cl := rnd(900); sr := cl + rnd(100);
        bz_lo <= cl; bz_hi <= sr; bz_start <= '1';
        for a in 8 * cl to 8 * sr + 7 loop rb(a) := 0; end loop;
        cl := rnd(1900); sr := cl + rnd(100);
        ez_lo <= cl; ez_hi <= sr; ez_start <= '1';
        for a in 8 * cl to 8 * sr + 7 loop rbd(a) := 0; end loop;
        wait until rising_edge(clk);
        bz_start <= '0'; ez_start <= '0';
        wait until rising_edge(clk);
        while bz_busy = '1' or ez_busy = '1' loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;

    -- the two physical copies of each polynomial memory must be identical
    ntt_we <= '0'; bm_dwe <= '0'; sm_we <= '0'; fsm_we <= '0'; da_we <= '0';
    b_we <= '0'; e_we <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    for i in pma'range loop
      assert pma(i) = pmb(i)
        report "TB FAIL poly_mem copies differ at row " & integer'image(i)
        severity failure;
    end loop;
    for i in pda'range loop
      assert pda(i) = pdb(i)
        report "TB FAIL poly_mem_d copies differ at row " & integer'image(i)
        severity failure;
    end loop;

    -- full zeroization of everything
    pz_start <= '1'; dz_start <= '1';
    bz_lo <= 0; bz_hi <= 1023; bz_start <= '1';
    ez_lo <= 0; ez_hi <= 2047; ez_start <= '1';
    wait until rising_edge(clk);
    pz_start <= '0'; dz_start <= '0'; bz_start <= '0'; ez_start <= '0';
    wait until rising_edge(clk);
    while pz_busy = '1' or dz_busy = '1' or bz_busy = '1' or ez_busy = '1' loop
      wait until rising_edge(clk);
    end loop;
    wait until rising_edge(clk);
    all_zero("final wipe");
    for i in bmm'range loop
      assert bmm(i) = (bmm(i)'range => '0')
        report "TB FAIL byte_mem word not zero" severity failure;
    end loop;
    for i in bdm'range loop
      assert bdm(i) = (bdm(i)'range => '0')
        report "TB FAIL byte_mem_d word not zero" severity failure;
    end loop;

    report "PQC MEMBANKS PASS checks=" & integer'image(n_chk) &
           " ops=" & integer'image(G_N) severity note;
    done_sim <= true;
    wait;
  end process;
end architecture sim;
