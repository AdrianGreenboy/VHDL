#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera el testbench VHDL de Layer 1 (tb_pcs_regbank.vhd) a partir de la MISMA
traza canonica del oraculo. Fuente unica de verdad: la traza Python.

El testbench:
  * instancia pcs_regbank
  * reproduce cada operacion (W/R/E) en orden
  * para W/R hace transacciones AXI-Lite reales y, en R, acumula la firma con
    el dato leido del RTL
  * para E conduce los puertos dp_* y acumula la MISMA codificacion de evento
  * al final acumula sombras + irq_out y compara con la firma golden

Uso: python3 gen_tb.py > ../rtl/tb_pcs_regbank.vhd
"""
import importlib.util, sys
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
_ORACLE_PATH = os.path.join(_HERE, "pcs_regbank_oracle.py")
spec = importlib.util.spec_from_file_location("oracle", _ORACLE_PATH)
o = importlib.util.module_from_spec(spec); spec.loader.exec_module(o)

GOLDEN = o.run(o.canonical_trace())

# Reejecutamos la traza contra un banco modelo para saber, en cada evento E,
# que valores deben tener los puertos dp_* (contadores live, status, pulsos ev)
# en el momento de la operacion. El testbench los aplicara.
def build_stimulus():
    bank = o.PcsRegBank()
    stim = []  # cada item: dict con lo que el TB debe hacer
    for kind, a, b in o.canonical_trace():
        if kind == "W":
            bank.write(a, b)
            stim.append({"op": "W", "off": a, "data": b & o.MASK32})
        elif kind == "R":
            val = bank.read(a)
            stim.append({"op": "R", "off": a, "expect": val & o.MASK32})
        elif kind == "E":
            bank.dp_event(a, b)
            enc = (o.fnv1a_32(a.encode("ascii")) ^ (b & o.MASK32)) & o.MASK32
            # snapshot del estado live + status + que evento sticky pulsar
            ev_bit = {
                "gain_lock": "lock_gained", "lose_lock": "lock_lost",
                "hi_ber": "hi_ber", "rx_err": "rx_err",
                "prbs_err": "prbs_err", "dma_done": "dma_done",
            }.get(a, None)
            stim.append({
                "op": "E", "enc": enc,
                "live": dict(bank.live),
                "status": bank.status,
                "ev": ev_bit,
            })
    return stim, bank

STIM, FINAL = build_stimulus()

def hx(v): return "x\"%08X\"" % (v & o.MASK32)

# --- emision del VHDL ---
L = []
def w(s=""): L.append(s)

w("-- AUTO-GENERADO por gen_tb.py desde pcs_regbank_oracle.py")
w("-- NO EDITAR A MANO. Fuente de verdad: la traza canonica del oraculo.")
w("-- Firma golden esperada: 0x%08X" % GOLDEN)
w("library ieee;")
w("use ieee.std_logic_1164.all;")
w("use ieee.numeric_std.all;")
w("")
w("entity tb_pcs_regbank is end entity;")
w("")
w("architecture sim of tb_pcs_regbank is")
w("  constant GOLDEN : unsigned(31 downto 0) := %s;" % hx(GOLDEN))
w("  constant FNV_OFFSET : unsigned(31 downto 0) := x\"811C9DC5\";")
w("  constant FNV_PRIME  : unsigned(31 downto 0) := x\"01000193\";")
w("")
w("  signal clk : std_logic := '0';")
w("  signal rstn: std_logic := '0';")
w("  -- AXI")
w("  signal awaddr : std_logic_vector(7 downto 0) := (others=>'0');")
w("  signal awvalid: std_logic := '0'; signal awready: std_logic;")
w("  signal wdata  : std_logic_vector(31 downto 0) := (others=>'0');")
w("  signal wstrb  : std_logic_vector(3 downto 0) := \"1111\";")
w("  signal wvalid : std_logic := '0'; signal wready : std_logic;")
w("  signal bresp  : std_logic_vector(1 downto 0); signal bvalid: std_logic;")
w("  signal bready : std_logic := '1';")
w("  signal araddr : std_logic_vector(7 downto 0) := (others=>'0');")
w("  signal arvalid: std_logic := '0'; signal arready: std_logic;")
w("  signal rdata  : std_logic_vector(31 downto 0); signal rresp: std_logic_vector(1 downto 0);")
w("  signal rvalid : std_logic; signal rready : std_logic := '1';")
w("  signal irq    : std_logic;")
w("  -- dp_*")
w("  signal dp_block_lock, dp_hi_ber, dp_scr_sync, dp_prbs_lock : std_logic := '0';")
w("  signal dp_tx_active, dp_rx_active, dp_dma_busy : std_logic := '0';")
w("  signal dp_cnt_tx_blk, dp_cnt_rx_blk, dp_cnt_rx_err : std_logic_vector(31 downto 0) := (others=>'0');")
w("  signal dp_cnt_ber, dp_lock_time : std_logic_vector(31 downto 0) := (others=>'0');")
w("  signal dp_ev_lock_gained, dp_ev_lock_lost, dp_ev_hi_ber : std_logic := '0';")
w("  signal dp_ev_rx_err, dp_ev_prbs_err, dp_ev_dma_done : std_logic := '0';")
w("  -- outputs de control (no chequeados en L1)")
w("  signal ctrl_reg : std_logic_vector(6 downto 0);")
w("  signal prbs_ctrl_reg : std_logic_vector(2 downto 0);")
w("  signal cmd_soft_reset, cmd_resync, cmd_cnt_clear, cmd_prbs_reset : std_logic;")
w("  signal prbs_inj, stats_snap : std_logic;")
w("  signal dma_addr_reg, dma_doorbell_reg : std_logic_vector(31 downto 0);")
w("")
w("  signal sig : unsigned(31 downto 0) := FNV_OFFSET;")
w("")
w("  -- FNV-1a sobre 1 byte")
w("  procedure fnv_byte(signal h : inout unsigned(31 downto 0); b : integer) is")
w("    variable hv : unsigned(31 downto 0);")
w("    variable prod : unsigned(63 downto 0);")
w("  begin")
w("    hv := h xor to_unsigned(b mod 256, 32);")
w("    prod := hv * FNV_PRIME;")
w("    h <= prod(31 downto 0);")
w("  end procedure;")
w("")
w("begin")
w("  clk <= not clk after 5 ns;")
w("")
w("  dut: entity work.pcs_regbank")
w("    port map (")
w("      s_axi_aclk=>clk, s_axi_aresetn=>rstn,")
w("      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,")
w("      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,")
w("      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,")
w("      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,")
w("      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,")
w("      irq_out=>irq,")
w("      dp_block_lock=>dp_block_lock, dp_hi_ber=>dp_hi_ber, dp_scr_sync=>dp_scr_sync,")
w("      dp_prbs_lock=>dp_prbs_lock, dp_tx_active=>dp_tx_active, dp_rx_active=>dp_rx_active,")
w("      dp_dma_busy=>dp_dma_busy,")
w("      dp_cnt_tx_blk=>dp_cnt_tx_blk, dp_cnt_rx_blk=>dp_cnt_rx_blk, dp_cnt_rx_err=>dp_cnt_rx_err,")
w("      dp_cnt_ber=>dp_cnt_ber, dp_lock_time=>dp_lock_time,")
w("      dp_ev_lock_gained=>dp_ev_lock_gained, dp_ev_lock_lost=>dp_ev_lock_lost,")
w("      dp_ev_hi_ber=>dp_ev_hi_ber, dp_ev_rx_err=>dp_ev_rx_err,")
w("      dp_ev_prbs_err=>dp_ev_prbs_err, dp_ev_dma_done=>dp_ev_dma_done,")
w("      ctrl_reg=>ctrl_reg, prbs_ctrl_reg=>prbs_ctrl_reg,")
w("      cmd_soft_reset=>cmd_soft_reset, cmd_resync=>cmd_resync,")
w("      cmd_cnt_clear=>cmd_cnt_clear, cmd_prbs_reset=>cmd_prbs_reset,")
w("      prbs_inj=>prbs_inj, stats_snap=>stats_snap,")
w("      dma_addr_reg=>dma_addr_reg, dma_doorbell_reg=>dma_doorbell_reg);")
w("")
w("  stim: process")
w("    variable rd : std_logic_vector(31 downto 0);")
w("")
w("    -- acumula un u32 en la firma, little-endian, byte a byte")
w("    procedure acc_u32(v : std_logic_vector(31 downto 0)) is")
w("    begin")
w("      fnv_byte(sig, to_integer(unsigned(v(7 downto 0))));   wait for 0 ns;")
w("      fnv_byte(sig, to_integer(unsigned(v(15 downto 8))));  wait for 0 ns;")
w("      fnv_byte(sig, to_integer(unsigned(v(23 downto 16)))); wait for 0 ns;")
w("      fnv_byte(sig, to_integer(unsigned(v(31 downto 24)))); wait for 0 ns;")
w("    end procedure;")
w("")
w("    procedure acc_byte(b : integer) is")
w("    begin")
w("      fnv_byte(sig, b); wait for 0 ns;")
w("    end procedure;")
w("")
w("    -- Escritura AXI-Lite (presenta AW+W, espera ready, luego B)")
w("    procedure axi_write(off : std_logic_vector(7 downto 0); dat : std_logic_vector(31 downto 0)) is")
w("      variable aw_done, w_done : boolean;")
w("    begin")
w("      wait until rising_edge(clk);")
w("      awaddr <= off; awvalid <= '1'; wdata <= dat; wvalid <= '1';")
w("      aw_done := false; w_done := false;")
w("      loop")
w("        wait until rising_edge(clk);")
w("        if awready = '1' then awvalid <= '0'; aw_done := true; end if;")
w("        if wready  = '1' then wvalid  <= '0'; w_done  := true; end if;")
w("        exit when aw_done and w_done;")
w("      end loop;")
w("      -- esperar B")
w("      loop")
w("        exit when bvalid = '1';")
w("        wait until rising_edge(clk);")
w("      end loop;")
w("      wait until rising_edge(clk);")
w("    end procedure;")
w("")
w("    -- Lectura AXI-Lite")
w("    procedure axi_read(off : std_logic_vector(7 downto 0); result : out std_logic_vector(31 downto 0)) is")
w("      variable ar_done : boolean;")
w("    begin")
w("      wait until rising_edge(clk);")
w("      araddr <= off; arvalid <= '1';")
w("      ar_done := false;")
w("      loop")
w("        wait until rising_edge(clk);")
w("        if arready = '1' then arvalid <= '0'; ar_done := true; end if;")
w("        exit when ar_done;")
w("      end loop;")
w("      loop")
w("        exit when rvalid = '1';")
w("        wait until rising_edge(clk);")
w("      end loop;")
w("      result := rdata;")
w("      wait until rising_edge(clk);")
w("    end procedure;")
w("")
w("  begin")
w("    -- reset")
w("    rstn <= '0'; wait for 40 ns; wait until rising_edge(clk); rstn <= '1';")
w("    wait until rising_edge(clk);")
w("")

# tags de kind: W=0, R=1, E=2 (igual que el oraculo)
for s in STIM:
    if s["op"] == "W":
        w("    -- W off=0x%02X" % s["off"])
        w("    axi_write(x\"%02X\", %s);" % (s["off"], hx(s["data"])))
        w("    acc_byte(0); acc_u32(x\"000000%02X\"); acc_u32(%s);" % (s["off"], hx(s["data"])))
    elif s["op"] == "R":
        w("    -- R off=0x%02X (esperado 0x%08X)" % (s["off"], s["expect"]))
        w("    axi_read(x\"%02X\", rd);" % s["off"])
        w("    assert rd = %s report \"MISMATCH off 0x%02X\" severity error;" % (hx(s["expect"]), s["off"]))
        w("    acc_byte(1); acc_u32(x\"000000%02X\"); acc_u32(rd);" % s["off"])
    else:  # E
        # aplicar puertos dp_*
        live = s["live"]
        w("    -- E enc=0x%08X" % s["enc"])
        w("    wait until rising_edge(clk);")
        w("    dp_cnt_tx_blk <= %s; dp_cnt_rx_blk <= %s;" % (hx(live[o.CNT_TX_BLK]), hx(live[o.CNT_RX_BLK])))
        w("    dp_cnt_rx_err <= %s; dp_cnt_ber <= %s;" % (hx(live[o.CNT_RX_ERR]), hx(live[o.CNT_BER])))
        w("    dp_lock_time <= %s;" % hx(live[o.LOCK_TIME]))
        st = s["status"]
        w("    dp_block_lock <= '%d'; dp_hi_ber <= '%d'; dp_scr_sync <= '%d'; dp_prbs_lock <= '%d';" % (
            1 if st & o.ST_BLOCK_LOCK else 0, 1 if st & o.ST_HI_BER else 0,
            1 if st & o.ST_SCR_SYNC else 0, 1 if st & o.ST_PRBS_LOCK else 0))
        w("    dp_tx_active <= '%d'; dp_rx_active <= '%d';" % (
            1 if st & o.ST_TX_ACTIVE else 0, 1 if st & o.ST_RX_ACTIVE else 0))
        if s["ev"]:
            sig_name = "dp_ev_" + s["ev"]
            w("    %s <= '1'; wait until rising_edge(clk); %s <= '0';" % (sig_name, sig_name))
        else:
            w("    wait until rising_edge(clk);")
        w("    acc_byte(2); acc_u32(x\"00000000\"); acc_u32(%s);" % hx(s["enc"]))

# estado final: sombras + irq_out. Necesitamos leer las sombras del RTL via AXI.
# Pero el oraculo usa bank.shadow (que ya reflejan el ultimo snapshot). El RTL
# tiene esas sombras en sh_*. Las leemos por AXI para el cierre de firma.
w("")
w("    -- cierre: sombras finales (leidas del RTL) + irq_out")
for off, name in [(o.CNT_TX_BLK,"tx"),(o.CNT_RX_BLK,"rx"),(o.CNT_RX_ERR,"rxerr"),(o.CNT_BER,"ber"),(o.LOCK_TIME,"lockt")]:
    w("    axi_read(x\"%02X\", rd); acc_u32(rd);" % off)
w("    acc_byte(to_integer(unsigned'('0' & irq)));")
w("")
w("    -- comparacion final")
w("    wait for 1 ns;")
w("    if sig = GOLDEN then")
w("      report \"LAYER1_PASS FNV32=0x\" & to_hstring(sig) severity note;")
w("    else")
w("      report \"LAYER1_FAIL FNV32=0x\" & to_hstring(sig) & \" GOLDEN=0x\" & to_hstring(GOLDEN) severity error;")
w("    end if;")
w("    wait;")
w("  end process;")
w("end architecture;")

print("\n".join(L))
