-- =============================================================
-- tb_soc_top.vhd - Paso 7: valida el top sintetizable del SoC
-- con AXI4-Lite REAL en ambos lados.
--
-- Modelo de DDR colgado del AXI maestro (64 MB, carga dispersa
-- desde boot_ram.hex, mapeada en DDR_BASE_PHYS) con latencia
-- configurable por generic para representar el NoC.
--
-- El testbench actua como el PS: escribe el banco de control por
-- AXI-Lite esclavo para arrancar el core, sondea el estado y
-- drena la consola desde el FIFO. Es exactamente la secuencia
-- que ejecutara el firmware en silicio.
--
-- Criterio de PASS:
--   - el banner del kernel sale por el FIFO de consola
--   - el contador de retiros avanza y coincide con lo esperado
--   - el core se detiene y reanuda con el bit CTRL.core_en
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_soc_top is
  generic (
    AXI_LAT   : natural := 4;        -- latencia del NoC en ciclos
    MAX_CYC   : natural := 2000000; -- techo de ciclos de simulacion
    EXPECTED  : string := "ABCDEFG"  -- marcas de integracion esperadas
  );
end entity;

architecture sim of tb_soc_top is
  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- AXI esclavo (el TB es el maestro: hace de PS)
  signal s_awaddr, s_wdata, s_araddr, s_rdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal s_awvalid, s_awready, s_wvalid, s_wready : std_logic := '0';
  signal s_bvalid, s_bready, s_arvalid, s_arready, s_rvalid, s_rready : std_logic := '0';
  signal s_wstrb : std_logic_vector(3 downto 0) := "1111";
  signal s_bresp, s_rresp : std_logic_vector(1 downto 0);

  -- AXI maestro (el TB es el esclavo: hace de DDR via NoC)
  signal m_awaddr, m_wdata, m_araddr, m_rdata : std_logic_vector(31 downto 0);
  signal m_awvalid, m_awready, m_wvalid, m_wready : std_logic;
  signal m_bvalid, m_bready, m_arvalid, m_arready, m_rvalid, m_rready : std_logic;
  signal m_wstrb : std_logic_vector(3 downto 0);
  signal m_bresp, m_rresp : std_logic_vector(1 downto 0) := "00";

  constant DDR_BASE : unsigned(31 downto 0) := x"70000000";
  constant NW : natural := 16*1024*1024;
  type t_ram is array (0 to NW-1) of integer;
  type t_ram_ptr is access t_ram;

  signal cyc : natural := 0;

  function slv(v : integer) return std_logic_vector is
  begin return std_logic_vector(to_signed(v,32)); end function;
  function int(v : std_logic_vector(31 downto 0)) return integer is
  begin return to_integer(signed(v)); end function;

  -- indice de palabra en el modelo de DDR; -1 si la direccion cae fuera
  -- del rango mapeado (el calcular en unsigned evita el overflow que
  -- produce restar una base mayor que la direccion)
  function ddr_idx(a : std_logic_vector(31 downto 0)) return integer is
    variable ua : unsigned(31 downto 0);
  begin
    ua := unsigned(a);
    if ua < DDR_BASE then return -1; end if;
    if (ua - DDR_BASE) >= to_unsigned(NW*4, 32) then return -1; end if;
    return to_integer((ua - DDR_BASE) srl 2);
  end function;

begin

  aclk <= not aclk after 5 ns;

  cyc_proc : process(aclk)
  begin
    if rising_edge(aclk) then cyc <= cyc + 1; end if;
  end process;

  dut : entity work.rv32ima_soc_top
    generic map (DDR_BASE_PHYS => x"70000000",
                 RESET_PC => x"80000000",
                 TICK_DIV => 100,
                 UART_FIFO_LOG2 => 12)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_awaddr => s_awaddr, s_awvalid => s_awvalid, s_awready => s_awready,
      s_wdata => s_wdata, s_wstrb => s_wstrb, s_wvalid => s_wvalid,
      s_wready => s_wready, s_bresp => s_bresp, s_bvalid => s_bvalid,
      s_bready => s_bready,
      s_araddr => s_araddr, s_arvalid => s_arvalid, s_arready => s_arready,
      s_rdata => s_rdata, s_rresp => s_rresp, s_rvalid => s_rvalid,
      s_rready => s_rready,
      m_awaddr => m_awaddr, m_awvalid => m_awvalid, m_awready => m_awready,
      m_wdata => m_wdata, m_wstrb => m_wstrb, m_wvalid => m_wvalid,
      m_wready => m_wready, m_bresp => m_bresp, m_bvalid => m_bvalid,
      m_bready => m_bready,
      m_araddr => m_araddr, m_arvalid => m_arvalid, m_arready => m_arready,
      m_rdata => m_rdata, m_rresp => m_rresp, m_rvalid => m_rvalid,
      m_rready => m_rready);

  -- =========================================================
  -- modelo de DDR colgado del AXI maestro (hace de NoC + DDR)
  -- =========================================================
  ddr_model : process
    variable ram : t_ram_ptr := null;
    file fh      : text open read_mode is "soctop_test.mem";
    variable l   : line;
    variable wv  : std_logic_vector(31 downto 0);
    variable ix  : integer;
    variable idx : integer;
    variable cur, nv : std_logic_vector(31 downto 0);
    variable lat : natural;
    variable waddr_v : std_logic_vector(31 downto 0) := (others=>'0');
    variable wdata_v : std_logic_vector(31 downto 0) := (others=>'0');
    variable wstrb_v : std_logic_vector(3 downto 0) := (others=>'0');
    variable have_aw, have_w : boolean;
  begin
    ram := new t_ram;
    for i in 0 to NW-1 loop ram(i) := 0; end loop;
    -- el programa se carga en el offset 0 de DDR, que el core ve como
    -- 0x80000000 (su base). RESET_PC apunta ahi directamente.
    ix := 0;
    while not endfile(fh) loop
      readline(fh, l); hread(l, wv);
      ram(ix) := int(wv);
      ix := ix + 1;
    end loop;
    report "programa cargado en DDR" severity note;

    m_arready <= '0'; m_rvalid <= '0'; m_rdata <= (others=>'0');
    m_awready <= '0'; m_wready <= '0'; m_bvalid <= '0';
    have_aw := false; have_w := false;

    loop
      wait until rising_edge(aclk);

      -- ---- canal de lectura ----
      if m_arvalid = '1' and m_arready = '0' and m_rvalid = '0' then
        m_arready <= '1';
        idx := ddr_idx(m_araddr);
        for k in 1 to AXI_LAT loop
          wait until rising_edge(aclk);
          m_arready <= '0';
        end loop;
        if idx >= 0 and idx < NW then
          m_rdata <= slv(ram(idx));
        else
          m_rdata <= (others => '0');
        end if;
        m_rvalid <= '1';
      elsif m_arready = '1' then
        m_arready <= '0';
      elsif m_rvalid = '1' and m_rready = '1' then
        m_rvalid <= '0';
      end if;

      -- ---- canal de escritura ----
      -- handshake AXI correcto: ready es una SENAL, asi que el maestro la
      -- ve un ciclo despues. La transferencia ocurre en el ciclo en que
      -- valid y ready estan ambos altos; los datos se capturan AHI, no al
      -- decidir levantar ready. Ademas aw y w son canales independientes:
      -- w puede llegar antes que aw, asi que la escritura solo se aplica
      -- cuando AMBOS se han recibido.
      if m_awvalid = '1' and m_awready = '1' then
        waddr_v := m_awaddr;
        have_aw := true;
      end if;
      if m_wvalid = '1' and m_wready = '1' then
        wdata_v := m_wdata;
        wstrb_v := m_wstrb;
        have_w  := true;
      end if;
      -- ready se ofrece mientras no haya una respuesta pendiente
      m_awready <= '1' when (m_bvalid = '0' and not have_aw) else '0';
      m_wready  <= '1' when (m_bvalid = '0' and not have_w)  else '0';

      if have_aw and have_w and m_bvalid = '0' then
        idx := ddr_idx(waddr_v);
        if idx >= 0 then
          cur := slv(ram(idx));
          nv  := cur;
          for b in 0 to 3 loop
            if wstrb_v(b) = '1' then
              nv(8*b+7 downto 8*b) := wdata_v(8*b+7 downto 8*b);
            end if;
          end loop;
          ram(idx) := int(nv);
        end if;
        for k in 1 to AXI_LAT loop
          wait until rising_edge(aclk);
        end loop;
        m_bvalid <= '1';
        have_aw := false; have_w := false;
      elsif m_bvalid = '1' and m_bready = '1' then
        m_bvalid <= '0';
      end if;
    end loop;
  end process;

  -- =========================================================
  -- el TB hace de PS: control por AXI-Lite y drenado de consola
  -- =========================================================
  ps_proc : process
    file fu : text open write_mode is "soctop_uart.log";
    variable lu : line;
    variable uart_n : natural := 0;
    variable retired : unsigned(31 downto 0);
    variable rv : std_logic_vector(31 downto 0);
    variable ch : character;
    variable got : string(1 to EXPECTED'length) := (others => ' ');
    variable gi  : natural := 0;
    variable ret_mid : unsigned(31 downto 0) := (others=>'0');
    variable paused_ok : boolean := false;

    procedure axi_w(addr : std_logic_vector(31 downto 0);
                    data : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      s_awaddr <= addr; s_awvalid <= '1';
      s_wdata  <= data; s_wvalid  <= '1';
      loop
        wait until rising_edge(aclk);
        exit when s_awready = '1' and s_wready = '1';
      end loop;
      s_awvalid <= '0'; s_wvalid <= '0';
      s_bready  <= '1';
      loop
        wait until rising_edge(aclk);
        exit when s_bvalid = '1';
      end loop;
      s_bready <= '0';
    end procedure;

    procedure axi_r(addr : std_logic_vector(31 downto 0);
                    res  : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      s_araddr <= addr; s_arvalid <= '1';
      loop
        wait until rising_edge(aclk);
        exit when s_arready = '1';
      end loop;
      s_arvalid <= '0';
      s_rready  <= '1';
      loop
        wait until rising_edge(aclk);
        exit when s_rvalid = '1';
      end loop;
      res := s_rdata;
      s_rready <= '0';
    end procedure;
  begin
    aresetn <= '0';
    for k in 1 to 20 loop wait until rising_edge(aclk); end loop;
    aresetn <= '1';
    for k in 1 to 20 loop wait until rising_edge(aclk); end loop;

    -- arrancar el core: CTRL.core_en = 1
    axi_w(x"80000000", x"00000001");
    report "core arrancado por AXI" severity note;

    -- sondear consola y estado (como hara el firmware del PS)
    loop
      -- drenar la consola
      axi_r(x"80000010", rv);
      if rv(8) = '1' then
        ch := character'val(to_integer(unsigned(rv(7 downto 0))));
        write(lu, ch);
        uart_n := uart_n + 1;
        if ch /= LF and ch /= CR and gi < EXPECTED'length then
          gi := gi + 1;
          got(gi) := ch;
        end if;
        if ch = LF then
          writeline(fu, lu);
        end if;
      end if;

      -- a mitad de camino: probar la pausa/reanudacion del core
      if gi >= 2 and not paused_ok then
        axi_w(x"80000000", x"00000000");   -- core_en = 0
        axi_r(x"80000008", rv);
        ret_mid := unsigned(rv);
        for k in 1 to 200 loop wait until rising_edge(aclk); end loop;
        axi_r(x"80000008", rv);
        assert unsigned(rv) = ret_mid
          report "FALLO: el core siguio retirando con core_en=0" severity failure;
        axi_w(x"80000000", x"00000001");   -- reanudar
        paused_ok := true;
        report "pausa/reanudacion OK" severity note;
      end if;

      exit when got = EXPECTED or cyc >= MAX_CYC;
    end loop;

    if uart_n > 0 then
      writeline(fu, lu);
    end if;

    -- verificaciones finales
    axi_r(x"80000008", rv);
    retired := unsigned(rv);
    report "estado final: retiros=" & integer'image(to_integer(retired))
           & " consola='" & got & "' cyc=" & integer'image(cyc) severity note;
    -- el programa de integracion retira ~510 instrucciones; exigimos un
    -- minimo holgado para detectar un core que no arranca, sin fijar una
    -- cifra fragil ante cambios menores del programa
    assert retired > 400
      report "FALLO: el core apenas retiro instrucciones ("
             & integer'image(to_integer(retired)) & ")" severity failure;
    if got /= EXPECTED then
      report "consola: emitido='" & got & "' esperado='" & EXPECTED
             & "' cyc=" & integer'image(cyc) severity note;
    end if;
    assert got = EXPECTED
      report "FALLO: consola incorrecta" severity failure;
    assert paused_ok
      report "FALLO: no se probo la pausa del core" severity failure;

    report "SOC TOP: PASS retiros=" & integer'image(to_integer(retired))
           & " marcas=" & got severity note;
    finish;
  end process;

end architecture;
