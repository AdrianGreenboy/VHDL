-- ============================================================================
-- fp32_fma_rtl.vhd -- Synthesizable, pipelined IEEE-754 binary32 FMA
-- (audit 2026-11, IP ADCS). Portable RTL: no vendor primitives, every stage
-- is plain logic + registers (ASIC: IHP SG13G2 / sky130; FPGA: any).
--
--   result = a*b + c   fused, ONE rounding, round-to-nearest-even,
-- BIT-EXACT with fp32_pkg.fma_fp32 (the numeric contract of this IP):
--   * FTZ: inputs with exponent 0 are +/-0; results < 2^-126 (after
--     rounding) are +/-0 with the result sign.
--   * any NaN input -> canonical qNaN 0x7FC00000; Inf*0 -> qNaN;
--     Inf - Inf -> qNaN; Inf otherwise propagates with its sign.
--   * a*b exactly zero: c returned unchanged; 0 + 0 keeps the sign if both
--     signs agree, else +0.
--   * exact cancellation of non-zero terms -> +0.
--   * overflow (after rounding) -> +/-Inf.
--
-- Datapath (exactness argument in AUDIT_FIXES.md):
--   S1  unpack, classify/specials, 24x24 product (48 b)
--   S2  align C in a 78-bit window (product at bits 51:4, C retained down to
--       bit 1, one dedicated sticky bit at bit 0 for C bits shifted out; if C
--       dominates by >= 50 positions it is clamped at 50 and the product only
--       acts as a sticky, which provably yields the same rounding), 79-bit
--       add / subtract with sign-magnitude result
--   S3  leading-zero count + normalise (24 b mantissa, guard, sticky)
--   S4  RNE rounding, exponent adjust, FTZ / overflow / specials select
-- Total latency LAT_FMA (>= 4): the 4 compute stages plus LAT_FMA-4 output
-- registers (balanced by retiming in synthesis if needed). Throughput 1/cycle.
-- MUT (verification only): 1 = truncate, 2 = sticky lost, 3 = bias + 1.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fp32_fma_rtl is
  generic (
    LAT_FMA : natural := 8;
    MUT     : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    in_valid  : in  std_logic;
    a         : in  std_logic_vector(31 downto 0);
    b         : in  std_logic_vector(31 downto 0);
    c         : in  std_logic_vector(31 downto 0);
    out_valid : out std_logic;
    result    : out std_logic_vector(31 downto 0)
  );
end entity fp32_fma_rtl;

architecture rtl of fp32_fma_rtl is
  constant NSTG : natural := 4;
  constant W    : natural := 79;          -- add/sub width (78-bit window + carry)
  constant QNAN : std_logic_vector(31 downto 0) := x"7FC00000";

  subtype exp_t is integer range -1024 to 1023;

  -- S1 -> S2
  signal s1_v, s1_spec, s1_czero, s1_sp, s1_sc : std_logic := '0';
  signal s1_specv : std_logic_vector(31 downto 0) := (others => '0');
  signal s1_mp    : unsigned(47 downto 0) := (others => '0');
  signal s1_mc    : unsigned(23 downto 0) := (others => '0');
  signal s1_ep, s1_ecg : exp_t := 0;
  -- S2 -> S3
  signal s2_v, s2_spec, s2_zero, s2_sign : std_logic := '0';
  signal s2_specv : std_logic_vector(31 downto 0) := (others => '0');
  signal s2_mag   : unsigned(W-1 downto 0) := (others => '0');
  signal s2_eanc  : exp_t := 0;
  -- S3 -> S4
  signal s3_v, s3_spec, s3_zero, s3_sign : std_logic := '0';
  signal s3_specv : std_logic_vector(31 downto 0) := (others => '0');
  signal s3_mant  : unsigned(23 downto 0) := (others => '0');
  signal s3_guard, s3_stick : std_logic := '0';
  signal s3_e     : exp_t := 0;
  -- S4 output
  signal s4_v : std_logic := '0';
  signal s4_r : std_logic_vector(31 downto 0) := (others => '0');

  type dly_t is array (natural range <>) of std_logic_vector(31 downto 0);

  -- leading-one position of a W-bit vector (W-1 .. 0), -1 if zero
  function lead1(x : unsigned(W-1 downto 0)) return integer is
  begin
    for i in W-1 downto 0 loop
      if x(i) = '1' then return i; end if;
    end loop;
    return -1;
  end function;
begin
  assert LAT_FMA >= NSTG report "fp32_fma_rtl: LAT_FMA must be >= 4" severity failure;

  -- ======================= S1: unpack / specials / multiply ================
  s1_p : process(clk, rst_n)
    variable ea, eb, ec : integer range 0 to 255;
    variable az, bz, cz, ai, bi, ci, an, bn, cn : boolean;
    variable sp : std_logic;
  begin
    if rst_n = '0' then
      s1_v <= '0';
    elsif rising_edge(clk) then
      s1_v <= in_valid;
      ea := to_integer(unsigned(a(30 downto 23)));
      eb := to_integer(unsigned(b(30 downto 23)));
      ec := to_integer(unsigned(c(30 downto 23)));
      az := ea = 0; bz := eb = 0; cz := ec = 0;
      ai := ea = 255 and unsigned(a(22 downto 0)) = 0;
      bi := eb = 255 and unsigned(b(22 downto 0)) = 0;
      ci := ec = 255 and unsigned(c(22 downto 0)) = 0;
      an := ea = 255 and not ai; bn := eb = 255 and not bi; cn := ec = 255 and not ci;
      sp := a(31) xor b(31);

      s1_spec <= '1';
      if an or bn or cn then
        s1_specv <= QNAN;
      elsif ai or bi then
        if (ai and bz) or (bi and az) or (ci and c(31) /= sp) then
          s1_specv <= QNAN;
        else
          s1_specv <= sp & "1111111100000000000000000000000";
        end if;
      elsif ci then
        s1_specv <= c(31) & "1111111100000000000000000000000";
      elsif az or bz then
        if cz then
          if sp = c(31) then s1_specv <= sp & "0000000000000000000000000000000";
          else s1_specv <= x"00000000"; end if;
        else
          s1_specv <= c;                       -- product exactly zero
        end if;
      else
        s1_spec <= '0';
        s1_specv <= (others => '0');
      end if;

      s1_sp <= sp;
      s1_sc <= c(31);
      s1_czero <= '1' when cz else '0';
      s1_mp <= unsigned('1' & a(22 downto 0)) * unsigned('1' & b(22 downto 0));
      if cz then
        s1_mc <= (others => '0');
      else
        s1_mc <= unsigned('1' & c(22 downto 0));
      end if;
      s1_ep  <= ea + eb - 300;                -- weight of the product LSB
      s1_ecg <= ec - 150;                     -- weight of the addend LSB
    end if;
  end process;

  -- ======================= S2: align + add/subtract =========================
  s2_p : process(clk, rst_n)
    variable al, ash, sh : integer;
    variable pw, cw : unsigned(W-1 downto 0);
    variable wide   : unsigned(71 downto 0);
    variable stk    : std_logic;
    variable d      : unsigned(W downto 0);
    variable eanc   : exp_t;
    variable sub    : boolean;
  begin
    if rst_n = '0' then
      s2_v <= '0';
    elsif rising_edge(clk) then
      s2_v <= s1_v;
      s2_spec <= s1_spec; s2_specv <= s1_specv;

      if s1_czero = '1' then al := 0; else al := s1_ecg - s1_ep; end if;
      if al >= 50 then
        ash := 50; eanc := s1_ecg - 50;        -- C dominates: clamp
      else
        ash := al; eanc := s1_ep;
      end if;

      pw := shift_left(resize(s1_mp, W), 4);  -- product at window bits 51:4
      stk := '0';
      if ash >= -3 then
        cw := shift_left(resize(s1_mc, W), ash + 4);
      else
        sh := -3 - ash;                        -- >= 1 bits fall below bit 1
        if sh > 48 then sh := 48; end if;
        wide := shift_right(resize(s1_mc, 72) sll 48, sh);
        cw := (others => '0');
        cw(24 downto 1) := wide(71 downto 48);
        if wide(47 downto 0) /= 0 then stk := '1'; end if;
      end if;
      cw(0) := stk;                            -- dedicated sticky bit

      sub := s1_sp /= s1_sc and s1_czero = '0';
      if not sub then
        d := resize(pw, W+1) + resize(cw, W+1);
        s2_mag  <= d(W-1 downto 0);
        s2_sign <= s1_sp;
      else
        d := resize(pw, W+1) - resize(cw, W+1);
        if d(W) = '0' then
          s2_mag <= d(W-1 downto 0); s2_sign <= s1_sp;
        else
          d := (not d) + 1;
          s2_mag <= d(W-1 downto 0); s2_sign <= s1_sc;
        end if;
      end if;
      s2_zero <= '1' when pw = cw and sub else '0';   -- exact cancellation
      s2_eanc <= eanc;
    end if;
  end process;

  -- ======================= S3: normalise ====================================
  s3_p : process(clk, rst_n)
    variable l : integer;
    variable n : unsigned(W-1 downto 0);
  begin
    if rst_n = '0' then
      s3_v <= '0';
    elsif rising_edge(clk) then
      s3_v <= s2_v;
      s3_spec <= s2_spec; s3_specv <= s2_specv; s3_sign <= s2_sign;
      l := lead1(s2_mag);
      if l < 0 then
        s3_zero <= '1'; l := 0;
      else
        s3_zero <= s2_zero;
      end if;
      n := shift_left(s2_mag, W-1 - l);
      s3_mant  <= n(W-1 downto W-24);
      s3_guard <= n(W-25);
      if n(W-26 downto 0) /= 0 then s3_stick <= '1'; else s3_stick <= '0'; end if;
      s3_e <= s2_eanc + l - 4;                 -- unbiased exponent of the leading 1
    end if;
  end process;

  -- ======================= S4: round + pack =================================
  s4_p : process(clk, rst_n)
    variable m25 : unsigned(24 downto 0);
    variable e   : integer;
    variable g, s, rup : std_logic;
  begin
    if rst_n = '0' then
      s4_v <= '0';
    elsif rising_edge(clk) then
      s4_v <= s3_v;
      g := s3_guard; s := s3_stick;
      if MUT = 2 then s := '0'; end if;
      rup := g and (s or s3_mant(0));
      if MUT = 1 then rup := '0'; end if;
      m25 := resize(s3_mant, 25);
      if rup = '1' then m25 := m25 + 1; end if;
      e := s3_e + 127;
      if m25(24) = '1' then
        m25 := shift_right(m25, 1); e := e + 1;
      end if;
      if MUT = 3 then e := e + 1; end if;
      if s3_spec = '1' then
        s4_r <= s3_specv;
      elsif s3_zero = '1' then
        s4_r <= x"00000000";                   -- exact cancellation -> +0
      elsif e >= 255 then
        s4_r <= s3_sign & "1111111100000000000000000000000";
      elsif e < 1 then
        s4_r <= s3_sign & "0000000000000000000000000000000";   -- FTZ
      else
        s4_r <= s3_sign & std_logic_vector(to_unsigned(e, 8)) &
                std_logic_vector(m25(22 downto 0));
      end if;
    end if;
  end process;

  -- ======================= output delay (LAT_FMA - 4) =======================
  g_nodly : if LAT_FMA = NSTG generate
    result    <= s4_r;
    out_valid <= s4_v;
  end generate;
  g_dly : if LAT_FMA > NSTG generate
    signal dly_d : dly_t(1 to LAT_FMA - NSTG) := (others => (others => '0'));
    signal dly_v : std_logic_vector(1 to LAT_FMA - NSTG) := (others => '0');
  begin
    dly_p : process(clk, rst_n)
    begin
      if rst_n = '0' then
        dly_v <= (others => '0');
      elsif rising_edge(clk) then
        dly_d(1) <= s4_r;
        dly_v(1) <= s4_v;
        for i in 2 to LAT_FMA - NSTG loop
          dly_d(i) <= dly_d(i-1);
          dly_v(i) <= dly_v(i-1);
        end loop;
      end if;
    end process;
    result    <= dly_d(LAT_FMA - NSTG);
    out_valid <= dly_v(LAT_FMA - NSTG);
  end generate;
end architecture rtl;
