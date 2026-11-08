-- tb_datapath.vhd - Verifica rf_datapath contra el oraculo por muestra.
-- AUDIT 2026-11: per-sample, bit-exact comparison against model/rf_model.py
-- (cycle-accurate model of the datapath, round-half-up contract) at several
-- operating points read from rf_oracle.txt ("python3 ../model/rf_model.py
-- --dump rf_oracle.txt"): op0 = historical bring-up point (DC tone,
-- passthrough FIR, golden 0x32783005), op1 = moving tone + low-pass FIR with
-- negative taps, op2 = other RX NCO + high-pass-ish FIR. For each point the
-- DUT is reset, the 16 coefficients loaded, rx enabled and 64 samples popped
-- from the RX FIFO; every word and the canonical checksum must match.
-- Any mismatch -> assert severity failure ("FIN SIMULACION DATAPATH: FAIL").
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_datapath is
  generic (OPFILE : string := "rf_oracle.txt");
end entity tb_datapath;

architecture sim of tb_datapath is
  constant C_TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal rx_en : std_logic := '0';
  signal ftw_rx, tone_ftw : std_logic_vector(31 downto 0) := (others=>'0');
  signal coef_we : std_logic := '0';
  signal coef_addr : std_logic_vector(3 downto 0) := (others=>'0');
  signal coef_data : std_logic_vector(15 downto 0) := (others=>'0');
  signal rssi : std_logic_vector(15 downto 0);
  signal rd_en : std_logic := '0';
  signal rd_data : std_logic_vector(31 downto 0);
  signal empty, full, ovf : std_logic;
  signal level : std_logic_vector(9 downto 0);
  signal fin : boolean := false;
begin
  clk <= '0' when fin else not clk after C_TCLK/2;

  dut : entity work.rf_datapath
    port map (clk_i=>clk, aresetn_i=>aresetn, rx_en_i=>rx_en,
              ftw_i=>ftw_rx, tone_ftw_i=>tone_ftw,
              coef_we_i=>coef_we, coef_addr_i=>coef_addr, coef_data_i=>coef_data,
              rssi_o=>rssi, rxf_rd_en_i=>rd_en, rxf_rd_data_o=>rd_data,
              rxf_empty_o=>empty, rxf_full_o=>full, rxf_level_o=>level,
              rxf_ovf_o=>ovf, rxf_ovf_clr_i=>'0');

  proc : process
    file fh : text;
    variable st : file_open_status;
    variable ln : line;
    variable nops, nsamp, errs : integer := 0;
    variable vftw, vtone, vchk, w, expw : std_logic_vector(31 downto 0);
    variable c16 : std_logic_vector(15 downto 0);
    type coef_t is array (0 to 15) of std_logic_vector(15 downto 0);
    variable cf : coef_t;
    variable chk : unsigned(31 downto 0);
    variable n : integer;
    variable tag : string(1 to 2);
  begin
    file_open(st, fh, OPFILE, read_mode);
    assert st = open_ok report "no " & OPFILE severity failure;
    readline(fh, ln); read(ln, nops);
    for op in 0 to nops-1 loop
      readline(fh, ln); read(ln, tag); hread(ln, vftw); hread(ln, vtone);
      read(ln, nsamp); hread(ln, vchk);
      readline(fh, ln);
      for k in 0 to 15 loop hread(ln, c16); cf(k) := c16; end loop;
      -- reset, configure, load coefficients, enable
      rx_en <= '0'; aresetn <= '0';
      ftw_rx <= vftw; tone_ftw <= vtone;
      wait for 3*C_TCLK;
      aresetn <= '1';
      wait until rising_edge(clk);
      for k in 0 to 15 loop
        coef_addr <= std_logic_vector(to_unsigned(k,4)); coef_data <= cf(k); coef_we <= '1';
        wait until rising_edge(clk);
        coef_we <= '0';
        wait until rising_edge(clk);
      end loop;
      rx_en <= '1';
      chk := (others => '0'); n := 0;
      while n < nsamp loop
        wait until rising_edge(clk);
        if empty = '0' then
          w := rd_data;
          rd_en <= '1';
          wait until rising_edge(clk);
          rd_en <= '0';
          readline(fh, ln); hread(ln, expw);
          if w /= expw then
            errs := errs + 1;
            if errs < 10 then
              report "op" & integer'image(op) & " sample " & integer'image(n) &
                     " got 0x" & to_hstring(w) & " exp 0x" & to_hstring(expw) severity error;
            end if;
          end if;
          chk := (chk(30 downto 0) & chk(31)) xor unsigned(w);
          n := n + 1;
        end if;
      end loop;
      if std_logic_vector(chk) /= vchk then
        errs := errs + 1;
        report "op" & integer'image(op) & " CHK=0x" & to_hstring(chk) & " exp 0x" & to_hstring(vchk) severity error;
      else
        report "op" & integer'image(op) & " CHK=0x" & to_hstring(chk) & " OK (" & integer'image(nsamp) & " samples bit-exact)";
      end if;
      assert ovf = '0' report "unexpected RX FIFO overflow" severity failure;
    end loop;
    file_close(fh);
    assert errs = 0
      report "FIN SIMULACION DATAPATH: FAIL errores=" & integer'image(errs) severity failure;
    report "FIN SIMULACION DATAPATH: PASS OPS=" & integer'image(nops) & " @ " & time'image(now) severity note;
    fin <= true;
    wait;
  end process;
end architecture sim;
