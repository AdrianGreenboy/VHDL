-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- tb_pcs_cl49: IEEE 802.3 clause-49 conformance against the independent
-- Python reference oracle/cl49_ref.py (audit 2026-11, fixes A2/A3).
--
--   MODE = "tx": pcs_tx_datapath must produce the reference 64-bit word
--                stream BIT-EXACTLY (sync header order, scrambler, gearbox).
--   MODE = "rx": pcs_rx_datapath is fed a spec stream that starts at an
--                arbitrary bit offset; it must slip to the block boundary,
--                reach block_lock and then decode every block (payload,
--                data/control) exactly, with all sync headers valid.
-- Prints TB_PCS_CL49_<MODE>_PASS or ..._FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_pcs_cl49 is
  generic (
    MODE   : string  := "tx";
    FBLK   : string  := "cl49_blocks.txt";
    FWORDS : string  := "cl49_words.txt";
    NBLK   : natural := 600;
    -- RX: number of consecutive corrupted sync headers injected after the
    -- first lock (cl49_ref.py rx ... b0 bn). Clause 49 drops the lock at the
    -- 16th invalid header of ONE 64-header window, so a consecutive run can
    -- straddle a window boundary: BADN <= 15 must never drop the lock (all
    -- BADN seen while locked); BADN >= 31 must always drop it once, after
    -- 16..31 invalid headers seen while locked. 16..30: phase dependent.
    BADN   : natural := 0
  );
end entity;

architecture sim of tb_pcs_cl49 is
  constant NW : natural := (NBLK * 66) / 64 + 4;
  type v64_arr is array (natural range <>) of std_logic_vector(63 downto 0);
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;

  signal t_in_valid, t_in_isd, t_in_ready, t_out_valid : std_logic := '0';
  signal t_in_pl, t_out_word : std_logic_vector(63 downto 0) := (others => '0');

  signal r_in_valid, r_in_ready, r_out_valid, r_out_isd, r_hdr_ok : std_logic := '0';
  signal r_lock, r_hiber, r_good, r_bad, r_slip, r_lost : std_logic;
  signal r_in_word, r_out_pl : std_logic_vector(63 downto 0) := (others => '0');
begin
  clk <= not clk after 1 ns when not done;

  g_tx: if MODE = "tx" generate
    dut: entity work.pcs_tx_datapath
      port map (clk=>clk, rst=>rst, in_valid=>t_in_valid, in_payload=>t_in_pl,
                in_is_data=>t_in_isd, in_ready=>t_in_ready,
                out_valid=>t_out_valid, out_word=>t_out_word);
  end generate;

  g_rx: if MODE = "rx" generate
    dut: entity work.pcs_rx_datapath
      port map (clk=>clk, rst=>rst, in_valid=>r_in_valid, in_word=>r_in_word,
                in_ready=>r_in_ready, out_valid=>r_out_valid, out_payload=>r_out_pl,
                out_is_data=>r_out_isd, out_hdr_ok=>r_hdr_ok, out_lock=>r_lock,
                out_hi_ber=>r_hiber, ev_goodsh=>r_good, ev_badsh=>r_bad,
                ev_slip=>r_slip, ev_lost=>r_lost);
  end generate;

  main: process
    file fb, fw : text;
    variable l : line;
    variable c : character;
    variable v : std_logic_vector(63 downto 0);
    variable bpl : v64_arr(0 to NBLK-1);
    variable bisd : std_logic_vector(0 to NBLK-1);
    variable words : v64_arr(0 to NW-1);
    variable nb, nw_r : natural := 0;
    variable ib, iw, got, errs, slips, matched, j : natural := 0;
    variable synced : boolean := false;
    variable was_locked : boolean := false;
    variable nbad, nlost : natural := 0;
    variable cyc : natural := 0;
  begin
    file_open(fb, FBLK, read_mode);
    while not endfile(fb) and nb < NBLK loop
      readline(fb, l); read(l, c);              -- 'D' data / 'C' control
      if c = 'D' then bisd(nb) := '1'; else bisd(nb) := '0'; end if;
      read(l, c); hread(l, v);
      bpl(nb) := v;
      nb := nb + 1;
    end loop;
    file_close(fb);
    file_open(fw, FWORDS, read_mode);
    while not endfile(fw) and nw_r < NW loop
      readline(fw, l); hread(l, v); words(nw_r) := v; nw_r := nw_r + 1;
    end loop;
    file_close(fw);

    rst <= '1';
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0';

    if MODE = "tx" then
      ib := 0; iw := 0;
      loop
        -- present the next block; it is taken on an edge with in_ready = 1
        if ib < nb then
          t_in_valid <= '1'; t_in_pl <= bpl(ib); t_in_isd <= bisd(ib);
        else
          t_in_valid <= '0';
        end if;
        wait until rising_edge(clk);
        if t_in_valid = '1' and t_in_ready = '1' then ib := ib + 1; end if;
        if t_out_valid = '1' then
          if iw < nw_r - 1 then
            if t_out_word /= words(iw) then
              if errs < 5 then
                report "TX word " & integer'image(iw) & " got " & to_hstring(t_out_word) &
                       " exp " & to_hstring(words(iw)) severity error;
              end if;
              errs := errs + 1;
            end if;
          end if;
          iw := iw + 1;
        end if;
        cyc := cyc + 1;
        exit when iw >= nw_r - 1 or cyc > 4 * NW;
      end loop;
      if errs = 0 and iw >= nw_r - 1 then
        report "TB_PCS_CL49_TX_PASS words=" & integer'image(iw) & " bit-exact" severity note;
      else
        report "TB_PCS_CL49_TX_FAIL errors=" & integer'image(errs) & " words=" &
               integer'image(iw) severity note;
      end if;
    else
      iw := 0; got := 0; matched := 0; errs := 0; slips := 0;
      loop
        if iw < nw_r then
          r_in_valid <= '1'; r_in_word <= words(iw);
        else
          r_in_valid <= '0';
        end if;
        wait until rising_edge(clk);
        if r_in_valid = '1' and r_in_ready = '1' then iw := iw + 1; end if;
        if r_slip = '1' then slips := slips + 1; end if;
        if r_lock = '1' then was_locked := true; end if;
        -- invalid headers tested while locked (the 16th one drops the lock)
        if r_bad = '1' and (r_lock = '1' or r_lost = '1') then nbad := nbad + 1; end if;
        if r_lost = '1' then nlost := nlost + 1; end if;
        if r_lock = '0' then synced := false; got := 0; end if;
        if r_out_valid = '1' and r_lock = '1' and r_hdr_ok = '0' then
          if synced then j := j + 1; end if;      -- corrupted header: skip
        elsif r_out_valid = '1' and r_lock = '1' then
          got := got + 1;
          if got > 2 then                         -- descrambler settled
            if not synced then
              -- find the transmitted block this output corresponds to
              for k in 0 to NBLK - 1 loop
                if k < nb and bpl(k) = r_out_pl and bisd(k) = r_out_isd then
                  j := k; synced := true; exit;
                end if;
              end loop;
              if not synced then errs := errs + 1; end if;
            end if;
            if synced then
              if j < nb then
                if r_out_pl /= bpl(j) or r_out_isd /= bisd(j) or r_hdr_ok /= '1' then
                  if errs < 5 then
                    report "RX block " & integer'image(j) & " got " & to_hstring(r_out_pl) &
                           " isd=" & std_logic'image(r_out_isd) & " exp " &
                           to_hstring(bpl(j)) & " isd=" & std_logic'image(bisd(j)) severity error;
                  end if;
                  errs := errs + 1;
                else
                  matched := matched + 1;
                end if;
              end if;
              j := j + 1;
            end if;
          end if;
        end if;
        cyc := cyc + 1;
        exit when iw >= nw_r or cyc > 4 * NW;
      end loop;
      -- every block after acquisition must match, up to the end of the stream
      if (BADN > 0 and BADN <= 15 and (nbad /= BADN or nlost /= 0)) or
         (BADN >= 31 and (nbad < 16 or nbad > 31 or nlost /= 1)) then
        report "RX header errors: invalid seen=" & integer'image(nbad) & " lock losses=" &
               integer'image(nlost) & " (injected " & integer'image(BADN) & ")" severity error;
        errs := errs + 1;
      end if;
      if errs = 0 and synced and matched >= 200 and j >= nb - 3 and slips <= 66 + 66 * nlost then
        report "TB_PCS_CL49_RX_PASS matched=" & integer'image(matched) & " slips=" &
               integer'image(slips) severity note;
      else
        report "TB_PCS_CL49_RX_FAIL errors=" & integer'image(errs) & " matched=" &
               integer'image(matched) & " slips=" & integer'image(slips) severity note;
      end if;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
