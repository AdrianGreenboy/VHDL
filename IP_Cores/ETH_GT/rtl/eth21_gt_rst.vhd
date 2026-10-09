-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Secuencia de reset del canal GTYP (Versal, gt_quad_base con
-- MASTER_RESET_EN), en el reloj libre aclk. Una parte comun (alimentacion y
-- PLL) y dos pistas INDEPENDIENTES para TX y RX: un receptor que no termina
-- (sin cable, sin senal, CDR sin lock) NO reinicia el transmisor ni el PLL.
--
-- Comun:
--   C_PG     todo en reset; espera gtpowergood
--   C_PLLRST mantiene hsclk0_lcpllreset T_PLLRST
--   C_PLLWT  espera hsclk0_lcplllock (timeout -> C_PG)
--   C_RUN    PLL en servicio; si cae el lock o gtpowergood -> C_PG (todo)
-- Por pista (TX y RX, solo en C_RUN):
--   P_RST   mantiene ch0_*mstreset T_RSTP
--   P_CLK   espera a que el reloj de usuario corra (*_alive, del medidor de
--           reloj); timeout -> P_RST
--   P_USR   T_USR despues sube *userrdy
--   P_DONE  espera *mstresetdone (timeout -> P_RST)
--   P_OK    *_ready = 1; si *mstresetdone cae -> P_RST
-- restart (CMD.GT_RESET) reinicia todo. Con 'manual' = 1 las salidas las
-- fija GT_CTRL (depuracion en silicio) y las FSM se detienen.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth21_gt_rst is
  generic (
    ACLK_HZ : natural := 100_000_000
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    restart      : in  std_logic;
    manual       : in  std_logic;
    man_pllrst   : in  std_logic;
    man_txmst    : in  std_logic;
    man_rxmst    : in  std_logic;
    man_txusr    : in  std_logic;
    man_rxusr    : in  std_logic;

    gtpowergood  : in  std_logic;
    lcplllock    : in  std_logic;
    txmstdone    : in  std_logic;
    rxmstdone    : in  std_logic;
    tx_alive     : in  std_logic;    -- ya en el dominio clk
    rx_alive     : in  std_logic;

    lcpllreset   : out std_logic;
    txmstreset   : out std_logic;
    rxmstreset   : out std_logic;
    txuserrdy    : out std_logic;
    rxuserrdy    : out std_logic;
    tx_ready     : out std_logic;
    rx_ready     : out std_logic;
    -- state(1:0) parte comun (0 PG, 1 PLLRST, 2 PLLWT, 3 RUN);
    -- state(2) pista TX en OK; state(3) pista RX en OK
    state        : out std_logic_vector(3 downto 0);
    s_pg, s_lock, s_txd, s_rxd : out std_logic
  );
end entity eth21_gt_rst;

architecture rtl of eth21_gt_rst is
  constant T_PLLRST : natural := ACLK_HZ / 100_000;   -- 10 us
  constant T_USR    : natural := ACLK_HZ / 100_000;   -- 10 us
  constant T_RSTP   : natural := ACLK_HZ / 100_000;   -- 10 us
  constant T_TMO    : natural := ACLK_HZ / 100;       -- 10 ms
  type c_t is (C_PG, C_PLLRST, C_PLLWT, C_RUN);
  type p_t is (P_RST, P_CLK, P_USR, P_DONE, P_OK);
  signal cs : c_t := C_PG;
  signal ccnt : unsigned(31 downto 0) := (others => '0');
  signal pg1, pg2, lk1, lk2, td1, td2, rd1, rd2 : std_logic := '0';
  signal o_pll : std_logic := '1';

  -- pista generica: un registro de estado + contador por direccion
  type trk_t is record
    st   : p_t;
    cnt  : unsigned(31 downto 0);
    mst  : std_logic;
    usr  : std_logic;
    rdy  : std_logic;
  end record;
  constant TRK_RST : trk_t := (st => P_RST, cnt => to_unsigned(T_RSTP, 32),
                               mst => '1', usr => '0', rdy => '0');
  signal tx, rx : trk_t := TRK_RST;
  signal txr_r, rxr_r : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of pg1, pg2, lk1, lk2, td1, td2, rd1, rd2 : signal is "TRUE";

  function step(t : trk_t; alive, done : std_logic) return trk_t is
    variable n : trk_t := t;
  begin
    case t.st is
      when P_RST =>
        n.mst := '1'; n.usr := '0'; n.rdy := '0';
        if t.cnt = 0 then
          n.mst := '0'; n.st := P_CLK; n.cnt := to_unsigned(T_TMO, 32);
        else
          n.cnt := t.cnt - 1;
        end if;
      when P_CLK =>
        if alive = '1' then
          n.st := P_USR; n.cnt := to_unsigned(T_USR, 32);
        elsif t.cnt = 0 then
          n := TRK_RST;
        else
          n.cnt := t.cnt - 1;
        end if;
      when P_USR =>
        if t.cnt = 0 then
          n.usr := '1'; n.st := P_DONE; n.cnt := to_unsigned(T_TMO, 32);
        else
          n.cnt := t.cnt - 1;
        end if;
      when P_DONE =>
        if done = '1' then
          n.rdy := '1'; n.st := P_OK;
        elsif t.cnt = 0 then
          n := TRK_RST;
        else
          n.cnt := t.cnt - 1;
        end if;
      when P_OK =>
        if done = '0' or alive = '0' then
          n := TRK_RST;
        end if;
    end case;
    return n;
  end function;
begin

  process(clk)
  begin
    if rising_edge(clk) then
      pg1 <= gtpowergood; pg2 <= pg1;
      lk1 <= lcplllock;   lk2 <= lk1;
      td1 <= txmstdone;   td2 <= td1;
      rd1 <= rxmstdone;   rd2 <= rd1;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or restart = '1' then
        cs <= C_PG; ccnt <= (others => '0'); o_pll <= '1';
        tx <= TRK_RST; rx <= TRK_RST;
      elsif manual = '0' then
        case cs is
          when C_PG =>
            o_pll <= '1'; tx <= TRK_RST; rx <= TRK_RST;
            if pg2 = '1' then
              ccnt <= to_unsigned(T_PLLRST, 32); cs <= C_PLLRST;
            end if;
          when C_PLLRST =>
            if ccnt = 0 then
              o_pll <= '0'; ccnt <= to_unsigned(T_TMO, 32); cs <= C_PLLWT;
            else
              ccnt <= ccnt - 1;
            end if;
          when C_PLLWT =>
            if lk2 = '1' then
              cs <= C_RUN;
            elsif ccnt = 0 then
              cs <= C_PG;
            else
              ccnt <= ccnt - 1;
            end if;
          when C_RUN =>
            if lk2 = '0' or pg2 = '0' then
              cs <= C_PG; o_pll <= '1'; tx <= TRK_RST; rx <= TRK_RST;
            else
              tx <= step(tx, tx_alive, td2);
              rx <= step(rx, rx_alive, rd2);
            end if;
        end case;
      end if;
    end if;
  end process;

  -- salidas (ready registrados tambien en modo manual: alimentan resets)
  process(clk)
  begin
    if rising_edge(clk) then
      if manual = '1' then
        txr_r <= td2 and man_txusr and tx_alive;
        rxr_r <= rd2 and man_rxusr and rx_alive;
      else
        txr_r <= tx.rdy;
        rxr_r <= rx.rdy;
      end if;
    end if;
  end process;

  lcpllreset <= man_pllrst when manual = '1' else o_pll;
  txmstreset <= man_txmst  when manual = '1' else tx.mst;
  rxmstreset <= man_rxmst  when manual = '1' else rx.mst;
  txuserrdy  <= man_txusr  when manual = '1' else tx.usr;
  rxuserrdy  <= man_rxusr  when manual = '1' else rx.usr;
  tx_ready   <= txr_r;
  rx_ready   <= rxr_r;

  with cs select state(1 downto 0) <=
    "00" when C_PG, "01" when C_PLLRST, "10" when C_PLLWT, "11" when C_RUN;
  state(2) <= '1' when tx.st = P_OK else '0';
  state(3) <= '1' when rx.st = P_OK else '0';

  s_pg <= pg2; s_lock <= lk2; s_txd <= td2; s_rxd <= rd2;

end architecture rtl;
