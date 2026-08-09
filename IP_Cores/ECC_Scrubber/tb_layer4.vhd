-- tb_layer4.vhd - Testbench Layer 4 del SoC + firmware. Core 20 HERCOSSNUX.
-- Precarga IMEM con ecc_fw.mem y la RAM local con la config (cfg_*.txt).
-- Corre el firmware, espera el doorbell (irq_out), y lee de la RAM local los
-- resultados que el firmware escribio (CE, DED, sticky, firma). Compara contra
-- los valores esperados pasados por generic. PASS si coinciden.
--
-- Como la RAM local es interna al SoC, el TB no puede leerla por un puerto. En su
-- lugar, exponemos una "sonda": el SoC deja dbg_pc, y para leer la RAM local
-- reusamos un truco de simulacion: instanciamos el SoC con la RAM local accesible
-- via un alias de senal jerarquica. GHDL permite external names para tipos
-- estandar; aqui leemos la memoria por un puerto de depuracion agregado.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity tb_layer4 is
  generic (
    CFG_INIT  : string  := "cfg_a.txt";
    EXP_CE    : natural := 2;
    EXP_DED   : natural := 1;
    EXP_FSYN  : natural := 520;
    EXP_LSYN  : natural := 547;
    EXP_SIG   : std_logic_vector(31 downto 0) := x"db5e11bb";
    RUN_TAG   : string  := "A"
  );
end entity;

architecture sim of tb_layer4 is
  signal aclk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal irq_out : std_logic;
  signal dbg_pc  : word_t;
  signal probe_addr : word_t := (others => '0');
  signal probe_data : word_t;
begin
  aclk <= not aclk after 5 ns;

  dut : entity work.ecc_soc_top
    generic map (DEPTH => 256, SCRUB_DEPTH => 32,
                 IMEM_INIT => "ecc_fw.mem", LOCAL_INIT => CFG_INIT,
                 DONE_WORD => 127)
    port map (aclk => aclk, aresetn => aresetn, irq_out => irq_out, dbg_pc => dbg_pc,
              dbg_local_addr => probe_addr, dbg_local_rdata => probe_data);

  stim : process
    variable ce, ded, fsyn, lsyn : natural;
    variable sig : std_logic_vector(31 downto 0);
    variable errors : natural := 0;

    procedure probe(byte_off : natural; val : out std_logic_vector(31 downto 0)) is
    begin
      probe_addr <= std_logic_vector(to_unsigned(byte_off, 32));
      wait for 1 ns;
      val := probe_data;
    end procedure;
    variable tmp : std_logic_vector(31 downto 0);
  begin
    aresetn <= '0';
    wait for 40 ns;
    aresetn <= '1';

    -- esperar doorbell
    for i in 0 to 200000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;
    assert irq_out = '1'
      report "RUN " & RUN_TAG & ": el firmware no toco el doorbell a tiempo"
      severity failure;
    wait for 20 ns;

    probe(16#10#, tmp); ce   := to_integer(unsigned(tmp));
    probe(16#14#, tmp); ded  := to_integer(unsigned(tmp));
    probe(16#18#, tmp); fsyn := to_integer(unsigned(tmp));
    probe(16#1C#, tmp); lsyn := to_integer(unsigned(tmp));
    probe(16#20#, sig);

    if ce /= EXP_CE then
      errors := errors + 1;
      report "RUN " & RUN_TAG & ": CE=" & integer'image(ce) &
             " exp=" & integer'image(EXP_CE) severity warning;
    end if;
    if ded /= EXP_DED then
      errors := errors + 1;
      report "RUN " & RUN_TAG & ": DED=" & integer'image(ded) &
             " exp=" & integer'image(EXP_DED) severity warning;
    end if;
    if fsyn /= EXP_FSYN then
      errors := errors + 1;
      report "RUN " & RUN_TAG & ": FIRST_SYN=" & integer'image(fsyn) &
             " exp=" & integer'image(EXP_FSYN) severity warning;
    end if;
    if lsyn /= EXP_LSYN then
      errors := errors + 1;
      report "RUN " & RUN_TAG & ": LAST_SYN=" & integer'image(lsyn) &
             " exp=" & integer'image(EXP_LSYN) severity warning;
    end if;
    if sig /= EXP_SIG then
      errors := errors + 1;
      report "RUN " & RUN_TAG & ": firma got=" &
             to_hstring(sig) & " exp=" & to_hstring(EXP_SIG) severity warning;
    end if;

    report "RUN " & RUN_TAG & ": CE=" & integer'image(ce) &
           " DED=" & integer'image(ded) &
           " FIRST_SYN=" & integer'image(fsyn) &
           " LAST_SYN=" & integer'image(lsyn);
    if errors = 0 then
      report "LAYER4 RUN " & RUN_TAG & " PASS - firmware en lockstep con el ISS";
    else
      report "LAYER4 RUN " & RUN_TAG & " FAIL" severity failure;
    end if;
    wait;
  end process;
end architecture;
