# lscpu / /proc/cpuinfo branding

User ask: make `lscpu` on Linux show a Foxden identity the same way
`lscpu` on an AMD host shows `AMD Ryzen 9 9950X 16-Core Processor`.

## How Linux populates /proc/cpuinfo on RISC-V

`arch/riscv/kernel/cpu.c` prints one block per hart, reading:

- `processor` - DT `cpus/cpu@N` index
- `hart`      - DT `reg` of the cpu node
- `isa`       - DT `riscv,isa` string
- `mmu`       - DT `mmu-type` string (e.g. `riscv,sv39`)
- `uarch`     - DT `riscv,microarch` / top-node `compatible` first token
- `hardware`  - DT root `model` string (appears as "Hardware" in cpuinfo)

## How we brand Foxden

1. **Root model string** - `WithFoxdenDTS("Foxden RV64GC Linux SoC")`
   sets the DT root `compatible = "foxden,foxden-risc-v"` and `model`
   fields via rocket-chip's `WithDTS`.

2. **Per-CPU compatible** - the Makefile HDL rule post-processes the
   generated DTS:
   ```
   sed 's#compatible = "sifive,rocket0", "riscv"#compatible = "foxden,foxden-core", "sifive,rocket0", "riscv"#'
   ```
   so each CPU node's `compatible` list *starts with* `foxden,foxden-core`
   (or `foxden,foxden-ooo-core` for BOOM tiles).  Linux prints the first
   token under `uarch`.

3. **ISA string** - inherited from rocket-chip; for the default
   Foxden_IO_RV64GC_* configs this is `rv64imafdc`. Extensions selected
   via `EXT=` append to this string so `lscpu` sees e.g.
   `rv64imafdc_zicond`.

## Expected lscpu output

```
# lscpu
Architecture:          riscv64
  Byte Order:          Little Endian
CPU(s):                4
  On-line CPU(s) list: 0-3
Vendor ID:             foxden,foxden-core
  Model name:          Foxden RV64GC Linux SoC
  CPU family:          RISC-V 64 (RV64GC)
  Core(s) per socket:  4
  Socket(s):           1
Caches (sum of all):
  L1i:                 64 KiB (4 instances)
  L1d:                 64 KiB (4 instances)
  L2:                  512 KiB
```

Not every util-linux version prints "Vendor ID" on RISC-V, but the
`/proc/cpuinfo` `hardware` line is always honoured and ends up in the
lscpu verbose output too.
