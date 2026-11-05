-- =============================================================================
--  tb_boot_rom.vhd  -  audit-2026-11: autonomous boot from the boot ROM
--  License: MIT
--
--  soc_top_pipe with BOOT_FROM_ROM = true. The runner compiles a
--  rv32_bootrom_pkg generated from boot_test.mem (gen_bootrom_pkg.py) and
--  pre-loads the IMEM with garbage (IMEM_INIT, simulation only) to model
--  undefined SRAM contents. Checks:
--    * the core starts on its own (no AXI write to CONTROL) and rings the
--      doorbell; the results in DMEM are right (sum 1..10 = 55, 56);
--    * IMEM words past the ROM image were zero-filled by the loader;
--    * AXI-Lite read and write issued in the SAME cycle to the IMEM window
--      (core halted): the read returns the word at the READ address and the
--      write lands (axil_soc read/write serialisation).
--  Runs with SYNC_MEM = true (ASIC mode) and false. Prints TB_BOOT_ROM_PASS.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;
use work.rv32_bootrom_pkg.all;

entity tb_boot_rom is
  generic (
    SYNC_MEM  : boolean := true;
    IMEM_INIT : string  := "garbage.mem"
  );
end entity tb_boot_rom;

architecture sim of tb_boot_rom is
  constant TCK : time := 10 ns;
  constant AW  : natural := 16;
  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal awaddr  : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb   : std_logic_vector(3 downto 0) := "1111";
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';
  signal araddr  : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';
  signal irq     : std_logic;
  signal done    : boolean := false;

  constant ADDR_CONTROL : integer := 16#0000#;
  constant BASE_IMEM    : integer := 16#1000#;
  constant BASE_DMEM    : integer := 16#2000#;
begin
  aclk <= not aclk after TCK/2 when not done else '0';

  dut : entity work.soc_top_pipe
    generic map (ADDR_W => AW, DEPTH => 256, IMEM_INIT => IMEM_INIT,
                 SYNC_MEM => SYNC_MEM, BOOT_FROM_ROM => true)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => awaddr, s_axi_awvalid => awvalid, s_axi_awready => awready,
      s_axi_wdata => wdata, s_axi_wstrb => wstrb, s_axi_wvalid => wvalid, s_axi_wready => wready,
      s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
      s_axi_araddr => araddr, s_axi_arvalid => arvalid, s_axi_arready => arready,
      s_axi_rdata => rdata, s_axi_rresp => rresp, s_axi_rvalid => rvalid, s_axi_rready => rready,
      irq_out => irq
    );

  stim : process
    variable errors : natural := 0;
    variable rd_v   : std_logic_vector(31 downto 0);
    variable got_w, got_r : boolean;

    procedure axi_write (constant a : integer; constant data : std_logic_vector(31 downto 0)) is
    begin
      awaddr <= std_logic_vector(to_unsigned(a, AW));
      wdata <= data; wstrb <= "1111"; awvalid <= '1'; wvalid <= '1'; bready <= '1';
      loop wait until rising_edge(aclk); exit when awready = '1'; end loop;
      awvalid <= '0'; wvalid <= '0';
      loop wait until rising_edge(aclk); exit when bvalid = '1'; end loop;
      bready <= '0';
    end procedure;

    procedure axi_read (constant a : integer; variable data : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, AW)); arvalid <= '1'; rready <= '1';
      loop wait until rising_edge(aclk); exit when arready = '1'; end loop;
      arvalid <= '0';
      loop wait until rising_edge(aclk); exit when rvalid = '1'; end loop;
      data := rdata; rready <= '0';
    end procedure;

    procedure chk (constant ok : boolean; constant name : string) is
    begin
      if ok then report "PASS " & name severity note;
      else report "FAIL " & name severity error; errors := errors + 1; end if;
    end procedure;
  begin
    aresetn <= '0';
    wait for 5*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';

    -- (1) autonomous boot: no host action at all, wait for the doorbell
    for i in 0 to 4000 loop
      wait until rising_edge(aclk);
      exit when irq = '1';
    end loop;
    chk(irq = '1', "core booted from ROM and rang the doorbell");
    axi_read(BASE_DMEM + 64*4, rd_v);
    chk(rd_v = x"00000037", "DMEM[64] = 55 (got 0x" & to_hstring(rd_v) & ")");
    axi_read(BASE_DMEM + 65*4, rd_v);
    chk(rd_v = x"00000038", "DMEM[65] = 56 (got 0x" & to_hstring(rd_v) & ")");

    -- (2) ROM image in IMEM and zero-fill of the rest
    axi_read(BASE_IMEM + 0, rd_v);
    chk(rd_v = BOOT_ROM(0), "IMEM[0] = ROM[0]");
    axi_read(BASE_IMEM + (BOOT_ROM'length - 1)*4, rd_v);
    chk(rd_v = BOOT_ROM(BOOT_ROM'length - 1), "IMEM[last] = ROM[last]");
    axi_read(BASE_IMEM + (BOOT_ROM'length)*4, rd_v);
    chk(rd_v = x"00000000", "IMEM past ROM zero-filled (got 0x" & to_hstring(rd_v) & ")");
    axi_read(BASE_IMEM + 255*4, rd_v);
    chk(rd_v = x"00000000", "IMEM[255] zero-filled");

    -- (3) halt the core, then overlapping AXI-Lite read + write in one cycle
    axi_write(ADDR_CONTROL, x"00000001");
    axi_write(BASE_IMEM + 200*4, x"A5A5A5A5");
    axi_write(BASE_IMEM + 201*4, x"11111111");
    awaddr <= std_logic_vector(to_unsigned(BASE_IMEM + 201*4, AW));
    wdata <= x"22222222"; wstrb <= "1111"; awvalid <= '1'; wvalid <= '1'; bready <= '1';
    araddr <= std_logic_vector(to_unsigned(BASE_IMEM + 200*4, AW)); arvalid <= '1'; rready <= '1';
    got_w := false; got_r := false;
    for i in 0 to 50 loop
      wait until rising_edge(aclk);
      if awready = '1' then awvalid <= '0'; wvalid <= '0'; end if;
      if arready = '1' then arvalid <= '0'; end if;
      if bvalid = '1' and bready = '1' then got_w := true; bready <= '0'; end if;
      if rvalid = '1' and rready = '1' then got_r := true; rd_v := rdata; rready <= '0'; end if;
      exit when got_w and got_r;
    end loop;
    chk(got_w and got_r, "overlapped read and write both completed");
    chk(rd_v = x"A5A5A5A5", "overlapped read returns the READ address word (got 0x" &
        to_hstring(rd_v) & ")");
    axi_read(BASE_IMEM + 201*4, rd_v);
    chk(rd_v = x"22222222", "overlapped write landed");

    if errors = 0 then
      report "TB_BOOT_ROM_PASS (SYNC_MEM=" & boolean'image(SYNC_MEM) & ")" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
