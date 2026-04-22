```
          _____           _
         |  ___|____  ____| | ___ _ __
         | |_ / _ \ \/ / _` |/ _ \ '_ \
         |  _| (_) >  < (_| |  __/ | | |
         |_|  \___/_/\_\__,_|\___|_| |_|           /\    /\
                                                 _/  \__/  \_
             a RISC-V softcore den             ,'            '.
            .___________________________.     /   ^       ^    \
            |  RV64GC   1-16 cores      |    (_.   o     o   ._)
            |  Linux-capable, OoO ready |     \\.  \\_/\\_/  .//
            |  Rocket + BOOM + XS slot  |      \\    \\_/    //
            |  Vivado 2023.2, KU5P      |       \\__//=\\__//
            '---------------------------'         )  ||  (
                                                 //   ||   \\
                                                //    ||    \\
                                               (=+====++====+=)
```

# Foxden-risc-v

A mixed Rocket / BOOM / XiangShan-ready RISC-V softcore generator for
AMD FPGAs, focused on the **RIGUKE RK-XCKU5P-F** (Kintex UltraScale+
xcku5p) but portable to any board supported by the vivado-risc-v flow.

Foxden replaces the old `rocket-chip`-based generator in the sibling
`RISC-V-CPU/` project with a **standalone**, licence-clean tree that
ships all its Chisel sources in-tree — no git submodules, no network
fetches at build time.

It plays the same role as MicroBlaze's "application core" on AMD
devices: a Linux-capable soft-CPU you configure through a Vivado-style
GUI, generate HDL for, and drop into a Vivado block design. Performance
targets are substantially higher because Foxden can elaborate an
out-of-order BOOM core on the same board instead of an in-order
MicroBlaze.

```
┌───────────────────────── Foxden 1.x snapshot ────────────────────────┐
│                                                                       │
│     16 configurations        32 extension / opt mixins                │
│      5 config families       26 EXT csv keys + 3 OPT profiles         │
│                                                                       │
│     Rocket RV64GC   ─── 1 / 2 / 4 / 8 cores                           │
│     SmallBOOM  (1-wide) ─── 1 / 2 / 4 cores                           │
│     MediumBOOM (2-wide) ─── 1 / 2 / 4 cores                           │
│     LargeBOOM  (3-wide) / MegaBOOM (4-wide) ─── 1 core                │
│     XiangShan Nanhu  (4-wide) ─── reserved slot (vendoring doc)       │
│                                                                       │
│     Chisel 3.6.1  ·  sbt 1.3  ·  JDK 17  ·  Vivado 2023.2             │
└───────────────────────────────────────────────────────────────────────┘
```

## Table of contents

- [What you get](#what-you-get)
- [Configurations](#configurations)
- [Extensions & optimisation knobs](#extensions--optimisation-knobs)
- [Configuration GUI](#configuration-gui)
- [Quick start](#quick-start)
- [How Foxden fits into RISC-V-CPU](#how-foxden-fits-into-risc-v-cpu)
- [lscpu / /proc/cpuinfo branding](#lscpu--proccpuinfo-branding)
- [Directory layout](#directory-layout)
- [Port / IO surface](#port--io-surface)
- [Performance envelope](#performance-envelope)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License & credits](#license--credits)

## What you get

- **5 core families, 16 ready-to-elaborate configurations.** From a 1-core
  RV64GC in-order Rocket to a 4-wide MegaBOOM single-core, with a reserved
  slot for XiangShan Nanhu as the Chisel-3 flagship OoO upgrade.
- **32 mix-and-match CDE mixins.** Extensions (Zicond, Zfh, NMI, H,
  RVE, B-bundle, …), optimisation profiles (area / balance / performance),
  FPU trim, non-blocking L1, vendor-ID branding, and more — all composable.
- **Vivado-style configurator GUI.** Python/Tk, no pip install, save/load
  `.foxden` presets, one-click "Generate HDL" or "Open Vivado".
- **Standalone tree.** No git submodules, no network during build. `git
  clone` and you're done. 324 MB on disk, ~40 MB generator sources.
- **Linux-capable by default.** Foxden_IO_RV64GC_* configs boot Debian
  RISC-V with UART / Gigabit Ethernet / MicroSD / JTAG debug, using the
  same u-boot + OpenSBI bootchain as vivado-risc-v.
- **Drop-in for RISC-V-CPU.** `make ... FOXDEN=1` from the sibling
  project hands HDL generation to Foxden; existing bitstream / flash
  / JTAG targets keep working.
- **lscpu-friendly identity.** `/proc/cpuinfo` shows
  `model = "Foxden RV64GC Linux SoC"` and `uarch = foxden,foxden-core`
  (or `foxden,foxden-ooo-core` for BOOM tiles).
- **Apache-2.0.** Vendored generators keep their BSD-3-Clause /
  SiFive licences; every vendored tree preserves its upstream LICENSE.

## Configurations

Run `make list-configs` to enumerate them; here's the map:

```
┌── family ──────────────────── class ─────────────── tile ────────── cores ──── fmax on ku5p-2 ─┐
│ 1. In-order RV64GC            Foxden_IO_RV64GC_1   Rocket big      1             125 MHz       │
│    (Linux application core)   Foxden_IO_RV64GC_2   Rocket big      2             125 MHz       │
│                               Foxden_IO_RV64GC_2_L2 Rocket + L2    2             100 MHz       │
│                               Foxden_IO_RV64GC_4   Rocket big      4             100 MHz       │
│                               Foxden_IO_RV64GC_4_L2W L2 + 256-bit  4 ★            100 MHz      │
│                               Foxden_IO_RV64GC_8   Rocket + L2     8              80 MHz       │
│ 2. Small out-of-order         Foxden_OoO_Small_1   SmallBOOM (1w)  1              80 MHz       │
│    (low-area speculative)     Foxden_OoO_Small_2   SmallBOOM       2              80 MHz       │
│                               Foxden_OoO_Small_4   SmallBOOM       4              80 MHz       │
│ 3. Medium out-of-order        Foxden_OoO_Medium_1  MediumBOOM (2w) 1 ★           62.5 MHz      │
│    (balanced IPC + area)      Foxden_OoO_Medium_2  MediumBOOM      2             62.5 MHz      │
│                               Foxden_OoO_Medium_4  MediumBOOM      4             62.5 MHz      │
│ 4. Flagship single core       Foxden_OoO_Large_1   LargeBOOM (3w)  1 ★           62.5 MHz      │
│                               Foxden_OoO_Mega_1    MegaBOOM  (4w)  1             50   MHz      │
│ 5. XiangShan Nanhu  (reserved)Foxden_OoO_XS_1      XS Nanhu (4w)   1             50   MHz *    │
│                               Foxden_OoO_XS_2      XS Nanhu (4w)   2             50   MHz *    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
  ★ recommended in the class       * estimated - XS is not vendored in 1.x (see memory notes)
```

## Extensions & optimisation knobs

Pass any csv combination to `EXT=`, one profile to `OPT=`.

```
EXT options (26)
  ┌─ hardware-backed ─────────────────────────────────────────────────────────┐
  │ zicond   zfh   zfhmin   zihintpause   nmi   rve   e   noc   cflush        │
  │ clockgate   nocease   hypervisor   h   nofpu   fpu-nodivsqrt              │
  │ nonblocking-l1                                                             │
  └───────────────────────────────────────────────────────────────────────────┘
  ┌─ advisory only (DTS-tagged, no HW on this rocket-chip) ───────────────────┐
  │ zba   zbb   zbs   zbc   b   bitmanip                                      │
  │ zicbom   zicboz   zacas   zk   crypto   aia   svpbmt   svinval            │
  └───────────────────────────────────────────────────────────────────────────┘
  ┌─ vector (requires companion generator drop) ─────────────────────────────┐
  │ vector   v     (Saturn)                                                   │
  │ v-ara          (Ara, SystemVerilog)                                       │
  └───────────────────────────────────────────────────────────────────────────┘

OPT profile    L1 I/D        L1 assoc.   BTB    Mul/Div      Typical use
  area         64 set        2-way       off    default      Tight LUT budgets
  balance *    64 set        4-way       on     default      Sensible default
  performance  128 set       8-way       on     fast         Max IPC
```

`make list-extensions` prints the menu with one-line descriptions.

## Configuration GUI

```
   ┌────────────────────────────────────────────────────────────────────────────┐
   │  Foxden-risc-v Configurator                      Vivado / KU5P ready       │
   ├─────────────┬──────────────────────────────────────────────────────────────┤
   │  Summary    │  General │ Memory │ Extensions │ Optimisation │ Peripherals  │
   │             │                                                              │
   │ CONFIG: …   │   Family       [ 1. In-order RV64GC (Linux)             ]   │
   │ BOARD:  …   │   Config       [ Foxden_IO_RV64GC_4_L2W                 ]   │
   │ CLK:    100 │   Board        [ rk-xcku5p                              ]   │
   │ DRAM:   2G  │   Clock   [ 100 ] MHz       DRAM [ 0x80000000 ]             │
   │ OPT:    bal │                                                              │
   │ EXT: zicond │                                                              │
   │             │                                                              │
   │ make …      │                                                              │
   ├─────────────┴──────────────────────────────────────────────────────────────┤
   │  [Load preset] [Save preset]  [Write config]  [Generate HDL]  [Close]      │
   └────────────────────────────────────────────────────────────────────────────┘
```

`make gui` or `python3 gui/foxden_configurator.py` (pure standard-library
Tk, no pip install needed). Presets are JSON `.foxden` files you can
check into a board repo.

## Quick start

```bash
# Prereqs: Vivado 2023.2, gcc-riscv64-linux-gnu, JDK 17, riscv64-unknown-elf-gcc,
# and hw_server running if you want to flash the board.

# 1. Pick a configuration and emit HDL (VHDL + Verilog + DTS)
make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W OPT=balance hdl

# 2. Create the Vivado project  (see "Troubleshooting" for the fresh-project quirk)
make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W vivado-project

# 3. Build bitstream  (~45 min on an 8-core host)
make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W bitstream

# 4. Flash QSPI via the running hw_server
make BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_4_L2W flash

# Optional: launch the GUI
make gui
```

Full rebuild from scratch is ~3 min of Scala compile + elaboration, plus
Vivado impl time. All downstream targets (Linux kernel, u-boot, OpenSBI,
Debian rootfs) are reused from the sibling `RISC-V-CPU/` tree.

## How Foxden fits into RISC-V-CPU

Two equally-valid entry points:

```
                                                  ┌─────────────────┐
                             ┌──────────────────► │   Foxden only   │
                             │  make hdl          │  (this repo)    │
                             │  make vivado-*     │                 │
     ┌────────────┐          │                    │  ── bitstream,  │
     │  you pick  │──────────┤                    │     flash via   │
     │   CONFIG=  │          │                    │     Foxden Mk.  │
     └────────────┘          │                    └─────────────────┘
                             │
                             │                    ┌──────────────────────────┐
                             └──────────────────► │  RISC-V-CPU + FOXDEN=1   │
                                make FOXDEN=1     │  (sibling project)       │
                                bitstream flash   │                          │
                                                  │  ── uses Foxden for HDL, │
                                                  │     then drives its own  │
                                                  │     Linux/u-boot/SBI +   │
                                                  │     Debian rootfs flow   │
                                                  └──────────────────────────┘
```

See `docs/MIGRATION.md` for the full table of "old rocket64* config"
→ "new Foxden_* config" mappings.

## lscpu / /proc/cpuinfo branding

The generated DTS is post-processed so Linux identifies the host as
Foxden rather than raw sifive / ucb-bar strings:

```
# /proc/cpuinfo on a Foxden_IO_RV64GC_4_L2W bitstream
processor   : 0
hart        : 0
isa         : rv64imafdc
mmu         : sv39
uarch       : foxden,foxden-core
hardware    : Foxden RV64GC Linux SoC
```

BOOM tiles show `uarch: foxden,foxden-ooo-core`.  Under `lscpu` you get
the AMD-style summary: CPU(s), Core(s)/socket, Caches, Vendor ID.  Full
rationale in `memory/lscpu-branding.md`.

## Directory layout

```
Foxden-risc-v/
├── README.md   LICENSE  NOTICE  .gitignore  build.sbt  Makefile  vivado.tcl
├── src/main/scala/foxden/        # Foxden-only Scala (6 config files + system)
│   ├── system/FoxdenSystem.scala
│   └── configs/
│       ├── FoxdenBase.scala           · shared config scaffolding
│       ├── FoxdenExtensions.scala     · 32 CDE mixins
│       ├── FoxdenInOrder.scala        · family 1 (Rocket RV64GC)
│       ├── FoxdenSmallOoO.scala       · family 2 (SmallBOOM)
│       ├── FoxdenMedOoO.scala         · family 3 (MediumBOOM)
│       ├── FoxdenLarge.scala          · family 4 (LargeBOOM + MegaBOOM)
│       └── FoxdenXiangShan.scala      · family 5 (XS Nanhu — reserved slot)
├── generators/                   # vendored, .git stripped (38 MB total)
│   ├── rocket-chip/     riscv-boom/     sifive-cache/
│   ├── testchipip/      targetutils/
├── gui/foxden_configurator.py    # Tk GUI (Microblaze-style)
├── board/
│   ├── rk-xcku5p/                · primary target: xdc, board_files, BD TCL
│   └── common/                   · jtag / program-flash / foxden-freq
├── bootrom/  uart/  sdc/  ethernet/  vhdl-wrapper/  # SoC infra
├── patches/                       # kernel / u-boot / opensbi diffs
├── docs/                          # committed docs
│   ├── EXTENSIONS.md     MIGRATION.md     STATUS.md     gui-layout.txt
└── memory/                        # developer notebook (gitignored)
    ├── README.md   architecture.md    vendoring.md    chisel-version.md
    ├── lscpu-branding.md   xiangshan-integration.md   ideas.md   todo.md
```

## Port / IO surface

FoxdenSystem exports the same IO as vivado-risc-v's RocketSystem, so
the KU5P board TCL is reused unchanged:

```
                  ┌───────────── FoxdenSystem ─────────────┐
   sys_reset ───► │                                         │
   clock     ───► │    RV64GC / BOOM / (XS)  1-16 harts     │ ◄─── 8 ext interrupts
   debug_clk ───► │                                         │
                  │    L1I + L1D per hart                   │
                  │    optional 512 KB SiFive inclusive L2  │
                  │                                         │
                  │  MEM_AXI4   ─────────────────────────►  │ ─► DDR4 (2 GB on KU5P)
                  │  IO_AXI4    ─────────────────────────►  │ ─► UART / SDC / ETH / user
                  │  DMA_AXI4   ◄────────────────────────── │ ◄─ GMII DMA / PCIe / user DMA
                  │  S_BSCAN   ◄────── JTAG bridge ───────► │ ◄─ OpenOCD / xsdb
                  │                                         │
                  └─────────────────────────────────────────┘
```

Peripheral map (Linux view — unchanged from vivado-risc-v):

```
   0x0000_0000  DDR4 SDRAM  (up to 14 GB)
   0x6000_0000  SD card controller   IRQ 2   driver riscv,axi-sd-card-1.0
   0x6001_0000  UART console         IRQ 1   driver riscv,axi-uart-1.0
   0x6002_0000  GbE DMA              IRQ 3   driver riscv,axi-ethernet-1.0
   0x0C00_0000  PLIC
   0x0200_0000  CLINT
   0x0001_0000  Debug module
```

## Performance envelope

Fmax targets baked into `board/common/foxden-freq` (KU5P, -2 speed grade,
Vivado 2023.2, post-P&R):

```
                 ┌── 125 MHz ─── Foxden_IO_RV64GC_{1,2}
                 │
      Rocket ────┤── 100 MHz ─── Foxden_IO_RV64GC_{2_L2, 4, 4_L2W}
                 │
                 └──  80 MHz ─── Foxden_IO_RV64GC_8
                 ┌──  80 MHz ─── Foxden_OoO_Small_*
                 │
      BOOM   ────┤── 62.5 MHz ─── Foxden_OoO_Medium_*  and Foxden_OoO_Large_1
                 │
                 └──  50 MHz ─── Foxden_OoO_Mega_1
      XiangShan ─── 50 MHz (estimated; not yet synthesised)
```

IPC ordering (relative to Rocket big @ 1.0):

```
   Rocket big  ──────────────────────────── 1.0  (in-order baseline)
   SmallBOOM   ──────────────────────────── 1.1  (1-wide OoO, small ROB)
   MediumBOOM  ───────────────────────────── 1.4  (2-wide, TAGE-L BPD)
   LargeBOOM   ────────────────────────────── 1.7  (3-wide, bigger LSU)
   MegaBOOM    ─────────────────────────────── 1.9  (4-wide)
   XS Nanhu    ─────────────────────────────── 2.0+ (TAGE-SC-L + ITTAGE)
```

Measurements TBD per config — tracked in `memory/todo.md`.

## Troubleshooting & FAQ

**`make vivado-project` errors with `[BD 5-232] No interface pins matched RocketChip/DMA_AXI4`.**
This is a Vivado 2023.2 quirk with fresh projects + VHDL entities; see
`docs/STATUS.md` for the full attempted-fix matrix. Workaround: run the
build through RISC-V-CPU with `FOXDEN=1`, which has the IP catalog
already primed.

**sbt fails trying to download `rocketchip 1.2.+`.**
Happens if `generators/testchipip/build.sbt` still has the
`libraryDependencies += "edu.berkeley.cs" %% "rocketchip" % "1.2.+"`
line. Foxden strips it — if you're vendoring a different testchipip,
do the same.

**bootrom build complains about missing `gnu/stubs-lp64.h`.**
Your `$PATH` is pointing to `riscv64-linux-gnu-gcc` (glibc) for bare-metal
code. The Makefile auto-detects `riscv64-unknown-elf-gcc` under
`workspace/gcc/riscv/bin/` (shared with RISC-V-CPU) — if you haven't
downloaded that toolchain yet, `apt install gcc-riscv64-unknown-elf`
or run `make -C ../RISC-V-CPU workspace/gcc/riscv`.

**Which config should I pick first?**
`Foxden_IO_RV64GC_4_L2W` — quad-core Rocket RV64GC with a 512 KB L2
and a 256-bit memory edge. It's the closest to MicroBlaze's
"application core" profile, Linux-ready at 100 MHz on KU5P.

**Can I mix BOOM and Rocket tiles?**
Yes, via CDE composition: stack `WithNSmallBooms(1)` on top of a
`Foxden_IO_RV64GC_4` and you'll get 4 Rocket + 1 BOOM. A dedicated
`WithFoxdenHetero` sugar is on the roadmap — see `memory/ideas.md`.

**Where did Chisel 6 support go?**
Deferred to Foxden 2.x. Rationale in `memory/chisel-version.md` —
the short version is the FIRRTL→CIRCT migration breaks the
VHDL-wrapper flow the KU5P board TCL expects.

## Roadmap

Near-term (1.x):
- [ ] `ipx::package_project` fix for the fresh-project Vivado BD quirk.
- [ ] Bitstream + JTAG boot verification end-to-end on KU5P.
- [ ] Per-config LUT / BRAM / DSP utilisation table.

Foxden 2.x:
- [ ] Migrate to Chisel 6 / CIRCT firtool.
- [ ] Vendor XiangShan Kunminghu as the 5th family (flagship).
- [ ] Replace the VHDL wrapper with a smaller Python generator.

See `memory/todo.md` (current work, blockers) and `memory/ideas.md`
(forward-looking).

## Contributing

Add a new extension in four steps:

1. Add a `WithFoxden*` class in
   [`src/main/scala/foxden/configs/FoxdenExtensions.scala`][ext]
   (use the `RocketCoreEdit` / `RocketTileEdit` helpers).
2. Wire a csv key → mixin mapping in the `ext_map` function in
   [`Makefile`][mk].
3. Add a `(key, label)` tuple to the `EXTENSIONS` list in
   [`gui/foxden_configurator.py`][gui].
4. Document it in [`docs/EXTENSIONS.md`][docs-ext].

Bigger surgery (adding a new tile / family) — see the procedure in
`memory/xiangshan-integration.md`.

[ext]:      src/main/scala/foxden/configs/FoxdenExtensions.scala
[mk]:       Makefile
[gui]:      gui/foxden_configurator.py
[docs-ext]: docs/EXTENSIONS.md

## License & credits

Apache-2.0 for all original Foxden additions.  Vendored generators
keep their upstream licences unchanged — full breakdown in
[`LICENSE`][LICENSE] and [`NOTICE`][NOTICE].

Foxden stands on:

- [rocket-chip](https://github.com/chipsalliance/rocket-chip) (Berkeley / SiFive)
- [riscv-boom](https://github.com/riscv-boom/riscv-boom) (Berkeley / BOOM team)
- [sifive-cache](https://github.com/sifive/block-inclusivecache-sifive) (SiFive)
- [testchipip](https://github.com/ucb-bar/testchipip) (UCB BAR)
- [vivado-risc-v](https://github.com/eugene-tarassov/vivado-risc-v) (Eugene Tarassov)
- [chipyard](https://github.com/ucb-bar/chipyard) (UCB BAR) — pattern inspiration
- [OpenXiangShan/XiangShan](https://github.com/OpenXiangShan/XiangShan) — XS Nanhu slot

[LICENSE]: LICENSE
[NOTICE]:  NOTICE

```
            *  *  *       built for KU5P, portable everywhere       *  *  *
```
