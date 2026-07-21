-- HERCOSSNUX NPU - sondas de protocolo AXI4 (Layer 3 del DMA).
--
-- Se verifica el master ANTES de conectarlo a la NPU, igual que se hizo con
-- el tiling en el Paso 5. Sin esto, un fallo de handshake apareceria como
-- firma incorrecta y seria imposible de localizar.
--
-- Sonda 1: rafaga de lectura simple, 64 bytes, sin backpressure
-- Sonda 2: lectura larga que obliga a varias rafagas (2560 bytes de W3)
-- Sonda 3: lectura con backpressure (RVALID intermitente)
-- Sonda 4: lectura sobre direccion con error, comprueba que se reporta
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_axi_pkg.all;

entity tb_axi_sondas is
  generic (
    G_SONDA : natural := 1
  );
end entity tb_axi_sondas;

architecture sim of tb_axi_sondas is

  constant CP : time := 10 ns;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal fin    : boolean := false;

  -- control del DMA
  signal rd_start : std_logic := '0';
  signal rd_addr  : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_bytes : natural := 0;
  signal rd_busy  : std_logic;
  signal rd_done  : std_logic;

  signal out_we   : std_logic;
  signal out_idx  : natural;
  signal out_data : std_logic_vector(7 downto 0);

  signal wr_start : std_logic := '0';
  signal wr_addr  : std_logic_vector(31 downto 0) := (others => '0');
  signal wr_bytes : natural := 0;
  signal wr_busy  : std_logic;
  signal wr_done  : std_logic;
  signal in_idx   : natural;
  signal in_data  : std_logic_vector(7 downto 0) := (others => '0');

  signal err_out  : std_logic;
  signal errcode  : std_logic_vector(1 downto 0);

  -- AXI
  signal arvalid, arready : std_logic;
  signal araddr : std_logic_vector(31 downto 0);
  signal arlen  : std_logic_vector(7 downto 0);
  signal arsize : std_logic_vector(2 downto 0);
  signal arburst: std_logic_vector(1 downto 0);
  signal rvalid, rready, rlast : std_logic;
  signal rdata  : std_logic_vector(31 downto 0);
  signal rresp  : std_logic_vector(1 downto 0);

  signal awvalid, awready : std_logic;
  signal awaddr : std_logic_vector(31 downto 0);
  signal awlen  : std_logic_vector(7 downto 0);
  signal awsize : std_logic_vector(2 downto 0);
  signal awburst: std_logic_vector(1 downto 0);
  signal wvalid, wready, wlast : std_logic;
  signal wdata  : std_logic_vector(31 downto 0);
  signal wstrb  : std_logic_vector(3 downto 0);
  signal bvalid, bready : std_logic;
  signal bresp  : std_logic_vector(1 downto 0);

  signal dbg_addr : natural := 0;
  signal dbg_data : std_logic_vector(7 downto 0);

  -- memoria de recepcion del testbench
  -- tx: lo que el testbench envia por DMA (solo lo escribe stim)
  -- rx: lo que el DMA devuelve (solo lo escribe el proceso de captura)
  type t_rx is array (0 to 4095) of integer range 0 to 255;
  signal tx : t_rx := (others => 0);
  signal rx : t_rx := (others => 0);

  -- parametros por sonda
  function stall_of (s : natural) return natural is
  begin
    if s = 3 then return 3; else return 0; end if;
  end function;

  function errad_of (s : natural) return integer is
  begin
    if s = 4 then return 16#2000#; else return -1; end if;
  end function;

begin

  clk <= not clk after CP/2 when not fin else '0';

  dut : entity work.npu_dma
    port map (clk => clk, rst_n => rst_n,
      rd_start => rd_start, rd_addr => rd_addr, rd_bytes => rd_bytes,
      rd_busy => rd_busy, rd_done => rd_done,
      out_we => out_we, out_idx => out_idx, out_data => out_data,
      wr_start => wr_start, wr_addr => wr_addr, wr_bytes => wr_bytes,
      wr_busy => wr_busy, wr_done => wr_done,
      in_idx => in_idx, in_data => in_data,
      err_out => err_out, errcode => errcode,
      m_arvalid => arvalid, m_arready => arready, m_araddr => araddr,
      m_arlen => arlen, m_arsize => arsize, m_arburst => arburst,
      m_rvalid => rvalid, m_rready => rready, m_rdata => rdata,
      m_rresp => rresp, m_rlast => rlast,
      m_awvalid => awvalid, m_awready => awready, m_awaddr => awaddr,
      m_awlen => awlen, m_awsize => awsize, m_awburst => awburst,
      m_wvalid => wvalid, m_wready => wready, m_wdata => wdata,
      m_wstrb => wstrb, m_wlast => wlast,
      m_bvalid => bvalid, m_bready => bready, m_bresp => bresp);

  ddr : entity work.axi_ddr_model
    generic map (G_SIZE_BYTES => 16#30000#,
                 G_STALL      => stall_of(G_SONDA),
                 G_ERR_ADDR   => errad_of(G_SONDA))
    port map (clk => clk, rst_n => rst_n,
      arvalid => arvalid, arready => arready, araddr => araddr,
      arlen => arlen, arburst => arburst,
      rvalid => rvalid, rready => rready, rdata => rdata,
      rresp => rresp, rlast => rlast,
      awvalid => awvalid, awready => awready, awaddr => awaddr,
      awlen => awlen, awburst => awburst,
      wvalid => wvalid, wready => wready, wdata => wdata,
      wstrb => wstrb, wlast => wlast,
      bvalid => bvalid, bready => bready, bresp => bresp,
      dbg_addr => dbg_addr, dbg_data => dbg_data);

  -- capturar el flujo de salida del DMA
  cap : process(clk)
  begin
    if rising_edge(clk) then
      if out_we = '1' and out_idx < 4096 then
        rx(out_idx) <= to_integer(unsigned(out_data));
      end if;
    end if;
  end process;

  stim : process
    variable nbytes : natural;
    variable base   : natural;
    variable nerr   : natural := 0;
    variable esperado : natural;
    variable ciclos : natural;
  begin
    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    -- Precargar el modelo de DDR por AXI seria lento; en su lugar se usa
    -- un patron determinista que el modelo devuelve desde mem, que arranca
    -- en ceros. Para tener datos no triviales se escriben antes por DMA.
    -- Sonda 1 y 2 escriben primero, luego leen y comparan.

    case G_SONDA is

      when 1 =>
        -- Rafaga simple: escribir 64 bytes y releerlos
        base := 16#1000#; nbytes := 64;
        for i in 0 to nbytes-1 loop
          tx(i) <= (i*7 + 13) mod 256;
        end loop;
        wait until rising_edge(clk);
        wr_addr  <= std_logic_vector(to_unsigned(base, 32));
        wr_bytes <= nbytes;
        wr_start <= '1';
        wait until rising_edge(clk);
        wr_start <= '0';
        wait until rising_edge(clk);
        while wr_busy = '1' loop wait until rising_edge(clk); end loop;
        wait until rising_edge(clk);

        -- limpiar y releer
        rd_addr  <= std_logic_vector(to_unsigned(base, 32));
        rd_bytes <= nbytes;
        rd_start <= '1';
        wait until rising_edge(clk);
        rd_start <= '0';
        wait until rising_edge(clk);
        while rd_busy = '1' loop wait until rising_edge(clk); end loop;
        wait until rising_edge(clk);

        for i in 0 to nbytes-1 loop
          esperado := (i*7 + 13) mod 256;
          if rx(i) /= esperado then
            nerr := nerr + 1;
            if nerr <= 3 then
              report "sonda1: byte " & integer'image(i)
                   & " obtenido " & integer'image(rx(i))
                   & " esperado " & integer'image(esperado) severity warning;
            end if;
          end if;
        end loop;

      when 2 =>
        -- Lectura larga: 2560 bytes obligan a 40 rafagas de 16 palabras
        base := 16#2000#; nbytes := 2560;
        for i in 0 to nbytes-1 loop
          tx(i) <= (i*31 + 7) mod 256;
        end loop;
        wait until rising_edge(clk);
        wr_addr  <= std_logic_vector(to_unsigned(base, 32));
        wr_bytes <= nbytes;
        wr_start <= '1';
        wait until rising_edge(clk);
        wr_start <= '0';
        wait until rising_edge(clk);
        while wr_busy = '1' loop wait until rising_edge(clk); end loop;
        wait until rising_edge(clk);

        rd_addr  <= std_logic_vector(to_unsigned(base, 32));
        rd_bytes <= nbytes;
        rd_start <= '1';
        wait until rising_edge(clk);
        rd_start <= '0';
        wait until rising_edge(clk);
        while rd_busy = '1' loop wait until rising_edge(clk); end loop;
        wait until rising_edge(clk);

        for i in 0 to nbytes-1 loop
          esperado := (i*31 + 7) mod 256;
          if rx(i) /= esperado then
            nerr := nerr + 1;
            if nerr <= 3 then
              report "sonda2: byte " & integer'image(i)
                   & " obtenido " & integer'image(rx(i))
                   & " esperado " & integer'image(esperado) severity warning;
            end if;
          end if;
        end loop;

      when 3 =>
        -- Backpressure: el modelo baja RVALID cada 3 transferencias
        base := 16#1000#; nbytes := 256;
        for i in 0 to nbytes-1 loop
          tx(i) <= (i*11 + 3) mod 256;
        end loop;
        wait until rising_edge(clk);
        wr_addr  <= std_logic_vector(to_unsigned(base, 32));
        wr_bytes <= nbytes;
        wr_start <= '1';
        wait until rising_edge(clk);
        wr_start <= '0';
        wait until rising_edge(clk);
        while wr_busy = '1' loop wait until rising_edge(clk); end loop;
        wait until rising_edge(clk);

        rd_addr  <= std_logic_vector(to_unsigned(base, 32));
        rd_bytes <= nbytes;
        rd_start <= '1';
        wait until rising_edge(clk);
        rd_start <= '0';
        wait until rising_edge(clk);
        while rd_busy = '1' loop wait until rising_edge(clk); end loop;
        wait until rising_edge(clk);

        for i in 0 to nbytes-1 loop
          esperado := (i*11 + 3) mod 256;
          if rx(i) /= esperado then
            nerr := nerr + 1;
            if nerr <= 3 then
              report "sonda3: byte " & integer'image(i)
                   & " obtenido " & integer'image(rx(i))
                   & " esperado " & integer'image(esperado) severity warning;
            end if;
          end if;
        end loop;

      when 4 =>
        -- Error: leer de la direccion marcada debe levantar err_out
        base := 16#2000#; nbytes := 64;
        rd_addr  <= std_logic_vector(to_unsigned(base, 32));
        rd_bytes <= nbytes;
        rd_start <= '1';
        wait until rising_edge(clk);
        rd_start <= '0';
        wait until rising_edge(clk);
        ciclos := 0;
        while rd_busy = '1' and ciclos < 10000 loop
          wait until rising_edge(clk);
          ciclos := ciclos + 1;
        end loop;
        wait until rising_edge(clk);
        if err_out /= '1' then
          nerr := nerr + 1;
          report "sonda4: no se reporto el error de lectura" severity warning;
        end if;
        if errcode /= C_RESP_SLVERR then
          nerr := nerr + 1;
          report "sonda4: errcode incorrecto" severity warning;
        end if;

      when others =>
        null;
    end case;

    if nerr = 0 then
      report "SONDA_AXI" & integer'image(G_SONDA) & " PASS" severity note;
    else
      report "SONDA_AXI" & integer'image(G_SONDA) & " FAIL errores="
           & integer'image(nerr) severity note;
    end if;

    fin <= true;
    wait;
  end process;

  -- el consumidor de escritura entrega el byte que el DMA pide
  in_data <= std_logic_vector(to_unsigned(tx(in_idx), 8)) when in_idx < 4096
             else (others => '0');

end architecture sim;
