-- =============================================================
-- tb_soc_rst.vhd - Paso 9: parada y reset seguros del canal AXI
--
-- REPRODUCE EL INTERBLOQUEO OBSERVADO EN SILICIO: el adaptador se
-- reseteaba con el reset software del core, matando la maquina AXI
-- a mitad de transaccion. Eso retira arvalid (ilegal) o abandona la
-- respuesta pendiente; el NoC queda con la respuesta huerfana
-- (rvalid=1 permanente) y no acepta mas peticiones (arready=0
-- permanente). Capturado con ILA: 4096 muestras con
-- arvalid=1/arready=0/rvalid=1/rready=0.
--
-- El modelo de memoria de este banco es ESTRICTO como el
-- SmartConnect real en modo low-area:
--   * una sola transaccion pendiente
--   * en cuanto ve arvalid, la peticion queda tomada (aunque el
--     master la retire despues: eso es la violacion)
--   * NO acepta otra peticion hasta que el master consuma la
--     respuesta anterior con rready
--
-- Secuencia: ITERS veces { arrancar; dejar correr un numero de
-- ciclos DISTINTO en cada vuelta (para que el reset caiga en fases
-- diferentes de una transaccion en vuelo); parar + reset software;
-- rearrancar y exigir las marcas completas del programa }.
--
-- Criterio de PASS: las ITERS vueltas terminan con las marcas
-- esperadas. Con el adaptador antiguo (reset del core mata las
-- FSM AXI) la primera vuelta cuyo reset caiga a mitad de
-- transaccion se interbloquea y el watchdog reporta FALLO.
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_soc_rst is
  generic (
    AXI_LAT  : natural := 12;        -- latencia larga: ventana ancha
    ITERS    : natural := 6;
    MAX_CYC  : natural := 4000000;
    EXPECTED : string  := "ABCDEFG"
  );
end entity;

architecture sim of tb_soc_rst is
  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal s_awaddr, s_wdata, s_araddr, s_rdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal s_awvalid, s_awready, s_wvalid, s_wready : std_logic := '0';
  signal s_bvalid, s_bready, s_arvalid, s_arready, s_rvalid, s_rready : std_logic := '0';
  signal s_wstrb : std_logic_vector(3 downto 0) := (others=>'0');
  signal s_bresp, s_rresp : std_logic_vector(1 downto 0);

  signal m_awaddr, m_wdata, m_araddr, m_rdata : std_logic_vector(31 downto 0);
  signal m_awvalid, m_awready, m_wvalid, m_wready : std_logic;
  signal m_bvalid, m_bready, m_arvalid, m_arready, m_rvalid, m_rready : std_logic;
  signal m_wstrb : std_logic_vector(3 downto 0);
  signal m_bresp, m_rresp : std_logic_vector(1 downto 0);

  constant NW : integer := 262400;  -- cubre hasta 0x80100400 (marca B escribe en +0x100000)
  type t_ram is array (0 to NW-1) of integer;
  type t_ram_ptr is access t_ram;

  function int(v : std_logic_vector(31 downto 0)) return integer is
    variable u : unsigned(31 downto 0);
  begin
    u := unsigned(v);
    if u(31) = '1' then
      return -to_integer(not u) - 1;
    else
      return to_integer(u);
    end if;
  end function;

  signal reload_req : std_logic := '0';
  signal reload_ack : std_logic := '0';

  function slv(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(i, 32));
  end function;
begin
  aclk <= not aclk after 5 ns;

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
  -- Modelo ESTRICTO de NoC+DDR (canal de lectura):
  -- toma la peticion al ver arvalid; la respuesta DEBE consumirse
  -- con rready antes de aceptar otra peticion. Igual el de escritura.
  -- =========================================================
  ddr_model : process
    variable ram : t_ram_ptr := null;
    file fh      : text open read_mode is "soctop_test.mem";
    variable l   : line;
    variable wv  : std_logic_vector(31 downto 0);
    variable ix, idx : integer;
    variable cur, nv : std_logic_vector(31 downto 0);
    variable lat : natural;
    variable raddr_v, waddr_v, wdata_v : std_logic_vector(31 downto 0);
    variable wstrb_v : std_logic_vector(3 downto 0);
    variable have_aw, have_w : boolean;
  begin
    ram := new t_ram;
    for i in 0 to NW-1 loop ram(i) := 0; end loop;
    ix := 0;
    while not endfile(fh) loop
      readline(fh, l); hread(l, wv);
      ram(ix) := int(wv); ix := ix + 1;
    end loop;
    report "programa cargado en DDR" severity note;

    m_arready <= '0'; m_rvalid <= '0'; m_rdata <= (others=>'0');
    m_rresp <= "00";
    m_awready <= '0'; m_wready <= '0'; m_bvalid <= '0'; m_bresp <= "00";
    have_aw := false; have_w := false;

    loop
      wait until rising_edge(aclk);

      -- recarga de RAM bajo demanda (para que la vuelta final del
      -- estimulo corra sobre memoria virgen: soctop_test no es
      -- idempotente, p.ej. el AMO acumula)
      if reload_req /= reload_ack then
        file_close(fh);
        file_open(fh, "soctop_test.mem", read_mode);
        for i in 0 to NW-1 loop ram(i) := 0; end loop;
        ix := 0;
        while not endfile(fh) loop
          readline(fh, l); hread(l, wv);
          ram(ix) := int(wv); ix := ix + 1;
        end loop;
        reload_ack <= reload_req;
      end if;

      -- ---- canal de LECTURA, estricto ----
      if m_arvalid = '1' then
        -- peticion tomada en cuanto se ve (como el SmartConnect):
        -- si el master la retirase despues, ya es tarde.
        raddr_v := m_araddr;
        for k in 1 to AXI_LAT loop wait until rising_edge(aclk); end loop;
        m_arready <= '1';
        wait until rising_edge(aclk);
        m_arready <= '0';
        -- presentar la respuesta y NO avanzar hasta que se consuma
        idx := (int(raddr_v) - int(x"70000000")) / 4;
        if idx >= 0 and idx < NW then
          m_rdata <= slv(ram(idx));
        else
          m_rdata <= (others => '1');
        end if;
        m_rvalid <= '1';
        loop
          wait until rising_edge(aclk);
          exit when m_rready = '1';
          -- si el master nunca consume, aqui se queda: interbloqueo
          -- real, identico al capturado con el ILA en silicio.
        end loop;
        m_rvalid <= '0';
      end if;

      -- ---- canal de ESCRITURA, estricto ----
      if m_awvalid = '1' and not have_aw then
        waddr_v := m_awaddr; have_aw := true;
      end if;
      if m_wvalid = '1' and not have_w then
        wdata_v := m_wdata; wstrb_v := m_wstrb; have_w := true;
      end if;
      if have_aw and have_w then
        for k in 1 to AXI_LAT loop wait until rising_edge(aclk); end loop;
        m_awready <= '1'; m_wready <= '1';
        wait until rising_edge(aclk);
        m_awready <= '0'; m_wready <= '0';
        idx := (int(waddr_v) - int(x"70000000")) / 4;
        if idx >= 0 and idx < NW then
          cur := slv(ram(idx));
          nv := cur;
          for b in 0 to 3 loop
            if wstrb_v(b) = '1' then
              nv(8*b+7 downto 8*b) := wdata_v(8*b+7 downto 8*b);
            end if;
          end loop;
          ram(idx) := int(nv);
        end if;
        m_bvalid <= '1';
        loop
          wait until rising_edge(aclk);
          exit when m_bready = '1';
        end loop;
        m_bvalid <= '0';
        have_aw := false; have_w := false;
      end if;
    end loop;
  end process;

  -- =========================================================
  -- Estimulo: el TB hace de PS por el banco de control
  -- =========================================================
  stim : process
    procedure axi_w(addr : std_logic_vector(31 downto 0);
                    data : std_logic_vector(31 downto 0)) is
    begin
      s_awaddr <= addr; s_awvalid <= '1';
      s_wdata <= data; s_wstrb <= "1111"; s_wvalid <= '1';
      s_bready <= '1';
      loop
        wait until rising_edge(aclk);
        exit when s_awready = '1';
      end loop;
      s_awvalid <= '0'; s_wvalid <= '0';
      loop
        wait until rising_edge(aclk);
        exit when s_bvalid = '1';
      end loop;
      s_bready <= '0';
      wait until rising_edge(aclk);
    end procedure;

    procedure axi_r(addr : std_logic_vector(31 downto 0);
                    variable data : out std_logic_vector(31 downto 0)) is
    begin
      s_araddr <= addr; s_arvalid <= '1'; s_rready <= '1';
      loop
        wait until rising_edge(aclk);
        exit when s_arready = '1';
      end loop;
      s_arvalid <= '0';
      loop
        wait until rising_edge(aclk);
        exit when s_rvalid = '1';
      end loop;
      data := s_rdata;
      s_rready <= '0';
      wait until rising_edge(aclk);
    end procedure;

    variable rv     : std_logic_vector(31 downto 0);
    variable marks  : string(1 to 32);
    variable nm     : natural;
    variable cyc    : natural;
    variable okiter : natural := 0;
    variable runcyc : natural;
  begin
    aresetn <= '0';
    for i in 1 to 10 loop wait until rising_edge(aclk); end loop;
    aresetn <= '1';
    for i in 1 to 10 loop wait until rising_edge(aclk); end loop;

    for it in 1 to ITERS loop
      -- arrancar (tras reset el PC esta en RESET_PC)
      axi_w(x"00000000", x"00000001");

      -- dejar correr un numero de ciclos distinto en cada vuelta para
      -- que la parada+reset caiga en fases diferentes de la transaccion
      -- AXI en vuelo (con AXI_LAT=12 la ventana es ancha). En la ultima
      -- vuelta se deja terminar el programa completo.
      if it < ITERS then
        runcyc := 137 + it * 61;   -- primos: fases variadas
        for k in 1 to runcyc loop wait until rising_edge(aclk); end loop;
        -- parar y reset software EN CALIENTE, como hace el driver
        axi_w(x"00000000", x"00000000");
        axi_w(x"00000000", x"00000002");
        axi_w(x"00000000", x"00000000");
        for k in 1 to 20 loop wait until rising_edge(aclk); end loop;
      else
        -- vuelta final: recoger las marcas del programa completo
        nm := 0; cyc := 0;
        marks := (others => ' ');
        while cyc < MAX_CYC loop
          axi_r(x"00000014", rv);          -- UART_LEVEL
          if unsigned(rv) /= 0 then
            axi_r(x"00000010", rv);        -- UART_RX (consume)
            if rv(8) = '1' and rv(7 downto 0) /= x"0A" then
              nm := nm + 1;
              marks(nm) := character'val(to_integer(unsigned(rv(7 downto 0))));
            end if;
          end if;
          axi_r(x"00000004", rv);          -- STATUS
          if rv(1) = '1' then exit; end if; -- poweroff = programa termino
          cyc := cyc + 20;
        end loop;
        if cyc >= MAX_CYC then
          report "SOC RST: FALLO watchdog (interbloqueo AXI) iter=" &
                 integer'image(it) severity failure;
        end if;
        if marks(1 to EXPECTED'length) /= EXPECTED then
          report "SOC RST: FALLO marcas='" & marks(1 to nm) & "'" severity failure;
        end if;
      end if;

      -- entre vueltas intermedias: verificar que el core NO quedo
      -- interbloqueado comprobando que rearranca y avanza retiros
      if it < ITERS then
        axi_w(x"00000000", x"00000001");
        for k in 1 to 400 loop wait until rising_edge(aclk); end loop;
        axi_r(x"00000008", rv);            -- RETIRED_LO
        if unsigned(rv) = 0 then
          report "SOC RST: FALLO iter=" & integer'image(it) &
                 " el core no rearranca tras reset (canal AXI bloqueado)"
                 severity failure;
        end if;
        -- parar y resetear para dejar la vuelta siguiente limpia
        axi_w(x"00000000", x"00000000");
        axi_w(x"00000000", x"00000002");
        axi_w(x"00000000", x"00000000");
        -- drenar y DESCARTAR la consola acumulada de esta vuelta
        loop
          axi_r(x"00000014", rv);
          exit when unsigned(rv) = 0;
          axi_r(x"00000010", rv);
        end loop;
        for k in 1 to 20 loop wait until rising_edge(aclk); end loop;
        okiter := okiter + 1;
        -- antes de la vuelta final: memoria virgen
        if it = ITERS - 1 then
          reload_req <= not reload_req;
          wait until reload_ack = reload_req;
          -- y reset una vez mas para que el PC parta limpio sobre ella
          axi_w(x"00000000", x"00000002");
          axi_w(x"00000000", x"00000000");
          for k in 1 to 20 loop wait until rising_edge(aclk); end loop;
        end if;
      end if;
    end loop;

    report "SOC RST: PASS iters=" & integer'image(ITERS) &
           " marcas=" & EXPECTED severity note;
    finish;
  end process;

  -- watchdog global
  wdog : process
  begin
    for k in 1 to MAX_CYC loop wait until rising_edge(aclk); end loop;
    report "SOC RST: FALLO watchdog global" severity failure;
    wait;
  end process;
end architecture;
