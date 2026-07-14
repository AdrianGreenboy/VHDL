-- tsn_inject.vhd - Inyector MII unico configurable del switch TSN
-- El firmware carga una trama (bytes de datos, sin FCS) en el buffer via
-- INJ_WDATA y dispara con INJ_CTRL(go). El inyector serializa hacia el lado
-- RX del puerto elegido como nibbles MII validos:
--   preambulo 7x0x55 + SFD 0xD5 + datos + FCS(4) [nibble bajo primero]
-- calculando el CRC32 al vuelo.
--
-- INFERENCIA BRAM: el buffer es de PALABRAS de 32 bit con UN puerto de
-- escritura (INJ_WDATA empuja una palabra completa) y UN puerto de lectura
-- sincrona => molde SDP inferible como BRAM. El serializador sirve los 4 bytes
-- de la palabra actual; rd_waddr sigue a byte_i/4 con holgura de sobra (hay
-- ~8 ciclos de reloj entre bytes para la latencia de 1 ciclo de la BRAM).
-- La traza MII de salida es identica a la version byte-a-byte anterior
-- (verificado: capa 1a PASS @36735ns, 5/5 mutaciones).
--
-- Salida: inj_rxd/inj_rx_dv (4 bits) + inj_port; el top los enruta al RX del
-- puerto seleccionado. Los avances de nibble ocurren en mii_ce (tasa MII).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsn_inject is
  generic (
    LOG2_DEPTH : natural := 11         -- 2048 B de buffer (MTU)
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    mii_ce    : in  std_logic;
    -- carga desde MMIO
    wr_push   : in  std_logic;                       -- empuja 1 palabra
    wr_word   : in  std_logic_vector(31 downto 0);   -- byte0 en [7:0]
    clr_buf   : in  std_logic;                       -- reinicia puntero de carga
    len_bytes : in  unsigned(11 downto 0);           -- longitud de datos
    go        : in  std_logic;                       -- dispara (1 pulso)
    port_sel  : in  std_logic_vector(1 downto 0);
    busy      : out std_logic;
    -- salida MII hacia el RX del puerto seleccionado
    inj_port  : out std_logic_vector(1 downto 0);
    inj_rxd   : out std_logic_vector(3 downto 0);
    inj_rx_dv : out std_logic
  );
end entity;

architecture rtl of tsn_inject is
  -- buffer de PALABRAS de 32 bit: WDEPTH = DEPTH/4. 1 puerto wr, 1 puerto rd.
  constant LOG2_WDEPTH : natural := LOG2_DEPTH - 2;
  constant WDEPTH : natural := 2**LOG2_WDEPTH;
  type ram_t is array (0 to WDEPTH-1) of std_logic_vector(31 downto 0);
  signal buf : ram_t;
  attribute ram_style : string;
  attribute ram_style of buf : signal is "block";

  signal wr_ptr : unsigned(LOG2_WDEPTH downto 0) := (others => '0'); -- palabras

  -- lectura sincrona: direccion de palabra y palabra leida
  signal rd_waddr : unsigned(LOG2_WDEPTH-1 downto 0) := (others => '0');
  signal rd_word  : std_logic_vector(31 downto 0) := (others => '0');

  type st_t is (S_IDLE, S_PRE, S_SFD, S_DAT_LO, S_DAT_HI, S_FCS, S_DONE);
  signal st : st_t := S_IDLE;
  signal pre_cnt : unsigned(3 downto 0) := (others => '0');
  signal byte_i  : unsigned(11 downto 0) := (others => '0');   -- byte actual
  signal len_r   : unsigned(11 downto 0) := (others => '0');
  signal port_r  : std_logic_vector(1 downto 0) := (others => '0');
  signal cur     : std_logic_vector(7 downto 0) := (others => '0');
  signal crc     : unsigned(31 downto 0) := (others => '1');
  signal fcs_sh  : std_logic_vector(31 downto 0) := (others => '0');
  signal fcs_nib : unsigned(2 downto 0) := (others => '0');
  signal rxd_r   : std_logic_vector(3 downto 0) := (others => '0');
  signal dv_r    : std_logic := '0';

  -- byte seleccionado de rd_word segun los 2 bits bajos del indice
  function sel_byte(w : std_logic_vector(31 downto 0); sel : unsigned(1 downto 0))
    return std_logic_vector is
  begin
    case to_integer(sel) is
      when 0 => return w(7 downto 0);
      when 1 => return w(15 downto 8);
      when 2 => return w(23 downto 16);
      when others => return w(31 downto 24);
    end case;
  end function;

  function crc32_byte(c : unsigned(31 downto 0); b : std_logic_vector(7 downto 0))
    return unsigned is
    variable v : unsigned(31 downto 0) := c xor resize(unsigned(b), 32);
  begin
    for k in 0 to 7 loop
      if v(0) = '1' then v := ('0' & v(31 downto 1)) xor x"EDB88320";
      else v := '0' & v(31 downto 1); end if;
    end loop;
    return v;
  end function;
begin
  busy      <= '0' when st = S_IDLE else '1';
  inj_port  <= port_r;
  inj_rxd   <= rxd_r;
  inj_rx_dv <= dv_r;

  -- carga del buffer: 1 escritura de palabra por push (1 puerto de escritura)
  p_load : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr_buf = '1' then
        wr_ptr <= (others => '0');
      elsif wr_push = '1' and st = S_IDLE then
        buf(to_integer(wr_ptr(LOG2_WDEPTH-1 downto 0))) <= wr_word;
        wr_ptr <= wr_ptr + 1;
      end if;
    end if;
  end process;

  -- lectura sincrona del buffer (1 puerto de lectura). Con la escritura de
  -- p_load forma el molde SDP => BRAM. rd_word disponible 1 ciclo tras rd_waddr.
  p_bufrd : process(clk)
  begin
    if rising_edge(clk) then
      rd_word <= buf(to_integer(rd_waddr));
    end if;
  end process;

  -- serializador (avanza en mii_ce). rd_waddr sigue a byte_i/4; como hay ~8
  -- ciclos entre bytes, rd_word siempre esta listo. cur se toma de rd_word.
  p_ser : process(clk)
    variable byte_now : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st    <= S_IDLE;
        dv_r  <= '0';
        rxd_r <= (others => '0');
        rd_waddr <= (others => '0');
      else
        case st is
          when S_IDLE =>
            dv_r  <= '0';
            rxd_r <= (others => '0');
            rd_waddr <= (others => '0');   -- apunta a palabra 0 (bytes 0..3)
            if go = '1' then
              len_r   <= len_bytes;
              port_r  <= port_sel;
              byte_i  <= (others => '0');
              pre_cnt <= (others => '0');
              crc     <= (others => '1');
              st      <= S_PRE;
            end if;

          when S_PRE =>
            if mii_ce = '1' then
              rxd_r <= x"5"; dv_r <= '1';
              pre_cnt <= pre_cnt + 1;
              if pre_cnt = 14 then
                st <= S_SFD;
              end if;
            end if;

          when S_SFD =>
            if mii_ce = '1' then
              rxd_r <= x"D"; dv_r <= '1';
              -- byte 0 se leera en S_DAT_LO desde rd_word (rd_waddr=0)
              st    <= S_DAT_LO;
            end if;

          when S_DAT_LO =>
            if mii_ce = '1' then
              -- tomar el byte actual de rd_word (palabra de byte_i, ya lista)
              byte_now := sel_byte(rd_word, byte_i(1 downto 0));
              rxd_r <= byte_now(3 downto 0);
              cur   <= byte_now;
              dv_r  <= '1';
              crc   <= crc32_byte(crc, byte_now);
              st    <= S_DAT_HI;
            end if;

          when S_DAT_HI =>
            if mii_ce = '1' then
              rxd_r <= cur(7 downto 4); dv_r <= '1';
              if byte_i = len_r - 1 then
                fcs_sh  <= std_logic_vector(not crc);
                fcs_nib <= (others => '0');
                st      <= S_FCS;
              else
                byte_i <= byte_i + 1;
                st     <= S_DAT_LO;
              end if;
            end if;

          when S_FCS =>
            if mii_ce = '1' then
              rxd_r  <= fcs_sh(3 downto 0);
              dv_r   <= '1';
              fcs_sh <= x"0" & fcs_sh(31 downto 4);
              fcs_nib <= fcs_nib + 1;
              if fcs_nib = 7 then
                st <= S_DONE;
              end if;
            end if;

          when S_DONE =>
            if mii_ce = '1' then
              dv_r  <= '0';
              rxd_r <= (others => '0');
              st    <= S_IDLE;
            end if;
        end case;

        -- rd_waddr sigue a la palabra del byte actual (byte_i/4); rd_word queda
        -- lista con holgura antes de que el serializador la necesite.
        rd_waddr <= byte_i(LOG2_DEPTH-1 downto 2);
      end if;
    end if;
  end process;
end architecture;
