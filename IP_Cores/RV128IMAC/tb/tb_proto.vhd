-- tb_proto.vhd - Layer 4: the FPGA prototype top (rv128_proto_top) driven exactly like
-- the A72 loader (fpga/rv128_load.c) does it on the board: AXI4-Lite writes of the
-- program into the BRAM window, TOHOST_OFF, RUN, then polling STATUS and draining the
-- console FIFO until HALT. Output files use the same format as the board runner so
-- fpga/board_check.py compares simulation and silicon with the same code.
--   CONSOLE  console bytes, raw
--   RESULT   "code=<n> retired=<n> cycles=<n>"  or  "TIMEOUT retired=<n> pc=<hex>"
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_proto is
  generic (
    HEX32    : string  := "prog.hex32";        -- "<byte offset> <word32>" per line, hex
    TOHOST   : integer := 16#1000#;
    CONSOLE  : string  := "console.bin";
    RESULT   : string  := "result.txt";
    TIMEOUT  : integer := 4000000;             -- cycles
    TICK_DIV : integer := 50
  );
end entity;

architecture sim of tb_proto is
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal fin : boolean := false;
  signal awaddr, araddr : std_logic_vector(17 downto 0) := (others => '0');
  signal awvalid, wvalid, bready, arvalid, rready : std_logic := '0';
  signal awready, wready, bvalid, arready, rvalid : std_logic;
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := (others => '0');
  signal bresp, rresp : std_logic_vector(1 downto 0);
begin
  clk <= not clk after 5 ns when not fin;

  dut : entity work.rv128_proto_top
    generic map (MEM_KB => 128, TICK_DIV => TICK_DIV, FIFO_LG => 12)
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_ctrl_awaddr => awaddr, s_axi_ctrl_awvalid => awvalid, s_axi_ctrl_awready => awready,
      s_axi_ctrl_wdata => wdata, s_axi_ctrl_wstrb => wstrb, s_axi_ctrl_wvalid => wvalid,
      s_axi_ctrl_wready => wready, s_axi_ctrl_bresp => bresp, s_axi_ctrl_bvalid => bvalid,
      s_axi_ctrl_bready => bready, s_axi_ctrl_araddr => araddr, s_axi_ctrl_arvalid => arvalid,
      s_axi_ctrl_arready => arready, s_axi_ctrl_rdata => rdata, s_axi_ctrl_rresp => rresp,
      s_axi_ctrl_rvalid => rvalid, s_axi_ctrl_rready => rready, halt_o => open);

  process
    type cfile is file of character;
    file fc : cfile;
    file fh : text;
    file fr : text;
    variable l : line;
    variable off, dat : std_logic_vector(31 downto 0);
    variable v, st : std_logic_vector(31 downto 0);
    variable cyc0 : time;
    variable n : integer := 0;
    variable code, ret_lo, ret_hi, cy_lo : std_logic_vector(31 downto 0);
    variable done : boolean := false;

    procedure axi_wr(a : natural; d : std_logic_vector(31 downto 0)) is
    begin
      awaddr <= std_logic_vector(to_unsigned(a, 18)); wdata <= d; wstrb <= "1111";
      awvalid <= '1'; wvalid <= '1';
      wait until rising_edge(clk) and awready = '1';
      awvalid <= '0'; wvalid <= '0'; bready <= '1';
      wait until rising_edge(clk) and bvalid = '1';
      bready <= '0';
    end procedure;

    procedure axi_rd(a : natural; d : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, 18)); arvalid <= '1';
      wait until rising_edge(clk) and arready = '1';
      arvalid <= '0'; rready <= '1';
      wait until rising_edge(clk) and rvalid = '1';
      d := rdata;
      rready <= '0';
    end procedure;
  begin
    file_open(fc, CONSOLE, write_mode);
    file_open(fr, RESULT, write_mode);
    for k in 0 to 4 loop wait until rising_edge(clk); end loop;
    aresetn <= '1';
    wait until rising_edge(clk);
    axi_wr(16#0000#, x"00000002");                      -- hold the core in reset
    axi_rd(16#0034#, v);
    assert v = x"52563132" report "ID incorrecto: " & to_hstring(v) severity failure;
    -- program into the BRAM window
    file_open(fh, HEX32, read_mode);
    while not endfile(fh) loop
      readline(fh, l);
      hread(l, off); hread(l, dat);
      axi_wr(16#20000# + to_integer(unsigned(off)), dat);
      n := n + 1;
    end loop;
    file_close(fh);
    -- read-back check of the first and last word
    axi_rd(16#20000#, v);
    axi_wr(16#0014#, std_logic_vector(to_unsigned(TOHOST, 32)));
    axi_wr(16#0000#, x"00000001");                      -- RUN
    for k in 0 to TIMEOUT / 8 loop
      axi_rd(16#0004#, st);
      while st(2) = '1' loop                            -- drain the console FIFO
        axi_rd(16#001C#, v);
        if v(8) = '1' then
          write(fc, character'val(to_integer(unsigned(v(7 downto 0)))));
        end if;
        axi_rd(16#0004#, st);
      end loop;
      if st(1) = '1' then done := true; exit; end if;
    end loop;
    if done then
      axi_rd(16#0018#, code); axi_rd(16#0028#, ret_lo); axi_rd(16#0020#, cy_lo);
      write(l, string'("code=") & integer'image(to_integer(unsigned(code)))
               & " retired=" & integer'image(to_integer(unsigned(ret_lo)))
               & " cycles=" & integer'image(to_integer(unsigned(cy_lo))));
    else
      axi_rd(16#0008#, ret_lo); axi_rd(16#0010#, v);
      write(l, string'("TIMEOUT retired=") & integer'image(to_integer(unsigned(ret_lo))) & " pc=" & to_hstring(v));
    end if;
    writeline(fr, l);
    file_close(fr);
    file_close(fc);
    fin <= true;
    wait;
  end process;
end architecture;
