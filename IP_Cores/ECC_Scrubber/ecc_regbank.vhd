-- ecc_regbank.vhd - Banco MMIO + inyector (Layer 3). Core 20 HERCOSSNUX.
-- Bus dmem simple: rdata COMBINACIONAL, valido el mismo ciclo que ready ('1').
-- Envuelve scrub_bram + scrub_fsm y anade el inyector de fallos por MMIO.
--
-- Secuencialidad (verificada contra mmio_oracle.py):
--   - inject inmediato: al escribir INJ_CTRL.arm con mode=1, una mini-FSM RCW
--     aplica el XOR a la palabra en INJ_ADDR. arm se auto-limpia al terminar.
--   - inject on-read: al escribir INJ_CTRL.arm con mode=0, se encola. Al escribir
--     CONTROL.scrub_en, PRIMERO se aplica la inyeccion pendiente (misma mini-FSM
--     RCW) y LUEGO arranca el barrido (start retenido en start_pending).
--   El escenario no solapa inyeccion y barrido, asi que el arbitraje de la BRAM
--   es trivial: el inyector la controla mientras inj_busy=1; la FSM el resto.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ecc_pkg.all;

entity ecc_regbank is
  generic (
    DEPTH    : natural := 32;
    INITFILE : string  := "layer3_init.txt"
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    sel   : in  std_logic;
    wr    : in  std_logic;
    addr  : in  std_logic_vector(15 downto 0);   -- ampliado: registros 0x00..0x40 + ventana datos 0x1000+
    wdata : in  std_logic_vector(31 downto 0);
    rdata : out std_logic_vector(31 downto 0);
    ready : out std_logic
  );
end entity;

architecture rtl of ecc_regbank is
  constant CORE_ID : std_logic_vector(31 downto 0) := x"5C520020";

  constant OFF_ID          : std_logic_vector(7 downto 0) := x"00";
  constant OFF_STATUS      : std_logic_vector(7 downto 0) := x"04";
  constant OFF_CONTROL     : std_logic_vector(7 downto 0) := x"08";
  constant OFF_REGION_BASE : std_logic_vector(7 downto 0) := x"0C";
  constant OFF_REGION_LEN  : std_logic_vector(7 downto 0) := x"10";
  constant OFF_PERIOD      : std_logic_vector(7 downto 0) := x"14";
  constant OFF_CE_COUNT    : std_logic_vector(7 downto 0) := x"18";
  constant OFF_DED_COUNT   : std_logic_vector(7 downto 0) := x"1C";
  constant OFF_FIRST_ADDR  : std_logic_vector(7 downto 0) := x"20";
  constant OFF_FIRST_SYN   : std_logic_vector(7 downto 0) := x"24";
  constant OFF_LAST_ADDR   : std_logic_vector(7 downto 0) := x"28";
  constant OFF_LAST_SYN    : std_logic_vector(7 downto 0) := x"2C";
  constant OFF_INJ_ADDR    : std_logic_vector(7 downto 0) := x"30";
  constant OFF_INJ_MASK_LO : std_logic_vector(7 downto 0) := x"34";
  constant OFF_INJ_MASK_HI : std_logic_vector(7 downto 0) := x"38";
  constant OFF_INJ_CTRL    : std_logic_vector(7 downto 0) := x"3C";
  constant OFF_SCRATCH     : std_logic_vector(7 downto 0) := x"40";

  signal region_base : unsigned(31 downto 0) := (others => '0');
  signal region_len  : unsigned(31 downto 0) := to_unsigned(DEPTH, 32);
  signal period      : unsigned(31 downto 0) := (others => '0');
  signal inj_addr    : unsigned(31 downto 0) := (others => '0');
  signal inj_mask_lo : std_logic_vector(31 downto 0) := (others => '0');
  signal inj_mask_hi : std_logic_vector(31 downto 0) := (others => '0');
  signal inj_ctrl    : std_logic_vector(31 downto 0) := (others => '0');
  signal scratch     : std_logic_vector(31 downto 0) := (others => '0');

  signal pend_valid  : std_logic := '0';
  signal pend_addr   : std_logic_vector(15 downto 0) := (others => '0');
  signal pend_mask   : ecc_t := (others => '0');

  signal b_we    : std_logic;
  signal b_waddr : std_logic_vector(15 downto 0);
  signal b_wdata : ecc_t;
  signal b_raddr : std_logic_vector(15 downto 0);
  signal b_rdata : ecc_t;

  signal f_start : std_logic := '0';
  signal f_we    : std_logic;
  signal f_waddr : std_logic_vector(15 downto 0);
  signal f_wdata : ecc_t;
  signal f_raddr : std_logic_vector(15 downto 0);
  signal f_busy, f_done : std_logic;
  signal f_ce, f_ded : std_logic_vector(31 downto 0);
  signal f_first_addr, f_last_addr : std_logic_vector(31 downto 0);
  signal f_first_syn, f_last_syn   : std_logic_vector(9 downto 0);

  type inj_state_t is (INJ_IDLE, INJ_READ, INJ_WAIT, INJ_WRITE);
  signal inj_state     : inj_state_t := INJ_IDLE;
  signal inj_go        : std_logic := '0';
  signal inj_busy      : std_logic := '0';
  signal inj_full_mask : ecc_t := (others => '0');
  signal inj_eff_addr  : std_logic_vector(15 downto 0) := (others => '0');
  signal inj_we        : std_logic := '0';
  signal inj_waddr     : std_logic_vector(15 downto 0) := (others => '0');
  signal inj_wdata     : ecc_t := (others => '0');
  signal inj_raddr     : std_logic_vector(15 downto 0) := (others => '0');

  signal start_pending : std_logic := '0';

  -- ventana de datos (0x1000+): lectura de la region palabra a palabra por el RV32.
  -- addr(12)='1' selecciona ventana; indice de palabra = addr(11 downto 3);
  -- addr(2)=0 -> LO (bits 31:0), addr(2)=1 -> HI (bits 38:32).
  -- La BRAM es sincrona (1 ciclo): FSM de ventana rearma por acceso.
  type win_state_t is (WS_IDLE, WS_WAIT, WS_CAP, WS_HOLD);
  signal win_state : win_state_t := WS_IDLE;
  signal win_sel   : std_logic;
  signal win_hi    : std_logic;
  signal win_wait  : std_logic;
  signal win_raddr : std_logic_vector(15 downto 0) := (others => '0');
  signal win_rdata : ecc_t := (others => '0');
  signal ready_i   : std_logic;

  function mask_of(lo, hi : std_logic_vector) return ecc_t is
    variable r : ecc_t := (others => '0');
  begin
    r(31 downto 0)  := lo;
    r(38 downto 32) := hi(6 downto 0);
    return r;
  end function;
begin

  bram : entity work.scrub_bram
    generic map (DEPTH => DEPTH, INITFILE => INITFILE)
    port map (clk => clk, we => b_we, waddr => b_waddr, wdata => b_wdata,
              raddr => b_raddr, rdata => b_rdata);

  fsm : entity work.scrub_fsm
    generic map (DEPTH => DEPTH)
    port map (clk => clk, rst => rst, start => f_start,
              we => f_we, waddr => f_waddr, wdata => f_wdata,
              raddr => f_raddr, rdata => b_rdata,
              busy => f_busy, done => f_done,
              ce_count => f_ce, ded_count => f_ded,
              first_addr => f_first_addr, first_syn => f_first_syn,
              last_addr => f_last_addr, last_syn => f_last_syn);

  win_sel <= '1' when (sel = '1' and addr(12) = '1') else '0';
  win_hi  <= addr(2);

  b_we    <= inj_we    when inj_busy = '1' else f_we;
  b_waddr <= inj_waddr when inj_busy = '1' else f_waddr;
  b_wdata <= inj_wdata when inj_busy = '1' else f_wdata;
  b_raddr <= inj_raddr when inj_busy = '1' else
             win_raddr when (win_state = WS_WAIT or win_state = WS_CAP) else
             f_raddr;

  wr_proc : process(clk)
  begin
    if rising_edge(clk) then
      inj_go  <= '0';
      f_start <= '0';
      if rst = '1' then
        region_base   <= (others => '0');
        region_len    <= to_unsigned(DEPTH, 32);
        period        <= (others => '0');
        inj_addr      <= (others => '0');
        inj_mask_lo   <= (others => '0');
        inj_mask_hi   <= (others => '0');
        inj_ctrl      <= (others => '0');
        scratch       <= (others => '0');
        pend_valid    <= '0';
        start_pending <= '0';
      else
        if sel = '1' and wr = '1' then
          case addr(7 downto 0) is
            when OFF_REGION_BASE => region_base <= unsigned(wdata);
            when OFF_REGION_LEN  => region_len  <= unsigned(wdata);
            when OFF_PERIOD      => period      <= unsigned(wdata);
            when OFF_INJ_ADDR    => inj_addr    <= unsigned(wdata);
            when OFF_INJ_MASK_LO => inj_mask_lo <= wdata;
            when OFF_INJ_MASK_HI => inj_mask_hi <= wdata;
            when OFF_SCRATCH     => scratch     <= wdata;
            when OFF_INJ_CTRL =>
              inj_ctrl <= wdata;
              if wdata(0) = '1' then
                if wdata(1) = '1' then
                  inj_go        <= '1';
                  inj_full_mask <= mask_of(inj_mask_lo, inj_mask_hi);
                  inj_eff_addr  <= std_logic_vector(inj_addr(15 downto 0));
                else
                  pend_valid <= '1';
                  pend_addr  <= std_logic_vector(inj_addr(15 downto 0));
                  pend_mask  <= mask_of(inj_mask_lo, inj_mask_hi);
                end if;
              end if;
            when OFF_CONTROL =>
              if wdata(0) = '1' then
                if pend_valid = '1' then
                  inj_go        <= '1';
                  inj_full_mask <= pend_mask;
                  inj_eff_addr  <= pend_addr;
                  start_pending <= '1';
                else
                  f_start <= '1';
                end if;
              end if;
            when others => null;
          end case;
        end if;

        if inj_state = INJ_WRITE then
          inj_ctrl(0) <= '0';
          pend_valid  <= '0';
          if start_pending = '1' then
            f_start       <= '1';
            start_pending <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  inj_proc : process(clk)
  begin
    if rising_edge(clk) then
      inj_we <= '0';
      if rst = '1' then
        inj_state <= INJ_IDLE;
        inj_busy  <= '0';
      else
        case inj_state is
          when INJ_IDLE =>
            if inj_go = '1' then
              inj_busy  <= '1';
              inj_raddr <= inj_eff_addr;
              inj_state <= INJ_READ;
            end if;
          when INJ_READ =>
            inj_state <= INJ_WAIT;
          when INJ_WAIT =>
            inj_wdata <= b_rdata xor inj_full_mask;
            inj_waddr <= inj_eff_addr;
            inj_we    <= '1';
            inj_state <= INJ_WRITE;
          when INJ_WRITE =>
            inj_busy  <= '0';
            inj_state <= INJ_IDLE;
        end case;
      end if;
    end if;
  end process;

  -- ventana de datos: FSM de 2 estados por acceso. Al detectar un acceso de
  -- ventana nuevo (win_sel y no en curso), captura la direccion y baja ready un
  -- ciclo (WS_WAIT); al siguiente ciclo la BRAM entrega el dato, lo registra y
  -- sube ready (WIN_DONE, 1 ciclo). Se rearma cuando win_sel se retira y vuelve.
  win_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        win_state <= WS_IDLE;
        win_rdata <= (others => '0');
      else
        case win_state is
          when WS_IDLE =>
            if win_sel = '1' and f_busy = '0' and inj_busy = '0' then
              win_raddr <= "0000000" & addr(11 downto 3);
              win_state <= WS_WAIT;
            end if;
          when WS_WAIT =>
            win_state <= WS_CAP;      -- la BRAM entregara mem(win_raddr) ahora
          when WS_CAP =>
            win_rdata <= b_rdata;      -- dato valido
            win_state <= WS_HOLD;
          when WS_HOLD =>
            -- espera a que el CPU retire el acceso antes de rearmar
            if win_sel = '0' then
              win_state <= WS_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  win_wait <= '1' when (win_state = WS_WAIT or win_state = WS_CAP) else '0';

  rd_proc : process(addr, region_base, region_len, period, inj_addr, inj_mask_lo,
                    inj_mask_hi, inj_ctrl, scratch, f_busy, f_done, f_ce, f_ded,
                    f_first_addr, f_first_syn, f_last_addr, f_last_syn,
                    win_sel, win_hi, win_rdata)
    variable v : std_logic_vector(31 downto 0);
  begin
    v := (others => '0');
    case addr(7 downto 0) is
      when OFF_ID          => v := CORE_ID;
      when OFF_STATUS =>
        v(0) := f_busy;
        v(1) := f_done;
        if unsigned(f_ded) /= 0 then v(2) := '1'; end if;
        if unsigned(f_ce)  /= 0 then v(3) := '1'; end if;
      when OFF_REGION_BASE => v := std_logic_vector(region_base);
      when OFF_REGION_LEN  => v := std_logic_vector(region_len);
      when OFF_PERIOD      => v := std_logic_vector(period);
      when OFF_CE_COUNT    => v := f_ce;
      when OFF_DED_COUNT   => v := f_ded;
      when OFF_FIRST_ADDR  => v := f_first_addr;
      when OFF_FIRST_SYN   => v(9 downto 0) := f_first_syn;
      when OFF_LAST_ADDR   => v := f_last_addr;
      when OFF_LAST_SYN    => v(9 downto 0) := f_last_syn;
      when OFF_INJ_ADDR    => v := std_logic_vector(inj_addr);
      when OFF_INJ_MASK_LO => v := inj_mask_lo;
      when OFF_INJ_MASK_HI => v := inj_mask_hi;
      when OFF_INJ_CTRL    => v := inj_ctrl;
      when OFF_SCRATCH     => v := scratch;
      when others          => v := (others => '0');
    end case;
    -- ventana de datos: sobrescribe con LO/HI de la palabra leida de la BRAM
    if win_sel = '1' then
      if win_hi = '1' then
        v := (others => '0');
        v(6 downto 0) := win_rdata(38 downto 32);  -- HI: bits 38..32
      else
        v := win_rdata(31 downto 0);               -- LO: bits 31..0
      end if;
    end if;
    rdata <= v;
  end process;

  -- ready baja mientras la ventana busca el dato; sube en WS_HOLD (dato listo).
  -- Accesos que no son de ventana: ready siempre '1'.
  ready_i <= '1' when win_sel = '0' else
             '1' when win_state = WS_HOLD else
             '0';
  ready <= ready_i;

end architecture;
