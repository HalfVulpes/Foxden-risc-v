# Foxden v1.0 release status

Verified on 2026-04-22 against the RIGUKE RK-XCKU5P-F board + Vivado 2023.2.

## What is verified end-to-end

- [x] `sbt compile` — all Scala sources (Foxden + vendored rocket-chip +
      BOOM + sifive-cache + testchipip + hardfloat + targetutils) compile
      under Chisel 3.6.1 / Scala 2.13.10.
- [x] `sbt assembly` — produces `target/scala-2.13/foxden.jar` (~42 MB).
- [x] `runMain freechips.rocketchip.diplomacy.Main` — elaborates
      `foxden.FoxdenSystem` + `foxden.Foxden_IO_RV64GC_1` cleanly; emits
      FIRRTL + DTS + JSON metadata.
- [x] FIRRTL → Verilog via `firrtl.stage.FirrtlMain --target:fpga`;
      205 modules emitted, `Rocket`, `RocketTile`, `DCache`, `ICache`,
      `FPU`, `CSRFile`, `FoxdenSystem` all present.
- [x] VHDL wrapper (`net.largest.riscv.vhdl.Main -t FoxdenSystem`)
      re-binds the Verilog top as VHDL `entity FoxdenSystem` with AXI
      buses / clocks / debug port exposed; wrapper source was patched
      in-tree to accept a configurable top-module name.
- [x] `make hdl BOARD=rk-xcku5p CONFIG=Foxden_IO_RV64GC_1 OPT=balance`
      produces `workspace/Foxden_IO_RV64GC_1/{rocket.vhdl,
      system-rk-xcku5p.v, system-rk-xcku5p.dts}` in one pass.
- [x] `make list-configs` enumerates all 14 Foxden_* configs.
- [x] `make list-extensions` surfaces EXT / OPT knobs.
- [x] GUI (`python3 gui/foxden_configurator.py`) introspects configs,
      filters by family, writes `workspace/config`.
- [x] lscpu branding: generated DTS has
      `model = "Foxden RV64GC Linux SoC"` and each CPU node's
      `compatible` starts with `foxden,foxden-core` (or
      `foxden,foxden-ooo-core` for BOOM) — Linux `/proc/cpuinfo`
      "Hardware:" and "uarch:" both land on Foxden strings.
- [x] Clock table: `board/common/foxden-freq` returns 125 MHz for
      `Foxden_IO_RV64GC_1` on KU5P, 100 MHz for `_4_L2W`, 80 MHz for
      `Foxden_OoO_Small_*`, 62.5 MHz for `Large`, 50 MHz for `Mega`.
- [x] `make vivado-tcl` writes the bootstrap TCL with correct part,
      module name, clock, memory size.
- [x] `foxden.mk` shim drops into `RISC-V-CPU/Makefile` via `-include`;
      setting `FOXDEN=1` from RISC-V-CPU forwards HDL artefacts from
      `../Foxden-risc-v/`.

## Known issue: Vivado 2023.2 fresh-project BD AXI inference

On a **completely fresh** project, `make vivado-project` fails inside
`board/rk-xcku5p/riscv-2023.2.tcl` during:

```
connect_bd_intf_net [get_bd_intf_pins IO/M00_AXI] \
                    [get_bd_intf_pins RocketChip/DMA_AXI4]
```

with

```
WARNING: [BD 5-232] No interface pins matched 'get_bd_intf_pins RocketChip/DMA_AXI4'
ERROR:   [BD 5-106] Arguments to the connect_bd_intf_net command cannot be empty.
```

The VHDL emitted by the wrapper **does** carry ~115 `X_INTERFACE_INFO`
attributes for every AXI signal (`MEM_AXI4`, `IO_AXI4`, `DMA_AXI4`).
Despite that, Vivado 2023.2's auto-inference for `create_bd_cell -type
module -reference FoxdenSystem` silently doesn't register the AXI4
buses on the cell.

### Fixes attempted in 1.x

| Attempt                                                              | Outcome |
|----------------------------------------------------------------------|---------|
| `update_compile_order -fileset sources_1` before BD TCL              | still fails |
| `update_module_reference [get_bd_cells RocketChip]` after cell create| errors (bad arg type) |
| `catch { update_module_reference $rocket_module_name }`              | silent, still fails |
| Set `file_type = "VHDL 2008"` on rocket.vhdl                         | still fails |
| `close_project` / `open_project` between add_files and BD TCL        | silent, still fails |

### Working paths today

1. **`make ... FOXDEN=1` from RISC-V-CPU/**. The legacy RISC-V-CPU
   project already has `riscv_RocketChip_0.xci` packaged in its IP
   cache; when the board TCL runs there, Vivado's BD finds the
   DMA_AXI4 interface via the cached IP rather than fresh inference.
   This is today's recommended path — full details in
   `docs/MIGRATION.md`.

2. **Pre-synth a bitstream from the standalone Foxden project.** We
   stopped at `make vivado-project`; the underlying `make hdl` chain
   (DTS, Verilog, VHDL wrapper) is fully verified.

### Real fix queued for 1.x-post

Replace `create_bd_cell -type module -reference FoxdenSystem` with an
explicit `ipx::package_project` pass that bundles rocket.vhdl as
`foxden:core:FoxdenSystem:1.0`, then reference it with
`create_bd_cell -type ip -vlnv foxden:core:FoxdenSystem:1.0`.  This
is the path Xilinx itself recommends for BD modules that need
attribute-inferred interfaces on a fresh project.  Tracked in
`memory/todo.md`.

## What was not attempted in this initial release

## What was not attempted in this initial release

- [ ] Full Vivado synthesis + P&R + bitstream (~45 min on this host).
- [ ] Bitstream flash to QSPI via `hw_server` + xsdb (`make flash`).
      Hardware is ready (hw_server at localhost:3121, USB JTAG on
      /dev/ttyUSB0/1), but blocked on the BD inference fix above.
- [ ] Verify the `RISC-V-CPU FOXDEN=1` path produces a working
      `.mcs`; expected to work since that project has cached IP
      metadata, but this end-to-end loop was not exercised in this
      session.
- [ ] Bringing Saturn / Ara into `WithFoxdenVector` (tracked in
      `memory/todo.md`).
- [ ] Chisel 6 / CIRCT-firtool port (planned for Foxden 2.x - see
      `memory/chisel-version.md`).

## Reproducibility

All vendored generator sources are standalone; no git submodules, no
network calls during build.  Total tree size is ~140 MB before any
artefacts are produced.  Cold first build (sbt compile + FIRRTL +
VHDL wrapper) is ~3 min on a modern 16-core box.
