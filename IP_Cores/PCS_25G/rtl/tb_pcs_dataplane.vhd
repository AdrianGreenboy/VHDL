-- AUTO-GENERADO por gen_tb_stats.py desde pcs_stats_oracle.py
-- NO EDITAR A MANO. Firma golden esperada: 0xFFE1A09F
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_dataplane is end entity;

architecture sim of tb_pcs_dataplane is
  constant GOLDEN : unsigned(31 downto 0) := x"FFE1A09F";
  constant FNV_OFFSET : unsigned(31 downto 0) := x"811C9DC5";
  constant FNV_PRIME  : unsigned(31 downto 0) := x"01000193";

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal blk_evt : std_logic_vector(2 downto 0) := "000";
  signal c_clear, c_sreset, c_resync, c_prbsr : std_logic := '0';
  signal cnt_tx, cnt_rx, cnt_rxerr, cnt_ber, lockt : std_logic_vector(31 downto 0);
  signal s_lock, s_scr, s_prbs, s_hiber, s_txa, s_rxa : std_logic;
  signal e_lg, e_ll, e_hb, e_re, e_pe : std_logic;

  -- shadow y sticky reproducidos en el TB (contrato del oraculo)
  signal sh_tx, sh_rx, sh_rxerr, sh_ber, sh_lockt : std_logic_vector(31 downto 0) := (others=>'0');
  signal sticky : std_logic_vector(5 downto 0) := (others=>'0');
  signal clr_mask : std_logic_vector(5 downto 0) := (others=>'0');
  signal clr_stb  : std_logic := '0';
  signal dma_done_stb : std_logic := '0';

  signal sig : unsigned(31 downto 0) := FNV_OFFSET;

  procedure fnv_byte(signal h : inout unsigned(31 downto 0); b : integer) is
    variable hv : unsigned(31 downto 0); variable pr : unsigned(63 downto 0);
  begin
    hv := h xor to_unsigned(b mod 256, 32); pr := hv * FNV_PRIME;
    h <= pr(31 downto 0);
  end procedure;

begin
  clk <= not clk after 1.28 ns;  -- ~390.625 MHz

  dut: entity work.pcs_dataplane
    generic map (LOCK_THRESHOLD => 64, HIBER_THRESHOLD => 16)
    port map (
      clk_dp=>clk, rst_dp=>rst, blk_evt=>blk_evt,
      cmd_cnt_clear=>c_clear, cmd_soft_reset=>c_sreset,
      cmd_resync=>c_resync, cmd_prbs_reset=>c_prbsr,
      cnt_tx_blk=>cnt_tx, cnt_rx_blk=>cnt_rx, cnt_rx_err=>cnt_rxerr,
      cnt_ber=>cnt_ber, lock_time=>lockt,
      st_block_lock=>s_lock, st_scr_sync=>s_scr, st_prbs_lock=>s_prbs,
      st_hi_ber=>s_hiber, st_tx_active=>s_txa, st_rx_active=>s_rxa,
      ev_lock_gained=>e_lg, ev_lock_lost=>e_ll, ev_hi_ber=>e_hb,
      ev_rx_err=>e_re, ev_prbs_err=>e_pe);

  -- captura de stickies: UNICO driver de sticky (evita X por doble driver)
  sticky_proc: process(clk)
    variable nx : std_logic_vector(5 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then sticky <= (others=>'0');
      else
        nx := sticky;
        if clr_stb = '1' then nx := nx and not clr_mask; end if;
        if e_lg = '1' then nx(0) := '1'; end if;
        if e_ll = '1' then nx(1) := '1'; end if;
        if e_hb = '1' then nx(2) := '1'; end if;
        if e_re = '1' then nx(3) := '1'; end if;
        if e_pe = '1' then nx(4) := '1'; end if;
        if dma_done_stb = '1' then nx(5) := '1'; end if;
        sticky <= nx;
      end if;
    end if;
  end process;

  stim: process
    variable v_st : std_logic_vector(7 downto 0);

    procedure acc_u32(v : std_logic_vector(31 downto 0)) is
    begin
      fnv_byte(sig, to_integer(unsigned(v(7 downto 0))));   wait for 0 ns;
      fnv_byte(sig, to_integer(unsigned(v(15 downto 8))));  wait for 0 ns;
      fnv_byte(sig, to_integer(unsigned(v(23 downto 16)))); wait for 0 ns;
      fnv_byte(sig, to_integer(unsigned(v(31 downto 24)))); wait for 0 ns;
    end procedure;
    procedure acc_byte(b : integer) is
    begin fnv_byte(sig, b); wait for 0 ns; end procedure;

    procedure pulse_evt(code : integer; n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
        blk_evt <= std_logic_vector(to_unsigned(code, 3));
      end loop;
      wait until rising_edge(clk);
      blk_evt <= "000";
    end procedure;

  begin
    rst <= '1'; wait for 10 ns; wait until rising_edge(clk); rst <= '0';
    wait until rising_edge(clk);

    -- run code=0 n=5
    pulse_evt(0, 5);
    acc_byte(0); acc_u32(x"C301CF96");
    -- run code=1 n=50
    pulse_evt(1, 50);
    acc_byte(0); acc_u32(x"51455FF3");
    -- rd_status esperado 0x20
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(32,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x20" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- run code=2 n=70
    pulse_evt(2, 70);
    acc_byte(0); acc_u32(x"50F7C01C");
    -- rd_status esperado 0x6D
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(109,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x6D" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- rd_irq esperado 0x01
    wait until rising_edge(clk);
    assert unsigned(sticky) = to_unsigned(1,6) report "IRQ mismatch got 0x" & to_hstring(sticky) & " exp 0x01" severity error;
    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));
    -- snap
    wait until rising_edge(clk);
    sh_tx <= cnt_tx; sh_rx <= cnt_rx; sh_rxerr <= cnt_rxerr;
    sh_ber <= cnt_ber; sh_lockt <= lockt;
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000");
    -- run code=1 n=10
    pulse_evt(1, 10);
    acc_byte(0); acc_u32(x"51455FCB");
    -- rd_cnt esperado tx,rx,rxerr,ber = (50,70,0,0); lockt=119 no-firmado
    assert sh_tx = x"00000032" report "CNT tx mismatch" severity error;
    assert sh_rx = x"00000046" report "CNT rx mismatch" severity error;
    assert sh_rxerr = x"00000000" report "CNT rxerr mismatch" severity error;
    assert sh_ber = x"00000000" report "CNT ber mismatch" severity error;
    acc_byte(3); acc_u32(sh_tx);
    acc_byte(3); acc_u32(sh_rx);
    acc_byte(3); acc_u32(sh_rxerr);
    acc_byte(3); acc_u32(sh_ber);
    -- run code=3 n=3
    pulse_evt(3, 3);
    acc_byte(0); acc_u32(x"F7664258");
    -- rd_status esperado 0x68
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(104,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x68" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- rd_irq esperado 0x0B
    wait until rising_edge(clk);
    assert unsigned(sticky) = to_unsigned(11,6) report "IRQ mismatch got 0x" & to_hstring(sticky) & " exp 0x0B" severity error;
    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));
    -- run code=2 n=70
    pulse_evt(2, 70);
    acc_byte(0); acc_u32(x"50F7C01C");
    -- rd_status esperado 0x6D
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(109,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x6D" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- run code=4 n=5
    pulse_evt(4, 5);
    acc_byte(0); acc_u32(x"73C2A3E1");
    -- rd_irq esperado 0x1B
    wait until rising_edge(clk);
    assert unsigned(sticky) = to_unsigned(27,6) report "IRQ mismatch got 0x" & to_hstring(sticky) & " exp 0x1B" severity error;
    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));
    -- run code=3 n=16
    pulse_evt(3, 16);
    acc_byte(0); acc_u32(x"F766424B");
    -- rd_status esperado 0x6A
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(106,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x6A" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- rd_irq esperado 0x1F
    wait until rising_edge(clk);
    assert unsigned(sticky) = to_unsigned(31,6) report "IRQ mismatch got 0x" & to_hstring(sticky) & " exp 0x1F" severity error;
    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));
    -- clr_irq mask=0x18
    wait until rising_edge(clk);
    clr_mask <= std_logic_vector(to_unsigned(24, 6)); clr_stb <= '1';
    wait until rising_edge(clk); clr_stb <= '0';
    wait until rising_edge(clk);
    acc_byte(6); acc_u32(std_logic_vector(to_unsigned(24, 32)));
    -- rd_irq esperado 0x07
    wait until rising_edge(clk);
    assert unsigned(sticky) = to_unsigned(7,6) report "IRQ mismatch got 0x" & to_hstring(sticky) & " exp 0x07" severity error;
    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));
    -- snap
    wait until rising_edge(clk);
    sh_tx <= cnt_tx; sh_rx <= cnt_rx; sh_rxerr <= cnt_rxerr;
    sh_ber <= cnt_ber; sh_lockt <= lockt;
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000");
    -- rd_cnt esperado tx,rx,rxerr,ber = (60,159,19,5); lockt=202 no-firmado
    assert sh_tx = x"0000003C" report "CNT tx mismatch" severity error;
    assert sh_rx = x"0000009F" report "CNT rx mismatch" severity error;
    assert sh_rxerr = x"00000013" report "CNT rxerr mismatch" severity error;
    assert sh_ber = x"00000005" report "CNT ber mismatch" severity error;
    acc_byte(3); acc_u32(sh_tx);
    acc_byte(3); acc_u32(sh_rx);
    acc_byte(3); acc_u32(sh_rxerr);
    acc_byte(3); acc_u32(sh_ber);
    -- cmd cnt_clear
    wait until rising_edge(clk); c_clear <= '1';
    wait until rising_edge(clk); c_clear <= '0';
    wait until rising_edge(clk);
    acc_byte(1); acc_u32(x"7490CD0A");
    -- snap
    wait until rising_edge(clk);
    sh_tx <= cnt_tx; sh_rx <= cnt_rx; sh_rxerr <= cnt_rxerr;
    sh_ber <= cnt_ber; sh_lockt <= lockt;
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000");
    -- rd_cnt esperado tx,rx,rxerr,ber = (0,0,0,0); lockt=202 no-firmado
    assert sh_tx = x"00000000" report "CNT tx mismatch" severity error;
    assert sh_rx = x"00000000" report "CNT rx mismatch" severity error;
    assert sh_rxerr = x"00000000" report "CNT rxerr mismatch" severity error;
    assert sh_ber = x"00000000" report "CNT ber mismatch" severity error;
    acc_byte(3); acc_u32(sh_tx);
    acc_byte(3); acc_u32(sh_rx);
    acc_byte(3); acc_u32(sh_rxerr);
    acc_byte(3); acc_u32(sh_ber);
    -- cmd soft_reset
    wait until rising_edge(clk); c_sreset <= '1';
    wait until rising_edge(clk); c_sreset <= '0';
    wait until rising_edge(clk);
    acc_byte(1); acc_u32(x"090EB451");
    -- rd_status esperado 0x60
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(96,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x60" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- run code=2 n=63
    pulse_evt(2, 63);
    acc_byte(0); acc_u32(x"50F7C065");
    -- rd_status esperado 0x60
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(96,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x60" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- run code=2 n=1
    pulse_evt(2, 1);
    acc_byte(0); acc_u32(x"50F7C05B");
    -- rd_status esperado 0x6D
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(109,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x6D" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- cmd soft_reset
    wait until rising_edge(clk); c_sreset <= '1';
    wait until rising_edge(clk); c_sreset <= '0';
    wait until rising_edge(clk);
    acc_byte(1); acc_u32(x"090EB451");
    -- rd_status esperado 0x60
    wait until rising_edge(clk);
    v_st := '0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock;
    assert unsigned(v_st) = to_unsigned(96,8) report "STATUS mismatch got 0x" & to_hstring(v_st) & " exp 0x60" severity error;
    acc_byte(4);
    acc_u32(x"000000" & v_st);
    -- cmd dma_done
    wait until rising_edge(clk); dma_done_stb <= '1';
    wait until rising_edge(clk); dma_done_stb <= '0';
    wait until rising_edge(clk);
    acc_byte(1); acc_u32(x"BD0DE762");
    -- rd_irq esperado 0x27
    wait until rising_edge(clk);
    assert unsigned(sticky) = to_unsigned(39,6) report "IRQ mismatch got 0x" & to_hstring(sticky) & " exp 0x27" severity error;
    acc_byte(5); acc_u32(std_logic_vector(resize(unsigned(sticky), 32)));

    -- cierre: estado final (lock_time excluido de la firma)
    acc_u32(sh_tx); acc_u32(sh_rx); acc_u32(sh_rxerr); acc_u32(sh_ber);
    acc_byte(to_integer(unsigned'('0' & s_rxa & s_txa & '0' & s_prbs & s_scr & s_hiber & s_lock)));
    acc_byte(to_integer(unsigned(sticky)));
    wait for 1 ns;
    if sig = GOLDEN then
      report "LAYER2A_PASS FNV32=0x" & to_hstring(sig) severity note;
    else
      report "LAYER2A_FAIL FNV32=0x" & to_hstring(sig) & " GOLDEN=0x" & to_hstring(GOLDEN) severity error;
    end if;
    wait;
  end process;
end architecture;
