-- =============================================================
-- rv32_amo_unit.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 2
-- Extension A: lr.w / sc.w con un reservation bit (mono-hart)
-- y los 9 AMOs, como FSM read-modify-write sobre el handshake
-- de memoria single-beat (req/we/ready con wait states).
-- Contratos:
--  - addr siempre alineada a palabra (el control del core
--    genera trap de desalineado antes de llegar aqui)
--  - res_clear (store normal o trap) no coincide en el mismo
--    ciclo con un lr.w completando (lo garantiza el control)
--  - la reserva se invalida conservadoramente por sc.w (siempre)
--    y por cualquier AMO (legal segun WARL de la spec RISC-V)
-- funct5 (instr[31:27]): lr=00010 sc=00011 amoswap=00001
-- amoadd=00000 amoxor=00100 amoand=01100 amoor=01000
-- amomin=10000 amomax=10100 amominu=11000 amomaxu=11100
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_amo_unit is
  port (
    clk       : in  std_logic;
    clk_en    : in  std_logic := '1';  -- gating: '0' congela la FSM (espera NoC)
    rstn      : in  std_logic;
    -- interfaz de instruccion
    start     : in  std_logic;  -- pulso 1 ciclo, solo con busy=0
    funct5    : in  std_logic_vector(4 downto 0);
    addr      : in  std_logic_vector(31 downto 0);
    src       : in  std_logic_vector(31 downto 0);  -- rs2
    res_clear : in  std_logic;  -- rompe la reserva (store/trap)
    busy      : out std_logic;
    done      : out std_logic;  -- pulso 1 ciclo
    result    : out std_logic_vector(31 downto 0); -- rd
    -- interfaz de memoria single-beat
    m_req     : out std_logic;
    m_we      : out std_logic;
    m_addr    : out std_logic_vector(31 downto 0);
    m_wdata   : out std_logic_vector(31 downto 0);
    m_rdata   : in  std_logic_vector(31 downto 0);
    m_ready   : in  std_logic
  );
end entity;

architecture rtl of rv32_amo_unit is

  constant F5_LR : std_logic_vector(4 downto 0) := "00010";
  constant F5_SC : std_logic_vector(4 downto 0) := "00011";

  type t_st is (ST_IDLE, ST_RD, ST_WR, ST_FIN);
  signal st : t_st;

  signal r_f5     : std_logic_vector(4 downto 0);
  signal r_addr   : std_logic_vector(31 downto 0);
  signal r_src    : std_logic_vector(31 downto 0);
  signal r_new    : std_logic_vector(31 downto 0);
  signal r_result : std_logic_vector(31 downto 0);
  signal r_done   : std_logic;
  signal r_res_valid : std_logic;
  signal r_res_addr  : std_logic_vector(31 downto 0);

  function f_amo(f5 : std_logic_vector(4 downto 0);
                 oldv, srcv : std_logic_vector(31 downto 0))
                 return std_logic_vector is
  begin
    case f5 is
      when "00001" => return srcv; -- MUT3
      when "00000" =>
        return std_logic_vector(unsigned(oldv) + unsigned(srcv));
      when "00100" => return oldv xor srcv;
      when "01100" => return oldv and srcv;
      when "01000" => return oldv or srcv;
      when "10000" =>  -- amomin.w
        if signed(oldv) < signed(srcv) then -- MUT1
          return oldv;
        else
          return srcv;
        end if;
      when "10100" =>  -- amomax.w
        if signed(oldv) > signed(srcv) then
          return oldv;
        else
          return srcv;
        end if;
      when "11000" =>  -- amominu.w
        if unsigned(oldv) < unsigned(srcv) then
          return oldv;
        else
          return srcv;
        end if;
      when others =>   -- amomaxu.w
        if unsigned(oldv) > unsigned(srcv) then
          return oldv;
        else
          return srcv;
        end if;
    end case;
  end function;

begin

  busy   <= '0' when st = ST_IDLE else '1';
  done   <= r_done;
  result <= r_result;

  m_req   <= '1' when (st = ST_RD) or (st = ST_WR) else '0';
  m_we    <= '1' when st = ST_WR else '0';
  m_addr  <= r_addr;
  m_wdata <= r_new;

  process(clk, rstn)
  begin
    if rstn = '0' then
      st <= ST_IDLE;
      r_f5 <= (others => '0');
      r_addr <= (others => '0');
      r_src <= (others => '0');
      r_new <= (others => '0');
      r_result <= (others => '0');
      r_done <= '0';
      r_res_valid <= '0';
      r_res_addr <= (others => '0');
    elsif rising_edge(clk) then
     if clk_en = '1' then
      r_done <= '0';
      if res_clear = '1' then
        r_res_valid <= '0';
      end if;
      case st is

        when ST_IDLE =>
          if start = '1' then
            r_f5   <= funct5;
            r_addr <= addr;
            r_src  <= src;
            if funct5 = F5_SC then
              if (r_res_valid = '1') and (r_res_addr = addr) then -- MUT2
                r_new    <= src;
                r_result <= x"00000000";
                st <= ST_WR;
              else
                r_result <= x"00000001";
                st <= ST_FIN;
              end if;
              r_res_valid <= '0';  -- sc siempre consume la reserva
            else
              st <= ST_RD;
            end if;
          end if;

        when ST_RD =>
          if m_ready = '1' then
            if r_f5 = F5_LR then
              r_result    <= m_rdata;
              r_res_valid <= '1';
              r_res_addr  <= r_addr;
              st <= ST_FIN;
            else
              r_result <= m_rdata; -- MUT4
              r_new    <= f_amo(r_f5, m_rdata, r_src);
              st <= ST_WR;
            end if;
          end if;

        when ST_WR =>
          if m_ready = '1' then
            if r_f5 /= F5_SC then
              r_res_valid <= '0'; -- MUT5
            end if;
            st <= ST_FIN;
          end if;

        when ST_FIN =>
          r_done <= '1';
          st <= ST_IDLE;

      end case;
     end if;  -- clk_en
    end if;
  end process;

end architecture;
