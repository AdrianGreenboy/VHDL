-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Top del core: banco AXI4-Lite (dominio s_axi_aclk) + cruces + datapath
-- (dominio clk_dp, 390.625 MHz).
--
-- Mapa de registros (offset de byte, ver doc/register_map.md):
--   0x00 ID          RO  0x4D414320 ("MAC" + Core 0x20)
--   0x04 SCRATCH     RW
--   0x08 CTRL        RW  b0 MAC_EN b1 LOOPBACK b2 PROMISC b3 GEN_CONT
--   0x0C CMD         W   b0 SOFT_RESET b1 CNT_CLEAR b2 GEN_START b3 GEN_STOP
--                        b4 INJ   (lee 0)
--   0x10 STATUS      RO  b0 LINK_UP b1 GEN_BUSY b2 GEN_DONE b3 RX_ACTIVE
--                        b4 TX_ACTIVE b8 SNAP_DONE b9 CMD_BUSY b10 CMD_TIMEOUT
--                        (CMD_BUSY: el ultimo CMD aun no se ha ejecutado en el
--                        dominio dp; mientras vale 1, GEN_DONE lee 0 y GEN_BUSY
--                        lee 1, para que un sondeo inmediato no vea el estado
--                        de la rafaga anterior)
--   0x14 IRQ_STATUS  RW1C b0 GEN_DONE b1 RX_CRC_ERR b2 CHK_ERR b3 LINK_LOST
--   0x18 IRQ_ENABLE  RW
--   0x1C SNAP        W   congela los 16 contadores (STATUS.SNAP_DONE al acabar)
--   0x20 MAC_LO 0x24 MAC_HI  direccion propia (= destino del generador)
--   0x28 SRC_LO 0x2C SRC_HI  origen del generador
--   0x30 LEN_CFG     RW  [10:0] len_min [26:16] len_max (L2 sin FCS)
--   0x34 LEN_STEP    RW  [10:0]
--   0x38 GEN_COUNT   RW  tramas por rafaga (GEN_CONT ignora)
--   0x40..0x7C       RO  contadores 0..15 (instantanea)
--
-- Cruces:
--   * CMD: los bits se guardan en un registro AXI estable y un unico toggle
--     avisa al dominio dp, que en ese momento CAPTURA tambien CTRL y toda la
--     configuracion (estables: se escribieron antes que CMD). La
--     configuracion entra en vigor en la siguiente escritura de CMD.
--     Mientras el CMD anterior no se haya ejecutado en el dominio dp
--     (CMD_BUSY) no se acepta NINGUNA escritura (awready retenido): ningun
--     comando se pierde ni se reordena y la configuracion no cambia mientras
--     el dominio dp la captura. Si el dominio dp no confirma en 256 ciclos
--     de aclk (clk_dp parado o en reset) CMD_BUSY se libera y se marca
--     STATUS.CMD_TIMEOUT: el bus nunca queda bloqueado.
--   * AXI: B y R se activan el ciclo DESPUES del handshake de AW/W y AR.
--   * SNAP: toggle a dp, dp copia los 16 contadores a una sombra estable y
--     devuelve un evento; el AXI lee la sombra directamente (estable).
--   * STATUS: doble FF por bit. IRQ: mac25g_evsync (sin perdida de eventos).
--   Todos los caminos de datos multi-bit estables se restringen con
--   set_max_delay -datapath_only en vivado/mac25g_cdc.xdc.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac25g_top is
  port (
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr  : in  std_logic_vector(7 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(7 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;
    irq_out       : out std_logic;

    clk_dp        : in  std_logic;
    rst_dp        : in  std_logic
  );
end entity mac25g_top;

architecture rtl of mac25g_top is
  constant ID_MAGIC : std_logic_vector(31 downto 0) := x"4D414320";

  signal rst_axi : std_logic;

  -- ---- dominio AXI ----
  signal awready_i, wready_i, bvalid_i, arready_i, rvalid_i : std_logic := '0';
  signal rdata_i    : std_logic_vector(31 downto 0) := (others => '0');
  signal r_scratch  : std_logic_vector(31 downto 0) := (others => '0');
  signal r_ctrl     : std_logic_vector(3 downto 0) := (others => '0');
  signal r_cmd      : std_logic_vector(4 downto 0) := (others => '0');
  signal r_irq_st   : std_logic_vector(3 downto 0) := (others => '0');
  signal r_irq_en   : std_logic_vector(3 downto 0) := (others => '0');
  signal r_mac_lo, r_src_lo, r_count : std_logic_vector(31 downto 0) := (others => '0');
  signal r_mac_hi, r_src_hi : std_logic_vector(15 downto 0) := (others => '0');
  signal r_lmin, r_lmax, r_lstep : std_logic_vector(10 downto 0) := (others => '0');
  signal p_cmd, p_snap : std_logic := '0';
  signal snap_done  : std_logic := '0';
  signal cmd_busy   : std_logic := '0';
  signal cmd_tmo    : unsigned(7 downto 0) := (others => '0');
  signal cmd_err    : std_logic := '0';

  -- estado sincronizado a AXI
  signal a_link, a_busy, a_done, a_rx, a_tx : std_logic;
  signal a_ev_done, a_ev_crc, a_ev_chk, a_ev_ll, a_snap_ack, a_cmd_ack : std_logic;

  -- ---- dominio dp ----
  signal d_cmd_stb, d_snap_stb : std_logic;
  signal c_ctrl     : std_logic_vector(3 downto 0) := (others => '0');
  signal c_mac, c_src : std_logic_vector(47 downto 0) := (others => '0');
  signal c_lmin, c_lmax, c_lstep : unsigned(10 downto 0) := (others => '0');
  signal c_count    : unsigned(31 downto 0) := (others => '0');
  signal c_cmd      : std_logic_vector(4 downto 0) := (others => '0');
  signal c_go       : std_logic := '0';
  signal dp_soft, dp_clr, dp_start, dp_stop, dp_inj : std_logic := '0';
  signal dp_rst     : std_logic := '1';
  signal st_link, st_busy, st_done, st_rx, st_tx : std_logic;
  signal ev_done, ev_crc, ev_chk, ev_ll : std_logic;
  signal cnt_flat   : std_logic_vector(16*32-1 downto 0);
  signal shadow     : std_logic_vector(16*32-1 downto 0) := (others => '0');
  signal d_snap_ack : std_logic := '0';
  signal ack_d1, ack_d2 : std_logic := '0';

  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of shadow : signal is "TRUE";
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of dp_rst : signal is 64;
begin
  rst_axi <= not s_axi_aresetn;

  -----------------------------------------------------------------------------
  -- AXI4-Lite: escritura (AW y W juntos), lectura
  -----------------------------------------------------------------------------
  process(s_axi_aclk)
    variable a : std_logic_vector(7 downto 0);
  begin
    if rising_edge(s_axi_aclk) then
      p_cmd <= '0'; p_snap <= '0';
      awready_i <= '0'; wready_i <= '0';
      if s_axi_aresetn = '0' then
        bvalid_i <= '0';
        r_scratch <= (others => '0'); r_ctrl <= (others => '0');
        r_cmd <= (others => '0'); r_irq_st <= (others => '0');
        r_irq_en <= (others => '0');
        r_mac_lo <= x"43414D02"; r_mac_hi <= x"2032";   -- 02:4D:41:43:32:20
        r_src_lo <= x"45474E02"; r_src_hi <= x"204E";   -- 02:4E:47:45:4E:20
        r_lmin <= std_logic_vector(to_unsigned(20, 11));
        r_lmax <= std_logic_vector(to_unsigned(1514, 11));
        r_lstep <= std_logic_vector(to_unsigned(37, 11));
        r_count <= std_logic_vector(to_unsigned(64, 32));
        snap_done <= '0'; cmd_busy <= '0'; cmd_tmo <= (others => '0'); cmd_err <= '0';
      else
        -- stickies de IRQ (set por eventos sincronizados)
        if a_ev_done = '1' then r_irq_st(0) <= '1'; end if;
        if a_ev_crc  = '1' then r_irq_st(1) <= '1'; end if;
        if a_ev_chk  = '1' then r_irq_st(2) <= '1'; end if;
        if a_ev_ll   = '1' then r_irq_st(3) <= '1'; end if;
        if a_snap_ack = '1' then snap_done <= '1'; end if;
        -- CMD_BUSY: desde la escritura de CMD hasta que el dominio dp confirma
        -- que lo ejecuto (y el estado ya refleja el comando), con timeout
        if a_cmd_ack = '1' then
          cmd_busy <= '0'; cmd_err <= '0';
        elsif cmd_busy = '1' then
          if cmd_tmo = 255 then cmd_busy <= '0'; cmd_err <= '1';
          else cmd_tmo <= cmd_tmo + 1; end if;
        end if;
        -- respuesta B el ciclo siguiente al handshake AW/W
        if awready_i = '1' then bvalid_i <= '1'; end if;

        -- ninguna escritura se acepta mientras un CMD esta en vuelo (awready
        -- retenido): orden de comandos y estabilidad de la config en HW
        if s_axi_awvalid = '1' and s_axi_wvalid = '1' and bvalid_i = '0' and
           awready_i = '0' and cmd_busy = '0' then
          awready_i <= '1'; wready_i <= '1';
          a := s_axi_awaddr;
          case a(7 downto 2) is
            when "000001" => r_scratch <= s_axi_wdata;
            when "000010" => r_ctrl <= s_axi_wdata(3 downto 0);
            when "000011" =>
              r_cmd <= s_axi_wdata(4 downto 0);
              p_cmd <= '1'; cmd_busy <= '1'; cmd_tmo <= (others => '0');
            when "000101" =>
              -- RW1C (un evento del mismo ciclo gana)
              for i in 0 to 3 loop
                if s_axi_wdata(i) = '1' then r_irq_st(i) <= '0'; end if;
              end loop;
              if a_ev_done = '1' then r_irq_st(0) <= '1'; end if;
              if a_ev_crc  = '1' then r_irq_st(1) <= '1'; end if;
              if a_ev_chk  = '1' then r_irq_st(2) <= '1'; end if;
              if a_ev_ll   = '1' then r_irq_st(3) <= '1'; end if;
            when "000110" => r_irq_en <= s_axi_wdata(3 downto 0);
            when "000111" => p_snap <= '1'; snap_done <= '0';
            when "001000" => r_mac_lo <= s_axi_wdata;
            when "001001" => r_mac_hi <= s_axi_wdata(15 downto 0);
            when "001010" => r_src_lo <= s_axi_wdata;
            when "001011" => r_src_hi <= s_axi_wdata(15 downto 0);
            when "001100" =>
              r_lmin <= s_axi_wdata(10 downto 0); r_lmax <= s_axi_wdata(26 downto 16);
            when "001101" => r_lstep <= s_axi_wdata(10 downto 0);
            when "001110" => r_count <= s_axi_wdata;
            when others => null;
          end case;
        elsif bvalid_i = '1' and s_axi_bready = '1' then
          bvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

  process(s_axi_aclk)
    variable a : std_logic_vector(7 downto 0);
    variable idx : natural range 0 to 15;
  begin
    if rising_edge(s_axi_aclk) then
      arready_i <= '0';
      if s_axi_aresetn = '0' then
        rvalid_i <= '0'; rdata_i <= (others => '0');
      elsif arready_i = '1' then
        rvalid_i <= '1';                       -- R el ciclo siguiente a AR
      elsif s_axi_arvalid = '1' and rvalid_i = '0' then
        arready_i <= '1';
        a := s_axi_araddr;
        if a(7 downto 6) = "01" then
          idx := to_integer(unsigned(a(5 downto 2)));
          rdata_i <= shadow(32*idx+31 downto 32*idx);
        else
          case a(7 downto 2) is
            when "000000" => rdata_i <= ID_MAGIC;
            when "000001" => rdata_i <= r_scratch;
            when "000010" => rdata_i <= x"0000000" & r_ctrl;
            when "000100" =>
              rdata_i <= (0 => a_link, 1 => a_busy or cmd_busy,
                          2 => a_done and not cmd_busy, 3 => a_rx,
                          4 => a_tx, 8 => snap_done, 9 => cmd_busy,
                          10 => cmd_err, others => '0');
            when "000101" => rdata_i <= x"0000000" & r_irq_st;
            when "000110" => rdata_i <= x"0000000" & r_irq_en;
            when "001000" => rdata_i <= r_mac_lo;
            when "001001" => rdata_i <= x"0000" & r_mac_hi;
            when "001010" => rdata_i <= r_src_lo;
            when "001011" => rdata_i <= x"0000" & r_src_hi;
            when "001100" => rdata_i <= "00000" & r_lmax & "00000" & r_lmin;
            when "001101" => rdata_i <= x"00000" & '0' & r_lstep;
            when "001110" => rdata_i <= r_count;
            when others   => rdata_i <= (others => '0');
          end case;
        end if;
      elsif rvalid_i = '1' and s_axi_rready = '1' then
        rvalid_i <= '0';
      end if;
    end if;
  end process;

  s_axi_awready <= awready_i;
  s_axi_wready  <= wready_i;
  s_axi_bresp   <= "00";
  s_axi_bvalid  <= bvalid_i;
  s_axi_arready <= arready_i;
  s_axi_rdata   <= rdata_i;
  s_axi_rresp   <= "00";
  s_axi_rvalid  <= rvalid_i;
  irq_out       <= '1' when (r_irq_st and r_irq_en) /= "0000" else '0';

  -----------------------------------------------------------------------------
  -- cruces AXI -> dp
  -----------------------------------------------------------------------------
  u_ps_cmd: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_cmd,
              clk_dst=>clk_dp, rst_dst=>rst_dp, pulse_out=>d_cmd_stb);
  u_ps_snap: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_snap,
              clk_dst=>clk_dp, rst_dst=>rst_dp, pulse_out=>d_snap_stb);

  -- captura de configuracion + decodificacion de comandos (1 ciclo despues,
  -- para que la configuracion nueva ya este vigente cuando llega el pulso)
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      dp_soft <= '0'; dp_clr <= '0'; dp_start <= '0'; dp_stop <= '0'; dp_inj <= '0';
      if rst_dp = '1' then
        c_go <= '0'; c_ctrl <= (others => '0'); ack_d1 <= '0'; ack_d2 <= '0';
      else
        c_go <= d_cmd_stb;
        -- confirmacion 2 ciclos despues de los pulsos: el generador ya
        -- actualizo busy/done cuando sale el ack
        ack_d1 <= c_go;
        ack_d2 <= ack_d1;
        if d_cmd_stb = '1' then
          c_ctrl  <= r_ctrl;
          c_cmd   <= r_cmd;
          c_mac   <= r_mac_hi & r_mac_lo;
          c_src   <= r_src_hi & r_src_lo;
          c_lmin  <= unsigned(r_lmin);
          c_lmax  <= unsigned(r_lmax);
          c_lstep <= unsigned(r_lstep);
          c_count <= unsigned(r_count);
        end if;
        if c_go = '1' then
          dp_soft  <= c_cmd(0);
          dp_clr   <= c_cmd(1);
          dp_start <= c_cmd(2);
          dp_stop  <= c_cmd(3);
          dp_inj   <= c_cmd(4);
        end if;
      end if;
    end if;
  end process;

  -- reset del datapath registrado (gran fanout: MAX_FANOUT replica)
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      dp_rst <= rst_dp or dp_soft;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- datapath
  -----------------------------------------------------------------------------
  u_dp: entity work.mac25g_datapath
    port map (
      clk_dp=>clk_dp, rst_dp=>dp_rst,
      mac_en=>c_ctrl(0), loopback=>c_ctrl(1), promisc=>c_ctrl(2), gen_cont=>c_ctrl(3),
      own_mac=>c_mac, src_mac=>c_src, len_min=>c_lmin, len_max=>c_lmax,
      len_step=>c_lstep, gen_count=>c_count,
      gen_start=>dp_start, gen_stop=>dp_stop, cnt_clear=>dp_clr, inj=>dp_inj,
      st_link=>st_link, st_busy=>st_busy, st_done=>st_done,
      st_rx_act=>st_rx, st_tx_act=>st_tx,
      ev_done=>ev_done, ev_crc=>ev_crc, ev_chkerr=>ev_chk, ev_lnk_lo=>ev_ll,
      cnt_flat=>cnt_flat);

  -- instantanea de contadores
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      d_snap_ack <= '0';
      if d_snap_stb = '1' then
        shadow <= cnt_flat;
        d_snap_ack <= '1';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- cruces dp -> AXI
  -----------------------------------------------------------------------------
  u_ls0: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_link, q=>a_link);
  u_ls1: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_busy, q=>a_busy);
  u_ls2: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_done, q=>a_done);
  u_ls3: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_rx,   q=>a_rx);
  u_ls4: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_tx,   q=>a_tx);

  u_ev0: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>ev_done,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_done);
  u_ev1: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>ev_crc,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_crc);
  u_ev2: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>ev_chk,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_chk);
  u_ev3: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>ev_ll,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_ll);
  u_ev5: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>ack_d2,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_cmd_ack);
  u_ev4: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp, ev_in=>d_snap_ack,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_snap_ack);

end architecture rtl;
