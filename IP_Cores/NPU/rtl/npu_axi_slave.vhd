-- HERCOSSNUX NPU - esclavo AXI4 full de los registros de control.
--
-- Subconjunto congelado:
--   - rafagas INCR y FIXED reales; WRAP se acepta y se comporta como INCR
--   - AWLEN hasta 255
--   - IDs propagados: AWID -> BID, ARID -> RID
--   - WSTRB respetado
--   - OKAY siempre, SLVERR en direccion no mapeada
--   - AWLOCK ignorado (sin acceso exclusivo)
--
-- Mapa (offsets dentro de la ventana de 64K):
--   0x00 CTRL    W  bit0 start (autoclear), bit1 load_weights (autoclear)
--   0x04 STATUS  R  bit0 busy, bit1 done, bit2 error, bit7:4 clase
--   0x08 ID      R  0x4E505531
--   0x0C BASE    RW base del buffer en DDR
--   0x10 ERRCODE R  ultimo RRESP/BRESP no OKAY
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_axi_pkg.all;

entity npu_axi_slave is
  generic (
    G_ID_W : natural := 4
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- escritura
    s_awvalid : in  std_logic;
    s_awready : out std_logic;
    s_awaddr  : in  std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    s_awlen   : in  std_logic_vector(7 downto 0);
    s_awsize  : in  std_logic_vector(2 downto 0);
    s_awburst : in  std_logic_vector(1 downto 0);
    s_awid    : in  std_logic_vector(G_ID_W-1 downto 0);

    s_wvalid  : in  std_logic;
    s_wready  : out std_logic;
    s_wdata   : in  std_logic_vector(C_AXI_DATA_W-1 downto 0);
    s_wstrb   : in  std_logic_vector(C_AXI_STRB_W-1 downto 0);
    s_wlast   : in  std_logic;

    s_bvalid  : out std_logic;
    s_bready  : in  std_logic;
    s_bresp   : out std_logic_vector(1 downto 0);
    s_bid     : out std_logic_vector(G_ID_W-1 downto 0);

    -- lectura
    s_arvalid : in  std_logic;
    s_arready : out std_logic;
    s_araddr  : in  std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    s_arlen   : in  std_logic_vector(7 downto 0);
    s_arsize  : in  std_logic_vector(2 downto 0);
    s_arburst : in  std_logic_vector(1 downto 0);
    s_arid    : in  std_logic_vector(G_ID_W-1 downto 0);

    s_rvalid  : out std_logic;
    s_rready  : in  std_logic;
    s_rdata   : out std_logic_vector(C_AXI_DATA_W-1 downto 0);
    s_rresp   : out std_logic_vector(1 downto 0);
    s_rlast   : out std_logic;
    s_rid     : out std_logic_vector(G_ID_W-1 downto 0);

    -- hacia el nucleo
    o_start   : out std_logic;
    o_loadw   : out std_logic;
    o_base    : out std_logic_vector(31 downto 0);
    i_busy    : in  std_logic;
    i_done    : in  std_logic;
    i_error   : in  std_logic;
    i_clase   : in  std_logic_vector(3 downto 0);
    i_errcode : in  std_logic_vector(1 downto 0)
  );
end entity npu_axi_slave;

architecture rtl of npu_axi_slave is

  type t_wstate is (WS_IDLE, WS_DATA, WS_RESP);
  signal wstate : t_wstate := WS_IDLE;

  type t_rstate is (RS_IDLE, RS_DATA);
  signal rstate : t_rstate := RS_IDLE;

  signal aw_addr  : unsigned(15 downto 0) := (others => '0');
  signal aw_burst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal aw_id    : std_logic_vector(G_ID_W-1 downto 0) := (others => '0');
  signal w_bad    : boolean := false;

  signal ar_addr  : unsigned(15 downto 0) := (others => '0');
  signal ar_burst : std_logic_vector(1 downto 0) := C_BURST_INCR;
  signal ar_id    : std_logic_vector(G_ID_W-1 downto 0) := (others => '0');
  signal ar_cnt   : natural range 0 to 255 := 0;
  signal ar_len   : natural range 0 to 255 := 0;

  signal awready_r : std_logic := '1';
  signal wready_r  : std_logic := '0';
  signal bvalid_r  : std_logic := '0';
  signal bresp_r   : std_logic_vector(1 downto 0) := C_RESP_OKAY;
  signal arready_r : std_logic := '1';
  signal rvalid_r  : std_logic := '0';
  signal rdata_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal rresp_r   : std_logic_vector(1 downto 0) := C_RESP_OKAY;
  signal rlast_r   : std_logic := '0';

  signal start_r : std_logic := '0';
  signal loadw_r : std_logic := '0';
  signal base_r  : std_logic_vector(31 downto 0) := x"70000000";

  -- Direccion mapeada? Solo los cinco registros definidos.
  function mapeada (a : unsigned(15 downto 0)) return boolean is
  begin
    case to_integer(a) is
      when C_REG_CTRL | C_REG_STATUS | C_REG_ID |
           C_REG_BASE | C_REG_ERRCODE => return true;
      when others => return false;
    end case;
  end function;

  function leer_reg (a : unsigned(15 downto 0);
                     busy, done, err : std_logic;
                     clase : std_logic_vector(3 downto 0);
                     errcode : std_logic_vector(1 downto 0);
                     base : std_logic_vector(31 downto 0))
    return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := (others => '0');
  begin
    case to_integer(a) is
      when C_REG_STATUS =>
        v(0) := busy;
        v(1) := done;
        v(2) := err;
        v(7 downto 4) := clase;
      when C_REG_ID =>
        v := C_ID_VALUE;
      when C_REG_BASE =>
        v := base;
      when C_REG_ERRCODE =>
        v(1 downto 0) := errcode;
      when others =>
        v := (others => '0');
    end case;
    return v;
  end function;

begin

  s_awready <= awready_r;
  s_wready  <= wready_r;
  s_bvalid  <= bvalid_r;
  s_bresp   <= bresp_r;
  s_bid     <= aw_id;
  s_arready <= arready_r;
  s_rvalid  <= rvalid_r;
  s_rdata   <= rdata_r;
  s_rresp   <= rresp_r;
  s_rlast   <= rlast_r;
  s_rid     <= ar_id;

  o_start <= start_r;
  o_loadw <= loadw_r;
  o_base  <= base_r;

  -- ---- escritura --------------------------------------------------------
  wr_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        wstate <= WS_IDLE; awready_r <= '1'; wready_r <= '0'; bvalid_r <= '0';
        start_r <= '0'; loadw_r <= '0'; base_r <= x"70000000";
      else
        -- los bits de disparo son de un solo ciclo
        start_r <= '0';
        loadw_r <= '0';

        case wstate is
          when WS_IDLE =>
            bvalid_r <= '0';
            awready_r <= '1';
            if s_awvalid = '1' and awready_r = '1' then
              aw_addr  <= unsigned(s_awaddr(15 downto 0));
              aw_burst <= s_awburst;
              aw_id    <= s_awid;
              w_bad    <= not mapeada(unsigned(s_awaddr(15 downto 0)));
              awready_r <= '0';
              wready_r  <= '1';
              wstate <= WS_DATA;
            end if;

          when WS_DATA =>
            if s_wvalid = '1' and wready_r = '1' then
              -- WSTRB respetado: solo se actualiza si el byte esta habilitado
              if mapeada(aw_addr) then
                case to_integer(aw_addr) is
                  when C_REG_CTRL =>
                    if s_wstrb(0) = '1' then
                      start_r <= s_wdata(0);
                      loadw_r <= s_wdata(1);
                    end if;
                  when C_REG_BASE =>
                    for b in 0 to 3 loop
                      if s_wstrb(b) = '1' then
                        base_r(8*b+7 downto 8*b) <= s_wdata(8*b+7 downto 8*b);
                      end if;
                    end loop;
                  when others =>
                    null;   -- registros de solo lectura
                end case;
              end if;

              -- FIXED no avanza; INCR y WRAP avanzan
              if aw_burst /= C_BURST_FIXED then
                aw_addr <= aw_addr + 4;
              end if;

              if s_wlast = '1' then
                wready_r <= '0';
                if w_bad then
                  bresp_r <= C_RESP_SLVERR;
                else
                  bresp_r <= C_RESP_OKAY;
                end if;
                bvalid_r <= '1';
                wstate <= WS_RESP;
              end if;
            end if;

          when WS_RESP =>
            if s_bready = '1' then
              bvalid_r <= '0';
              wstate <= WS_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- ---- lectura ----------------------------------------------------------
  rd_proc : process(clk)
    variable a : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        rstate <= RS_IDLE; arready_r <= '1'; rvalid_r <= '0'; rlast_r <= '0';
      else
        case rstate is
          when RS_IDLE =>
            rvalid_r <= '0'; rlast_r <= '0';
            arready_r <= '1';
            if s_arvalid = '1' and arready_r = '1' then
              a := unsigned(s_araddr(15 downto 0));
              ar_addr  <= a;
              ar_burst <= s_arburst;
              ar_id    <= s_arid;
              ar_len   <= to_integer(unsigned(s_arlen));
              ar_cnt   <= 0;
              arready_r <= '0';
              -- primera palabra
              rdata_r <= leer_reg(a, i_busy, i_done, i_error,
                                  i_clase, i_errcode, base_r);
              if mapeada(a) then
                rresp_r <= C_RESP_OKAY;
              else
                rresp_r <= C_RESP_SLVERR;
              end if;
              if to_integer(unsigned(s_arlen)) = 0 then
                rlast_r <= '1';
              else
                rlast_r <= '0';
              end if;
              rvalid_r <= '1';
              rstate <= RS_DATA;
            end if;

          when RS_DATA =>
            if rvalid_r = '1' and s_rready = '1' then
              if ar_cnt = ar_len then
                rvalid_r <= '0';
                rlast_r  <= '0';
                rstate   <= RS_IDLE;
              else
                if ar_burst = C_BURST_FIXED then
                  a := ar_addr;
                else
                  a := ar_addr + 4;
                  ar_addr <= a;
                end if;
                rdata_r <= leer_reg(a, i_busy, i_done, i_error,
                                    i_clase, i_errcode, base_r);
                if mapeada(a) then
                  rresp_r <= C_RESP_OKAY;
                else
                  rresp_r <= C_RESP_SLVERR;
                end if;
                if ar_cnt + 1 = ar_len then
                  rlast_r <= '1';
                else
                  rlast_r <= '0';
                end if;
                ar_cnt <= ar_cnt + 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
