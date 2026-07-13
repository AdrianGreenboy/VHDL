-- ============================================================================
-- adcs_regfile.vhd — Banco de registros del IP ADCS sobre el BUS DMEM de
-- familia (patron A2, como SpaceWire). Reemplaza el front-end AXI-Lite del
-- diseno de tesis por el contrato dmem del RV32IM:
--   sel   : peticion calificada de 1 ciclo
--   we    : strobe de escritura colapsado (0 => lectura)
--   addr  : offset de registro (byte address; se usa addr[7:2] = indice word)
--   wdata : dato de escritura
--   rdata : COMBINACIONAL durante el ciclo de sel (requerido por el lockstep
--           RTL-vs-ISS de capa 4). NUNCA registrar rdata: un rdata registrado
--           pasa capa 2 por polling pero rompe capa 4 (cada lw devuelve el
--           dato de la lectura anterior).
--   ready : este banco responde en 1 ciclo (comb), ready='1' siempre que sel.
--
-- DONE/ERR STICKY: se limpian solo por soft_reset o start (no clear-on-read;
-- el clear-on-read tenia carrera con done_set => polling infinito). Fiel a la
-- leccion ya incorporada en el diseno de tesis.
--
-- Registros v1: 0x00..0x2C activos; 0x30..0x40 RESERVADOS (QR fase 2, RAZ/WI);
-- 0x44 DEBUG (RO); 0x48 DBGTAG (RO, tag de presencia 0xADC5_0101).
--
-- MUT (solo verificacion, 0 en uso normal):
--   1 = rdata registrado (rompe el contrato combinacional; capa 2 lo caza)
--   2 = START no auto-limpia (pulso se vuelve nivel)
--   3 = DONE clear-on-read (reintroduce la carrera del diseno viejo)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;
use work.riscv_pkg.all;

entity adcs_regfile is
  generic (
    MUT : natural := 0
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    -- bus dmem de familia (contrato real: word_t, wstrb, rdata comb, ready='1')
    dmem_sel   : in  std_logic;                       -- region ADCS decodificada
    dmem_addr  : in  word_t;                          -- offset (se usa [7:0])
    dmem_wdata : in  word_t;
    dmem_wstrb : in  std_logic_vector(3 downto 0);    -- /= "0000" => escritura
    dmem_rdata : out word_t;
    dmem_ready : out std_logic;
    -- control hacia el datapath
    start_pulse : out std_logic;
    soft_reset  : out std_logic;
    irq_en      : out std_logic;
    mode        : out std_logic_vector(1 downto 0);
    n_dim       : out std_logic_vector(IDX_W-1 downto 0);
    maxiter     : out std_logic_vector(15 downto 0);
    step_f      : out std_logic_vector(31 downto 0);
    umax_f      : out std_logic_vector(31 downto 0);
    h_base      : out std_logic_vector(31 downto 0);
    g_base      : out std_logic_vector(31 downto 0);
    u_base      : out std_logic_vector(31 downto 0);
    -- estado desde el datapath
    busy        : in  std_logic;
    done_set    : in  std_logic;
    err_set     : in  std_logic;
    iter_cnt    : in  std_logic_vector(15 downto 0);
    dbg_in      : in  std_logic_vector(31 downto 0)
  );
end entity adcs_regfile;

architecture rtl of adcs_regfile is
  signal reg_ctrl    : std_logic_vector(31 downto 0);
  signal reg_mode    : std_logic_vector(31 downto 0);
  signal reg_ndim    : std_logic_vector(31 downto 0);
  signal reg_maxiter : std_logic_vector(31 downto 0);
  signal reg_step    : std_logic_vector(31 downto 0);
  signal reg_umax    : std_logic_vector(31 downto 0);
  signal reg_hbase   : std_logic_vector(31 downto 0);
  signal reg_gbase   : std_logic_vector(31 downto 0);
  signal reg_ubase   : std_logic_vector(31 downto 0);
  signal st_done     : std_logic;
  signal st_err      : std_logic;

  signal wr_hs       : std_logic;
  signal rd_hs       : std_logic;
  signal a8          : std_logic_vector(7 downto 0);
  signal rdata_c     : std_logic_vector(31 downto 0);
  signal rdata_q     : std_logic_vector(31 downto 0);
begin

  a8    <= dmem_addr(7 downto 0);
  -- escritura: region seleccionada Y algun strobe activo (contrato de familia).
  -- lectura: region seleccionada Y sin strobe (wstrb = "0000").
  wr_hs <= '1' when (dmem_sel = '1' and dmem_wstrb /= "0000") else '0';
  rd_hs <= '1' when (dmem_sel = '1' and dmem_wstrb  = "0000") else '0';

  soft_reset  <= reg_ctrl(CTRL_SRESET_BIT);
  irq_en      <= reg_ctrl(CTRL_IRQEN_BIT);
  mode        <= reg_mode(1 downto 0);
  n_dim       <= reg_ndim(IDX_W-1 downto 0);
  maxiter     <= reg_maxiter(15 downto 0);
  step_f      <= reg_step;
  umax_f      <= reg_umax;
  h_base      <= reg_hbase;
  g_base      <= reg_gbase;
  u_base      <= reg_ubase;

  dmem_ready <= '1';   -- single-cycle: sin wait states (contrato de familia)

  -- ------------------------------------------------------------------------
  -- ESCRITURA + START pulse + STATUS sticky
  -- ------------------------------------------------------------------------
  p_wr : process (clk, rst_n)
    variable start_clr : boolean;
  begin
    if rst_n = '0' then
      reg_ctrl    <= (others => '0');
      reg_mode    <= (others => '0');
      reg_ndim    <= std_logic_vector(to_unsigned(70, 32));
      reg_maxiter <= std_logic_vector(to_unsigned(30, 32));
      reg_step    <= (others => '0');
      reg_umax    <= (others => '0');
      reg_hbase   <= (others => '0');
      reg_gbase   <= (others => '0');
      reg_ubase   <= (others => '0');
      st_done     <= '0';
      st_err      <= '0';
      start_pulse <= '0';
    elsif rising_edge(clk) then
      start_pulse <= '0';
      start_clr := false;
      -- auto-clear del bit START (es un pulso)
      if MUT /= 2 then
        reg_ctrl(CTRL_START_BIT) <= '0';
      end if;

      if wr_hs = '1' then
        case a8 is
          when x"00" =>
            reg_ctrl(7 downto 0) <= dmem_wdata(7 downto 0);
            if dmem_wdata(CTRL_START_BIT) = '1' then
              start_pulse <= '1';
              start_clr   := true;   -- clear con prioridad sobre done_set
            end if;
          when x"08"    => reg_mode    <= dmem_wdata;
          when x"0C"    => reg_ndim    <= dmem_wdata;
          when x"10" => reg_maxiter <= dmem_wdata;
          when x"14"    => reg_step    <= dmem_wdata;
          when x"18"    => reg_umax    <= dmem_wdata;
          when x"1C"   => reg_hbase   <= dmem_wdata;
          when x"20"   => reg_gbase   <= dmem_wdata;
          when x"24"   => reg_ubase   <= dmem_wdata;
          when others      => null;   -- 0x30..0x40 reservados: WI
        end case;
      end if;

      -- STATUS sticky. ANTI-CARRERA (leccion PTP): el clear por START ocurre EN
      -- EL MISMO ciclo de la escritura de CTRL (start_clr), con prioridad sobre
      -- done_set. Si el firmware lee STATUS justo tras escribir START no debe
      -- ver el DONE sticky de la operacion anterior (creeria que la nueva ya
      -- termino y saldria antes de tiempo). El clear via start_pulse registrado
      -- llegaba un ciclo tarde y causaba exactamente esa carrera en capa 4.
      if reg_ctrl(CTRL_SRESET_BIT) = '1' or start_clr then
        st_done <= '0';
        st_err  <= '0';
      else
        if done_set = '1' then st_done <= '1'; end if;
        if err_set  = '1' then st_err  <= '1'; end if;
      end if;

      -- MUT3: DONE clear-on-read (carrera reintroducida a proposito)
      if MUT = 3 and rd_hs = '1' and a8 = x"04" then
        st_done <= '0';
      end if;
    end if;
  end process;

  -- ------------------------------------------------------------------------
  -- LECTURA COMBINACIONAL (contrato de familia)
  -- ------------------------------------------------------------------------
  p_rd_comb : process (all)
  begin
    case a8 is
      when x"00"    => rdata_c <= reg_ctrl;
      when x"04"  => rdata_c <= (31 downto 3 => '0') &
                                     st_err & busy & st_done;
      when x"08"    => rdata_c <= reg_mode;
      when x"0C"    => rdata_c <= reg_ndim;
      when x"10" => rdata_c <= reg_maxiter;
      when x"14"    => rdata_c <= reg_step;
      when x"18"    => rdata_c <= reg_umax;
      when x"1C"   => rdata_c <= reg_hbase;
      when x"20"   => rdata_c <= reg_gbase;
      when x"24"   => rdata_c <= reg_ubase;
      when x"28" => rdata_c <= x"0000" & iter_cnt;
      when x"2C" => rdata_c <= IP_VERSION;
      when x"44"   => rdata_c <= dbg_in;
      when x"48"  => rdata_c <= DBG_TAG;
      when others      => rdata_c <= x"DEAD_BEEF";
    end case;
  end process;

  -- version registrada (solo para la MUTACION 1: rompe el contrato)
  p_rd_reg : process (clk)
  begin
    if rising_edge(clk) then
      if rd_hs = '1' then
        rdata_q <= rdata_c;
      end if;
    end if;
  end process;

  dmem_rdata <= rdata_q when MUT = 1 else rdata_c;

end architecture rtl;
