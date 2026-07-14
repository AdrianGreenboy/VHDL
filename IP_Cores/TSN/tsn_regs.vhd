-- tsn_regs.vhd - Banco de registros MMIO del switch TSN 4x4
-- Contrato dmem de la familia: sel/we/addr/wdata sincronos, rdata COMBINACIONAL
-- (un rdata registrado pasa una capa 2 ingenua pero rompe capa 4: cada lw
-- devuelve el dato de la lectura anterior - leccion de la familia).
-- Desviacion documentada: addr de 9 bits (la familia usa 8) para alojar el
-- bloque Qbv reservado en 0x100-0x1FC (fase 2, base de tiempo PTP).
--
-- Mapa (aprobado en scope freeze):
--   0x000 CONTROL  : b0 enable (rw), b1 cnt_clear (W1, autolimpia, lee 0)
--   0x004 STATUS   : status_in (RO) [3:0] fifo no-vacia [7:4] salida ocupada
--                    [11:8] entrada drenandose
--   0x008 TBL_MAC_LO (rw, holding)   MAC destino [31:0]
--   0x00C TBL_MAC_HI (rw, holding)   [15:0] MAC[47:32] [17:16] puerto [31] valid
--   0x010 TBL_IDX  : escritura dispara tbl_wr con idx=wdata[3:0]; lee ultimo idx
--   0x040-0x04C RX_CNT p0-p3   (RO, wrap, clear por cnt_clear)
--   0x050-0x05C TX_CNT p0-p3
--   0x060-0x06C DROP_OVF p0-p3
--   0x070-0x07C DROP_FCS p0-p3
--   0x080-0x08C TAGGED p0-p3
--   0x0C0 DBG_STATE : dbg_in (RO)
--   0x100-0x1FC Qbv GCL reservado fase 2 (lee 0, escritura ignorada)
--   resto: lee 0, escritura ignorada

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsn_regs is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                       -- sincrono, activo alto
    -- bus dmem
    sel       : in  std_logic;
    we        : in  std_logic;
    addr      : in  std_logic_vector(8 downto 0);
    wdata     : in  std_logic_vector(31 downto 0);
    rdata     : out std_logic_vector(31 downto 0);   -- COMBINACIONAL
    irq       : out std_logic;                       -- reservado (0 en v1)
    -- control
    enable    : out std_logic;
    -- escritura de tabla hacia el xbar
    tbl_wr    : out std_logic;
    tbl_idx   : out std_logic_vector(3 downto 0);
    tbl_mac   : out std_logic_vector(47 downto 0);
    tbl_port  : out std_logic_vector(1 downto 0);
    tbl_vld   : out std_logic;
    -- control del inyector (0x020-0x02C)
    inj_push  : out std_logic;                       -- pulso: empuja wdata
    inj_word  : out std_logic_vector(31 downto 0);
    inj_clr   : out std_logic;                       -- pulso: reinicia buffer
    inj_len   : out unsigned(11 downto 0);
    inj_go    : out std_logic;                       -- pulso: dispara
    inj_psel  : out std_logic_vector(1 downto 0);
    inj_busy  : in  std_logic;
    -- pulsos de contadores (del ingress/xbar)
    p_rx      : in  std_logic_vector(3 downto 0);
    p_tx      : in  std_logic_vector(3 downto 0);
    p_ovf     : in  std_logic_vector(3 downto 0);
    p_fcs     : in  std_logic_vector(3 downto 0);
    p_tag     : in  std_logic_vector(3 downto 0);
    -- estado y debug
    status_in : in  std_logic_vector(11 downto 0);
    dbg_in    : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of tsn_regs is
  signal enable_r  : std_logic := '0';
  signal cnt_clr   : std_logic := '0';
  signal mac_lo_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal mac_hi_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal idx_r     : std_logic_vector(3 downto 0)  := (others => '0');
  signal tbl_wr_r  : std_logic := '0';

  -- inyector
  signal inj_len_r  : unsigned(11 downto 0) := (others => '0');
  signal inj_psel_r : std_logic_vector(1 downto 0) := (others => '0');
  signal inj_push_r, inj_clr_r, inj_go_r : std_logic := '0';
  signal inj_word_r : std_logic_vector(31 downto 0) := (others => '0');

  -- 20 contadores: grupo g (0=rx 1=tx 2=ovf 3=fcs 4=tag) x puerto p
  type cnt_t is array (0 to 19) of unsigned(31 downto 0);
  signal cnt : cnt_t := (others => (others => '0'));

  signal pulses : std_logic_vector(19 downto 0);
begin
  irq      <= '0';
  enable   <= enable_r;
  tbl_wr   <= tbl_wr_r;
  tbl_idx  <= idx_r;
  tbl_mac  <= mac_hi_r(15 downto 0) & mac_lo_r;
  tbl_port <= mac_hi_r(17 downto 16);
  tbl_vld  <= mac_hi_r(31);

  inj_push <= inj_push_r;
  inj_word <= inj_word_r;
  inj_clr  <= inj_clr_r;
  inj_len  <= inj_len_r;
  inj_go   <= inj_go_r;
  inj_psel <= inj_psel_r;

  pulses <= p_tag & p_fcs & p_ovf & p_tx & p_rx;

  p_wr : process(clk)
  begin
    if rising_edge(clk) then
      tbl_wr_r <= '0';
      cnt_clr  <= '0';
      inj_push_r <= '0';
      inj_clr_r  <= '0';
      inj_go_r   <= '0';
      if rst = '1' then
        enable_r <= '0';
        mac_lo_r <= (others => '0');
        mac_hi_r <= (others => '0');
        idx_r    <= (others => '0');
        inj_len_r  <= (others => '0');
        inj_psel_r <= (others => '0');
      elsif sel = '1' and we = '1' then
        case addr is
          when 9x"000" =>
            enable_r <= wdata(0);
            cnt_clr  <= wdata(1);            -- W1: pulso de limpieza
          when 9x"008" => mac_lo_r <= wdata;
          when 9x"00C" => mac_hi_r <= wdata;
          when 9x"010" =>
            idx_r    <= wdata(3 downto 0);
            tbl_wr_r <= '1';                 -- dispara la escritura de tabla
          when 9x"020" =>                    -- INJ_CTRL: [1:0] puerto, [2] go
            inj_psel_r <= wdata(1 downto 0);
            inj_go_r   <= wdata(2);
          when 9x"024" =>                    -- INJ_LEN
            inj_len_r  <= unsigned(wdata(11 downto 0));
          when 9x"028" =>                    -- INJ_WDATA: empuja 4 bytes
            inj_word_r <= wdata;
            inj_push_r <= '1';
          when 9x"02C" =>                    -- INJ_STATUS: b1 clr (W1)
            inj_clr_r  <= wdata(1);
          when others => null;               -- RO / reservado / no mapeado
        end case;
      end if;
    end if;
  end process;

  p_cnt : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or cnt_clr = '1' then
        cnt <= (others => (others => '0'));
      else
        for k in 0 to 19 loop
          if pulses(k) = '1' then
            cnt(k) <= cnt(k) + 1;            -- wrap natural a 32 bits
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- lectura COMBINACIONAL (contrato dmem de la familia)
  p_rd : process(all)
    variable g, p : integer;
  begin
    rdata <= (others => '0');
    if sel = '1' and we = '0' then
      case addr is
        when 9x"000" => rdata(0) <= enable_r;         -- b1 lee 0 (W1)
        when 9x"004" => rdata(11 downto 0) <= status_in;
        when 9x"008" => rdata <= mac_lo_r;
        when 9x"00C" => rdata <= mac_hi_r;
        when 9x"010" => rdata(3 downto 0) <= idx_r;
        when 9x"020" => rdata(1 downto 0) <= inj_psel_r;
        when 9x"024" => rdata(11 downto 0) <= std_logic_vector(inj_len_r);
        when 9x"02C" => rdata(0) <= inj_busy;   -- INJ_STATUS: b0 ocupado
        when 9x"0C0" => rdata <= dbg_in;
        when others =>
          if unsigned(addr) >= 16#040# and unsigned(addr) <= 16#08C#
             and addr(1 downto 0) = "00" then
            g := to_integer(unsigned(addr(7 downto 4))) - 4;
            p := to_integer(unsigned(addr(3 downto 2)));
            rdata <= std_logic_vector(cnt(g*4 + p));
          end if;
      end case;
    end if;
  end process;
end architecture;
