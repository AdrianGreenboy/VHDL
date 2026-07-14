-- ============================================================================
-- pcie_ts_gen.vhd -- PCIE IP v1
-- Generador de Ordered Sets de training. Cuando el LTSSM pide un TS
-- (send='1'), emite 16 simbolos hacia el scrambler:
--   sym0=COM, sym1=Link(PAD), sym2=Lane(PAD), sym3=N_FTS, sym4=Rate,
--   sym5=TrainCtl, sym6..15=TS_ID (0x4A TS1 / 0x45 TS2).
-- sym0: is_com='1' (reinit LFSR). sym1..15: bypass='1' (no scramble, el LFSR
-- avanza igual en el scrambler). Al terminar los 16 simbolos, pulsa done.
--
-- Si no hay TS en curso y send='0', emite IDLE (D00, is_k=0). El generador
-- captura los parametros al arrancar un TS y los mantiene hasta completarlo.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;
use work.pcie_8b10b_pkg.all;

entity pcie_ts_gen is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    en        : in  std_logic;

    send      : in  std_logic;                   -- pide emitir un TS
    ts_kind   : in  std_logic;                   -- 0=TS1, 1=TS2
    train_ctl : in  work.pcie_ltssm_pkg.byte_t;
    n_fts     : in  work.pcie_ltssm_pkg.byte_t;
    link_num  : in  work.pcie_ltssm_pkg.byte_t;                      -- PAD si no configurado
    lane_num  : in  work.pcie_ltssm_pkg.byte_t;
    done      : out std_logic;                   -- pulso al completar el TS
    active    : out std_logic;                   -- '1' mientras emite un TS

    -- hacia el scrambler
    sym       : out work.pcie_ltssm_pkg.byte_t;
    sym_k     : out std_logic;
    sym_com   : out std_logic;
    sym_skp   : out std_logic;
    sym_byp   : out std_logic
  );
end entity;

architecture rtl of pcie_ts_gen is
  signal cnt    : integer range 0 to TS_LEN := 0;
  signal busy   : std_logic := '0';
  signal kind_q : std_logic := '0';
  signal ctl_q  : work.pcie_ltssm_pkg.byte_t := (others => '0');
  signal nfts_q : work.pcie_ltssm_pkg.byte_t := (others => '0');
  signal lk_q   : work.pcie_ltssm_pkg.byte_t := (others => '0');
  signal ln_q   : work.pcie_ltssm_pkg.byte_t := (others => '0');
begin
  active <= busy;

  process(clk)
    variable idb : work.pcie_ltssm_pkg.byte_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt <= 0; busy <= '0'; done <= '0';
        sym <= (others => '0'); sym_k <= '0';
        sym_com <= '0'; sym_skp <= '0'; sym_byp <= '0';
      else
        done <= '0';
        if en = '1' then
          -- defaults
          sym <= x"00"; sym_k <= '0'; sym_com <= '0';
          sym_skp <= '0'; sym_byp <= '0';

          if busy = '0' then
            if send = '1' then
              -- arrancar TS: capturar parametros y emitir sym0=COM
              busy   <= '1';
              kind_q <= ts_kind;
              ctl_q  <= train_ctl;
              nfts_q <= n_fts;
              lk_q   <= link_num;
              ln_q   <= lane_num;
              sym <= K_COM; sym_k <= '1'; sym_com <= '1';
              cnt <= 1;
            else
              -- idle logico
              sym <= x"00"; sym_k <= '0';
            end if;
          else
            -- emitir sym1..15 scrambleados normalmente. El COM (sym0) reinicia
            -- el LFSR en TX y en RX (via is_com del deframer remoto), de modo
            -- que ambos LFSR quedan alineados y el descramble RX recupera los
            -- valores originales del TS. No se usa bypass (simetria TX/RX).
            case cnt is
              when 1 => sym <= lk_q;                       -- Link (PAD)
                        if lk_q = PAD_BYTE then sym_k <= '1'; end if;
              when 2 => sym <= ln_q;                       -- Lane (PAD)
                        if ln_q = PAD_BYTE then sym_k <= '1'; end if;
              when 3 => sym <= nfts_q;                     -- N_FTS
              when 4 => sym <= RATE_2G5;                   -- Rate
              when 5 => sym <= ctl_q;                      -- Training Control
              when others =>
                if kind_q = '0' then sym <= TS1_ID; else sym <= TS2_ID; end if;
            end case;
            -- PAD se envia como K23.7; para bypass el scrambler no toca el dato
            -- (el codec lo tratara como K si sym_k='1'). Aqui sym_byp evita XOR.
            if cnt = TS_LEN - 1 then
              done <= '1';
              busy <= '0';
              cnt  <= 0;
            else
              cnt <= cnt + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
