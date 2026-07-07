-- =============================================================================
--  tb_soc.vhd  -  Testbench del SoC: emula al PS sobre AXI4-Lite
--  Licencia: MIT
--
--  Flujo: (1) carga program.mem en IMEM por AXI, (2) suelta el reset del core
--  (CONTROL=0), (3) espera, (4) detiene el core (CONTROL=1), (5) lee DMEM[0]
--  y verifica que el programa base dejo 42 (sw x3,0(x13)). Tambien lee el PC.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.riscv_pkg.all;

entity tb_soc is
end entity tb_soc;

architecture sim of tb_soc is
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

  -- constantes del mapa AXI
  constant ADDR_CONTROL : std_logic_vector(AW-1 downto 0) := x"0000";
  constant ADDR_DBGPC   : std_logic_vector(AW-1 downto 0) := x"0008";
  constant BASE_IMEM    : integer := 16#1000#;
  constant BASE_DMEM    : integer := 16#2000#;
begin

  aclk <= not aclk after TCK/2;

  dut : entity work.soc_top
    generic map (ADDR_W => AW, DEPTH => 256)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => awaddr, s_axi_awvalid => awvalid, s_axi_awready => awready,
      s_axi_wdata => wdata, s_axi_wstrb => wstrb, s_axi_wvalid => wvalid, s_axi_wready => wready,
      s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
      s_axi_araddr => araddr, s_axi_arvalid => arvalid, s_axi_arready => arready,
      s_axi_rdata => rdata, s_axi_rresp => rresp, s_axi_rvalid => rvalid, s_axi_rready => rready
    );

  stim : process
    variable errors : natural := 0;
    variable l      : line;
    variable w      : word_t;
    variable i      : natural;
    file     fprog  : text;
    variable fstat  : file_open_status;

    procedure axi_write (constant addr : std_logic_vector(AW-1 downto 0);
                         constant data : std_logic_vector(31 downto 0)) is
    begin
      awaddr <= addr; wdata <= data; wstrb <= "1111";
      awvalid <= '1'; wvalid <= '1'; bready <= '1';
      loop wait until rising_edge(aclk); exit when awready = '1'; end loop;
      awvalid <= '0'; wvalid <= '0';
      loop wait until rising_edge(aclk); exit when bvalid = '1'; end loop;
      bready <= '0';
    end procedure;

    procedure axi_read (constant addr : std_logic_vector(AW-1 downto 0);
                        variable data : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= addr; arvalid <= '1'; rready <= '1';
      loop wait until rising_edge(aclk); exit when arready = '1'; end loop;
      arvalid <= '0';
      loop wait until rising_edge(aclk); exit when rvalid = '1'; end loop;
      data := rdata;
      rready <= '0';
    end procedure;

    procedure check (constant got, exp : std_logic_vector(31 downto 0);
                     constant name : string) is
    begin
      if got = exp then
        report "PASS " & name severity note;
      else
        report "FAIL " & name & " got=0x" & to_hstring(got) &
               " exp=0x" & to_hstring(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;

    variable rd : std_logic_vector(31 downto 0);
  begin
    -- reset del PS
    aresetn <= '0';
    wait for 5*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait until rising_edge(aclk);

    -- (1) carga program.mem en IMEM (el core esta detenido: CONTROL.bit0=1)
    file_open(fstat, fprog, "program.mem", read_mode);
    assert fstat = open_ok report "no se pudo abrir program.mem" severity failure;
    i := 0;
    while not endfile(fprog) loop
      readline(fprog, l);
      if l'length > 0 then
        hread(l, w);
        axi_write(std_logic_vector(to_unsigned(BASE_IMEM + i*4, AW)), w);
        i := i + 1;
      end if;
    end loop;
    file_close(fprog);
    report "programa cargado: " & integer'image(i) & " instrucciones" severity note;

    -- (2) suelta el reset del core (CONTROL = 0 -> corre)
    axi_write(ADDR_CONTROL, x"00000000");

    -- (3) deja correr
    for k in 0 to 299 loop wait until rising_edge(aclk); end loop;

    -- (4) detiene el core para poder leer memoria (CONTROL = 1)
    axi_write(ADDR_CONTROL, x"00000001");
    wait until rising_edge(aclk);

    -- (5) lee DMEM[0] (el programa base hizo sw x3=42 en mem[0])
    axi_read(std_logic_vector(to_unsigned(BASE_DMEM + 0, AW)), rd);
    check(rd, x"0000002A", "DMEM[0] = 42 (store del core)");

    -- lee el PC de depuracion (debe estar en el lazo final)
    axi_read(ADDR_DBGPC, rd);
    report "DBG_PC = 0x" & to_hstring(rd) severity note;

    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DEL SOC PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
