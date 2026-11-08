-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Top del core: banco AXI4-Lite (dominio s_axi_aclk) + cruces + datapath
-- (dominio clk_dp, 390.625 MHz).
--
-- Mapa de registros (offset de byte, ver doc/register_map.md):
--   0x00 ID          RO  0x4D414320 ("MAC" + Core 0x20)
--   0x04 SCRATCH     RW
--   0x08 CTRL        RW  b0 MAC_EN b1 LOOPBACK b2 PROMISC b3 GEN_CONT
--                        b4 RX_HOLD (RX FIFO consumer stalled: tests the
--                        back-pressure / PAUSE path)
--   0x0C CMD         W   b0 SOFT_RESET b1 CNT_CLEAR b2 GEN_START b3 GEN_STOP
--                        b4 INJ b5 SEND_PAUSE (PAUSE_SWQ quanta)  (lee 0)
--   0x10 STATUS      RO  b0 LINK_UP b1 GEN_BUSY b2 GEN_DONE b3 RX_ACTIVE
--                        b4 TX_ACTIVE b5 PAUSED b6 XOFF b8 SNAP_DONE
--                        b9 CMD_BUSY b10 CMD_TIMEOUT
--                        (CMD_BUSY: el ultimo CMD aun no se ha ejecutado en el
--                        dominio dp; mientras vale 1, GEN_DONE lee 0 y GEN_BUSY
--                        lee 1, para que un sondeo inmediato no vea el estado
--                        de la rafaga anterior)
--   0x14 IRQ_STATUS  RW1C b0 GEN_DONE b1 RX_CRC_ERR b2 CHK_ERR b3 LINK_LOST
--   0x18 IRQ_ENABLE  RW
--   0x1C SNAP        W   congela los 24 contadores (STATUS.SNAP_DONE al acabar)
--   0x20 MAC_LO 0x24 MAC_HI  direccion propia (= destino del generador)
--   0x28 SRC_LO 0x2C SRC_HI  origen del generador
--   0x30 LEN_CFG     RW  [10:0] len_min [26:16] len_max (L2 sin FCS)
--   0x34 LEN_STEP    RW  [10:0]
--   0x38 GEN_COUNT   RW  tramas por rafaga (GEN_CONT ignora; 0 = rafaga vacia)
--   0x3C PAUSE_CTRL  RW  b0 HONOR (obey received PAUSE) b1 AUTO (XOFF/XON
--                        from the RX FIFO watermarks) [31:16] XOFF quanta
--   0x40..0x7C       RO  contadores 0..15 (instantanea)
--   0x80 PAUSE_WM    RW  [15:0] low watermark [31:16] high watermark (words)
--   0x84 PAUSE_SWQ   RW  [15:0] quanta of CMD.SEND_PAUSE
--   0xA0..0xBC       RO  contadores 16..23 (instantanea): RX_PAUSE TX_PAUSE
--                        RX_CTRL RX_FIFO_DROP TX_KEEP_ERR BLK_FIFO_OVF
--                        PAUSED_SLOTS RX_FIFO_MAX
--   Unmapped offsets answer SLVERR (B and R); writes to RO offsets are
--   ignored with OKAY. WSTRB is honoured per byte lane (audit 2026-11).
--
-- Cruces:
--   * CMD (audit 2026-11, fix B4): every CMD write increments a 4-bit Gray
--     GENERATION counter that crosses to the dp domain bit by bit (one bit
--     changes per command). The dp domain executes the command once per new
--     generation and returns the generation it has seen (Gray, 2FF back);
--     CMD_BUSY clears when the returned generation equals the current one.
--     If the dp domain does not confirm in 256 aclk (clk_dp stopped or in
--     reset) CMD_BUSY is released, STATUS.CMD_TIMEOUT is set and the command
--     is KILLED: the dp domain will not execute it later (before the fix the
--     pending toggle executed the stale command whenever clk_dp came back,
--     and a later command could cancel it in the toggle and be lost). While
--     in reset the dp domain adopts the current generation without
--     executing it; a later CMD supersedes a killed one.
--     Mientras el CMD anterior no se haya ejecutado (CMD_BUSY) no se acepta
--     NINGUNA escritura (awready retenido): ningun comando se pierde ni se
--     reordena y la configuracion no cambia mientras el dominio dp la
--     captura; the bus never hangs (timeout).
--   * AXI: B y R se activan el ciclo DESPUES del handshake de AW/W y AR.
--   * SNAP: toggle a dp, dp copia los contadores a una sombra estable y
--     devuelve un evento; el AXI lee la sombra directamente (estable).
--   * STATUS: doble FF por bit. IRQ: mac25g_evsync (sin perdida de eventos).
--   * Power-on (fix M6): optional por_n (async, active low) -> per-domain
--     mac25g_porsync; it resets the toggle / generation flops and holds the
--     functional resets for 4 clock edges after release (see mac25g_sync).
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
    rst_dp        : in  std_logic;

    -- chip power-on reset (ASIC), asynchronous, active low; '1' = FPGA
    por_n         : in  std_logic := '1'
  );
end entity mac25g_top;

architecture rtl of mac25g_top is
  constant ID_MAGIC : std_logic_vector(31 downto 0) := x"4D414320";

  function gray(b : unsigned(3 downto 0)) return std_logic_vector is
  begin
    return std_logic_vector(b xor ('0' & b(3 downto 1)));
  end function;

  -- byte-lane merge of a register write (WSTRB)
  function merge(old, d : std_logic_vector(31 downto 0); s : std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable r : std_logic_vector(31 downto 0) := old;
  begin
    for b in 0 to 3 loop
      if s(b) = '1' then r(8*b+7 downto 8*b) := d(8*b+7 downto 8*b); end if;
    end loop;
    return r;
  end function;

  signal rst_axi, rst_dp_i, por_axi, por_dp : std_logic;

  -- ---- dominio AXI ----
  signal awready_i, wready_i, bvalid_i, arready_i, rvalid_i : std_logic := '0';
  signal bresp_i, rresp_i : std_logic_vector(1 downto 0) := "00";
  signal rdata_i    : std_logic_vector(31 downto 0) := (others => '0');
  signal r_scratch  : std_logic_vector(31 downto 0) := (others => '0');
  signal r_ctrl     : std_logic_vector(4 downto 0) := (others => '0');
  signal r_cmd      : std_logic_vector(5 downto 0) := (others => '0');
  signal r_irq_st   : std_logic_vector(3 downto 0) := (others => '0');
  signal r_irq_en   : std_logic_vector(3 downto 0) := (others => '0');
  signal r_mac_lo, r_src_lo, r_count : std_logic_vector(31 downto 0) := (others => '0');
  signal r_mac_hi, r_src_hi : std_logic_vector(15 downto 0) := (others => '0');
  signal r_lmin, r_lmax, r_lstep : std_logic_vector(10 downto 0) := (others => '0');
  signal r_pctrl    : std_logic_vector(31 downto 0) := x"FFFF0000";
  signal r_wm       : std_logic_vector(31 downto 0) := x"01800080";   -- hi 384, lo 128
  signal r_swq      : std_logic_vector(15 downto 0) := (others => '0');
  signal p_snap, p_cmd, p_kill : std_logic := '0';
  signal snap_done  : std_logic := '0';
  signal cmd_busy   : std_logic := '0';
  signal cmd_tmo    : unsigned(7 downto 0) := (others => '0');
  signal cmd_err    : std_logic := '0';
  signal cmd_gen    : unsigned(3 downto 0) := (others => '0');
  signal cmd_gray   : std_logic_vector(3 downto 0) := (others => '0');
  signal cmd_kill   : std_logic := '0';
  signal ak1, ak2   : std_logic_vector(3 downto 0) := (others => '0');
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ak1, ak2 : signal is "TRUE";

  -- estado sincronizado a AXI
  signal a_link, a_busy, a_done, a_rx, a_tx, a_paused, a_xoff : std_logic;
  signal a_ev_done, a_ev_crc, a_ev_chk, a_ev_ll, a_snap_ack : std_logic;

  -- ---- dominio dp ----
  signal gs1, gs2   : std_logic_vector(3 downto 0) := (others => '0');
  attribute ASYNC_REG of gs1, gs2 : signal is "TRUE";
  signal last_g     : std_logic_vector(3 downto 0) := (others => '0');
  signal ack_p1, ack_p2, ack_p3, ack_g : std_logic_vector(3 downto 0) := (others => '0');
  signal d_kill     : std_logic;
  signal d_snap_stb : std_logic;
  -- strobes registrados y replicados: capturan 48+512 registros (CE)
  signal cmd_stb_r, snap_stb_r : std_logic := '0';
  signal c_ctrl     : std_logic_vector(4 downto 0) := (others => '0');
  signal c_mac, c_src : std_logic_vector(47 downto 0) := (others => '0');
  signal c_lmin, c_lmax, c_lstep : unsigned(10 downto 0) := (others => '0');
  signal c_count    : unsigned(31 downto 0) := (others => '0');
  signal c_cmd      : std_logic_vector(5 downto 0) := (others => '0');
  signal c_kill     : std_logic := '0';
  signal c_pctrl    : std_logic_vector(31 downto 0) := (others => '0');
  signal c_wm       : std_logic_vector(31 downto 0) := (others => '0');
  signal c_swq      : std_logic_vector(15 downto 0) := (others => '0');
  signal c_go       : std_logic := '0';
  signal dp_soft, dp_clr, dp_start, dp_stop, dp_inj, dp_pause : std_logic := '0';
  signal dp_rst     : std_logic := '1';
  signal st_link, st_busy, st_done, st_rx, st_tx, st_paused, st_xoff : std_logic;
  signal ev_done, ev_crc, ev_chk, ev_ll : std_logic;
  signal cnt_flat   : std_logic_vector(16*32-1 downto 0);
  signal cnt2_flat  : std_logic_vector(8*32-1 downto 0);
  signal shadow     : std_logic_vector(16*32-1 downto 0) := (others => '0');
  signal shadow2    : std_logic_vector(8*32-1 downto 0) := (others => '0');
  signal d_snap_ack : std_logic := '0';

  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of shadow : signal is "TRUE";
  attribute DONT_TOUCH of shadow2 : signal is "TRUE";
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of dp_rst : signal is 64;
  attribute MAX_FANOUT of cmd_stb_r : signal is 32;
  attribute MAX_FANOUT of snap_stb_r : signal is 32;
begin
  u_por_axi: entity work.mac25g_porsync port map (clk=>s_axi_aclk, por_n=>por_n, por=>por_axi);
  u_por_dp:  entity work.mac25g_porsync port map (clk=>clk_dp,     por_n=>por_n, por=>por_dp);
  rst_axi  <= (not s_axi_aresetn) or por_axi;
  rst_dp_i <= rst_dp or por_dp;

  -----------------------------------------------------------------------------
  -- AXI4-Lite: escritura (AW y W juntos), lectura
  -----------------------------------------------------------------------------
  process(s_axi_aclk)
    variable a  : std_logic_vector(7 downto 0);
    variable wd : std_logic_vector(31 downto 0);
    variable st : std_logic_vector(3 downto 0);
    variable ok : boolean;
  begin
    if rising_edge(s_axi_aclk) then
      p_snap <= '0'; p_cmd <= '0'; p_kill <= '0';
      awready_i <= '0'; wready_i <= '0';
      if rst_axi = '1' then
        bvalid_i <= '0'; bresp_i <= "00";
        r_scratch <= (others => '0'); r_ctrl <= (others => '0');
        r_cmd <= (others => '0'); r_irq_st <= (others => '0');
        r_irq_en <= (others => '0');
        r_mac_lo <= x"43414D02"; r_mac_hi <= x"2032";   -- 02:4D:41:43:32:20
        r_src_lo <= x"45474E02"; r_src_hi <= x"204E";   -- 02:4E:47:45:4E:20
        r_lmin <= std_logic_vector(to_unsigned(20, 11));
        r_lmax <= std_logic_vector(to_unsigned(1514, 11));
        r_lstep <= std_logic_vector(to_unsigned(37, 11));
        r_count <= std_logic_vector(to_unsigned(64, 32));
        r_pctrl <= x"FFFF0000"; r_wm <= x"01800080"; r_swq <= (others => '0');
        snap_done <= '0'; cmd_busy <= '0'; cmd_tmo <= (others => '0'); cmd_err <= '0';
      else
        -- stickies de IRQ (set por eventos sincronizados)
        if a_ev_done = '1' then r_irq_st(0) <= '1'; end if;
        if a_ev_crc  = '1' then r_irq_st(1) <= '1'; end if;
        if a_ev_chk  = '1' then r_irq_st(2) <= '1'; end if;
        if a_ev_ll   = '1' then r_irq_st(3) <= '1'; end if;
        if a_snap_ack = '1' then snap_done <= '1'; end if;
        -- CMD_BUSY: desde la escritura de CMD hasta que el dominio dp
        -- devuelve la misma generacion (y el estado ya refleja el comando)
        -- (p_cmd = 1: cmd_gray is updated on the next edge, do not compare)
        if cmd_busy = '1' and p_cmd = '0' and ak2 = cmd_gray then
          cmd_busy <= '0'; cmd_err <= '0';
        elsif cmd_busy = '1' then
          if cmd_tmo = 255 then cmd_busy <= '0'; cmd_err <= '1';
            p_kill <= '1';                         -- never executed later
          else cmd_tmo <= cmd_tmo + 1; end if;
        end if;
        -- respuesta B el ciclo siguiente al handshake AW/W
        if awready_i = '1' then bvalid_i <= '1'; end if;

        -- ninguna escritura se acepta mientras un CMD esta en vuelo (awready
        -- retenido): orden de comandos y estabilidad de la config en HW
        if s_axi_awvalid = '1' and s_axi_wvalid = '1' and bvalid_i = '0' and
           awready_i = '0' and cmd_busy = '0' then
          awready_i <= '1'; wready_i <= '1';
          a  := s_axi_awaddr;
          wd := s_axi_wdata;
          st := s_axi_wstrb;
          ok := a(1 downto 0) = "00";
          if not ok then
            null;                                                    -- unaligned
          else
          case a(7 downto 2) is
            when "000000" | "000100" => null;                         -- RO
            when "000001" => r_scratch <= merge(r_scratch, wd, st);
            when "000010" =>
              if st(0) = '1' then r_ctrl <= wd(4 downto 0); end if;
            when "000011" =>
              -- CMD: bits in byte lane 0; a write without lane 0 is a no-op
              if st(0) = '1' then
                r_cmd <= wd(5 downto 0);
                p_cmd <= '1'; cmd_busy <= '1'; cmd_tmo <= (others => '0');
              end if;
            when "000101" =>
              -- RW1C (un evento del mismo ciclo gana)
              for i in 0 to 3 loop
                if wd(i) = '1' and st(0) = '1' then r_irq_st(i) <= '0'; end if;
              end loop;
              if a_ev_done = '1' then r_irq_st(0) <= '1'; end if;
              if a_ev_crc  = '1' then r_irq_st(1) <= '1'; end if;
              if a_ev_chk  = '1' then r_irq_st(2) <= '1'; end if;
              if a_ev_ll   = '1' then r_irq_st(3) <= '1'; end if;
            when "000110" =>
              if st(0) = '1' then r_irq_en <= wd(3 downto 0); end if;
            when "000111" => p_snap <= '1'; snap_done <= '0';
            when "001000" => r_mac_lo <= merge(r_mac_lo, wd, st);
            when "001001" => r_mac_hi <= merge(x"0000" & r_mac_hi, wd, st)(15 downto 0);
            when "001010" => r_src_lo <= merge(r_src_lo, wd, st);
            when "001011" => r_src_hi <= merge(x"0000" & r_src_hi, wd, st)(15 downto 0);
            when "001100" =>
              wd := merge("00000" & r_lmax & "00000" & r_lmin, wd, st);
              r_lmin <= wd(10 downto 0); r_lmax <= wd(26 downto 16);
            when "001101" =>
              wd := merge(x"00000" & '0' & r_lstep, wd, st);
              r_lstep <= wd(10 downto 0);
            when "001110" => r_count <= merge(r_count, wd, st);
            when "001111" => r_pctrl <= merge(r_pctrl, wd, st);
            when "100000" => r_wm <= merge(r_wm, wd, st);
            when "100001" => r_swq <= merge(x"0000" & r_swq, wd, st)(15 downto 0);
            when others =>
              if a(7 downto 6) /= "01" and a(7 downto 5) /= "101" then
                ok := false;                                         -- unmapped
              end if;
          end case;
          end if;
          if ok then bresp_i <= "00"; else bresp_i <= "10"; end if;  -- SLVERR
        elsif bvalid_i = '1' and s_axi_bready = '1' then
          bvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

  -- generation counter flops: reset only at power-on (an AXI-only reset must
  -- not look like a new command to the dp domain). Gray: one bit per command.
  process(s_axi_aclk, por_axi)
  begin
    if por_axi = '1' then
      cmd_gen <= (others => '0'); cmd_gray <= (others => '0'); cmd_kill <= '0';
    elsif rising_edge(s_axi_aclk) then
      if p_cmd = '1' then
        cmd_gen <= cmd_gen + 1; cmd_gray <= gray(cmd_gen + 1); cmd_kill <= '0';
      elsif p_kill = '1' then
        cmd_kill <= '1';
      end if;
    end if;
  end process;

  process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      ak1 <= ack_g; ak2 <= ak1;                    -- dp -> AXI, Gray, no reset
    end if;
  end process;

  process(s_axi_aclk)
    variable a : std_logic_vector(7 downto 0);
    variable idx : natural range 0 to 15;
  begin
    if rising_edge(s_axi_aclk) then
      arready_i <= '0';
      if rst_axi = '1' then
        rvalid_i <= '0'; rdata_i <= (others => '0'); rresp_i <= "00";
      elsif arready_i = '1' then
        rvalid_i <= '1';                       -- R el ciclo siguiente a AR
      elsif s_axi_arvalid = '1' and rvalid_i = '0' then
        arready_i <= '1';
        a := s_axi_araddr;
        rresp_i <= "00";
        if a(1 downto 0) /= "00" then
          rdata_i <= (others => '0'); rresp_i <= "10";
        elsif a(7 downto 6) = "01" then
          idx := to_integer(unsigned(a(5 downto 2)));
          rdata_i <= shadow(32*idx+31 downto 32*idx);
        elsif a(7 downto 5) = "101" then
          idx := to_integer(unsigned(a(4 downto 2)));
          rdata_i <= shadow2(32*idx+31 downto 32*idx);
        else
          case a(7 downto 2) is
            when "000000" => rdata_i <= ID_MAGIC;
            when "000001" => rdata_i <= r_scratch;
            when "000010" => rdata_i <= x"000000" & "000" & r_ctrl;
            when "000011" | "000111" => rdata_i <= (others => '0');  -- WO
            when "000100" =>
              rdata_i <= (0 => a_link, 1 => a_busy or cmd_busy,
                          2 => a_done and not cmd_busy, 3 => a_rx,
                          4 => a_tx, 5 => a_paused, 6 => a_xoff,
                          8 => snap_done, 9 => cmd_busy,
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
            when "001111" => rdata_i <= r_pctrl;
            when "100000" => rdata_i <= r_wm;
            when "100001" => rdata_i <= x"0000" & r_swq;
            when others   => rdata_i <= (others => '0'); rresp_i <= "10";
          end case;
        end if;
      elsif rvalid_i = '1' and s_axi_rready = '1' then
        rvalid_i <= '0';
      end if;
    end if;
  end process;

  s_axi_awready <= awready_i;
  s_axi_wready  <= wready_i;
  s_axi_bresp   <= bresp_i;
  s_axi_bvalid  <= bvalid_i;
  s_axi_arready <= arready_i;
  s_axi_rdata   <= rdata_i;
  s_axi_rresp   <= rresp_i;
  s_axi_rvalid  <= rvalid_i;
  irq_out       <= '1' when (r_irq_st and r_irq_en) /= "0000" else '0';

  -----------------------------------------------------------------------------
  -- cruces AXI -> dp
  -----------------------------------------------------------------------------
  u_ls_kill: entity work.mac25g_lsync port map (clk_dst=>clk_dp, d=>cmd_kill, q=>d_kill);
  u_ps_snap: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_snap,
              clk_dst=>clk_dp, rst_dst=>rst_dp_i, pulse_out=>d_snap_stb,
              por_src=>por_axi);

  -- CMD generation: Gray bits synchronised one by one (one bit changes per
  -- command); a new generation = one command. In reset the dp domain adopts
  -- the generation without executing it and without acknowledging it.
  process(clk_dp, por_dp)
  begin
    if por_dp = '1' then
      last_g <= (others => '0'); ack_g <= (others => '0');
    elsif rising_edge(clk_dp) then
      cmd_stb_r <= '0';
      if rst_dp_i = '1' then
        last_g <= gs2;
      elsif gs2 /= last_g then
        last_g <= gs2;
        cmd_stb_r <= '1';
      end if;
      -- acknowledge 3 cycles after the detection: the generator has updated
      -- busy/done by then (it is the generation already executed)
      ack_p1 <= last_g; ack_p2 <= ack_p1; ack_p3 <= ack_p2;
      if rst_dp_i = '0' then ack_g <= ack_p3; end if;
    end if;
  end process;

  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      gs1 <= cmd_gray; gs2 <= gs1;                 -- AXI -> dp, no reset
    end if;
  end process;

  -- captura de configuracion + decodificacion de comandos (1 ciclo despues,
  -- para que la configuracion nueva ya este vigente cuando llega el pulso)
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      dp_soft <= '0'; dp_clr <= '0'; dp_start <= '0'; dp_stop <= '0'; dp_inj <= '0';
      dp_pause <= '0';
      if rst_dp_i = '1' then
        c_go <= '0'; c_ctrl <= (others => '0');
      else
        c_go <= cmd_stb_r;
        if cmd_stb_r = '1' then
          c_ctrl  <= r_ctrl;
          c_cmd   <= r_cmd;
          c_kill  <= d_kill;
          c_mac   <= r_mac_hi & r_mac_lo;
          c_src   <= r_src_hi & r_src_lo;
          c_lmin  <= unsigned(r_lmin);
          c_lmax  <= unsigned(r_lmax);
          c_lstep <= unsigned(r_lstep);
          c_count <= unsigned(r_count);
          c_pctrl <= r_pctrl;
          c_wm    <= r_wm;
          c_swq   <= r_swq;
        end if;
        if c_go = '1' and c_kill = '0' then
          dp_soft  <= c_cmd(0);
          dp_clr   <= c_cmd(1);
          dp_start <= c_cmd(2);
          dp_stop  <= c_cmd(3);
          dp_inj   <= c_cmd(4);
          dp_pause <= c_cmd(5);
        end if;
      end if;
    end if;
  end process;

  -- reset del datapath registrado (gran fanout: MAX_FANOUT replica)
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      dp_rst <= rst_dp_i or dp_soft;
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
      cnt_flat=>cnt_flat,
      pause_honor=>c_pctrl(0), pause_auto=>c_pctrl(1), pause_quanta=>c_pctrl(31 downto 16),
      rx_hi_wm=>unsigned(c_wm(31 downto 16)), rx_lo_wm=>unsigned(c_wm(15 downto 0)),
      pause_sw_req=>dp_pause, pause_sw_quanta=>c_swq,
      rx_tready=>not c_ctrl(4),
      st_paused=>st_paused, st_xoff=>st_xoff, cnt2_flat=>cnt2_flat);

  -- instantanea de contadores
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      d_snap_ack <= '0';
      snap_stb_r <= d_snap_stb;
      if snap_stb_r = '1' then
        shadow  <= cnt_flat;
        shadow2 <= cnt2_flat;
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
  u_ls5: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_paused, q=>a_paused);
  u_ls6: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>st_xoff, q=>a_xoff);

  u_ev0: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp_i, ev_in=>ev_done,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_done, por_src=>por_dp);
  u_ev1: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp_i, ev_in=>ev_crc,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_crc, por_src=>por_dp);
  u_ev2: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp_i, ev_in=>ev_chk,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_chk, por_src=>por_dp);
  u_ev3: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp_i, ev_in=>ev_ll,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_ev_ll, por_src=>por_dp);
  u_ev4: entity work.mac25g_evsync
    port map (clk_src=>clk_dp, rst_src=>rst_dp_i, ev_in=>d_snap_ack,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_snap_ack, por_src=>por_dp);

end architecture rtl;
