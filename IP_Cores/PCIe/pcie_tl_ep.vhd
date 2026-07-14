-- ============================================================================
-- pcie_tl_ep.vhd -- PCIE IP v1
-- Transaction Layer, lado Endpoint (completer). Recibe TLPs deframados por
-- bytes (stream con start/last), los parsea y ejecuta:
--   * MWr3      : escribe 'length' DW en BAR0 (BRAM interna) desde addr.
--   * MRd3      : lee 'length' DW de BAR0 y genera un CplD de vuelta.
--   * CfgWr0    : escribe en config space (offset de registro).
--   * CfgRd0    : lee config space y genera CplD.
--   * (MSI)     : cuando se activa msi_trigger, emite un MWr3 a la direccion
--                 MSI programada con el dato MSI (interrupcion).
--
-- Salidas: un stream de TLP de respuesta (Cpl/CplD/MSI) hacia la DLL TX del
-- propio nodo (tx_*), y acceso de escritura/lectura al BAR0.
--
-- Config space Type 0 (subset): 0x00 Vendor/Device, 0x08 Class/Rev,
--   0x10 BAR0, 0x3C IntLine, MSI cap en 0x50 (addr) / 0x54 (data).
--
-- Formato de TLP entrante/saliente (bytes big-endian, sin seq ni LCRC: eso lo
-- gestiona la DLL). Header 3DW = 12 bytes, luego payload en DW.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_tl_pkg.all;

entity pcie_tl_ep is
  generic (
    BAR0_WORDS : integer := 256    -- tamano de BAR0 en DW (BRAM)
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    -- TLP entrante (desde DLL RX, deframado por bytes)
    rx_valid   : in  std_logic;
    rx_data    : in  byte_t;
    rx_start   : in  std_logic;
    rx_last    : in  std_logic;

    -- TLP de respuesta (hacia DLL TX)
    tx_valid   : out std_logic;
    tx_data    : out byte_t;
    tx_start   : out std_logic;
    tx_last    : out std_logic;
    tx_ready   : in  std_logic;

    -- disparo de MSI (interrupcion del EP hacia el RC)
    msi_trigger: in  std_logic;

    -- monitor
    bar0_dbg   : out dw_t;          -- ultimo DW escrito en BAR0
    cfg_done   : out std_logic;     -- pulso al completar un acceso cfg
    mwr_cnt_o  : out std_logic_vector(15 downto 0);
    mrd_cnt_o  : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of pcie_tl_ep is
  -- BAR0 BRAM (SDP)
  type bar_t is array (0 to BAR0_WORDS-1) of dw_t;
  signal bar0 : bar_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of bar0 : signal is "block";

  -- config space (16 DW = 64 bytes minimo)
  type cfg_t is array (0 to 31) of dw_t;
  signal cfg : cfg_t := (others => (others => '0'));

  type rstate_t is (S_HDR, S_WDATA, S_EXEC, S_CPL_HDR, S_CPL_DATA, S_MSI);
  signal st : rstate_t := S_HDR;

  -- buffer de header entrante (hasta 3 DW = 12 bytes)
  signal hb : std_logic_vector(0 to 11*8-1) := (others => '0'); -- no usado directo
  type hbytes_t is array (0 to 15) of byte_t;
  signal hbuf : hbytes_t := (others => (others=>'0'));
  signal hcnt : integer range 0 to 16 := 0;

  signal kind     : tlp_kind_t := TK_UNKNOWN;
  signal len_dw   : integer range 0 to 1023 := 0;
  signal addr     : unsigned(31 downto 0) := (others=>'0');
  signal reqid    : std_logic_vector(15 downto 0) := (others=>'0');
  signal tag      : byte_t := (others=>'0');

  signal wr_idx   : integer range 0 to BAR0_WORDS := 0;
  signal wr_word  : dw_t := (others=>'0');
  signal wr_bpos  : integer range 0 to 4 := 0;

  signal rd_idx   : integer range 0 to BAR0_WORDS := 0;
  signal cpl_i    : integer range 0 to 16 := 0;
  signal cpl_data : dw_t := (others=>'0');
  signal is_cfg   : boolean := false;

  signal mwr_cnt  : unsigned(15 downto 0) := (others=>'0');
  signal mrd_cnt  : unsigned(15 downto 0) := (others=>'0');

  -- respuesta: buffer de TLP de salida (header 3DW + 1DW data max en v1)
  type obuf_t is array (0 to 15) of byte_t;
  signal obuf : obuf_t := (others => (others=>'0'));
  signal olen : integer range 0 to 16 := 0;
  signal oi   : integer range 0 to 16 := 0;

  constant CPL_REQID : std_logic_vector(15 downto 0) := x"0100"; -- ID del EP
begin

  mwr_cnt_o <= std_logic_vector(mwr_cnt);
  mrd_cnt_o <= std_logic_vector(mrd_cnt);

  -- ============== salidas TX combinacionales ==============
  -- tx_data/tx_valid/tx_start/tx_last se derivan COMBINACIONALMENTE del estado y
  -- del puntero oi. Esto es clave: con salida registrada, al avanzar oi el nuevo
  -- byte no aparecia hasta el ciclo siguiente y la DLL consumia el byte viejo
  -- otra vez (duplicacion). Salida combinacional -> cada byte se presenta una
  -- sola vez, sincronizado con el avance de oi.
  comb_tx : process(st, oi, obuf, cpl_data)
  begin
    tx_valid <= '0'; tx_data <= (others=>'0');
    tx_start <= '0'; tx_last <= '0';
    case st is
      when S_CPL_HDR =>
        tx_valid <= '1';
        tx_data  <= obuf(oi);
        if oi = 0 then tx_start <= '1'; end if;
      when S_CPL_DATA =>
        tx_valid <= '1';
        case oi is
          when 0 => tx_data <= cpl_data(31 downto 24);
          when 1 => tx_data <= cpl_data(23 downto 16);
          when 2 => tx_data <= cpl_data(15 downto 8);
          when others => tx_data <= cpl_data(7 downto 0);
        end case;
        if oi = 3 then tx_last <= '1'; end if;
      when others =>
        tx_valid <= '0';
    end case;
  end process;

  process(clk)
    variable b0 : byte_t;
    variable a  : integer;
    variable vlen : std_logic_vector(9 downto 0);
    variable vaddr : std_logic_vector(31 downto 0);
    variable vword : dw_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= S_HDR; hcnt <= 0; len_dw <= 0; wr_idx <= 0; wr_bpos <= 0;
        cpl_i <= 0; olen <= 0; oi <= 0;
        mwr_cnt <= (others=>'0'); mrd_cnt <= (others=>'0');
        cfg_done <= '0'; bar0_dbg <= (others=>'0');
        -- inicializar config space
        cfg(0) <= CFG_DEVICE_ID & CFG_VENDOR_ID;   -- 0x00
        cfg(2) <= CFG_CLASS;                        -- 0x08
        cfg(4) <= (others=>'0');                    -- 0x10 BAR0 (base 0)
      else
        cfg_done <= '0';

        case st is
          -- =============== recepcion de header ===============
          when S_HDR =>
            if rx_valid = '1' then
              if rx_start = '1' then
                hbuf(0) <= rx_data; hcnt <= 1;
              else
                if hcnt < 16 then hbuf(hcnt) <= rx_data; end if;
                hcnt <= hcnt + 1;
              end if;

              -- header 3DW = 12 bytes. Al recibir el byte 11 (idx 11) lo tenemos
              if hcnt = 11 then
                b0 := hbuf(0);
                vlen  := hbuf(2)(1 downto 0) & hbuf(3);
                vaddr := hbuf(8) & hbuf(9) & hbuf(10) & rx_data;
                kind   <= f_kind(b0);
                len_dw <= to_integer(unsigned(vlen));
                reqid  <= hbuf(4) & hbuf(5);
                tag    <= hbuf(6);
                addr   <= unsigned(vaddr);
                is_cfg <= (f_kind(b0) = TK_CFGRD0) or (f_kind(b0) = TK_CFGWR0);

                case f_kind(b0) is
                  when TK_MWR3 =>
                    -- decode de BAR0: dentro de rango si los bits por encima de
                    -- la ventana BAR0 son cero. Se comprueba con los bits de
                    -- direccion directamente para NO convertir toda vaddr a
                    -- integer (0xFEED0000 excede integer'high y desbordaria).
                    if unsigned(vaddr(31 downto 10)) = 0 then
                      wr_idx  <= to_integer(unsigned(vaddr(9 downto 2)));
                      wr_bpos <= 0;
                      st <= S_WDATA;
                    else
                      st <= S_HDR; hcnt <= 0;   -- fuera de BAR0: ignorar
                    end if;
                  when TK_CFGWR0 =>
                    wr_bpos <= 0;
                    st <= S_WDATA;
                  when TK_MRD3 =>
                    if unsigned(vaddr(31 downto 10)) = 0 then
                      mrd_cnt <= mrd_cnt + 1;
                      rd_idx <= to_integer(unsigned(vaddr(9 downto 2)));
                      st <= S_EXEC;
                    else
                      st <= S_HDR; hcnt <= 0;   -- fuera de BAR0: ignorar
                    end if;
                  when TK_CFGRD0 =>
                    st <= S_EXEC;
                  when others =>
                    st <= S_HDR; hcnt <= 0;
                end case;
              end if;
            end if;

          -- =============== datos de escritura ===============
          when S_WDATA =>
            if rx_valid = '1' then
              -- ensamblar DW big-endian
              case wr_bpos is
                when 0 => wr_word(31 downto 24) <= rx_data; wr_bpos <= 1;
                when 1 => wr_word(23 downto 16) <= rx_data; wr_bpos <= 2;
                when 2 => wr_word(15 downto 8)  <= rx_data; wr_bpos <= 3;
                when others =>
                  wr_word(7 downto 0) <= rx_data; wr_bpos <= 0;
                  -- DW completo: escribir
                  vword := wr_word(31 downto 8) & rx_data;
                  if is_cfg then
                    a := to_integer(addr(6 downto 2));  -- offset DW en cfg
                    cfg(a) <= vword;
                    cfg_done <= '1';
                  else
                    bar0(wr_idx) <= vword;
                    bar0_dbg <= vword;
                    wr_idx <= wr_idx + 1;
                    mwr_cnt <= mwr_cnt + 1;
                  end if;
                  if rx_last = '1' then
                    st <= S_HDR; hcnt <= 0;
                  end if;
              end case;
              if rx_last = '1' and wr_bpos /= 3 then
                -- payload termino en medio de un DW (no deberia en v1 alineado)
                st <= S_HDR; hcnt <= 0;
              end if;
            end if;

          -- =============== ejecucion de lectura -> Cpl ===============
          when S_EXEC =>
            if is_cfg then
              a := to_integer(addr(6 downto 2));
              cpl_data <= cfg(a);
              cfg_done <= '1';
            else
              cpl_data <= bar0(rd_idx);
            end if;
            -- construir CplD (3DW header + 1DW data)
            obuf(0) <= B0_CPLD;                     -- Fmt/Type CplD
            obuf(1) <= x"00";
            obuf(2) <= x"00"; obuf(3) <= x"01";     -- length = 1 DW
            obuf(4) <= CPL_REQID(15 downto 8); obuf(5) <= CPL_REQID(7 downto 0);
            obuf(6) <= x"04";                       -- byte count baja (4)
            obuf(7) <= x"00";
            obuf(8) <= reqid(15 downto 8); obuf(9) <= reqid(7 downto 0);
            obuf(10) <= tag; obuf(11) <= x"00";     -- lower addr
            olen <= 16; oi <= 0;
            st <= S_CPL_HDR;

          when S_CPL_HDR =>
            -- salidas tx_* generadas combinacionalmente (ver proceso comb_tx);
            -- aqui solo se avanza el puntero al aceptar (tx_ready='1').
            if tx_ready = '1' then
              if oi = 11 then
                st <= S_CPL_DATA; oi <= 0;
              else
                oi <= oi + 1;
              end if;
            end if;

          when S_CPL_DATA =>
            if tx_ready = '1' then
              if oi = 3 then
                st <= S_HDR; hcnt <= 0;
              else
                oi <= oi + 1;
              end if;
            end if;

          when S_MSI =>
            st <= S_HDR;

          when others =>
            st <= S_HDR;
        end case;

        -- ------- MSI: disparo asincrono, se sirve cuando estamos en S_HDR -------
        if msi_trigger = '1' and st = S_HDR then
          -- MWr3 a la direccion MSI (cfg(0x50)) con dato cfg(0x54)
          obuf(0) <= B0_MWR3; obuf(1) <= x"00";
          obuf(2) <= x"00"; obuf(3) <= x"01";
          obuf(4) <= CPL_REQID(15 downto 8); obuf(5) <= CPL_REQID(7 downto 0);
          obuf(6) <= x"00"; obuf(7) <= x"0F";       -- tag MSI, BE=1111
          obuf(8)  <= cfg(20)(31 downto 24); obuf(9) <= cfg(20)(23 downto 16);
          obuf(10) <= cfg(20)(15 downto 8);  obuf(11) <= cfg(20)(7 downto 0);
          cpl_data <= cfg(21);                       -- dato MSI
          olen <= 16; oi <= 0;
          st <= S_CPL_HDR;   -- reutiliza el emisor (header + 1DW data)
        end if;

      end if;
    end if;
  end process;

end architecture;
