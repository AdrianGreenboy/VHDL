-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_ntt_d: verifies the ML-DSA NTT datapath against oracle vectors.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Thirty cases: 10 forward, 10 inverse, 10 coefficient-wise products, each
-- compared coefficient by coefficient against mldsa65.py. The end-of-run
-- signature is FNV-1a over every produced coefficient, never over cycle
-- counts.
--
-- Coefficients are compared canonically. The datapath works in a signed
-- representation that is correct modulo q but not reduced, so the testbench
-- normalises before comparing rather than requiring the RTL to reduce, which
-- would cost cycles the algorithm does not need.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity tb_ntt_d is
end entity tb_ntt_d;

architecture sim of tb_ntt_d is

  -- Same lowercase hex helper the ML-KEM testbenches use, so signatures are
  -- directly comparable across blocks.
  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  signal start : std_logic := '0';
  signal op    : std_logic_vector(1 downto 0) := "00";
  signal done  : std_logic;
  signal busy  : std_logic;

  signal u_araddr, u_awaddr, u_braddr : std_logic_vector(7 downto 0);
  signal u_awdata : std_logic_vector(C_CW - 1 downto 0);
  signal u_awe    : std_logic;

  signal m_aslot, m_bslot : integer range 0 to C_SLOTS_D - 1 := 0;
  signal m_araddr, m_awaddr, m_braddr : std_logic_vector(7 downto 0);
  signal m_ardata, m_brdata : std_logic_vector(C_CW - 1 downto 0);
  signal m_awdata : std_logic_vector(C_CW - 1 downto 0);
  signal m_awe    : std_logic;

  -- host access for loading and reading back
  signal h_sel   : std_logic := '1';
  signal h_slot  : integer range 0 to C_SLOTS_D - 1 := 0;
  signal h_addr  : std_logic_vector(7 downto 0) := (others => '0');
  signal h_wdata : std_logic_vector(C_CW - 1 downto 0) := (others => '0');
  signal h_we    : std_logic := '0';

begin

  clk <= not clk after 5 ns;

  u_dut : entity work.ntt_d_unit
    port map (clk => clk, rst_n => rst_n, start => start, op => op,
              done => done, busy => busy,
              a_raddr => u_araddr, a_rdata => m_ardata,
              a_waddr => u_awaddr, a_wdata => u_awdata, a_we => u_awe,
              b_raddr => u_braddr, b_rdata => m_brdata);

  u_mem : entity work.poly_mem_d
    port map (clk => clk,
              a_slot => m_aslot, a_raddr => m_araddr, a_rdata => m_ardata,
              a_waddr => m_awaddr, a_wdata => m_awdata, a_we => m_awe,
              b_slot => m_bslot, b_raddr => m_braddr, b_rdata => m_brdata);

  -- The host owns the memory while h_sel is high, the unit owns it otherwise.
  m_aslot  <= h_slot when h_sel = '1' else 0;
  m_bslot  <= h_slot when h_sel = '1' else 1;
  m_araddr <= h_addr when h_sel = '1' else u_araddr;
  m_braddr <= h_addr when h_sel = '1' else u_braddr;
  m_awaddr <= h_addr when h_sel = '1' else u_awaddr;
  m_awdata <= h_wdata when h_sel = '1' else u_awdata;
  m_awe    <= h_we   when h_sel = '1' else u_awe;

  process
    file     fh   : text;
    variable ln   : line;
    variable tag  : string(1 to 4);
    variable c    : character;
    variable v    : integer;
    variable n    : integer := 0;
    variable nf, ni, np : integer := 0;
    variable sig  : unsigned(63 downto 0) := x"cbf29ce484222325";

    type t_poly is array (0 to 255) of integer;
    variable pin, pin2, pexp : t_poly;

    procedure wait_clk (k : integer) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure fnv (variable s : inout unsigned(63 downto 0);
                   constant x : in integer) is
      variable u : unsigned(31 downto 0);
      variable b : unsigned(63 downto 0);
    begin
      u := unsigned(to_signed(x, 32));
      for k in 0 to 3 loop
        b := resize(u((k * 8 + 7) downto (k * 8)), 64);
        s := s xor b;
        -- the product is 128 bits wide; FNV-1a keeps the low 64
        s := resize(s * x"00000100000001b3", 64);
      end loop;
    end procedure;

    procedure host_write (constant slot : in integer;
                          constant addr : in integer;
                          constant val  : in integer) is
    begin
      h_sel   <= '1';
      h_slot  <= slot;
      h_addr  <= std_logic_vector(to_unsigned(addr, 8));
      h_wdata <= std_logic_vector(to_signed(val, C_CW));
      h_we    <= '1';
      wait_clk(1);
      h_we    <= '0';
      wait_clk(1);
    end procedure;

    procedure host_read (constant slot : in integer;
                         constant addr : in integer;
                         variable val  : out integer) is
    begin
      h_sel  <= '1';
      h_slot <= slot;
      h_addr <= std_logic_vector(to_unsigned(addr, 8));
      wait_clk(2);
      val := to_integer(signed(m_ardata));
    end procedure;

    -- Reduce a signed representative into [0, q) for comparison. The datapath
    -- is correct modulo q without being reduced, and forcing it to reduce
    -- would add cycles the algorithm never asks for.
    function canon (x : integer) return integer is
      variable r : integer;
    begin
      r := x mod C_QD;
      if r < 0 then
        r := r + C_QD;
      end if;
      return r;
    end function canon;

    procedure run_op (constant o : in std_logic_vector(1 downto 0)) is
    begin
      h_sel <= '0';
      wait_clk(2);
      op    <= o;
      start <= '1';
      wait_clk(1);
      start <= '0';
      while done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);
      h_sel <= '1';
      wait_clk(2);
    end procedure;

  begin
    rst_n <= '0';
    wait_clk(5);
    rst_n <= '1';
    wait_clk(5);

    file_open(fh, "ntt_d_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 4 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "NTTF" or tag = "NTTI" then
        for i in 0 to 255 loop
          read(ln, pin(i));
        end loop;
        for i in 0 to 255 loop
          read(ln, pexp(i));
        end loop;

        for i in 0 to 255 loop
          host_write(0, i, pin(i));
        end loop;

        if tag = "NTTF" then
          run_op("00");
          nf := nf + 1;
        else
          run_op("01");
          ni := ni + 1;
        end if;

        for i in 0 to 255 loop
          host_read(0, i, v);
          assert canon(v) = pexp(i)
            report "TB FAIL " & tag & " case " & integer'image(n) &
                   " coeff " & integer'image(i) &
                   " got=" & integer'image(canon(v)) &
                   " exp=" & integer'image(pexp(i))
            severity failure;
          fnv(sig, canon(v));
        end loop;
        n := n + 1;

      elsif tag = "PMUL" then
        for i in 0 to 255 loop
          read(ln, pin(i));
        end loop;
        for i in 0 to 255 loop
          read(ln, pin2(i));
        end loop;
        for i in 0 to 255 loop
          read(ln, pexp(i));
        end loop;

        -- Exactly one operand of every product carries the R^2 lift. The
        -- unit lifts nothing itself, so the vector file supplies operand A
        -- already lifted and the expected output is the PLAIN product. If
        -- the lift were dropped, or applied to both operands, every
        -- coefficient would come out scaled by a power of R and the
        -- comparison below would fail on the first one.
        for i in 0 to 255 loop
          host_write(0, i, pin(i));
          host_write(1, i, pin2(i));
        end loop;

        run_op("10");
        np := np + 1;

        for i in 0 to 255 loop
          host_read(0, i, v);
          assert canon(v) = pexp(i)
            report "TB FAIL PMUL case " & integer'image(n) &
                   " coeff " & integer'image(i) &
                   " got=" & integer'image(canon(v)) &
                   " exp=" & integer'image(pexp(i))
            severity failure;
          fnv(sig, canon(v));
        end loop;
        n := n + 1;
      end if;
    end loop;
    file_close(fh);

    assert nf = 10 and ni = 10
      report "TB FAIL expected 10 forward and 10 inverse cases, got " &
             integer'image(nf) & " and " & integer'image(ni)
      severity failure;

    report "PQC L3B NTTD PASS fwd=" & integer'image(nf) &
           " inv=" & integer'image(ni) &
           " pmul=" & integer'image(np) &
           " sig=" & to_hex(sig)
      severity note;
    wait;
  end process;

end architecture sim;
