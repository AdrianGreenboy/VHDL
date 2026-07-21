-- HERCOSSNUX NPU - motor DMA, maestro AXI4.
--
-- Subconjunto congelado: solo rafagas INCR, ARLEN <= 15 (16 transferencias
-- de 4 bytes = 64 B, muy por debajo de la frontera de 4 KB), ID fijo en 0,
-- RRESP y BRESP comprobados y reportados por err_out.
--
-- Interfaz interna: se le pide un bloque (direccion + numero de bytes) y
-- entrega los bytes de uno en uno por out_data/out_we con out_idx creciente.
-- Asi el consumidor no necesita saber nada de AXI.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_axi_pkg.all;

entity npu_dma is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- peticion de lectura de bloque
    rd_start  : in  std_logic;
    rd_addr   : in  std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    rd_bytes  : in  natural;
    rd_busy   : out std_logic;
    rd_done   : out std_logic;

    -- flujo de salida de bytes leidos
    out_we    : out std_logic;
    out_idx   : out natural;
    out_data  : out std_logic_vector(7 downto 0);

    -- peticion de escritura de bloque
    wr_start  : in  std_logic;
    wr_addr   : in  std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    wr_bytes  : in  natural;
    wr_busy   : out std_logic;
    wr_done   : out std_logic;

    -- flujo de entrada de bytes a escribir
    in_idx    : out natural;
    in_data   : in  std_logic_vector(7 downto 0);

    err_out   : out std_logic;
    errcode   : out std_logic_vector(1 downto 0);

    -- AXI4 master
    m_arvalid : out std_logic;
    m_arready : in  std_logic;
    m_araddr  : out std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    m_arlen   : out std_logic_vector(7 downto 0);
    m_arsize  : out std_logic_vector(2 downto 0);
    m_arburst : out std_logic_vector(1 downto 0);

    m_rvalid  : in  std_logic;
    m_rready  : out std_logic;
    m_rdata   : in  std_logic_vector(C_AXI_DATA_W-1 downto 0);
    m_rresp   : in  std_logic_vector(1 downto 0);
    m_rlast   : in  std_logic;

    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_awaddr  : out std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);

    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_wdata   : out std_logic_vector(C_AXI_DATA_W-1 downto 0);
    m_wstrb   : out std_logic_vector(C_AXI_STRB_W-1 downto 0);
    m_wlast   : out std_logic;

    m_bvalid  : in  std_logic;
    m_bready  : out std_logic;
    m_bresp   : in  std_logic_vector(1 downto 0)
  );
end entity npu_dma;

architecture rtl of npu_dma is

  type t_rstate is (R_IDLE, R_ADDR, R_CAP, R_DATA, R_NEXT, R_DONE);
  signal rstate : t_rstate := R_IDLE;

  signal r_base   : unsigned(31 downto 0) := (others => '0');
  signal r_total  : natural := 0;     -- bytes totales pedidos
  signal r_sent   : natural := 0;     -- bytes ya entregados
  signal r_blen   : natural := 0;     -- transferencias de la rafaga actual
  signal r_bcnt   : natural := 0;
  signal r_byte   : natural := 0;     -- indice de byte dentro de la palabra

  -- W_FILL ensambla la palabra leyendo 4 bytes en ciclos sucesivos: el
  -- consumidor entrega un byte por ciclo segun in_idx.
  type t_wstate is (W_IDLE, W_ADDR, W_FILL, W_DATA, W_RESP, W_DONE);
  signal wstate : t_wstate := W_IDLE;

  signal w_base  : unsigned(31 downto 0) := (others => '0');
  signal w_total : natural := 0;
  signal w_sent  : natural := 0;
  signal w_blen  : natural := 0;
  signal w_bcnt  : natural := 0;

  signal arvalid_r : std_logic := '0';
  signal araddr_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal arlen_r   : std_logic_vector(7 downto 0) := (others => '0');
  signal rready_r  : std_logic := '0';

  signal awvalid_r : std_logic := '0';
  signal awaddr_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal awlen_r   : std_logic_vector(7 downto 0) := (others => '0');
  signal wvalid_r  : std_logic := '0';
  signal wdata_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal wlast_r   : std_logic := '0';
  signal bready_r  : std_logic := '0';

  signal out_we_r  : std_logic := '0';
  signal out_idx_r : natural := 0;
  signal out_dat_r : std_logic_vector(7 downto 0) := (others => '0');

  signal in_idx_r  : natural := 0;
  signal wfill_b   : natural range 0 to 4 := 0;
  -- Indice del proximo byte a pedir al consumidor. Se lleva aparte de
  -- w_sent porque w_sent se actualiza en el mismo flanco y tendria el
  -- valor viejo al calcular la direccion siguiente.
  signal wnext_i   : natural := 0;
  signal wacc      : std_logic_vector(31 downto 0) := (others => '0');

  signal rd_busy_r : std_logic := '0';
  signal rd_done_r : std_logic := '0';
  signal wr_busy_r : std_logic := '0';
  signal wr_done_r : std_logic := '0';
  -- Un driver por proceso: err_r/errcode_r manejadas desde dos procesos
  -- distintos producian multiples drivers y resolvian a 'X'.
  signal err_rd     : std_logic := '0';
  signal errcode_rd : std_logic_vector(1 downto 0) := C_RESP_OKAY;
  signal err_wr     : std_logic := '0';
  signal errcode_wr : std_logic_vector(1 downto 0) := C_RESP_OKAY;

  -- palabra recibida, se descompone en 4 bytes en ciclos sucesivos
  signal rword : std_logic_vector(31 downto 0) := (others => '0');
  signal rword_v : std_logic := '0';

  -- Transferencias que quedan, acotadas a C_MAX_BURST
  function burst_len (restantes : natural) return natural is
    variable palabras : natural;
  begin
    palabras := (restantes + 3) / 4;
    if palabras > C_MAX_BURST then
      return C_MAX_BURST;
    else
      return palabras;
    end if;
  end function;

begin

  m_arvalid <= arvalid_r;
  m_araddr  <= araddr_r;
  m_arlen   <= arlen_r;
  m_arsize  <= "010";                 -- 4 bytes por transferencia
  m_arburst <= C_BURST_INCR;
  m_rready  <= rready_r;

  m_awvalid <= awvalid_r;
  m_awaddr  <= awaddr_r;
  m_awlen   <= awlen_r;
  m_awsize  <= "010";
  m_awburst <= C_BURST_INCR;
  m_wvalid  <= wvalid_r;
  m_wdata   <= wdata_r;
  m_wstrb   <= (others => '1');
  m_wlast   <= wlast_r;
  m_bready  <= bready_r;

  out_we   <= out_we_r;
  out_idx  <= out_idx_r;
  out_data <= out_dat_r;
  in_idx   <= in_idx_r;

  rd_busy <= rd_busy_r;
  rd_done <= rd_done_r;
  wr_busy <= wr_busy_r;
  wr_done <= wr_done_r;
  err_out <= err_rd or err_wr;
  errcode <= errcode_rd when err_rd = '1' else errcode_wr;

  -- ---- lectura ----------------------------------------------------------
  rd_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        rstate <= R_IDLE; arvalid_r <= '0'; rready_r <= '0';
        rd_busy_r <= '0'; rd_done_r <= '0'; out_we_r <= '0';
      else
        rd_done_r <= '0';
        out_we_r  <= '0';

        case rstate is
          when R_IDLE =>
            rd_busy_r <= '0';
            if rd_start = '1' then
              r_base    <= unsigned(rd_addr);
              r_total   <= rd_bytes;
              r_sent    <= 0;
              rd_busy_r <= '1';
              rstate    <= R_ADDR;
            end if;

          when R_ADDR =>
            -- Emitir la direccion de la siguiente rafaga
            if arvalid_r = '0' then
              r_blen   <= burst_len(r_total - r_sent);
              araddr_r <= std_logic_vector(r_base + to_unsigned(r_sent, 32));
              arlen_r  <= std_logic_vector(
                            to_unsigned(burst_len(r_total - r_sent) - 1, 8));
              arvalid_r <= '1';
              r_bcnt   <= 0;
              r_byte   <= 0;
            elsif m_arready = '1' then
              arvalid_r <= '0';
              rready_r  <= '1';
              rstate    <= R_CAP;
            end if;

          when R_CAP =>
            -- Captura de una palabra. Estado propio: usar una bandera
            -- rword_v no bastaba porque se limpiaba y se volvia a poner en
            -- el mismo ciclo, entregando los bytes de la palabra anterior.
            rready_r <= '1';
            if m_rvalid = '1' and rready_r = '1' then
              rword    <= m_rdata;
              rready_r <= '0';
              r_byte   <= 0;
              if m_rresp /= C_RESP_OKAY then
                err_rd     <= '1';
                errcode_rd <= m_rresp;
              end if;
              rstate <= R_DATA;
            end if;

          when R_DATA =>
            -- rword ya contiene la palabra: entregar sus 4 bytes
            if r_sent < r_total then
              out_we_r  <= '1';
              out_idx_r <= r_sent;
              out_dat_r <= rword(8*r_byte + 7 downto 8*r_byte);
              r_sent    <= r_sent + 1;
            end if;
            if r_byte = 3 or r_sent + 1 >= r_total then
              r_byte <= 0;
              if r_bcnt = r_blen - 1 then
                rstate <= R_NEXT;
              else
                r_bcnt <= r_bcnt + 1;
                rstate <= R_CAP;
              end if;
            else
              r_byte <= r_byte + 1;
            end if;

          when R_NEXT =>
            rready_r <= '0';
            if r_sent >= r_total then
              rstate <= R_DONE;
            else
              rstate <= R_ADDR;
            end if;

          when R_DONE =>
            rd_busy_r <= '0';
            rd_done_r <= '1';
            rstate    <= R_IDLE;
        end case;
      end if;
    end if;
  end process;

  -- ---- escritura --------------------------------------------------------
  wr_proc : process(clk)
    variable b : natural;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        wstate <= W_IDLE; awvalid_r <= '0'; wvalid_r <= '0'; bready_r <= '0';
        wr_busy_r <= '0'; wr_done_r <= '0';
      else
        wr_done_r <= '0';

        case wstate is
          when W_IDLE =>
            wr_busy_r <= '0';
            if wr_start = '1' then
              w_base    <= unsigned(wr_addr);
              w_total   <= wr_bytes;
              w_sent    <= 0;
              in_idx_r  <= 0;
              wr_busy_r <= '1';
              wnext_i   <= 0;
              wstate    <= W_ADDR;
            end if;

          when W_ADDR =>
            if awvalid_r = '0' then
              w_blen    <= burst_len(w_total - w_sent);
              awaddr_r  <= std_logic_vector(w_base + to_unsigned(w_sent, 32));
              awlen_r   <= std_logic_vector(
                             to_unsigned(burst_len(w_total - w_sent) - 1, 8));
              awvalid_r <= '1';
              w_bcnt    <= 0;
            elsif m_awready = '1' then
              awvalid_r <= '0';
              wfill_b   <= 0;
              in_idx_r  <= w_sent;
              wstate    <= W_FILL;
            end if;

          when W_FILL =>
            -- in_idx_r se fija en W_ADDR a w_sent, asi que en el ciclo con
            -- wfill_b = k el consumidor ya presenta el byte (w_sent + k).
            -- Se guarda ese byte y se pide el siguiente en el mismo ciclo.
            -- Validado contra un modelo ciclo a ciclo antes de escribirlo.
            if wfill_b < 4 then
              if w_sent + wfill_b < w_total then
                wacc(8*wfill_b + 7 downto 8*wfill_b) <= in_data;
              else
                wacc(8*wfill_b + 7 downto 8*wfill_b) <= (others => '0');
              end if;
              in_idx_r <= w_sent + wfill_b + 1;
              wfill_b  <= wfill_b + 1;
            else
              wdata_r  <= wacc;
              wvalid_r <= '1';
              if w_bcnt = w_blen - 1 then
                wlast_r <= '1';
              else
                wlast_r <= '0';
              end if;
              wstate <= W_DATA;
            end if;

          when W_DATA =>
            if m_wready = '1' and wvalid_r = '1' then
              w_sent <= w_sent + 4;
              wvalid_r <= '0';
              if wlast_r = '1' then
                wlast_r  <= '0';
                bready_r <= '1';
                wstate   <= W_RESP;
              else
                w_bcnt   <= w_bcnt + 1;
                wfill_b  <= 0;
                in_idx_r <= w_sent + 4;
                wstate   <= W_FILL;
              end if;
            end if;

          when W_RESP =>
            if m_bvalid = '1' and bready_r = '1' then
              bready_r <= '0';
              if m_bresp /= C_RESP_OKAY then
                err_wr     <= '1';
                errcode_wr <= m_bresp;
              end if;
              if w_sent >= w_total then
                wstate <= W_DONE;
              else
                wstate <= W_ADDR;
              end if;
            end if;

          when W_DONE =>
            wr_busy_r <= '0';
            wr_done_r <= '1';
            wstate    <= W_IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
