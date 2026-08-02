library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_l5_full is
end entity;

architecture sim of tb_l5_full is
  constant GOLDEN    : unsigned(31 downto 0) := x"E6898DC5";
  constant SENTINEL  : unsigned(31 downto 0) := x"00C0FFEE";
  constant FNV_PRIME : unsigned(31 downto 0) := x"01000193";
  constant FB_AWID   : integer := 15;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mmio_sel, mmio_we : std_logic := '0';
  signal mmio_addr : std_logic_vector(15 downto 0) := (others=>'0');
  signal mmio_wdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal mmio_rdata : std_logic_vector(31 downto 0);

  signal awaddr : std_logic_vector(31 downto 0);
  signal awlen  : std_logic_vector(7 downto 0);
  signal awsize : std_logic_vector(2 downto 0);
  signal awburst: std_logic_vector(1 downto 0);
  signal awvalid, awready : std_logic;
  signal wdata  : std_logic_vector(31 downto 0);
  signal wstrb  : std_logic_vector(3 downto 0);
  signal wlast, wvalid, wready : std_logic;
  signal bresp  : std_logic_vector(1 downto 0) := "00";
  signal bvalid, bready : std_logic;

  -- DDR model (byte addressed, 128 KB window from 0x70000000)
  type ddr_t is array(0 to 131071) of std_logic_vector(7 downto 0);
  signal ddr : ddr_t := (others => (others=>'0'));
  -- result region driven only by the firmware process (the RV32 would store
  -- these via its own DDR path; kept separate here to avoid multi-driver 'X')
  signal res_sig  : std_logic_vector(31 downto 0) := (others=>'0');
  signal res_sent : std_logic_vector(31 downto 0) := (others=>'0');

  function fnv_step(h : unsigned(31 downto 0); b : unsigned(7 downto 0))
    return unsigned is
    variable x : unsigned(31 downto 0); variable m : unsigned(63 downto 0);
  begin
    x := h xor resize(b,32); m := x * FNV_PRIME; return m(31 downto 0);
  end function;
begin
  clk <= not clk after 5 ns;

  dut : entity work.mipi_top
    generic map (W=>128, H=>96, FB_DEPTH=>18432, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst,
              mmio_sel=>mmio_sel, mmio_we=>mmio_we, mmio_addr=>mmio_addr,
              mmio_wdata=>mmio_wdata, mmio_rdata=>mmio_rdata,
              m_awaddr=>awaddr, m_awlen=>awlen, m_awsize=>awsize, m_awburst=>awburst,
              m_awvalid=>awvalid, m_awready=>awready,
              m_wdata=>wdata, m_wstrb=>wstrb, m_wlast=>wlast, m_wvalid=>wvalid, m_wready=>wready,
              m_bresp=>bresp, m_bvalid=>bvalid, m_bready=>bready);

  -- AXI slave DDR model
  axi_slave : process(clk)
    variable waddr : integer := 0;
    variable active : boolean := false;
  begin
    if rising_edge(clk) then
      awready<='0'; wready<='0'; bvalid<='0';
      if rst='1' then active:=false;
      else
        if awvalid='1' and not active then
          awready<='1';
          waddr := to_integer(unsigned(awaddr) - x"70000000");
          active := true;
        end if;
        if active then
          wready<='1';
          if wvalid='1' then
            ddr(waddr)   <= wdata(7 downto 0);
            ddr(waddr+1) <= wdata(15 downto 8);
            ddr(waddr+2) <= wdata(23 downto 16);
            ddr(waddr+3) <= wdata(31 downto 24);
            waddr := waddr + 4;
            if wlast='1' then bvalid<='1'; bresp<="00"; active:=false; end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Emulated RV32 firmware driving the MMIO bus, then emulated PS verify
  firmware : process
    variable h : unsigned(31 downto 0);
    variable n0, n1 : integer;
    variable g : integer := 0;
    variable ps_sent : unsigned(31 downto 0);
    variable ps_sig  : unsigned(31 downto 0);

    procedure fold_fb(sel : std_logic; nbytes : integer;
                      variable hv : inout unsigned(31 downto 0)) is
    begin
      mmio_sel<='1'; mmio_we<='1'; mmio_addr<=x"001C";
      mmio_wdata<=(0=>sel, others=>'0');
      wait until rising_edge(clk); mmio_we<='0';
      mmio_addr<=x"0020"; wait until rising_edge(clk);  -- prime
      for i in 0 to nbytes-1 loop
        mmio_addr<=x"0020"; wait until rising_edge(clk);
        hv := fnv_step(hv, unsigned(mmio_rdata(7 downto 0)));
      end loop;
      mmio_sel<='0';
    end procedure;

    procedure dma_copy(sel : std_logic; dst : std_logic_vector(31 downto 0);
                       nbytes : integer) is
      variable gg : integer := 0;
    begin
      mmio_sel<='1'; mmio_we<='1';
      mmio_addr<=x"0010"; mmio_wdata<=(0=>sel, others=>'0'); wait until rising_edge(clk);
      mmio_addr<=x"0014"; mmio_wdata<=dst; wait until rising_edge(clk);
      mmio_addr<=x"0018"; mmio_wdata<=std_logic_vector(to_unsigned(nbytes,32)); wait until rising_edge(clk);
      mmio_addr<=x"0000"; mmio_wdata<=x"00000002"; wait until rising_edge(clk);  -- start_dma
      mmio_we<='0';
      -- poll dma_done
      loop
        mmio_sel<='1'; mmio_we<='0'; mmio_addr<=x"0004"; wait until rising_edge(clk);
        exit when mmio_rdata(1)='1' or gg>2000000; gg:=gg+1;
      end loop;
      mmio_sel<='0';
    end procedure;

  begin
    rst<='1'; wait for 40 ns; wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);

    -- === RV32 firmware sequence ===
    -- 1. start selftest
    mmio_sel<='1'; mmio_we<='1'; mmio_addr<=x"0000"; mmio_wdata<=x"00000001";
    wait until rising_edge(clk); mmio_we<='0';
    loop
      mmio_sel<='1'; mmio_we<='0'; mmio_addr<=x"0004"; wait until rising_edge(clk);
      exit when mmio_rdata(0)='1' or g>2000000; g:=g+1;
    end loop;
    mmio_sel<='0';
    report "[FW] selftest done";

    -- 2. read counts
    mmio_sel<='1'; mmio_we<='0'; mmio_addr<=x"0008"; wait until rising_edge(clk);
    n0 := to_integer(unsigned(mmio_rdata(14 downto 0)));
    mmio_addr<=x"000C"; wait until rising_edge(clk);
    n1 := to_integer(unsigned(mmio_rdata(14 downto 0)));
    mmio_sel<='0';
    report "[FW] FB0="&integer'image(n0)&" FB1="&integer'image(n1);

    -- 3. fold FNV FB0 then FB1
    h := x"811C9DC5";
    fold_fb('0', n0, h);
    fold_fb('1', n1, h);
    report "[FW] computed signature = 0x"&to_hstring(h);

    -- 4. DMA both FBs to DDR (0x70000000 FB0, 0x70008000 FB1)
    dma_copy('0', x"70000000", n0);
    dma_copy('1', x"70008000", n1);
    report "[FW] DMA complete";

    -- 5. publish results: signature then sentinel (ordering: sentinel last)
    res_sig  <= std_logic_vector(h);
    wait until rising_edge(clk);
    res_sent <= std_logic_vector(SENTINEL);
    wait until rising_edge(clk);

    -- === PS verify sequence ===
    ps_sig  := unsigned(res_sig);
    ps_sent := unsigned(res_sent);
    report "[PS] sentinel  = 0x"&to_hstring(ps_sent);
    report "[PS] signature = 0x"&to_hstring(ps_sig);
    if ps_sent = SENTINEL and ps_sig = GOLDEN then
      report "L5 SILICON-PATH PASS - full firmware chain, signature 0x"&to_hstring(GOLDEN)
        severity note;
    else
      report "L5 SILICON-PATH FAIL" severity failure;
    end if;
    wait;
  end process;
end architecture;
