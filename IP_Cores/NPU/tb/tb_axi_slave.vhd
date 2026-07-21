-- HERCOSSNUX NPU - sondas del esclavo AXI4 full.
-- Se verifica el slave ANTES de integrarlo, igual que el master en el Paso 12.
--
-- Sonda 1: lectura simple de ID y BASE por defecto
-- Sonda 2: escritura de BASE con WSTRB parcial, luego lectura
-- Sonda 3: rafaga de lectura INCR de 4 palabras con ID propagado
-- Sonda 4: acceso a direccion no mapeada, debe responder SLVERR
-- Sonda 5: rafaga FIXED, la direccion no debe avanzar
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_axi_pkg.all;

entity tb_axi_slave is
  generic (
    G_SONDA : natural := 1
  );
end entity tb_axi_slave;

architecture sim of tb_axi_slave is

  constant CP : time := 10 ns;
  constant IDW : natural := 4;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal fin   : boolean := false;

  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal awaddr  : std_logic_vector(31 downto 0) := (others => '0');
  signal awlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal awsize  : std_logic_vector(2 downto 0) := "010";
  signal awburst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal awid    : std_logic_vector(IDW-1 downto 0) := (others => '0');

  signal wvalid : std_logic := '0';
  signal wready : std_logic;
  signal wdata  : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb  : std_logic_vector(3 downto 0) := "1111";
  signal wlast  : std_logic := '0';

  signal bvalid : std_logic;
  signal bready : std_logic := '0';
  signal bresp  : std_logic_vector(1 downto 0);
  signal bid    : std_logic_vector(IDW-1 downto 0);

  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal araddr  : std_logic_vector(31 downto 0) := (others => '0');
  signal arlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal arsize  : std_logic_vector(2 downto 0) := "010";
  signal arburst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal arid    : std_logic_vector(IDW-1 downto 0) := (others => '0');

  signal rvalid : std_logic;
  signal rready : std_logic := '0';
  signal rdata  : std_logic_vector(31 downto 0);
  signal rresp  : std_logic_vector(1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(IDW-1 downto 0);

  signal o_start, o_loadw : std_logic;
  signal o_base : std_logic_vector(31 downto 0);
  signal i_busy  : std_logic := '0';
  signal i_done  : std_logic := '0';
  signal i_error : std_logic := '0';
  signal i_clase : std_logic_vector(3 downto 0) := "0101";
  signal i_errcode : std_logic_vector(1 downto 0) := "00";

  signal nerr : natural := 0;

begin

  clk <= not clk after CP/2 when not fin else '0';

  dut : entity work.npu_axi_slave
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
      o_start => o_start, o_loadw => o_loadw, o_base => o_base,
      i_busy => i_busy, i_done => i_done, i_error => i_error,
      i_clase => i_clase, i_errcode => i_errcode);

  stim : process

    procedure leer (addr : natural; id : natural;
                    len : natural; burst : std_logic_vector(1 downto 0)) is
    begin
      araddr  <= std_logic_vector(to_unsigned(addr, 32));
      arlen   <= std_logic_vector(to_unsigned(len, 8));
      arburst <= burst;
      arid    <= std_logic_vector(to_unsigned(id, IDW));
      arvalid <= '1';
      wait until rising_edge(clk) and arready = '1';
      arvalid <= '0';
      rready  <= '1';
    end procedure;

    procedure escribir (addr : natural; dato : std_logic_vector(31 downto 0);
                        strb : std_logic_vector(3 downto 0)) is
    begin
      awaddr  <= std_logic_vector(to_unsigned(addr, 32));
      awlen   <= (others => '0');
      awburst <= C_BURST_INCR;
      awid    <= "0011";
      awvalid <= '1';
      wait until rising_edge(clk) and awready = '1';
      awvalid <= '0';
      wdata <= dato; wstrb <= strb; wlast <= '1'; wvalid <= '1';
      wait until rising_edge(clk) and wready = '1';
      wvalid <= '0'; wlast <= '0';
      bready <= '1';
      wait until rising_edge(clk) and bvalid = '1';
      bready <= '0';
    end procedure;

    variable v : std_logic_vector(31 downto 0);
  begin
    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    case G_SONDA is

      when 1 =>
        -- ID y BASE por defecto
        leer(C_REG_ID, 5, 0, C_BURST_INCR);
        wait until rising_edge(clk) and rvalid = '1';
        if rdata /= C_ID_VALUE then
          nerr <= nerr + 1;
          report "sonda1: ID incorrecto" severity warning;
        end if;
        if rid /= "0101" then
          nerr <= nerr + 1;
          report "sonda1: RID no propagado" severity warning;
        end if;
        if rlast /= '1' then
          nerr <= nerr + 1;
          report "sonda1: RLAST ausente en rafaga de 1" severity warning;
        end if;
        rready <= '0';
        wait until rising_edge(clk);

        leer(C_REG_BASE, 0, 0, C_BURST_INCR);
        wait until rising_edge(clk) and rvalid = '1';
        if rdata /= x"70000000" then
          nerr <= nerr + 1;
          report "sonda1: BASE por defecto incorrecta" severity warning;
        end if;
        rready <= '0';

      when 2 =>
        -- Escribir BASE completa y releer
        escribir(C_REG_BASE, x"71234000", "1111");
        wait until rising_edge(clk);
        leer(C_REG_BASE, 0, 0, C_BURST_INCR);
        wait until rising_edge(clk) and rvalid = '1';
        if rdata /= x"71234000" then
          nerr <= nerr + 1;
          report "sonda2: BASE no se escribio" severity warning;
        end if;
        rready <= '0';
        wait until rising_edge(clk);

        -- WSTRB parcial: solo el byte 0
        escribir(C_REG_BASE, x"000000FF", "0001");
        wait until rising_edge(clk);
        leer(C_REG_BASE, 0, 0, C_BURST_INCR);
        wait until rising_edge(clk) and rvalid = '1';
        if rdata /= x"712340FF" then
          nerr <= nerr + 1;
          report "sonda2: WSTRB parcial mal aplicado, leido "
               & to_hstring(rdata) severity warning;
        end if;
        rready <= '0';

      when 3 =>
        -- Rafaga INCR de 4 palabras desde CTRL: 0x00,0x04,0x08,0x0C
        i_clase <= "0111";
        i_done  <= '1';
        wait until rising_edge(clk);
        leer(C_REG_CTRL, 9, 3, C_BURST_INCR);
        for k in 0 to 3 loop
          wait until rising_edge(clk) and rvalid = '1';
          if rid /= "1001" then
            nerr <= nerr + 1;
            report "sonda3: RID incorrecto en palabra "
                 & integer'image(k) severity warning;
          end if;
          if k = 1 then
            -- STATUS: done en bit1, clase en 7:4
            if rdata(1) /= '1' or rdata(7 downto 4) /= "0111" then
              nerr <= nerr + 1;
              report "sonda3: STATUS incorrecto, leido "
                   & to_hstring(rdata) severity warning;
            end if;
          end if;
          if k = 2 and rdata /= C_ID_VALUE then
            nerr <= nerr + 1;
            report "sonda3: ID incorrecto en la rafaga" severity warning;
          end if;
          if k = 3 and rlast /= '1' then
            nerr <= nerr + 1;
            report "sonda3: RLAST ausente en la ultima palabra" severity warning;
          end if;
        end loop;
        rready <= '0';

      when 4 =>
        -- Direccion no mapeada
        leer(16#100#, 2, 0, C_BURST_INCR);
        wait until rising_edge(clk) and rvalid = '1';
        if rresp /= C_RESP_SLVERR then
          nerr <= nerr + 1;
          report "sonda4: no se reporto SLVERR en lectura" severity warning;
        end if;
        rready <= '0';
        wait until rising_edge(clk);

        escribir(16#200#, x"12345678", "1111");
        if bresp /= C_RESP_SLVERR then
          nerr <= nerr + 1;
          report "sonda4: no se reporto SLVERR en escritura" severity warning;
        end if;

      when 5 =>
        -- Rafaga FIXED: la direccion no avanza, siempre el mismo registro
        leer(C_REG_ID, 4, 2, C_BURST_FIXED);
        for k in 0 to 2 loop
          wait until rising_edge(clk) and rvalid = '1';
          if rdata /= C_ID_VALUE then
            nerr <= nerr + 1;
            report "sonda5: FIXED avanzo la direccion en palabra "
                 & integer'image(k) & ", leido " & to_hstring(rdata)
              severity warning;
          end if;
        end loop;
        rready <= '0';

      when others =>
        null;
    end case;

    wait until rising_edge(clk);
    if nerr = 0 then
      report "SONDA_SLV" & integer'image(G_SONDA) & " PASS" severity note;
    else
      report "SONDA_SLV" & integer'image(G_SONDA) & " FAIL errores="
           & integer'image(nerr) severity note;
    end if;

    fin <= true;
    wait;
  end process;

end architecture sim;
