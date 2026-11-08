-- ============================================================================
-- tb_eb.vhd -- PCIE IP, elastic buffer bench (audit 2026-11)
-- Write (recovered) clock 10 ns; read (local) clock offset by +-2000 ppm
-- (much more than the +-600 ppm PCIe budget). The writer sends data symbols
-- with a SKP ordered set (COM + 3 SKP) every SKP_EVERY symbols. Checks:
--   * the non-SKP symbol stream comes out unchanged and in order,
--   * no overflow / underflow,
--   * SKPs were dropped (local clock slower) or added (local clock faster).
-- Run with -gPPM=2000 and -gPPM=-2000.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;

entity tb_eb is
  generic (PPM : integer := 2000; N_SYM : integer := 20000; SKP_EVERY : integer := 100);
end entity;

architecture sim of tb_eb is
  constant TW : time := 10 ns;
  constant TR : time := 10 ns + (10 ns * PPM) / 1000000;
  signal wclk, rclk : std_logic := '0';
  signal fin : boolean := false;
  signal wrst, rrst : std_logic := '1';
  signal w_sym, r_sym : byte_t := (others => '0');
  signal w_k, r_k, r_en, ovf, udf, sadd, sdrop : std_logic := '0';
  signal n_add, n_drop, n_rd : integer := 0;
begin
  wclk <= '0' when fin else not wclk after TW/2;
  rclk <= '0' when fin else not rclk after TR/2;

  dut : entity work.pcie_elastic_buf
    generic map (LOG2_DEPTH => 4, HI_MARK => 10, LO_MARK => 6)
    port map (wclk=>wclk, wrst=>wrst, w_sym=>w_sym, w_k=>w_k, w_en=>'1',
              rclk=>rclk, rrst=>rrst, r_sym=>r_sym, r_k=>r_k, r_en=>r_en,
              ovf=>ovf, udf=>udf, skp_added=>sadd, skp_dropped=>sdrop);

  wr : process
    variable d : integer := 0;
    variable i : integer := 0;
  begin
    wrst <= '1'; for k in 0 to 5 loop wait until rising_edge(wclk); end loop;
    wrst <= '0';
    while d < N_SYM loop
      if i mod SKP_EVERY = 0 then
        w_sym <= K_COM; w_k <= '1'; wait until rising_edge(wclk);
        for s in 1 to 3 loop w_sym <= K_SKP; w_k <= '1'; wait until rising_edge(wclk); end loop;
      end if;
      w_sym <= std_logic_vector(to_unsigned(d mod 256, 8)); w_k <= '0';
      wait until rising_edge(wclk);
      d := d + 1; i := i + 1;
    end loop;
    -- keep sending SKP sets so the reader can drain
    for r in 0 to 20 loop
      w_sym <= K_COM; w_k <= '1'; wait until rising_edge(wclk);
      for s in 1 to 3 loop w_sym <= K_SKP; w_k <= '1'; wait until rising_edge(wclk); end loop;
    end loop;
    wait;
  end process;

  cnt_w : process(wclk) begin
    if rising_edge(wclk) then if sdrop = '1' then n_drop <= n_drop + 1; end if; end if;
  end process;

  rd : process
    variable d : integer := 0;
  begin
    rrst <= '1'; for k in 0 to 5 loop wait until rising_edge(rclk); end loop;
    rrst <= '0';
    loop
      wait until rising_edge(rclk);
      if sadd = '1' then n_add <= n_add + 1; end if;
      if r_en = '1' and r_k = '0' then
        assert r_sym = std_logic_vector(to_unsigned(d mod 256, 8))
          report "EB: data symbol " & integer'image(d) & " lost/duplicated/reordered"
          severity failure;
        d := d + 1; n_rd <= d;
        exit when d = N_SYM;
      end if;
      assert ovf = '0' report "EB: overflow" severity failure;
      assert udf = '0' report "EB: underflow" severity failure;
    end loop;
    if PPM > 0 then
      assert n_drop > 0 report "EB: local clock slower but no SKP dropped" severity failure;
    else
      assert n_add > 0 report "EB: local clock faster but no SKP added" severity failure;
    end if;
    report "TB_EB PASS ppm=" & integer'image(PPM) & " data=" & integer'image(d) &
           " skp_dropped=" & integer'image(n_drop) & " skp_added=" & integer'image(n_add);
    fin <= true; wait;
  end process;
end architecture;
