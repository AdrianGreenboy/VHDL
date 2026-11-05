-- ============================================================================
-- tb_adc_audit.vhd (AUDIT 2026-11): self-checking tests of the audit fixes.
--  A) External modulator on its OWN clock (pdm_clk 37 ns vs aclk 10 ns,
--     asynchronous): adc_core in ext_clk mode must deliver to the CIC exactly
--     the bit sequence of the modulator. Checked differentially against a
--     second adc_core in legacy mode fed the same bits synchronously (one CIC
--     valid per bit): both must output the identical sample sequence.
--     The bit stream is an independent 1st-order sigma-delta of a sine.
--  A2) Same check with pdm_clk 13 ns (f_pdm = 0.77 f_aclk): still exact.
--  B) Modulator faster than aclk (pdm_clk 7 ns): ext_ovr must be reported.
--  C) adc_mmio FIFO overflow: pushes beyond capacity set IRQ_STAT bit2
--     (sticky), raise irq when IRQ_EN bit2, W1C clears; STATUS unchanged.
--  D) DMA/MMIO grant: with dma_busy_i='1' a FIFO_DATA read is held off
--     (ready='0', no pop) while DMA pops proceed; on release it pops once.
--  E) A FIFO_DATA read with sel held 3 cycles pops exactly once.
-- Pass: "ADC AUDIT PASS". Any error -> assert severity failure.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_adc_audit is
end entity;

architecture sim of tb_adc_audit is
  constant NBITS : integer := 6000;
  constant NSMP  : integer := 18;
  type bits_t is array (0 to NBITS-1) of std_logic;
  function gen_bits return bits_t is
    variable b : bits_t; variable acc, x : real := 0.0;
  begin
    for k in 0 to NBITS-1 loop
      x := 0.6 * sin(2.0 * MATH_PI * real(k) / 701.0);
      if acc >= 0.0 then b(k) := '1'; acc := acc + x - 1.0;
      else b(k) := '0'; acc := acc + x + 1.0; end if;
    end loop;
    return b;
  end function;
  constant BITS : bits_t := gen_bits;

  signal clk : std_logic := '0';
  signal pclk : std_logic := '0';
  signal pclk_half : time := 18.5 ns;
  signal aresetn : std_logic := '0';
  signal fin : boolean := false;

  -- A/B: cores
  signal x_pdm : std_logic;
  signal r_pdm, r_en : std_logic := '0';
  signal x_smp, r_smp : std_logic_vector(23 downto 0);
  signal x_sv, r_sv, x_ovr, x_fb, r_fb, x_to, r_to : std_logic;
  type smp_a is array (0 to NSMP-1) of std_logic_vector(23 downto 0);
  signal xs, rs : smp_a;
  signal nx, nr, novr : integer := 0;
  signal pdm_run : boolean := false;
  signal bit_idx : integer := 0;
  signal bit_rst : boolean := false;
  signal a2_rst  : boolean := false;

  -- C/D/E: mmio
  signal rst : std_logic := '1';
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(7 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq, ready, push, dma_busy, dma_rd : std_logic := '0';
  signal pword : std_logic_vector(31 downto 0) := (others => '0');
begin
  clk  <= '0' when fin else not clk after 5 ns;
  pclk <= '0' when fin else not pclk after pclk_half;

  -- ---------------------------------------------------------------- A/B
  u_x : entity work.adc_core
    port map (clk => clk, aresetn => aresetn, en_i => '1', src_sel_i => '1',
              finc_i => x"00193000", osr_sel_i => "10", pdm_ext_i => x_pdm,
              pdm_clk_i => pclk, ext_clk_i => '1', ext_ovr_o => x_ovr,
              pdm_fb_o => x_fb, ext_timeout_o => x_to,
              sample_o => x_smp, sample_valid_o => x_sv);
  u_r : entity work.adc_core
    port map (clk => clk, aresetn => aresetn, en_i => r_en, src_sel_i => '1',
              finc_i => x"00193000", osr_sel_i => "10", pdm_ext_i => r_pdm,
              pdm_clk_i => '0', ext_clk_i => '0', ext_ovr_o => open,
              pdm_fb_o => r_fb, ext_timeout_o => r_to,
              sample_o => r_smp, sample_valid_o => r_sv);

  -- modulator: x_pdm = BITS(bit_idx); the index advances right after every
  -- pdm_clk rising edge at which the DUT captures (aresetn='1'), i.e. the
  -- modulator changes its output just after the edge, like a real one.
  x_pdm <= BITS(bit_idx);
  proc_mod : process (pclk, bit_rst)
  begin
    if bit_rst then
      bit_idx <= 0;
    elsif rising_edge(pclk) then
      if aresetn = '1' and pdm_run and bit_idx < NBITS - 1 then
        bit_idx <= bit_idx + 1;
      end if;
    end if;
  end process;

  -- reference: legacy path, one bit per 3 aclk, en pulse when s2 holds it
  proc_ref : process
  begin
    wait until aresetn = '1';
    loop
    wait until rising_edge(clk);
    for k in 0 to NBITS-1 loop
      r_pdm <= BITS(k);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      r_en <= '1';
      wait until rising_edge(clk);
      r_en <= '0';
      exit when aresetn = '0';
    end loop;
    if aresetn /= '0' then wait until aresetn = '0'; end if;
    wait until aresetn = '1';
    end loop;
  end process;

  proc_cap : process (clk)
  begin
    if rising_edge(clk) then
      if a2_rst then nx <= 0; nr <= 0; novr <= 0; end if;
      if x_sv = '1' and nx < NSMP then xs(nx) <= x_smp; nx <= nx + 1; end if;
      if r_sv = '1' and nr < NSMP then rs(nr) <= r_smp; nr <= nr + 1; end if;
      if x_ovr = '1' then novr <= novr + 1; end if;
    end if;
  end process;

  -- ---------------------------------------------------------------- C/D/E
  u_m : entity work.adc_mmio
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              smp_push_i => push, smp_word_i => pword,
              enable => open, src_sel => open, osr_sel => open, finc => open,
              ext_timeout_i => '0', dma_addr => open, dma_len => open, dma_go => open,
              dma_busy_i => dma_busy, dma_done_p_i => '0', dma_fifo_rd_i => dma_rd,
              fifo_rdata_o => open, fifo_empty_o => open, dbg_i => x"00000000",
              ready => ready, ext_ovr_i => '0', ext_clk => open);

  stim : process
    variable errs : integer := 0;
    variable r : std_logic_vector(31 downto 0);
    procedure fail(m : string) is
    begin errs := errs + 1; report "FALLO ADC AUDIT: " & m severity error; end procedure;
    procedure wr32(a : std_logic_vector(7 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk); sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk); sel <= '0'; we <= '0';
    end procedure;
    procedure rd32(a : std_logic_vector(7 downto 0); v : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk); sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns; v := rdata;
      wait until rising_edge(clk); sel <= '0';
    end procedure;
    procedure push_n(n : integer; base : integer) is
    begin
      for k in 0 to n-1 loop
        wait until rising_edge(clk);
        pword <= std_logic_vector(to_unsigned(base + k, 32)); push <= '1';
      end loop;
      wait until rising_edge(clk); push <= '0';
      for k in 1 to 4 loop wait until rising_edge(clk); end loop;
    end procedure;
    variable lvl0 : integer;
  begin
    -- ---- A
    aresetn <= '0'; rst <= '1'; pdm_run <= true;
    wait for 100 ns; wait until rising_edge(clk);
    aresetn <= '1'; rst <= '0';
    wait until nx = NSMP and nr = NSMP for 2 ms;
    if nx /= NSMP or nr /= NSMP then
      fail("A: not enough samples ext=" & integer'image(nx) & " ref=" & integer'image(nr));
    else
      for k in 0 to NSMP-1 loop
        if xs(k) /= rs(k) then
          fail("A: sample " & integer'image(k) & " ext=0x" & to_hstring(xs(k)) &
               " ref=0x" & to_hstring(rs(k)));
        end if;
      end loop;
    end if;
    if novr /= 0 then fail("A: spurious ext_ovr at f_pdm < f_aclk/2"); end if;
    report "A: " & integer'image(NSMP) & " CIC samples, pdm_clk path == legacy reference";
    -- ---- A2: modulator at 13 ns (0.77 f_aclk): must still be exact.
    -- Restart both cores from reset with the same bit stream.
    pdm_run <= false;
    aresetn <= '0'; pclk_half <= 6.5 ns;
    wait for 100 ns;
    bit_rst <= true; wait for 100 ns; bit_rst <= false;
    a2_rst <= true; wait until rising_edge(clk); a2_rst <= false;
    pdm_run <= true;
    wait until rising_edge(clk);
    aresetn <= '1';
    wait until nx = NSMP and nr = NSMP for 2 ms;
    for k in 0 to NSMP-1 loop
      if xs(k) /= rs(k) then
        fail("A2: sample " & integer'image(k) & " ext=0x" & to_hstring(xs(k)) &
             " ref=0x" & to_hstring(rs(k)));
      end if;
    end loop;
    if novr /= 0 then fail("A2: spurious ext_ovr at f_pdm = 0.77 f_aclk"); end if;
    report "A2: pdm_clk 13 ns path == legacy reference, no overrun";
    -- ---- B: modulator faster than aclk (7 ns): overrun must be reported
    pdm_run <= false;
    pclk_half <= 3.5 ns;
    wait for 200 ns;
    bit_rst <= true; wait for 100 ns; bit_rst <= false; pdm_run <= true;
    wait for 20 us;
    if novr = 0 then fail("B: overrun not reported with pdm_clk 7 ns"); end if;
    report "B: ext_ovr events=" & integer'image(novr);
    pdm_run <= false;

    -- ---- C: FIFO overflow sticky + IRQ + W1C
    wr32(x"14", x"00000004");                     -- IRQ_EN bit2
    push_n(520, 16#1000#);
    rd32(x"18", r);
    if r(2) /= '1' then fail("C: IRQ_STAT bit2 (OVFL) not set, got " & to_hstring(r)); end if;
    if irq /= '1' then fail("C: irq not raised by OVFL"); end if;
    rd32(x"04", r);
    if r /= x"00000004" then fail("C: STATUS changed (compat) got " & to_hstring(r)); end if;
    rd32(x"0C", r);
    if to_integer(unsigned(r)) /= 514 then fail("C: level " & integer'image(to_integer(unsigned(r)))); end if;
    -- drain a little and confirm the flag is sticky
    rd32(x"10", r);
    if r /= x"00001000" then fail("C: head order got " & to_hstring(r)); end if;
    rd32(x"18", r);
    if r(2) /= '1' then fail("C: OVFL not sticky"); end if;
    wr32(x"18", x"00000004");                     -- W1C
    rd32(x"18", r);
    if r(2) /= '0' then fail("C: W1C did not clear OVFL"); end if;
    if irq /= '0' then fail("C: irq still high after W1C"); end if;

    -- ---- E: sel held 3 cycles on FIFO_DATA pops exactly once
    rd32(x"0C", r); lvl0 := to_integer(unsigned(r));
    wait until rising_edge(clk); sel <= '1'; we <= '0'; addr <= x"10";
    for k in 1 to 3 loop wait until rising_edge(clk); end loop;
    sel <= '0';
    for k in 1 to 4 loop wait until rising_edge(clk); end loop;
    rd32(x"0C", r);
    if to_integer(unsigned(r)) /= lvl0 - 1 then
      fail("E: held read popped " & integer'image(lvl0 - to_integer(unsigned(r))) & " words");
    end if;

    -- ---- D: DMA owns the FIFO -> MMIO read held off, DMA pops proceed
    rd32(x"0C", r); lvl0 := to_integer(unsigned(r));
    wait until rising_edge(clk);
    dma_busy <= '1';
    sel <= '1'; we <= '0'; addr <= x"10";
    for k in 1 to 6 loop
      wait until rising_edge(clk);
      if ready /= '0' then fail("D: ready not held off while DMA busy"); end if;
      dma_rd <= '1' when k <= 2 else '0';            -- DMA pops 2 words
    end loop;
    dma_rd <= '0';
    wait until rising_edge(clk);
    dma_busy <= '0';                                  -- DMA releases the FIFO
    wait for 1 ns;
    if ready /= '1' then fail("D: ready not released"); end if;
    wait until rising_edge(clk);
    sel <= '0';
    for k in 1 to 4 loop wait until rising_edge(clk); end loop;
    rd32(x"0C", r);
    if to_integer(unsigned(r)) /= lvl0 - 3 then
      fail("D: level " & integer'image(to_integer(unsigned(r))) & " exp " & integer'image(lvl0 - 3)
           & " (2 DMA pops + 1 MMIO pop)");
    end if;

    assert errs = 0 report "ADC AUDIT FAIL errores=" & integer'image(errs) severity failure;
    report "ADC AUDIT PASS";
    fin <= true;
    wait;
  end process;
end architecture;
