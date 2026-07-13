-------------------------------------------------------------------------------
-- dsp_mmio.vhd  --  Wrapper MMIO del IP DSP (Layer 2, familia RV32IM SoC).
--
-- Region 0x9000_0000, patron SpaceWire (MMIO directo, rdata COMBINACIONAL
-- durante req, ready inmediato). Sin AXI. Llenado de datos por MMIO (opcion A).
--
-- Mapa de registros (offsets byte):
--   0x000 ID      RO  0xD5B10100
--   0x004 CTRL    RW  bit0=START(autoclear) bits[3:1]=FUNC bit4=REAL_PACK bit5=FLUSH
--                     FUNC: 000 FFT_fwd 001 FFT_inv 010 FIR 011 CORDIC_rot 100 CORDIC_vec
--   0x008 STATUS  RO/W1C  bit0=BUSY bit1=DONE(sticky) bit2=ERR
--   0x00C LOG2N   RW  3..10
--   0x010 FIR_LEN RW  1..64
--   0x014 CORDIC_A RW  angulo(rot) / X(vec)
--   0x018 CORDIC_B RW  Y(vec)
--   0x01C RES_LO  RO  cos/mag
--   0x020 RES_HI  RO  sin/fase
--   0x080..0x0FF COEF  RW 32 words (coef simetricos FIR, Q1.15 en [15:0])
--   0x1000..0x1FFF DATA RW buffer 1024 complejos {im[31:16], re[15:0]}
--
-- Contrato dmem: req (sel), wstrb (we colapsado), rdata comb, ready inmediato.
-- CONTRATO CRITICO (leccion PTP): dmem_rdata es COMBINACIONAL, lectura directa.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dsp_mmio is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;                          -- sincrono activo alto
    -- bus dmem (contrato de familia)
    req    : in  std_logic;                          -- sel calificado 1 ciclo
    addr   : in  std_logic_vector(15 downto 0);      -- offset dentro de la region
    wdata  : in  std_logic_vector(31 downto 0);
    wstrb  : in  std_logic_vector(3 downto 0);
    rdata  : out std_logic_vector(31 downto 0);      -- COMBINACIONAL
    ready  : out std_logic                            -- inmediato
  );
end entity;

architecture rtl of dsp_mmio is

  constant ID_VAL : std_logic_vector(31 downto 0) := x"D5B10100";

  -- registros
  signal ctrl_r    : std_logic_vector(31 downto 0) := (others=>'0');
  signal log2n_r   : std_logic_vector(31 downto 0) := (others=>'0');
  signal firlen_r  : std_logic_vector(31 downto 0) := (others=>'0');
  signal corda_r   : std_logic_vector(31 downto 0) := (others=>'0');
  signal cordb_r   : std_logic_vector(31 downto 0) := (others=>'0');
  signal reslo_r   : std_logic_vector(31 downto 0) := (others=>'0');
  signal reshi_r   : std_logic_vector(31 downto 0) := (others=>'0');

  signal status_busy : std_logic := '0';
  signal status_done : std_logic := '0';   -- sticky
  signal status_err  : std_logic := '0';

  -- COEF: 32 words
  type coef_arr_t is array (0 to 31) of std_logic_vector(31 downto 0);
  signal coef_r : coef_arr_t := (others => (others=>'0'));

  -- DATA buffer: 1024 complejos (re en [15:0], im en [31:16]).
  -- BRAM SDP: 1 puerto de escritura (proceso unico) + 1 puerto de lectura
  -- REGISTRADA. Todos los accesos (MMIO + internos) se multiplexan a estos
  -- puertos. ram_style=block. La lectura tiene 1 ciclo de latencia.
  type data_arr_t is array (0 to 1023) of std_logic_vector(31 downto 0);
  signal data_r : data_arr_t := (others => (others=>'0'));
  attribute ram_style : string;
  attribute ram_style of data_r : signal is "block";
  -- puerto de escritura
  signal dr_waddr : integer range 0 to 1023 := 0;
  signal dr_wdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal dr_we    : std_logic := '0';
  -- puerto de lectura registrada
  signal dr_raddr : integer range 0 to 1023 := 0;
  signal dr_rdata : std_logic_vector(31 downto 0) := (others=>'0');
  -- wait-state de lectura DATA: 1 ciclo (BRAM registrada)
  signal data_rd_ready : std_logic := '0';
  signal data_rd_seen  : std_logic := '0';
  signal dr_raddr_q    : integer range 0 to 1023 := 0;

  -- decodificacion de acceso
  signal we      : std_logic;
  signal is_data : std_logic;
  signal is_coef : std_logic;
  signal widx    : integer range 0 to 1023;
  signal cidx    : integer range 0 to 31;

  -- FUNC
  constant F_FFTF : std_logic_vector(2 downto 0) := "000";
  constant F_FFTI : std_logic_vector(2 downto 0) := "001";
  constant F_FIR  : std_logic_vector(2 downto 0) := "010";
  constant F_CROT : std_logic_vector(2 downto 0) := "011";
  constant F_CVEC : std_logic_vector(2 downto 0) := "100";

  -- CORDIC
  signal cor_start : std_logic := '0';
  signal cor_mode  : std_logic := '0';
  signal cor_xin, cor_yin, cor_zin : std_logic_vector(15 downto 0);
  signal cor_xout, cor_yout, cor_zout : std_logic_vector(15 downto 0);
  signal cor_busy, cor_done : std_logic;

  -- FIR
  signal fir_push : std_logic := '0';
  signal fir_flush: std_logic := '0';
  signal fir_xin  : std_logic_vector(15 downto 0);
  signal fir_yout : std_logic_vector(15 downto 0);
  signal fir_valid, fir_busy : std_logic;
  signal fir_coef_we : std_logic := '0';
  signal fir_coef_idx: std_logic_vector(5 downto 0) := (others=>'0');
  signal fir_coef_dat: std_logic_vector(15 downto 0) := (others=>'0');

  -- FSM de orquestacion de operacion
  type op_t is (OP_IDLE, OP_RUN, OP_FINISH,
                OP_FFT_LOAD, OP_FFT_RUN, OP_FFT_STORE,
                OP_FIR_LOADCO, OP_FIR_PUSH, OP_FIR_PUSH1B, OP_FIR_PUSH2, OP_FIR_WAIT, OP_FIR_STORE,
                OP_RP_LOAD, OP_RP_LOAD1B, OP_RP_LOAD2, OP_RP_LOAD2B, OP_RP_LOAD3, OP_RP_FFTRUN, OP_RP_TOUNS, OP_RP_UNSRUN, OP_RP_STORE);
  signal op_state : op_t := OP_IDLE;
  signal cur_func : std_logic_vector(2 downto 0) := (others=>'0');
  signal real_pack_r : std_logic := '0';

  -- DATA_LEN (0x024): num muestras (FIR) / 2N reales (real-pack)
  signal datalen_r : std_logic_vector(31 downto 0) := (others=>'0');
  signal blk_n     : integer range 0 to 2048 := 0;
  signal fir_ci    : integer range 0 to 32 := 0;   -- indice carga coef

  -- FFT
  signal fft_log2n : std_logic_vector(3 downto 0);
  signal fft_inv   : std_logic := '0';
  signal fft_wr_en : std_logic := '0';
  signal fft_wr_idx: std_logic_vector(9 downto 0) := (others=>'0');
  signal fft_wr_re, fft_wr_im : std_logic_vector(15 downto 0) := (others=>'0');
  signal fft_start : std_logic := '0';
  signal fft_done, fft_busy : std_logic;
  signal fft_rd_idx: std_logic_vector(9 downto 0) := (others=>'0');
  signal fft_rd_re, fft_rd_im : std_logic_vector(15 downto 0);
  signal xfer_idx  : integer range 0 to 1026 := 0;   -- +2 para vaciar pipeline BRAM
  signal fft_n     : integer range 1 to 1024 := 1024;

  -- unsplit (real-pack)
  signal uns_log2n2 : std_logic_vector(3 downto 0);
  signal uns_wr_en  : std_logic := '0';
  signal uns_wr_idx : std_logic_vector(9 downto 0) := (others=>'0');
  signal uns_wr_zr, uns_wr_zi : std_logic_vector(15 downto 0) := (others=>'0');
  signal uns_start  : std_logic := '0';
  signal uns_done, uns_busy : std_logic;
  signal uns_rd_idx : std_logic_vector(9 downto 0) := (others=>'0');
  signal uns_rd_xr, uns_rd_xi : std_logic_vector(15 downto 0);
  signal rp_n2      : integer range 2 to 1024 := 2;   -- 2N
  signal rp_n       : integer range 1 to 512 := 1;    -- N

begin

  ---------------------------------------------------------------------------
  -- BRAM SDP para data_r: 1 puerto escritura + 1 lectura registrada.
  -- Todos los accesos (MMIO e internos) se multiplexan a dr_waddr/dr_raddr.
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if dr_we = '1' then
        data_r(dr_waddr) <= dr_wdata;
      end if;
      dr_rdata <= data_r(dr_raddr);
    end if;
  end process;

  -- wait-state de lectura DATA por MMIO. El dato en dr_rdata corresponde al
  -- dr_raddr del ciclo ANTERIOR. Una lectura DATA esta lista cuando la
  -- direccion que se leyo (dr_raddr_q) coincide con la pedida (widx).
  process(clk)
  begin
    if rising_edge(clk) then
      dr_raddr_q <= dr_raddr;
    end if;
  end process;
  data_rd_ready <= '1' when (dr_raddr_q = widx) else '0';

  ---------------------------------------------------------------------------
  -- decodificacion combinacional
  ---------------------------------------------------------------------------
  we      <= '1' when (req='1' and wstrb /= "0000") else '0';
  is_data <= '1' when addr(15 downto 12) = "0001" else '0';      -- 0x1000-0x1FFF
  is_coef <= '1' when (addr(15 downto 7) = "000000001") else '0';-- 0x080-0x0FF
  widx    <= to_integer(unsigned(addr(11 downto 2)));            -- palabra en DATA
  cidx    <= to_integer(unsigned(addr(6 downto 2)));            -- palabra en COEF

  -- ready: inmediato para todo EXCEPTO lecturas a la ventana DATA, que ahora
  -- salen de BRAM registrada (1 ciclo). Para lecturas DATA, ready se difiere
  -- 1 ciclo (lo gestiona el registro data_rd_pend abajo).
  ready   <= req when not (is_data='1' and we='0') else data_rd_ready;

  ---------------------------------------------------------------------------
  -- lectura: registros de control COMBINACIONALES; ventana DATA REGISTRADA.
  ---------------------------------------------------------------------------
  process(all)
  begin
    if is_data = '1' then
      rdata <= dr_rdata;               -- BRAM registrada (1 ciclo latencia)
    elsif is_coef = '1' then
      rdata <= coef_r(cidx);
    else
      case addr(7 downto 0) is
        when x"00"  => rdata <= ID_VAL;
        when x"04"  => rdata <= ctrl_r;
        when x"08"  => rdata <= (0 => status_busy, 1 => status_done,
                                 2 => status_err, others => '0');
        when x"0C"  => rdata <= log2n_r;
        when x"10"  => rdata <= firlen_r;
        when x"14"  => rdata <= corda_r;
        when x"18"  => rdata <= cordb_r;
        when x"1C"  => rdata <= reslo_r;
        when x"20"  => rdata <= reshi_r;
        when x"24"  => rdata <= datalen_r;
        when others => rdata <= (others=>'0');
      end case;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- datapaths
  ---------------------------------------------------------------------------
  cor_xin <= corda_r(15 downto 0);   -- vec: X
  cor_yin <= cordb_r(15 downto 0);   -- vec: Y
  cor_zin <= corda_r(15 downto 0);   -- rot: angulo

  u_cordic : entity work.cordic_dp
    generic map (ITERS => 16)
    port map (clk=>clk, rst=>rst, start=>cor_start, mode=>cor_mode,
              x_in=>cor_xin, y_in=>cor_yin, z_in=>cor_zin,
              x_out=>cor_xout, y_out=>cor_yout, z_out=>cor_zout,
              busy=>cor_busy, done=>cor_done);

  u_fir : entity work.fir_dp
    generic map (MAXTAPS => 64)
    port map (clk=>clk, rst=>(rst or fir_flush),
              cfg_len=>firlen_r(6 downto 0),
              coef_we=>fir_coef_we, coef_idx=>fir_coef_idx, coef_dat=>fir_coef_dat,
              push=>fir_push, x_in=>fir_xin, y_out=>fir_yout,
              valid=>fir_valid, busy=>fir_busy);

  u_fft : entity work.fft_dp
    generic map (NMAX=>1024, LOG2MAX=>10)
    port map (clk=>clk, rst=>rst, log2n=>fft_log2n, inv=>fft_inv,
              wr_en=>fft_wr_en, wr_idx=>fft_wr_idx, wr_re=>fft_wr_re, wr_im=>fft_wr_im,
              start=>fft_start, done=>fft_done, busy=>fft_busy,
              rd_idx=>fft_rd_idx, rd_re=>fft_rd_re, rd_im=>fft_rd_im);

  u_uns : entity work.fft_unsplit_dp
    generic map (NMAX=>512, LOG2MAX=>9)
    port map (clk=>clk, rst=>rst, log2n2=>uns_log2n2,
              wr_en=>uns_wr_en, wr_idx=>uns_wr_idx, wr_zr=>uns_wr_zr, wr_zi=>uns_wr_zi,
              start=>uns_start, done=>uns_done, busy=>uns_busy,
              rd_idx=>uns_rd_idx, rd_xr=>uns_rd_xr, rd_xi=>uns_rd_xi);

  ---------------------------------------------------------------------------
  -- escritura de registros + orquestacion
  ---------------------------------------------------------------------------
  process(clk)
    variable func : std_logic_vector(2 downto 0);
  begin
    if rising_edge(clk) then
      cor_start   <= '0';
      fir_push    <= '0';
      fir_flush   <= '0';
      fir_coef_we <= '0';
      fft_wr_en   <= '0';
      fft_start   <= '0';
      uns_wr_en   <= '0';
      uns_start   <= '0';
      dr_we       <= '0';
      -- por defecto el puerto de lectura BRAM sigue a la direccion MMIO (widx);
      -- los estados de operacion internos lo sobreescriben cuando cargan datos.
      dr_raddr    <= widx;

      if rst='1' then
        ctrl_r <= (others=>'0'); log2n_r<=(others=>'0'); firlen_r<=(others=>'0');
        corda_r<=(others=>'0'); cordb_r<=(others=>'0');
        reslo_r<=(others=>'0'); reshi_r<=(others=>'0');
        status_busy<='0'; status_done<='0'; status_err<='0';
        op_state<=OP_IDLE;
      else
        -- escrituras
        if we='1' then
          if is_data='1' then
            dr_waddr <= widx; dr_wdata <= wdata; dr_we <= '1';
          elsif is_coef='1' then
            coef_r(cidx) <= wdata;
          else
            case addr(7 downto 0) is
              when x"04" =>
                ctrl_r <= wdata;
                -- START (bit0)
                if wdata(0)='1' then
                  func := wdata(3 downto 1);
                  cur_func <= func;
                  status_busy <= '1';
                  status_done <= '0';
                  status_err  <= '0';
                  -- FLUSH (bit5) para FIR
                  if wdata(5)='1' then fir_flush <= '1'; end if;
                  real_pack_r <= wdata(4);
                  op_state <= OP_RUN;
                  -- lanzar el datapath adecuado
                  case func is
                    when F_CROT => cor_mode<='0'; cor_start<='1';
                    when F_CVEC => cor_mode<='1'; cor_start<='1';
                    when F_FIR  =>
                      -- FIR modo bloque: cargar coefs, luego procesar DATA_LEN muestras
                      blk_n  <= to_integer(unsigned(datalen_r(11 downto 0)));
                      fir_ci <= 0;
                      xfer_idx <= 0;
                      fir_flush <= '1';   -- limpiar linea de retardo
                      op_state <= OP_FIR_LOADCO;
                    when F_FFTF =>
                      if wdata(4)='1' then
                        -- FFT real-empacada: 2N reales -> compleja de N -> unsplit
                        rp_n2 <= to_integer(unsigned(datalen_r(11 downto 0)));
                        rp_n  <= to_integer(unsigned(datalen_r(11 downto 0)))/2;
                        fft_inv<='0';
                        fft_log2n<=std_logic_vector(to_unsigned(
                          to_integer(unsigned(log2n_r(3 downto 0)))-1,4)); -- log2(N)=log2(2N)-1
                        fft_n <= 2**(to_integer(unsigned(log2n_r(3 downto 0)))-1);
                        uns_log2n2 <= log2n_r(3 downto 0);
                        xfer_idx<=0; op_state<=OP_RP_LOAD;
                      else
                        fft_inv<='0'; fft_log2n<=log2n_r(3 downto 0);
                        fft_n <= 2**to_integer(unsigned(log2n_r(3 downto 0)));
                        xfer_idx<=0; op_state<=OP_FFT_LOAD;
                      end if;
                    when F_FFTI =>
                      fft_inv<='1'; fft_log2n<=log2n_r(3 downto 0);
                      fft_n <= 2**to_integer(unsigned(log2n_r(3 downto 0)));
                      xfer_idx<=0; op_state<=OP_FFT_LOAD;
                    when others => null;
                  end case;
                end if;
              when x"08" =>
                -- W1C sobre DONE/ERR
                if wdata(1)='1' then status_done<='0'; end if;
                if wdata(2)='1' then status_err <='0'; end if;
              when x"0C" => log2n_r  <= wdata;
              when x"10" => firlen_r <= wdata;
              when x"14" => corda_r  <= wdata;
              when x"18" => cordb_r  <= wdata;
              when x"24" => datalen_r <= wdata;
              when others => null;
            end case;
          end if;
        end if;

        -- FSM de operacion: capturar DONE de los datapaths
        case op_state is
          when OP_RUN =>
            case cur_func is
              when F_CROT | F_CVEC =>
                if cor_done='1' then
                  if cur_func=F_CROT then
                    reslo_r <= std_logic_vector(resize(signed(cor_xout),32)); -- cos
                    reshi_r <= std_logic_vector(resize(signed(cor_yout),32)); -- sin
                  else
                    reslo_r <= std_logic_vector(resize(signed(cor_xout),32)); -- mag
                    reshi_r <= std_logic_vector(resize(signed(cor_zout),32)); -- fase
                  end if;
                  op_state <= OP_FINISH;
                end if;
              when F_FIR =>
                if fir_valid='1' then
                  reslo_r <= std_logic_vector(resize(signed(fir_yout),32));
                  op_state <= OP_FINISH;
                end if;
              when others =>
                op_state <= OP_FINISH;   -- FFT placeholder
            end case;

          when OP_FFT_LOAD =>
            -- lectura BRAM latencia 2 (dr_raddr reg + dr_rdata reg). Poner
            -- dr_raddr=xfer_idx ; el dato de xfer_idx-2 esta en dr_rdata.
            if xfer_idx < fft_n then
              dr_raddr <= xfer_idx;
            end if;
            if xfer_idx > 1 then
              fft_wr_idx <= std_logic_vector(to_unsigned(xfer_idx-2,10));
              fft_wr_re  <= dr_rdata(15 downto 0);
              fft_wr_im  <= dr_rdata(31 downto 16);
              fft_wr_en  <= '1';
            end if;
            if xfer_idx = fft_n + 1 then
              xfer_idx <= 0;
              op_state <= OP_FFT_RUN;
              fft_start <= '1';
            else
              xfer_idx <= xfer_idx + 1;
            end if;

          when OP_FFT_RUN =>
            if fft_done='1' then
              xfer_idx <= 0;
              op_state <= OP_FFT_STORE;
            end if;

          when OP_FFT_STORE =>
            -- leer buffer de fft y escribir de vuelta a DATA.
            -- fft_dp BRAM: rd_idx -> rd_re/rd_im con 2 ciclos de latencia
            -- (ADDRA registrado + DOUTA registrado). Skew de 2: cuando el
            -- contador va por xfer_idx, el dato valido es el de xfer_idx-2.
            -- latencia total lectura FFT en OP_STORE: 1 (reg fft_rd_idx) +
            -- 2 (BRAM: ADDRA reg + DOUTA reg) = 3 ciclos. Skew de 3.
            if xfer_idx < fft_n then
              fft_rd_idx <= std_logic_vector(to_unsigned(xfer_idx,10));
            end if;
            if xfer_idx > 2 then
              dr_waddr <= xfer_idx-3; dr_wdata <= fft_rd_im & fft_rd_re; dr_we <= '1';
            end if;
            if xfer_idx = fft_n + 2 then
              op_state <= OP_FINISH;
            else
              xfer_idx <= xfer_idx + 1;
            end if;

          ------------------------------------------------------------------
          -- FIR modo bloque
          ------------------------------------------------------------------
          when OP_FIR_LOADCO =>
            -- cargar 32 coeficientes coef_r -> fir_dp
            fir_coef_idx <= std_logic_vector(to_unsigned(fir_ci,6));
            fir_coef_dat <= coef_r(fir_ci)(15 downto 0);
            fir_coef_we  <= '1';
            if fir_ci = 31 then
              fir_ci <= 0;
              xfer_idx <= 0;
              op_state <= OP_FIR_PUSH;
            else
              fir_ci <= fir_ci + 1;
            end if;

          when OP_FIR_PUSH =>
            -- poner direccion ; latencia BRAM 2 ciclos hasta dr_rdata
            dr_raddr <= xfer_idx;
            op_state <= OP_FIR_PUSH1B;

          when OP_FIR_PUSH1B =>
            -- ciclo de espera (latencia BRAM)
            op_state <= OP_FIR_PUSH2;

          when OP_FIR_PUSH2 =>
            -- dato disponible en dr_rdata (2 ciclos tras poner dr_raddr)
            fir_xin  <= dr_rdata(15 downto 0);
            fir_push <= '1';
            op_state <= OP_FIR_WAIT;

          when OP_FIR_WAIT =>
            -- esperar valid, escribir salida en DATA[xfer_idx] in-place
            if fir_valid='1' then
              dr_waddr <= xfer_idx; dr_wdata <= x"0000" & fir_yout; dr_we <= '1';
              if xfer_idx = blk_n - 1 then
                op_state <= OP_FINISH;
              else
                xfer_idx <= xfer_idx + 1;
                op_state <= OP_FIR_PUSH;
              end if;
            end if;

          ------------------------------------------------------------------
          -- FFT real-empacada: DATA(2N reales) -> fft_dp(N) -> unsplit -> DATA
          ------------------------------------------------------------------
          when OP_RP_LOAD =>
            -- empacar z[n]=x[2n]+j x[2n+1]. Lectura BRAM serializada:
            -- poner dir 2n ; latencia 2 ; leer 2n ; poner dir 2n+1 ; latencia 2 ;
            -- leer 2n+1 y escribir z[n].
            dr_raddr <= 2*xfer_idx;
            op_state <= OP_RP_LOAD1B;

          when OP_RP_LOAD1B =>
            op_state <= OP_RP_LOAD2;

          when OP_RP_LOAD2 =>
            -- dr_rdata = x[2n] (re). Guardar y pedir x[2n+1].
            fft_wr_re <= dr_rdata(15 downto 0);
            dr_raddr  <= 2*xfer_idx + 1;
            op_state  <= OP_RP_LOAD2B;

          when OP_RP_LOAD2B =>
            op_state <= OP_RP_LOAD3;

          when OP_RP_LOAD3 =>
            -- dr_rdata = x[2n+1] (im). Escribir z[n] al fft.
            fft_wr_idx <= std_logic_vector(to_unsigned(xfer_idx,10));
            fft_wr_im  <= dr_rdata(15 downto 0);
            fft_wr_en  <= '1';
            if xfer_idx = rp_n - 1 then
              xfer_idx <= 0;
              op_state <= OP_RP_FFTRUN;
              fft_start <= '1';
            else
              xfer_idx <= xfer_idx + 1;
              op_state <= OP_RP_LOAD;
            end if;

          when OP_RP_FFTRUN =>
            if fft_done='1' then
              xfer_idx <= 0;
              op_state <= OP_RP_TOUNS;
            end if;

          when OP_RP_TOUNS =>
            -- copiar Z (salida fft) -> buffer del unsplit.
            -- fft_dp BRAM: latencia 3 (reg fft_rd_idx + 2 BRAM). Skew de 3.
            if xfer_idx <= rp_n then
              fft_rd_idx <= std_logic_vector(to_unsigned(xfer_idx,10));
            end if;
            if xfer_idx > 2 then
              uns_wr_idx <= std_logic_vector(to_unsigned(xfer_idx-3,10));
              uns_wr_zr  <= fft_rd_re;
              uns_wr_zi  <= fft_rd_im;
              uns_wr_en  <= '1';
            end if;
            if xfer_idx = rp_n + 2 then
              xfer_idx <= 0;
              op_state <= OP_RP_UNSRUN;
              uns_start <= '1';
            else
              xfer_idx <= xfer_idx + 1;
            end if;

          when OP_RP_UNSRUN =>
            if uns_done='1' then
              xfer_idx <= 0;
              op_state <= OP_RP_STORE;
            end if;

          when OP_RP_STORE =>
            -- unsplit produce X[0..N]; escribir a DATA in-place (skew 1 ciclo)
            if xfer_idx <= rp_n then
              uns_rd_idx <= std_logic_vector(to_unsigned(xfer_idx,10));
            end if;
            if xfer_idx > 0 then
              dr_waddr <= xfer_idx-1; dr_wdata <= uns_rd_xi & uns_rd_xr; dr_we <= '1';
            end if;
            if xfer_idx = rp_n + 1 then
              op_state <= OP_FINISH;
            else
              xfer_idx <= xfer_idx + 1;
            end if;

          when OP_FINISH =>
            status_busy <= '0';
            status_done <= '1';   -- sticky
            op_state <= OP_IDLE;

          when others => null;
        end case;

        -- carga de coeficientes al FIR: al arrancar FIR, volcar coef_r -> fir
        -- (simplificado Layer 2: se cargan via secuencia dedicada en el TB)
      end if;
    end if;
  end process;

  -- conexion directa de una muestra FIR (Layer 2: 1 muestra por START)
  -- fir_xin ahora lo controla la FSM (OP_FIR_PUSH)

end architecture;
