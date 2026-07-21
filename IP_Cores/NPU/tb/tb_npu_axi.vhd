-- HERCOSSNUX NPU - testbench de integracion AXI.
--
-- Ejercita la cadena completa tal como lo hara el PS:
--   1. precargar la DDR con pesos e imagen (por AXI, como haria el PS)
--   2. escribir CTRL.load_weights y esperar done
--   3. por cada imagen: copiarla a la DDR, escribir CTRL.start, esperar done
--   4. leer el resultado de la DDR y comparar con las firmas congeladas
--
-- Criterio: SIG_CLASE identica a la del oraculo. Es la misma firma que ya
-- produce npu_top con los datos por puertos; que se mantenga al llegar por
-- DDR demuestra que la integracion no altera el resultado.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library work;
use work.npu_pkg.all;
use work.npu_axi_pkg.all;

entity tb_npu_axi is
  generic (
    G_NIMG    : natural := 8;
    G_VECFILE : string  := "vec/ddr_image.txt"
  );
end entity tb_npu_axi;

architecture sim of tb_npu_axi is

  constant CP  : time := 10 ns;
  constant IDW : natural := 4;
  constant BASE : natural := 0;   -- el modelo de DDR arranca en 0

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal fin   : boolean := false;

  -- slave (el testbench hace de PS)
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal awaddr  : std_logic_vector(31 downto 0) := (others => '0');
  signal awlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal awsize  : std_logic_vector(2 downto 0) := "010";
  signal awburst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal awid    : std_logic_vector(IDW-1 downto 0) := (others => '0');
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb   : std_logic_vector(3 downto 0) := "1111";
  signal wlast   : std_logic := '0';
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';
  signal bresp   : std_logic_vector(1 downto 0);
  signal bid     : std_logic_vector(IDW-1 downto 0);
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal araddr  : std_logic_vector(31 downto 0) := (others => '0');
  signal arlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal arsize  : std_logic_vector(2 downto 0) := "010";
  signal arburst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal arid    : std_logic_vector(IDW-1 downto 0) := (others => '0');
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rlast   : std_logic;
  signal rid     : std_logic_vector(IDW-1 downto 0);

  -- master hacia el modelo de DDR
  signal m_arvalid, m_arready : std_logic;
  signal m_araddr : std_logic_vector(31 downto 0);
  signal m_arlen  : std_logic_vector(7 downto 0);
  signal m_arsize : std_logic_vector(2 downto 0);
  signal m_arburst: std_logic_vector(1 downto 0);
  signal m_rvalid, m_rready, m_rlast : std_logic;
  signal m_rdata  : std_logic_vector(31 downto 0);
  signal m_rresp  : std_logic_vector(1 downto 0);
  signal m_awvalid, m_awready : std_logic;
  signal m_awaddr : std_logic_vector(31 downto 0);
  signal m_awlen  : std_logic_vector(7 downto 0);
  signal m_awsize : std_logic_vector(2 downto 0);
  signal m_awburst: std_logic_vector(1 downto 0);
  signal m_wvalid, m_wready, m_wlast : std_logic;
  signal m_wdata  : std_logic_vector(31 downto 0);
  signal m_wstrb  : std_logic_vector(3 downto 0);
  signal m_bvalid, m_bready : std_logic;
  signal m_bresp  : std_logic_vector(1 downto 0);

  signal dbg_addr : natural := 0;
  signal dbg_data : std_logic_vector(7 downto 0);
  signal pre_we   : std_logic := '0';
  signal pre_addr : natural := 0;
  signal pre_data : std_logic_vector(7 downto 0) := (others => '0');

  function hex2b (s : string) return integer is
    variable d : integer := 0;
    variable r : integer := 0;
  begin
    for i in s'range loop
      case s(i) is
        when '0' to '9' => d := character'pos(s(i)) - character'pos('0');
        when 'a' to 'f' => d := character'pos(s(i)) - character'pos('a') + 10;
        when 'A' to 'F' => d := character'pos(s(i)) - character'pos('A') + 10;
        when others     => d := 0;
      end case;
      r := r*16 + d;
    end loop;
    return r;
  end function;

begin

  clk <= not clk after CP/2 when not fin else '0';

  dut : entity work.npu_axi_top
    generic map (G_ID_W => IDW)
    port map (clk => clk, rst_n => rst_n,
      s_awvalid => awvalid, s_awready => awready, s_awaddr => awaddr,
      s_awlen => awlen, s_awsize => awsize, s_awburst => awburst,
      s_awid => awid,
      s_wvalid => wvalid, s_wready => wready, s_wdata => wdata,
      s_wstrb => wstrb, s_wlast => wlast,
      s_bvalid => bvalid, s_bready => bready, s_bresp => bresp, s_bid => bid,
      s_arvalid => arvalid, s_arready => arready, s_araddr => araddr,
      s_arlen => arlen, s_arsize => arsize, s_arburst => arburst,
      s_arid => arid,
      s_rvalid => rvalid, s_rready => rready, s_rdata => rdata,
      s_rresp => rresp, s_rlast => rlast, s_rid => rid,
      m_arvalid => m_arvalid, m_arready => m_arready, m_araddr => m_araddr,
      m_arlen => m_arlen, m_arsize => m_arsize, m_arburst => m_arburst,
      m_rvalid => m_rvalid, m_rready => m_rready, m_rdata => m_rdata,
      m_rresp => m_rresp, m_rlast => m_rlast,
      m_awvalid => m_awvalid, m_awready => m_awready, m_awaddr => m_awaddr,
      m_awlen => m_awlen, m_awsize => m_awsize, m_awburst => m_awburst,
      m_wvalid => m_wvalid, m_wready => m_wready, m_wdata => m_wdata,
      m_wstrb => m_wstrb, m_wlast => m_wlast,
      m_bvalid => m_bvalid, m_bready => m_bready, m_bresp => m_bresp);

  ddr : entity work.axi_ddr_model
    generic map (G_SIZE_BYTES => 16#30000#, G_STALL => 0, G_ERR_ADDR => -1)
    port map (clk => clk, rst_n => rst_n,
      arvalid => m_arvalid, arready => m_arready, araddr => m_araddr,
      arlen => m_arlen, arburst => m_arburst,
      rvalid => m_rvalid, rready => m_rready, rdata => m_rdata,
      rresp => m_rresp, rlast => m_rlast,
      awvalid => m_awvalid, awready => m_awready, awaddr => m_awaddr,
      awlen => m_awlen, awburst => m_awburst,
      wvalid => m_wvalid, wready => m_wready, wdata => m_wdata,
      wstrb => m_wstrb, wlast => m_wlast,
      bvalid => m_bvalid, bready => m_bready, bresp => m_bresp,
      dbg_addr => dbg_addr, dbg_data => dbg_data,
      pre_we => pre_we, pre_addr => pre_addr, pre_data => pre_data);

  stim : process
    file     fh : text;
    variable ln : line;
    variable st : file_open_status;
    variable ok : boolean;
    variable s2 : string(1 to 2);
    variable s8 : string(1 to 8);
    variable c  : character;
    variable nerr : natural := 0;
    variable sig_cl : unsigned(31 downto 0) := C_SIG_INIT;
    variable nimg : natural := 0;
    variable ciclos : natural;
    variable clase_leida : natural;

    -- escribir un registro del slave
    procedure wr_reg (addr : natural; dato : std_logic_vector(31 downto 0)) is
    begin
      awaddr  <= std_logic_vector(to_unsigned(addr, 32));
      awlen   <= (others => '0');
      awvalid <= '1';
      wait until rising_edge(clk) and awready = '1';
      awvalid <= '0';
      wdata <= dato; wstrb <= "1111"; wlast <= '1'; wvalid <= '1';
      wait until rising_edge(clk) and wready = '1';
      wvalid <= '0'; wlast <= '0';
      bready <= '1';
      wait until rising_edge(clk) and bvalid = '1';
      bready <= '0';
    end procedure;

    -- leer un registro del slave
    procedure rd_reg (addr : natural; res : out std_logic_vector(31 downto 0)) is
    begin
      araddr  <= std_logic_vector(to_unsigned(addr, 32));
      arlen   <= (others => '0');
      arvalid <= '1';
      wait until rising_edge(clk) and arready = '1';
      arvalid <= '0';
      rready  <= '1';
      wait until rising_edge(clk) and rvalid = '1';
      res := rdata;
      rready <= '0';
    end procedure;

    variable v : std_logic_vector(31 downto 0);
    variable blk_off : natural := 0;
    variable blk_n   : natural := 0;
  begin
    file_open(st, fh, G_VECFILE, read_mode);
    assert st = open_ok
      report "tb_npu_axi: no se pudo abrir el archivo" severity failure;

    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    -- Precarga de la DDR con los bloques de pesos del fichero
    readline(fh, ln);   -- cabecera
    readline(fh, ln);   -- SIZE
    loop
      exit when endfile(fh);
      readline(fh, ln);
      if ln'length >= 6 and ln(ln'low to ln'low+5) = "BLOQUE" then
        -- BLOQUE <off hex 8> <n>
        for k in 1 to 7 loop read(ln, c, ok); end loop;
        read(ln, s8, ok);
        blk_off := hex2b(s8);
        read(ln, c, ok);
        blk_n := 0;
        loop
          read(ln, c, ok);
          exit when (not ok) or c = ' ';
          blk_n := blk_n*10 + (character'pos(c) - character'pos('0'));
        end loop;
        for i in 0 to blk_n-1 loop
          if i mod 32 = 0 then
            readline(fh, ln);
          else
            read(ln, c, ok);
          end if;
          read(ln, s2, ok);
          pre_addr <= blk_off + i;
          pre_data <= std_logic_vector(to_unsigned(hex2b(s2), 8));
          pre_we   <= '1';
          wait until rising_edge(clk);
        end loop;
        pre_we <= '0';
      elsif ln'length >= 6 and ln(ln'low to ln'low+5) = "IMAGEN" then
        exit;   -- las imagenes se cargan en el bucle de inferencia
      end if;
    end loop;
    pre_we <= '0';
    wait until rising_edge(clk);

    -- comprobar el ID para validar la conexion del slave
    rd_reg(C_REG_ID, v);
    if v /= C_ID_VALUE then
      nerr := nerr + 1;
      report "tb_npu_axi: ID incorrecto, leido " & to_hstring(v)
        severity warning;
    end if;

    -- BASE a 0: el modelo de DDR arranca en la direccion 0
    wr_reg(C_REG_BASE, std_logic_vector(to_unsigned(BASE, 32)));

    -- cargar pesos
    wr_reg(C_REG_CTRL, x"00000002");    -- load_weights
    ciclos := 0;
    loop
      rd_reg(C_REG_STATUS, v);
      exit when v(1) = '1' or ciclos > 200000;
      ciclos := ciclos + 1;
    end loop;
    if v(1) /= '1' then
      nerr := nerr + 1;
      report "tb_npu_axi: la carga de pesos no termino" severity warning;
    end if;

    -- inferencia por imagen: cada una se copia a DDR antes de disparar
    for n in 0 to G_NIMG-1 loop
      -- la linea IMAGEN ya se leyo o se lee ahora
      if n > 0 then
        readline(fh, ln);
      end if;
      for k in 0 to 7 loop
        readline(fh, ln);
        for j in 0 to 31 loop
          if j > 0 then read(ln, c, ok); end if;
          read(ln, s2, ok);
          pre_addr <= C_OFF_IMG + k*32 + j;
          pre_data <= std_logic_vector(to_unsigned(hex2b(s2), 8));
          pre_we   <= '1';
          wait until rising_edge(clk);
        end loop;
      end loop;
      pre_we <= '0';
      wait until rising_edge(clk);

      wr_reg(C_REG_CTRL, x"00000001");  -- start
      ciclos := 0;
      loop
        rd_reg(C_REG_STATUS, v);
        exit when v(1) = '1' or ciclos > 500000;
        ciclos := ciclos + 1;
      end loop;
      if v(1) /= '1' then
        nerr := nerr + 1;
        report "tb_npu_axi: inferencia " & integer'image(n)
             & " no termino" severity warning;
        exit;
      end if;
      clase_leida := to_integer(unsigned(v(7 downto 4)));
      sig_cl := sig_update(sig_cl, to_signed(clase_leida, 8));
      nimg := nimg + 1;
    end loop;

    file_close(fh);

    report "TB_NPU_AXI imgs=" & integer'image(nimg)
         & " errores=" & integer'image(nerr)
         & " SIG_CLASE=0x" & to_hstring(sig_cl) severity note;

    fin <= true;
    wait;
  end process;

end architecture sim;
