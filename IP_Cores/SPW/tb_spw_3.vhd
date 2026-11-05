-- ============================================================================
-- tb_spw_3.vhd -- Layer 3 (audit 2026-11): recovered-clock receiver spw_rx_dsr
-- against an INDEPENDENT Data-Strobe transmitter model at up to 400 Mbit/s.
-- ============================================================================
-- The model encodes characters itself (ECSS-E-ST-50-12C: odd parity over the
-- previous character's data bits + P + flag, LSB-first data, ESC+FCT = NULL,
-- ESC+N-Char = Time-Code) and drives D and S with absolute-time waits:
-- bit k edge at t_k + jitter_k (uniform pseudo-random), with an extra skew
-- applied to S transitions relative to D. The system clock (100 MHz) is
-- asynchronous to the bit grid (no common clock, fractional start offset).
-- Zero code shared with the RTL. A checker compares every decoded event
-- (NULL, FCT, N-Char, EOP/EEP, Time-Code) with the model's own list.
--
--   A  10 Mbit/s, no jitter: mixed characters
--   B  400 Mbit/s, jitter +-0.25 ns, S skew +0.4 ns: 300 random characters
--   C  400 Mbit/s, jitter +-0.30 ns, S skew -0.4 ns: 300 random characters
--   D  rate step 400 -> 10 -> 200 Mbit/s inside one stream
--   E  parity error at 400 Mbit/s -> err_par, HALT; re-arm with rxen
--   F  disconnect at 400 Mbit/s -> err_disc after ~850 ns of silence
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spw_3 is
end entity tb_spw_3;

architecture sim of tb_spw_3 is

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';
  signal rxen : std_logic := '0';
  signal din, sin : std_logic := '0';

  signal first_null, got_null, got_fct, got_time, rx_we : std_logic;
  signal err_par, err_esc, err_disc : std_logic;
  signal time_out : std_logic_vector(7 downto 0);
  signal rx_data  : std_logic_vector(8 downto 0);

  -- expected event list: kind & 9-bit payload
  --   kind 1 NULL, 2 FCT, 3 TIME, 4 DATA (b8: EOP/EEP)
  type ev_t is array (0 to 4095) of std_logic_vector(11 downto 0);
  signal exp_ev  : ev_t := (others => (others => '0'));
  signal exp_n   : integer := 0;         -- produced by the model
  signal got_n   : integer := 0;         -- matched by the checker
  signal resync  : boolean := false;     -- toggled by the model: skip preamble again
  signal n_perr, n_eerr, n_disc : integer := 0;
  signal n_null  : integer := 0;
  signal chk_on  : boolean := true;

begin

  clk <= not clk after 5 ns;             -- 100 MHz

  dut : entity work.spw_rx_dsr
    port map (
      clk => clk, rst => rst, en => '1', rxen => rxen, din => din, sin => sin,
      first_null => first_null, got_null => got_null, got_fct => got_fct,
      got_time => got_time, time_out => time_out,
      rx_we => rx_we, rx_data => rx_data,
      err_par => err_par, err_esc => err_esc, err_disc => err_disc);

  -- --------------------------------------------------------------- checker
  chk : process (clk)
    variable k : std_logic_vector(2 downto 0);
    variable p : std_logic_vector(8 downto 0);
    variable e : std_logic_vector(11 downto 0);
    variable any : boolean;
    variable synced : boolean := false;   -- checker passed the preamble
    variable rs_seen : boolean := false;
  begin
    if rising_edge(clk) then
      if err_par = '1' then n_perr <= n_perr + 1; end if;
      if err_esc = '1' then n_eerr <= n_eerr + 1; end if;
      if err_disc = '1' then n_disc <= n_disc + 1; end if;
      any := true;
      if got_null = '1' then k := "001"; p := (others => '0');
      elsif got_fct = '1' then k := "010"; p := (others => '0');
      elsif got_time = '1' then k := "011"; p := '0' & time_out;
      elsif rx_we = '1' then k := "100"; p := rx_data;
      else any := false;
      end if;
      assert (got_null = '1' and got_fct = '1') = false
        report "FALLO: dos eventos en el mismo ciclo" severity failure;
      if resync /= rs_seen then
        rs_seen := resync;
        synced  := false;
      end if;
      if any and chk_on then
        if not synced then
          -- skip leading NULLs (preamble; the first ones may be lost while
          -- the recovered-clock domain leaves reset)
          if k /= "001" then
            e := exp_ev(got_n);
            assert e = k & p
              report "FALLO: primer evento tras el preambulo incorrecto"
              severity failure;
            synced := true;
            got_n <= got_n + 1;
          end if;
        elsif k = "001" then
          n_null <= n_null + 1;            -- NULLs are counted, not listed
        else
          e := exp_ev(got_n);
          assert got_n < exp_n
            report "FALLO: evento inesperado (no emitido por el modelo)"
            severity failure;
          assert e = k & p
            report "FALLO: evento " & integer'image(got_n) & " esperado "
                   & integer'image(to_integer(unsigned(e))) & " recibido "
                   & integer'image(to_integer(unsigned(k)) * 512 + to_integer(unsigned(p)))
            severity failure;
          got_n <= got_n + 1;
        end if;
      end if;
    end if;
  end process;

  -- ----------------------------------------------------- DS transmitter model
  model : process
    variable seed  : unsigned(31 downto 0) := x"1234ABCD";
    variable tbit  : time := 100 ns;      -- bit period
    variable jit   : time := 0 ns;        -- +- jitter amplitude
    variable skew  : time := 0 ns;        -- extra delay of S transitions
    variable tnext : time;                -- nominal time of the next bit
    variable dl, sl : std_logic := '0';   -- line state
    variable prevp : std_logic := '0';    -- XOR of previous data bits
    variable n     : integer := 0;
    variable bad_parity : boolean := false;
    variable nnull : integer := 0;        -- NULLs sent with ex = true

    impure function rnd return integer is   -- 0..999
    begin
      seed := resize(seed * to_unsigned(1664525, 32), 32) + to_unsigned(1013904223, 32);
      return to_integer(seed(31 downto 22)) mod 1000;
    end function;

    procedure put_bit(b : std_logic) is
      variable t : time;
    begin
      t := tnext;
      if jit > 0 ns then
        t := t + (jit * (rnd - 500)) / 500;
      end if;
      if b /= dl then
        dl := b;
        if t > now then wait for t - now; end if;
        din <= dl;
      else
        sl := not sl;
        t := t + skew;
        if t > now then wait for t - now; end if;
        sin <= sl;
      end if;
      tnext := tnext + tbit;
    end procedure;

    procedure expect(kind : integer; p : std_logic_vector(8 downto 0)) is
    begin
      exp_ev(n) <= std_logic_vector(to_unsigned(kind, 3)) & p;
      n := n + 1;
      exp_n <= n;
    end procedure;

    -- control character: flag 1, 2 data bits (c1 first)
    procedure lchar(c1, c2 : std_logic) is
      variable pb : std_logic;
    begin
      pb := not (prevp xor '1');
      if bad_parity then pb := not pb; bad_parity := false; end if;
      put_bit(pb); put_bit('1'); put_bit(c1); put_bit(c2);
      prevp := c1 xor c2;
    end procedure;

    -- data character: flag 0, 8 data bits LSB first
    procedure nchar(d : std_logic_vector(7 downto 0)) is
      variable pb, x : std_logic;
    begin
      pb := not (prevp xor '0');
      if bad_parity then pb := not pb; bad_parity := false; end if;
      put_bit(pb); put_bit('0');
      x := '0';
      for i in 0 to 7 loop
        put_bit(d(i));
        x := x xor d(i);
      end loop;
      prevp := x;
    end procedure;

    -- NULLs are not in the exact event list (they are link filler and the
    -- last ones of a burst may stay in the receiver's partial 8-bit group);
    -- the checker counts them instead (n_null)
    procedure c_null(ex : boolean) is
    begin
      lchar('1', '1'); lchar('0', '0');
      if ex then nnull := nnull + 1; end if;
    end procedure;
    procedure c_fct is begin lchar('0', '0'); expect(2, (others => '0')); end procedure;
    procedure c_eop is begin lchar('0', '1'); expect(4, "100000000"); end procedure;
    procedure c_eep is begin lchar('1', '0'); expect(4, "100000001"); end procedure;
    procedure c_data(d : std_logic_vector(7 downto 0)) is
    begin nchar(d); expect(4, '0' & d); end procedure;
    procedure c_time(d : std_logic_vector(7 downto 0)) is
    begin lchar('1', '1'); nchar(d); expect(3, '0' & d); end procedure;

    procedure random_chars(cnt : integer) is
      variable r : integer;
    begin
      for i in 1 to cnt loop
        r := rnd;
        if r < 550 then
          c_data(std_logic_vector(to_unsigned(rnd mod 256, 8)));
        elsif r < 650 then c_eop;
        elsif r < 700 then c_eep;
        elsif r < 800 then c_fct;
        elsif r < 850 then c_time(std_logic_vector(to_unsigned(rnd mod 256, 8)));
        else c_null(true);
        end if;
      end loop;
    end procedure;

    procedure wait_events(msg : string) is
    begin
      -- keep the line alive with filler NULLs (as a real link does)
      for i in 1 to 400 loop
        exit when got_n = n;
        c_null(false);
      end loop;
      assert got_n = n
        report "FALLO: " & msg & ": eventos " & integer'image(got_n)
               & " de " & integer'image(n)
        severity failure;
    end procedure;

  begin
    rst <= '1';
    wait for 103 ns;
    rst <= '0';
    rxen <= '1';
    wait for 1 us + 3.7 ns;               -- fractional offset vs clk
    tnext := now;

    -- A: 10 Mbit/s
    report "A: 10 Mbit/s";
    tbit := 100 ns;
    for i in 1 to 4 loop c_null(false); end loop;
    c_fct; c_data(x"00"); c_data(x"FF"); c_data(x"A5"); c_data(x"5A");
    c_eop; c_time(x"15"); c_null(true); c_data(x"3C"); c_eep; c_fct;
    c_null(true); c_null(true);
    wait_events("A");
    assert first_null = '1' report "FALLO: A sin first_null" severity failure;

    -- B: 400 Mbit/s, jitter, +skew
    report "B: 400 Mbit/s, jitter +-0.25 ns, skew +0.4 ns";
    tbit := 2.5 ns; jit := 0.25 ns; skew := 0.4 ns;
    random_chars(300);
    c_null(true);
    wait_events("B");

    -- C: 400 Mbit/s, jitter, -skew
    report "C: 400 Mbit/s, jitter +-0.30 ns, skew -0.4 ns";
    jit := 0.30 ns; skew := -0.4 ns;
    random_chars(300);
    c_null(true);
    wait_events("C");

    -- D: rate steps in one stream
    report "D: 400 -> 10 -> 200 Mbit/s";
    jit := 0 ns; skew := 0 ns;
    tbit := 100 ns; random_chars(10);
    tbit := 5 ns;   jit := 0.5 ns; random_chars(100);
    c_null(true);
    wait_events("D");
    assert n_perr = 0 and n_eerr = 0 and n_disc = 0
      report "FALLO: errores espurios en A-D" severity failure;
    assert n_null >= nnull
      report "FALLO: NULLs perdidos en A-D" severity failure;

    -- E: parity error at 400 Mbit/s
    report "E: error de paridad a 400 Mbit/s";
    tbit := 2.5 ns; jit := 0.25 ns;
    c_data(x"11");
    bad_parity := true;
    nchar(x"22");                         -- not expected: parity error
    for i in 1 to 8 loop c_null(false); end loop;
    wait for 2 us;
    tnext := now;                          -- resume the bit grid after the pause
    assert n_perr = 1
      report "FALLO: E error de paridad no detectado" severity failure;
    assert got_n = n
      report "FALLO: E eventos previos al error perdidos" severity failure;
    -- re-arm: rxen low, then the model keeps sending NULLs + new data
    chk_on <= false;
    rxen <= '0';
    for i in 1 to 40 loop c_null(false); end loop;
    rxen <= '1';
    resync <= not resync;
    chk_on <= true;
    for i in 1 to 20 loop c_null(false); end loop;
    c_data(x"77"); c_eop;
    wait_events("E re-armado");

    -- F: disconnect
    report "F: desconexion";
    c_null(true);
    wait for 2 us;                         -- line frozen after the last bit
    assert n_disc = 1
      report "FALLO: F desconexion no detectada" severity failure;
    assert n_perr = 1 and n_eerr = 0
      report "FALLO: F errores espurios" severity failure;

    report "CAPA 3 PASS: RX con reloj recuperado DS a 400 Mbit/s";
    finish;
  end process;

  wd : process
  begin
    wait for 2 ms;
    assert false report "FALLO: timeout global" severity failure;
  end process;

end architecture sim;
