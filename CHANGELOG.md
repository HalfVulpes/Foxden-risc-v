# Changelog

All user-visible changes to Foxden-risc-v.  Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); version numbers are
semver with the caveat that anything before 1.0 is subject to change
without deprecation cycles.

## [Unreleased]

### Added
- (nothing yet)

### Changed
- (nothing yet)

### Fixed
- (nothing yet)

## [0.2.0] - 2026-04-22

Second pass of the first-day scaffold.  Extension surface grew 6.4x, a
5th core family slot (XiangShan Nanhu) was reserved, and the build
chain was verified end-to-end through VHDL wrapper emission.

### Added
- **Family #5: XiangShan Nanhu (reserved slot).** Classes
  `Foxden_OoO_XS_1` / `Foxden_OoO_XS_2` live in
  `src/main/scala/foxden/configs/FoxdenXiangShan.scala`.  Raising
  `RuntimeException` with actionable vendoring instructions until the
  XS `nanhu` branch is dropped into `generators/xiangshan/`.
- **27 new extension / tuning mixins** in `FoxdenExtensions.scala`
  (5 → 32 total): Zicond, Zfh, Zihintpause, NMI, RVE, NoC, CFlush,
  ClockGate, NoCease, VendorID, Zba, Zbb, Zbs, Zbc, Zicbom, Zacas,
  Zk, AIA, Svpbmt, Svinval, NoFPU, FPUNoDivSqrt, NonblockingL1,
  CacheBlock, NPMPs, NPerfCounters, VectorAra.  26 csv keys wired in
  the Makefile (`ext_map`), matched in the GUI.
- **B-bundle alias**: `EXT=b` expands to `zba,zbb,zbs`.
- **GUI**: extensions tab now lays out 26 checkboxes in 3 columns.
- **New docs**: `CHANGELOG.md` (this file), `docs/STATUS.md`,
  `docs/EXTENSIONS.md` (rewritten), `memory/xiangshan-integration.md`,
  `memory/ideas.md`.
- **Research log**: 2024-2026 OSS OoO core survey in
  `memory/xiangshan-integration.md` (XiangShan Nanhu picked as the
  only Chisel-3-compatible upgrade above LargeBOOM; Kunminghu /
  Nanhu-V5 / Tenstorrent Ascalon / NaxRiscv / VexiiRiscv / CVA6+HPDcache /
  OpenC910 all evaluated).

### Changed
- `WithFoxdenDTS` now sets the DTS **`model`** field to
  `"Foxden RV64GC Linux SoC"` (was accidentally a short vendor
  string).  Linux `/proc/cpuinfo`'s `hardware` line now reads this.
- `RocketCoreEdit` / `RocketTileEdit` internal helpers factor the
  CDE tile-walking boilerplate, making the mixin file one-liners.
- Makefile `list-extensions` prints the full 26-key menu, grouped by
  (hardware / advisory / vector / FPU trim / memory).
- BOOM CPU-node `compatible` rewrite uses the correct upstream prefix
  `ucb-bar,boom0` (was `sifive,boom0`).  Post-processed DTS shows
  `compatible = "foxden,foxden-ooo-core", "ucb-bar,boom0", "riscv"`
  for BOOM tiles — Linux `uarch:` comes out `foxden,foxden-ooo-core`.
- VHDL wrapper (`vhdl-wrapper/src/net/largest/riscv/vhdl/Main.java`)
  extended with a `-t <top>` flag so the top Verilog module name is
  no longer hard-coded to `RocketSystem`.  The Makefile passes
  `-t FoxdenSystem` now; legacy `-m` still sets the emitted VHDL
  entity name.
- `board/common/foxden-freq`: matching now keys off the plain
  `Foxden_*` class name (dropped `foxden.` prefix).  Fmax table
  calibrated per family / core count on KU5P -2.
- `.gitignore`: `memory/*` is now excluded (notebook is private).

### Fixed
- `testchipip/build.sbt` stripped the
  `libraryDependencies += "edu.berkeley.cs" %% "rocketchip" % "1.2.+"`
  line that otherwise tried to fetch an unrelated Maven artifact on a
  fresh sbt cache.
- `sbt runMain freechips.rocketchip.diplomacy.Main` requires an
  absolute `--dir`; the Makefile now uses `realpath` everywhere.
- `workspace/bootrom.img` placeholder is now auto-created so a
  bare `sbt runMain` from a clean checkout elaborates without a
  `java.nio.file.NoSuchFileException`.
- Makefile auto-detects `riscv64-unknown-elf-gcc` in this order:
  `workspace/gcc/riscv/bin/`, `../RISC-V-CPU/workspace/gcc/riscv/bin/`,
  then `$PATH`.  No more unexplained `gnu/stubs-lp64.h` failures.

### Known blockers (carried forward)
- Vivado 2023.2 fresh-project BD fails to auto-infer AXI4 interfaces
  on the VHDL entity, despite 115 `X_INTERFACE_INFO` attributes.
  Five fixes attempted (update_compile_order, update_module_reference
  two ways, VHDL 2008, close/reopen), none worked.  Real fix is
  `ipx::package_project`.  Tracked in `memory/todo.md`; workaround
  is the RISC-V-CPU `FOXDEN=1` path.

## [0.1.0] - 2026-04-22

Initial scaffold.

### Added
- Standalone tree layout; vendored generators (rocket-chip,
  riscv-boom, sifive-cache, testchipip, targetutils) without
  `.git` metadata.
- Four config families, 14 classes (Foxden_IO_RV64GC_*,
  Foxden_OoO_Small/Medium/Large/Mega).
- Initial 5 extension mixins (Zicond, Zbb advisory, NMI, Hypervisor,
  Vector-throw).
- Base CDE scaffolding (FoxdenBaseConfig / FoxdenWideBusConfig) and
  the top-level `FoxdenSystem` SoC wrapper.
- Makefile, build.sbt, vivado.tcl, board/rk-xcku5p/, board/common/.
- GUI (`gui/foxden_configurator.py`, ~420 LOC, pure Tk).
- Apache-2.0 LICENSE + NOTICE with upstream attribution; .gitignore.
- `docs/`: README.md, MIGRATION.md, EXTENSIONS.md, gui-layout.txt.
- `memory/`: architecture.md, vendoring.md, chisel-version.md,
  lscpu-branding.md, todo.md.
- `RISC-V-CPU/foxden.mk` shim so `make FOXDEN=1` from the legacy
  project forwards HDL generation to Foxden.
