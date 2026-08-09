-- tb_layer4_b.vhd - Run B (scrub OFF) de Layer 4: reusa tb_layer4 con generics
-- de la corrida no-protegida. Firma esperada distinta = gancho del paper.
library ieee;
use ieee.std_logic_1164.all;
entity tb_layer4_b is end entity;
architecture sim of tb_layer4_b is
begin
  dut : entity work.tb_layer4
    generic map (
      CFG_INIT => "cfg_b.txt",
      EXP_CE => 0, EXP_DED => 0, EXP_FSYN => 0, EXP_LSYN => 0,
      EXP_SIG => x"0f37257a", RUN_TAG => "B"
    );
end architecture;
