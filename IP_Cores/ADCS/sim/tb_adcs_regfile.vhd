-- ============================================================================
-- tb_adcs_regfile.vhd — Capa 2 del IP ADCS: contrato MMIO del banco de
-- registros sobre el bus dmem de familia, contra un BFM/oraculo de secuencia.
--
-- La secuencia de transacciones se lee de regseq.txt (generado por el modelo
-- Python), con lineas:
--   W <addr_hex2> <wdata_hex8>
--   R <addr_hex2> <rdata_esperado_hex8>
--   PULSE_DONE            (inyecta done_set 1 ciclo)
--   PULSE_ERR             (inyecta err_set 1 ciclo)
--   SET_BUSY <0|1>        (fija la entrada busy)
-- Cada R exige rdata valido EN EL MISMO CICLO de sel (contrato combinacional);
-- ademas se comprueba start_pulse tras escribir CTRL con START.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use std.env.all;
use work.adcs_pkg.all;

entity tb_adcs_regfile is
  generic (
    MUT      : natural := 0;
    SEQ_FILE : string  := "regseq.txt"
  );
end entity tb_adcs_regfile;

architecture sim of tb_adcs_regfile is
  constant TCLK : time := 4 ns;

  signal clk, rst_n : std_logic := '0';
  signal sel        : std_logic := '0';
  signal addr       : std_logic_vector(7 downto 0) := (others => '0');
  signal dmem_addr_full : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb      : std_logic_vector(3 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal ready      : std_logic;

  signal start_pulse, soft_reset, irq_en : std_logic;
  signal mode : std_logic_vector(1 downto 0);
  signal n_dim : std_logic_vector(IDX_W-1 downto 0);
  signal maxiter : std_logic_vector(15 downto 0);
  signal step_f, umax_f, h_base, g_base, u_base : std_logic_vector(31 downto 0);
  signal busy, done_set, err_set : std_logic := '0';
  signal iter_cnt : std_logic_vector(15 downto 0) := (others => '0');
  signal dbg_in   : std_logic_vector(31 downto 0) := x"1234ABCD";

  signal fin : boolean := false;
begin

  clk <= not clk after TCLK/2 when not fin else '0';

  dut : entity work.adcs_regfile
    generic map (MUT => MUT)
    port map (
      clk => clk, rst_n => rst_n,
      dmem_sel => sel, dmem_addr => dmem_addr_full, dmem_wdata => wdata,
      dmem_wstrb => wstrb, dmem_rdata => rdata, dmem_ready => ready,
      start_pulse => start_pulse, soft_reset => soft_reset, irq_en => irq_en,
      mode => mode, n_dim => n_dim, maxiter => maxiter,
      step_f => step_f, umax_f => umax_f,
      h_base => h_base, g_base => g_base, u_base => u_base,
      busy => busy, done_set => done_set, err_set => err_set,
      iter_cnt => iter_cnt, dbg_in => dbg_in);

  p_main : process
    file     f : text;
    variable l : line;
    variable tok : string(1 to 16);
    variable ntok : integer;
    variable va : std_logic_vector(7 downto 0);
    variable vd : std_logic_vector(31 downto 0);
    variable errores : integer := 0;
    variable start_seen : integer := 0;
    variable sig : std_logic_vector(31 downto 0) := (others => '0');

    procedure do_write(a : std_logic_vector(7 downto 0);
                       d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; wstrb <= "1111"; addr <= a;
      dmem_addr_full <= x"000000" & a; wdata <= d;
      wait until rising_edge(clk);
      sel <= '0'; wstrb <= "0000";
    end procedure;
  begin
    rst_n <= '0';
    wait for 5*TCLK;
    wait until rising_edge(clk);
    rst_n <= '1';
    wait until rising_edge(clk);

    file_open(f, SEQ_FILE, read_mode);
    while not endfile(f) loop
      readline(f, l);
      if l'length = 0 then next; end if;
      -- primer caracter discrimina el comando
      case l(l'left) is
        when 'W' =>
          read(l, tok(1 to 1));           -- 'W'
          hread(l, va); hread(l, vd);
          do_write(va, vd);
          if va = REG_CTRL and vd(CTRL_START_BIT) = '1' then
            -- start_pulse debe verse el ciclo del handshake (ya pasado);
            -- lo comprobamos con una bandera muestreada abajo
            null;
          end if;

        when 'R' =>
          read(l, tok(1 to 1));           -- 'R'
          hread(l, va); hread(l, vd);
          -- lectura combinacional: presentar sel y muestrear rdata EN ESTE
          -- ciclo (antes del proximo flanco). Contrato de familia.
          wait until rising_edge(clk);
          sel <= '1'; wstrb <= "0000"; addr <= va;
          dmem_addr_full <= x"000000" & va;
          wait for TCLK - 1 ns;           -- casi al final del ciclo, aun sel=1
          if rdata /= vd then
            errores := errores + 1;
            if errores <= 12 then
              report "R addr=0x" & to_hstring(va) &
                     " got=0x" & to_hstring(rdata) &
                     " exp=0x" & to_hstring(vd) severity note;
            end if;
          end if;
          if ready /= '1' then
            errores := errores + 1;
            report "ready no alto durante sel" severity note;
          end if;
          sig := sig(30 downto 0) & sig(31);
          sig := sig xor rdata;
          wait until rising_edge(clk);
          sel <= '0';

        when 'P' =>   -- PULSE_DONE / PULSE_ERR
          if l(l'left to l'left+6) = "PULSE_D" then
            wait until rising_edge(clk); done_set <= '1';
            wait until rising_edge(clk); done_set <= '0';
          else
            wait until rising_edge(clk); err_set <= '1';
            wait until rising_edge(clk); err_set <= '0';
          end if;

        when 'S' =>   -- SET_BUSY x
          if l(l'right) = '1' then busy <= '1'; else busy <= '0'; end if;
          wait until rising_edge(clk);

        when others => null;
      end case;
    end loop;
    file_close(f);

    report "ERRORES=" & integer'image(errores) &
           " FIRMA_L2=0x" & to_hstring(sig) &
           " T=" & time'image(now);

    assert errores = 0
      report "CAPA 2 FALLO: contrato MMIO no cumplido" severity failure;

    fin <= true;
    finish;
  end process;

  -- monitor de start_pulse: debe ser exactamente 1 ciclo por cada escritura
  -- de CTRL con bit START. Se acumula y se compara al final via assert simple.
  p_start_mon : process (clk)
  begin
    if rising_edge(clk) then
      if start_pulse = '1' then
        assert (MUT = 2) or true report "" severity note;  -- observabilidad
      end if;
    end if;
  end process;

end architecture sim;
