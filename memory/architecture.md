# Architecture notes

## The four families

| # | Family          | Role                                         | Tile     | Width | ROB  | L1I/D  | L2  | Target |
|---|-----------------|----------------------------------------------|----------|-------|------|--------|-----|--------|
| 1 | In-order RV64GC | Linux "application core", MicroBlaze-analog  | Rocket   | 1     | n/a  | 16K/16K| opt | 1/2/4/8 cores |
| 2 | Small OoO       | Tight LUT budget, still speculative          | SmallBOOM| 1     | 32   | 16K/16K| 512K| 1/2/4 cores |
| 3 | Medium OoO      | Balanced IPC + area                          | MediumBOOM| 2    | 64   | 32K/32K| 512K| 1/2/4 cores |
| 4 | Large OoO       | Single-core max perf                         | LargeBOOM | 3    | 96   | 32K/64K| 1M  | 1 core  |
|   |                 | Optional Mega single-core                    | MegaBOOM  | 4    | 128  | 64K/64K| 1M  | 1 core  |

## Shared SoC top

All four families plug into one `FoxdenSystem` Scala module:

```
FoxdenSystem (RocketSubsystem)
├── HasAsyncExtInterrupts           # 8 ext interrupts
├── CanHaveMasterAXI4MemPort        # DDR path
├── CanHaveMasterAXI4MMIOPort       # UART / SDC / ETH / user
├── CanHaveSlaveAXI4Port            # Ethernet / DMA
└── BootROM (workspace/bootrom.img)
```

The same Vivado block-design TCL from vivado-risc-v reuses this top
because the port set is identical; only the instance naming differs (we
keep `RocketChip` as the BD cell name for source compatibility).

## Memory subsystem knobs

- `FoxdenBaseConfig`      - 64-bit memory edge, no L2.
- `FoxdenWideBusConfig`   - 256-bit memory edge; used by all OoO configs.
- `WithInclusiveCache`    - 512 KB SiFive inclusive L2 by default.
- `WithNBanks(N)`         - extra banks for >2-core setups.

For OoO configs we stack `WithInclusiveCache ++ FoxdenWideBusConfig` by
default - BOOM is memory-bandwidth-bound without L2, and you lose most
of the reorder window waiting on DDR.

## Clock targets (KU5P, Vivado 2023.2)

- In-order 4-core: **100 MHz** (same as vivado-risc-v flagship)
- In-order 1/2-core: 100-125 MHz
- SmallBOOM 1-core: 80-100 MHz
- MediumBOOM 1-core: 62.5-80 MHz (TAGE predictor + wide LSU)
- LargeBOOM 1-core: 50-62.5 MHz
- MegaBOOM: 50 MHz maximum, expect P&R pain

Numbers above are ballpark from upstream boom/rocket-chip results on
comparable UltraScale+ parts - tighten with `board/common/foxden-freq`
once we have first synthesis runs.
