-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- tb_mac_cl49: the MAC_25G PCS encoders against the independent clause-49
-- reference PCS_25G/oracle/cl49_ref.py (audit 2026-11, fix A2):
--   MODE = "pcs66" : mac25g_pcs66_tx 66-bit blocks bit-exact (block bit 0 =
--                    first bit on the wire), and mac25g_pcs66_rx decodes the
--                    reference blocks back (payload + data/control)
--   MODE = "pcs_tx": mac25g_pcs_tx (line-rate gearbox) 64-bit words bit-exact
-- Prints TB_MAC_CL49_<MODE>_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_mac_cl49 is
  generic (
    MODE : string  := "pcs66";
    FBLK : string  := "cl49_blocks.txt";
    FEXP : string  := "cl49_b66.txt";
    NBLK : natural := 600
  );
end entity;

architecture sim of tb_mac_cl49 is
  type v64_arr is array (natural range <>) of std_logic_vector(63 downto 0);
  type v68_arr is array (natural range <>) of std_logic_vector(67 downto 0);
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  signal iv, isd, ordy, ov, rv, risd : std_logic := '0';
  signal ipl, ow, rpl : std_logic_vector(63 downto 0) := (others => '0');
  signal ob : std_logic_vector(65 downto 0);
  signal rb : std_logic_vector(65 downto 0) := (others => '0');
  signal rbv : std_logic := '0';
begin
  clk <= not clk after 1 ns when not done;

  g66: if MODE = "pcs66" generate
    u_tx: entity work.mac25g_pcs66_tx
      port map (clk=>clk, rst=>rst, in_valid=>iv, in_payload=>ipl, in_is_data=>isd,
                out_valid=>ov, out_block=>ob);
    u_rx: entity work.mac25g_pcs66_rx
      port map (clk=>clk, rst=>rst, in_valid=>rbv, in_block=>rb,
                out_valid=>rv, out_payload=>rpl, out_is_data=>risd, out_hdr_ok=>open);
    ordy <= '1';
  end generate;
  gtx: if MODE = "pcs_tx" generate
    u_tx: entity work.mac25g_pcs_tx
      port map (clk=>clk, rst=>rst, in_valid=>iv, in_payload=>ipl, in_is_data=>isd,
                in_ready=>ordy, out_valid=>ov, out_word=>ow);
  end generate;

  main: process
    file fb, fe : text;
    variable l : line;
    variable c : character;
    variable v : std_logic_vector(63 downto 0);
    variable v68 : std_logic_vector(67 downto 0);
    variable bpl : v64_arr(0 to NBLK-1);
    variable bisd : std_logic_vector(0 to NBLK-1);
    variable ex : v68_arr(0 to NBLK+20);
    variable nb, ne, ib, io, ir, ifr, errs, cyc : natural := 0;
  begin
    file_open(fb, FBLK, read_mode);
    while not endfile(fb) and nb < NBLK loop
      readline(fb, l); read(l, c);
      if c = 'D' then bisd(nb) := '1'; else bisd(nb) := '0'; end if;
      read(l, c); hread(l, v); bpl(nb) := v; nb := nb + 1;
    end loop;
    file_close(fb);
    file_open(fe, FEXP, read_mode);
    while not endfile(fe) and ne < NBLK + 20 loop
      readline(fe, l);
      if MODE = "pcs66" then hread(l, v68); else hread(l, v); v68 := x"0" & v; end if;
      ex(ne) := v68; ne := ne + 1;
    end loop;
    file_close(fe);

    rst <= '1';
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    rst <= '0';
    loop
      if ib < nb then iv <= '1'; ipl <= bpl(ib); isd <= bisd(ib); else iv <= '0'; end if;
      -- pcs66 RX: feed the REFERENCE blocks
      if MODE = "pcs66" and ifr < ne then rbv <= '1'; rb <= ex(ifr)(65 downto 0); else rbv <= '0'; end if;
      wait until rising_edge(clk);
      if rbv = '1' then ifr := ifr + 1; end if;
      if iv = '1' and ordy = '1' then ib := ib + 1; end if;
      if ov = '1' then
        if MODE = "pcs66" then
          if io < ne and ob /= ex(io)(65 downto 0) then
            if errs < 5 then report "block " & integer'image(io) & " got " & to_hstring(ob) &
                                    " exp " & to_hstring(ex(io)(65 downto 0)) severity error; end if;
            errs := errs + 1;
          end if;
        else
          if io < ne - 1 and ow /= ex(io)(63 downto 0) then
            if errs < 5 then report "word " & integer'image(io) & " got " & to_hstring(ow) &
                                    " exp " & to_hstring(ex(io)(63 downto 0)) severity error; end if;
            errs := errs + 1;
          end if;
        end if;
        io := io + 1;
      end if;
      if MODE = "pcs66" and rv = '1' then
        -- descrambler output; the first block depends on the unknown state
        if ir >= 1 and ir < nb and (rpl /= bpl(ir) or risd /= bisd(ir)) then
          if errs < 5 then report "rx block " & integer'image(ir) & " mismatch" severity error; end if;
          errs := errs + 1;
        end if;
        ir := ir + 1;
      end if;
      cyc := cyc + 1;
      exit when (io >= ne - 1 and (MODE /= "pcs66" or ir >= nb - 1)) or cyc > 4 * NBLK + 100;
    end loop;
    if errs = 0 and io >= ne - 1 then
      report "TB_MAC_CL49_" & MODE & "_PASS units=" & integer'image(io) & " bit-exact" severity note;
    else
      report "TB_MAC_CL49_" & MODE & "_FAIL errors=" & integer'image(errs) severity note;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
