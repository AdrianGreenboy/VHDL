-- =============================================================================
--  tb_accel.vhd  -  Valida el flujo del acelerador (lo mismo que riscv_accel.c)
--  Licencia: MIT
--
--  Replica en simulacion lo que hace la app de Linux: carga accel_sumsq.mem en
--  IMEM por AXI, escribe N y el arreglo en DMEM, arranca el core, hace polling
--  de la bandera de "listo" por AXI, y lee el resultado. Verifica la suma de
--  cuadrados de 1..5 = 55.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.riscv_pkg.all;

entity tb_accel is
end entity tb_accel;

architecture sim of tb_accel is
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

  constant ADDR_CONTROL : integer := 16#0000#;
  constant BASE_IMEM    : integer := 16#1000#;
  constant BASE_DMEM    : integer := 16#2000#;
  constant DMEM_N       : integer := 0;
  constant DMEM_ARR     : integer := 1;
  constant DMEM_RESULT  : integer := 64;
  constant DMEM_DONE    : integer := 65;
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
    variable rd_v   : std_logic_vector(31 downto 0);

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

  begin
    aresetn <= '0';
    wait for 5*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait until rising_edge(aclk);

    -- (1) core detenido (CONTROL.bit0 = 1 al reset). Carga el acelerador en IMEM.
    file_open(fstat, fprog, "accel_sumsq.mem", read_mode);
    assert fstat = open_ok report "no se pudo abrir accel_sumsq.mem" severity failure;
    i := 0;
    while not endfile(fprog) loop
      readline(fprog, l);
      if l'length > 0 then
        hread(l, w);
        axi_write(BASE_IMEM + i*4, w);
        i := i + 1;
      end if;
    end loop;
    file_close(fprog);

    -- (2) escribe entradas: N=5, arreglo 1..5
    axi_write(BASE_DMEM + DMEM_N*4, x"00000005");
    for k in 1 to 5 loop
      axi_write(BASE_DMEM + (DMEM_ARR + k-1)*4, std_logic_vector(to_unsigned(k, 32)));
    end loop;
    axi_write(BASE_DMEM + DMEM_DONE*4, x"00000000");   -- limpia bandera

    -- (3) arranca el core
    axi_write(ADDR_CONTROL, x"00000000");

    -- (4) polling de la bandera "listo" (lecturas funcionan aunque corra)
    loop
      axi_read(BASE_DMEM + DMEM_DONE*4, rd_v);
      exit when rd_v /= x"00000000";
    end loop;

    -- (5) lee el resultado y detiene el core
    axi_read(BASE_DMEM + DMEM_RESULT*4, rd_v);
    axi_write(ADDR_CONTROL, x"00000001");

    if rd_v = x"00000037" then    -- 55
      report "PASS sum de cuadrados 1..5 = 55" severity note;
    else
      report "FAIL got=0x" & to_hstring(rd_v) & " exp=0x00000037" severity error;
      errors := errors + 1;
    end if;

    report "-----------------------------------------";
    if errors = 0 then
      report "EL FLUJO DEL ACELERADOR FUNCIONA" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
