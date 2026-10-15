-- rv64_muldiv.vhd - unidad M iterativa, portable a ASIC (sin DSP).
--   Multiplicacion radix-4: 32 iteraciones (16 para MULW).
--   Division con restauracion radix-2: 64 iteraciones (32 para variantes W).
-- Protocolo: 'start' con la unidad libre captura operandos; 'done' se mantiene
-- con 'result' estable hasta 'ack'. 'kill' aborta en cualquier momento.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_muldiv is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    kill   : in  std_logic;
    ack    : in  std_logic;
    f3     : in  std_logic_vector(2 downto 0);
    is_w   : in  std_logic;
    a, b   : in  xword;
    busy   : out std_logic;
    done   : out std_logic;
    result : out xword
  );
end entity;

architecture rtl of rv64_muldiv is
  type st_t is (IDLE, MUL, DIV, FIN, HOLD);
  signal st      : st_t;
  signal cnt     : unsigned(6 downto 0);
  signal op_f3   : std_logic_vector(2 downto 0);
  signal op_w    : std_logic;
  signal neg_q   : std_logic;                     -- negar producto / cociente
  signal neg_r   : std_logic;                     -- negar resto
  signal ua      : unsigned(63 downto 0);         -- multiplicando / divisor
  signal ua3     : unsigned(65 downto 0);         -- 3*ua (radix-4)
  signal p       : unsigned(127 downto 0);        -- producto / {resto, cociente}
  signal rr      : unsigned(64 downto 0);         -- resto parcial
  signal dz      : std_logic;                     -- division por cero
  signal dz_val  : xword;
  signal res     : xword;
begin
  busy   <= '0' when st = IDLE else '1';
  done   <= '1' when st = HOLD else '0';
  result <= res;

  process (clk)
    variable sa, sb       : std_logic;
    variable av, bv       : xword;
    variable ma, mb       : unsigned(63 downto 0);
    variable add          : unsigned(65 downto 0);
    variable sum          : unsigned(65 downto 0);
    variable r2           : unsigned(64 downto 0);
    variable prod         : unsigned(127 downto 0);
    variable q, rem_v     : unsigned(63 downto 0);
    variable outv         : xword;
  begin
    if rising_edge(clk) then
      if rst = '1' or kill = '1' then
        st <= IDLE;
      else
        case st is
          when IDLE =>
            if start = '1' then
              op_f3 <= f3;
              op_w  <= is_w;
              if f3(2) = '0' then
                -- multiplicacion: signo segun la variante
                sa := '0'; sb := '0';
                if (f3 = "001" or f3 = "010") then sa := a(63); end if;  -- MULH, MULHSU
                if f3 = "001" then sb := b(63); end if;                    -- MULH
                ma := unsigned(a); mb := unsigned(b);
                if sa = '1' then ma := unsigned(-signed(a)); end if;
                if sb = '1' then mb := unsigned(-signed(b)); end if;
                neg_q <= sa xor sb;
                ua    <= ma;
                ua3   <= ('0' & ma & '0') + ("00" & ma);
                p     <= x"0000000000000000" & mb;
                if is_w = '1' then cnt <= to_unsigned(16, 7); else cnt <= to_unsigned(32, 7); end if;
                st <= MUL;
              else
                -- division: extension segun W y signo
                if is_w = '1' then
                  if f3(0) = '0' then av := sext(a(31 downto 0), 32); bv := sext(b(31 downto 0), 32);
                  else av := x"00000000" & a(31 downto 0); bv := x"00000000" & b(31 downto 0); end if;
                else
                  av := a; bv := b;
                end if;
                sa := av(63) and not f3(0);
                sb := bv(63) and not f3(0);
                ma := unsigned(av); mb := unsigned(bv);
                if sa = '1' then ma := unsigned(-signed(av)); end if;
                if sb = '1' then mb := unsigned(-signed(bv)); end if;
                neg_q <= sa xor sb;
                neg_r <= sa;
                ua    <= mb;                         -- divisor
                rr    <= (others => '0');
                if bv = XZERO then dz <= '1'; else dz <= '0'; end if;
                if f3(1) = '0' then dz_val <= (others => '1'); else dz_val <= av; end if;
                if is_w = '1' then
                  p   <= x"0000000000000000" & ma(31 downto 0) & x"00000000";
                  cnt <= to_unsigned(32, 7);
                else
                  p   <= x"0000000000000000" & ma;
                  cnt <= to_unsigned(64, 7);
                end if;
                st <= DIV;
              end if;
            end if;

          when MUL =>
            case p(1 downto 0) is
              when "00"   => add := (others => '0');
              when "01"   => add := "00" & ua;
              when "10"   => add := '0' & ua & '0';
              when others => add := ua3;
            end case;
            sum := ("00" & p(127 downto 64)) + add;
            p   <= sum & p(63 downto 2);
            cnt <= cnt - 1;
            if cnt = 1 then st <= FIN; end if;

          when DIV =>
            r2 := rr(63 downto 0) & p(63);
            if r2 >= ('0' & ua) then
              rr <= r2 - ('0' & ua);
              p(63 downto 0) <= p(62 downto 0) & '1';
            else
              rr <= r2;
              p(63 downto 0) <= p(62 downto 0) & '0';
            end if;
            cnt <= cnt - 1;
            if cnt = 1 then st <= FIN; end if;

          when FIN =>
            if op_f3(2) = '0' then
              prod := p;
              if neg_q = '1' then prod := unsigned(-signed(p)); end if;
              if op_w = '1' then
                outv := sext(std_logic_vector(p(63 downto 32)), 32);  -- MULW: 16 iteraciones
              elsif op_f3 = "000" then
                outv := std_logic_vector(prod(63 downto 0));
              else
                outv := std_logic_vector(prod(127 downto 64));
              end if;
            else
              q := p(63 downto 0); rem_v := rr(63 downto 0);
              if neg_q = '1' then q := unsigned(-signed(q)); end if;
              if neg_r = '1' then rem_v := unsigned(-signed(rem_v)); end if;
              if dz = '1' then outv := dz_val;
              elsif op_f3(1) = '0' then outv := std_logic_vector(q);
              else outv := std_logic_vector(rem_v); end if;
              if op_w = '1' then outv := sext(outv(31 downto 0), 32); end if;
            end if;
            res <= outv;
            st  <= HOLD;

          when HOLD =>
            if ack = '1' then st <= IDLE; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
