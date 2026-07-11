# Integración Opción B — el core RV32IM controla el IP PTP por AXI-Lite

El core accede al IP PTP mapeado en `0x8000_0000` de su bus de datos. Un maestro
AXI-Lite embebido (`ptp_axil_master.vhd`, ya verificado) traduce el acceso del
core a transacciones AXI4-Lite hacia `ptp_axil`, y congela el core con el
wait-state (`dmem_ready='0'`) hasta que la transacción completa.

Cadena verificada en simulación (`tb_ptp_axil_master`, PASS):
`core (dmem) -> ptp_axil_master -> ptp_axil -> ptp_top`
con SERVO readback OK, Sync, meanPathDelay=40 ns, offset esclavo=0.

## Ficheros a añadir al proyecto del core (`~/rv32i/`)

Copiar del paquete a `~/rv32i/`:
- `ptp_axil_master.vhd`  (maestro AXI-Lite embebido)
- todo el RTL del IP PTP ya está en `~/vhdl_repo/IP_Cores/PTP/rtl/`; el proyecto
  del core debe referenciarlo (o copiar los `.vhd` del IP a `~/rv32i/`).

## Cambios en `mem_subsys_dma.vhd`

### 1. Puertos nuevos de la entidad (maestro AXI-Lite hacia ptp_axil)

Añadir al final del `port (...)`, antes del `);` de cierre:

```vhdl
    -- ---- maestro AXI4-Lite hacia el IP PTP (0x8000_0000) ----
    p_awaddr  : out std_logic_vector(15 downto 0);
    p_awvalid : out std_logic;
    p_awready : in  std_logic;
    p_wdata   : out std_logic_vector(31 downto 0);
    p_wstrb   : out std_logic_vector(3 downto 0);
    p_wvalid  : out std_logic;
    p_wready  : in  std_logic;
    p_bresp   : in  std_logic_vector(1 downto 0);
    p_bvalid  : in  std_logic;
    p_bready  : out std_logic;
    p_araddr  : out std_logic_vector(15 downto 0);
    p_arvalid : out std_logic;
    p_arready : in  std_logic;
    p_rdata   : in  std_logic_vector(31 downto 0);
    p_rresp   : in  std_logic_vector(1 downto 0);
    p_rvalid  : in  std_logic;
    p_rready  : out std_logic
```

### 2. Señales nuevas (zona de declaración de la arquitectura)

```vhdl
  signal is_ptp     : std_logic;
  signal ptp_start  : std_logic;
  signal ptp_we     : std_logic;
  signal ptp_rdata  : word_t;
  signal ptp_ready  : std_logic;
```

### 3. Decodificado (junto a is_local / is_dmareg)

```vhdl
  is_ptp <= '1' when dmem_addr(31 downto 28) = "0110" else '0';   -- 0x6000_0000
```

NOTA IMPORTANTE sobre el mapa de tu SoC: la region alta (bit 31 = 1,
0x8000_0000+) YA sale por el maestro AXI hacia la DDR externa (ver
`accel_ddr.s`). Por eso el IP PTP NO puede ir en 0x8000_0000 y se mapea en
0x6000_0000. La firma de resultados se escribe en 0x8000_0000+ (region alta),
que va directa a la DDR por el maestro AXI — sin programar el DMA a mano.

### 4. Instanciar el maestro AXI-Lite embebido

```vhdl
  ptp_start <= is_ptp and dmem_req;
  ptp_we    <= '1' when dmem_wstrb /= "0000" else '0';

  u_ptp_axil_master : entity work.ptp_axil_master
    port map (
      clk => clk, aresetn => aresetn,
      start => ptp_start, we => ptp_we,
      addr  => dmem_addr(15 downto 0), wdata => dmem_wdata,
      rdata => ptp_rdata, ready => ptp_ready,
      m_awaddr => p_awaddr, m_awvalid => p_awvalid, m_awready => p_awready,
      m_wdata => p_wdata, m_wstrb => p_wstrb, m_wvalid => p_wvalid, m_wready => p_wready,
      m_bresp => p_bresp, m_bvalid => p_bvalid, m_bready => p_bready,
      m_araddr => p_araddr, m_arvalid => p_arvalid, m_arready => p_arready,
      m_rdata => p_rdata, m_rresp => p_rresp, m_rvalid => p_rvalid, m_rready => p_rready);
```

### 5. Mux de rdata y ready (reemplaza el bloque final)

Sustituir:

```vhdl
  dmem_rdata <= loc_rdata    when is_local  = '1' else
                dmareg_rdata when is_dmareg = '1' else
                (others => '0');
  dmem_ready <= '1';
```

por:

```vhdl
  dmem_rdata <= loc_rdata    when is_local  = '1' else
                dmareg_rdata when is_dmareg = '1' else
                ptp_rdata    when is_ptp    = '1' else
                (others => '0');
  -- local y DMA-reg son de 1 ciclo; el IP PTP inserta wait-states hasta que
  -- la transaccion AXI-Lite completa (ptp_ready pulsa al terminar).
  dmem_ready <= ptp_ready when is_ptp = '1' else '1';
```

IMPORTANTE (contrato dmem del core): comprueba cómo espera tu core el `ready`.
Si el core muestrea `dmem_ready` y `dmem_rdata` en el MISMO ciclo (combinacional),
`ptp_ready` ya cumple: pulsa 1 ciclo con el dato válido. Si tu core registra el
rdata un ciclo después del ready, ajusta el flanco en el core como hiciste con
el resto de la familia (el bug del `lw` que devolvía el dato anterior). Con el
DMA (que también es de 1 ciclo aquí) tu core ya funciona, así que el mismo
contrato aplica.

## Cambios en `soc_top_master.vhd`

### 1. Cablear el maestro del subsistema al ptp_axil

En la instancia de `mem_subsys_dma`, conectar los nuevos puertos `p_*` a señales
internas, e instanciar `ptp_axil`:

```vhdl
  u_ptp_axil : entity work.ptp_axil
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (
      s_axi_aclk => aclk, s_axi_aresetn => aresetn,
      s_axi_awaddr => p_awaddr, s_axi_awvalid => p_awvalid, s_axi_awready => p_awready,
      s_axi_wdata => p_wdata, s_axi_wstrb => p_wstrb, s_axi_wvalid => p_wvalid, s_axi_wready => p_wready,
      s_axi_bresp => p_bresp, s_axi_bvalid => p_bvalid, s_axi_bready => p_bready,
      s_axi_araddr => p_araddr, s_axi_arvalid => p_arvalid, s_axi_arready => p_arready,
      s_axi_rdata => p_rdata, s_axi_rresp => p_rresp, s_axi_rvalid => p_rvalid, s_axi_rready => p_rready,
      irq => ptp_irq, mii_txd => open, mii_tx_en => open,
      mii_rxd => (others => '0'), mii_rx_dv => '0');
```

En LOOP_INT los pines MII van a `open`/tierra (loopback interno). El `ptp_irq`
puede unirse al `irq_out` del SoC (OR con el doorbell) si quieres que el IP
interrumpa al PS; para la validación por firma en DDR no es necesario.

## Firmware

El `ptp_bringup.mem` (incluido, actualizado) escribe/lee `0x6000_00xx` para el
IP (el subsistema lo enruta por el maestro AXI-Lite), y vuelca la firma a
`0x8000_0000+` (region alta), que tu SoC envia directo a la DDR por el maestro
AXI — igual que `accel_ddr.s`. NO hace falta programar el DMA a mano para la
firma. El A72 ve esa DDR en la fisica que fije `ddr_base` (p.ej. 0x7000_0000) y
la lee con `devmem`.

Firma en DDR (palabras de 32b):
- [0] STATUS tras Sync (bit0 rx_sync)
- [1] STATUS tras Pdelay (bit2 mpd_valid)
- [2] MPD_LO = 40
- [3] MPD_HI = 0
- [4] STATUS tras esclavo (bit3 offset_valid)
- [5] OFFSET = 0
- [7] doorbell 0x0000D0ED

## Validación previa a placa (capa 5 en simulación)

El testbench `tb_ptp_axil_master.vhd` (incluido, PASS) valida la cadena
core->AXI->IP. Para la validación FIEL con el core RTL ejecutando el `.mem`:
integra los cambios anteriores y corre `tb_soc_master` (o una copia) cargando
`ptp_bringup.mem` en el IMEM; comprueba que la firma en `0x7000_0000` coincide
con el oráculo `iss_ptp.py` (STATUS, MPD=40, OFFSET=0, doorbell 0xD0ED).
