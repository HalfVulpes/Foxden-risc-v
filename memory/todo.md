# Open TODOs (last updated 2026-04-22, after the "hygiene + README" pass)

## Just-closed in this pass
- [x] Extension surface audit: 5 → 32 mixins, 26 EXT csv keys.
- [x] XS (XiangShan Nanhu) 5th-family slot reserved + vendoring memo.
- [x] `FoxdenXiangShan.scala` raises a clean RuntimeException (verified).
- [x] Dead empty dirs (`scripts/`, `tools/`, `third_party/`) removed.
- [x] Empty `.patch` files (riscv-boom, sifive-cache) removed.
- [x] `.gitignore` extended (`*.class`, `*~`, `.vscode/`, `.direnv/`).
- [x] `CHANGELOG.md` landed at repo root.
- [x] `README.md` rewritten with ASCII-art fox banner, 5-family table,
      port diagram, Fmax/IPC tables, FAQ, roadmap, contributing guide.
- [x] `memory/ideas.md` brainstorm opened.
- [x] `memory/README.md` updated to list all notebook files.

## Longer-running

### Blocker (needs fresh attempt)
- [ ] Vivado 2023.2 fresh-project `[BD 5-232]` on `RocketChip/DMA_AXI4`.
      Five fixes tried in 0.2 (see docs/STATUS.md).  Real fix:
      `ipx::package_project` bundles rocket.vhdl as
      `foxden:core:FoxdenSystem:1.0`, then `create_bd_cell -type ip -vlnv`.
      Workaround for users today: RISC-V-CPU `FOXDEN=1` path.

### Follow-ups (Foxden 1.x post)
- [ ] Vendor XiangShan Nanhu; flip `Foxden_OoO_XS_{1,2}` over.
- [ ] Vendor Saturn V extension; flip `WithFoxdenVector` over.
- [ ] Zbb hardware via a Zbb-capable rocket-chip fork.
- [ ] Run full synth → bitstream on KU5P for one flagship per family.
- [ ] JTAG flash + Linux boot end-to-end; capture `/proc/cpuinfo`
      screenshot into docs/.
- [ ] Per-config LUT / BRAM / DSP utilisation report autopublish
      (`docs/utilization/*.md`).
- [ ] Dial `board/common/foxden-freq` with measured Fmax.

### Further out (Foxden 2.x)
- [ ] Chisel 6 port (see `memory/chisel-version.md`).
- [ ] CIRCT `firtool` replacing classic FIRRTL.
- [ ] VHDL wrapper rewrite in Python (drop the antlr4 dep).
- [ ] XiangShan Kunminghu / Nanhu-V5 as the flagship family.

### Nice-to-haves
- [ ] `WithFoxdenHetero(...)` sugar for mixed tile sets.
- [ ] Config presets shipped in `gui/presets/*.foxden`.
- [ ] Per-hart gating + NUMA demo.
- [ ] CI workflow: sbt compile + make dts + python syntax on push.
- [ ] Release tarball target.
- [ ] Web front-end of the GUI over SSH (Flask + htmx).

## Known caveats
- Multi-core BOOM (any width) is upstream-flagged as occasionally unstable;
  Foxden_OoO_Large_1 remains the recommended flagship until XS lands.
- Gemmini RoCC accelerator was *not* vendored in 1.x to keep the tree slim.

---

# Historical: closed earlier in 0.1 → 0.2 progression
- [x] `sbt compile` clean against the full vendored generator tree.
- [x] `make dts` for Foxden_IO_RV64GC_1 (1-core Rocket) + Foxden_OoO_Medium_1 (2-wide BOOM) produce valid DTS.
- [x] `make verilog` emits 205-module `FoxdenSystem.v`.
- [x] `make hdl` drives the whole chain (FIRRTL → Verilog → VHDL wrapper).
- [x] `make list-configs` enumerates all 16 Foxden configs (14 real + 2 XS reserved).
- [x] `make list-extensions` enumerates 26 EXT keys.
- [x] XS (XiangShan Nanhu) 5th-family slot reserved with clean runtime error + `memory/xiangshan-integration.md` write-up of the vendoring plan (research in that doc; summary: `nanhu` branch is the only Chisel-3-compatible modern upgrade above LargeBOOM; Kunminghu/Nanhu-V5 are Chisel-6 blocked).
- [x] Extension matrix expanded from 5 → 26 keys covering Zicond, Zfh, NMI, Hypervisor, RVE, NoC, CFlush, ClockGate, NoCease, Zihintpause, Zba/Zbb/Zbs/Zbc (advisory), B, Zicbom, Zacas, Zk, AIA, Svpbmt, Svinval, Vector (Saturn / Ara), NoFPU, FPU-NoDivSqrt, NonblockingL1. See `docs/EXTENSIONS.md`.
- [x] BOOM compatible rewrite uses `ucb-bar,boom0` (not `sifive,boom0`). DTS shows `compatible = "foxden,foxden-ooo-core", "ucb-bar,boom0", "riscv"`.

## In-flight / blocked
- [ ] Vivado 2023.2 fresh-project BD AXI inference (`[BD 5-232] No interface pins matched RocketChip/DMA_AXI4`).  Attempts so far:
  - `update_compile_order` before BD TCL — no effect.
  - `update_module_reference` after `create_bd_cell` — errored on arg type.
  - `close_project` / `open_project` cycle before BD TCL — **in progress**, monitoring.
  - Next if that fails: `ipx::package_project -force` the VHDL as a standalone IP and reference the cell with `-vlnv` instead of `-type module -reference`.

## Follow-ups
- [ ] **Vendor XiangShan Nanhu** into `generators/xiangshan/` and flip
      `Foxden_OoO_XS_{1,2}` over.  Procedure in `memory/xiangshan-integration.md`.
- [ ] **Vendor Saturn vector unit** into `generators/saturn/` and flip
      `WithFoxdenVector` to a real mixin.
- [ ] **Vendor Ara** (alternative to Saturn) - bigger lift, SV not Chisel.
- [ ] **Zbb hardware**: evaluate a Zbb-capable rocket-chip fork; flip
      `WithFoxdenZbb` + friends from advisory markers to real `useBitManip`-style flags.
- [ ] **Zicbom / Zicboz / Zacas**: need a newer rocket-chip release; tracked
      alongside Chisel-6 port in `memory/chisel-version.md`.
- [ ] **Sm/Ss-AIA**: needs IMSIC + APLIC IP blocks wired into the subsystem.
- [ ] **Dial `board/common/foxden-freq`** with measured Fmax once we have
      first successful bitstream runs.
- [ ] **Auto-publish per-config utilisation reports** under `docs/utilization/`.
- [ ] **FPU-less Linux kernel build variant** for `EXT=nofpu`.
- [ ] **Per-tile heterogeneous configs** (e.g. 1 LargeBOOM + 3 RocketBig, all on
      one subsystem).  Doable today with manual CDE stacking; ergonomic GUI
      surface is a follow-up.
- [ ] **Run full synthesis → bitstream** on KU5P once the BD inference issue
      is resolved (~45 min per config).
- [ ] **JTAG flash via hw_server + xsdb** end-to-end boot test.
- [ ] **GUI enhancements**: scrollable extension list if we go past 32 keys;
      cache-size sliders that map to `WithL1{I,D}Cache{Sets,Ways}` mixins.

## Known caveats
- Multi-core BOOM (any width) is upstream-flagged as occasionally unstable;
  Foxden_OoO_Large_1 remains the recommended flagship until XS lands.
- Gemmini RoCC accelerator was *not* vendored in 1.x to keep the tree slim.
