-- =============================================================
-- rv32_mmio_bus.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 5
-- Decodificador del puerto MMIO rapido del adaptador. Cuelga
-- UART, CLINT y SYSCON, con el mismo mapa que mini-rv32ima:
--
--   addr[31:16]=0x1000 -> UART   (0x10000000..)
--   addr[31:16]=0x1100 -> CLINT  (0x11000000..)
--   addr[31:16]=0x1110 -> SYSCON (0x11100000..)
--   cualquier otro rango -> lectura 0, ready='1' (no cuelga el bus)
--
-- Todos los perifericos son single-beat con ready='1', asi que
-- el bus responde en el mismo ciclo. rdata es COMBINACIONAL
-- (mismo contrato que el dmem del core: el adaptador lo registra).
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_mmio_bus is
  port (
    clk        : in  std_logic;
    rstn       : in  std_logic;
    tick       : in  std_logic;   -- pulso de tiempo para el CLINT
    -- lado adaptador (puerto MMIO rapido)
    req        : in  std_logic;
    we         : in  std_logic;
    addr       : in  std_logic_vector(31 downto 0);
    wdata      : in  std_logic_vector(31 downto 0);
    rdata      : out std_logic_vector(31 downto 0);
    ready      : out std_logic;
    -- UART: salida de caracteres
    tx_valid   : out std_logic;
    tx_data    : out std_logic_vector(7 downto 0);
    -- UART: entrada de caracteres
    rx_dr      : in  std_logic := '0';
    rx_data    : in  std_logic_vector(7 downto 0) := (others => '0');
    rx_take    : out std_logic;
    -- eventos de sistema
    poweroff_o : out std_logic;
    reboot_o   : out std_logic;
    -- interrupciones del CLINT hacia la unidad de traps
    mtip       : out std_logic;
    msip       : out std_logic
  );
end entity;

architecture rtl of rv32_mmio_bus is
  constant SEL_UART   : std_logic_vector(15 downto 0) := x"1000";
  constant SEL_CLINT  : std_logic_vector(15 downto 0) := x"1100";
  constant SEL_SYSCON : std_logic_vector(15 downto 0) := x"1110";

  signal sel      : std_logic_vector(15 downto 0);
  signal off      : std_logic_vector(15 downto 0);
  signal req_uart, req_clint, req_syscon : std_logic;
  signal rd_uart, rd_clint, rd_syscon    : std_logic_vector(31 downto 0);
  signal rdy_uart, rdy_clint, rdy_syscon : std_logic;
begin

  sel <= addr(31 downto 16);
  off <= addr(15 downto 0);

  req_uart   <= req when sel = SEL_UART   else '0';
  req_clint  <= req when sel = SEL_CLINT  else '0';
  req_syscon <= req when sel = SEL_SYSCON else '0';

  u_uart : entity work.rv32_uart
    port map (clk=>clk, rstn=>rstn,
      req=>req_uart, we=>we, addr=>off, wdata=>wdata,
      rdata=>rd_uart, ready=>rdy_uart,
      tx_valid=>tx_valid, tx_data=>tx_data,
      rx_dr=>rx_dr, rx_data=>rx_data, rx_take=>rx_take);

  u_clint : entity work.rv32_clint
    port map (clk=>clk, rstn=>rstn, tick=>tick,
      req=>req_clint, we=>we, addr=>off, wdata=>wdata,
      rdata=>rd_clint, ready=>rdy_clint,
      mtip=>mtip, msip=>msip);

  u_syscon : entity work.rv32_syscon
    port map (clk=>clk, rstn=>rstn,
      req=>req_syscon, we=>we, addr=>off, wdata=>wdata,
      rdata=>rd_syscon, ready=>rdy_syscon,
      poweroff_o=>poweroff_o, reboot_o=>reboot_o);

  -- mux de lectura combinacional
  rdata <= rd_uart   when sel = SEL_UART
      else rd_clint  when sel = SEL_CLINT
      else rd_syscon when sel = SEL_SYSCON
      else (others => '0');   -- rango no mapeado: 0 (igual que el emulador)

  -- ready: todos responden en 1 ciclo; un rango no mapeado tampoco cuelga
  ready <= rdy_uart   when sel = SEL_UART
      else rdy_clint  when sel = SEL_CLINT
      else rdy_syscon when sel = SEL_SYSCON
      else '1';

end architecture;
