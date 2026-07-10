-- ============================================================================
-- spw_tx.vhd -- Motor transmisor SpaceWire (ECSS-E-ST-50-12C)
-- ============================================================================
-- Codificacion Data-Strobe: exactamente una transicion (D o S) por bit.
-- Caracteres:
--   N-Char dato : P, 0, d0..d7 (LSB primero)            (10 bits)
--   L-Char      : P, 1, b1, b2                          (4 bits)
--                 FCT=00  EOP=01  EEP=10  ESC=11  (b1 primero, b2 despues)
--   NULL        : ESC + FCT
--   Time-Code   : ESC + N-Char(dato = time_val)
-- Paridad IMPAR: P cubre los bits de payload del caracter ANTERIOR mas el
-- propio P y el flag actual (numero de unos impar).
-- Prioridad en frontera de caracter: Time-Code > FCT > N-Char > NULL.
-- La secuencia ESC+X forzada (NULL o Time-Code) nunca se interrumpe.
--
-- div = ciclos de clk por bit (minimo 2). Con clk = 100 MHz:
--   div=10 -> 10 Mbit/s, div=5 -> 20, div=4 -> 25, div=2 -> 50.
--
-- en   = '0' mantiene el motor en reset sincrono (patron EN_x del MMIO).
-- txen = habilitacion del transmisor por la FSM del enlace (Started..Run).
--        Con txen='0' D y S se llevan a '0' (reset del enlace, ECSS 8.4.2).
-- allow_fct   : la FSM permite emitir FCTs (Connecting..Run).
-- allow_nchar : la FSM permite emitir N-Chars y Time-Codes (Run).
-- Peticiones por nivel con ack de 1 ciclo al arrancar el caracter.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_tx is
  port (
    clk         : in  std_logic;
    arstn       : in  std_logic;
    en          : in  std_logic;
    div         : in  std_logic_vector(7 downto 0);
    txen        : in  std_logic;
    allow_fct   : in  std_logic;
    allow_nchar : in  std_logic;
    -- peticion de FCT (control de flujo, desde la capa de enlace)
    fct_req     : in  std_logic;
    fct_ack     : out std_logic;
    -- peticion de Time-Code
    time_req    : in  std_logic;
    time_val    : in  std_logic_vector(7 downto 0);
    time_ack    : out std_logic;
    -- N-Chars: b8='0' dato d7..d0; b8='1' -> b0='0' EOP, b0='1' EEP
    d_valid     : in  std_logic;
    d_data      : in  std_logic_vector(8 downto 0);
    d_ack       : out std_logic;
    -- salida Data-Strobe
    dout        : out std_logic;
    sout        : out std_logic
  );
end entity spw_tx;

architecture rtl of spw_tx is

  type force_t is (F_NONE, F_FCT, F_TIME);

  signal cnt      : unsigned(7 downto 0)         := (others => '0');
  signal bits     : std_logic_vector(9 downto 0) := (others => '0');
  signal blen     : unsigned(3 downto 0)         := (others => '0');
  signal bidx     : unsigned(3 downto 0)         := (others => '0');
  signal acc      : std_logic                    := '0';  -- XOR payload char previo
  signal dreg     : std_logic                    := '0';
  signal sreg     : std_logic                    := '0';
  signal running  : std_logic                    := '0';
  signal force_r  : force_t                      := F_NONE;
  signal time_lat : std_logic_vector(7 downto 0) := (others => '0');

begin

  dout <= dreg;
  sout <= sreg;

  main : process (clk, arstn)
    variable v_f    : std_logic;
    variable v_pay  : std_logic_vector(7 downto 0);
    variable v_plen : integer range 2 to 8;
    variable v_p    : std_logic;
    variable v_b    : std_logic;
    variable v_bits : std_logic_vector(9 downto 0);
    variable v_acc  : std_logic;
    variable divv   : unsigned(7 downto 0);

    -- Selecciona el siguiente caracter en frontera. Lee acc (payload del
    -- caracter que acaba de terminar) para calcular P, y deja en acc el
    -- XOR del payload del caracter nuevo.
    procedure select_char is
    begin
      v_f    := '1';
      v_pay  := (others => '0');
      v_plen := 2;

      if force_r = F_FCT then                      -- segunda mitad de NULL
        v_pay(0) := '0'; v_pay(1) := '0';
        force_r  <= F_NONE;
      elsif force_r = F_TIME then                  -- segunda mitad de Time-Code
        v_f      := '0';
        v_pay    := time_lat;
        v_plen   := 8;
        force_r  <= F_NONE;
      elsif time_req = '1' and allow_nchar = '1' then
        v_pay(0) := '1'; v_pay(1) := '1';          -- ESC
        time_lat <= time_val;
        force_r  <= F_TIME;
        time_ack <= '1';
      elsif fct_req = '1' and allow_fct = '1' then
        v_pay(0) := '0'; v_pay(1) := '0';          -- FCT
        fct_ack  <= '1';
      elsif d_valid = '1' and allow_nchar = '1' then
        if d_data(8) = '1' then
          if d_data(0) = '0' then
            v_pay(0) := '0'; v_pay(1) := '1';      -- EOP
          else
            v_pay(0) := '1'; v_pay(1) := '0';      -- EEP
          end if;
        else
          v_f    := '0';
          v_pay  := d_data(7 downto 0);
          v_plen := 8;
        end if;
        d_ack <= '1';
      else
        v_pay(0) := '1'; v_pay(1) := '1';          -- ESC de NULL
        force_r  <= F_FCT;
      end if;

      -- paridad impar: acc(prev) xor P xor F = '1'
      v_p := not (acc xor v_f);

      v_bits    := (others => '0');
      v_bits(0) := v_p;
      v_bits(1) := v_f;
      for i in 0 to 7 loop
        if i < v_plen then
          v_bits(2 + i) := v_pay(i);
        end if;
      end loop;
      bits <= v_bits;
      blen <= to_unsigned(2 + v_plen, 4);
      bidx <= (others => '0');

      v_acc := '0';
      for i in 0 to 7 loop
        if i < v_plen then
          v_acc := v_acc xor v_pay(i);
        end if;
      end loop;
      acc <= v_acc;
    end procedure;

  begin
    if arstn = '0' then
      cnt      <= (others => '0');
      bits     <= (others => '0');
      blen     <= (others => '0');
      bidx     <= (others => '0');
      acc      <= '0';
      dreg     <= '0';
      sreg     <= '0';
      running  <= '0';
      force_r  <= F_NONE;
      time_lat <= (others => '0');
      fct_ack  <= '0';
      time_ack <= '0';
      d_ack    <= '0';
    elsif rising_edge(clk) then
      fct_ack  <= '0';
      time_ack <= '0';
      d_ack    <= '0';

      divv := unsigned(div);
      if divv < 2 then
        divv := to_unsigned(2, 8);
      end if;

      if en = '0' or txen = '0' then
        cnt     <= (others => '0');
        bidx    <= (others => '0');
        acc     <= '0';
        dreg    <= '0';
        sreg    <= '0';
        running <= '0';
        force_r <= F_NONE;
      else
        if running = '0' then
          select_char;
          running <= '1';
          cnt     <= (others => '0');
        else
          if cnt = divv - 1 then
            cnt <= (others => '0');
            -- emitir bits(bidx) con codificacion DS
            v_b := bits(to_integer(bidx));
            if v_b /= dreg then
              dreg <= v_b;                -- transiciona D, S quieto
            else
              sreg <= not sreg;           -- transiciona S, D quieto
            end if;
            if bidx = blen - 1 then
              select_char;
            else
              bidx <= bidx + 1;
            end if;
          else
            cnt <= cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process main;

end architecture rtl;
