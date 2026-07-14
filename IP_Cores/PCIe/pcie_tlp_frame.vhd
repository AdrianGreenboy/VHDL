-- ============================================================================
-- pcie_tlp_frame.vhd -- PCIE IP v1
-- Enmarcador de TLP directo, acoplado 1:1 con la DLL_TX. Resuelve el desajuste
-- de arranque del framer generico: aqui el handshake es simple y sin latencia
-- oculta. La DLL_TX pulsa 'start' un ciclo antes del primer byte, luego entrega
-- bytes con 'valid' y marca 'last' en el ultimo. Este bloque emite:
--   STP, <bytes...>, END   como simbolos (byte + is_k + is_com/is_skp/bypass).
-- Entre tramas emite IDLE (D00). Inserta un SKP OS (COM+3xSKP) cada
-- SKP_INTERVAL simbolos cuando esta en IDLE.
--
-- Handshake: 'ready' se ofrece cuando el enmarcador puede aceptar un byte
-- (estado F_PAY). La DLL_TX mantiene el byte hasta ver ready.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;

entity pcie_tlp_frame is
  generic (
    SKP_INTERVAL : integer := 600
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    en        : in  std_logic;

    start     : in  std_logic;                  -- pulso: abre TLP (STP)
    din       : in  byte_t;
    dvalid    : in  std_logic;
    dlast     : in  std_logic;
    dready    : out std_logic;

    sym       : out byte_t;
    sym_k     : out std_logic;
    sym_com   : out std_logic;
    sym_skp   : out std_logic;
    sym_byp   : out std_logic;
    busy      : out std_logic
  );
end entity;

architecture rtl of pcie_tlp_frame is
  type st_t is (F_IDLE, F_STP, F_PAY, F_END, F_GAP, F_SKP1, F_SKP2, F_SKP3);
  signal st : st_t := F_IDLE;
  signal skp_cnt : integer range 0 to 65535 := 0;
  signal pend : std_logic := '0';
  -- skid de entrada (registra din/dvalid/dlast 1 ciclo)
  signal sk_d : byte_t := (others=>'0');
  signal sk_v : std_logic := '0';
  signal sk_l : std_logic := '0';
begin
  busy   <= '0' when st = F_IDLE else '1';
  dready <= '1';   -- sin contrapresion

  process(clk)
  begin
    if rst='1' then
      st<=F_IDLE; skp_cnt<=0; pend<='0';
      sk_d<=(others=>'0'); sk_v<='0'; sk_l<='0';
      sym<=x"00"; sym_k<='0'; sym_com<='0'; sym_skp<='0'; sym_byp<='0';
    elsif rising_edge(clk) then
      if start='1' then pend<='1'; end if;

      -- skid: registra la entrada cada ciclo
      sk_d<=din; sk_v<=dvalid; sk_l<=dlast;

      if en='1' then
        sym<=x"00"; sym_k<='0'; sym_com<='0'; sym_skp<='0'; sym_byp<='0';
        if skp_cnt = SKP_INTERVAL-1 then skp_cnt<=0; else skp_cnt<=skp_cnt+1; end if;

        case st is
          when F_IDLE =>
            if skp_cnt = SKP_INTERVAL-1 then
              sym<=K_COM; sym_k<='1'; sym_com<='1'; st<=F_SKP1;
            elsif pend='1' then
              pend<='0';
              sym<=K_STP; sym_k<='1'; st<=F_PAY;
            else
              sym<=x"00"; sym_k<='0';
            end if;

          when F_STP =>
            st<=F_PAY;

          when F_PAY =>
            -- consume del skid (dato del ciclo anterior)
            if sk_v='1' then
              sym<=sk_d; sym_k<='0';
              if sk_l='1' then st<=F_END; end if;
            else
              sym<=x"00"; sym_k<='0';
            end if;

          when F_END =>
            sym<=K_END; sym_k<='1'; st<=F_GAP;

          when F_GAP =>
            -- inter-frame gap: un simbolo logico entre TLPs para que el
            -- deframer/adaptador del receptor cierre el TLP anterior antes de
            -- ver el STP del siguiente (evita el solape END->START que perdia
            -- el primer byte del segundo TLP en back-to-back).
            sym<=x"00"; sym_k<='0'; st<=F_IDLE;

          when F_SKP1 => sym<=K_SKP; sym_k<='1'; sym_skp<='1'; st<=F_SKP2;
          when F_SKP2 => sym<=K_SKP; sym_k<='1'; sym_skp<='1'; st<=F_SKP3;
          when F_SKP3 => sym<=K_SKP; sym_k<='1'; sym_skp<='1'; st<=F_IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture;
