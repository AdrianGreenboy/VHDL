-------------------------------------------------------------------------------
-- tb_dsp_mmio_l2d.vhd  --  Layer 2d (AUDIT 2026-11): robustness contract.
--
--  A) START parameter validation: every out-of-range LOG2N / FIR_LEN /
--     DATA_LEN / reserved FUNC must finish quickly with DONE=1 and ERR=1,
--     must not touch DATA, and ERR must be W1C. A valid op afterwards works
--     and reports ERR=0.
--  B) FFT_SAT sticky bit (STATUS bit3): set iff the oracle saw saturation,
--     results bit-exact against dsp_oracle.py, W1C clears it.
--  C) DATA window read-after-write with 0/1/2 idle cycles between the write
--     and the read (and back-to-back reads of the same word): must always
--     return the freshly written value.
--
-- Bus master holds req until ready (family dmem contract).
-- Pass: "L2D OK" and errors=0. Self-checking, assert severity failure.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_dsp_mmio_l2d is
end entity;

architecture sim of tb_dsp_mmio_l2d is
  constant CLK_P : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal req : std_logic := '0';
  signal addr: std_logic_vector(15 downto 0) := (others=>'0');
  signal wdata: std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb: std_logic_vector(3 downto 0) := (others=>'0');
  signal rdata: std_logic_vector(31 downto 0);
  signal ready: std_logic;
  signal sim_done : boolean := false;
begin

  dut : entity work.dsp_mmio
    port map (clk=>clk, rst=>rst, req=>req, addr=>addr,
              wdata=>wdata, wstrb=>wstrb, rdata=>rdata, ready=>ready);

  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    variable errors : integer := 0;
    variable rv : std_logic_vector(31 downto 0);
    file fh : text open read_mode is "tb_fft_sat_mmio.mem";
    variable ln : line;
    variable ncases, l2, invf, n, satexp : integer;
    variable tag : string(1 to 4);
    variable win, wout : std_logic_vector(31 downto 0);
    type wmem_t is array (0 to 1023) of std_logic_vector(31 downto 0);
    variable expw : wmem_t;
    variable mism : integer;

    -- single-cycle write (no settle cycle; the next access may follow at once)
    procedure wr0(a : std_logic_vector(15 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      addr<=a; wdata<=d; wstrb<="1111"; req<='1';
      wait until rising_edge(clk);
      req<='0'; wstrb<="0000";
    end procedure;
    procedure idle(k : natural) is
    begin
      for i in 1 to k loop wait until rising_edge(clk); end loop;
    end procedure;
    procedure wr(a : std_logic_vector(15 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wr0(a, d); idle(1);
    end procedure;
    -- read holding req until ready; sample rdata in the ready cycle
    procedure rd(a : std_logic_vector(15 downto 0); v : out std_logic_vector(31 downto 0)) is
    begin
      addr<=a; req<='1'; wstrb<="0000";
      for t in 0 to 5000 loop
        wait for 1 ns;
        if ready='1' then exit; end if;
        wait until rising_edge(clk);
      end loop;
      assert ready='1' report "read timeout" severity failure;
      v := rdata;
      wait until rising_edge(clk);
      req<='0';
    end procedure;
    procedure chk(cond : boolean; msg : string) is
    begin
      if not cond then
        errors := errors + 1;
        report "FALLO: " & msg severity warning;
      end if;
    end procedure;
    procedure wait_done(v : out std_logic_vector(31 downto 0); maxpolls : natural) is
      variable r : std_logic_vector(31 downto 0);
    begin
      for w in 0 to maxpolls loop
        rd(x"0008", r);
        exit when r(1)='1';
      end loop;
      v := r;
    end procedure;
    -- launch with an expected rejection
    procedure expect_err(ctrl : std_logic_vector(31 downto 0); msg : string) is
      variable r : std_logic_vector(31 downto 0);
    begin
      wr(x"1010", x"5A5A1234");               -- DATA[4] canary
      wr(x"0004", ctrl);
      wait_done(r, 8);                         -- must finish almost at once
      chk(r(1)='1', msg & ": DONE not set");
      chk(r(2)='1', msg & ": ERR not set");
      chk(r(0)='0', msg & ": still BUSY");
      rd(x"1010", r);
      chk(r = x"5A5A1234", msg & ": DATA modified got=" & to_hstring(r));
      wr(x"0008", x"00000006");               -- W1C DONE+ERR
      rd(x"0008", r);
      chk(r(2 downto 1)="00", msg & ": W1C failed got=" & to_hstring(r));
    end procedure;
  begin
    rst<='1'; wait for 4*CLK_P; wait until rising_edge(clk); rst<='0'; idle(2);

    ---------------------------------------------------------------- A
    wr(x"000C", x"00000008");  wr(x"0024", x"00000010");
    wr(x"0010", x"00000000");  expect_err(x"00000005", "FIR_LEN=0");
    wr(x"0010", x"00000041");  expect_err(x"00000005", "FIR_LEN=65");
    wr(x"0010", x"00000010");  wr(x"0024", x"00000000");
    expect_err(x"00000005", "FIR DATA_LEN=0");
    wr(x"0024", x"00000401");  expect_err(x"00000005", "FIR DATA_LEN=1025");
    wr(x"000C", x"0000000B");  expect_err(x"00000001", "FFT LOG2N=11");
    wr(x"000C", x"00000000");  expect_err(x"00000003", "IFFT LOG2N=0");
    wr(x"000C", x"0000000F");  expect_err(x"00000003", "IFFT LOG2N=15");
    wr(x"000C", x"00000109");  expect_err(x"00000001", "FFT LOG2N high bits");
    wr(x"000C", x"00000009");  wr(x"0024", x"00000100");
    expect_err(x"00000011", "REALPACK DATA_LEN/=2**LOG2N");
    wr(x"000C", x"00000001");  wr(x"0024", x"00000002");
    expect_err(x"00000011", "REALPACK LOG2N=1");
    expect_err(x"0000000F", "FUNC=111 reserved");
    -- a valid op after the errors: CORDIC rotation of angle 0 -> cos ~ 32767
    wr(x"0014", x"00000000");
    wr(x"0004", x"00000007");
    wait_done(rv, 64);
    chk(rv(1)='1' and rv(2)='0', "valid CORDIC after errors: STATUS=" & to_hstring(rv));
    rd(x"001C", rv);
    chk(signed(rv(15 downto 0)) > 32700, "CORDIC cos(0) got=" & to_hstring(rv));
    wr(x"0008", x"00000002");

    ---------------------------------------------------------------- B
    readline(fh, ln); read(ln, ncases);
    for c in 0 to ncases-1 loop
      readline(fh, ln); read(ln, tag); read(ln, l2); read(ln, invf); read(ln, n); read(ln, satexp);
      for t in 0 to n-1 loop
        readline(fh, ln); hread(ln, win); hread(ln, wout);
        wr(std_logic_vector(to_unsigned(16#1000# + 4*t, 16)), win);
        expw(t) := wout;
      end loop;
      wr(x"000C", std_logic_vector(to_unsigned(l2, 32)));
      if invf = 1 then wr(x"0004", x"00000003"); else wr(x"0004", x"00000001"); end if;
      wait_done(rv, 200000);
      chk(rv(1)='1' and rv(2)='0', "FFT case "&integer'image(c)&" STATUS="&to_hstring(rv));
      chk((rv(3)='1') = (satexp=1), "FFT_SAT case "&integer'image(c)&" got="&std_logic'image(rv(3))
                                     &" exp="&integer'image(satexp));
      mism := 0;
      for t in 0 to n-1 loop
        rd(std_logic_vector(to_unsigned(16#1000# + 4*t, 16)), rv);
        if rv /= expw(t) then mism := mism + 1; end if;
      end loop;
      chk(mism = 0, "FFT via MMIO case "&integer'image(c)&" mismatches="&integer'image(mism));
      if satexp = 1 then
        wr(x"0008", x"00000008");             -- W1C FFT_SAT
        rd(x"0008", rv);
        chk(rv(3)='0', "FFT_SAT W1C failed");
      end if;
      wr(x"0008", x"00000002");
    end loop;
    file_close(fh);

    ---------------------------------------------------------------- C
    for gap in 0 to 2 loop
      -- prime the read port on the address, then overwrite and read back
      wr(x"1100", x"11111111");
      rd(x"1100", rv);
      chk(rv = x"11111111", "RAW prime gap="&integer'image(gap));
      wr0(x"1100", std_logic_vector(to_unsigned(16#22220000# + gap, 32)));
      idle(gap);
      rd(x"1100", rv);
      chk(rv = std_logic_vector(to_unsigned(16#22220000# + gap, 32)),
          "RAW gap="&integer'image(gap)&" got="&to_hstring(rv));
      rd(x"1100", rv);                        -- back-to-back same address
      chk(rv = std_logic_vector(to_unsigned(16#22220000# + gap, 32)),
          "RAR gap="&integer'image(gap)&" got="&to_hstring(rv));
      -- interleave: write A, write B, read A, read B with no gaps
      wr0(x"1200", x"AAAA0000"); wr0(x"1204", x"BBBB0000");
      rd(x"1200", rv); chk(rv = x"AAAA0000", "interleave A got="&to_hstring(rv));
      rd(x"1204", rv); chk(rv = x"BBBB0000", "interleave B got="&to_hstring(rv));
      wr0(x"1200", x"CCCC0000");
      rd(x"1200", rv); chk(rv = x"CCCC0000", "rewrite A got="&to_hstring(rv));
    end loop;

    report "L2D errores=" & integer'image(errors);
    assert errors=0 report "MUTANTE VIVO: "&integer'image(errors)&" fallos" severity failure;
    report "L2D OK - validacion START, FFT_SAT y RAW de la ventana DATA";
    sim_done<=true; wait;
  end process;
end architecture;
