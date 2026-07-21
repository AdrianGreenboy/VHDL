-- HERCOSSNUX NPU - modelo de DDR como esclavo AXI4, solo para simulacion.
--
-- Sirve de banco de pruebas del master del NPU. Soporta:
--   - rafagas INCR de lectura y escritura
--   - backpressure configurable (G_STALL): cada cuantos ciclos se baja RVALID
--   - inyeccion de error (G_ERR_ADDR): una direccion que responde SLVERR
--
-- No pretende ser un modelo AXI completo: cubre lo que el master del NPU
-- ejercita, que es el subconjunto congelado.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_axi_pkg.all;

entity axi_ddr_model is
  generic (
    G_SIZE_BYTES : natural := 16#30000#;   -- 192 KB, cubre hasta OFF_RES
    G_STALL      : natural := 0;           -- 0 = sin backpressure
    G_ERR_ADDR   : integer := -1           -- -1 = sin inyeccion de error
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;

    -- canal de direccion de lectura
    arvalid : in  std_logic;
    arready : out std_logic;
    araddr  : in  std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    arlen   : in  std_logic_vector(7 downto 0);
    arburst : in  std_logic_vector(1 downto 0);

    -- canal de datos de lectura
    rvalid  : out std_logic;
    rready  : in  std_logic;
    rdata   : out std_logic_vector(C_AXI_DATA_W-1 downto 0);
    rresp   : out std_logic_vector(1 downto 0);
    rlast   : out std_logic;

    -- canal de direccion de escritura
    awvalid : in  std_logic;
    awready : out std_logic;
    awaddr  : in  std_logic_vector(C_AXI_ADDR_W-1 downto 0);
    awlen   : in  std_logic_vector(7 downto 0);
    awburst : in  std_logic_vector(1 downto 0);

    -- canal de datos de escritura
    wvalid  : in  std_logic;
    wready  : out std_logic;
    wdata   : in  std_logic_vector(C_AXI_DATA_W-1 downto 0);
    wstrb   : in  std_logic_vector(C_AXI_STRB_W-1 downto 0);
    wlast   : in  std_logic;

    -- canal de respuesta de escritura
    bvalid  : out std_logic;
    bready  : in  std_logic;
    bresp   : out std_logic_vector(1 downto 0);

    -- acceso de depuracion y precarga desde el testbench
    dbg_addr : in  natural := 0;
    dbg_data : out std_logic_vector(7 downto 0);
    -- precarga: escritura directa sin pasar por AXI
    pre_we   : in  std_logic := '0';
    pre_addr : in  natural := 0;
    pre_data : in  std_logic_vector(7 downto 0) := (others => '0')
  );
end entity axi_ddr_model;

architecture sim of axi_ddr_model is

  type t_mem is array (0 to G_SIZE_BYTES-1) of integer range 0 to 255;
  signal mem : t_mem := (others => 0);

  type t_rstate is (R_IDLE, R_DATA);
  signal rstate : t_rstate := R_IDLE;
  signal r_addr : natural := 0;
  signal r_cnt  : natural := 0;
  signal r_len  : natural := 0;
  signal r_err  : boolean := false;
  signal stall_c : natural := 0;

  type t_wstate is (W_IDLE, W_DATA, W_RESP);
  signal wstate : t_wstate := W_IDLE;
  signal w_addr : natural := 0;
  signal w_err  : boolean := false;

  signal arready_r : std_logic := '0';
  signal rvalid_r  : std_logic := '0';
  signal rlast_r   : std_logic := '0';
  signal rdata_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal rresp_r   : std_logic_vector(1 downto 0) := C_RESP_OKAY;
  signal awready_r : std_logic := '0';
  signal wready_r  : std_logic := '0';
  signal bvalid_r  : std_logic := '0';
  signal bresp_r   : std_logic_vector(1 downto 0) := C_RESP_OKAY;

begin

  arready <= arready_r;
  rvalid  <= rvalid_r;
  rlast   <= rlast_r;
  rdata   <= rdata_r;
  rresp   <= rresp_r;
  awready <= awready_r;
  wready  <= wready_r;
  bvalid  <= bvalid_r;
  bresp   <= bresp_r;

  dbg_data <= std_logic_vector(to_unsigned(mem(dbg_addr), 8));

  -- ---- lectura ----------------------------------------------------------
  rd_proc : process(clk)
    variable a : natural;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        rstate <= R_IDLE; arready_r <= '1'; rvalid_r <= '0'; rlast_r <= '0';
        stall_c <= 0;
      else
        case rstate is
          when R_IDLE =>
            rvalid_r <= '0'; rlast_r <= '0';
            arready_r <= '1';
            if arvalid = '1' and arready_r = '1' then
              r_addr <= to_integer(unsigned(araddr));
              r_len  <= to_integer(unsigned(arlen));
              r_cnt  <= 0;
              r_err  <= (G_ERR_ADDR >= 0) and
                        (to_integer(unsigned(araddr)) = G_ERR_ADDR);
              -- rresp se fija aqui: r_err es una senal y en el primer ciclo
              -- de R_DATA todavia tendria el valor anterior.
              if (G_ERR_ADDR >= 0) and
                 (to_integer(unsigned(araddr)) = G_ERR_ADDR) then
                rresp_r <= C_RESP_SLVERR;
              else
                rresp_r <= C_RESP_OKAY;
              end if;
              arready_r <= '0';
              rstate <= R_DATA;
            end if;

          when R_DATA =>
            -- Un solo punto de decision por ciclo. La version anterior
            -- calculaba la direccion con r_cnt y lo incrementaba en el mismo
            -- ciclo, lo que emitia la primera palabra dos veces.
            if G_STALL > 0 and stall_c = G_STALL then
              rvalid_r <= '0';
              stall_c  <= 0;
            elsif rvalid_r = '1' and rready = '1' then
              -- palabra aceptada: preparar la siguiente o terminar
              if r_cnt = r_len then
                rvalid_r <= '0';
                rlast_r  <= '0';
                rstate   <= R_IDLE;
              else
                a := r_addr + 4*(r_cnt + 1);
                if a + 3 < G_SIZE_BYTES then
                  rdata_r <= std_logic_vector(to_unsigned(mem(a+3), 8)) &
                             std_logic_vector(to_unsigned(mem(a+2), 8)) &
                             std_logic_vector(to_unsigned(mem(a+1), 8)) &
                             std_logic_vector(to_unsigned(mem(a),   8));
                else
                  rdata_r <= (others => '0');
                end if;
                if r_cnt + 1 = r_len then
                  rlast_r <= '1';
                else
                  rlast_r <= '0';
                end if;
                r_cnt   <= r_cnt + 1;
                stall_c <= stall_c + 1;
              end if;
            elsif rvalid_r = '0' then
              -- primera palabra de la rafaga
              a := r_addr + 4*r_cnt;
              if a + 3 < G_SIZE_BYTES then
                rdata_r <= std_logic_vector(to_unsigned(mem(a+3), 8)) &
                           std_logic_vector(to_unsigned(mem(a+2), 8)) &
                           std_logic_vector(to_unsigned(mem(a+1), 8)) &
                           std_logic_vector(to_unsigned(mem(a),   8));
              else
                rdata_r <= (others => '0');
              end if;
              if r_cnt = r_len then
                rlast_r <= '1';
              else
                rlast_r <= '0';
              end if;
              rvalid_r <= '1';
            end if;

        end case;
      end if;
    end if;
  end process;

  -- ---- escritura --------------------------------------------------------
  wr_proc : process(clk)
    variable a : natural;
  begin
    if rising_edge(clk) then
      -- precarga desde el testbench: mismo proceso que la escritura AXI para
      -- no crear un segundo driver sobre mem
      if pre_we = '1' and pre_addr < G_SIZE_BYTES then
        mem(pre_addr) <= to_integer(unsigned(pre_data));
      end if;
      if rst_n = '0' then
        wstate <= W_IDLE; awready_r <= '1'; wready_r <= '0'; bvalid_r <= '0';
      else
        case wstate is
          when W_IDLE =>
            bvalid_r <= '0';
            awready_r <= '1';
            if awvalid = '1' and awready_r = '1' then
              w_addr <= to_integer(unsigned(awaddr));
              w_err  <= (G_ERR_ADDR >= 0) and
                        (to_integer(unsigned(awaddr)) = G_ERR_ADDR);
              awready_r <= '0';
              wready_r  <= '1';
              wstate <= W_DATA;
            end if;

          when W_DATA =>
            if wvalid = '1' and wready_r = '1' then
              a := w_addr;
              for b in 0 to 3 loop
                if wstrb(b) = '1' and a + b < G_SIZE_BYTES then
                  mem(a + b) <= to_integer(unsigned(wdata(8*b+7 downto 8*b)));
                end if;
              end loop;
              w_addr <= w_addr + 4;
              if wlast = '1' then
                wready_r <= '0';
                if w_err then
                  bresp_r <= C_RESP_SLVERR;
                else
                  bresp_r <= C_RESP_OKAY;
                end if;
                bvalid_r <= '1';
                wstate <= W_RESP;
              end if;
            end if;

          when W_RESP =>
            if bready = '1' then
              bvalid_r <= '0';
              wstate <= W_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- Carga desde el testbench por procedimiento externo no es posible en VHDL
  -- sin puertos, asi que el testbench escribe por AXI o accede por jerarquia.

end architecture sim;
