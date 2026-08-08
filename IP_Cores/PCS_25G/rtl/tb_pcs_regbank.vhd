-- AUTO-GENERADO por gen_tb.py desde pcs_regbank_oracle.py
-- NO EDITAR A MANO. Fuente de verdad: la traza canonica del oraculo.
-- Firma golden esperada: 0xD49A4DB4
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_regbank is end entity;

architecture sim of tb_pcs_regbank is
  constant GOLDEN : unsigned(31 downto 0) := x"D49A4DB4";
  constant FNV_OFFSET : unsigned(31 downto 0) := x"811C9DC5";
  constant FNV_PRIME  : unsigned(31 downto 0) := x"01000193";

  signal clk : std_logic := '0';
  signal rstn: std_logic := '0';
  -- AXI
  signal awaddr : std_logic_vector(7 downto 0) := (others=>'0');
  signal awvalid: std_logic := '0'; signal awready: std_logic;
  signal wdata  : std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb  : std_logic_vector(3 downto 0) := "1111";
  signal wvalid : std_logic := '0'; signal wready : std_logic;
  signal bresp  : std_logic_vector(1 downto 0); signal bvalid: std_logic;
  signal bready : std_logic := '1';
  signal araddr : std_logic_vector(7 downto 0) := (others=>'0');
  signal arvalid: std_logic := '0'; signal arready: std_logic;
  signal rdata  : std_logic_vector(31 downto 0); signal rresp: std_logic_vector(1 downto 0);
  signal rvalid : std_logic; signal rready : std_logic := '1';
  signal irq    : std_logic;
  -- dp_*
  signal dp_block_lock, dp_hi_ber, dp_scr_sync, dp_prbs_lock : std_logic := '0';
  signal dp_tx_active, dp_rx_active, dp_dma_busy : std_logic := '0';
  signal dp_cnt_tx_blk, dp_cnt_rx_blk, dp_cnt_rx_err : std_logic_vector(31 downto 0) := (others=>'0');
  signal dp_cnt_ber, dp_lock_time : std_logic_vector(31 downto 0) := (others=>'0');
  signal dp_ev_lock_gained, dp_ev_lock_lost, dp_ev_hi_ber : std_logic := '0';
  signal dp_ev_rx_err, dp_ev_prbs_err, dp_ev_dma_done : std_logic := '0';
  -- outputs de control (no chequeados en L1)
  signal ctrl_reg : std_logic_vector(6 downto 0);
  signal prbs_ctrl_reg : std_logic_vector(2 downto 0);
  signal cmd_soft_reset, cmd_resync, cmd_cnt_clear, cmd_prbs_reset : std_logic;
  signal prbs_inj, stats_snap : std_logic;
  signal dma_addr_reg, dma_doorbell_reg : std_logic_vector(31 downto 0);

  signal sig : unsigned(31 downto 0) := FNV_OFFSET;

  -- FNV-1a sobre 1 byte
  procedure fnv_byte(signal h : inout unsigned(31 downto 0); b : integer) is
    variable hv : unsigned(31 downto 0);
    variable prod : unsigned(63 downto 0);
  begin
    hv := h xor to_unsigned(b mod 256, 32);
    prod := hv * FNV_PRIME;
    h <= prod(31 downto 0);
  end procedure;

begin
  clk <= not clk after 5 ns;

  dut: entity work.pcs_regbank
    port map (
      s_axi_aclk=>clk, s_axi_aresetn=>rstn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
      irq_out=>irq,
      dp_block_lock=>dp_block_lock, dp_hi_ber=>dp_hi_ber, dp_scr_sync=>dp_scr_sync,
      dp_prbs_lock=>dp_prbs_lock, dp_tx_active=>dp_tx_active, dp_rx_active=>dp_rx_active,
      dp_dma_busy=>dp_dma_busy,
      dp_cnt_tx_blk=>dp_cnt_tx_blk, dp_cnt_rx_blk=>dp_cnt_rx_blk, dp_cnt_rx_err=>dp_cnt_rx_err,
      dp_cnt_ber=>dp_cnt_ber, dp_lock_time=>dp_lock_time,
      dp_ev_lock_gained=>dp_ev_lock_gained, dp_ev_lock_lost=>dp_ev_lock_lost,
      dp_ev_hi_ber=>dp_ev_hi_ber, dp_ev_rx_err=>dp_ev_rx_err,
      dp_ev_prbs_err=>dp_ev_prbs_err, dp_ev_dma_done=>dp_ev_dma_done,
      ctrl_reg=>ctrl_reg, prbs_ctrl_reg=>prbs_ctrl_reg,
      cmd_soft_reset=>cmd_soft_reset, cmd_resync=>cmd_resync,
      cmd_cnt_clear=>cmd_cnt_clear, cmd_prbs_reset=>cmd_prbs_reset,
      prbs_inj=>prbs_inj, stats_snap=>stats_snap,
      dma_addr_reg=>dma_addr_reg, dma_doorbell_reg=>dma_doorbell_reg);

  stim: process
    variable rd : std_logic_vector(31 downto 0);

    -- acumula un u32 en la firma, little-endian, byte a byte
    procedure acc_u32(v : std_logic_vector(31 downto 0)) is
    begin
      fnv_byte(sig, to_integer(unsigned(v(7 downto 0))));   wait for 0 ns;
      fnv_byte(sig, to_integer(unsigned(v(15 downto 8))));  wait for 0 ns;
      fnv_byte(sig, to_integer(unsigned(v(23 downto 16)))); wait for 0 ns;
      fnv_byte(sig, to_integer(unsigned(v(31 downto 24)))); wait for 0 ns;
    end procedure;

    procedure acc_byte(b : integer) is
    begin
      fnv_byte(sig, b); wait for 0 ns;
    end procedure;

    -- Escritura AXI-Lite (presenta AW+W, espera ready, luego B)
    procedure axi_write(off : std_logic_vector(7 downto 0); dat : std_logic_vector(31 downto 0)) is
      variable aw_done, w_done : boolean;
    begin
      wait until rising_edge(clk);
      awaddr <= off; awvalid <= '1'; wdata <= dat; wvalid <= '1';
      aw_done := false; w_done := false;
      loop
        wait until rising_edge(clk);
        if awready = '1' then awvalid <= '0'; aw_done := true; end if;
        if wready  = '1' then wvalid  <= '0'; w_done  := true; end if;
        exit when aw_done and w_done;
      end loop;
      -- esperar B
      loop
        exit when bvalid = '1';
        wait until rising_edge(clk);
      end loop;
      wait until rising_edge(clk);
    end procedure;

    -- Lectura AXI-Lite
    procedure axi_read(off : std_logic_vector(7 downto 0); result : out std_logic_vector(31 downto 0)) is
      variable ar_done : boolean;
    begin
      wait until rising_edge(clk);
      araddr <= off; arvalid <= '1';
      ar_done := false;
      loop
        wait until rising_edge(clk);
        if arready = '1' then arvalid <= '0'; ar_done := true; end if;
        exit when ar_done;
      end loop;
      loop
        exit when rvalid = '1';
        wait until rising_edge(clk);
      end loop;
      result := rdata;
      wait until rising_edge(clk);
    end procedure;

  begin
    -- reset
    rstn <= '0'; wait for 40 ns; wait until rising_edge(clk); rstn <= '1';
    wait until rising_edge(clk);

    -- R off=0x00 (esperado 0x50435319)
    axi_read(x"00", rd);
    assert rd = x"50435319" report "MISMATCH off 0x00" severity error;
    acc_byte(1); acc_u32(x"00000000"); acc_u32(rd);
    -- W off=0x04
    axi_write(x"04", x"DEADBEEF");
    acc_byte(0); acc_u32(x"00000004"); acc_u32(x"DEADBEEF");
    -- R off=0x04 (esperado 0xDEADBEEF)
    axi_read(x"04", rd);
    assert rd = x"DEADBEEF" report "MISMATCH off 0x04" severity error;
    acc_byte(1); acc_u32(x"00000004"); acc_u32(rd);
    -- W off=0x04
    axi_write(x"04", x"00000000");
    acc_byte(0); acc_u32(x"00000004"); acc_u32(x"00000000");
    -- R off=0x04 (esperado 0x00000000)
    axi_read(x"04", rd);
    assert rd = x"00000000" report "MISMATCH off 0x04" severity error;
    acc_byte(1); acc_u32(x"00000004"); acc_u32(rd);
    -- W off=0x04
    axi_write(x"04", x"A5A5A5A5");
    acc_byte(0); acc_u32(x"00000004"); acc_u32(x"A5A5A5A5");
    -- R off=0x04 (esperado 0xA5A5A5A5)
    axi_read(x"04", rd);
    assert rd = x"A5A5A5A5" report "MISMATCH off 0x04" severity error;
    acc_byte(1); acc_u32(x"00000004"); acc_u32(rd);
    -- W off=0x08
    axi_write(x"08", x"FFFFFFFF");
    acc_byte(0); acc_u32(x"00000008"); acc_u32(x"FFFFFFFF");
    -- R off=0x08 (esperado 0x0000007F)
    axi_read(x"08", rd);
    assert rd = x"0000007F" report "MISMATCH off 0x08" severity error;
    acc_byte(1); acc_u32(x"00000008"); acc_u32(rd);
    -- R off=0x10 (esperado 0x00000010)
    axi_read(x"10", rd);
    assert rd = x"00000010" report "MISMATCH off 0x10" severity error;
    acc_byte(1); acc_u32(x"00000010"); acc_u32(rd);
    -- W off=0x08
    axi_write(x"08", x"0000004F");
    acc_byte(0); acc_u32(x"00000008"); acc_u32(x"0000004F");
    -- R off=0x08 (esperado 0x0000004F)
    axi_read(x"08", rd);
    assert rd = x"0000004F" report "MISMATCH off 0x08" severity error;
    acc_byte(1); acc_u32(x"00000008"); acc_u32(rd);
    -- W off=0x0C
    axi_write(x"0C", x"FFFFFFFF");
    acc_byte(0); acc_u32(x"0000000C"); acc_u32(x"FFFFFFFF");
    -- R off=0x0C (esperado 0x00000000)
    axi_read(x"0C", rd);
    assert rd = x"00000000" report "MISMATCH off 0x0C" severity error;
    acc_byte(1); acc_u32(x"0000000C"); acc_u32(rd);
    -- W off=0x1C
    axi_write(x"1C", x"00000003");
    acc_byte(0); acc_u32(x"0000001C"); acc_u32(x"00000003");
    -- R off=0x1C (esperado 0x00000003)
    axi_read(x"1C", rd);
    assert rd = x"00000003" report "MISMATCH off 0x1C" severity error;
    acc_byte(1); acc_u32(x"0000001C"); acc_u32(rd);
    -- W off=0x1C
    axi_write(x"1C", x"00000007");
    acc_byte(0); acc_u32(x"0000001C"); acc_u32(x"00000007");
    -- R off=0x1C (esperado 0x00000003)
    axi_read(x"1C", rd);
    assert rd = x"00000003" report "MISMATCH off 0x1C" severity error;
    acc_byte(1); acc_u32(x"0000001C"); acc_u32(rd);
    -- R off=0x14 (esperado 0x00000000)
    axi_read(x"14", rd);
    assert rd = x"00000000" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- E enc=0x93A33BB6
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"00000000"; dp_cnt_rx_blk <= x"00000000";
    dp_cnt_rx_err <= x"00000000"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '0'; dp_hi_ber <= '0'; dp_scr_sync <= '0'; dp_prbs_lock <= '0';
    dp_tx_active <= '0'; dp_rx_active <= '0';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"93A33BB6");
    -- E enc=0x8FF1BEA6
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"00000000"; dp_cnt_rx_blk <= x"00000000";
    dp_cnt_rx_err <= x"00000000"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '0'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '0';
    dp_tx_active <= '0'; dp_rx_active <= '0';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"8FF1BEA6");
    -- E enc=0x317D08FD
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"00000000"; dp_cnt_rx_blk <= x"00000000";
    dp_cnt_rx_err <= x"00000000"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '0';
    dp_tx_active <= '0'; dp_rx_active <= '0';
    dp_ev_lock_gained <= '1'; wait until rising_edge(clk); dp_ev_lock_gained <= '0';
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"317D08FD");
    -- E enc=0x8FD1970F
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"00000000"; dp_cnt_rx_blk <= x"00000000";
    dp_cnt_rx_err <= x"00000000"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '0'; dp_rx_active <= '0';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"8FD1970F");
    -- R off=0x10 (esperado 0x0000001D)
    axi_read(x"10", rd);
    assert rd = x"0000001D" report "MISMATCH off 0x10" severity error;
    acc_byte(1); acc_u32(x"00000010"); acc_u32(rd);
    -- R off=0x14 (esperado 0x00000001)
    axi_read(x"14", rd);
    assert rd = x"00000001" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- E enc=0x8B64E477
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000003E8"; dp_cnt_rx_blk <= x"00000000";
    dp_cnt_rx_err <= x"00000000"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '0';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"8B64E477");
    -- E enc=0x77056681
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000003E8"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000000"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"77056681");
    -- E enc=0x3578ADE4
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000003E8"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000003"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    dp_ev_rx_err <= '1'; wait until rising_edge(clk); dp_ev_rx_err <= '0';
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"3578ADE4");
    -- R off=0x14 (esperado 0x00000009)
    axi_read(x"14", rd);
    assert rd = x"00000009" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- E enc=0x8B64E66B
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000005DC"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000003"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"8B64E66B");
    -- W off=0x20
    axi_write(x"20", x"00000001");
    acc_byte(0); acc_u32(x"00000020"); acc_u32(x"00000001");
    -- E enc=0x8B64E478
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000009C3"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000003"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '1'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    wait until rising_edge(clk);
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"8B64E478");
    -- R off=0x24 (esperado 0x000005DC)
    axi_read(x"24", rd);
    assert rd = x"000005DC" report "MISMATCH off 0x24" severity error;
    acc_byte(1); acc_u32(x"00000024"); acc_u32(rd);
    -- R off=0x28 (esperado 0x000003E8)
    axi_read(x"28", rd);
    assert rd = x"000003E8" report "MISMATCH off 0x28" severity error;
    acc_byte(1); acc_u32(x"00000028"); acc_u32(rd);
    -- R off=0x2C (esperado 0x00000003)
    axi_read(x"2C", rd);
    assert rd = x"00000003" report "MISMATCH off 0x2C" severity error;
    acc_byte(1); acc_u32(x"0000002C"); acc_u32(rd);
    -- R off=0x30 (esperado 0x00000000)
    axi_read(x"30", rd);
    assert rd = x"00000000" report "MISMATCH off 0x30" severity error;
    acc_byte(1); acc_u32(x"00000030"); acc_u32(rd);
    -- R off=0x34 (esperado 0x00001000)
    axi_read(x"34", rd);
    assert rd = x"00001000" report "MISMATCH off 0x34" severity error;
    acc_byte(1); acc_u32(x"00000034"); acc_u32(rd);
    -- W off=0x18
    axi_write(x"18", x"FFFFFFFF");
    acc_byte(0); acc_u32(x"00000018"); acc_u32(x"FFFFFFFF");
    -- R off=0x18 (esperado 0x0000003F)
    axi_read(x"18", rd);
    assert rd = x"0000003F" report "MISMATCH off 0x18" severity error;
    acc_byte(1); acc_u32(x"00000018"); acc_u32(rd);
    -- W off=0x18
    axi_write(x"18", x"00000019");
    acc_byte(0); acc_u32(x"00000018"); acc_u32(x"00000019");
    -- R off=0x18 (esperado 0x00000019)
    axi_read(x"18", rd);
    assert rd = x"00000019" report "MISMATCH off 0x18" severity error;
    acc_byte(1); acc_u32(x"00000018"); acc_u32(rd);
    -- R off=0x14 (esperado 0x00000009)
    axi_read(x"14", rd);
    assert rd = x"00000009" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- W off=0x1C
    axi_write(x"1C", x"FFFFFFF8");
    acc_byte(0); acc_u32(x"0000001C"); acc_u32(x"FFFFFFF8");
    -- R off=0x1C (esperado 0x00000000)
    axi_read(x"1C", rd);
    assert rd = x"00000000" report "MISMATCH off 0x1C" severity error;
    acc_byte(1); acc_u32(x"0000001C"); acc_u32(rd);
    -- W off=0x14
    axi_write(x"14", x"00000018");
    acc_byte(0); acc_u32(x"00000014"); acc_u32(x"00000018");
    -- R off=0x14 (esperado 0x00000001)
    axi_read(x"14", rd);
    assert rd = x"00000001" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- E enc=0x2B594CE3
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000009C3"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000003"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '0'; dp_hi_ber <= '0'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    dp_ev_lock_lost <= '1'; wait until rising_edge(clk); dp_ev_lock_lost <= '0';
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"2B594CE3");
    -- R off=0x10 (esperado 0x0000007C)
    axi_read(x"10", rd);
    assert rd = x"0000007C" report "MISMATCH off 0x10" severity error;
    acc_byte(1); acc_u32(x"00000010"); acc_u32(rd);
    -- R off=0x14 (esperado 0x00000003)
    axi_read(x"14", rd);
    assert rd = x"00000003" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- E enc=0x70DBAF9D
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000009C3"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000003"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '0'; dp_hi_ber <= '1'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    dp_ev_hi_ber <= '1'; wait until rising_edge(clk); dp_ev_hi_ber <= '0';
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"70DBAF9D");
    -- R off=0x10 (esperado 0x0000007E)
    axi_read(x"10", rd);
    assert rd = x"0000007E" report "MISMATCH off 0x10" severity error;
    acc_byte(1); acc_u32(x"00000010"); acc_u32(rd);
    -- R off=0x14 (esperado 0x00000007)
    axi_read(x"14", rd);
    assert rd = x"00000007" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- W off=0x0C
    axi_write(x"0C", x"00000001");
    acc_byte(0); acc_u32(x"0000000C"); acc_u32(x"00000001");
    -- R off=0x10 (esperado 0x0000007E)
    axi_read(x"10", rd);
    assert rd = x"0000007E" report "MISMATCH off 0x10" severity error;
    acc_byte(1); acc_u32(x"00000010"); acc_u32(rd);
    -- R off=0x04 (esperado 0xA5A5A5A5)
    axi_read(x"04", rd);
    assert rd = x"A5A5A5A5" report "MISMATCH off 0x04" severity error;
    acc_byte(1); acc_u32(x"00000004"); acc_u32(rd);
    -- W off=0x38
    axi_write(x"38", x"70001000");
    acc_byte(0); acc_u32(x"00000038"); acc_u32(x"70001000");
    -- R off=0x38 (esperado 0x70001000)
    axi_read(x"38", rd);
    assert rd = x"70001000" report "MISMATCH off 0x38" severity error;
    acc_byte(1); acc_u32(x"00000038"); acc_u32(rd);
    -- E enc=0xBD0DE763
    wait until rising_edge(clk);
    dp_cnt_tx_blk <= x"000009C3"; dp_cnt_rx_blk <= x"000003E8";
    dp_cnt_rx_err <= x"00000003"; dp_cnt_ber <= x"00000000";
    dp_lock_time <= x"00001000";
    dp_block_lock <= '0'; dp_hi_ber <= '1'; dp_scr_sync <= '1'; dp_prbs_lock <= '1';
    dp_tx_active <= '1'; dp_rx_active <= '1';
    dp_ev_dma_done <= '1'; wait until rising_edge(clk); dp_ev_dma_done <= '0';
    acc_byte(2); acc_u32(x"00000000"); acc_u32(x"BD0DE763");
    -- W off=0x3C
    axi_write(x"3C", x"00C0FFEE");
    acc_byte(0); acc_u32(x"0000003C"); acc_u32(x"00C0FFEE");
    -- R off=0x3C (esperado 0x00C0FFEE)
    axi_read(x"3C", rd);
    assert rd = x"00C0FFEE" report "MISMATCH off 0x3C" severity error;
    acc_byte(1); acc_u32(x"0000003C"); acc_u32(rd);
    -- R off=0x14 (esperado 0x00000027)
    axi_read(x"14", rd);
    assert rd = x"00000027" report "MISMATCH off 0x14" severity error;
    acc_byte(1); acc_u32(x"00000014"); acc_u32(rd);
    -- W off=0x0C
    axi_write(x"0C", x"00000004");
    acc_byte(0); acc_u32(x"0000000C"); acc_u32(x"00000004");
    -- W off=0x20
    axi_write(x"20", x"00000001");
    acc_byte(0); acc_u32(x"00000020"); acc_u32(x"00000001");
    -- R off=0x24 (esperado 0x000009C3)
    axi_read(x"24", rd);
    assert rd = x"000009C3" report "MISMATCH off 0x24" severity error;
    acc_byte(1); acc_u32(x"00000024"); acc_u32(rd);
    -- W off=0x44
    axi_write(x"44", x"12345678");
    acc_byte(0); acc_u32(x"00000044"); acc_u32(x"12345678");
    -- R off=0x44 (esperado 0x00000000)
    axi_read(x"44", rd);
    assert rd = x"00000000" report "MISMATCH off 0x44" severity error;
    acc_byte(1); acc_u32(x"00000044"); acc_u32(rd);
    -- R off=0x78 (esperado 0x00000000)
    axi_read(x"78", rd);
    assert rd = x"00000000" report "MISMATCH off 0x78" severity error;
    acc_byte(1); acc_u32(x"00000078"); acc_u32(rd);

    -- cierre: sombras finales (leidas del RTL) + irq_out
    axi_read(x"24", rd); acc_u32(rd);
    axi_read(x"28", rd); acc_u32(rd);
    axi_read(x"2C", rd); acc_u32(rd);
    axi_read(x"30", rd); acc_u32(rd);
    axi_read(x"34", rd); acc_u32(rd);
    acc_byte(to_integer(unsigned'('0' & irq)));

    -- comparacion final
    wait for 1 ns;
    if sig = GOLDEN then
      report "LAYER1_PASS FNV32=0x" & to_hstring(sig) severity note;
    else
      report "LAYER1_FAIL FNV32=0x" & to_hstring(sig) & " GOLDEN=0x" & to_hstring(GOLDEN) severity error;
    end if;
    wait;
  end process;
end architecture;
