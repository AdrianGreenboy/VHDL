-- dma_burst.vhd - Maestro DMA que drena la RX FIFO del RF hacia DDR.
-- Contrato: al recibir start_i (pulso), copia len_i palabras de 32 bits desde
-- la RX FIFO (rd_en/rd_data/empty) hacia un puerto de escritura de DDR
-- (wr_addr/wr_data/wr_en) empezando en addr_i. Emite rafagas troceadas en la
-- FRONTERA DE 4 KB: el estado D_CALC calcula cuantas palabras faltan para el
-- proximo limite de 4 KB y limita la rafaga a ese tope (patron canonico de la
-- familia; el contenido en DDR es identico, solo cambia el troceo del burst).
-- done_o pulsa al terminar. Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dma_burst is
  port (
    clk_i      : in  std_logic;
    aresetn_i  : in  std_logic;
    start_i    : in  std_logic;
    addr_i     : in  std_logic_vector(31 downto 0);
    len_i      : in  std_logic_vector(31 downto 0);   -- numero de palabras
    -- RX FIFO
    fifo_rd_en_o   : out std_logic;
    fifo_rd_data_i : in  std_logic_vector(31 downto 0);
    fifo_empty_i   : in  std_logic;
    -- puerto de escritura a DDR
    wr_en_o    : out std_logic;
    wr_addr_o  : out std_logic_vector(31 downto 0);
    wr_data_o  : out std_logic_vector(31 downto 0);
    busy_o     : out std_logic;
    burst_start_o : out std_logic;   -- pulso al iniciar cada rafaga (post D_CALC)
    burst_len_o   : out std_logic_vector(31 downto 0);  -- longitud de la rafaga
    done_o     : out std_logic
  );
end entity dma_burst;

architecture rtl of dma_burst is
  type t_state is (S_IDLE, S_CALC, S_XFER, S_DONE);
  signal state_r : t_state := S_IDLE;
  signal addr_r  : unsigned(31 downto 0) := (others => '0');
  signal rem_r   : unsigned(31 downto 0) := (others => '0');  -- palabras restantes
  signal burst_r : unsigned(31 downto 0) := (others => '0');
  signal rd_phase_r : std_logic := '0';
begin

  busy_o <= '0' when state_r = S_IDLE else '1';

  proc : process (clk_i, aresetn_i)
    variable to_boundary_v : unsigned(31 downto 0);
    variable words_v       : unsigned(31 downto 0);
  begin
    if aresetn_i = '0' then
      state_r  <= S_IDLE;
      addr_r   <= (others => '0');
      rem_r    <= (others => '0');
      burst_r  <= (others => '0');
      wr_en_o  <= '0';
      wr_addr_o <= (others => '0');
      wr_data_o <= (others => '0');
      fifo_rd_en_o <= '0';
      done_o   <= '0';
      burst_start_o <= '0';
      burst_len_o <= (others=>'0');
    elsif rising_edge(clk_i) then
      wr_en_o <= '0';
      fifo_rd_en_o <= '0';
      done_o <= '0';
      burst_start_o <= '0';

      case state_r is
        when S_IDLE =>
          if start_i = '1' then
            addr_r <= unsigned(addr_i);
            rem_r  <= unsigned(len_i);
            state_r <= S_CALC;
          end if;

        when S_CALC =>
          if rem_r = 0 then
            state_r <= S_DONE;
          else
            -- palabras hasta el proximo limite de 4 KB (0x1000) desde addr_r
            to_boundary_v := (to_unsigned(16#1000#, 32) -
                              (addr_r and to_unsigned(16#0FFF#, 32))) srl 2;
            if to_boundary_v = 0 then
              to_boundary_v := to_unsigned(1024, 32);  -- alineado: rafaga completa de 4KB (1024 palabras)
            end if;
            if rem_r < to_boundary_v then
              words_v := rem_r;
            else
              words_v := to_boundary_v;
            end if;
            burst_r <= words_v;
            burst_start_o <= '1';
            burst_len_o   <= std_logic_vector(words_v);
            state_r <= S_XFER;
          end if;

        when S_XFER =>
          if burst_r = 0 then
            state_r <= S_CALC;
          elsif fifo_empty_i = '0' then
            -- Escribe el frente actual a DDR y hace pop en el mismo flanco.
            -- El frente es combinacional; tras el pop (rd_ptr+1 en este flanco)
            -- el siguiente ciclo presenta la palabra siguiente. Para evitar la
            -- doble lectura (rd_ptr se actualiza al final del flanco), alternamos
            -- lectura/espera con el flag rd_phase.
            if rd_phase_r = '0' then
              wr_en_o   <= '1';
              wr_addr_o <= std_logic_vector(addr_r);
              wr_data_o <= fifo_rd_data_i;
              fifo_rd_en_o <= '1';
              addr_r  <= addr_r + 4;
              rem_r   <= rem_r - 1;
              burst_r <= burst_r - 1;
              rd_phase_r <= '1';   -- proximo ciclo: dejar propagar el pop
            else
              rd_phase_r <= '0';
            end if;
          end if;
          -- si la FIFO esta vacia, espera (stall) hasta que llegue dato

        when S_DONE =>
          done_o <= '1';
          state_r <= S_IDLE;
      end case;
    end if;
  end process proc;

end architecture rtl;
