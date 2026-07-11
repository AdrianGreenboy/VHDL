-- tb_tx_override.vhd — capa 1a del override 1-step en eth_tx_mii.
-- Transmite una trama corta con override activo en una ventana, captura TODOS
-- los nibbles emitidos (dst..FCS) y los vuelca a tx_stream.txt. Un verificador
-- Python independiente reensambla los bytes, comprueba que la ventana quedo
-- parcheada y que el FCS cubre correctamente los bytes PARCHEADOS.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.eth_pkg.all;

entity tb_tx_override is
end entity;

architecture sim of tb_tx_override is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid, tx_last : std_logic := '0';
  signal tx_ready, tx_busy, underrun : std_logic;
  signal txd : std_logic_vector(3 downto 0);
  signal tx_en, tx_sfd_pulse : std_logic;
  signal ovr_en : std_logic := '0';
  signal ovr_off : std_logic_vector(10 downto 0) := (others => '0');
  signal ovr_len : std_logic_vector(3 downto 0) := (others => '0');
  signal ovr_data : std_logic_vector(79 downto 0) := (others => '0');

  constant TCK : time := 10 ns;
  signal done : boolean := false;

  -- trama de datos a enviar: 16 bytes (dst..type + algunos payload), tx_last
  -- en el ultimo. La ventana de override sera [8,10) (2 bytes) para probar.
  type darr is array (natural range <>) of std_logic_vector(7 downto 0);
  constant NDAT : integer := 16;
  signal frame : darr(0 to NDAT-1) := (
    x"01", x"80", x"C2", x"00", x"00", x"0E",   -- dst
    x"AA", x"BB", x"CC", x"DD", x"EE", x"FF",   -- src (parcheable)
    x"88", x"F7",                               -- type
    x"12", x"34");                              -- payload

begin
  clk <= not clk after TCK/2 when not done else '0';

  -- mii_ce: 1 de cada 4
  process(clk)
    variable d : unsigned(1 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      if rst = '1' then d := (others => '0'); mii_ce <= '0';
      elsif d = 3 then d := (others => '0'); mii_ce <= '1';
      else d := d + 1; mii_ce <= '0'; end if;
    end if;
  end process;

  dut : entity work.eth_tx_mii
    port map (
      clk => clk, rst => rst, mii_ce => mii_ce,
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready, tx_busy => tx_busy, underrun => underrun,
      txd => txd, tx_en => tx_en, tx_sfd_pulse => tx_sfd_pulse,
      ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data);

  -- captura de nibbles: cada mii_ce con tx_en='1' registra un nibble
  cap : process
    file fh : text;
    variable ln : line;
    variable idx : integer := 0;
  begin
    file_open(fh, "tx_stream.txt", write_mode);
    loop
      wait until rising_edge(clk);
      exit when done;
      if mii_ce = '1' and tx_en = '1' then
        write(ln, to_integer(unsigned(txd)));
        writeline(fh, ln);
        idx := idx + 1;
      end if;
    end loop;
    file_close(fh);
    wait;
  end process;

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure stepce is begin
      loop step; exit when mii_ce = '1'; end loop;
    end procedure;
  begin
    -- override: parchear src bytes 8..9 (offset 8, len 2) con 0x55,0x66
    ovr_off  <= std_logic_vector(to_unsigned(8, 11));
    ovr_len  <= std_logic_vector(to_unsigned(2, 4));
    ovr_data <= (others => '0');
    ovr_data(7 downto 0)  <= x"55";   -- byte 0 de override (byte_cnt=8)
    ovr_data(15 downto 8) <= x"66";   -- byte 1 de override (byte_cnt=9)
    ovr_en   <= '1';

    rst <= '1'; step; step; rst <= '0';
    -- arrancar: tx_valid alto, alimentar bytes cuando tx_ready
    tx_valid <= '1';
    tx_data  <= frame(0);
    tx_last  <= '0';

    -- alimentar la trama: el motor consume 1 byte por tx_ready (en DAT_LO+mii_ce)
    for i in 0 to NDAT-1 loop
      -- esperar tx_ready
      loop
        step;
        exit when tx_ready = '1';
      end loop;
      -- en el ciclo de tx_ready, presentar el siguiente byte
      if i < NDAT-1 then
        tx_data <= frame(i+1);
        if i+1 = NDAT-1 then tx_last <= '1'; end if;
      end if;
    end loop;
    -- mantener hasta que el motor termine (IPG)
    tx_valid <= '0';
    tx_last  <= '0';
    for k in 0 to 400 loop step; end loop;

    done <= true;
    report "=== TX_OVERRIDE captura completa ===";
    wait;
  end process;

end architecture sim;
