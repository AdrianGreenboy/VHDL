-- tb_pqc_top: exercise the synthesis top through real AXI-Lite transactions,
-- exactly as the PS binary will: write control.start, poll status.done, read
-- the four signature words, compare against the two 64-bit expected values.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pqc_top is end entity;
architecture sim of tb_pqc_top is
  signal clk : std_logic := '0';
  signal rstn : std_logic := '0';
  signal awaddr, araddr : std_logic_vector(7 downto 0) := (others=>'0');
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic := '0';
  signal arvalid, arready, rvalid, rready : std_logic := '0';
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb : std_logic_vector(3 downto 0) := "1111";
  signal bresp, rresp : std_logic_vector(1 downto 0);
  function hx(v:unsigned(31 downto 0)) return string is
    constant D:string(1 to 16):="0123456789abcdef"; variable r:string(1 to 8);
  begin for i in 0 to 7 loop r(8-i):=D(to_integer(v(4*i+3 downto 4*i))+1); end loop; return r; end;
begin
  clk <= not clk after 5 ns;
  dut : entity work.pqc_top
    port map (s_axi_aclk=>clk, s_axi_aresetn=>rstn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready);

  process
    procedure axi_write(constant a:std_logic_vector(7 downto 0); constant d:std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      awaddr<=a; awvalid<='1'; wdata<=d; wvalid<='1'; bready<='1';
      wait until rising_edge(clk) and awready='1';
      awvalid<='0'; wvalid<='0';
      wait until rising_edge(clk) and bvalid='1';
      bready<='0';
    end procedure;
    procedure axi_read(constant a:std_logic_vector(7 downto 0); variable d:out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      araddr<=a; arvalid<='1'; rready<='1';
      wait until rising_edge(clk) and arready='1';
      arvalid<='0';
      wait until rising_edge(clk) and rvalid='1';
      d:=rdata; rready<='0';
    end procedure;
    variable r : std_logic_vector(31 downto 0);
    variable kl,kh,dl,dh : std_logic_vector(31 downto 0);
  begin
    rstn<='0'; wait for 80 ns; rstn<='1'; wait for 40 ns;
    -- launch self-test
    axi_write(x"00", x"00000001");
    -- poll status.done (bit3)
    loop
      axi_read(x"04", r);
      exit when r(3)='1';
    end loop;
    report "status = " & hx(unsigned(r)) severity note;
    axi_read(x"08", kl); axi_read(x"0c", kh);
    axi_read(x"10", dl); axi_read(x"14", dh);
    report "kem_sig = " & hx(unsigned(kh)) & hx(unsigned(kl)) severity note;
    report "dsa_sig = " & hx(unsigned(dh)) & hx(unsigned(dl)) severity note;
    assert r(0)='1' report "TOP FAIL: pass bit not set" severity failure;
    assert kh=x"95e07091" and kl=x"fa5b3cc4" report "TOP FAIL: kem sig" severity failure;
    assert dh=x"f93232f7" and dl=x"ea2d1575" report "TOP FAIL: dsa sig" severity failure;
    report "PQC L5 TOP PASS kem=95e07091fa5b3cc4 dsa=f93232f7ea2d1575 via_axi=1" severity note;
    std.env.finish; wait;
  end process;
end architecture;
