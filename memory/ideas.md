# Foxden forward-looking idea dump

Not a TODO — a holding pen for directions worth considering when
Foxden 1.x is stable enough to move beyond feature-parity with the
vivado-risc-v flow. Items here are opinionated, not committed.

## Core / micro-architecture

- **Heterogeneous tile sets.** Already possible by hand via CDE
  composition (1× LargeBOOM + 3× Rocket big in one subsystem). Add a
  `WithFoxdenHetero(cpu1, cpu2, ...)` sugar and surface it in the GUI
  as a drag-and-drop tile canvas à la Microblaze's AXI IP list.
- **Core-per-socket style layouts.** Useful once NUMA gets meaningful
  latency on FPGA — clusters of 2-4 cores with their own L2 and a
  crossed TileLink interconnect.
- **Dark-silicon gating.** Per-tile power-down with clock + reset
  crossings driven by a top-level register; useful for thermal demos
  on bigger FPGAs.
- **Spike companion harness.** Foxden-sim target that produces a
  cycle-accurate RTL + Spike-backed ISA model for self-checking on
  every commit.

## ISA extensions worth promoting from advisory → hardware

- **Zbb / Zba / Zbs** via a Zbb-capable rocket-chip fork (there are a
  few on GitHub); the Foxden mixins are already named, just need the
  backing hardware.
- **Zacas + Zabha atomics** - small core patch, useful for modern
  Linux crypto and lock-free data structures.
- **Zicbom / Zicboz** - cache-block management, required by a growing
  number of device drivers (DMA buffers in particular).
- **Smaia + Ssaia + IMSIC/APLIC** - a real AIA port is a big-ish
  chunk of work but pays off for >8 core / many-interrupt scenarios.
- **Smstateen + Smcdeleg** - supervisor-mode counter delegation.
- **Ssccfg / Ssqosid** - QoS for shared-resource accounting (Linux
  6.6+ has hooks).

## Vector unit candidates

- **Saturn** (Berkeley, Chisel) - primary slot for
  `WithFoxdenVector`. Pipeline-first design, good match for an IPC-
  focused OoO. Steps enumerated in `todo.md`.
- **Ara** (ETH Zürich, SystemVerilog) - alternative; much larger
  throughput but pairs naturally with CVA6 rather than Rocket/BOOM.
- **Skim a VPU from XiangShan Nanhu** once XS is vendored - their V
  unit is RVV 1.0 compliant and ships with a TAGE-flavoured BPD.

## Top-of-the-tree OoO options

| Candidate | Why | Blocker |
|-----------|-----|---------|
| XiangShan Kunminghu / KMH | 6-wide OoO, TAGE-SC-L + ITTAGE, best open-source IPC | Chisel 6 (await Foxden 2.x) |
| XiangShan Nanhu-V5 | Chisel-6 successor to Nanhu, tidier codebase | Chisel 6 |
| Tenstorrent Ascalon | 2026's top perf/watt RV64 | Closed-source IP; not an option |
| `openhwgroup/cva6` (SS) | Mature, good docs | SystemVerilog; superscalar in-order |
| BOOMv4 + LSPA | Next-gen LSU, out-of-order stores | Chisel 6 |

## Memory subsystem

- **RoCC accelerator slots.** Keep Gemmini on the shortlist; add a
  `WithFoxdenRoCC(builder)` sugar that the GUI turns into
  "Attach accelerator…" menu.
- **CHERI-RISC-V guard bit path.** Big, but a demo-able wiring in a
  single-core Foxden variant would stand out.
- **Coherent L3.** Right now we stop at 512 KB inclusive L2. A tiled
  L3 (constellation-style) lands well on xcku5p's DDR bandwidth.
- **LPDDR4 support.** The board has DDR4 but the generator should
  take an LPDDR4 MIG config as a swap-in.

## Toolchain / flow

- **Chisel 6 branch.** Foxden 2.x: drop vendored rocket-chip sources,
  use chipyard's rocket-chip at a pinned SHA via a Makefile target
  that just `git checkout`s a release tag and patches the outer
  build. Keeps standalone property, drops ~50 MB of tree.
- **FIRRTL → CIRCT/firtool.** Replace the FIRRTL stage with firtool
  invocation. Needed for Chisel 6 and for any modern config that
  relies on post-FIRRTL passes.
- **VHDL wrapper rewrite.** The java+antlr wrapper we vendored works
  but is crusty. Re-port to a small Python module that reads Verilog
  port declarations and emits VHDL entities with X_INTERFACE_INFO
  attributes — drop the antlr4 runtime dep entirely.
- **Vivado 2024.x / 2025.x support.** Currently pinned to 2023.2 for
  QSPI safety reasons; the BD inference quirk we hit may actually be
  fixed in newer releases.
- **Bitstream-cache in workspace/.** Hash the `(CONFIG, BOARD, EXT,
  OPT)` tuple; cache the `.mcs` in `~/.cache/foxden/` so re-running
  the same flow skips 45 min of P&R.

## GUI

- **Live constraint preview.** As the user toggles extensions the
  summary pane could estimate LUT / BRAM / DSP draw using pre-measured
  data points (once we have them).
- **"What changes?" diff view.** When EXT / OPT changes, show the
  CDE chain diff.
- **Generate IPXACT.** Emit `.xcix` alongside the bitstream so a
  Vivado user can drop the whole Foxden SoC into IP Integrator as one
  block without opening the GUI at all.
- **Web front-end.** Port the Tk GUI to Flask + htmx so it runs over
  SSH. Useful for FPGA farms.
- **Config presets shipped in `gui/presets/*.foxden`.** "Minimal",
  "Balanced", "Performance", "Server", "Linux-capable", each matched
  to a flagship config so the first-use story is a single click.

## Software / workload

- **Debian image bake.** Extend RISC-V-CPU's existing rootfs recipe
  with Foxden-branded `/etc/os-release` and `/proc/cpuinfo` demo.
- **CoreMark / SPEC harness.** Parameterised make target that runs
  a benchmark under QEMU or on-board and publishes to `docs/benchmarks/`.
- **Power / temperature logging.** `docs/thermal/` with a 5-min
  `stress-ng` run per config — useful baseline for would-be porters.
- **OpenSBI upstreaming.** vivado-risc-v patches OpenSBI; the diff is
  small — try getting an SBI platform definition accepted upstream
  so future Foxden deploys don't need local SBI patches.

## Project plumbing

- **CHANGELOG.md** at repo root (keeps semver visible).
- **CONTRIBUTING.md** with the "add an extension in 4 steps" walkthrough.
- **Release tarballs.** `make release` target that builds a `.tar.gz`
  without `workspace/`, `target/`, `.git/` for offline consumers.
- **CI.** A GitHub Actions workflow that at minimum runs `sbt
  compile`, `make dts`, and `python3 -m py_compile gui/*.py` on every
  push — catches regressions in config IDs / extension mapping.
- **SemVer rules** published in README; Foxden ports that change the
  FoxdenSystem IO shape bump the major version.

## Naming / branding

- Keep the "Foxden" identity consistent. Possible mascot: a fox in a
  nine-tailed RISC-V pipeline. Good for swag, also for the splash
  screen of the GUI.
- A short tag-line candidate list:
  - "MicroBlaze is dead; long live Foxden."
  - "A modern Linux-capable RISC-V softcore — yours, standalone."
  - "From Rocket to BOOM to XiangShan, one flow."
