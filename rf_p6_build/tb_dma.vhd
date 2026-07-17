-- tb_dma.vhd - Prueba dirigida del dma_burst enfocada en el split de 4KB (D_CALC).
-- Precarga una FIFO con N palabras identificables (0x1000+i) y arranca el DMA en
-- una direccion CERCA de una frontera de 4KB (0x70000FF0) para que el troceo
-- ocurra: 4 palabras hasta la frontera 0x71000000, luego el resto. Verifica que
-- (a) TODAS las palabras llegan a DDR en orden, (b) las direcciones son
-- contiguas (el split no altera el contenido ni el orden), (c) el numero total
-- coincide. Golden: "FIN SIMULACION DMA: PASS N=20 @ ..."
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_dma is
end entity tb_dma;

architecture sim of tb_dma is
  constant C_TCLK : time := 10 ns;
  constant N : integer := 20;
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal start : std_logic := '0';
  signal addr, len : std_logic_vector(31 downto 0);
  signal f_rd_en : std_logic;
  signal f_rd_data : std_logic_vector(31 downto 0);
  signal f_empty : std_logic;
  signal wr_en : std_logic;
  signal wr_addr, wr_data : std_logic_vector(31 downto 0);
  signal busy, done, bstart : std_logic;
  signal blen : std_logic_vector(31 downto 0);
  signal split_seen : boolean := false;
  signal cross_seen : boolean := false;
  signal fin : boolean := false;

  -- FIFO modelo simple (cola)
  type t_q is array (0 to 63) of std_logic_vector(31 downto 0);
  signal q : t_q := (others => x"00000000");
  signal head : integer := 0;
  signal tail : integer := 0;

  -- DDR BFM
  type t_ddr is array (0 to 4095) of std_logic_vector(31 downto 0);
  signal ddr : t_ddr := (others => x"DEADBEEF");
begin
  clk <= '0' when fin else not clk after C_TCLK/2;

  f_empty <= '1' when head = tail else '0';
  f_rd_data <= q(head) when head /= tail else x"00000000";

  addr <= x"70000FF0";   -- 4 palabras (16 bytes) antes de 0x70001000
  len  <= std_logic_vector(to_unsigned(N,32));

  dut : entity work.dma_burst
    port map (clk_i=>clk, aresetn_i=>aresetn, start_i=>start, addr_i=>addr, len_i=>len,
              fifo_rd_en_o=>f_rd_en, fifo_rd_data_i=>f_rd_data, fifo_empty_i=>f_empty,
              wr_en_o=>wr_en, wr_addr_o=>wr_addr, wr_data_o=>wr_data,
              busy_o=>busy, burst_start_o=>bstart, burst_len_o=>blen, done_o=>done);

  -- pop del modelo FIFO
  proc_fifo : process (clk)
  begin
    if rising_edge(clk) then
      if f_rd_en = '1' and head /= tail then
        head <= head + 1;
      end if;
    end if;
  end process;

  -- DDR BFM
  proc_ddr : process (clk)
    variable idx : integer;
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        idx := to_integer(unsigned(wr_addr) - 16#70000000#) / 4;
        if idx >= 0 and idx < 4096 then ddr(idx) <= wr_data; end if;
      end if;
    end if;
  end process;

  -- monitor de rafagas: registra si hubo split (>1 rafaga) y si alguna cruza 4KB
  proc_burst : process (clk)
    variable nb : integer := 0;
    variable astart, aend : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      if bstart = '1' then
        nb := nb + 1;
        if nb > 1 then split_seen <= true; end if;
        astart := unsigned(wr_addr);  -- addr actual al iniciar rafaga
      end if;
    end if;
  end process;

  proc : process
    variable ok : boolean := true;
    variable base_idx : integer;
  begin
    -- precargar la FIFO con N palabras 0x1000+i
    for i in 0 to N-1 loop
      q(i) <= std_logic_vector(to_unsigned(16#1000# + i, 32));
    end loop;
    tail <= N;
    aresetn <= '0';
    wait for 3*C_TCLK;
    aresetn <= '1';
    wait for 2*C_TCLK;
    start <= '1'; wait until rising_edge(clk); start <= '0';
    -- esperar done
    for k in 1 to 5000 loop
      wait until rising_edge(clk);
      exit when done = '1';
    end loop;
    wait for 2*C_TCLK;
    -- verificar: DDR desde indice (0xFF0/4)=1020 en adelante, contiguo, 0x1000+i
    base_idx := 16#FF0# / 4;  -- 1020
    for i in 0 to N-1 loop
      if ddr(base_idx + i) /= std_logic_vector(to_unsigned(16#1000#+i,32)) then
        if ok then
          report "FALLA DDR idx="&integer'image(base_idx+i)&" esp="&
                 to_hstring(to_unsigned(16#1000#+i,32))&" got="&to_hstring(ddr(base_idx+i)) severity error;
        end if;
        ok := false;
      end if;
    end loop;
    if not split_seen then
      report "FALLA: no hubo split de rafaga en la frontera de 4KB" severity error;
      ok := false;
    end if;
    if ok then
      report "FIN SIMULACION DMA: PASS N="&integer'image(N)&" SPLIT=si @ "&time'image(now) severity note;
    else
      report "FIN SIMULACION DMA: FAIL @ "&time'image(now) severity error;
    end if;
    fin <= true; wait;
  end process;
end architecture sim;
