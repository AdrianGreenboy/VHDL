-- rv64_uart.vhd - UART compatible 16550 (subconjunto para OpenSBI y el driver
-- 8250 de Linux): FIFOs TX/RX de 16, DLL/DLM, IER/IIR/FCR/LCR/MCR/LSR/MSR/SCR,
-- 8N1 con divisor x16. Solo accesos de 1 byte (otros -> error, como el ISS).
-- irq: datos recibidos (IER0) o THR vacio (IER1).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_uart is
  port (
    clk, rst : in  std_logic;
    req      : in  std_logic;
    we       : in  std_logic;
    addr     : in  std_logic_vector(2 downto 0);
    size     : in  std_logic_vector(1 downto 0);
    wdata    : in  xword;                              -- por carriles
    rdata    : out xword;                              -- por carriles
    err      : out std_logic;
    irq      : out std_logic;
    tx       : out std_logic;
    rx       : in  std_logic
  );
end entity;

architecture rtl of rv64_uart is
  type fifo_t is array (0 to 15) of std_logic_vector(7 downto 0);
  signal txf, rxf : fifo_t;
  signal tx_wp, tx_rp, rx_wp, rx_rp : unsigned(4 downto 0);
  signal ier, lcr, mcr, scr, dll, dlm : std_logic_vector(7 downto 0);
  signal fifo_en : std_logic;
  signal thre_irq_armed : std_logic;
  -- emisor
  signal tx_busy  : std_logic;
  signal tx_sh    : std_logic_vector(9 downto 0);
  signal tx_cnt   : unsigned(3 downto 0);
  signal tx_tick  : unsigned(19 downto 0);
  -- receptor
  signal rx_s1, rx_s2 : std_logic;
  signal rx_busy  : std_logic;
  signal rx_sh    : std_logic_vector(7 downto 0);
  signal rx_cnt   : unsigned(3 downto 0);
  signal rx_tick  : unsigned(19 downto 0);
  signal rx_over  : std_logic;

  signal wb       : std_logic_vector(7 downto 0);
  signal tx_empty, rx_avail, tx_full, rx_full : std_logic;
  signal bitlen   : unsigned(19 downto 0);
begin
  tx_empty <= '1' when tx_wp = tx_rp else '0';
  tx_full  <= '1' when tx_wp - tx_rp = 16 else '0';
  rx_avail <= '1' when rx_wp /= rx_rp else '0';
  rx_full  <= '1' when rx_wp - rx_rp = 16 else '0';
  bitlen   <= unsigned(std_logic_vector'(dlm & dll)) & "0000";   -- divisor x16 ciclos por bit
  wb <= wdata(8 * to_integer(unsigned(addr)) + 7 downto 8 * to_integer(unsigned(addr)));
  irq <= (ier(0) and rx_avail) or (ier(1) and thre_irq_armed);

  process (all)
    variable v : std_logic_vector(7 downto 0);
  begin
    v := x"00";
    case addr is
      when "000" =>
        if lcr(7) = '1' then v := dll;
        elsif rx_avail = '1' then v := rxf(to_integer(rx_rp(3 downto 0)));
        else v := x"00"; end if;                     -- FIFO vacia: valor definido (no basura)
      when "001" => if lcr(7) = '1' then v := dlm; else v := ier; end if;
      when "010" =>                                  -- IIR
        if ier(0) = '1' and rx_avail = '1' then v := x"04";
        elsif ier(1) = '1' and thre_irq_armed = '1' then v := x"02";
        else v := x"01"; end if;
        if fifo_en = '1' then v(7 downto 6) := "11"; end if;
      when "011" => v := lcr;
      when "100" => v := mcr;
      when "101" => v := '0' & (tx_empty and not tx_busy) & tx_empty & "000" & rx_over & rx_avail;
      when "110" => v := x"B0";                       -- DCD, DSR, CTS
      when others => v := scr;
    end case;
    rdata <= std_logic_vector(shift_left(resize(unsigned(v), 64), 8 * to_integer(unsigned(addr))));
    err <= '1' when req = '1' and size /= "00" else '0';
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tx_wp <= (others => '0'); tx_rp <= (others => '0'); rx_wp <= (others => '0'); rx_rp <= (others => '0');
        ier <= x"00"; lcr <= x"03"; mcr <= x"00"; scr <= x"00"; dll <= x"01"; dlm <= x"00";
        fifo_en <= '0'; thre_irq_armed <= '0';
        tx_busy <= '0'; tx <= '1'; rx_busy <= '0'; rx_over <= '0'; rx_s1 <= '1'; rx_s2 <= '1';
      else
        -- ------------------------------------------------ registros
        if req = '1' and size = "00" then
          if we = '1' then
            case addr is
              when "000" =>
                if lcr(7) = '1' then dll <= wb;
                elsif tx_full = '0' then
                  txf(to_integer(tx_wp(3 downto 0))) <= wb; tx_wp <= tx_wp + 1; thre_irq_armed <= '0';
                end if;
              when "001" =>
                if lcr(7) = '1' then dlm <= wb;
                else
                  ier <= wb;
                  if wb(1) = '1' and tx_empty = '1' then thre_irq_armed <= '1'; end if;
                end if;
              when "010" =>
                fifo_en <= wb(0);
                if wb(1) = '1' then rx_rp <= rx_wp; rx_over <= '0'; end if;
                if wb(2) = '1' then tx_rp <= tx_wp; end if;
              when "011" => lcr <= wb;
              when "100" => mcr <= wb;
              when "111" => scr <= wb;
              when others => null;
            end case;
          else
            if addr = "000" and lcr(7) = '0' and rx_avail = '1' then rx_rp <= rx_rp + 1; end if;
            if addr = "010" and ier(1) = '1' and thre_irq_armed = '1' and
               not (ier(0) = '1' and rx_avail = '1') then
              thre_irq_armed <= '0';                     -- leer IIR con THRE limpia la causa
            end if;
            if addr = "101" then rx_over <= '0'; end if;
          end if;
        end if;

        -- ------------------------------------------------ emisor 8N1
        if tx_busy = '0' then
          if tx_empty = '0' then
            tx_sh <= '1' & txf(to_integer(tx_rp(3 downto 0))) & '0';
            tx_rp <= tx_rp + 1; tx_busy <= '1'; tx_cnt <= (others => '0'); tx_tick <= (others => '0');
            if tx_wp = tx_rp + 1 and ier(1) = '1' then thre_irq_armed <= '1'; end if;
          end if;
        else
          tx <= tx_sh(0);
          if tx_tick = bitlen - 1 then
            tx_tick <= (others => '0');
            tx_sh <= '1' & tx_sh(9 downto 1);
            if tx_cnt = 9 then tx_busy <= '0'; tx <= '1'; else tx_cnt <= tx_cnt + 1; end if;
          else
            tx_tick <= tx_tick + 1;
          end if;
        end if;

        -- ------------------------------------------------ receptor 8N1
        rx_s1 <= rx; rx_s2 <= rx_s1;
        if rx_busy = '0' then
          if rx_s2 = '0' then                            -- bit de start
            rx_busy <= '1'; rx_cnt <= (others => '0'); rx_tick <= '0' & bitlen(19 downto 1);
          end if;
        else
          if rx_tick = bitlen - 1 then
            rx_tick <= (others => '0');
            if rx_cnt = 0 and rx_s2 = '1' then
              rx_busy <= '0';                            -- start espurio
            elsif rx_cnt = 9 then
              rx_busy <= '0';
              if rx_full = '0' then
                rxf(to_integer(rx_wp(3 downto 0))) <= rx_sh; rx_wp <= rx_wp + 1;
              else
                rx_over <= '1';
              end if;
            else
              if rx_cnt /= 0 then rx_sh <= rx_s2 & rx_sh(7 downto 1); end if;
              rx_cnt <= rx_cnt + 1;
            end if;
          else
            rx_tick <= rx_tick + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
