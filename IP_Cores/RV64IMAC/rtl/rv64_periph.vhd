-- rv64_periph.vhd - puente de perifericos: esclavo AXI4 (beats unicos) hacia
--   0x0000_1000  boot ROM 4 KiB (ROM sincrona canonica)
--   0x0200_0000  CLINT
--   0x0C00_0000  PLIC
--   0x1000_0000  UART 16550
--   0x1001_0000  IP_Cores: 16 ranuras de 64 KiB con el bus MMIO nativo de la familia
--                IP_Cores (sel/req/addr/wdata/wstrb/rdata, 32 bit, un ciclo, igual que
--                el dmem de los SoC RV32): los cores se conectan sin cambios.
--   0x2000_0000  ventana AXI4-Lite de 32 bit (256 MiB) para IPs genericas / Xilinx
-- Un acceso de 8 bytes a una ranura o a la ventana AXI-Lite se parte en dos de 32 bit
-- (palabra baja y luego alta). Rafagas o direcciones fuera del mapa -> SLVERR/DECERR.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_bootrom_pkg.all;

entity rv64_periph is
  generic (TICK_DIV : positive := 100);
  port (
    clk, rst : in std_logic;
    -- esclavo AXI4 (desde el crossbar)
    s_awaddr  : in  xword;
    s_awlen   : in  std_logic_vector(7 downto 0);
    s_awsize  : in  std_logic_vector(2 downto 0);
    s_awvalid : in  std_logic;
    s_awready : out std_logic;
    s_wdata   : in  xword;
    s_wstrb   : in  std_logic_vector(7 downto 0);
    s_wlast   : in  std_logic;
    s_wvalid  : in  std_logic;
    s_wready  : out std_logic;
    s_bresp   : out std_logic_vector(1 downto 0);
    s_bvalid  : out std_logic;
    s_bready  : in  std_logic;
    s_araddr  : in  xword;
    s_arlen   : in  std_logic_vector(7 downto 0);
    s_arsize  : in  std_logic_vector(2 downto 0);
    s_arvalid : in  std_logic;
    s_arready : out std_logic;
    s_rdata   : out xword;
    s_rresp   : out std_logic_vector(1 downto 0);
    s_rlast   : out std_logic;
    s_rvalid  : out std_logic;
    s_rready  : in  std_logic;
    -- bus MMIO nativo de las IP_Cores (ranura n = 0x1001_0000 + n * 64 KiB)
    mm_sel    : out std_logic_vector(15 downto 0);
    mm_req    : out std_logic;
    mm_addr   : out std_logic_vector(15 downto 0);     -- desplazamiento dentro de la ranura
    mm_wdata  : out std_logic_vector(31 downto 0);
    mm_wstrb  : out std_logic_vector(3 downto 0);      -- 0000 = lectura
    mm_rdata  : in  std_logic_vector(16 * 32 - 1 downto 0);
    -- maestro AXI4-Lite 32 bit (ventana 0x2000_0000)
    l_awaddr  : out std_logic_vector(31 downto 0);
    l_awprot  : out std_logic_vector(2 downto 0);
    l_awvalid : out std_logic;
    l_awready : in  std_logic;
    l_wdata   : out std_logic_vector(31 downto 0);
    l_wstrb   : out std_logic_vector(3 downto 0);
    l_wvalid  : out std_logic;
    l_wready  : in  std_logic;
    l_bresp   : in  std_logic_vector(1 downto 0);
    l_bvalid  : in  std_logic;
    l_bready  : out std_logic;
    l_araddr  : out std_logic_vector(31 downto 0);
    l_arprot  : out std_logic_vector(2 downto 0);
    l_arvalid : out std_logic;
    l_arready : in  std_logic;
    l_rdata   : in  std_logic_vector(31 downto 0);
    l_rresp   : in  std_logic_vector(1 downto 0);
    l_rvalid  : in  std_logic;
    l_rready  : out std_logic;
    -- interrupciones de las IP_Cores (fuentes PLIC 2..17) y salidas al core
    irq_ip    : in  std_logic_vector(15 downto 0);
    mtip, msip, meip, seip : out std_logic;
    mtime     : out xword;
    -- UART
    uart_tx   : out std_logic;
    uart_rx   : in  std_logic
  );
end entity;

architecture rtl of rv64_periph is
  type st_t is (IDLE, WDATA, S_ACC, ROMRD, MM, L_AR, L_R, L_AW, L_B, RESP_R, RESP_B);
  signal st     : st_t;
  signal is_wr  : std_logic;
  signal addr   : xword;
  signal size   : std_logic_vector(1 downto 0);
  signal burst  : std_logic;
  signal wd     : xword;
  signal ws     : std_logic_vector(7 downto 0);
  signal rd     : xword;
  signal rerr   : std_logic_vector(1 downto 0);
  signal half   : std_logic;                         -- 2a mitad de un acceso de 8 bytes
  signal aw_ok, w_ok : std_logic;                    -- AW / W de AXI-Lite ya aceptados
  signal mm_slot : natural range 0 to 15;
  signal mm_word : std_logic_vector(31 downto 0);

  -- dispositivos
  type dev_t is (D_NONE, D_ROM, D_CLINT, D_PLIC, D_UART, D_MMIO, D_AXIL);
  signal dev : dev_t;
  signal c_req, p_req, u_req : std_logic;
  signal c_rd, p_rd, u_rd : xword;
  signal c_err, p_err, u_err : std_logic;
  signal u_irq : std_logic;
  signal rom_q : std_logic_vector(63 downto 0);
  signal src   : std_logic_vector(31 downto 1);

  function decode(a : xword) return dev_t is
    variable u : unsigned(63 downto 0) := unsigned(a);
  begin
    if pma_rom(a) then return D_ROM; end if;
    if u >= x"0000000002000000" and u < x"0000000002010000" then return D_CLINT; end if;
    if u >= x"000000000C000000" and u < x"0000000010000000" then return D_PLIC; end if;
    if u >= x"0000000010000000" and u < x"0000000010001000" then return D_UART; end if;
    if u >= x"0000000010010000" and u < x"0000000010110000" then return D_MMIO; end if;
    if u >= x"0000000020000000" and u < x"0000000030000000" then return D_AXIL; end if;
    return D_NONE;
  end function;
begin
  -- ---------------------------------------------------------------- dispositivos
  c_req <= '1' when st = S_ACC and dev = D_CLINT else '0';
  p_req <= '1' when st = S_ACC and dev = D_PLIC else '0';
  u_req <= '1' when st = S_ACC and dev = D_UART else '0';

  clint_u : entity work.rv64_clint generic map (TICK_DIV => TICK_DIV) port map (
    clk => clk, rst => rst, req => c_req, we => is_wr, addr => addr(15 downto 0), size => size,
    wdata => wd, wstrb => ws, rdata => c_rd, err => c_err, mtip => mtip, msip => msip, mtime_o => mtime);

  src <= (17 downto 2 => irq_ip, 1 => u_irq, others => '0');
  plic_u : entity work.rv64_plic port map (
    clk => clk, rst => rst, req => p_req, we => is_wr, addr => addr(25 downto 0), size => size,
    wdata => wd, rdata => p_rd, err => p_err, src => src, meip => meip, seip => seip);

  uart_u : entity work.rv64_uart port map (
    clk => clk, rst => rst, req => u_req, we => is_wr, addr => addr(2 downto 0), size => size,
    wdata => wd, rdata => u_rd, err => u_err, irq => u_irq, tx => uart_tx, rx => uart_rx);

  -- boot ROM sincrona canonica (constante indexada dentro de un proceso con reloj)
  process (clk)
  begin
    if rising_edge(clk) then
      rom_q <= BOOTROM(to_integer(unsigned(addr(11 downto 3))));
    end if;
  end process;

  -- ---------------------------------------------------------------- AXI4 esclavo
  s_arready <= '1' when st = IDLE else '0';
  s_awready <= '1' when st = IDLE and s_arvalid = '0' else '0';
  s_wready  <= '1' when st = WDATA else '0';
  s_rvalid  <= '1' when st = RESP_R else '0';
  s_rdata   <= rd;
  s_rresp   <= rerr;
  s_rlast   <= '1';
  s_bvalid  <= '1' when st = RESP_B else '0';
  s_bresp   <= rerr;

  -- ---------------------------------------------------------------- bus MMIO nativo
  mm_slot <= (to_integer(unsigned(addr(23 downto 16))) + 15) mod 16;  -- 0x1001_0000 -> ranura 0, 0x1010_0000 -> 15
  process (all)
    variable hi : boolean;
  begin
    mm_sel <= (others => '0');
    if st = MM then mm_sel(mm_slot) <= '1'; end if;
    hi := (size = "11" and half = '1') or (size /= "11" and addr(2) = '1');
    mm_req <= '1' when st = MM else '0';
    mm_addr <= addr(15 downto 3) & half & "00" when size = "11" else addr(15 downto 2) & "00";
    if hi then
      mm_wdata <= wd(63 downto 32);
      mm_wstrb <= ws(7 downto 4) when is_wr = '1' else "0000";
    else
      mm_wdata <= wd(31 downto 0);
      mm_wstrb <= ws(3 downto 0) when is_wr = '1' else "0000";
    end if;
    mm_word <= mm_rdata(32 * mm_slot + 31 downto 32 * mm_slot);
  end process;

  -- ---------------------------------------------------------------- AXI4-Lite maestro
  l_araddr  <= addr(31 downto 3) & half & "00" when size = "11" else addr(31 downto 2) & "00";
  l_awaddr  <= addr(31 downto 3) & half & "00" when size = "11" else addr(31 downto 2) & "00";
  l_arprot  <= "000"; l_awprot <= "000";
  l_arvalid <= '1' when st = L_AR else '0';
  l_rready  <= '1' when st = L_R else '0';
  l_awvalid <= '1' when st = L_AW and aw_ok = '0' else '0';
  l_wvalid  <= '1' when st = L_AW and w_ok = '0' else '0';   -- AW y W independientes
  l_wdata   <= wd(63 downto 32) when (size = "11" and half = '1') or (size /= "11" and addr(2) = '1')
               else wd(31 downto 0);
  l_wstrb   <= ws(7 downto 4) when (size = "11" and half = '1') or (size /= "11" and addr(2) = '1')
               else ws(3 downto 0);
  l_bready  <= '1' when st = L_B else '0';

  process (clk)
    variable aw_done, w_done : boolean;
    variable hi : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= IDLE;
      else
        case st is
          when IDLE =>
            half <= '0'; rerr <= "00"; rd <= XZERO; aw_ok <= '0'; w_ok <= '0';
            if s_arvalid = '1' then
              is_wr <= '0'; addr <= s_araddr; size <= s_arsize(1 downto 0);
              burst <= '1' when s_arlen /= x"00" else '0';
              dev <= decode(s_araddr);
              st <= S_ACC;
            elsif s_awvalid = '1' then
              is_wr <= '1'; addr <= s_awaddr; size <= s_awsize(1 downto 0);
              burst <= '1' when s_awlen /= x"00" else '0';
              dev <= decode(s_awaddr);
              st <= WDATA;
            end if;

          when WDATA =>
            if s_wvalid = '1' then
              wd <= s_wdata; ws <= s_wstrb;
              if s_wlast = '1' then st <= S_ACC; end if;   -- rafagas: solo el ultimo beat (con error)
            end if;

          when S_ACC =>
            if burst = '1' then
              rerr <= "10";
              if is_wr = '1' then st <= RESP_B; else st <= RESP_R; end if;
            else
              case dev is
                when D_ROM =>
                  if is_wr = '1' then rerr <= "10"; st <= RESP_B; else st <= ROMRD; end if;
                when D_CLINT =>
                  rd <= c_rd; if c_err = '1' then rerr <= "10"; end if;
                  if is_wr = '1' then st <= RESP_B; else st <= RESP_R; end if;
                when D_PLIC =>
                  rd <= p_rd; if p_err = '1' then rerr <= "10"; end if;
                  if is_wr = '1' then st <= RESP_B; else st <= RESP_R; end if;
                when D_UART =>
                  rd <= u_rd; if u_err = '1' then rerr <= "10"; end if;
                  if is_wr = '1' then st <= RESP_B; else st <= RESP_R; end if;
                when D_MMIO =>
                  st <= MM;
                when D_AXIL =>
                  if is_wr = '1' then st <= L_AW; else st <= L_AR; end if;
                when D_NONE =>
                  rerr <= "11";
                  if is_wr = '1' then st <= RESP_B; else st <= RESP_R; end if;
              end case;
            end if;

          when ROMRD =>
            rd <= rom_q;
            st <= RESP_R;

          when MM =>
            -- un ciclo por palabra de 32 bit; rdata del core es combinacional
            hi := (size = "11" and half = '1') or (size /= "11" and addr(2) = '1');
            if is_wr = '0' then
              if hi then rd(63 downto 32) <= mm_word; else rd(31 downto 0) <= mm_word; end if;
            end if;
            if size = "11" and half = '0' then
              half <= '1';
            elsif is_wr = '1' then
              st <= RESP_B;
            else
              st <= RESP_R;
            end if;

          when L_AR =>
            if l_arready = '1' then st <= L_R; end if;
          when L_R =>
            if l_rvalid = '1' then
              if l_rresp(1) = '1' then rerr <= l_rresp; end if;
              hi := (size = "11" and half = '1') or (size /= "11" and addr(2) = '1');
              if hi then rd(63 downto 32) <= l_rdata; else rd(31 downto 0) <= l_rdata; end if;
              if size = "11" and half = '0' then
                half <= '1'; st <= L_AR;
              else
                st <= RESP_R;
              end if;
            end if;

          when L_AW =>
            -- el esclavo puede aceptar AW y W en ciclos distintos (AXI)
            aw_done := aw_ok = '1' or l_awready = '1';
            w_done  := w_ok = '1' or l_wready = '1';
            if l_awready = '1' then aw_ok <= '1'; end if;
            if l_wready = '1' then w_ok <= '1'; end if;
            if aw_done and w_done then aw_ok <= '0'; w_ok <= '0'; st <= L_B; end if;
          when L_B =>
            if l_bvalid = '1' then
              if l_bresp(1) = '1' then rerr <= l_bresp; end if;
              if size = "11" and half = '0' then
                half <= '1'; st <= L_AW;
              else
                st <= RESP_B;
              end if;
            end if;

          when RESP_R =>
            if s_rready = '1' then st <= IDLE; end if;
          when RESP_B =>
            if s_bready = '1' then st <= IDLE; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
