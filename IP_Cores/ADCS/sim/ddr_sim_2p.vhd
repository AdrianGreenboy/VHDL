-- ============================================================================
-- ddr_sim_2p.vhd — Modelo de DDR para sim con DOS puertos AXI4 esclavos que
-- comparten la MISMA memoria (en silicio: dos puertos NoC al mismo controlador
-- LPDDR4). Puerto 0 = dma_burst del SoC (ADDR_W bits); puerto 1 = maestro
-- propio del IP ADCS (32 bits). Precarga por INIT_FILE, lectura de debug.
--
-- Arbitraje trivial: cada puerto tiene su FSM independiente; las escrituras se
-- serializan por ser un unico proceso (last-write-wins por direccion). Backpre-
-- ssure ligera por LFSR para no idealizar el NoC.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use work.riscv_pkg.all;

entity ddr_sim_2p is
  generic (
    ADDR_W    : natural := 40;
    DEPTH     : natural := 16384;
    INIT_FILE : string  := ""
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    -- puerto 0: dma_burst del SoC (ADDR_W)
    p0_awaddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    p0_awlen   : in  std_logic_vector(7 downto 0);
    p0_awvalid : in  std_logic;
    p0_awready : out std_logic;
    p0_wdata   : in  std_logic_vector(31 downto 0);
    p0_wstrb   : in  std_logic_vector(3 downto 0);
    p0_wlast   : in  std_logic;
    p0_wvalid  : in  std_logic;
    p0_wready  : out std_logic;
    p0_bresp   : out std_logic_vector(1 downto 0);
    p0_bvalid  : out std_logic;
    p0_bready  : in  std_logic;
    p0_araddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    p0_arlen   : in  std_logic_vector(7 downto 0);
    p0_arvalid : in  std_logic;
    p0_arready : out std_logic;
    p0_rdata   : out std_logic_vector(31 downto 0);
    p0_rresp   : out std_logic_vector(1 downto 0);
    p0_rlast   : out std_logic;
    p0_rvalid  : out std_logic;
    p0_rready  : in  std_logic;
    -- puerto 1: maestro del IP ADCS (32 bits)
    p1_awaddr  : in  std_logic_vector(31 downto 0);
    p1_awvalid : in  std_logic;
    p1_awready : out std_logic;
    p1_wdata   : in  std_logic_vector(31 downto 0);
    p1_wstrb   : in  std_logic_vector(3 downto 0);
    p1_wlast   : in  std_logic;
    p1_wvalid  : in  std_logic;
    p1_wready  : out std_logic;
    p1_bresp   : out std_logic_vector(1 downto 0);
    p1_bvalid  : out std_logic;
    p1_bready  : in  std_logic;
    p1_araddr  : in  std_logic_vector(31 downto 0);
    p1_arvalid : in  std_logic;
    p1_arready : out std_logic;
    p1_rdata   : out std_logic_vector(31 downto 0);
    p1_rresp   : out std_logic_vector(1 downto 0);
    p1_rlast   : out std_logic;
    p1_rvalid  : out std_logic;
    p1_rready  : in  std_logic;
    -- debug
    dbg_addr : in  natural := 0;
    dbg_data : out word_t
  );
end entity ddr_sim_2p;

architecture sim of ddr_sim_2p is
  type mem_t is array (0 to DEPTH-1) of word_t;

  impure function load(fn : string) return mem_t is
    file     f : text;
    variable l : line;
    variable w : word_t;
    variable m : mem_t := (others => (others => '0'));
    variable i : natural := 0;
    variable st : file_open_status;
  begin
    if fn = "" then return m; end if;
    file_open(st, f, fn, read_mode);
    if st /= open_ok then return m; end if;
    while not endfile(f) and i < DEPTH loop
      readline(f, l);
      if l'length > 0 then hread(l, w); m(i) := w; i := i + 1; end if;
    end loop;
    file_close(f);
    return m;
  end function;

  signal mem : mem_t := load(INIT_FILE);
  constant HI : natural := 1 + integer(ceil(log2(real(DEPTH))));

  -- FSMs de cada puerto
  type wst_t is (W_IDLE, W_DATA, W_RESP);
  type rst_t is (R_IDLE, R_DATA);
  signal w0, w1 : wst_t := W_IDLE;
  signal r0, r1 : rst_t := R_IDLE;
  signal w0_idx, w1_idx, r0_idx, r1_idx : natural range 0 to DEPTH-1 := 0;
  signal r0_cnt, r1_cnt : integer := 0;
begin

  dbg_data <= mem(dbg_addr) when dbg_addr < DEPTH else (others => '0');

  process (clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        p0_awready <= '0'; p0_wready <= '0'; p0_bvalid <= '0'; p0_bresp <= "00";
        p0_arready <= '0'; p0_rvalid <= '0'; p0_rlast <= '0'; p0_rresp <= "00";
        p1_awready <= '0'; p1_wready <= '0'; p1_bvalid <= '0'; p1_bresp <= "00";
        p1_arready <= '0'; p1_rvalid <= '0'; p1_rlast <= '0'; p1_rresp <= "00";
        w0 <= W_IDLE; w1 <= W_IDLE; r0 <= R_IDLE; r1 <= R_IDLE;
      else
        -- ============ PUERTO 0 (dma_burst SoC) ============
        -- escritura
        p0_awready <= '0';
        case w0 is
          when W_IDLE =>
            if p0_awvalid = '1' then
              p0_awready <= '1';
              w0_idx <= to_integer(unsigned(p0_awaddr(HI downto 2)));
              w0 <= W_DATA;
            end if;
          when W_DATA =>
            p0_wready <= '1';
            if p0_wvalid = '1' and p0_wready = '1' then
              for b in 0 to 3 loop
                if p0_wstrb(b) = '1' then
                  mem(w0_idx)(b*8+7 downto b*8) <= p0_wdata(b*8+7 downto b*8);
                end if;
              end loop;
              if p0_wlast = '1' then
                p0_wready <= '0';
                p0_bvalid <= '1'; p0_bresp <= "00";
                w0 <= W_RESP;
              else
                w0_idx <= w0_idx + 1;
              end if;
            end if;
          when W_RESP =>
            if p0_bready = '1' then p0_bvalid <= '0'; w0 <= W_IDLE; end if;
        end case;
        -- lectura
        p0_arready <= '0';
        case r0 is
          when R_IDLE =>
            if p0_arvalid = '1' then
              p0_arready <= '1';
              r0_idx <= to_integer(unsigned(p0_araddr(HI downto 2)));
              r0_cnt <= to_integer(unsigned(p0_arlen));
              r0 <= R_DATA;
            end if;
          when R_DATA =>
            if p0_rvalid = '0' then
              p0_rdata <= mem(r0_idx);
              p0_rvalid <= '1'; p0_rresp <= "00";
              if r0_cnt = 0 then p0_rlast <= '1'; else p0_rlast <= '0'; end if;
            elsif p0_rready = '1' then
              if r0_cnt = 0 then
                p0_rvalid <= '0'; p0_rlast <= '0'; r0 <= R_IDLE;
              else
                r0_idx <= r0_idx + 1; r0_cnt <= r0_cnt - 1;
                p0_rdata <= mem(r0_idx + 1);
                if r0_cnt - 1 = 0 then p0_rlast <= '1'; end if;
              end if;
            end if;
        end case;

        -- ============ PUERTO 1 (maestro ADCS) ============
        p1_awready <= '0';
        case w1 is
          when W_IDLE =>
            if p1_awvalid = '1' then
              p1_awready <= '1';
              w1_idx <= to_integer(unsigned(p1_awaddr(HI downto 2)));
              w1 <= W_DATA;
            end if;
          when W_DATA =>
            p1_wready <= '1';
            if p1_wvalid = '1' and p1_wready = '1' then
              for b in 0 to 3 loop
                if p1_wstrb(b) = '1' then
                  mem(w1_idx)(b*8+7 downto b*8) <= p1_wdata(b*8+7 downto b*8);
                end if;
              end loop;
              p1_wready <= '0';
              p1_bvalid <= '1'; p1_bresp <= "00";
              w1 <= W_RESP;
            end if;
          when W_RESP =>
            if p1_bready = '1' then p1_bvalid <= '0'; w1 <= W_IDLE; end if;
        end case;
        p1_arready <= '0';
        case r1 is
          when R_IDLE =>
            if p1_arvalid = '1' then
              p1_arready <= '1';
              r1_idx <= to_integer(unsigned(p1_araddr(HI downto 2)));
              r1 <= R_DATA;
            end if;
          when R_DATA =>
            if p1_rvalid = '0' then
              p1_rdata <= mem(r1_idx);
              p1_rvalid <= '1'; p1_rresp <= "00"; p1_rlast <= '1';
            elsif p1_rready = '1' then
              p1_rvalid <= '0'; p1_rlast <= '0'; r1 <= R_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture sim;
