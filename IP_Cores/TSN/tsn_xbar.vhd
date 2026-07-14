-- tsn_xbar.vhd - Clasificador + crossbar 4x4 + arbitro RR del switch TSN
-- Semantica identica al schedule() del oraculo Python:
--   * clasificacion por MAC destino: bit I/G (desc_mac(40)) => broadcast/
--     multicast a todos menos el ingreso; hit en tabla => puerto (o filtrado
--     si == ingreso); miss => flooding a todos menos el ingreso
--   * cada salida ociosa hace RR sobre las entradas elegibles (clasificadas,
--     no drenandose, con esa salida pendiente); la entrada queda bloqueada
--     mientras se drena (HOL documentado)
--   * multicast SECUENCIAL: tras cada destino, rd_rewind y re-arbitraje;
--     rd_commit + desc_pop solo tras el ultimo destino
--   * filtrado (dst==ingreso): auto-drenaje con descarte (sin TX)
-- Tabla: 16 entradas (mac48 + puerto2 + valid), escritura sincrona MMIO;
-- lookup combinacional, gana el indice mas bajo.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tsn_pkg.all;

entity tsn_xbar is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- lado ingress (x4)
    desc_valid : in  std_logic_vector(3 downto 0);
    desc_mac   : in  mac_arr4;
    desc_len   : in  len_arr4;
    desc_pop   : out std_logic_vector(3 downto 0);
    rd_en      : out std_logic_vector(3 downto 0);
    rd_data    : in  byte_arr4;
    rd_valid   : in  std_logic_vector(3 downto 0);
    rd_commit  : out std_logic_vector(3 downto 0);
    rd_rewind  : out std_logic_vector(3 downto 0);
    -- lado TX (x4)
    tx_data    : out byte_arr4;
    tx_valid   : out std_logic_vector(3 downto 0);
    tx_last    : out std_logic_vector(3 downto 0);
    tx_ready   : in  std_logic_vector(3 downto 0);
    -- escritura de tabla (MMIO, 3 pasos: mac_lo/mac_hi cargados fuera)
    tbl_wr     : in  std_logic;
    tbl_idx    : in  std_logic_vector(3 downto 0);
    tbl_mac    : in  std_logic_vector(47 downto 0);
    tbl_port   : in  std_logic_vector(1 downto 0);
    tbl_vld    : in  std_logic;
    -- pulsos de contadores por salida
    cnt_tx     : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of tsn_xbar is
  -- tabla de forwarding
  type tmac_t is array (0 to 15) of std_logic_vector(47 downto 0);
  type tprt_t is array (0 to 15) of std_logic_vector(1 downto 0);
  signal t_mac : tmac_t := (others => (others => '0'));
  signal t_prt : tprt_t := (others => (others => '0'));
  signal t_vld : std_logic_vector(15 downto 0) := (others => '0');

  -- estado por entrada
  type ist_t is (I_IDLE, I_RDY, I_LOCK, I_DISC, I_FIN, I_GAP, I_REW);
  type ist_arr is array (0 to 3) of ist_t;
  signal ist   : ist_arr := (others => I_IDLE);
  type dst_arr is array (0 to 3) of std_logic_vector(3 downto 0);
  signal dests : dst_arr := (others => (others => '0'));
  signal ilen  : len_arr4 := (others => (others => '0'));
  type cnt_arr is array (0 to 3) of unsigned(10 downto 0);
  signal icnt  : cnt_arr := (others => (others => '0'));

  -- estado por salida
  type sel_arr is array (0 to 3) of integer range 0 to 3;
  signal obusy : std_logic_vector(3 downto 0) := (others => '0');
  signal osel  : sel_arr := (others => 0);
  signal rr    : sel_arr := (others => 0);

  -- pulsos registrados hacia las FIFOs
  signal pop_r, rcm_r, rrw_r : std_logic_vector(3 downto 0) := (others => '0');

  function onehot(p : integer) return std_logic_vector is
    variable v : std_logic_vector(3 downto 0) := (others => '0');
  begin
    v(p) := '1'; return v;
  end;
begin
  desc_pop  <= pop_r;
  rd_commit <= rcm_r;
  rd_rewind <= rrw_r;

  p_tbl : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        t_vld <= (others => '0');
      elsif tbl_wr = '1' then
        t_mac(to_integer(unsigned(tbl_idx))) <= tbl_mac;
        t_prt(to_integer(unsigned(tbl_idx))) <= tbl_port;
        t_vld(to_integer(unsigned(tbl_idx))) <= tbl_vld;
      end if;
    end if;
  end process;

  p_sched : process(clk)
    variable vd    : std_logic_vector(3 downto 0);
    variable hit   : boolean;
    variable hp    : integer range 0 to 3;
    variable vtake : std_logic_vector(3 downto 0);
    variable i     : integer range 0 to 3;
    variable xfer  : boolean;
  begin
    if rising_edge(clk) then
      pop_r  <= (others => '0');
      rcm_r  <= (others => '0');
      rrw_r  <= (others => '0');
      cnt_tx <= (others => '0');
      if rst = '1' then
        ist   <= (others => I_IDLE);
        obusy <= (others => '0');
        rr    <= (others => 0);
      else
        -- 1) transferencias en curso: contar y cerrar
        for o in 0 to 3 loop
          if obusy(o) = '1' then
            i := osel(o);
            xfer := tx_ready(o) = '1' and rd_valid(i) = '1'
                    and icnt(i) < ilen(i);
            if xfer then
              if icnt(i) = ilen(i) - 1 then
                -- ultimo byte entregado a esta salida
                obusy(o)  <= '0';
                cnt_tx(o) <= '1';
                if (dests(i) and not onehot(o)) = "0000" then
                  rcm_r(i) <= '1';       -- ultimo destino: liberar y avanzar
                  pop_r(i) <= '1';
                  ist(i)   <= I_FIN;
                else
                  rrw_r(i) <= '1';       -- quedan destinos: re-leer
                  ist(i)   <= I_REW;
                end if;
                dests(i)(o) <= '0';
              else
                icnt(i) <= icnt(i) + 1;
              end if;
            end if;
          end if;
        end loop;
        -- 2) auto-drenaje de tramas filtradas (dst==ingreso)
        for k in 0 to 3 loop
          if ist(k) = I_DISC and rd_valid(k) = '1' and icnt(k) < ilen(k) then
            if icnt(k) = ilen(k) - 1 then
              rcm_r(k) <= '1';
              pop_r(k) <= '1';
              ist(k)   <= I_FIN;
            else
              icnt(k) <= icnt(k) + 1;
            end if;
          end if;
        end loop;
        -- 3) transiciones de estados muertos
        for k in 0 to 3 loop
          case ist(k) is
            when I_FIN => ist(k) <= I_GAP;   -- pulso activo este ciclo
            when I_GAP => ist(k) <= I_IDLE;  -- desc_pop ya asentado
            when I_REW => ist(k) <= I_RDY;   -- rd_rewind ya asentado
            when others => null;
          end case;
        end loop;
        -- 4) clasificacion de nuevas tramas en cabeza
        for k in 0 to 3 loop
          if ist(k) = I_IDLE and desc_valid(k) = '1' then
            if desc_mac(k)(40) = '1' then
              vd := not onehot(k);           -- broadcast/multicast (bit I/G)
            else
              hit := false; hp := 0;
              for j in 15 downto 0 loop      -- gana el indice mas bajo
                if t_vld(j) = '1' and t_mac(j) = desc_mac(k) then
                  hit := true; hp := to_integer(unsigned(t_prt(j)));
                end if;
              end loop;
              if not hit then
                vd := not onehot(k);         -- miss: flooding
              elsif hp = k then
                vd := (others => '0');       -- filtrada
              else
                vd := onehot(hp);
              end if;
            end if;
            ilen(k) <= desc_len(k);
            icnt(k) <= (others => '0');
            if vd = "0000" then
              dests(k) <= (others => '0');
              ist(k)   <= I_DISC;
            else
              dests(k) <= vd;
              ist(k)   <= I_RDY;
            end if;
          end if;
        end loop;
        -- 5) emparejamiento: salidas ociosas hacen RR sobre entradas listas
        vtake := (others => '0');
        for o in 0 to 3 loop
          if obusy(o) = '0' then
            for k in 0 to 3 loop
              i := (rr(o) + k) mod 4;
              if ist(i) = I_RDY and vtake(i) = '0' and dests(i)(o) = '1' then
                osel(o)  <= i;
                obusy(o) <= '1';
                rr(o)    <= (i + 1) mod 4;
                icnt(i)  <= (others => '0');
                ist(i)   <= I_LOCK;
                vtake(i) := '1';
                exit;
              end if;
            end loop;
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- datapath combinacional del crossbar
  p_comb : process(all)
    variable i : integer range 0 to 3;
  begin
    rd_en    <= (others => '0');
    tx_data  <= (others => (others => '0'));
    tx_valid <= (others => '0');
    tx_last  <= (others => '0');
    for o in 0 to 3 loop
      if obusy(o) = '1' then
        i := osel(o);
        if ist(i) = I_LOCK and icnt(i) < ilen(i) then
          tx_data(o)  <= rd_data(i);
          tx_valid(o) <= rd_valid(i);
          if icnt(i) = ilen(i) - 1 then
            tx_last(o) <= rd_valid(i);
          end if;
          rd_en(i) <= tx_ready(o) and rd_valid(i);
        end if;
      end if;
    end loop;
    for k in 0 to 3 loop
      if ist(k) = I_DISC and icnt(k) < ilen(k) then
        rd_en(k) <= rd_valid(k);           -- descarte a velocidad de FIFO
      end if;
    end loop;
  end process;
end architecture;
