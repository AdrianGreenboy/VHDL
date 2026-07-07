-- =============================================================================
--  axil_soc.vhd  -  Esclavo AXI4-Lite: control del core + ventanas IMEM/DMEM
--  Licencia: MIT
--
--  Mapa de direcciones (espacio de 64 KB, palabra alineada):
--    0x0000  CONTROL  (rw)  bit0 = 1 mantiene el core en reset (halt)
--    0x0004  STATUS   (ro)  bit0 = core corriendo (= not CONTROL.bit0)
--    0x0008  DBG_PC   (ro)  PC actual del core
--    0x1000..0x1FFF  ventana IMEM (una palabra por direccion, addr[.. :2])
--    0x2000..0x2FFF  ventana DMEM
--
--  El PS pone CONTROL.bit0 = 1 (halt) antes de escribir/leer IMEM/DMEM; ese bit
--  conmuta el arbitraje de escritura de las RAMs (axi_owns). Al reset el core
--  arranca detenido (CONTROL.bit0 = 1).
--
--  Esclavo AXI4-Lite simple (una transaccion a la vez), con ready combinacional.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity axil_soc is
  generic ( ADDR_W : natural := 16 );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    s_axi_awaddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    cpu_hold_reset : out std_logic;
    axi_owns_mem   : out std_logic;
    dbg_pc         : in  word_t;

    imem_axi_addr  : out word_t;
    imem_axi_wdata : out word_t;
    imem_axi_wstrb : out std_logic_vector(3 downto 0);
    imem_axi_rdata : in  word_t;

    dmem_axi_addr  : out word_t;
    dmem_axi_wdata : out word_t;
    dmem_axi_wstrb : out std_logic_vector(3 downto 0);
    dmem_axi_rdata : in  word_t;

    -- interrupcion: el core escribio el doorbell (fin de calculo)
    done_pulse : in  std_logic := '0';
    irq_out    : out std_logic;

    -- base fisica de la DDR para el DMA (la fija el A72 por 0x10/0x14)
    ddr_base_o : out std_logic_vector(39 downto 0)
  );
end entity axil_soc;

architecture rtl of axil_soc is
  constant REG_REGS : std_logic_vector(1 downto 0) := "00";
  constant REG_IMEM : std_logic_vector(1 downto 0) := "01";
  constant REG_DMEM : std_logic_vector(1 downto 0) := "10";

  type wstate_t is (W_IDLE, W_WRITE, W_RESP);
  type rstate_t is (R_IDLE, R_DATA);
  signal wstate : wstate_t := W_IDLE;
  signal rstate : rstate_t := R_IDLE;

  signal awaddr_q, araddr_q : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal wdata_q  : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb_q  : std_logic_vector(3 downto 0)  := (others => '0');
  signal ctrl_reg : std_logic_vector(31 downto 0) := (0 => '1', others => '0');
  signal rdata_q  : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wstrb : std_logic_vector(3 downto 0) := "0000";
  signal irq_sticky : std_logic := '0';
  signal ddr_base_lo : std_logic_vector(31 downto 0) := (others => '0');
  signal ddr_base_hi : std_logic_vector(7 downto 0)  := (others => '0');
begin

  ddr_base_o <= ddr_base_hi & ddr_base_lo;

  cpu_hold_reset <= ctrl_reg(0);
  axi_owns_mem   <= ctrl_reg(0);
  irq_out        <= irq_sticky;

  s_axi_bresp <= "00";
  s_axi_rresp <= "00";
  s_axi_rdata <= rdata_q;

  -- ready combinacional
  s_axi_awready <= '1' when (wstate = W_IDLE and s_axi_awvalid = '1' and s_axi_wvalid = '1') else '0';
  s_axi_wready  <= s_axi_awready;
  s_axi_arready <= '1' when (rstate = R_IDLE and s_axi_arvalid = '1') else '0';

  -- direccion/dato hacia las RAMs
  imem_axi_addr <= std_logic_vector(resize(unsigned(awaddr_q), 32)) when wstate = W_WRITE
                   else std_logic_vector(resize(unsigned(araddr_q), 32));
  dmem_axi_addr <= imem_axi_addr;
  imem_axi_wdata <= wdata_q;
  dmem_axi_wdata <= wdata_q;
  imem_axi_wstrb <= mem_wstrb when awaddr_q(13 downto 12) = REG_IMEM else "0000";
  dmem_axi_wstrb <= mem_wstrb when awaddr_q(13 downto 12) = REG_DMEM else "0000";

  -- escritura a memoria alineada con la direccion (ambas validas en W_WRITE)
  mem_wstrb <= wstrb_q when wstate = W_WRITE else "0000";

  ---------------------------------------------------------------------------
  -- Canal de escritura
  ---------------------------------------------------------------------------
  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        wstate       <= W_IDLE;
        ctrl_reg     <= (0 => '1', others => '0');
        s_axi_bvalid <= '0';
        ddr_base_lo  <= (others => '0');
        ddr_base_hi  <= (others => '0');
      else
        case wstate is
          when W_IDLE =>
            if s_axi_awvalid = '1' and s_axi_wvalid = '1' then
              awaddr_q <= s_axi_awaddr;
              wdata_q  <= s_axi_wdata;
              wstrb_q  <= s_axi_wstrb;
              wstate   <= W_WRITE;
            end if;

          when W_WRITE =>
            -- CONTROL/DDR_BASE se escriben aqui; IMEM/DMEM via mem_wstrb (comb)
            if awaddr_q(13 downto 12) = REG_REGS then
              case awaddr_q(4 downto 2) is
                when "000"  => ctrl_reg    <= wdata_q;               -- 0x00 CONTROL
                when "100"  => ddr_base_lo <= wdata_q;               -- 0x10 DDR_BASE_LO
                when "101"  => ddr_base_hi <= wdata_q(7 downto 0);   -- 0x14 DDR_BASE_HI
                when others => null;
              end case;
            end if;
            s_axi_bvalid <= '1';
            wstate       <= W_RESP;

          when W_RESP =>
            if s_axi_bready = '1' then
              s_axi_bvalid <= '0';
              wstate       <= W_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Canal de lectura
  ---------------------------------------------------------------------------
  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        rstate       <= R_IDLE;
        s_axi_rvalid <= '0';
      else
        case rstate is
          when R_IDLE =>
            if s_axi_arvalid = '1' then
              araddr_q <= s_axi_araddr;
              rstate   <= R_DATA;
            end if;

          when R_DATA =>
            case araddr_q(13 downto 12) is
              when REG_REGS =>
                case araddr_q(4 downto 2) is
                  when "000"  => rdata_q <= ctrl_reg;
                  when "001"  => rdata_q <= (0 => not ctrl_reg(0), others => '0');
                  when "010"  => rdata_q <= dbg_pc;
                  when "011"  => rdata_q <= (0 => irq_sticky, others => '0'); -- 0x0C IRQ
                  when "100"  => rdata_q <= ddr_base_lo;                       -- 0x10
                  when "101"  => rdata_q <= std_logic_vector(resize(unsigned(ddr_base_hi), 32)); -- 0x14
                  when others => rdata_q <= (others => '0');
                end case;
              when REG_IMEM => rdata_q <= imem_axi_rdata;
              when REG_DMEM => rdata_q <= dmem_axi_rdata;
              when others   => rdata_q <= (others => '0');
            end case;
            s_axi_rvalid <= '1';
            if s_axi_rvalid = '1' and s_axi_rready = '1' then
              s_axi_rvalid <= '0';
              rstate       <= R_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Interrupcion: sticky, se pone con done_pulse, se limpia escribiendo 1 al
  -- registro IRQ (offset 0x0C). done_pulse tiene prioridad.
  ---------------------------------------------------------------------------
  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        irq_sticky <= '0';
      elsif done_pulse = '1' then
        irq_sticky <= '1';
      elsif (wstate = W_WRITE and awaddr_q(13 downto 12) = REG_REGS and
             awaddr_q(4 downto 2) = "011" and wdata_q(0) = '1') then
        irq_sticky <= '0';
      end if;
    end if;
  end process;

end architecture rtl;
