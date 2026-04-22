# Foxden ISA extensions & micro-architecture knobs

Pass one or more keys to `EXT=` (csv) to opt in.  The same names show up
as checkboxes in the GUI.  The top-level Makefile maps each to a CDE
mixin that prepends to the selected `CONFIG`.

## Extension matrix

### Hardware-backed (real hardware on the vendored rocket-chip)

| EXT key        | Foxden mixin                    | What it does |
|----------------|---------------------------------|--------------|
| `zicond`       | `WithFoxdenZicond`              | Sets `useConditionalZero = true`; enables `czero.eqz/nez`. |
| `zfh`, `zfhmin`| `WithFoxdenZfh`                 | Enables IEEE 16-bit half-precision float via `WithFP16`. |
| `zihintpause`  | `WithFoxdenZihintpause`         | Advisory marker - Rocket always implements `pause` as a HINT. |
| `nmi`          | `WithFoxdenNMI`                 | Sets `useNMI = true`; adds the non-maskable interrupt CSRs. |
| `rve`, `e`     | `WithFoxdenRVE`                 | RV64E: 16-register embedded ABI. Incompatible with `hypervisor`. |
| `noc`          | `WithFoxdenNoC`                 | Drops the C (compressed) extension - plain RV64IMAFD. |
| `cflush`       | `WithFoxdenCFlush`              | Non-standard L1 cache-flush instruction (firmware debug). |
| `clockgate`    | `WithFoxdenClockGate`           | Gate tile clocks via `EICG_wrapper`. |
| `nocease`      | `WithFoxdenNoCease`             | Disable the non-standard CEASE instruction. |
| `hypervisor`, `h` | `WithFoxdenHypervisor`       | Enables H-extension; L1 TLB granularity drops to 4 KB. |
| `nofpu`        | `WithFoxdenNoFPU`               | Drop the FPU entirely. Kernel must be soft-float. |
| `fpu-nodivsqrt`| `WithFoxdenFPUNoDivSqrt`        | Keep FPU but omit FDIV / FSQRT (large in LUTs). |
| `nonblocking-l1` | `WithFoxdenNonblockingL1`     | Convert L1 D$ to non-blocking with 2 MSHRs. |

### Advisory only (no hardware on the Chisel-3 rocket-chip we vendor)

These mixins are no-ops at the RTL level.  They are retained so the
build surface matches the upstream extension names, and so a future
rocket-chip fork that implements them can flip these to real mixins
without changing the user-facing API.  Software binaries compiled with
`-march=rv64gc_zbb`, etc., still run via M-mode emulation trap handlers.

| EXT key        | Foxden mixin                 |
|----------------|------------------------------|
| `zba`          | `WithFoxdenZba`              |
| `zbb`          | `WithFoxdenZbb`              |
| `zbs`          | `WithFoxdenZbs`              |
| `zbc`          | `WithFoxdenZbc`              |
| `b`, `bitmanip`| `WithFoxdenZba` + `WithFoxdenZbb` + `WithFoxdenZbs` |
| `zicbom`, `zicboz` | `WithFoxdenZicbom`       |
| `zacas`        | `WithFoxdenZacas`            |
| `zk`, `crypto` | `WithFoxdenZk`               |
| `aia`          | `WithFoxdenAIA`              |
| `svpbmt`       | `WithFoxdenSvpbmt`           |
| `svinval`      | `WithFoxdenSvinval`          |

### Vector (V) - requires a companion generator

| EXT key     | Foxden mixin                | Status |
|-------------|-----------------------------|--------|
| `vector`, `v` | `WithFoxdenVector`        | **fails build** until Saturn is vendored; see `memory/todo.md`. |
| `v-ara`     | `WithFoxdenVectorAra`       | **fails build** until Ara is vendored; SystemVerilog integration is a larger task. |

## Micro-architecture profiles (OPT=…)

| OPT value       | Foxden mixin                | Effect |
|-----------------|-----------------------------|--------|
| `area`          | `WithFoxdenAreaOpt`         | 64-set / 2-way L1s, BTB off. Smallest footprint. |
| `balance` *(default)* | `WithFoxdenBalancedOpt` | 64-set / 4-way L1s, 1 MSHR. |
| `performance`, `perf` | `WithFoxdenPerfOpt`   | 128-set / 8-way L1s, 2 MSHRs, fast mul/div, fast load-word+byte. |

## Combining

Extension mixins stack left-to-right ahead of the optimization mixin
and the config class.  `EXT=zicond,nmi OPT=performance CONFIG=Foxden_IO_RV64GC_4_L2W`
produces the CDE chain

```
foxden.WithFoxdenZicond ++
foxden.WithFoxdenNMI ++
foxden.WithFoxdenPerfOpt ++
foxden.Foxden_IO_RV64GC_4_L2W
```

## Adding a new extension

1. Add a `WithFoxden*` class in `src/main/scala/foxden/configs/FoxdenExtensions.scala`
   (use `RocketCoreEdit { core => core.copy(...) }` or `RocketTileEdit` for
   tile-level changes, and `WithHypervisor` / `WithFP16` style inheritance for
   pre-existing subsystem mixins).
2. Extend the `ext_map` function in the top-level `Makefile` with a new csv key.
3. Add a tuple in `gui/foxden_configurator.py`'s `EXTENSIONS` list.
4. Add a row in the appropriate table above.

## Future work

See `memory/todo.md` and `memory/xiangshan-integration.md` for:
- Saturn / Ara vector unit vendoring.
- Zbb hardware via a newer rocket-chip fork.
- Zicbom / Zicboz / Zacas via a Chisel-6 rocket-chip port.
- Sm/Ss-AIA via IMSIC + APLIC IP integration.
- XiangShan Nanhu as the flagship OoO family (reserved
  `Foxden_OoO_XS_*` slot already exists).
